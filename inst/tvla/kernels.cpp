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

/* ---- the masked gadgets of src/rmbl_masked.h (the masked decapsulation's building
 * blocks). Randomness comes from a buffer the host fills afresh for every trace. Each
 * gadget also runs as its own unmasked control: the same code with the second share zero,
 * which is the plain computation on the secret. ---- */
#include "../../src/rmbl_masked.h"

static const uint32_t *g_rand;
static uint32_t rand_fn(void *) { return *g_rand++; }

extern "C" {

__attribute__((used, noinline)) void tvla_decode(const int16_t *a0, const int16_t *a1, const uint32_t *rnd,
                                                 uint32_t *out) {
    g_rand = rnd;
    rmbl_masked::Rng rng;
    rng.fn = rand_fn;
    rng.ctx = 0;
    rmbl_masked::sec_decode1(out[0], out[1], a0, a1, rng);
}

__attribute__((used, noinline)) void tvla_keccak(uint64_t *s0, uint64_t *s1, const uint32_t *rnd) {
    g_rand = rnd;
    rmbl_masked::Rng rng;
    rng.fn = rand_fn;
    rng.ctx = 0;
    rmbl_masked::keccakf_masked(s0, s1, rng);
}

__attribute__((used, noinline)) void tvla_cbd(const unsigned char *b0, const unsigned char *b1, const uint32_t *rnd,
                                              int16_t *out) {
    g_rand = rnd;
    rmbl_masked::Rng rng;
    rng.fn = rand_fn;
    rng.ctx = 0;
    rmbl_masked::sec_cbd32(out, out + 32, b0, b1, 0, 2, rng);
}

}

/* no C library on the bare target: the two routines the compiler emits for struct copies */
extern "C" __attribute__((used)) void *memcpy(void *d, const void *s, unsigned int n) {
    unsigned char *dd = static_cast<unsigned char *>(d);
    const unsigned char *ss = static_cast<const unsigned char *>(s);
    while (n--) *dd++ = *ss++;
    return d;
}
extern "C" __attribute__((used)) void *memset(void *d, int c, unsigned int n) {
    unsigned char *dd = static_cast<unsigned char *>(d);
    while (n--) *dd++ = static_cast<unsigned char>(c);
    return d;
}
