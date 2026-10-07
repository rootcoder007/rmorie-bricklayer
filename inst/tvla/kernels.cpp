/* Cortex-M4 kernels for the simulated power analysis (tvla.cpp). Freestanding: no library,
 * no startup code; the host sets the stack and calls each entry point directly. The
 * arithmetic is the package's own (src/rmbl_mlkem_arith.h), not a copy.
 *
 * Unmasked entries take the secret as it is. Masked entries take it as two arithmetic
 * shares, s = s0 + s1 mod q, freshly split for every execution, and never combine them:
 * every intermediate value is a function of one share, which on its own is uniform and
 * independent of s. That is first-order masking of the linear part of decapsulation. */
#include "../../src/rmbl_mlkem_arith.h"

using namespace rmbl_mlkem_core;

extern "C" {

/* s^T u in the NTT domain for one polynomial: the secret-key product at the heart of
 * ML-KEM decryption (FIPS 203 K-PKE.Decrypt), with u public. */
__attribute__((used, noinline)) void tvla_mlkem_basemul(const int16_t *s, const int16_t *u, int16_t *out) {
    poly_basemul(out, s, u);
}

__attribute__((used, noinline)) void tvla_mlkem_basemul_masked(const int16_t *s0, const int16_t *s1,
                                                                const int16_t *u, int16_t *out0, int16_t *out1) {
    poly_basemul(out0, s0, u);
    poly_basemul(out1, s1, u);
}

/* The forward NTT of a secret polynomial (ML-KEM key generation transforms s and e). */
__attribute__((used, noinline)) void tvla_mlkem_ntt(int16_t *r) { ntt(r); }

__attribute__((used, noinline)) void tvla_mlkem_ntt_masked(int16_t *r0, int16_t *r1) {
    ntt(r0);
    ntt(r1);
}

/* the return trap: the host stops emulation when execution reaches here */
__attribute__((used, noinline, naked)) void tvla_halt(void) { __asm__ volatile("b ."); }

}
