#include "ct_common.h"
#include <string>
#include <vector>

int ct_running_memcheck() { return RUNNING_ON_VALGRIND != 0; }

/* The kernels test for a pending interrupt through rmbl_barrier.cpp, which
 * is R's; this binary runs with no R session, so nothing is ever pending. */
extern "C" int rmbl_kernel_interrupted = 0;
extern "C" int rmbl_interrupt_pending(void) { return 0; }
/* the kernels raise a pending interrupt through the barrier; no R here */
extern "C" void rmbl_interrupt_raise_unbarriered(void) {}


__attribute__((noinline)) int ct_stack_remnants(const unsigned char *needle, size_t n, const char *what) {
    unsigned char probe[1 << 16];
    __asm__ volatile("" : : "r"(probe) : "memory"); /* the dead stack, not a fresh zero page */
    ct_public(probe, sizeof probe);                 /* the scan itself is not a finding */
    ct_public(needle, n);
    const size_t w = n < 16 ? n : 16;
    int hits = 0;
    for (size_t i = 0; i + w <= sizeof probe; ++i) {
        if (std::memcmp(probe + i, needle, w) == 0) ++hits;
    }
    if (hits) std::fprintf(stderr, "ZEROISATION: %d cop%s of %s left on the dead stack\n", hits, hits == 1 ? "y" : "ies", what);
    return hits;
}

struct Case {
    const char *name;
    int (*fn)();
};
int ct_mlkem512();
int ct_mlkem768();
int ct_mlkem1024();
int ct_mldsa44();
int ct_mldsa65();
int ct_mldsa87();
int ct_slhdsa_shake_128f();
int ct_slhdsa_sha2_128f();
int ct_slhdsa_shake_128s();
int ct_hqc1();
int ct_hqc3();
int ct_hqc5();
int ct_hqc1_round4();
int ct_xmss();
int ct_drbg_portable();
int ct_drbg_aesni();
int ct_hmac_sha256();
int ct_pbkdf2();
int ct_blake2b_keyed();
int ct_sha2();
int ct_sha3();
int ct_digest_equal();

static const Case kCases[] = {
    {"mlkem512", ct_mlkem512},       {"mlkem768", ct_mlkem768},     {"mlkem1024", ct_mlkem1024},
    {"mldsa44", ct_mldsa44},         {"mldsa65", ct_mldsa65},       {"mldsa87", ct_mldsa87},
    {"slhdsa-shake-128f", ct_slhdsa_shake_128f}, {"slhdsa-sha2-128f", ct_slhdsa_sha2_128f},
    {"slhdsa-shake-128s", ct_slhdsa_shake_128s},
    {"hqc1", ct_hqc1},               {"hqc3", ct_hqc3},             {"hqc5", ct_hqc5},
    {"hqc1-round4", ct_hqc1_round4}, {"xmss", ct_xmss},
    {"drbg-portable", ct_drbg_portable}, {"drbg-aesni", ct_drbg_aesni},
    {"hmac-sha256", ct_hmac_sha256}, {"pbkdf2", ct_pbkdf2},         {"blake2b-keyed", ct_blake2b_keyed},
    {"sha2", ct_sha2},               {"sha3", ct_sha3},             {"digest-equal", ct_digest_equal},
};

int main(int argc, char **argv) {
    if (argc < 2 || std::string(argv[1]) == "--list") {
        for (const Case &c : kCases) std::printf("%s\n", c.name);
        return argc < 2 ? 2 : 0;
    }
    int bad = 0;
    for (int i = 1; i < argc; ++i) {
        bool found = false;
        for (const Case &c : kCases) {
            if (std::string(argv[i]) == c.name) {
                found = true;
                const int rc = c.fn();
                std::fprintf(stderr, "%s: %s\n", c.name, rc == 0 ? "ok" : "FAILED (functional check)");
                if (rc != 0) ++bad;
            }
        }
        if (!found) {
            std::fprintf(stderr, "unknown case %s\n", argv[i]);
            return 2;
        }
    }
    return bad ? 1 : 0;
}
