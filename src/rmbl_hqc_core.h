#ifndef RMBL_HQC_CORE_H
#define RMBL_HQC_CORE_H

/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * HQC-KEM (Hamming Quasi-Cyclic), the code-based key encapsulation NIST
 * selected in March 2025 for standardisation beside ML-KEM. This follows
 * the HQC specification of 2025-08-22 and is byte-for-byte the scheme of
 * the authors' reference implementation v5.0.0 (public domain,
 * https://gitlab.com/pqc-hqc/hqc): every one of the 300 official
 * known-answer vectors (100 per parameter set) is reproduced exactly.
 * NIST's FIPS 207 draft may still change sizes (it proposes a 32-byte
 * seed-only decapsulation key); when it is final this file follows it.
 *
 * Where this differs from the reference, it differs on purpose:
 *
 *  - Byte order is explicit. The reference copies bytes straight into
 *    uint64_t words and so only works on little-endian machines; every
 *    load and store here goes through load_le/store_le.
 *  - The secret-dependent work is branch-free and has no secret-indexed
 *    memory access: the duplicate check of the rejection sampler, the
 *    Reed-Muller peak search and the implicit-rejection select all use
 *    masks, and the select sits behind an optimisation barrier so a
 *    compiler cannot turn it back into a branch.
 *  - Polynomial multiplication over GF(2) is Karatsuba down to a 64x64
 *    carry-less product. Portable builds use the constant-time "multiply
 *    with holes" product (integer multiplies of bit-masked operands, as in
 *    BearSSL); x86-64 uses PCLMULQDQ when the CPU has it (chosen at run
 *    time) and ARMv8 uses PMULL when the compiler targets the crypto
 *    extension. All three give identical bits.
 *  - Every secret intermediate is wiped, including the re-encrypted
 *    ciphertext of decapsulation, which is derived from the decrypted
 *    message.
 *
 * The layout of the parts:
 *   GF(2^8)            the field of the Reed-Solomon code (poly 0x11D)
 *   gf2x               multiplication in GF(2)[x]/(x^n - 1)
 *   sampling           SampleVect, SampleFixedWeightVect$ (rejection) and
 *                      SampleFixedWeightVect (Sendrier's Algorithm 5)
 *   Reed-Muller        RM(1,7), duplicated, decoded by Hadamard transform
 *   Reed-Solomon       shortened RS over GF(256), Berlekamp + additive FFT
 *   PKE / KEM          HQC-PKE and the salted FO transform with implicit
 *                      rejection
 */

#include <cstddef>
#include <cstdint>
#include <cstring>

#if defined(__x86_64__) && (defined(__GNUC__) || defined(__clang__))
#include <immintrin.h>
#define RMBL_HQC_X86_PCLMUL 1
#endif
#if defined(__aarch64__) && defined(__ARM_FEATURE_AES)
#include <arm_neon.h>
#define RMBL_HQC_ARM_PMULL 1
#endif

/* the FIPS 202 sponge from rmbl_keccak.cpp */
#ifndef RMBL_KECCAK_DECLARED
#define RMBL_KECCAK_DECLARED
struct RmblKeccak {
    uint64_t s[25];
    size_t rate;
    unsigned char pad;
    size_t pos;
    bool squeezing;
};
extern "C" void rmbl_keccak_init(RmblKeccak *, size_t, unsigned char);
extern "C" void rmbl_keccak_absorb(RmblKeccak *, const unsigned char *, size_t);
extern "C" void rmbl_keccak_finalize(RmblKeccak *);
extern "C" void rmbl_keccak_squeeze(RmblKeccak *, unsigned char *, size_t);
#endif

/* Constant-time testing hook: a test build defines this to tell a checker
 * (valgrind memcheck, ctgrind-style) that a value derived from a secret is
 * allowed to be public. It is used at exactly the two places the
 * specification accepts a leak: the rejection test of the keygen sampler (a
 * public criterion on unused randomness) and the fact that a draw repeated
 * an earlier position. Everywhere else a secret never reaches a branch or an
 * address. */
#ifndef RMBL_HQC_DECLASSIFY
#define RMBL_HQC_DECLASSIFY(ptr, len) ((void)0)
#endif

namespace rmbl_hqc {

/* ------------------------------------------------------------ helpers */

/* wipe that the optimiser cannot drop */
inline void wipe(void *p, size_t n) {
    volatile unsigned char *q = static_cast<volatile unsigned char *>(p);
    while (n--) *q++ = 0;
}

/* an opaque copy: stops the compiler from reasoning about a mask */
inline uint64_t barrier(uint64_t x) {
#if defined(__GNUC__) || defined(__clang__)
    __asm__ volatile("" : "+r"(x));
    return x;
#else
    volatile uint64_t y = x;
    return y;
#endif
}

inline uint64_t load_le64(const uint8_t *p, size_t n = 8) {
    uint64_t v = 0;
    for (size_t i = 0; i < n; ++i) v |= static_cast<uint64_t>(p[i]) << (8 * i);
    return v;
}
inline void store_le64(uint8_t *p, uint64_t v, size_t n = 8) {
    for (size_t i = 0; i < n; ++i) p[i] = static_cast<uint8_t>(v >> (8 * i));
}
/* bytes -> words, little-endian, the last word zero-padded */
inline void bytes_to_words(uint64_t *w, size_t nw, const uint8_t *b, size_t nb) {
    for (size_t i = 0; i < nw; ++i) {
        size_t off = 8 * i;
        w[i] = off >= nb ? 0 : load_le64(b + off, nb - off < 8 ? nb - off : 8);
    }
}
inline void words_to_bytes(uint8_t *b, size_t nb, const uint64_t *w) {
    for (size_t off = 0, i = 0; off < nb; off += 8, ++i) store_le64(b + off, w[i], nb - off < 8 ? nb - off : 8);
}
/* 0xFF..FF when equal, constant time */
inline uint64_t ct_eq_mask(const uint8_t *a, const uint8_t *b, size_t n) {
    uint64_t d = 0;
    for (size_t i = 0; i < n; ++i) d |= static_cast<uint64_t>(a[i] ^ b[i]);
    /* d == 0 -> (0 - 1) >> 63 == 1 */
    return barrier(0 - ((d - 1) >> 63));
}

/* ------------------------------------------------------------ parameters */

constexpr size_t cdiv(size_t a, size_t b) { return (a + b - 1) / b; }

template <uint32_t N_, uint32_t N1_, uint32_t N2_, uint32_t W_, uint32_t WE_, uint32_t WR_, uint32_t K_,
          uint32_t DELTA_, uint32_t FFT_, uint64_t MU_, uint32_t THRESH_>
struct Params {
    static constexpr uint32_t N = N_;        /* length of the ambient space (a primitive prime) */
    static constexpr uint32_t N1 = N1_;      /* Reed-Solomon length */
    static constexpr uint32_t N2 = N2_;      /* duplicated Reed-Muller length */
    static constexpr uint32_t N1N2 = N1_ * N2_;
    static constexpr uint32_t W = W_;        /* weight of x, y */
    static constexpr uint32_t WE = WE_;      /* weight of e */
    static constexpr uint32_t WR = WR_;      /* weight of r1, r2 */
    static constexpr uint32_t K = K_;        /* message bytes = security bytes = RS dimension */
    static constexpr uint32_t DELTA = DELTA_; /* RS error-correcting capacity */
    static constexpr uint32_t G = 2 * DELTA_ + 1; /* RS generator polynomial coefficients */
    static constexpr uint32_t FFT = FFT_;    /* additive FFT size exponent */
    static constexpr uint64_t MU = MU_;      /* floor(2^32 / N), Barrett */
    static constexpr uint32_t THRESH = THRESH_; /* rejection threshold for 24-bit samples */
    static constexpr uint32_t MULT = N2_ / 128; /* copies of each RM(1,7) codeword */

    static constexpr size_t NW = cdiv(N_, 64);
    static constexpr size_t NBYTES = cdiv(N_, 8);
    static constexpr size_t N1N2W = cdiv(N1N2, 64);
    static constexpr size_t N1N2BYTES = cdiv(N1N2, 8);
    static constexpr size_t SEED = 32;
    static constexpr size_t SALT = 16;
    static constexpr size_t SS = 32;
    static constexpr size_t EK = SEED + NBYTES;
    static constexpr size_t DK = EK + SEED + K + SEED;
    static constexpr size_t CT = NBYTES + N1N2BYTES + SALT;
    static constexpr uint64_t TOPMASK = (N_ % 64) ? ((uint64_t(1) << (N_ % 64)) - 1) : ~uint64_t(0);
};

using HQC1 = Params<17669, 46, 384, 66, 75, 75, 16, 15, 4, 243079ULL, 16767881>;
using HQC3 = Params<35851, 56, 640, 100, 114, 114, 24, 16, 5, 119800ULL, 16742417>;
using HQC5 = Params<57637, 90, 640, 131, 149, 149, 32, 29, 5, 74517ULL, 16772367>;

static_assert(HQC1::EK == 2241 && HQC1::DK == 2321 && HQC1::CT == 4433, "HQC-1 sizes");
static_assert(HQC3::EK == 4514 && HQC3::DK == 4602 && HQC3::CT == 8978, "HQC-3 sizes");
static_assert(HQC5::EK == 7237 && HQC5::DK == 7333 && HQC5::CT == 14421, "HQC-5 sizes");
static_assert(HQC1::N1N2 % 64 == 0 && HQC3::N1N2 % 64 == 0 && HQC5::N1N2 % 64 == 0, "v fills whole words");

/* ------------------------------------------------------------ symmetric */

enum : uint8_t { DOM_PRNG = 0, DOM_XOF = 1 };
enum : uint8_t { DOM_G = 0, DOM_H = 1, DOM_I = 2, DOM_J = 3 };

/* SHAKE256 with HQC's XOF domain byte. get() reproduces a quirk of the
 * reference: a request that is not a multiple of 8 bytes squeezes the
 * rounded-up amount and drops the tail, which moves the stream position
 * (the KATs depend on it). */
struct Xof {
    RmblKeccak st;
    void init(const uint8_t *seed, size_t len, uint8_t domain = DOM_XOF) {
        rmbl_keccak_init(&st, 136, 0x1F);
        rmbl_keccak_absorb(&st, seed, len);
        rmbl_keccak_absorb(&st, &domain, 1);
        rmbl_keccak_finalize(&st);
    }
    void get(uint8_t *out, size_t len) {
        size_t rem = len % 8;
        rmbl_keccak_squeeze(&st, out, len - rem);
        if (rem) {
            uint8_t tmp[8];
            rmbl_keccak_squeeze(&st, tmp, 8);
            std::memcpy(out + len - rem, tmp, rem);
            wipe(tmp, sizeof tmp);
        }
    }
    void get_raw(uint8_t *out, size_t len) { rmbl_keccak_squeeze(&st, out, len); }
    ~Xof() { wipe(&st, sizeof st); }
};

/* SHA3-256 / SHA3-512 of the concatenated parts, then the domain byte */
inline void sha3_parts(uint8_t *out, size_t outlen, uint8_t domain, const uint8_t *const *parts,
                       const size_t *lens, size_t nparts) {
    RmblKeccak st;
    rmbl_keccak_init(&st, outlen == 32 ? 136 : 72, 0x06);
    for (size_t i = 0; i < nparts; ++i) rmbl_keccak_absorb(&st, parts[i], lens[i]);
    rmbl_keccak_absorb(&st, &domain, 1);
    rmbl_keccak_finalize(&st);
    rmbl_keccak_squeeze(&st, out, outlen);
    wipe(&st, sizeof st);
}

/* ------------------------------------------------------------ GF(2^8) */

namespace gf {

constexpr uint16_t POLY = 0x11D;

/* a * b mod POLY, constant time (no tables, no branches). The 15-bit
 * carry-less product comes from integer multiplies of operands with
 * three-bit holes (at most two partial products meet at a bit, so no carry
 * reaches the next one); x^8 = x^4 + x^3 + x^2 + 1 then folds the high
 * byte down twice. */
inline uint16_t mul(uint16_t a, uint16_t b) {
    const uint32_t m0 = 0x11, m1 = 0x22, m2 = 0x44, m3 = 0x88;
    uint32_t a0 = a & m0, a1 = a & m1, a2 = a & m2, a3 = a & m3;
    uint32_t b0 = b & m0, b1 = b & m1, b2 = b & m2, b3 = b & m3;
    const uint32_t k0 = 0x1111, k1 = 0x2222, k2 = 0x4444, k3 = 0x8888;
    uint32_t p = (((a0 * b0) ^ (a1 * b3) ^ (a2 * b2) ^ (a3 * b1)) & k0) |
                 (((a0 * b1) ^ (a1 * b0) ^ (a2 * b3) ^ (a3 * b2)) & k1) |
                 (((a0 * b2) ^ (a1 * b1) ^ (a2 * b0) ^ (a3 * b3)) & k2) |
                 (((a0 * b3) ^ (a1 * b2) ^ (a2 * b1) ^ (a3 * b0)) & k3);
    for (int pass = 0; pass < 2; ++pass) {
        uint32_t hi = p >> 8;
        p = (p & 0xFF) ^ hi ^ (hi << 2) ^ (hi << 3) ^ (hi << 4);
    }
    return static_cast<uint16_t>(p);
}
inline uint16_t square(uint16_t a) { return mul(a, a); }
/* a^254 = a^-1 (and 0 -> 0) */
inline uint16_t inverse(uint16_t a) {
    uint16_t a2 = square(a), a3 = mul(a2, a), a4 = square(a2), a7 = mul(a4, a3);
    uint16_t a11 = mul(a4, a7), a15 = mul(a11, a4);
    uint16_t t = square(square(square(a15))); /* a^120 */
    t = mul(t, a7);                           /* a^127 */
    return square(t);                         /* a^254 */
}

/* exp/log tables for PUBLIC indices only (generator polynomial, syndrome
 * powers, FFT bookkeeping); secret operands always go through mul(). */
struct Tables {
    uint16_t exp[258];
    uint16_t log[256];
};
constexpr Tables make_tables() {
    Tables t{};
    uint16_t elt = 1;
    for (int i = 0; i < 255; ++i) {
        t.exp[i] = elt;
        t.log[elt] = static_cast<uint16_t>(i);
        elt = static_cast<uint16_t>(elt << 1);
        if (elt & 0x100) elt ^= POLY;
    }
    t.exp[255] = 1;
    t.exp[256] = 2;
    t.exp[257] = 4;
    t.log[0] = 0;
    return t;
}
constexpr Tables T = make_tables();

} // namespace gf

/* ------------------------------------------------------------ GF(2)[x] */

namespace gf2x {

/* constant-time 64x64 -> low 64 bits of the carry-less product: integer
 * multiplies of operands with three-bit holes. At output bit p < 60 at most
 * 15 partial products meet, which fits the hole; 16 can only meet at
 * p >= 60, whose carry leaves the word. */
inline uint64_t bmul64(uint64_t x, uint64_t y) {
    const uint64_t m0 = 0x1111111111111111ULL, m1 = m0 << 1, m2 = m0 << 2, m3 = m0 << 3;
    uint64_t x0 = x & m0, x1 = x & m1, x2 = x & m2, x3 = x & m3;
    uint64_t y0 = y & m0, y1 = y & m1, y2 = y & m2, y3 = y & m3;
    uint64_t z0 = (x0 * y0) ^ (x1 * y3) ^ (x2 * y2) ^ (x3 * y1);
    uint64_t z1 = (x0 * y1) ^ (x1 * y0) ^ (x2 * y3) ^ (x3 * y2);
    uint64_t z2 = (x0 * y2) ^ (x1 * y1) ^ (x2 * y0) ^ (x3 * y3);
    uint64_t z3 = (x0 * y3) ^ (x1 * y2) ^ (x2 * y1) ^ (x3 * y0);
    return (z0 & m0) | (z1 & m1) | (z2 & m2) | (z3 & m3);
}
inline uint64_t rev64(uint64_t x) {
    x = ((x & 0x5555555555555555ULL) << 1) | ((x >> 1) & 0x5555555555555555ULL);
    x = ((x & 0x3333333333333333ULL) << 2) | ((x >> 2) & 0x3333333333333333ULL);
    x = ((x & 0x0F0F0F0F0F0F0F0FULL) << 4) | ((x >> 4) & 0x0F0F0F0F0F0F0F0FULL);
    x = ((x & 0x00FF00FF00FF00FFULL) << 8) | ((x >> 8) & 0x00FF00FF00FF00FFULL);
    x = ((x & 0x0000FFFF0000FFFFULL) << 16) | ((x >> 16) & 0x0000FFFF0000FFFFULL);
    return (x << 32) | (x >> 32);
}
/* the full 128-bit product: the high half from the bit-reversed operands */
inline void clmul_portable(uint64_t a, uint64_t b, uint64_t *lo, uint64_t *hi) {
    *lo = bmul64(a, b);
    *hi = rev64(bmul64(rev64(a), rev64(b))) >> 1;
}

/* Karatsuba over words; the base case is a schoolbook of carry-less
 * products. tmp needs 8 * n words. The recursion and its shape depend only
 * on n, never on the data. Generated twice by the macro below: once with the
 * portable product and, on x86-64, once compiled for PCLMULQDQ. */
#define RMBL_HQC_KARATSUBA(NAME, ATTR, CLMUL, CUT)                                               \
    ATTR static void NAME##_school(uint64_t *r, const uint64_t *a, const uint64_t *b, size_t n) { \
        for (size_t i = 0; i < 2 * n; ++i) r[i] = 0;                                         \
        for (size_t i = 0; i < n; ++i) {                                                      \
            for (size_t j = 0; j < n; ++j) {                                                  \
                uint64_t lo, hi;                                                              \
                CLMUL(a[i], b[j], &lo, &hi);                                                  \
                r[i + j] ^= lo;                                                               \
                r[i + j + 1] ^= hi;                                                           \
            }                                                                                 \
        }                                                                                     \
    }                                                                                         \
    ATTR static void NAME(uint64_t *r, const uint64_t *a, const uint64_t *b, size_t n, uint64_t *tmp) { \
        if (n <= CUT) {                                                                       \
            NAME##_school(r, a, b, n);                                                        \
            return;                                                                           \
        }                                                                                     \
        size_t m = n >> 1, n0 = m, n1 = n - m;                                                \
        uint64_t *z0 = tmp, *z2 = z0 + 2 * n, *zm = z2 + 2 * n, *ta = zm + 2 * n, *tb = ta + n; \
        uint64_t *child = tmp + 8 * n;                                                        \
        NAME(z0, a, b, n0, child);                                                            \
        NAME(z2, a + m, b + m, n1, child);                                                    \
        for (size_t i = 0; i < n1; ++i) {                                                     \
            ta[i] = (i < n0 ? a[i] : 0) ^ a[m + i];                                           \
            tb[i] = (i < n0 ? b[i] : 0) ^ b[m + i];                                           \
        }                                                                                     \
        NAME(zm, ta, tb, n1, child);                                                          \
        for (size_t i = 0; i < 2 * n; ++i) r[i] = 0;                                          \
        for (size_t i = 0; i < 2 * n0; ++i) r[i] ^= z0[i];                                    \
        for (size_t i = 0; i < 2 * n1; ++i) r[2 * m + i] ^= z2[i];                            \
        for (size_t i = 0; i < 2 * n1; ++i) {                                                 \
            uint64_t z0i = i < 2 * n0 ? z0[i] : 0;                                            \
            r[m + i] ^= zm[i] ^ z0i ^ z2[i];                                                  \
        }                                                                                     \
    }

/* cut-offs measured on x86-64: a portable product costs ~60 cycles, so
 * Karatsuba pays all the way down to single words; PCLMULQDQ is one cycle,
 * so a 16-word schoolbook beats the bookkeeping of further splitting */
RMBL_HQC_KARATSUBA(karatsuba_portable, , clmul_portable, 1)

#if defined(RMBL_HQC_X86_PCLMUL)
__attribute__((target("pclmul,sse2"))) static inline void clmul_x86(uint64_t a, uint64_t b, uint64_t *lo,
                                                                    uint64_t *hi) {
    __m128i p = _mm_clmulepi64_si128(_mm_cvtsi64_si128(static_cast<long long>(a)),
                                     _mm_cvtsi64_si128(static_cast<long long>(b)), 0x00);
    *lo = static_cast<uint64_t>(_mm_cvtsi128_si64(p));
    *hi = static_cast<uint64_t>(_mm_cvtsi128_si64(_mm_srli_si128(p, 8)));
}
RMBL_HQC_KARATSUBA(karatsuba_x86, __attribute__((target("pclmul,sse2"))), clmul_x86, 16)

inline bool have_pclmul() {
    static const int ok = __builtin_cpu_supports("pclmul") ? 1 : 0;
    return ok != 0;
}
#endif

#if defined(RMBL_HQC_ARM_PMULL)
static inline void clmul_arm(uint64_t a, uint64_t b, uint64_t *lo, uint64_t *hi) {
    poly128_t p = vmull_p64(static_cast<poly64_t>(a), static_cast<poly64_t>(b));
    uint64x2_t v = vreinterpretq_u64_p128(p);
    *lo = vgetq_lane_u64(v, 0);
    *hi = vgetq_lane_u64(v, 1);
}
RMBL_HQC_KARATSUBA(karatsuba_arm, , clmul_arm, 16)
#endif

/* set to 1 to force the portable product (tests compare the paths) */
inline int &force_portable() {
    static int f = 0;
    return f;
}

inline void karatsuba(uint64_t *r, const uint64_t *a, const uint64_t *b, size_t n, uint64_t *tmp) {
#if defined(RMBL_HQC_X86_PCLMUL)
    if (!force_portable() && have_pclmul()) {
        karatsuba_x86(r, a, b, n, tmp);
        return;
    }
#endif
#if defined(RMBL_HQC_ARM_PMULL)
    if (!force_portable()) {
        karatsuba_arm(r, a, b, n, tmp);
        return;
    }
#endif
    karatsuba_portable(r, a, b, n, tmp);
}

/* the scratch the recursion needs: 8n at each level, n halving (sized for
 * the smallest cut-off, so it covers every path) */
constexpr size_t scratch_words(size_t n) { return n <= 1 ? 0 : 8 * n + scratch_words(n - n / 2); }

/* o = a * b mod (x^N - 1) */
template <class P>
inline void mul(uint64_t *o, const uint64_t *a, const uint64_t *b) {
    static constexpr size_t NW = P::NW;
    uint64_t prod[2 * NW];
    uint64_t tmp[scratch_words(NW) + 1];
    karatsuba(prod, a, b, NW, tmp);
    constexpr unsigned s = P::N % 64;
    for (size_t i = 0; i < NW; ++i) {
        uint64_t r = prod[i + NW - 1] >> s;
        uint64_t carry = prod[i + NW] << (64 - s);
        o[i] = prod[i] ^ r ^ carry;
    }
    o[NW - 1] &= P::TOPMASK;
    wipe(prod, sizeof prod);
    wipe(tmp, sizeof tmp);
}
static_assert(HQC1::N % 64 != 0 && HQC3::N % 64 != 0 && HQC5::N % 64 != 0, "the reduction shifts by N mod 64");

} // namespace gf2x

/* ------------------------------------------------------------ sampling */

namespace sample {

/* x mod N for x < 2^24, constant time */
template <class P>
inline uint32_t barrett(uint32_t x) {
    uint64_t q = (static_cast<uint64_t>(x) * P::MU) >> 32;
    uint32_t r = x - static_cast<uint32_t>(q * P::N);
    uint32_t ge = ((r - P::N) >> 31) ^ 1; /* r >= N */
    return r - ((0u - ge) & P::N);
}

/* 1 << k for a secret k < 64 without a variable shift: six fixed shifts
 * chosen by masks (a shift by a secret count is constant time on common
 * cores but not on every one, and a checker cannot tell them apart) */
inline uint64_t onehot64(uint32_t k) {
    uint64_t b = 1;
    for (unsigned i = 0; i < 6; ++i) {
        uint64_t sel = 0 - static_cast<uint64_t>((k >> i) & 1u);
        b = (b & ~sel) | ((b << (1u << i)) & sel);
    }
    return b;
}

/* support -> vector, constant time in the (secret) positions */
template <class P>
inline void write_support(uint64_t *v, const uint32_t *support, size_t weight) {
    for (size_t i = 0; i < P::NW; ++i) v[i] = 0;
    for (size_t j = 0; j < weight; ++j) {
        const uint32_t word = support[j] >> 6;
        const uint64_t bit = onehot64(support[j] & 63);
        for (size_t i = 0; i < P::NW; ++i) {
            uint32_t d = static_cast<uint32_t>(i) ^ word;
            uint64_t eq = 0 - static_cast<uint64_t>(1 ^ ((d | (0u - d)) >> 31));
            v[i] |= bit & eq;
        }
    }
}

/* SampleFixedWeightVect$: uniform positions by 24-bit rejection sampling.
 * Only rejected (public-criterion) samples and the fact that a draw
 * repeated an earlier position change the timing. */
template <class P>
inline void fixed_weight_uniform(Xof &ctx, uint64_t *v, size_t weight) {
    uint32_t support[P::WR > P::W ? P::WR : P::W] = {0};
    uint8_t buf[3 * (P::WR > P::W ? P::WR : P::W)];
    const size_t blen = 3 * weight;
    size_t i = 0, j = blen;
    while (i < weight) {
        uint32_t s;
        bool rejected;
        do {
            if (j == blen) {
                ctx.get(buf, blen);
                j = 0;
            }
            s = (static_cast<uint32_t>(buf[j]) << 16) | (static_cast<uint32_t>(buf[j + 1]) << 8) | buf[j + 2];
            j += 3;
            rejected = s >= P::THRESH;
            RMBL_HQC_DECLASSIFY(&rejected, sizeof rejected);
        } while (rejected);
        s = barrett<P>(s);
        uint32_t dup = 0;
        for (size_t k = 0; k < i; ++k) {
            uint32_t d = support[k] ^ s;
            dup |= 1 ^ ((d | (0u - d)) >> 31);
        }
        support[i] = s;
        RMBL_HQC_DECLASSIFY(&dup, sizeof dup);
        i += 1 ^ dup;
    }
    write_support<P>(v, support, weight);
    wipe(support, sizeof support);
    wipe(buf, sizeof buf);
}

/* SampleFixedWeightVect: Sendrier's Algorithm 5 -- no rejection, a
 * constant-time collision repair */
template <class P>
inline void fixed_weight(Xof &ctx, uint64_t *v, size_t weight) {
    uint32_t support[P::WR] = {0};
    uint8_t buf[4 * P::WR];
    ctx.get(buf, 4 * weight);
    for (size_t i = 0; i < weight; ++i) {
        uint64_t r = load_le64(buf + 4 * i, 4);
        support[i] = static_cast<uint32_t>(i + ((r * (P::N - i)) >> 32));
    }
    for (size_t ii = weight - 1; ii-- > 0;) {
        uint32_t found = 0;
        for (size_t j = ii + 1; j < weight; ++j) {
            uint32_t d = support[j] ^ support[ii];
            found |= 1 ^ ((d | (0u - d)) >> 31);
        }
        uint32_t mask = 0u - found;
        support[ii] = (mask & static_cast<uint32_t>(ii)) ^ (~mask & support[ii]);
    }
    write_support<P>(v, support, weight);
    wipe(support, sizeof support);
    wipe(buf, sizeof buf);
}

/* SampleVect: a uniform vector of F_2^N (the public h) */
template <class P>
inline void uniform(Xof &ctx, uint64_t *v) {
    uint8_t buf[P::NBYTES];
    ctx.get(buf, P::NBYTES);
    bytes_to_words(v, P::NW, buf, P::NBYTES);
    v[P::NW - 1] &= P::TOPMASK;
}

} // namespace sample

/* ------------------------------------------------------------ Reed-Muller */

namespace rm {

/* RM(1,7) codeword of one byte, as two 64-bit words */
inline void encode_byte(uint64_t *w, uint8_t m) {
    auto bit = [m](int k) { return static_cast<uint32_t>(0u - ((m >> k) & 1u)); };
    uint32_t a = bit(7);
    a ^= bit(0) & 0xaaaaaaaau;
    a ^= bit(1) & 0xccccccccu;
    a ^= bit(2) & 0xf0f0f0f0u;
    a ^= bit(3) & 0xff00ff00u;
    a ^= bit(4) & 0xffff0000u;
    uint32_t u0 = a;
    a ^= bit(5);
    uint32_t u1 = a;
    a ^= bit(6);
    uint32_t u3 = a;
    a ^= bit(5);
    uint32_t u2 = a;
    w[0] = static_cast<uint64_t>(u0) | (static_cast<uint64_t>(u1) << 32);
    w[1] = static_cast<uint64_t>(u2) | (static_cast<uint64_t>(u3) << 32);
}

/* the duplicated code: byte i fills codewords i*MULT .. i*MULT+MULT-1 */
template <class P>
inline void encode(uint64_t *cdw, const uint8_t *msg) {
    for (size_t i = 0; i < P::N1; ++i) {
        uint64_t w[2];
        encode_byte(w, msg[i]);
        for (size_t c = 0; c < P::MULT; ++c) {
            size_t k = 2 * (i * P::MULT + c);
            cdw[k] = w[0];
            cdw[k + 1] = w[1];
        }
    }
}

/* soft decoding: sum the copies bitwise, Hadamard transform, take the peak.
 * All of it is constant time; the peak search keeps its running best with
 * masks rather than comparisons that a compiler may branch on. */
template <class P>
inline void decode(uint8_t *msg, const uint64_t *cdw) {
    for (size_t i = 0; i < P::N1; ++i) {
        int16_t e[128], t[128];
        for (int b = 0; b < 128; ++b) e[b] = 0;
        for (size_t c = 0; c < P::MULT; ++c) {
            size_t k = 2 * (i * P::MULT + c);
            for (int b = 0; b < 128; ++b) e[b] = static_cast<int16_t>(e[b] + ((cdw[k + (b >> 6)] >> (b & 63)) & 1));
        }
        int16_t *p1 = e, *p2 = t;
        for (int pass = 0; pass < 7; ++pass) {
            for (int q = 0; q < 64; ++q) {
                p2[q] = static_cast<int16_t>(p1[2 * q] + p1[2 * q + 1]);
                p2[q + 64] = static_cast<int16_t>(p1[2 * q] - p1[2 * q + 1]);
            }
            int16_t *s = p1;
            p1 = p2;
            p2 = s;
        }
        /* after 7 passes the transform is in p1 */
        p1[0] = static_cast<int16_t>(p1[0] - 64 * static_cast<int>(P::MULT));
        int32_t best_abs = 0, best_val = 0, best_pos = 0;
        for (int32_t q = 0; q < 128; ++q) {
            int32_t v = p1[q];
            int32_t neg = v >> 31;               /* -1 when v < 0 */
            int32_t av = (v ^ neg) - neg;        /* |v| */
            int32_t gt = (best_abs - av) >> 31;  /* -1 when av > best_abs */
            best_val = (gt & v) | (~gt & best_val);
            best_pos = (gt & q) | (~gt & best_pos);
            best_abs = (gt & av) | (~gt & best_abs);
        }
        int32_t pos = (0 - best_val) >> 31;      /* -1 when best_val > 0 */
        msg[i] = static_cast<uint8_t>(best_pos | (pos & 128));
        wipe(e, sizeof e);
        wipe(t, sizeof t);
    }
}

} // namespace rm

/* ------------------------------------------------------------ Reed-Solomon */

namespace rs {

/* generator polynomial prod_{i=1}^{2 delta} (x - alpha^i), from public
 * tables */
template <class P>
struct Gen {
    uint16_t g[P::G];
    constexpr Gen() : g() {
        g[0] = 1;
        uint32_t deg = 0;
        for (uint32_t i = 1; i < 2 * P::DELTA + 1; ++i) {
            for (uint32_t j = deg; j; --j) {
                uint16_t c = g[j] ? gf::T.exp[(gf::T.log[g[j]] + i) % 255] : 0;
                g[j] = static_cast<uint16_t>(c ^ g[j - 1]);
            }
            g[0] = g[0] ? gf::T.exp[(gf::T.log[g[0]] + i) % 255] : 0;
            g[++deg] = 1;
        }
    }
};

template <class P>
inline void encode(uint8_t *cdw, const uint8_t *msg) {
    static constexpr Gen<P> gen{};
    constexpr size_t R = P::N1 - P::K; /* redundancy = G - 1 */
    uint8_t b[P::N1] = {0};
    for (size_t i = 0; i < P::K; ++i) {
        uint8_t gate = static_cast<uint8_t>(msg[P::K - 1 - i] ^ b[R - 1]);
        uint16_t tmp[P::G];
        for (size_t j = 0; j < P::G; ++j) tmp[j] = gf::mul(gate, gen.g[j]);
        for (size_t k = R - 1; k; --k) b[k] = static_cast<uint8_t>(b[k - 1] ^ tmp[k]);
        b[0] = static_cast<uint8_t>(tmp[0]);
    }
    std::memcpy(b + R, msg, P::K);
    std::memcpy(cdw, b, P::N1);
    wipe(b, sizeof b);
}

/* syndromes S_i = sum_j c_j alpha^{(i+1) j}, i < 2 delta */
template <class P>
inline void syndromes(uint16_t *s, const uint8_t *c) {
    for (size_t i = 0; i < 2 * P::DELTA; ++i) {
        uint16_t acc = c[0];
        for (size_t j = 1; j < P::N1; ++j) acc ^= gf::mul(c[j], gf::T.exp[((i + 1) * j) % 255]);
        s[i] = acc;
    }
}

/* Berlekamp's error-locator polynomial, constant time (the reference's
 * simplified algorithm). Returns deg sigma. */
template <class P>
inline uint16_t elp(uint16_t *sigma, const uint16_t *syn) {
    constexpr uint16_t D = P::DELTA;
    uint16_t deg_sigma = 0, deg_sigma_p = 0, deg_sigma_copy;
    uint16_t sigma_copy[D + 1] = {0};
    uint16_t X_sigma_p[D + 1] = {0};
    X_sigma_p[1] = 1;
    uint16_t pp = static_cast<uint16_t>(-1);
    uint16_t d_p = 1;
    uint16_t d = syn[0];
    sigma[0] = 1;
    for (uint16_t mu = 0; mu < 2 * D; ++mu) {
        for (uint16_t i = 0; i < D; ++i) sigma_copy[i] = sigma[i];
        deg_sigma_copy = deg_sigma;
        uint16_t dd = gf::mul(d, gf::inverse(d_p));
        for (uint16_t i = 1; i <= mu + 1 && i <= D; ++i) sigma[i] ^= gf::mul(dd, X_sigma_p[i]);
        uint16_t deg_X = static_cast<uint16_t>(mu - pp);
        uint16_t deg_X_sigma_p = static_cast<uint16_t>(deg_X + deg_sigma_p);
        uint16_t mask1 = static_cast<uint16_t>(-(static_cast<uint16_t>(-d) >> 15));
        uint16_t mask2 = static_cast<uint16_t>(-(static_cast<uint16_t>(deg_sigma - deg_X_sigma_p) >> 15));
        uint16_t mask12 = static_cast<uint16_t>(barrier(mask1 & mask2));
        deg_sigma ^= mask12 & (deg_X_sigma_p ^ deg_sigma);
        if (mu == 2 * D - 1) break;
        pp ^= mask12 & (mu ^ pp);
        d_p ^= mask12 & (d ^ d_p);
        for (uint16_t i = D; i; --i) X_sigma_p[i] = (mask12 & sigma_copy[i - 1]) ^ (~mask12 & X_sigma_p[i - 1]);
        deg_sigma_p ^= mask12 & (deg_sigma_copy ^ deg_sigma_p);
        d = syn[mu + 1];
        for (uint16_t i = 1; i <= mu + 1 && i <= D; ++i) d ^= gf::mul(sigma[i], syn[mu + 1 - i]);
    }
    wipe(sigma_copy, sizeof sigma_copy);
    wipe(X_sigma_p, sizeof X_sigma_p);
    return deg_sigma;
}

/* ---- additive FFT over GF(2^8) (Gao-Mateer), for the roots of sigma ---- */
constexpr uint32_t M = 8;

inline void subset_sums(uint16_t *ss, const uint16_t *set, uint16_t n) {
    ss[0] = 0;
    for (uint16_t i = 0; i < n; ++i)
        for (uint16_t j = 0; j < (1 << i); ++j) ss[(1 << i) + j] = set[i] ^ ss[j];
}

template <uint32_t FFTP>
struct Fft {
    /* MAXMF bounds m_f at compile time (the caller's buffers hold
     * 2^(MAXMF-1) entries), so cases a call can never reach are not compiled */
    template <uint32_t MAXMF>
    static void radix(uint16_t *f0, uint16_t *f1, const uint16_t *f, uint32_t m_f) {
        switch (m_f) {
        case 4:
            if constexpr (MAXMF >= 4) {
            f0[4] = f[8] ^ f[12];
            f0[6] = f[12] ^ f[14];
            f0[7] = f[14] ^ f[15];
            f1[5] = f[11] ^ f[13];
            f1[6] = f[13] ^ f[14];
            f1[7] = f[15];
            f0[5] = f[10] ^ f[12] ^ f1[5];
            f1[4] = f[9] ^ f[13] ^ f0[5];
            f0[0] = f[0];
            f1[3] = f[7] ^ f[11] ^ f[15];
            f0[3] = f[6] ^ f[10] ^ f[14] ^ f1[3];
            f0[2] = f[4] ^ f0[4] ^ f0[3] ^ f1[3];
            f1[1] = f[3] ^ f[5] ^ f[9] ^ f[13] ^ f1[3];
            f1[2] = f[3] ^ f1[1] ^ f0[3];
            f0[1] = f[2] ^ f0[2] ^ f1[1];
            f1[0] = f[1] ^ f0[1];
            }
            break;
        case 3:
            f0[0] = f[0];
            f0[2] = f[4] ^ f[6];
            f0[3] = f[6] ^ f[7];
            f1[1] = f[3] ^ f[5] ^ f[7];
            f1[2] = f[5] ^ f[6];
            f1[3] = f[7];
            f0[1] = f[2] ^ f0[2] ^ f1[1];
            f1[0] = f[1] ^ f0[1];
            break;
        case 2:
            f0[0] = f[0];
            f0[1] = f[2] ^ f[3];
            f1[0] = f[1] ^ f0[1];
            f1[1] = f[3];
            break;
        /* no m_f = 1 case: rec() evaluates a degree-1 polynomial directly and
         * never asks for that split, and run() and radix_big() start at 4 */
        default:
            /* only the 32-point FFT (HQC-3/5) splits further; for HQC-1 this
             * path cannot run and is not compiled */
            if constexpr (MAXMF >= 5) radix_big(f0, f1, f, m_f);
            break;
        }
    }
    static void radix_big(uint16_t *f0, uint16_t *f1, const uint16_t *f, uint32_t m_f) {
        uint16_t Q[2 * (1 << (FFTP - 2)) + 1] = {0};
        uint16_t R[2 * (1 << (FFTP - 2)) + 1] = {0};
        uint16_t Q0[1 << (FFTP - 2)] = {0}, Q1[1 << (FFTP - 2)] = {0};
        uint16_t R0[1 << (FFTP - 2)] = {0}, R1[1 << (FFTP - 2)] = {0};
        size_t n = size_t(1) << (m_f - 2);
        std::memcpy(Q, f + 3 * n, 2 * n);
        std::memcpy(Q + n, f + 3 * n, 2 * n);
        std::memcpy(R, f, 4 * n);
        for (size_t i = 0; i < n; ++i) {
            Q[i] ^= f[2 * n + i];
            R[n + i] ^= Q[i];
        }
        radix<FFTP - 1>(Q0, Q1, Q, m_f - 1);
        radix<FFTP - 1>(R0, R1, R, m_f - 1);
        std::memcpy(f0, R0, 2 * n);
        std::memcpy(f0 + n, Q0, 2 * n);
        std::memcpy(f1, R1, 2 * n);
        std::memcpy(f1 + n, Q1, 2 * n);
        wipe(Q, sizeof Q);
        wipe(R, sizeof R);
        wipe(Q0, sizeof Q0);
        wipe(Q1, sizeof Q1);
        wipe(R0, sizeof R0);
        wipe(R1, sizeof R1);
    }
    static void rec(uint16_t *w, uint16_t *f, size_t f_coeffs, uint8_t m, uint32_t m_f, const uint16_t *betas) {
        uint16_t f0[1 << (FFTP - 2)] = {0}, f1[1 << (FFTP - 2)] = {0};
        uint16_t gammas[M - 2] = {0}, deltas[M - 2] = {0};
        uint16_t gammas_sums[1 << (M - 2)] = {0};
        uint16_t u[1 << (M - 2)] = {0}, v[1 << (M - 2)] = {0};
        uint16_t tmp[M - (FFTP - 1)] = {0};
        if (m_f == 1) {
            for (size_t i = 0; i < m; ++i) tmp[i] = gf::mul(betas[i], f[1]);
            w[0] = f[0];
            size_t x = 1;
            for (size_t j = 0; j < m; ++j) {
                for (size_t k = 0; k < x; ++k) w[x + k] = w[k] ^ tmp[j];
                x <<= 1;
            }
            wipe(tmp, sizeof tmp);
            return;
        }
        if (betas[m - 1] != 1) { /* public */
            uint16_t bp = 1;
            size_t x = size_t(1) << m_f;
            for (size_t i = 1; i < x; ++i) {
                bp = gf::mul(bp, betas[m - 1]);
                f[i] = gf::mul(bp, f[i]);
            }
        }
        radix<FFTP - 1>(f0, f1, f, m_f);
        for (size_t i = 0; i + 1 < m; ++i) {
            gammas[i] = gf::mul(betas[i], gf::inverse(betas[m - 1]));
            deltas[i] = gf::square(gammas[i]) ^ gammas[i];
        }
        subset_sums(gammas_sums, gammas, static_cast<uint16_t>(m - 1));
        rec(u, f0, (f_coeffs + 1) / 2, static_cast<uint8_t>(m - 1), m_f - 1, deltas);
        size_t k = size_t(1) << ((m - 1) & 0xf);
        if (f_coeffs <= 3) {
            w[0] = u[0];
            w[k] = u[0] ^ f1[0];
            for (size_t i = 1; i < k; ++i) {
                w[i] = u[i] ^ gf::mul(gammas_sums[i], f1[0]);
                w[k + i] = w[i] ^ f1[0];
            }
        } else {
            rec(v, f1, f_coeffs / 2, static_cast<uint8_t>(m - 1), m_f - 1, deltas);
            std::memcpy(w + k, v, 2 * k);
            w[0] = u[0];
            w[k] ^= u[0];
            for (size_t i = 1; i < k; ++i) {
                w[i] = u[i] ^ gf::mul(gammas_sums[i], v[i]);
                w[k + i] ^= w[i];
            }
        }
        wipe(f0, sizeof f0);
        wipe(f1, sizeof f1);
        wipe(u, sizeof u);
        wipe(v, sizeof v);
    }
    static void betas_of(uint16_t *b) {
        for (size_t i = 0; i < M - 1; ++i) b[i] = static_cast<uint16_t>(1 << (M - 1 - i));
    }
    /* w = sigma evaluated over the field, in the FFT's order */
    static void run(uint16_t *w, const uint16_t *f_in, size_t f_coeffs) {
        uint16_t f[1 << FFTP];
        std::memcpy(f, f_in, sizeof f);
        uint16_t betas[M - 1] = {0}, betas_sums[1 << (M - 1)] = {0};
        uint16_t f0[1 << (FFTP - 1)] = {0}, f1[1 << (FFTP - 1)] = {0};
        uint16_t deltas[M - 1] = {0};
        uint16_t u[1 << (M - 1)] = {0}, v[1 << (M - 1)] = {0};
        betas_of(betas);
        subset_sums(betas_sums, betas, M - 1);
        radix<FFTP>(f0, f1, f, FFTP);
        for (size_t i = 0; i < M - 1; ++i) deltas[i] = gf::square(betas[i]) ^ betas[i];
        rec(u, f0, (f_coeffs + 1) / 2, M - 1, FFTP - 1, deltas);
        rec(v, f1, f_coeffs / 2, M - 1, FFTP - 1, deltas);
        size_t k = size_t(1) << (M - 1);
        std::memcpy(w + k, v, 2 * k);
        w[0] = u[0];
        w[k] ^= u[0];
        for (size_t i = 1; i < k; ++i) {
            w[i] = u[i] ^ gf::mul(betas_sums[i], v[i]);
            w[k + i] ^= w[i];
        }
        wipe(f, sizeof f);
        wipe(f0, sizeof f0);
        wipe(f1, sizeof f1);
        wipe(u, sizeof u);
        wipe(v, sizeof v);
    }
    /* error[j] = 1 where alpha^-j... is a root; positions are public */
    static void error_poly(uint8_t *error, const uint16_t *w) {
        uint16_t gammas[M - 1] = {0}, gammas_sums[1 << (M - 1)] = {0};
        betas_of(gammas);
        subset_sums(gammas_sums, gammas, M - 1);
        size_t k = size_t(1) << (M - 1);
        error[0] ^= static_cast<uint8_t>(1 ^ (static_cast<uint16_t>(-w[0]) >> 15));
        error[0] ^= static_cast<uint8_t>(1 ^ (static_cast<uint16_t>(-w[k]) >> 15));
        for (size_t i = 1; i < k; ++i) {
            size_t idx = 255 - gf::T.log[gammas_sums[i]];
            error[idx] ^= static_cast<uint8_t>(1 ^ (static_cast<uint16_t>(-w[i]) >> 15));
            idx = 255 - gf::T.log[gammas_sums[i] ^ 1];
            error[idx] ^= static_cast<uint8_t>(1 ^ (static_cast<uint16_t>(-w[k + i]) >> 15));
        }
    }
};

template <class P>
inline void z_poly(uint16_t *z, const uint16_t *sigma, uint16_t degree, const uint16_t *syn) {
    z[0] = 1;
    for (size_t i = 1; i < P::DELTA + 1; ++i) {
        uint16_t mask = static_cast<uint16_t>(-(static_cast<uint16_t>(i - degree - 1) >> 15));
        z[i] = mask & sigma[i];
    }
    z[1] ^= syn[0];
    for (size_t i = 2; i <= P::DELTA; ++i) {
        uint16_t mask = static_cast<uint16_t>(-(static_cast<uint16_t>(i - degree - 1) >> 15));
        z[i] ^= mask & syn[i - 1];
        for (size_t j = 1; j < i; ++j) z[i] ^= mask & gf::mul(sigma[j], syn[i - j - 1]);
    }
}

template <class P>
inline void error_values(uint16_t *ev, const uint16_t *z, const uint8_t *error) {
    constexpr size_t D = P::DELTA;
    uint16_t beta_j[D] = {0}, e_j[D] = {0};
    uint16_t cnt = 0;
    for (size_t i = 0; i < P::N1; ++i) {
        uint16_t found = 0;
        uint16_t m1 = static_cast<uint16_t>(-static_cast<int32_t>(error[i]) >> 31);
        for (size_t j = 0; j < D; ++j) {
            uint16_t m2 = static_cast<uint16_t>(~static_cast<uint16_t>(-static_cast<int32_t>(j ^ cnt) >> 31));
            beta_j[j] = static_cast<uint16_t>(beta_j[j] + (m1 & m2 & gf::T.exp[i]));
            found = static_cast<uint16_t>(found + (m1 & m2 & 1));
        }
        cnt = static_cast<uint16_t>(cnt + found);
    }
    const uint16_t real = cnt;
    for (size_t i = 0; i < D; ++i) {
        uint16_t t1 = 1, t2 = 1;
        uint16_t inv = gf::inverse(beta_j[i]);
        uint16_t invp = 1;
        for (size_t j = 1; j <= D; ++j) {
            invp = gf::mul(invp, inv);
            t1 ^= gf::mul(invp, z[j]);
        }
        for (size_t k = 1; k < D; ++k) t2 = gf::mul(t2, static_cast<uint16_t>(1 ^ gf::mul(inv, beta_j[(i + k) % D])));
        uint16_t m1 = static_cast<uint16_t>((static_cast<int16_t>(i) - static_cast<int16_t>(real)) >> 15);
        e_j[i] = m1 & gf::mul(t1, gf::inverse(t2));
    }
    cnt = 0;
    for (size_t i = 0; i < P::N1; ++i) {
        uint16_t found = 0;
        uint16_t m1 = static_cast<uint16_t>(-static_cast<int32_t>(error[i]) >> 31);
        for (size_t j = 0; j < D; ++j) {
            uint16_t m2 = static_cast<uint16_t>(~static_cast<uint16_t>(-static_cast<int32_t>(j ^ cnt) >> 31));
            ev[i] = static_cast<uint16_t>(ev[i] + (m1 & m2 & e_j[j]));
            found = static_cast<uint16_t>(found + (m1 & m2 & 1));
        }
        cnt = static_cast<uint16_t>(cnt + found);
    }
    wipe(beta_j, sizeof beta_j);
    wipe(e_j, sizeof e_j);
}

template <class P>
inline void decode(uint8_t *msg, const uint8_t *cdw_in) {
    uint8_t c[P::N1];
    std::memcpy(c, cdw_in, P::N1);
    uint16_t syn[2 * P::DELTA] = {0};
    uint16_t sigma[1 << P::FFT] = {0};
    uint8_t error[1 << M] = {0};
    uint16_t z[P::N1] = {0};
    uint16_t ev[P::N1] = {0};
    uint16_t w[1 << M] = {0};
    syndromes<P>(syn, c);
    uint16_t deg = elp<P>(sigma, syn);
    Fft<P::FFT>::run(w, sigma, P::DELTA + 1);
    Fft<P::FFT>::error_poly(error, w);
    z_poly<P>(z, sigma, deg, syn);
    error_values<P>(ev, z, error);
    for (size_t i = 0; i < P::N1; ++i) c[i] = static_cast<uint8_t>(c[i] ^ ev[i]);
    std::memcpy(msg, c + (P::G - 1), P::K);
    wipe(c, sizeof c);
    wipe(syn, sizeof syn);
    wipe(sigma, sizeof sigma);
    wipe(error, sizeof error);
    wipe(z, sizeof z);
    wipe(ev, sizeof ev);
    wipe(w, sizeof w);
}

} // namespace rs

/* ------------------------------------------------------------ HQC-PKE */

template <class P>
struct Scheme {
    static constexpr size_t NW = P::NW;

    /* (seed_dk, seed_ek) = I(seed_pke) */
    static void hash_i(uint8_t out[64], const uint8_t seed[32]) {
        const uint8_t *parts[1] = {seed};
        size_t lens[1] = {32};
        sha3_parts(out, 64, DOM_I, parts, lens, 1);
    }
    static void hash_h(uint8_t out[32], const uint8_t *ek) {
        const uint8_t *parts[1] = {ek};
        size_t lens[1] = {P::EK};
        sha3_parts(out, 32, DOM_H, parts, lens, 1);
    }
    static void hash_g(uint8_t out[64], const uint8_t hek[32], const uint8_t *m, const uint8_t *salt) {
        const uint8_t *parts[3] = {hek, m, salt};
        size_t lens[3] = {32, P::K, P::SALT};
        sha3_parts(out, 64, DOM_G, parts, lens, 3);
    }
    static void hash_j(uint8_t out[32], const uint8_t hek[32], const uint8_t *sigma, const uint8_t *ct) {
        const uint8_t *parts[3] = {hek, sigma, ct};
        size_t lens[3] = {32, P::K, P::CT};
        sha3_parts(out, 32, DOM_J, parts, lens, 3);
    }

    static void secret_y(uint64_t *y, const uint8_t seed_dk[32]) {
        Xof x;
        x.init(seed_dk, 32);
        sample::fixed_weight_uniform<P>(x, y, P::W);
    }
    static void public_h(uint64_t *h, const uint8_t seed_ek[32]) {
        Xof x;
        x.init(seed_ek, 32);
        sample::uniform<P>(x, h);
    }

    static void pke_keygen(uint8_t *ek, uint8_t seed_dk_out[32], const uint8_t seed_pke[32]) {
        uint8_t kp[64];
        hash_i(kp, seed_pke);
        uint64_t x[NW], y[NW], h[NW], s[NW];
        {
            Xof dx;
            dx.init(kp, 32);
            sample::fixed_weight_uniform<P>(dx, y, P::W);
            sample::fixed_weight_uniform<P>(dx, x, P::W);
        }
        public_h(h, kp + 32);
        gf2x::mul<P>(s, y, h);
        for (size_t i = 0; i < NW; ++i) s[i] ^= x[i];
        std::memcpy(ek, kp + 32, 32);
        words_to_bytes(ek + 32, P::NBYTES, s);
        std::memcpy(seed_dk_out, kp, 32);
        wipe(kp, sizeof kp);
        wipe(x, sizeof x);
        wipe(y, sizeof y);
    }

    /* c = (u, v) as bytes, salt not included */
    static void pke_encrypt(uint8_t *ct, const uint8_t *ek, const uint8_t *m, const uint8_t theta[32]) {
        uint64_t h[NW], s[NW], r1[NW], r2[NW], e[NW], u[NW], t[NW];
        uint64_t v[P::N1N2W];
        public_h(h, ek);
        bytes_to_words(s, NW, ek + 32, P::NBYTES);
        {
            Xof tx;
            tx.init(theta, 32);
            sample::fixed_weight<P>(tx, r2, P::WR);
            sample::fixed_weight<P>(tx, e, P::WE);
            sample::fixed_weight<P>(tx, r1, P::WR);
        }
        gf2x::mul<P>(u, r2, h);
        for (size_t i = 0; i < NW; ++i) u[i] ^= r1[i];
        uint8_t rsw[P::N1];
        rs::encode<P>(rsw, m);
        rm::encode<P>(v, rsw);
        gf2x::mul<P>(t, r2, s);
        for (size_t i = 0; i < NW; ++i) t[i] ^= e[i];
        /* Truncate(.., N1N2) then add */
        for (size_t i = 0; i < P::N1N2W; ++i) v[i] ^= t[i];
        words_to_bytes(ct, P::NBYTES, u);
        words_to_bytes(ct + P::NBYTES, P::N1N2BYTES, v);
        wipe(r1, sizeof r1);
        wipe(r2, sizeof r2);
        wipe(e, sizeof e);
        wipe(t, sizeof t);
        wipe(v, sizeof v);
        wipe(rsw, sizeof rsw);
    }

    static void pke_decrypt(uint8_t *m, const uint8_t seed_dk[32], const uint8_t *ct) {
        uint64_t y[NW], u[NW], t[NW];
        uint64_t v[P::N1N2W];
        secret_y(y, seed_dk);
        bytes_to_words(u, NW, ct, P::NBYTES);
        bytes_to_words(v, P::N1N2W, ct + P::NBYTES, P::N1N2BYTES);
        gf2x::mul<P>(t, y, u);
        for (size_t i = 0; i < P::N1N2W; ++i) v[i] ^= t[i];
        uint8_t rsw[P::N1];
        rm::decode<P>(rsw, v);
        rs::decode<P>(m, rsw);
        wipe(y, sizeof y);
        wipe(t, sizeof t);
        wipe(v, sizeof v);
        wipe(rsw, sizeof rsw);
    }

    /* ---------------------------------------------------------- HQC-KEM */

    /* dk = ek || seed_dk || sigma || seed_kem */
    static void keygen(uint8_t *ek, uint8_t *dk, const uint8_t seed_kem[32]) {
        uint8_t seed_pke[32], sigma[P::K], seed_dk[32];
        {
            Xof k;
            k.init(seed_kem, 32);
            k.get(seed_pke, 32);
            k.get(sigma, P::K);
        }
        pke_keygen(ek, seed_dk, seed_pke);
        std::memcpy(dk, ek, P::EK);
        std::memcpy(dk + P::EK, seed_dk, 32);
        std::memcpy(dk + P::EK + 32, sigma, P::K);
        std::memcpy(dk + P::EK + 32 + P::K, seed_kem, 32);
        wipe(seed_pke, sizeof seed_pke);
        wipe(sigma, sizeof sigma);
        wipe(seed_dk, sizeof seed_dk);
    }

    /* ek is well formed when the bits of s past N are zero */
    static bool ek_ok(const uint8_t *ek) {
        constexpr unsigned spare = static_cast<unsigned>(8 * P::NBYTES - P::N);
        if (spare == 0) return true;
        uint8_t top = ek[P::EK - 1];
        return (top >> (8 - spare)) == 0;
    }

    /* dk's stored seeds must re-derive from its seed_kem (one XOF, one
     * SHA3-512): a corrupted or spliced key is refused instead of
     * decapsulating to garbage. Constant time in the secret bytes. */
    static bool dk_ok(const uint8_t *dk) {
        uint8_t seed_pke[32], sigma[P::K], kp[64];
        {
            Xof k;
            k.init(dk + P::EK + 32 + P::K, 32);
            k.get(seed_pke, 32);
            k.get(sigma, P::K);
        }
        hash_i(kp, seed_pke);
        uint64_t ok = ct_eq_mask(kp, dk + P::EK, 32) & ct_eq_mask(sigma, dk + P::EK + 32, P::K) &
                      ct_eq_mask(kp + 32, dk, 32);
        wipe(seed_pke, sizeof seed_pke);
        wipe(sigma, sizeof sigma);
        wipe(kp, sizeof kp);
        return ok != 0;
    }

    static void encaps(uint8_t *ct, uint8_t ss[32], const uint8_t *ek, const uint8_t *m, const uint8_t salt[16]) {
        uint8_t hek[32], kt[64];
        hash_h(hek, ek);
        hash_g(kt, hek, m, salt);
        pke_encrypt(ct, ek, m, kt + 32);
        std::memcpy(ct + P::NBYTES + P::N1N2BYTES, salt, P::SALT);
        std::memcpy(ss, kt, 32);
        wipe(kt, sizeof kt);
    }

    static void decaps(uint8_t ss[32], const uint8_t *dk, const uint8_t *ct) {
        const uint8_t *ek = dk;
        const uint8_t *seed_dk = dk + P::EK;
        const uint8_t *sigma = dk + P::EK + 32;
        uint8_t m[P::K], hek[32], kt[64], kbar[32];
        uint8_t ct2[P::CT];
        pke_decrypt(m, seed_dk, ct);
        hash_h(hek, ek);
        hash_g(kt, hek, m, ct + P::NBYTES + P::N1N2BYTES);
        pke_encrypt(ct2, ek, m, kt + 32);
        std::memcpy(ct2 + P::NBYTES + P::N1N2BYTES, ct + P::NBYTES + P::N1N2BYTES, P::SALT);
        hash_j(kbar, hek, sigma, ct);
        uint64_t keep = ct_eq_mask(ct, ct2, P::CT); /* all ones when c' = c */
        uint8_t k8 = static_cast<uint8_t>(barrier(keep));
        for (size_t i = 0; i < 32; ++i) ss[i] = static_cast<uint8_t>((kt[i] & k8) | (kbar[i] & static_cast<uint8_t>(~k8)));
        wipe(m, sizeof m);
        wipe(kt, sizeof kt);
        wipe(kbar, sizeof kbar);
        wipe(ct2, sizeof ct2);
    }
};

/* ------------------------------------------------------------ HQC round 4 */

/* The round-4 submission of 2023-04-30 (liboqs <= 0.12, PQClean's hqc-128/192/256): the same
 * codes and parameters as above, a different KEM around them -- 40-byte seeds, SHAKE256-512
 * with a trailing domain byte for G (3) and K (4) and for the seed expander (2), positions
 * drawn as i + (r mod (N - i)), and a 64-byte shared secret K(m || u || v). */
template <class P>
struct Scheme4 {
    static constexpr size_t NW = P::NW;
    static constexpr size_t SEED = 40;
    static constexpr size_t SALT = 16;
    static constexpr size_t SS = 64;
    static constexpr size_t EK = SEED + P::NBYTES;
    static constexpr size_t DK = SEED + P::K + EK;
    static constexpr size_t CT = P::NBYTES + P::N1N2BYTES + SALT;
    static constexpr size_t RND = 2 * SEED + P::K; /* the keygen randomness: sk_seed, sigma, pk_seed */
    enum : uint8_t { DOM_SEEDEXP = 2, DOM_G4 = 3, DOM_K4 = 4 };

    static void shake512(uint8_t out[64], uint8_t domain, const uint8_t *const *parts, const size_t *lens,
                         size_t nparts) {
        RmblKeccak st;
        rmbl_keccak_init(&st, 136, 0x1F);
        for (size_t i = 0; i < nparts; ++i) rmbl_keccak_absorb(&st, parts[i], lens[i]);
        rmbl_keccak_absorb(&st, &domain, 1);
        rmbl_keccak_finalize(&st);
        rmbl_keccak_squeeze(&st, out, 64);
        wipe(&st, sizeof st);
    }

    /* r mod (N - i) as the reference computes it: Barrett with floor(2^32 / (N - i)) and one
     * conditional subtraction (the modulus is public, so the division is too) */
    static uint32_t reduce(uint32_t a, size_t i) {
        const uint32_t n = static_cast<uint32_t>(P::N - i);
        const uint32_t m = static_cast<uint32_t>((uint64_t(1) << 32) / n);
        const uint32_t q = static_cast<uint32_t>((static_cast<uint64_t>(a) * m) >> 32);
        uint32_t r = a - q * n;
        r -= n;
        return r + (n & (0u - (r >> 31)));
    }

    static void fixed_weight(Xof &ctx, uint64_t *v, size_t weight) {
        uint32_t support[P::WR > P::W ? P::WR : P::W] = {0};
        uint8_t buf[4 * (P::WR > P::W ? P::WR : P::W)];
        ctx.get(buf, 4 * weight);
        for (size_t i = 0; i < weight; ++i) {
            support[i] = static_cast<uint32_t>(i + reduce(static_cast<uint32_t>(load_le64(buf + 4 * i, 4)), i));
        }
        for (size_t ii = weight - 1; ii-- > 0;) {
            uint32_t found = 0;
            for (size_t j = ii + 1; j < weight; ++j) {
                uint32_t d = support[j] ^ support[ii];
                found |= 1 ^ ((d | (0u - d)) >> 31);
            }
            uint32_t mask = 0u - found;
            support[ii] = (mask & static_cast<uint32_t>(ii)) ^ (~mask & support[ii]);
        }
        sample::write_support<P>(v, support, weight);
        wipe(support, sizeof support);
        wipe(buf, sizeof buf);
    }

    static void secret_xy(uint64_t *x, uint64_t *y, const uint8_t *sk_seed) {
        Xof sx;
        sx.init(sk_seed, SEED, DOM_SEEDEXP);
        fixed_weight(sx, x, P::W);
        fixed_weight(sx, y, P::W);
    }
    static void public_h(uint64_t *h, const uint8_t *pk_seed) {
        Xof px;
        px.init(pk_seed, SEED, DOM_SEEDEXP);
        sample::uniform<P>(px, h);
    }

    /* ek = pk_seed || s, dk = sk_seed || sigma || ek, from the RND bytes the reference draws */
    static void keygen(uint8_t *ek, uint8_t *dk, const uint8_t *rnd) {
        const uint8_t *sk_seed = rnd, *sigma = rnd + SEED, *pk_seed = rnd + SEED + P::K;
        uint64_t x[NW], y[NW], h[NW], s[NW];
        secret_xy(x, y, sk_seed);
        public_h(h, pk_seed);
        gf2x::mul<P>(s, y, h);
        for (size_t i = 0; i < NW; ++i) s[i] ^= x[i];
        std::memcpy(ek, pk_seed, SEED);
        words_to_bytes(ek + SEED, P::NBYTES, s);
        std::memcpy(dk, sk_seed, SEED);
        std::memcpy(dk + SEED, sigma, P::K);
        std::memcpy(dk + SEED + P::K, ek, EK);
        wipe(x, sizeof x);
        wipe(y, sizeof y);
    }

    static bool ek_ok(const uint8_t *ek) {
        constexpr unsigned spare = static_cast<unsigned>(8 * P::NBYTES - P::N);
        return spare == 0 || (ek[EK - 1] >> (8 - spare)) == 0;
    }

    /* the stored public key must be the one the secret seed makes (s = x + y h): a corrupted or
     * spliced key is refused instead of decapsulating to garbage. Constant time in the secrets. */
    static bool dk_ok(const uint8_t *dk) {
        const uint8_t *ek = dk + SEED + P::K;
        if (!ek_ok(ek)) return false;
        uint64_t x[NW], y[NW], h[NW], s[NW];
        uint8_t sb[P::NBYTES];
        secret_xy(x, y, dk);
        public_h(h, ek);
        gf2x::mul<P>(s, y, h);
        for (size_t i = 0; i < NW; ++i) s[i] ^= x[i];
        words_to_bytes(sb, P::NBYTES, s);
        uint64_t ok = ct_eq_mask(sb, ek + SEED, P::NBYTES);
        wipe(x, sizeof x);
        wipe(y, sizeof y);
        wipe(s, sizeof s);
        wipe(sb, sizeof sb);
        return ok != 0;
    }

    /* (u || v) as bytes into ct */
    static void pke_encrypt(uint8_t *ct, const uint8_t *ek, const uint8_t *m, const uint8_t *theta) {
        uint64_t h[NW], s[NW], r1[NW], r2[NW], e[NW], u[NW], t[NW];
        uint64_t v[P::N1N2W];
        public_h(h, ek);
        bytes_to_words(s, NW, ek + SEED, P::NBYTES);
        {
            Xof tx;
            tx.init(theta, SEED, DOM_SEEDEXP);
            fixed_weight(tx, r1, P::WR);
            fixed_weight(tx, r2, P::WR);
            fixed_weight(tx, e, P::WE);
        }
        gf2x::mul<P>(u, r2, h);
        for (size_t i = 0; i < NW; ++i) u[i] ^= r1[i];
        uint8_t rsw[P::N1];
        rs::encode<P>(rsw, m);
        rm::encode<P>(v, rsw);
        gf2x::mul<P>(t, r2, s);
        for (size_t i = 0; i < NW; ++i) t[i] ^= e[i];
        for (size_t i = 0; i < P::N1N2W; ++i) v[i] ^= t[i];
        words_to_bytes(ct, P::NBYTES, u);
        words_to_bytes(ct + P::NBYTES, P::N1N2BYTES, v);
        wipe(r1, sizeof r1);
        wipe(r2, sizeof r2);
        wipe(e, sizeof e);
        wipe(t, sizeof t);
        wipe(v, sizeof v);
        wipe(rsw, sizeof rsw);
    }

    static void hash_g(uint8_t theta[64], const uint8_t *m, const uint8_t *ek, const uint8_t *salt) {
        const uint8_t *parts[3] = {m, ek, salt};
        size_t lens[3] = {P::K, EK, SALT};
        shake512(theta, DOM_G4, parts, lens, 3);
    }
    static void hash_k(uint8_t ss[64], const uint8_t *m, const uint8_t *uv) {
        const uint8_t *parts[2] = {m, uv};
        size_t lens[2] = {P::K, P::NBYTES + P::N1N2BYTES};
        shake512(ss, DOM_K4, parts, lens, 2);
    }

    static void encaps(uint8_t *ct, uint8_t ss[64], const uint8_t *ek, const uint8_t *m, const uint8_t *salt) {
        uint8_t theta[64];
        hash_g(theta, m, ek, salt);
        pke_encrypt(ct, ek, m, theta);
        std::memcpy(ct + P::NBYTES + P::N1N2BYTES, salt, SALT);
        hash_k(ss, m, ct);
        wipe(theta, sizeof theta);
    }

    static void decaps(uint8_t ss[64], const uint8_t *dk, const uint8_t *ct) {
        const uint8_t *sigma = dk + SEED;
        const uint8_t *ek = dk + SEED + P::K;
        uint64_t x[NW], y[NW], u[NW], t[NW];
        uint64_t v[P::N1N2W];
        uint8_t m[P::K], theta[64], mc[P::K], rsw[P::N1];
        uint8_t ct2[P::NBYTES + P::N1N2BYTES];
        secret_xy(x, y, dk);
        bytes_to_words(u, NW, ct, P::NBYTES);
        bytes_to_words(v, P::N1N2W, ct + P::NBYTES, P::N1N2BYTES);
        gf2x::mul<P>(t, y, u);
        for (size_t i = 0; i < P::N1N2W; ++i) v[i] ^= t[i];
        rm::decode<P>(rsw, v);
        rs::decode<P>(m, rsw);
        hash_g(theta, m, ek, ct + P::NBYTES + P::N1N2BYTES);
        pke_encrypt(ct2, ek, m, theta);
        uint64_t keep = ct_eq_mask(ct, ct2, P::NBYTES + P::N1N2BYTES); /* all ones when (u, v) = (u', v') */
        uint8_t k8 = static_cast<uint8_t>(barrier(keep));
        for (size_t i = 0; i < P::K; ++i) mc[i] = static_cast<uint8_t>((m[i] & k8) | (sigma[i] & static_cast<uint8_t>(~k8)));
        hash_k(ss, mc, ct);
        wipe(x, sizeof x);
        wipe(y, sizeof y);
        wipe(t, sizeof t);
        wipe(v, sizeof v);
        wipe(m, sizeof m);
        wipe(mc, sizeof mc);
        wipe(theta, sizeof theta);
        wipe(rsw, sizeof rsw);
        wipe(ct2, sizeof ct2);
    }
};

} // namespace rmbl_hqc

#endif
