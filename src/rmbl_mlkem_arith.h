#ifndef RMBL_MLKEM_ARITH_H
#define RMBL_MLKEM_ARITH_H

/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * ML-KEM (FIPS 203) ring arithmetic: Z_q[X]/(X^256+1) with q = 3329, the Montgomery and
 * Barrett reductions, the number-theoretic transform and the base-case products. No R,
 * no allocation, no library calls: rmbl_mlkem_core.h includes it for the package, and
 * inst/tvla compiles the same file for a bare Cortex-M4 to analyse its power leakage.
 * See rmbl_mlkem_core.h for why this is not shared with ML-DSA.
 */

#include <stdint.h>

namespace rmbl_mlkem_core {

const int16_t kQ = 3329;
const int kN = 256;
const uint16_t kQInv = 62209;   /* q^-1 mod 2^16 */
const int16_t kZetaRoot = 17;   /* the 256th root of unity mod q */

/* a * 2^-16 mod q, for |a| < 2^15 * q. The cast to int16_t is the
 * reduction: it keeps only the low 16 bits, which is exactly the
 * multiple of q that has to be subtracted. */
inline int16_t montgomery_reduce(int32_t a) {
    /* uint16 * uint16 promotes to int and overflows for a > 2^15 (gcc-UBSAN
     * on CRAN, 2026-09-17); widen to uint32_t so the product is unsigned
     * arithmetic, then keep the low 16 bits. */
    const int16_t t = static_cast<int16_t>(static_cast<uint16_t>(
        static_cast<uint32_t>(static_cast<uint16_t>(a)) * kQInv));
    return static_cast<int16_t>((a - static_cast<int32_t>(t) * kQ) >> 16);
}

/* a mod q, centred: the result is in (-q/2, q/2]. */
inline int16_t barrett_reduce(int16_t a) {
    const int16_t v = static_cast<int16_t>(((1 << 26) + kQ / 2) / kQ);
    int16_t t = static_cast<int16_t>(
        (static_cast<int32_t>(v) * a + (1 << 25)) >> 26);
    t = static_cast<int16_t>(t * kQ);
    return static_cast<int16_t>(a - t);
}

/* The positive standard representative, 0 to q-1. barrett_reduce leaves
 * a CENTRED value, so what is needed here is to add q to the negative
 * ones -- not to subtract it, which is the same code with the sign the
 * other way round and silently encodes negative coefficients. */
/* floor(n / q) and n mod q for 0 <= n < 2^23, by multiply-and-shift (Granlund and
 * Montgomery 1994: m = ceil(2^35 / q), exact on that range; checked for every n). A
 * written division by the constant q is turned into the same multiply only when the
 * compiler optimises: at -O0, GCC emits a hardware divide, whose latency depends on the
 * operand on many cores (KyberSlash, Bernstein et al. 2024). Secret-dependent code calls
 * these instead. */
inline uint32_t div_q(uint32_t n) {
    return static_cast<uint32_t>((static_cast<uint64_t>(n) * 10321340u) >> 35);
}
inline uint32_t mod_q(uint32_t n) { return n - 3329u * div_q(n); }

inline int16_t to_positive(int16_t a) {
    return static_cast<int16_t>(a + ((a >> 15) & kQ));
}

/* The 128 twiddle factors, in Montgomery form, indexed by the
 * bit-reversal of the exponent as FIPS 203 specifies. Computed rather
 * than transcribed: a table of 128 hand-copied constants is 128 chances
 * to introduce a typo that no round-trip test would catch, since the
 * inverse transform would undo it.
 */
struct Zetas {
    int16_t z[128];
    int16_t f;       /* 2^-7 * 2^32 mod q, folded into the inverse NTT */
};

inline int16_t brv7(int i) {
    int r = 0;
    for (int b = 0; b < 7; ++b) r |= ((i >> b) & 1) << (6 - b);
    return static_cast<int16_t>(r);
}

inline const Zetas &zetas() {
    static Zetas t;
    static bool ready = false;
    if (!ready) {
        /* powers of the root, in Montgomery form: x -> x * 2^16 mod q */
        int32_t pow = 1;
        int32_t mont[128];
        for (int i = 0; i < 128; ++i) {
            mont[i] = (pow * 65536) % kQ;
            pow = (pow * kZetaRoot) % kQ;
        }
        for (int i = 0; i < 128; ++i) {
            int32_t v = mont[brv7(i)];
            if (v > kQ / 2) v -= kQ;
            t.z[i] = static_cast<int16_t>(v);
        }
        /* 1441 = 2^-7 * 2^32 mod q, the constant the reference folds in
         * so that the inverse transform ends in Montgomery form */
        t.f = 1441;
        ready = true;
    }
    return t;
}

/* The forward transform: seven layers, stopping at degree-one base
 * cases. ML-KEM's X^256+1 does not split completely over Z_q, which is
 * why there is no eighth layer and why multiplication needs basemul
 * rather than a coefficientwise product. */
inline void ntt(int16_t r[256]) {
    const Zetas &Z = zetas();
    unsigned int k = 1;
    for (int len = 128; len >= 2; len >>= 1) {
        for (int start = 0; start < 256; start = start + 2 * len) {
            const int16_t zeta = Z.z[k++];
            for (int j = start; j < start + len; ++j) {
                const int16_t t = montgomery_reduce(
                    static_cast<int32_t>(zeta) * r[j + len]);
                r[j + len] = static_cast<int16_t>(r[j] - t);
                r[j] = static_cast<int16_t>(r[j] + t);
            }
        }
    }
    for (int i = 0; i < 256; ++i) r[i] = barrett_reduce(r[i]);
}

inline void invntt(int16_t r[256]) {
    const Zetas &Z = zetas();
    unsigned int k = 127;
    for (int len = 2; len <= 128; len <<= 1) {
        for (int start = 0; start < 256; start = start + 2 * len) {
            const int16_t zeta = Z.z[k--];
            for (int j = start; j < start + len; ++j) {
                const int16_t t = r[j];
                r[j] = barrett_reduce(
                    static_cast<int16_t>(t + r[j + len]));
                r[j + len] = static_cast<int16_t>(r[j + len] - t);
                r[j + len] = montgomery_reduce(
                    static_cast<int32_t>(zeta) * r[j + len]);
            }
        }
    }
    for (int i = 0; i < 256; ++i) {
        r[i] = montgomery_reduce(static_cast<int32_t>(Z.f) * r[i]);
    }
}

/* One degree-one base case: (a0 + a1 X)(b0 + b1 X) mod (X^2 - zeta). */
inline void basemul(int16_t r[2], const int16_t a[2], const int16_t b[2],
                    int16_t zeta) {
    r[0] = montgomery_reduce(static_cast<int32_t>(a[1]) * b[1]);
    r[0] = montgomery_reduce(static_cast<int32_t>(r[0]) * zeta);
    r[0] = static_cast<int16_t>(
        r[0] + montgomery_reduce(static_cast<int32_t>(a[0]) * b[0]));
    r[1] = montgomery_reduce(static_cast<int32_t>(a[0]) * b[1]);
    r[1] = static_cast<int16_t>(
        r[1] + montgomery_reduce(static_cast<int32_t>(a[1]) * b[0]));
}

inline void poly_basemul(int16_t r[256], const int16_t a[256],
                         const int16_t b[256]) {
    const Zetas &Z = zetas();
    for (int i = 0; i < 64; ++i) {
        basemul(&r[4 * i], &a[4 * i], &b[4 * i], Z.z[64 + i]);
        basemul(&r[4 * i + 2], &a[4 * i + 2], &b[4 * i + 2],
                static_cast<int16_t>(-Z.z[64 + i]));
    }
}

}  // namespace rmbl_mlkem_core

#endif
