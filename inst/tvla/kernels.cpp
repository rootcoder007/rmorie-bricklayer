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

/* ---- composed kernels: several gadgets in one trace, so the hand-over between them (a
 * register or stack slot one gadget leaves for the next) is measured too. The ML-KEM one is
 * the decapsulation's secret-dependent spine for one polynomial: w = v - s*u (basemul,
 * inverse NTT, share by share), Compress_1 of w by the masked decoder, then one Keccak
 * permutation over a state seeded with the message shares (the first block of G). The ML-DSA
 * one is the signer's z path for 32 coefficients: y from Boolean shares (sec_b2a), z = y + c s1
 * share by share, the masked norm test, then the masked low-bits test on w - c s2. ---- */
extern "C" {

__attribute__((used, noinline)) void tvla_mlkem_decaps_composed(const int16_t *s0, const int16_t *s1,
                                                                 const int16_t *u, const int16_t *v,
                                                                 const uint32_t *rnd, uint32_t *out) {
    g_rand = rnd;
    rmbl_masked::Rng rng;
    rng.fn = rand_fn;
    rng.ctx = 0;
    int16_t w0[256], w1[256];
    poly_basemul(w0, s0, u);
    invntt(w0);
    for (int j = 0; j < 256; ++j) w0[j] = static_cast<int16_t>(v[j] - w0[j]);
    poly_basemul(w1, s1, u);
    invntt(w1);
    for (int j = 0; j < 256; ++j) w1[j] = static_cast<int16_t>(-w1[j]);
    for (int j = 0; j < 256; ++j) {
        w0[j] = to_positive(barrett_reduce(w0[j]));
        w1[j] = to_positive(barrett_reduce(w1[j]));
    }
    uint32_t m0[8], m1[8];
    for (int g = 0; g < 8; ++g) rmbl_masked::sec_decode1(m0[g], m1[g], w0 + 32 * g, w1 + 32 * g, rng);
    uint64_t st0[25], st1[25];
    for (int i = 0; i < 25; ++i) { st0[i] = 0; st1[i] = 0; }
    for (int g = 0; g < 8; g += 2) {
        st0[g / 2] = static_cast<uint64_t>(m0[g]) | (static_cast<uint64_t>(m0[g + 1]) << 32);
        st1[g / 2] = static_cast<uint64_t>(m1[g]) | (static_cast<uint64_t>(m1[g + 1]) << 32);
    }
    rmbl_masked::keccakf_masked(st0, st1, rng);
    for (int g = 0; g < 8; ++g) { out[g] = m0[g]; out[8 + g] = m1[g]; }
    out[16] = static_cast<uint32_t>(st0[0]);
    out[17] = static_cast<uint32_t>(st1[0]);
}

__attribute__((used, noinline)) void tvla_dsa_sign_composed(const unsigned char *y0, const unsigned char *y1,
                                                             const int32_t *cs1_0, const int32_t *cs1_1,
                                                             const uint32_t *rnd, uint32_t *out) {
    g_rand = rnd;
    rmbl_masked::Rng rng;
    rng.fn = rand_fn;
    rng.ctx = 0;
    const int32_t q = 8380417;
    rmbl_masked::Bs yb;
    for (int s = 0; s < 2; ++s) {
        const unsigned char *buf = s ? y1 : y0;
        for (int b = 0; b < 20; ++b) {
            uint32_t w = 0;
            for (int j = 0; j < 32; ++j) {
                const unsigned pos = 20u * static_cast<unsigned>(j) + static_cast<unsigned>(b);
                w |= static_cast<uint32_t>((buf[pos >> 3] >> (pos & 7u)) & 1u) << j;
            }
            yb.w[s][b] = w;
        }
        for (int b = 20; b < rmbl_masked::kMaxBits; ++b) yb.w[s][b] = 0;
    }
    int32_t z0[32], z1[32];
    rmbl_masked::sec_b2a(z0, z1, yb, rng, rmbl_masked::kDsa);
    /* z = y + c s1, share by share, reduced into [0, q) */
    for (int j = 0; j < 32; ++j) {
        z0[j] += cs1_0[j]; z0[j] -= q & -static_cast<int32_t>(z0[j] >= q);
        z1[j] += cs1_1[j]; z1[j] -= q & -static_cast<int32_t>(z1[j] >= q);
    }
    rmbl_masked::AllOk acc;
    rmbl_masked::dsa_norm_acc(acc, z0, z1, 32, (1 << 19) - 196, rng);
    rmbl_masked::Bs bp;
    rmbl_masked::dsa_bprime(bp, z0, z1, (8380417 - 1) / 32, rng);
    int32_t w1[32];
    for (int j = 0; j < 32; ++j) w1[j] = 0;
    uint32_t o[2];
    rmbl_masked::dsa_lowbits_ok(o, bp, w1, (8380417 - 1) / 32, 196, rng);
    acc.add(o, rng);
    rmbl_masked::m_pub(rmbl_masked::pz(out, out + 1, acc.a, acc.a + 1), 0, 3);
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

/* ---- ML-DSA signing gadgets (q = 8380417), from the same header ---- */
extern "C" {

/* y's Boolean-to-arithmetic conversion: 32 values of 20 bits, packed as in polyz_unpack,
 * b0 ^ b1 the secret; out = 32 arithmetic shares then 32 more */
__attribute__((used, noinline)) void tvla_dsa_b2a(const unsigned char *b0, const unsigned char *b1,
                                                  const uint32_t *rnd, int32_t *out) {
    g_rand = rnd;
    rmbl_masked::Rng rng;
    rng.fn = rand_fn;
    rng.ctx = 0;
    rmbl_masked::Bs v;
    for (int s = 0; s < 2; ++s) {
        const unsigned char *buf = s ? b1 : b0;
        for (int b = 0; b < 20; ++b) {
            uint32_t w = 0;
            for (int j = 0; j < 32; ++j) {
                const unsigned pos = 20u * static_cast<unsigned>(j) + static_cast<unsigned>(b);
                w |= static_cast<uint32_t>((buf[pos >> 3] >> (pos & 7u)) & 1u) << j;
            }
            v.w[s][b] = w;
        }
        for (int b = 20; b < rmbl_masked::kMaxBits; ++b) v.w[s][b] = 0;
    }
    rmbl_masked::sec_b2a(out, out + 32, v, rng, rmbl_masked::kDsa);
}

/* HighBits' operand b' and the r0 window test of 32 values a0 + a1 mod q (w1 = 0, gamma2 =
 * (q - 1) / 32, beta = 196: ML-DSA-65); out = the test's two share words */
__attribute__((used, noinline)) void tvla_dsa_lowbits(const int32_t *a0, const int32_t *a1, const uint32_t *rnd,
                                                      uint32_t *out) {
    g_rand = rnd;
    rmbl_masked::Rng rng;
    rng.fn = rand_fn;
    rng.ctx = 0;
    rmbl_masked::Bs bp;
    rmbl_masked::dsa_bprime(bp, a0, a1, (8380417 - 1) / 32, rng);
    int32_t w1[32];
    for (int j = 0; j < 32; ++j) w1[j] = 0;
    rmbl_masked::dsa_lowbits_ok(out, bp, w1, (8380417 - 1) / 32, 196, rng);
}

/* the masked norm test ||a|| < gamma1 - beta over 32 values, accumulated, not revealed */
__attribute__((used, noinline)) void tvla_dsa_norm(const int32_t *a0, const int32_t *a1, const uint32_t *rnd,
                                                   uint32_t *out) {
    g_rand = rnd;
    rmbl_masked::Rng rng;
    rng.fn = rand_fn;
    rng.ctx = 0;
    rmbl_masked::AllOk acc;
    rmbl_masked::dsa_norm_acc(acc, a0, a1, 32, (1 << 19) - 196, rng);
    rmbl_masked::m_pub(rmbl_masked::pz(out, out + 1, acc.a, acc.a + 1), 0, 3);
}

}
