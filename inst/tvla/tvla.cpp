/* Simulated power analysis: Test Vector Leakage Assessment (TVLA, fixed-vs-random Welch
 * t-test; Goodwill et al. 2011, ISO/IEC 17825) on power traces from an emulated
 * Cortex-M4 under a Hamming-weight leakage model.
 *
 * The kernels (kernels.cpp, the package's own arithmetic) are cross-compiled for a
 * Cortex-M4 and executed instruction by instruction in unicorn. Each instruction is one
 * sample: the Hamming weight of every register value it changed, plus that of every value
 * it stored to memory. That is the standard first-order model of CMOS power consumption
 * (data-dependent switching), the model physical traces of microcontrollers follow to
 * first order. Class 0 runs on a fixed secret, class 1 on a random one, chosen at random
 * per trace; Welch's t at every sample compares the classes. |t| > 4.5 anywhere is the
 * TVLA mark of first-order leakage.
 *
 * What this is and is not: a pre-silicon assessment of the code under a leakage model. It
 * finds the first-order leakage the model expresses (values, not timing; timing is
 * inst/dudect's). It is not a measurement of a physical device: real chips leak through
 * transitions, glitches and coupling the model omits, which is why masked designs are
 * also checked on hardware when hardware is available.
 *
 *   ./tvla KERNEL [traces]     KERNEL: list | all | a name below
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
#include <unicorn/unicorn.h>

#include "build/symbols.h"   /* addresses of the kernel entry points, from nm */

static const uint64_t kBase = 0x20000000, kSize = 1u << 20;
static const uint64_t kInput = kBase + 0xC0000;   /* input/output buffers */
static const uint64_t kStack = kBase + kSize - 16;
static const int16_t kQ = 3329;

struct Run {
    uc_engine *uc = nullptr;
    std::vector<double> trace;
    uint32_t last[13] = {0};
};

static inline int hw32(uint32_t x) { return __builtin_popcount(x); }

static void on_code(uc_engine *uc, uint64_t, uint32_t, void *ud) {
    Run *r = static_cast<Run *>(ud);
    static const int regs[13] = {UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3, UC_ARM_REG_R4,
                                 UC_ARM_REG_R5, UC_ARM_REG_R6, UC_ARM_REG_R7, UC_ARM_REG_R8, UC_ARM_REG_R9,
                                 UC_ARM_REG_R10, UC_ARM_REG_R11, UC_ARM_REG_R12};
    uint32_t v[13];
    void *ptrs[13];
    for (int i = 0; i < 13; ++i) ptrs[i] = &v[i];
    uc_reg_read_batch(uc, const_cast<int *>(regs), ptrs, 13);
    double s = 0;
    for (int i = 0; i < 13; ++i) {
        if (v[i] != r->last[i]) s += hw32(v[i]);
        r->last[i] = v[i];
    }
    /* the sample for the instruction that just completed */
    r->trace.push_back(s);
}

static void on_write(uc_engine *, uc_mem_type, uint64_t, int size, int64_t value, void *ud) {
    Run *r = static_cast<Run *>(ud);
    uint64_t v = static_cast<uint64_t>(value);
    if (size < 8) v &= (1ull << (8 * size)) - 1;
    if (!r->trace.empty()) r->trace.back() += __builtin_popcountll(v);
}

static std::vector<unsigned char> g_image;

static void load_image(const char *path) {
    FILE *f = std::fopen(path, "rb");
    if (!f) { std::perror(path); std::exit(2); }
    unsigned char buf[65536];
    size_t n;
    while ((n = std::fread(buf, 1, sizeof buf, f)) > 0) g_image.insert(g_image.end(), buf, buf + n);
    std::fclose(f);
}

/* Run one kernel call; returns the trace. args are r0..r4 (r4 goes on the stack per AAPCS). */
static std::vector<double> run_kernel(uint32_t entry, const std::vector<uint32_t> &args,
                                      const std::vector<std::pair<uint64_t, std::vector<unsigned char>>> &mem) {
    Run r;
    if (uc_open(UC_ARCH_ARM, static_cast<uc_mode>(UC_MODE_THUMB | UC_MODE_MCLASS), &r.uc) != UC_ERR_OK) { std::fprintf(stderr, "uc_open\n"); std::exit(2); }
    uc_mem_map(r.uc, kBase, kSize, UC_PROT_ALL);
    uc_mem_write(r.uc, kBase, g_image.data(), g_image.size());
    for (const auto &m : mem) uc_mem_write(r.uc, m.first, m.second.data(), m.second.size());
    uint32_t sp = static_cast<uint32_t>(kStack);
    if (args.size() > 4) {
        sp -= 8;
        uint32_t a4 = args[4];
        uc_mem_write(r.uc, sp, &a4, 4);
    }
    const int ar[4] = {UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3};
    for (size_t i = 0; i < args.size() && i < 4; ++i) { uint32_t a = args[i]; uc_reg_write(r.uc, ar[i], &a); }
    uc_reg_write(r.uc, UC_ARM_REG_SP, &sp);
    uint32_t lr = static_cast<uint32_t>(TVLA_HALT) | 1u;
    uc_reg_write(r.uc, UC_ARM_REG_LR, &lr);
    uc_reg_read(r.uc, UC_ARM_REG_R0, &r.last[0]);
    uc_hook h1, h2;
    uc_hook_add(r.uc, &h1, UC_HOOK_CODE, reinterpret_cast<void *>(on_code), &r, 1, 0);
    uc_hook_add(r.uc, &h2, UC_HOOK_MEM_WRITE, reinterpret_cast<void *>(on_write), &r, 1, 0);
    const uc_err e = uc_emu_start(r.uc, entry | 1u, TVLA_HALT & ~1u, 0, 0);
    if (e != UC_ERR_OK) { std::fprintf(stderr, "emulation failed: %s\n", uc_strerror(e)); std::exit(2); }
    uc_close(r.uc);
    return r.trace;
}

/* ---- kernels and their input classes -------------------------------------------------- */
static std::vector<unsigned char> bytes16(const std::vector<int16_t> &v) {
    std::vector<unsigned char> b(v.size() * 2);
    std::memcpy(b.data(), v.data(), b.size());
    return b;
}
static std::vector<int16_t> poly(std::mt19937_64 &g) {
    std::vector<int16_t> p(256);
    for (auto &x : p) x = static_cast<int16_t>(g() % kQ);
    return p;
}
static std::vector<int16_t> sub_mod(const std::vector<int16_t> &a, const std::vector<int16_t> &b) {
    std::vector<int16_t> c(256);
    for (int i = 0; i < 256; ++i) c[i] = static_cast<int16_t>(((a[i] - b[i]) % kQ + kQ) % kQ);
    return c;
}

struct Kernel {
    const char *name;
    const char *what;
    bool masked;
    std::vector<double> (*trace)(const std::vector<int16_t> &secret, std::mt19937_64 &g);
};

static std::vector<int16_t> g_public;   /* the fixed public operand (u) */

static std::vector<double> k_basemul(const std::vector<int16_t> &s, std::mt19937_64 &) {
    const uint64_t a = kInput, b = a + 512, o = b + 512;
    return run_kernel(TVLA_MLKEM_BASEMUL, {uint32_t(a), uint32_t(b), uint32_t(o)},
                      {{a, bytes16(s)}, {b, bytes16(g_public)}});
}
static std::vector<double> k_basemul_masked(const std::vector<int16_t> &s, std::mt19937_64 &g) {
    const std::vector<int16_t> s0 = poly(g), s1 = sub_mod(s, s0);   /* fresh shares every run */
    const uint64_t a = kInput, a1 = a + 512, b = a1 + 512, o0 = b + 512, o1 = o0 + 512;
    return run_kernel(TVLA_MLKEM_BASEMUL_MASKED, {uint32_t(a), uint32_t(a1), uint32_t(b), uint32_t(o0), uint32_t(o1)},
                      {{a, bytes16(s0)}, {a1, bytes16(s1)}, {b, bytes16(g_public)}});
}
static std::vector<double> k_ntt(const std::vector<int16_t> &s, std::mt19937_64 &) {
    const uint64_t a = kInput;
    return run_kernel(TVLA_MLKEM_NTT, {uint32_t(a)}, {{a, bytes16(s)}});
}
static std::vector<double> k_ntt_masked(const std::vector<int16_t> &s, std::mt19937_64 &g) {
    const std::vector<int16_t> s0 = poly(g), s1 = sub_mod(s, s0);
    const uint64_t a = kInput, a1 = a + 512;
    return run_kernel(TVLA_MLKEM_NTT_MASKED, {uint32_t(a), uint32_t(a1)}, {{a, bytes16(s0)}, {a1, bytes16(s1)}});
}

static const Kernel kKernels[] = {
    {"mlkem_basemul", "ML-KEM secret-key product s*u (NTT domain), unmasked", false, k_basemul},
    {"mlkem_basemul_masked", "ML-KEM secret-key product, first-order arithmetic masking", true, k_basemul_masked},
    {"mlkem_ntt", "ML-KEM forward NTT of a secret polynomial, unmasked", false, k_ntt},
    {"mlkem_ntt_masked", "ML-KEM forward NTT, first-order arithmetic masking", true, k_ntt_masked},
};

struct Acc {
    std::vector<double> mean[2], m2[2];
    double n[2] = {0, 0};
    void push(const std::vector<double> &x, int c) {
        if (mean[c].empty()) { mean[c].assign(x.size(), 0); m2[c].assign(x.size(), 0); }
        n[c] += 1;
        for (size_t i = 0; i < x.size(); ++i) {
            const double d = x[i] - mean[c][i];
            mean[c][i] += d / n[c];
            m2[c][i] += d * (x[i] - mean[c][i]);
        }
    }
};

/* Welch's t at every sample of one experiment. */
static std::vector<double> tvec(const Acc &acc, size_t len) {
    std::vector<double> t(len, 0);
    for (size_t i = 0; i < len; ++i) {
        const double v0 = acc.n[0] > 1 ? acc.m2[0][i] / (acc.n[0] - 1) : 0;
        const double v1 = acc.n[1] > 1 ? acc.m2[1][i] / (acc.n[1] - 1) : 0;
        const double den = std::sqrt(v0 / acc.n[0] + v1 / acc.n[1]);
        t[i] = den > 0 ? (acc.mean[0][i] - acc.mean[1][i]) / den : 0;
    }
    return t;
}

/* Two independent experiments, as the TVLA procedure prescribes: a sample point counts as
 * leaking only when |t| > 4.5 in both, with the same sign. With tens of thousands of points
 * a single experiment crosses 4.5 somewhere by chance (P(|t| > 4.5) is about 7e-6 per
 * point); two independent crossings at the same point do not happen by chance. */
static int run(const Kernel &k, int traces, std::mt19937_64 &g) {
    const std::vector<int16_t> fixed = poly(g);
    Acc acc[2];
    size_t len = 0;
    for (int e = 0; e < 2; ++e) {
        for (int i = 0; i < traces; ++i) {
            const int c = static_cast<int>(g() & 1u);
            const std::vector<double> t = k.trace(c == 0 ? fixed : poly(g), g);
            if (len == 0) len = t.size();
            if (t.size() != len) {
                std::printf("%-22s trace length varies (%zu vs %zu): timing depends on the input\n", k.name,
                            t.size(), len);
                return 1;
            }
            acc[e].push(t, c);
        }
    }
    const std::vector<double> t1 = tvec(acc[0], len), t2 = tvec(acc[1], len);
    double tmax = 0;
    size_t both = 0, at = 0;
    for (size_t i = 0; i < len; ++i) {
        const double m = std::min(std::fabs(t1[i]), std::fabs(t2[i]));
        if (m > 4.5 && (t1[i] > 0) == (t2[i] > 0)) ++both;
        if (m > tmax) { tmax = m; at = i; }
    }
    const bool leaks = both > 0;
    std::printf("%-22s traces=2x%-5d samples=%-7zu min-of-two max|t|=%8.2f at %-6zu points leaking in both: %-6zu %s  (%s)\n",
                k.name, traces, len, tmax, at, both, leaks ? "FIRST-ORDER LEAKAGE" : "no first-order leakage", k.what);
    std::fflush(stdout);
    /* the unmasked kernels are expected to leak (they are the positive controls); a
     * masked kernel that leaks is the failure */
    if (k.masked && leaks) return 1;
    if (!k.masked && !leaks) { std::printf("  control NOT detected: the model sees nothing here\n"); return 1; }
    return 0;
}

int main(int argc, char **argv) {
    const char *which = argc > 1 ? argv[1] : "all";
    const int traces = argc > 2 ? std::atoi(argv[2]) : 2000;
    if (std::strcmp(which, "list") == 0) {
        for (const auto &k : kKernels) std::printf("%-22s %s\n", k.name, k.what);
        return 0;
    }
    const char *img = std::getenv("TVLA_IMAGE");
    load_image(img ? img : "build/kernels.bin");
    std::random_device rd;
    std::mt19937_64 g((static_cast<uint64_t>(rd()) << 32) ^ rd());
    g_public = poly(g);
    int bad = 0, ran = 0;
    for (const auto &k : kKernels) {
        if (std::strcmp(which, "all") != 0 && std::strcmp(which, k.name) != 0) continue;
        bad += run(k, traces, g);
        ++ran;
    }
    if (!ran) { std::fprintf(stderr, "unknown kernel %s (try: list)\n", which); return 2; }
    return bad ? 1 : 0;
}
