/* dudect-style timing leakage test (Reparaz, Balasch, Verbauwhede, "Dude, is my code
 * constant time?", DATE 2017), written for this package's kernels.
 *
 * For each target, every measurement times one call (or a fixed batch of calls) on an
 * input drawn from one of two classes: class 0 a FIXED input, class 1 a RANDOM one,
 * chosen at random per measurement so drift in the machine affects both classes alike.
 * Welch's t-test compares the two timing distributions, on the raw measurements and on
 * each of NUM_CROPS upper-tail crops (the method's guard against outliers). A constant-
 * time implementation shows no difference whatever the input; |t| > 10 is the method's
 * conventional mark of a real difference, |t| < 4.5 of none.
 *
 * This measures the binary on the machine it runs on: the CI matrix runs it on x86-64
 * (Linux) and arm64 (macOS); ./run.sh runs it anywhere the package builds. It is the
 * hardware counterpart of inst/ctcheck, which proves the absence of secret-dependent
 * branches and addresses statically under valgrind.
 *
 *   ./dudect TARGET [measurements]      (TARGET: list | all | one name below)
 */
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <string>
#include <vector>
#include <time.h>
#if defined(__aarch64__) && defined(__linux__)
#include <sys/auxv.h>
#endif

/* the kernels, from their own translation units */
size_t dd_mlkem_ct_bytes();
void dd_mlkem_prep(const unsigned char *seed64, const unsigned char *m32);
void dd_mlkem_dec_fixed(unsigned char *in);
void dd_mlkem_dec_run(const unsigned char *in);
void dd_mlkem_enc_run(const unsigned char *m32);
size_t dd_hqc_ct_bytes();
size_t dd_hqc_k_bytes();
size_t dd_hqc_salt_bytes();
void dd_hqc_prep(const unsigned char *seed32, const unsigned char *m, const unsigned char *salt);
void dd_hqc_dec_fixed(unsigned char *in);
void dd_hqc_dec_run(const unsigned char *in);

extern "C" { int rmbl_kernel_interrupted = 0; }
extern "C" int rmbl_interrupt_pending(void) { return 0; }
extern "C" void rmbl_interrupt_raise_unbarriered(void) {}
extern "C" int rmbl_digest_equal(const char *a, const char *b, size_t n);
extern "C" int rmbl_pbkdf2_sha256(const unsigned char *pass, size_t passlen,
                                  const unsigned char *salt, size_t saltlen,
                                  int iterations, int dklen, unsigned char *out);

/* ---- the clock: a cycle or tick counter, serialised ------------------------------- */
static inline uint64_t ticks() {
#if defined(__x86_64__) || defined(__i386__)
    unsigned lo, hi;
    __asm__ volatile("lfence\n\trdtsc\n\tlfence" : "=a"(lo), "=d"(hi) :: "memory");
    return (static_cast<uint64_t>(hi) << 32) | lo;
#elif defined(__aarch64__)
    uint64_t v;
    __asm__ volatile("isb\n\tmrs %0, cntvct_el0\n\tisb" : "=r"(v) :: "memory");
    return v;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return static_cast<uint64_t>(ts.tv_sec) * 1000000000ull + static_cast<uint64_t>(ts.tv_nsec);
#endif
}

/* ---- Arm data-independent timing (FEAT_DIT) ------------------------------------------- */
/* On Armv8.4+ cores the architecture guarantees data-independent timing for the integer
 * instructions only while PSTATE.DIT is set. DUDECT_DIT=1 sets it for the whole run, so CI
 * can measure the kernels with and without it. Returns whether DIT is now set. */
static bool set_dit() {
#if defined(__aarch64__)
#if defined(__linux__)
    const unsigned long kHwcapDit = 1ul << 24;
    if (!(getauxval(AT_HWCAP) & kHwcapDit)) return false;
#endif
    __asm__ volatile(".inst 0xd503415f");   /* msr DIT, #1 */
    uint64_t v;
    __asm__ volatile(".inst 0xd53b42a0\n\tmov %0, x0" : "=r"(v) :: "x0");   /* mrs x0, DIT */
    return (v >> 24) & 1u;
#else
    return false;
#endif
}

/* ---- Welch's t, online (Welford) ----------------------------------------------------- */
struct Welch {
    double mean[2] = {0, 0}, m2[2] = {0, 0}, n[2] = {0, 0};
    void push(double x, int c) {
        n[c] += 1;
        const double d = x - mean[c];
        mean[c] += d / n[c];
        m2[c] += d * (x - mean[c]);
    }
    double t() const {
        if (n[0] < 2 || n[1] < 2) return 0;
        const double v0 = m2[0] / (n[0] - 1), v1 = m2[1] / (n[1] - 1);
        const double den = std::sqrt(v0 / n[0] + v1 / n[1]);
        return den > 0 ? (mean[0] - mean[1]) / den : 0;
    }
};

/* ---- targets --------------------------------------------------------------------------- */
struct Target {
    const char *name;
    const char *what;
    size_t in_len;          /* bytes of per-measurement input */
    int batch;              /* calls per timed measurement (raises short calls above the clock) */
    void (*prepare)(std::mt19937_64 &);            /* fixed key material */
    void (*fixed)(unsigned char *in);              /* class 0 input */
    void (*run)(const unsigned char *in);          /* the operation timed */
};

static unsigned char g_sink[64];

static void rnd_fill(std::mt19937_64 &g, unsigned char *p, size_t n) {
    for (size_t i = 0; i < n; ++i) p[i] = static_cast<unsigned char>(g());
}

/* ML-KEM-768 decapsulation: fixed key; a valid ciphertext against random ones (which take
 * the implicit-rejection path). Encapsulation: fixed key; the secret message m fixed
 * against random. */
static void mlkem_prep(std::mt19937_64 &g) {
    unsigned char seed[64], m[32];
    rnd_fill(g, seed, 64);
    rnd_fill(g, m, 32);
    dd_mlkem_prep(seed, m);
}
static unsigned char g_m_fixed[32] = {0x5a};
static void mlkem_enc_fixed(unsigned char *in) { std::memcpy(in, g_m_fixed, 32); }

/* HQC-1 decapsulation: fixed key; a valid ciphertext against random ones. */
static void hqc_prep(std::mt19937_64 &g) {
    unsigned char seed[32];
    std::vector<unsigned char> m(dd_hqc_k_bytes()), salt(dd_hqc_salt_bytes());
    rnd_fill(g, seed, 32);
    rnd_fill(g, m.data(), m.size());
    rnd_fill(g, salt.data(), salt.size());
    dd_hqc_prep(seed, m.data(), salt.data());
}

/* Digest comparison: equal digests against random (unequal) ones of the same length. */
static unsigned char g_ref[64];
static void cmp_prep(std::mt19937_64 &g) { rnd_fill(g, g_ref, 64); }
static void cmp_fixed(unsigned char *in) { std::memcpy(in, g_ref, 64); }
static void cmp_run(const unsigned char *in) {
    g_sink[0] ^= static_cast<unsigned char>(
        rmbl_digest_equal(reinterpret_cast<const char *>(g_ref), reinterpret_cast<const char *>(in), 64));
}

/* PBKDF2-HMAC-SHA-256, one iteration: the password fixed against random (same length). */
static unsigned char g_pw_fixed[32] = {0x31};
static void kdf_fixed(unsigned char *in) { std::memcpy(in, g_pw_fixed, 32); }
static void kdf_run(const unsigned char *in) {
    static const unsigned char salt[16] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
    rmbl_pbkdf2_sha256(in, 32, salt, 16, 1, 32, g_sink);
}
static void none_prep(std::mt19937_64 &) {}

/* Positive control: an early-exit compare, which leaks by construction (equal inputs scan
 * all 64 bytes, random ones stop at the first). The run requires dudect to flag it, so a
 * clean result for the real targets cannot come from a harness that sees nothing. */
static void __attribute__((noinline)) leaky_cmp_run(const unsigned char *in) {
    volatile int eq = 1;
    for (int i = 0; i < 64; ++i) {
        if (in[i] != g_ref[i]) { eq = 0; break; }
    }
    g_sink[1] ^= static_cast<unsigned char>(eq);
}

static const Target kTargets[] = {
    {"mlkem768_decaps", "ML-KEM-768 decapsulation: valid vs random ciphertext",
     dd_mlkem_ct_bytes(), 1, mlkem_prep, dd_mlkem_dec_fixed, dd_mlkem_dec_run},
    {"mlkem768_encaps", "ML-KEM-768 encapsulation: fixed vs random message m",
     32, 1, mlkem_prep, mlkem_enc_fixed, dd_mlkem_enc_run},
    {"hqc1_decaps", "HQC-1 decapsulation: valid vs random ciphertext",
     dd_hqc_ct_bytes(), 1, hqc_prep, dd_hqc_dec_fixed, dd_hqc_dec_run},
    {"digest_equal", "constant-time digest compare: equal vs unequal 64-byte inputs",
     64, 64, cmp_prep, cmp_fixed, cmp_run},
    {"pbkdf2_sha256", "PBKDF2-HMAC-SHA-256 (1 iteration): fixed vs random password",
     32, 4, none_prep, kdf_fixed, kdf_run},
};
static const Target kControl = {"control_leaky", "positive control: early-exit compare (must be flagged)",
                                64, 64, cmp_prep, cmp_fixed, leaky_cmp_run};

/* ---- the test --------------------------------------------------------------------------- */
static const int kCrops = 100;

/* Inputs for a chunk of measurements are generated before any of them is timed, both
 * classes into the same array (dudect's own discipline): generating a random input just
 * before timing it, and copying a fixed one, leave the caches and predictors in different
 * states, which shows up as a difference that has nothing to do with the code under test. */
static const long kChunk = 2048;

static double time_one(const Target &t, const unsigned char *in) {
    const uint64_t a = ticks();
    for (int b = 0; b < t.batch; ++b) t.run(in);
    const uint64_t z = ticks();
    return static_cast<double>(z - a);
}

static void fill_chunk(const Target &t, std::mt19937_64 &g, std::vector<unsigned char> &buf,
                       std::vector<int> &cls, long n) {
    for (long i = 0; i < n; ++i) {
        cls[static_cast<size_t>(i)] = static_cast<int>(g() & 1u);
        unsigned char *slot = buf.data() + static_cast<size_t>(i) * t.in_len;
        if (cls[static_cast<size_t>(i)] == 0) t.fixed(slot); else rnd_fill(g, slot, t.in_len);
    }
}

static int run_target(const Target &t, long n_meas, std::mt19937_64 &g) {
    t.prepare(g);
    std::vector<unsigned char> buf(static_cast<size_t>(kChunk) * t.in_len);
    std::vector<int> cls(static_cast<size_t>(kChunk));
    /* warm-up chunk sets the crop thresholds */
    fill_chunk(t, g, buf, cls, kChunk);
    std::vector<double> first;
    for (long i = 0; i < kChunk; ++i) first.push_back(time_one(t, buf.data() + static_cast<size_t>(i) * t.in_len));
    std::sort(first.begin(), first.end());
    double thr[kCrops];
    for (int k = 0; k < kCrops; ++k) {
        const double p = 1.0 - std::pow(0.5, 10.0 * (k + 1) / kCrops);
        thr[k] = first[static_cast<size_t>(p * (first.size() - 1))];
    }
    Welch all, crop[kCrops];
    for (long done = 0; done < n_meas; done += kChunk) {
        const long n = n_meas - done < kChunk ? n_meas - done : kChunk;
        fill_chunk(t, g, buf, cls, n);
        for (long i = 0; i < n; ++i) {
            const double x = time_one(t, buf.data() + static_cast<size_t>(i) * t.in_len);
            const int c = cls[static_cast<size_t>(i)];
            all.push(x, c);
            for (int k = 0; k < kCrops; ++k) if (x < thr[k]) crop[k].push(x, c);
        }
    }
    double tmax = std::fabs(all.t());
    for (int k = 0; k < kCrops; ++k) {
        if (crop[k].n[0] + crop[k].n[1] < 1000) continue;
        const double v = std::fabs(crop[k].t());
        if (v > tmax) tmax = v;
    }
    const char *verdict = tmax > 10 ? "LEAKAGE" : (tmax > 4.5 ? "inconclusive" : "no evidence of leakage");
    std::printf("%-16s n=%-9ld max|t|=%7.3f  mean ticks %10.1f vs %10.1f  %s  (%s)\n", t.name, n_meas,
                tmax, all.mean[0], all.mean[1], verdict, t.what);
    std::fflush(stdout);
    return tmax > 10 ? 1 : 0;
}

int main(int argc, char **argv) {
    const char *which = argc > 1 ? argv[1] : "all";
    const long n = argc > 2 ? std::atol(argv[2]) : 200000;
    if (std::strcmp(which, "list") == 0) {
        for (const auto &t : kTargets) std::printf("%-16s %s\n", t.name, t.what);
        std::printf("%-16s %s\n", kControl.name, kControl.what);
        return 0;
    }
    std::random_device rd;
    std::mt19937_64 g((static_cast<uint64_t>(rd()) << 32) ^ rd());
    const char *dit = std::getenv("DUDECT_DIT");
    if (dit && std::strcmp(dit, "1") == 0) {
        std::printf("DIT: %s\n", set_dit() ? "set (data-independent timing on)" : "not available on this CPU");
    } else {
        std::printf("DIT: not requested\n");
    }
    int bad = 0, ran = 0;
    if (std::strcmp(which, "all") == 0 || std::strcmp(which, kControl.name) == 0) {
        /* the control must be flagged: if it is not, the measurement cannot see a leak here */
        if (run_target(kControl, n, g) == 0) {
            std::printf("CONTROL NOT DETECTED: this machine or clock cannot resolve the leak; "
                        "the results below are not evidence\n");
            return 3;
        }
        if (std::strcmp(which, kControl.name) == 0) return 0;
    }
    for (const auto &t : kTargets) {
        if (std::strcmp(which, "all") != 0 && std::strcmp(which, t.name) != 0) continue;
        bad += run_target(t, n, g);
        ++ran;
    }
    if (!ran) { std::fprintf(stderr, "unknown target %s (try: list)\n", which); return 2; }
    return bad ? 1 : 0;
}
