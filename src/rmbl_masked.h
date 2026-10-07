#ifndef RMBL_MASKED_H
#define RMBL_MASKED_H

/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * First-order masking gadgets (two shares) for ML-KEM decapsulation.
 *
 * A secret is held as two shares that are each uniformly random on their own: a Boolean
 * sharing x = x0 ^ x1, or an arithmetic sharing a = a0 + a1 (mod q). Linear operations act
 * on each share separately. The non-linear ones (AND, addition across bits, the
 * conversions between the two kinds of sharing) use fresh randomness so that no single
 * intermediate value depends on the secret. That is first-order security: an adversary
 * who sees any one intermediate value (a power sample, under the usual leakage model)
 * learns nothing about the secret. inst/tvla checks these gadgets, compiled for a
 * Cortex-M4, against that model.
 *
 * Algorithms: Trichina's two-share AND; a ripple-carry adder over Boolean shares
 * (Goubin 2001, bitsliced 32 coefficients to a word as in Bronchain and Cassiers, TCHES
 * 2022); conversion from arithmetic shares mod q by adding the shares inside the Boolean
 * domain and testing the sum against public constants (the decoding of Bos et al., TCHES
 * 2021, and the decompressed comparison of Bhasin et al., TCHES 2021, which replaces the
 * hash-based comparison of Oder et al. 2018 that Bhasin et al. broke); Boolean-to-
 * arithmetic conversion by a masked modular subtraction of a fresh arithmetic share; and
 * the masked Keccak of Bertoni et al. (2010), chi through the masked AND.
 *
 * No R, no allocation, no library calls: the package and the Cortex-M4 build share it.
 */

#include <stddef.h>
#include <stdint.h>

namespace rmbl_masked {

/* An opaque copy: stops the optimiser from seeing through a share computation and
 * recombining the shares (x0 ^ x1 computed in a register would unmask x). */
#if defined(__GNUC__) || defined(__clang__)
template <class T> inline T opaque(T x) {
    __asm__ volatile("" : "+r"(x));
    return x;
}
#else
template <class T> inline T opaque(T x) { return x; }
#endif

/* The randomness source: the package passes the operating system's CSPRNG, the Cortex-M4
 * build a buffer the host fills. */
struct Rng {
    uint32_t (*fn)(void *);
    void *ctx;
    uint32_t u32() { return fn(ctx); }
    uint64_t u64() {
        const uint64_t h = u32();
        return (h << 32) | u32();
    }
};

const int16_t kQ = 3329;

/* A value in [0, q) from 32 random bits by multiply-and-shift: no loop, so the running
 * time never depends on the randomness (a rejection loop made the trace length vary). Its
 * distance from uniform is at most q / 2^32 < 2^-20. */
inline int16_t rand_q(Rng &rng) {
    return static_cast<int16_t>((static_cast<uint64_t>(rng.u32()) * static_cast<uint64_t>(kQ)) >> 32);
}

/* v + q when v < 0, else v, for v in (-2^31, 2^31 - q): the sign becomes an all-ones or
 * all-zero mask through opaque(), so the compiler cannot turn it back into a conditional
 * (an IT block on Thumb-2 executes or skips the add depending on the share). */
inline int32_t cadd_q(int32_t v) {
    const uint32_t m = opaque(static_cast<uint32_t>(0u - (static_cast<uint32_t>(v) >> 31)));
    return static_cast<int32_t>(static_cast<uint32_t>(v) + (static_cast<uint32_t>(kQ) & m));
}

/* Trichina's AND: (z0, z1) shares x & y. Each partial sum is masked by r before a cross
 * term joins it, so no intermediate depends on x or y. */
template <class T>
inline void sec_and(T &z0, T &z1, T x0, T x1, T y0, T y1, T r) {
    T t = opaque(static_cast<T>(r ^ (x0 & y0)));
    t = opaque(static_cast<T>(t ^ (x0 & y1)));
    t = opaque(static_cast<T>(t ^ (x1 & y0)));
    t = opaque(static_cast<T>(t ^ (x1 & y1)));
    z0 = r;
    z1 = t;
}

/* ---- bitsliced Boolean numbers: 32 lanes, bit b of every lane in word w[share][b] ---- */
const int kMaxBits = 16;
struct Bs {
    uint32_t w[2][kMaxBits];
};

/* One share's 32 values, bitsliced: a function of that share alone. */
inline void bitslice(uint32_t out[kMaxBits], const int16_t v[32], int bits) {
    for (int b = 0; b < bits; ++b) {
        uint32_t w = 0;
        for (int j = 0; j < 32; ++j) {
            w |= (static_cast<uint32_t>(static_cast<uint16_t>(v[j]) >> b) & 1u) << j;
        }
        out[b] = w;
    }
    for (int b = bits; b < kMaxBits; ++b) out[b] = 0;
}

/* Boolean shares of one arithmetic share's values, re-masked with fresh randomness: two
 * arithmetic shares must never meet unmasked inside one Boolean sharing, or their XOR (a
 * function of the secret) would appear in a register. */
inline void boolean_of_share(Bs &out, const int16_t v[32], int bits, Rng &rng) {
    uint32_t w[kMaxBits];
    bitslice(w, v, bits);
    for (int b = 0; b < bits; ++b) {
        const uint32_t r = rng.u32();
        out.w[0][b] = opaque(static_cast<uint32_t>(w[b] ^ r));
        out.w[1][b] = r;
    }
    for (int b = bits; b < kMaxBits; ++b) out.w[0][b] = out.w[1][b] = 0;
}

/* z = x + y (mod 2^bits), ripple-carry over Boolean shares. */
inline void sec_add(Bs &z, const Bs &x, const Bs &y, int bits, Rng &rng) {
    uint32_t c0 = 0, c1 = 0;
    for (int i = 0; i < bits; ++i) {
        const uint32_t p0 = x.w[0][i] ^ y.w[0][i], p1 = x.w[1][i] ^ y.w[1][i];
        z.w[0][i] = opaque(static_cast<uint32_t>(p0 ^ c0));
        z.w[1][i] = opaque(static_cast<uint32_t>(p1 ^ c1));
        if (i + 1 < bits) {
            uint32_t g0, g1, h0, h1;
            sec_and(g0, g1, x.w[0][i], x.w[1][i], y.w[0][i], y.w[1][i], rng.u32());
            sec_and(h0, h1, c0, c1, p0, p1, rng.u32());
            c0 = opaque(static_cast<uint32_t>(g0 ^ h0));
            c1 = opaque(static_cast<uint32_t>(g1 ^ h1));
        }
    }
    for (int i = bits; i < kMaxBits; ++i) z.w[0][i] = z.w[1][i] = 0;
}

/* z = x + c (mod 2^bits) for a public constant per lane. */
inline void sec_add_public(Bs &z, const Bs &x, const int16_t c[32], int bits, Rng &rng) {
    uint32_t cw[kMaxBits];
    bitslice(cw, c, bits);
    uint32_t c0 = 0, c1 = 0;
    for (int i = 0; i < bits; ++i) {
        const uint32_t p0 = x.w[0][i] ^ cw[i], p1 = x.w[1][i];
        z.w[0][i] = opaque(static_cast<uint32_t>(p0 ^ c0));
        z.w[1][i] = opaque(static_cast<uint32_t>(p1 ^ c1));
        if (i + 1 < bits) {
            /* x & c is linear in x for a public c */
            const uint32_t g0 = x.w[0][i] & cw[i], g1 = x.w[1][i] & cw[i];
            uint32_t h0, h1;
            sec_and(h0, h1, c0, c1, p0, p1, rng.u32());
            c0 = opaque(static_cast<uint32_t>(g0 ^ h0));
            c1 = opaque(static_cast<uint32_t>(g1 ^ h1));
        }
    }
    for (int i = bits; i < kMaxBits; ++i) z.w[0][i] = z.w[1][i] = 0;
}

/* Masked "x < c" per lane, for x in [0, 2^13) and a public c in [0, 2^14): the sign of
 * x - c in 14-bit two's complement. Shares (s0, s1) of a word whose bit j is lane j's
 * answer. */
const int kCmpBits = 14;
inline void sec_less(uint32_t &s0, uint32_t &s1, const Bs &x, const int16_t c[32], Rng &rng) {
    int16_t neg[32];
    for (int j = 0; j < 32; ++j) neg[j] = static_cast<int16_t>((1 << kCmpBits) - c[j]);
    Bs d;
    sec_add_public(d, x, neg, kCmpBits, rng);
    s0 = d.w[0][kCmpBits - 1];
    s1 = d.w[1][kCmpBits - 1];
}

/* The integer sum T = a0 + a1 (in [0, 2q - 2]) of two arithmetic shares in [0, q), as
 * Boolean shares, 14 bits, 32 lanes. */
inline void share_sum(Bs &t, const int16_t a0[32], const int16_t a1[32], Rng &rng) {
    Bs x, y;
    boolean_of_share(x, a0, kCmpBits, rng);
    boolean_of_share(y, a1, kCmpBits, rng);
    sec_add(t, x, y, kCmpBits, rng);
}

/* Masked Compress_1 (FIPS 203 decoding of one message bit per coefficient): the bit is 1
 * exactly when the coefficient x lies in [833, 2496]. With T = a0 + a1, x is T or T - q,
 * so the bit is [833 <= T < 2497] xor [4162 <= T < 5826]. */
inline void sec_decode1(uint32_t &b0, uint32_t &b1, const int16_t a0[32], const int16_t a1[32],
                        Rng &rng) {
    Bs t;
    share_sum(t, a0, a1, rng);
    int16_t c[32];
    uint32_t l1[2], l2[2], l3[2], l4[2];
    const int16_t k[4] = {833, 2497, 4162, 5826};
    uint32_t *outs[4] = {l1, l2, l3, l4};
    for (int i = 0; i < 4; ++i) {
        for (int j = 0; j < 32; ++j) c[j] = k[i];
        sec_less(outs[i][0], outs[i][1], t, c, rng);
    }
    /* [T >= 833] & [T < 2497]: the complement of a Boolean sharing flips one share */
    uint32_t p0, p1, q0, q1;
    sec_and(p0, p1, static_cast<uint32_t>(~l1[0]), l1[1], l2[0], l2[1], rng.u32());
    sec_and(q0, q1, static_cast<uint32_t>(~l3[0]), l3[1], l4[0], l4[1], rng.u32());
    b0 = opaque(static_cast<uint32_t>(p0 ^ q0));
    b1 = opaque(static_cast<uint32_t>(p1 ^ q1));
}

/* Masked interval test for the ciphertext comparison: lane j's coefficient x (shares in
 * [0, q)) satisfies (x - lo_j) mod q < w_j. a0 is shifted by the public lo first. */
inline void sec_in_interval(uint32_t &o0, uint32_t &o1, const int16_t a0[32], const int16_t a1[32],
                            const int16_t lo[32], const int16_t w[32], Rng &rng) {
    int16_t s0[32];
    for (int j = 0; j < 32; ++j) {
        int32_t v = static_cast<int32_t>(a0[j]) - lo[j];
        v = cadd_q(v);
        s0[j] = static_cast<int16_t>(v);
    }
    Bs t;
    share_sum(t, s0, a1, rng);
    int16_t cw[32], cq[32], cqw[32];
    for (int j = 0; j < 32; ++j) {
        cw[j] = w[j];
        cq[j] = kQ;
        cqw[j] = static_cast<int16_t>(kQ + w[j]);
    }
    uint32_t a[2], b[2], c[2];
    sec_less(a[0], a[1], t, cw, rng);   /* T < w */
    sec_less(b[0], b[1], t, cq, rng);   /* T < q */
    sec_less(c[0], c[1], t, cqw, rng);  /* T < q + w */
    uint32_t d0, d1;
    sec_and(d0, d1, static_cast<uint32_t>(~b[0]), b[1], c[0], c[1], rng.u32());
    o0 = opaque(static_cast<uint32_t>(a[0] ^ d0));
    o1 = opaque(static_cast<uint32_t>(a[1] ^ d1));
}

/* Boolean (bitsliced, `bits` wide, non-negative values below q) to arithmetic shares mod
 * q: a1 is a fresh uniform share; a0 = (v - a1) mod q is computed inside the Boolean
 * domain and only then recombined, which reveals a value uniform on its own. */
inline void sec_b2a(int16_t a0[32], int16_t a1[32], const Bs &v, Rng &rng) {
    int16_t r[32], nr[32];
    for (int j = 0; j < 32; ++j) {
        r[j] = rand_q(rng);
        nr[j] = static_cast<int16_t>(kQ - r[j]);   /* in [1, q] */
    }
    Bs m, y, z;
    boolean_of_share(m, nr, kCmpBits, rng);
    sec_add(y, v, m, kCmpBits, rng);              /* v + q - r, in [1, 2q) */
    int16_t negq[32], cq[32];
    for (int j = 0; j < 32; ++j) {
        negq[j] = static_cast<int16_t>((1 << kCmpBits) - kQ);
        cq[j] = kQ;
    }
    sec_add_public(z, y, negq, kCmpBits, rng);    /* y - q */
    uint32_t s0, s1;
    sec_less(s0, s1, y, cq, rng);                 /* y < q: keep y, else y - q */
    for (int b = 0; b < kCmpBits; ++b) {
        uint32_t t0, t1;
        sec_and(t0, t1, s0, s1, y.w[0][b] ^ z.w[0][b], y.w[1][b] ^ z.w[1][b], rng.u32());
        z.w[0][b] = opaque(static_cast<uint32_t>(z.w[0][b] ^ t0));
        z.w[1][b] = opaque(static_cast<uint32_t>(z.w[1][b] ^ t1));
    }
    /* recombine: (v - r) mod q is uniform whatever v is */
    for (int j = 0; j < 32; ++j) {
        uint32_t val = 0;
        for (int b = 0; b < kCmpBits; ++b) {
            const uint32_t bit = ((z.w[0][b] ^ z.w[1][b]) >> j) & 1u;
            val |= bit << b;
        }
        a0[j] = static_cast<int16_t>(val);
        a1[j] = r[j];
    }
}

/* Masked SamplePolyCBD_eta for 32 coefficients: buf0 ^ buf1 is the PRF output; lane j is
 * coefficient lane0 + j. Each coefficient is popcount(x bits) - popcount(y bits), shifted
 * by eta into [0, 2 eta] in the Boolean domain, converted, and shifted back mod q. */
inline void sec_cbd32(int16_t a0[32], int16_t a1[32], const unsigned char *buf0,
                      const unsigned char *buf1, int lane0, int eta, Rng &rng) {
    /* sum of eta one-bit values, as a 2-bit Boolean number (eta <= 3) */
    Bs acc_x, acc_y;
    for (int s = 0; s < 2; ++s)
        for (int b = 0; b < kMaxBits; ++b) acc_x.w[s][b] = acc_y.w[s][b] = 0;
    for (int k = 0; k < 2 * eta; ++k) {
        Bs bit;
        for (int s = 0; s < 2; ++s) {
            const unsigned char *buf = s ? buf1 : buf0;
            uint32_t w = 0;
            for (int j = 0; j < 32; ++j) {
                const size_t pos = static_cast<size_t>(2 * eta) * static_cast<size_t>(lane0 + j) + static_cast<size_t>(k);
                w |= static_cast<uint32_t>((buf[pos >> 3] >> (pos & 7u)) & 1u) << j;
            }
            bit.w[s][0] = w;
            for (int b = 1; b < kMaxBits; ++b) bit.w[s][b] = 0;
        }
        Bs &acc = k < eta ? acc_x : acc_y;
        Bs sum;
        sec_add(sum, acc, bit, 2, rng);
        acc = sum;
    }
    /* v = x + ~y + 1 + eta = x - y + eta, in 4-bit arithmetic (2 eta <= 6) */
    Bs ny;
    for (int s = 0; s < 2; ++s)
        for (int b = 0; b < kMaxBits; ++b) ny.w[s][b] = acc_y.w[s][b];
    for (int b = 0; b < 4; ++b) ny.w[0][b] = ~ny.w[0][b];   /* ~y over 4 bits: -y - 1 (mod 16) */
    Bs v1, v;
    sec_add(v1, acc_x, ny, 4, rng);
    int16_t c[32];
    for (int j = 0; j < 32; ++j) c[j] = static_cast<int16_t>(eta + 1);
    sec_add_public(v, v1, c, 4, rng);                   /* x - y + eta, in [0, 2 eta] */
    for (int s = 0; s < 2; ++s)
        for (int b = 4; b < kMaxBits; ++b) v.w[s][b] = 0;
    sec_b2a(a0, a1, v, rng);
    for (int j = 0; j < 32; ++j) {                      /* undo the shift by eta, mod q */
        int32_t t = static_cast<int32_t>(a0[j]) - eta;
        t = cadd_q(t);
        a0[j] = static_cast<int16_t>(t);
    }
}

/* ---- masked Keccak-f[1600] ------------------------------------------------------------ */
const uint64_t kRC[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL, 0x8000000080008000ULL,
    0x000000000000808bULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
    0x000000000000008aULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
    0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
    0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800aULL, 0x800000008000000aULL,
    0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL};
const int kRho[25] = {0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, 21, 8, 18, 2, 61, 56, 14};

inline uint64_t rotl(uint64_t x, int n) { return n ? (x << n) | (x >> (64 - n)) : x; }

/* theta, rho, pi on one share (linear) */
inline void keccak_linear(uint64_t a[25]) {
    uint64_t c[5], b[25];
    for (int x = 0; x < 5; ++x) c[x] = a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20];
    for (int x = 0; x < 5; ++x) {
        const uint64_t d = c[(x + 4) % 5] ^ rotl(c[(x + 1) % 5], 1);
        for (int y = 0; y < 25; y += 5) a[y + x] ^= d;
    }
    for (int x = 0; x < 5; ++x)
        for (int y = 0; y < 5; ++y) b[y + 5 * ((2 * x + 3 * y) % 5)] = rotl(a[x + 5 * y], kRho[x + 5 * y]);
    for (int i = 0; i < 25; ++i) a[i] = b[i];
}

inline void keccakf_masked(uint64_t s0[25], uint64_t s1[25], Rng &rng) {
    for (int round = 0; round < 24; ++round) {
        keccak_linear(s0);
        keccak_linear(s1);
        for (int y = 0; y < 25; y += 5) {
            uint64_t b0[5], b1[5];
            for (int x = 0; x < 5; ++x) {
                b0[x] = s0[y + x];
                b1[x] = s1[y + x];
            }
            for (int x = 0; x < 5; ++x) {
                uint64_t t0, t1;
                /* chi: a ^ (~b & c); the complement flips one share */
                sec_and(t0, t1, static_cast<uint64_t>(~b0[(x + 1) % 5]), b1[(x + 1) % 5], b0[(x + 2) % 5],
                        b1[(x + 2) % 5], rng.u64());
                s0[y + x] = opaque(static_cast<uint64_t>(b0[x] ^ t0));
                s1[y + x] = opaque(static_cast<uint64_t>(b1[x] ^ t1));
            }
        }
        s0[0] ^= kRC[round];   /* iota, into one share */
    }
}

/* A masked sponge: in0 ^ in1 is the input (in1 may be NULL for a public tail), out0 ^ out1
 * the output. rate in bytes, domain the padding byte (0x06 SHA-3, 0x1f SHAKE). */
inline void sponge_masked(unsigned char *out0, unsigned char *out1, size_t outlen,
                          const unsigned char *in0, const unsigned char *in1, size_t inlen,
                          size_t rate, unsigned char domain, Rng &rng) {
    uint64_t s0[25], s1[25];
    for (int i = 0; i < 25; ++i) s0[i] = s1[i] = 0;
    size_t pos = 0;
    for (size_t i = 0; i < inlen; ++i) {
        const int lane = static_cast<int>(pos / 8), sh = static_cast<int>(8 * (pos % 8));
        s0[lane] ^= static_cast<uint64_t>(in0[i]) << sh;
        if (in1) s1[lane] ^= static_cast<uint64_t>(in1[i]) << sh;
        if (++pos == rate) {
            keccakf_masked(s0, s1, rng);
            pos = 0;
        }
    }
    s0[pos / 8] ^= static_cast<uint64_t>(domain) << (8 * (pos % 8));
    s0[(rate - 1) / 8] ^= static_cast<uint64_t>(0x80) << (8 * ((rate - 1) % 8));
    keccakf_masked(s0, s1, rng);
    pos = 0;
    for (size_t i = 0; i < outlen; ++i) {
        if (pos == rate) {
            keccakf_masked(s0, s1, rng);
            pos = 0;
        }
        const int lane = static_cast<int>(pos / 8), sh = static_cast<int>(8 * (pos % 8));
        out0[i] = static_cast<unsigned char>(s0[lane] >> sh);
        out1[i] = static_cast<unsigned char>(s1[lane] >> sh);
        ++pos;
    }
}

}  // namespace rmbl_masked

#endif
