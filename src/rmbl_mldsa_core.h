#ifndef RMBL_MLDSA_CORE_H
#define RMBL_MLDSA_CORE_H

/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Arithmetic layer for ML-DSA (FIPS 204): the ring Z_q[X]/(X^256 + 1)
 * with q = 8380417, its number-theoretic transform, and the coefficient
 * decompositions the signature scheme is built from.
 *
 * q = 2^23 - 2^13 + 1 is prime and q - 1 is divisible by 512, so the
 * ring has a primitive 512th root of unity (1753) and the transform is
 * the negacyclic one: 256 pointwise products replace a 256-term
 * convolution, which is what makes the scheme fast enough to be
 * practical.
 *
 * Coefficients are held in Montgomery form during the transform --
 * a value x is represented as x * 2^32 mod q -- because that turns the
 * modular reduction after each multiply into a shift and a subtract
 * with no division. The zetas table below is therefore also in
 * Montgomery form, and is COMPUTED at load rather than transcribed, so
 * a typo in 256 constants is not a thing that can happen here; the
 * test suite checks the computed table against the published one.
 */

#include <cstddef>
#include <cstdint>
#include <cstring>

#include <R.h>
#include <Rinternals.h>

/* the FIPS 202 sponge from rmbl_keccak.cpp */
struct RmblKeccak {
    uint64_t s[25];
    size_t rate;
    unsigned char pad;
    size_t pos;
    bool squeezing;
};
extern "C" void rmbl_keccak_init(RmblKeccak *, size_t, unsigned char);
extern "C" void rmbl_keccak_absorb(RmblKeccak *, const unsigned char *,
                                   size_t);
extern "C" void rmbl_keccak_finalize(RmblKeccak *);
extern "C" void rmbl_keccak_squeeze(RmblKeccak *, unsigned char *,
                                    size_t);
extern "C" void rmbl_shake256(unsigned char *, size_t,
                              const unsigned char *, size_t);

namespace rmbl_mldsa_core {


const int32_t kQ = 8380417;
const int32_t kQInv = 58728449;      /* q^-1 mod 2^32 */
const int kN = 256;
const int32_t kRootOfUnity = 1753;

/* r = a * 2^-32 mod q, with -q < r < q for |a| <= 2^31 * q. */
inline int32_t montgomery_reduce(int64_t a) {
    const int32_t t = static_cast<int32_t>(
        static_cast<int64_t>(static_cast<int32_t>(a)) * kQInv);
    return static_cast<int32_t>((a - static_cast<int64_t>(t) * kQ) >> 32);
}

/* r congruent to a mod q with |r| <= 6283008, for a <= 2^31 - 2^22 - 1. */
inline int32_t reduce32(int32_t a) {
    const int32_t t = (a + (1 << 22)) >> 23;
    return a - t * kQ;
}

/* the canonical representative in [0, q) */
inline int32_t caddq(int32_t a) {
    return a + ((a >> 31) & kQ);
}

/* The zetas table: zetas[i] = 2^32 * zeta^brv8(i) mod q, where brv8 is
 * the bit reversal of an 8-bit index. Computed once, on first use. */
struct Zetas {
    int32_t z[256];
    Zetas() {
        /* 2^32 mod q, obtained without a 64-bit modulus on the constant
         * so the value is derived rather than asserted */
        int64_t mont = 1;
        for (int i = 0; i < 32; ++i) mont = (mont * 2) % kQ;
        /* powers of the root of unity in plain form */
        int64_t pow[256];
        pow[0] = 1;
        for (int i = 1; i < 256; ++i) {
            pow[i] = (pow[i - 1] * kRootOfUnity) % kQ;
        }
        for (int i = 0; i < 256; ++i) {
            /* bit-reverse the 8-bit index */
            int r = 0;
            for (int b = 0; b < 8; ++b) if (i & (1 << b)) r |= 1 << (7 - b);
            z[i] = static_cast<int32_t>((pow[r] * mont) % kQ);
            /* the reference stores these as signed values in (-q/2, q/2] */
            if (z[i] > kQ / 2) z[i] -= kQ;
            if (z[i] < -kQ / 2) z[i] += kQ;
        }
        /* Index 0 is never read -- both transforms step k before using
         * it -- and the reference leaves it zero. Match that, so the
         * computed table can be compared against the published one
         * element for element with nothing to explain away. */
        z[0] = 0;
        {
        }
    }
};

const Zetas &zetas() {
    static const Zetas z;
    return z;
}

/* Forward negacyclic NTT, in place. Input coefficients bounded by q in
 * absolute value; output by 8q. */
void ntt(int32_t a[256]) {
    const int32_t *z = zetas().z;
    unsigned int k = 0;
    for (int len = 128; len > 0; len >>= 1) {
        for (int start = 0; start < 256; start = start + 2 * len) {
            const int32_t zeta = z[++k];
            for (int j = start; j < start + len; ++j) {
                const int32_t t = montgomery_reduce(
                    static_cast<int64_t>(zeta) * a[j + len]);
                a[j + len] = a[j] - t;
                a[j] = a[j] + t;
            }
        }
    }
}

/* Inverse NTT, in place, including the 256^-1 scaling folded into the
 * final constant. */
void invntt_tomont(int32_t a[256]) {
    const int32_t *z = zetas().z;
    /* 256^-1 * 2^64 mod q, so the output lands back in Montgomery form */
    const int32_t f = 41978;
    unsigned int k = 256;
    for (int len = 1; len < 256; len <<= 1) {
        for (int start = 0; start < 256; start = start + 2 * len) {
            const int32_t zeta = -z[--k];
            for (int j = start; j < start + len; ++j) {
                const int32_t t = a[j];
                a[j] = t + a[j + len];
                a[j + len] = t - a[j + len];
                a[j + len] = montgomery_reduce(
                    static_cast<int64_t>(zeta) * a[j + len]);
            }
        }
    }
    for (int j = 0; j < 256; ++j) {
        a[j] = montgomery_reduce(static_cast<int64_t>(f) * a[j]);
    }
}

/* ---------------------------------------------------------------------
 * Sampling. Every one of these is rejection sampling over a SHAKE
 * stream, and the rejection bounds are what make the output uniform on
 * the intended set rather than merely pseudorandom. Getting a bound
 * wrong yields a scheme that still signs and verifies against itself
 * and is not ML-DSA.
 * ------------------------------------------------------------------ */

}  // namespace rmbl_mldsa_core

#endif
