/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * The parameter-dependent half of ML-DSA (FIPS 204). This file is
 * included once per parameter set, with MLDSA_NS and the MLDSA_*
 * parameters defined by the includer -- deliberately NOT guarded
 * against multiple inclusion, and deliberately not a template: the
 * parameters fix array sizes and packed field widths, and one
 * instantiation per set keeps every bound a compile-time constant.
 *
 * Requires: MLDSA_NS, MLDSA_K, MLDSA_L, MLDSA_ETA, MLDSA_TAU,
 * MLDSA_BETA, MLDSA_GAMMA1, MLDSA_GAMMA2_DEN, MLDSA_OMEGA,
 * MLDSA_CTILDE.
 */

namespace MLDSA_NS {

using rmbl_mldsa_core::kQ;
using rmbl_mldsa_core::montgomery_reduce;
using rmbl_mldsa_core::reduce32;
using rmbl_mldsa_core::caddq;
using rmbl_mldsa_core::ntt;
using rmbl_mldsa_core::invntt_tomont;

const int kSeedBytes = 32;
const int kCrhBytes = 64;
const int kTrBytes = 64;
/* The parameter set, supplied by whichever translation unit includes
 * this body. FIPS 204 defines three: ML-DSA-44, -65 and -87. */
const int kK = MLDSA_K;
const int kL = MLDSA_L;
const int kEta = MLDSA_ETA;
const int kTau = MLDSA_TAU;
const int32_t kBeta = MLDSA_BETA;
const int32_t kGamma1 = MLDSA_GAMMA1;
const int32_t kGamma2 = (kQ - 1) / MLDSA_GAMMA2_DEN;
const int kOmega = MLDSA_OMEGA;
const int kCtildeBytes = MLDSA_CTILDE;
#if MLDSA_ETA == 2
const int kPolyEtaPacked = 96;    /* eta = 2: 3 bits per coefficient */
#else
const int kPolyEtaPacked = 128;   /* eta = 4: 4 bits per coefficient */
#endif
#if MLDSA_GAMMA1 == (1 << 17)
const int kPolyZPacked = 576;     /* gamma1 = 2^17: 18 bits each */
#else
const int kPolyZPacked = 640;     /* gamma1 = 2^19: 20 bits each */
#endif
#if MLDSA_GAMMA2_DEN == 88
const int kPolyW1Packed = 192;    /* gamma2 = (q-1)/88: 6 bits each */
#else
const int kPolyW1Packed = 128;    /* gamma2 = (q-1)/32: 4 bits each */
#endif
const int kPolyT1Packed = 320;    /* 10 bits each */
const int kPolyT0Packed = 416;    /* 13 bits each */

/* Constant-time testing hook (inst/ctcheck): a value the specification
 * publishes anyway -- rho, the challenge, the hints and which samples were rejected -- is declared public to the checker here,
 * so the branch that follows is not reported. A no-op in the package. */
#ifndef RMBL_MLDSA_DECLASSIFY
#define RMBL_MLDSA_DECLASSIFY(ptr, len) ((void)0)
#endif

/* a_i uniform on [0, q), three bytes at a time with the top bit
 * cleared. Returns how many coefficients were filled. */
unsigned int rej_uniform(int32_t *a, unsigned int len,
                         const unsigned char *buf, unsigned int buflen) {
    unsigned int ctr = 0, pos = 0;
    while (ctr < len && pos + 3 <= buflen) {
        uint32_t t = buf[pos++];
        t |= static_cast<uint32_t>(buf[pos++]) << 8;
        t |= static_cast<uint32_t>(buf[pos++]) << 16;
        t &= 0x7FFFFF;
        if (t < static_cast<uint32_t>(kQ)) a[ctr++] = static_cast<int32_t>(t);
    }
    return ctr;
}

/* a_i uniform on [-eta, eta], a nibble at a time. For eta = 4 a nibble
 * below 9 maps to 4 - t; for eta = 2 a nibble below 15 is reduced mod 5
 * (division-free, as in the reference) and maps to 2 - t. Nibbles at or
 * above the bound are rejected, which is what keeps the distribution
 * uniform rather than biased toward zero. */
unsigned int rej_eta(int32_t *a, unsigned int len,
                     const unsigned char *buf, unsigned int buflen) {
    unsigned int ctr = 0, pos = 0;
    while (ctr < len && pos < buflen) {
        uint32_t t0 = buf[pos] & 0x0F;
        uint32_t t1 = buf[pos++] >> 4;
        /* FIPS 204 RejBoundedPoly: whether a nibble is rejected is public
         * (the rejected randomness is never used), the accepted value is
         * not. Only the decision is declassified. */
#if MLDSA_ETA == 2
        unsigned int ok0 = t0 < 15, ok1 = t1 < 15;
        RMBL_MLDSA_DECLASSIFY(&ok0, sizeof ok0);
        RMBL_MLDSA_DECLASSIFY(&ok1, sizeof ok1);
        if (ok0) {
            t0 = t0 - (205 * t0 >> 10) * 5;
            a[ctr++] = 2 - static_cast<int32_t>(t0);
        }
        if (ok1 && ctr < len) {
            t1 = t1 - (205 * t1 >> 10) * 5;
            a[ctr++] = 2 - static_cast<int32_t>(t1);
        }
#else
        unsigned int ok0 = t0 < 9, ok1 = t1 < 9;
        RMBL_MLDSA_DECLASSIFY(&ok0, sizeof ok0);
        RMBL_MLDSA_DECLASSIFY(&ok1, sizeof ok1);
        if (ok0) a[ctr++] = 4 - static_cast<int32_t>(t0);
        if (ok1 && ctr < len) a[ctr++] = 4 - static_cast<int32_t>(t1);
#endif
    }
    return ctr;
}

/* The expanded matrix A: each entry is a polynomial sampled from
 * SHAKE128 keyed by rho and the entry's own (i, j), so the whole matrix
 * is reproducible from 32 bytes. */
void poly_uniform(int32_t a[256], const unsigned char rho[32],
                  uint16_t nonce) {
    unsigned char ext[34];
    std::memcpy(ext, rho, 32);
    ext[32] = static_cast<unsigned char>(nonce & 0xff);
    ext[33] = static_cast<unsigned char>(nonce >> 8);
    RmblKeccak st;
    rmbl_keccak_init(&st, 168, 0x1f);
    rmbl_keccak_absorb(&st, ext, 34);
    rmbl_keccak_finalize(&st);
    unsigned char buf[168 * 5];
    rmbl_keccak_squeeze(&st, buf, sizeof buf);
    unsigned int ctr = rej_uniform(a, 256, buf, sizeof buf);
    while (ctr < 256) {
        rmbl_keccak_squeeze(&st, buf, 168);
        ctr += rej_uniform(a + ctr, 256 - ctr, buf, 168);
    }
}

void poly_uniform_eta(int32_t a[256], const unsigned char seed[64],
                      uint16_t nonce) {
    unsigned char ext[66];
    rmbl_ct::Guard ge(ext, sizeof ext);
    std::memcpy(ext, seed, 64);
    ext[64] = static_cast<unsigned char>(nonce & 0xff);
    ext[65] = static_cast<unsigned char>(nonce >> 8);
    RmblKeccak st;
    rmbl_ct::Guard gst(&st, sizeof st);
    rmbl_keccak_init(&st, 136, 0x1f);
    rmbl_keccak_absorb(&st, ext, 66);
    rmbl_keccak_finalize(&st);
    unsigned char buf[136 * 2];
    rmbl_ct::Guard gb(buf, sizeof buf);
    rmbl_keccak_squeeze(&st, buf, sizeof buf);
    unsigned int ctr = rej_eta(a, 256, buf, sizeof buf);
    while (ctr < 256) {
        rmbl_keccak_squeeze(&st, buf, 136);
        ctr += rej_eta(a + ctr, 256 - ctr, buf, 136);
    }
}

/* z is not rejection sampled: the packed field width (18 bits for
 * gamma1 = 2^17, 20 for 2^19) is read straight out and mapped into
 * (-gamma1, gamma1]. */
void polyz_unpack(int32_t r[256], const unsigned char *a) {
#if MLDSA_GAMMA1 == (1 << 17)
    for (int i = 0; i < 64; ++i) {
        uint32_t t[4];
        t[0] = a[9 * i + 0];
        t[0] |= static_cast<uint32_t>(a[9 * i + 1]) << 8;
        t[0] |= static_cast<uint32_t>(a[9 * i + 2]) << 16;
        t[0] &= 0x3FFFF;
        t[1] = static_cast<uint32_t>(a[9 * i + 2]) >> 2;
        t[1] |= static_cast<uint32_t>(a[9 * i + 3]) << 6;
        t[1] |= static_cast<uint32_t>(a[9 * i + 4]) << 14;
        t[1] &= 0x3FFFF;
        t[2] = static_cast<uint32_t>(a[9 * i + 4]) >> 4;
        t[2] |= static_cast<uint32_t>(a[9 * i + 5]) << 4;
        t[2] |= static_cast<uint32_t>(a[9 * i + 6]) << 12;
        t[2] &= 0x3FFFF;
        t[3] = static_cast<uint32_t>(a[9 * i + 6]) >> 6;
        t[3] |= static_cast<uint32_t>(a[9 * i + 7]) << 2;
        t[3] |= static_cast<uint32_t>(a[9 * i + 8]) << 10;
        t[3] &= 0x3FFFF;
        for (int j = 0; j < 4; ++j) {
            r[4 * i + j] = kGamma1 - static_cast<int32_t>(t[j]);
        }
    }
#else
    for (int i = 0; i < 128; ++i) {
        uint32_t t0 = a[5 * i + 0];
        t0 |= static_cast<uint32_t>(a[5 * i + 1]) << 8;
        t0 |= static_cast<uint32_t>(a[5 * i + 2]) << 16;
        t0 &= 0xFFFFF;
        uint32_t t1 = static_cast<uint32_t>(a[5 * i + 2]) >> 4;
        t1 |= static_cast<uint32_t>(a[5 * i + 3]) << 4;
        t1 |= static_cast<uint32_t>(a[5 * i + 4]) << 12;
        t1 &= 0xFFFFF;
        r[2 * i + 0] = kGamma1 - static_cast<int32_t>(t0);
        r[2 * i + 1] = kGamma1 - static_cast<int32_t>(t1);
    }
#endif
}

void poly_uniform_gamma1(int32_t a[256], const unsigned char seed[64],
                         uint16_t nonce) {
    unsigned char ext[66];
    std::memcpy(ext, seed, 64);
    ext[64] = static_cast<unsigned char>(nonce & 0xff);
    ext[65] = static_cast<unsigned char>(nonce >> 8);
    unsigned char buf[kPolyZPacked];
    RmblKeccak st;
    rmbl_keccak_init(&st, 136, 0x1f);
    rmbl_keccak_absorb(&st, ext, 66);
    rmbl_keccak_finalize(&st);
    rmbl_keccak_squeeze(&st, buf, sizeof buf);
    polyz_unpack(a, buf);
}

/* The challenge: tau coefficients set to +/-1, placed by a
 * Fisher-Yates-style walk so exactly tau are non-zero. The signs come
 * from the first eight bytes of the stream and the positions from the
 * rest, rejecting any byte beyond the current index. */
void poly_challenge(int32_t c[256], const unsigned char *seed) {
    RmblKeccak st;
    rmbl_keccak_init(&st, 136, 0x1f);
    rmbl_keccak_absorb(&st, seed, static_cast<size_t>(kCtildeBytes));
    rmbl_keccak_finalize(&st);
    unsigned char buf[136];
    rmbl_keccak_squeeze(&st, buf, 136);
    uint64_t signs = 0;
    for (int i = 0; i < 8; ++i) {
        signs |= static_cast<uint64_t>(buf[i]) << (8 * i);
    }
    unsigned int pos = 8;
    for (int i = 0; i < 256; ++i) c[i] = 0;
    for (int i = 256 - kTau; i < 256; ++i) {
        unsigned int b;
        do {
            if (pos >= 136) {
                rmbl_keccak_squeeze(&st, buf, 136);
                pos = 0;
            }
            b = buf[pos++];
        } while (static_cast<int>(b) > i);
        c[i] = c[b];
        c[b] = 1 - 2 * static_cast<int32_t>(signs & 1);
        signs >>= 1;
    }
}

/* ---------------------------------------------------------------------
 * Rounding, and the hint mechanism.
 *
 * The signature does not carry the low bits of w = A*y. Instead the
 * verifier recomputes a high part and the signer sends one bit per
 * coefficient saying whether the recomputation will land one step out.
 * That is what keeps the signature small, and it is why an error here
 * produces a scheme whose signatures verify only against itself.
 * ------------------------------------------------------------------ */

/* a = a1 * 2 * gamma2 + a0 with a0 in (-gamma2, gamma2]. a1 runs over
 * 0..15 when gamma2 = (q-1)/32 and 0..43 when gamma2 = (q-1)/88. The
 * magic constants are the reference's division-free form of
 * a1 = round(a / (2 gamma2)). */
inline int32_t decompose(int32_t *a0, int32_t a) {
    int32_t a1 = (a + 127) >> 7;
#if MLDSA_GAMMA2_DEN == 88
    a1 = (a1 * 11275 + (1 << 23)) >> 24;
    a1 ^= ((43 - a1) >> 31) & a1;
#else
    a1 = (a1 * 1025 + (1 << 21)) >> 22;
    a1 &= 15;
#endif
    *a0 = a - a1 * 2 * kGamma2;
    *a0 -= (((kQ - 1) / 2 - *a0) >> 31) & kQ;
    return a1;
}

/* One hint bit: set when the low part is outside the window, so the
 * verifier's high part would differ. The `a0 == -gamma2 && a1 != 0`
 * arm is the boundary case that makes the encoding unique. */
inline unsigned int make_hint(int32_t a0, int32_t a1) {
    if (a0 > kGamma2 || a0 < -kGamma2 || (a0 == -kGamma2 && a1 != 0)) {
        return 1;
    }
    return 0;
}

inline int32_t use_hint(int32_t a, unsigned int hint) {
    int32_t a0;
    const int32_t a1 = decompose(&a0, a);
    if (hint == 0) return a1;
#if MLDSA_GAMMA2_DEN == 88
    /* 44 values, so the step wraps explicitly rather than by masking */
    if (a0 > 0) return a1 == 43 ? 0 : a1 + 1;
    return a1 == 0 ? 43 : a1 - 1;
#else
    return a0 > 0 ? ((a1 + 1) & 15) : ((a1 - 1) & 15);
#endif
}

/* Rejects a polynomial whose coefficients leave the allowed range. The
 * absolute value is taken branch-free on the sign bit; the early return
 * on the first out-of-range coefficient is data-dependent, as in the
 * pq-crystals reference, and leaks only the index of that coefficient
 * inside a rejection iteration whose outcome (rejected) is public anyway.
 * It is not a constant-time comparison and does not claim to be. */
inline int poly_chknorm(const int32_t a[256], int32_t B) {
    if (B > (kQ - 1) / 8) return 1;
    /* every coefficient is examined; an early return would tell a timing
     * observer which coefficient of z (hence of the secret) was large */
    uint32_t bad = 0;
    for (int i = 0; i < 256; ++i) {
        int32_t t = a[i] >> 31;
        t = a[i] - (t & 2 * a[i]);
        bad |= static_cast<uint32_t>(B - 1 - t) >> 31; /* t >= B */
    }
    int rejected = bad != 0;
    RMBL_MLDSA_DECLASSIFY(&rejected, sizeof rejected); /* the rejection itself is public */
    return rejected;
}

/* ---------------------------------------------------------------------
 * Bit packing. Every one of these is a fixed-width field layout, and a
 * misplaced shift produces bytes another implementation cannot read
 * while round-tripping perfectly through its own inverse.
 * ------------------------------------------------------------------ */

/* t1: 10 bits per coefficient, 4 coefficients to 5 bytes. */
inline void polyt1_pack(unsigned char *r, const int32_t a[256]) {
    for (int i = 0; i < 64; ++i) {
        r[5 * i + 0] = static_cast<unsigned char>(a[4 * i + 0] >> 0);
        r[5 * i + 1] = static_cast<unsigned char>((a[4 * i + 0] >> 8) |
                                                  (a[4 * i + 1] << 2));
        r[5 * i + 2] = static_cast<unsigned char>((a[4 * i + 1] >> 6) |
                                                  (a[4 * i + 2] << 4));
        r[5 * i + 3] = static_cast<unsigned char>((a[4 * i + 2] >> 4) |
                                                  (a[4 * i + 3] << 6));
        r[5 * i + 4] = static_cast<unsigned char>(a[4 * i + 3] >> 2);
    }
}

inline void polyt1_unpack(int32_t r[256], const unsigned char *a) {
    for (int i = 0; i < 64; ++i) {
        r[4 * i + 0] = ((a[5 * i + 0] >> 0) |
                        (static_cast<uint32_t>(a[5 * i + 1]) << 8)) & 0x3FF;
        r[4 * i + 1] = ((a[5 * i + 1] >> 2) |
                        (static_cast<uint32_t>(a[5 * i + 2]) << 6)) & 0x3FF;
        r[4 * i + 2] = ((a[5 * i + 2] >> 4) |
                        (static_cast<uint32_t>(a[5 * i + 3]) << 4)) & 0x3FF;
        r[4 * i + 3] = ((a[5 * i + 3] >> 6) |
                        (static_cast<uint32_t>(a[5 * i + 4]) << 2)) & 0x3FF;
    }
}

/* t0: 13 bits per coefficient, 8 coefficients to 13 bytes, stored as
 * 2^12 - t0 so the value is non-negative. */
inline void polyt0_pack(unsigned char *r, const int32_t a[256]) {
    uint32_t t[8];
    for (int i = 0; i < 32; ++i) {
        for (int j = 0; j < 8; ++j) {
            t[j] = static_cast<uint32_t>((1 << 12) - a[8 * i + j]);
        }
        r[13 * i + 0]  = static_cast<unsigned char>(t[0]);
        r[13 * i + 1]  = static_cast<unsigned char>((t[0] >> 8) | (t[1] << 5));
        r[13 * i + 2]  = static_cast<unsigned char>(t[1] >> 3);
        r[13 * i + 3]  = static_cast<unsigned char>((t[1] >> 11) | (t[2] << 2));
        r[13 * i + 4]  = static_cast<unsigned char>((t[2] >> 6) | (t[3] << 7));
        r[13 * i + 5]  = static_cast<unsigned char>(t[3] >> 1);
        r[13 * i + 6]  = static_cast<unsigned char>((t[3] >> 9) | (t[4] << 4));
        r[13 * i + 7]  = static_cast<unsigned char>(t[4] >> 4);
        r[13 * i + 8]  = static_cast<unsigned char>((t[4] >> 12) | (t[5] << 1));
        r[13 * i + 9]  = static_cast<unsigned char>((t[5] >> 7) | (t[6] << 6));
        r[13 * i + 10] = static_cast<unsigned char>(t[6] >> 2);
        r[13 * i + 11] = static_cast<unsigned char>((t[6] >> 10) | (t[7] << 3));
        r[13 * i + 12] = static_cast<unsigned char>(t[7] >> 5);
    }
}

inline void polyt0_unpack(int32_t r[256], const unsigned char *a) {
    for (int i = 0; i < 32; ++i) {
        r[8 * i + 0] = (a[13 * i + 0] |
            (static_cast<uint32_t>(a[13 * i + 1]) << 8)) & 0x1FFF;
        r[8 * i + 1] = ((a[13 * i + 1] >> 5) |
            (static_cast<uint32_t>(a[13 * i + 2]) << 3) |
            (static_cast<uint32_t>(a[13 * i + 3]) << 11)) & 0x1FFF;
        r[8 * i + 2] = ((a[13 * i + 3] >> 2) |
            (static_cast<uint32_t>(a[13 * i + 4]) << 6)) & 0x1FFF;
        r[8 * i + 3] = ((a[13 * i + 4] >> 7) |
            (static_cast<uint32_t>(a[13 * i + 5]) << 1) |
            (static_cast<uint32_t>(a[13 * i + 6]) << 9)) & 0x1FFF;
        r[8 * i + 4] = ((a[13 * i + 6] >> 4) |
            (static_cast<uint32_t>(a[13 * i + 7]) << 4) |
            (static_cast<uint32_t>(a[13 * i + 8]) << 12)) & 0x1FFF;
        r[8 * i + 5] = ((a[13 * i + 8] >> 1) |
            (static_cast<uint32_t>(a[13 * i + 9]) << 7)) & 0x1FFF;
        r[8 * i + 6] = ((a[13 * i + 9] >> 6) |
            (static_cast<uint32_t>(a[13 * i + 10]) << 2) |
            (static_cast<uint32_t>(a[13 * i + 11]) << 10)) & 0x1FFF;
        r[8 * i + 7] = ((a[13 * i + 11] >> 3) |
            (static_cast<uint32_t>(a[13 * i + 12]) << 5)) & 0x1FFF;
        for (int j = 0; j < 8; ++j) {
            r[8 * i + j] = (1 << 12) - r[8 * i + j];
        }
    }
}

/* s1 and s2: 3 bits per coefficient for eta = 2, 4 bits for eta = 4,
 * stored as eta - a so the field is non-negative. */
inline void polyeta_pack(unsigned char *r, const int32_t a[256]) {
#if MLDSA_ETA == 2
    unsigned char t[8];
    for (int i = 0; i < 32; ++i) {
        for (int j = 0; j < 8; ++j) {
            t[j] = static_cast<unsigned char>(kEta - a[8 * i + j]);
        }
        r[3 * i + 0] = static_cast<unsigned char>(t[0] | (t[1] << 3) |
                                                  (t[2] << 6));
        r[3 * i + 1] = static_cast<unsigned char>((t[2] >> 2) | (t[3] << 1) |
                                                  (t[4] << 4) | (t[5] << 7));
        r[3 * i + 2] = static_cast<unsigned char>((t[5] >> 1) | (t[6] << 2) |
                                                  (t[7] << 5));
    }
#else
    for (int i = 0; i < 128; ++i) {
        const unsigned char t0 = static_cast<unsigned char>(kEta - a[2 * i]);
        const unsigned char t1 = static_cast<unsigned char>(kEta - a[2 * i + 1]);
        r[i] = static_cast<unsigned char>(t0 | (t1 << 4));
    }
#endif
}

inline void polyeta_unpack(int32_t r[256], const unsigned char *a) {
#if MLDSA_ETA == 2
    for (int i = 0; i < 32; ++i) {
        r[8 * i + 0] = (a[3 * i + 0] >> 0) & 7;
        r[8 * i + 1] = (a[3 * i + 0] >> 3) & 7;
        r[8 * i + 2] = ((a[3 * i + 0] >> 6) |
                        (static_cast<uint32_t>(a[3 * i + 1]) << 2)) & 7;
        r[8 * i + 3] = (a[3 * i + 1] >> 1) & 7;
        r[8 * i + 4] = (a[3 * i + 1] >> 4) & 7;
        r[8 * i + 5] = ((a[3 * i + 1] >> 7) |
                        (static_cast<uint32_t>(a[3 * i + 2]) << 1)) & 7;
        r[8 * i + 6] = (a[3 * i + 2] >> 2) & 7;
        r[8 * i + 7] = (a[3 * i + 2] >> 5) & 7;
        for (int j = 0; j < 8; ++j) r[8 * i + j] = kEta - r[8 * i + j];
    }
#else
    for (int i = 0; i < 128; ++i) {
        r[2 * i + 0] = kEta - (a[i] & 0x0F);
        r[2 * i + 1] = kEta - (a[i] >> 4);
    }
#endif
}

/* z: 18 or 20 bits per coefficient, stored as gamma1 - z. */
inline void polyz_pack(unsigned char *r, const int32_t a[256]) {
#if MLDSA_GAMMA1 == (1 << 17)
    uint32_t t[4];
    for (int i = 0; i < 64; ++i) {
        for (int j = 0; j < 4; ++j) {
            t[j] = static_cast<uint32_t>(kGamma1 - a[4 * i + j]);
        }
        r[9 * i + 0] = static_cast<unsigned char>(t[0]);
        r[9 * i + 1] = static_cast<unsigned char>(t[0] >> 8);
        r[9 * i + 2] = static_cast<unsigned char>((t[0] >> 16) | (t[1] << 2));
        r[9 * i + 3] = static_cast<unsigned char>(t[1] >> 6);
        r[9 * i + 4] = static_cast<unsigned char>((t[1] >> 14) | (t[2] << 4));
        r[9 * i + 5] = static_cast<unsigned char>(t[2] >> 4);
        r[9 * i + 6] = static_cast<unsigned char>((t[2] >> 12) | (t[3] << 6));
        r[9 * i + 7] = static_cast<unsigned char>(t[3] >> 2);
        r[9 * i + 8] = static_cast<unsigned char>(t[3] >> 10);
    }
#else
    uint32_t t[2];
    for (int i = 0; i < 128; ++i) {
        t[0] = static_cast<uint32_t>(kGamma1 - a[2 * i + 0]);
        t[1] = static_cast<uint32_t>(kGamma1 - a[2 * i + 1]);
        r[5 * i + 0] = static_cast<unsigned char>(t[0]);
        r[5 * i + 1] = static_cast<unsigned char>(t[0] >> 8);
        r[5 * i + 2] = static_cast<unsigned char>((t[0] >> 16) | (t[1] << 4));
        r[5 * i + 3] = static_cast<unsigned char>(t[1] >> 4);
        r[5 * i + 4] = static_cast<unsigned char>(t[1] >> 12);
    }
#endif
}

/* w1: 6 bits per coefficient when gamma2 = (q-1)/88 (a1 runs to 43),
 * 4 bits when gamma2 = (q-1)/32 (a1 runs to 15). */
inline void polyw1_pack(unsigned char *r, const int32_t a[256]) {
#if MLDSA_GAMMA2_DEN == 88
    for (int i = 0; i < 64; ++i) {
        r[3 * i + 0] = static_cast<unsigned char>(a[4 * i + 0] |
                                                  (a[4 * i + 1] << 6));
        r[3 * i + 1] = static_cast<unsigned char>((a[4 * i + 1] >> 2) |
                                                  (a[4 * i + 2] << 4));
        r[3 * i + 2] = static_cast<unsigned char>((a[4 * i + 2] >> 4) |
                                                  (a[4 * i + 3] << 2));
    }
#else
    for (int i = 0; i < 128; ++i) {
        r[i] = static_cast<unsigned char>(a[2 * i] | (a[2 * i + 1] << 4));
    }
#endif
}

/* a = a1 * 2^d + a0 with -2^(d-1) < a0 <= 2^(d-1), d = 13. The high
 * part is what the public key carries; the low part is dropped and
 * recovered from hints. */
inline void power2round(int32_t a, int32_t *a0, int32_t *a1) {
    *a1 = (a + (1 << 12) - 1) >> 13;
    *a0 = a - (*a1 << 13);
}

/* ---------------------------------------------------------------------
 * Vectors and the matrix.
 *
 * A is K-by-L over the ring, and is never stored in a key: it is
 * expanded from rho whenever needed, which is why a public key is
 * 1952 bytes rather than megabytes.
 * ------------------------------------------------------------------ */

struct PolyVecL { int32_t v[kL][256]; };
struct PolyVecK { int32_t v[kK][256]; };

inline void poly_add(int32_t c[256], const int32_t a[256],
                     const int32_t b[256]) {
    for (int i = 0; i < 256; ++i) c[i] = a[i] + b[i];
}

inline void poly_sub(int32_t c[256], const int32_t a[256],
                     const int32_t b[256]) {
    for (int i = 0; i < 256; ++i) c[i] = a[i] - b[i];
}

inline void poly_reduce(int32_t a[256]) {
    for (int i = 0; i < 256; ++i) a[i] = reduce32(a[i]);
}

inline void poly_caddq(int32_t a[256]) {
    for (int i = 0; i < 256; ++i) a[i] = caddq(a[i]);
}

inline void poly_shiftl(int32_t a[256]) {
    for (int i = 0; i < 256; ++i) a[i] <<= 13;
}

inline void poly_pointwise_montgomery(int32_t c[256], const int32_t a[256],
                                      const int32_t b[256]) {
    for (int i = 0; i < 256; ++i) {
        c[i] = montgomery_reduce(static_cast<int64_t>(a[i]) * b[i]);
    }
}

/* The matrix: entry (i, j) is sampled with nonce (i << 8) + j, so the
 * whole of A follows from rho and nothing about the order is left to
 * chance. */
void matrix_expand(PolyVecL mat[kK], const unsigned char rho[32]) {
    for (int i = 0; i < kK; ++i) {
        for (int j = 0; j < kL; ++j) {
            poly_uniform(mat[i].v[j], rho,
                         static_cast<uint16_t>((i << 8) + j));
        }
    }
}

void matrix_pointwise_montgomery(PolyVecK *t, const PolyVecL mat[kK],
                                 const PolyVecL *v) {
    int32_t acc[256];
    for (int i = 0; i < kK; ++i) {
        poly_pointwise_montgomery(t->v[i], mat[i].v[0], v->v[0]);
        for (int j = 1; j < kL; ++j) {
            poly_pointwise_montgomery(acc, mat[i].v[j], v->v[j]);
            poly_add(t->v[i], t->v[i], acc);
        }
    }
}

#define VECL_EACH(body) for (int i = 0; i < kL; ++i) { body }
#define VECK_EACH(body) for (int i = 0; i < kK; ++i) { body }

inline void vecl_ntt(PolyVecL *v)            { VECL_EACH(ntt(v->v[i]);) }
inline void vecl_invntt(PolyVecL *v)         { VECL_EACH(invntt_tomont(v->v[i]);) }
inline void vecl_reduce(PolyVecL *v)         { VECL_EACH(poly_reduce(v->v[i]);) }
inline void veck_ntt(PolyVecK *v)            { VECK_EACH(ntt(v->v[i]);) }
inline void veck_invntt(PolyVecK *v)         { VECK_EACH(invntt_tomont(v->v[i]);) }
inline void veck_reduce(PolyVecK *v)         { VECK_EACH(poly_reduce(v->v[i]);) }
inline void veck_caddq(PolyVecK *v)          { VECK_EACH(poly_caddq(v->v[i]);) }
inline void veck_shiftl(PolyVecK *v)         { VECK_EACH(poly_shiftl(v->v[i]);) }

inline void vecl_add(PolyVecL *c, const PolyVecL *a, const PolyVecL *b) {
    VECL_EACH(poly_add(c->v[i], a->v[i], b->v[i]);)
}
inline void veck_add(PolyVecK *c, const PolyVecK *a, const PolyVecK *b) {
    VECK_EACH(poly_add(c->v[i], a->v[i], b->v[i]);)
}
inline void veck_sub(PolyVecK *c, const PolyVecK *a, const PolyVecK *b) {
    VECK_EACH(poly_sub(c->v[i], a->v[i], b->v[i]);)
}

inline void vecl_uniform_eta(PolyVecL *v, const unsigned char seed[64],
                             uint16_t nonce) {
    for (int i = 0; i < kL; ++i) {
        poly_uniform_eta(v->v[i], seed, static_cast<uint16_t>(nonce + i));
    }
}
inline void veck_uniform_eta(PolyVecK *v, const unsigned char seed[64],
                             uint16_t nonce) {
    for (int i = 0; i < kK; ++i) {
        poly_uniform_eta(v->v[i], seed, static_cast<uint16_t>(nonce + i));
    }
}
inline void vecl_uniform_gamma1(PolyVecL *v, const unsigned char seed[64],
                                uint16_t nonce) {
    for (int i = 0; i < kL; ++i) {
        poly_uniform_gamma1(v->v[i], seed,
                            static_cast<uint16_t>(kL * nonce + i));
    }
}

inline void vecl_pointwise_poly(PolyVecL *r, const int32_t a[256],
                                const PolyVecL *v) {
    VECL_EACH(poly_pointwise_montgomery(r->v[i], a, v->v[i]);)
}
inline void veck_pointwise_poly(PolyVecK *r, const int32_t a[256],
                                const PolyVecK *v) {
    VECK_EACH(poly_pointwise_montgomery(r->v[i], a, v->v[i]);)
}

inline int vecl_chknorm(const PolyVecL *v, int32_t B) {
    for (int i = 0; i < kL; ++i) if (poly_chknorm(v->v[i], B)) return 1;
    return 0;
}
inline int veck_chknorm(const PolyVecK *v, int32_t B) {
    for (int i = 0; i < kK; ++i) if (poly_chknorm(v->v[i], B)) return 1;
    return 0;
}

inline void veck_power2round(PolyVecK *v1, PolyVecK *v0, const PolyVecK *v) {
    for (int i = 0; i < kK; ++i) {
        for (int j = 0; j < 256; ++j) {
            int32_t a0, a1;
            power2round(v->v[i][j], &a0, &a1);
            v1->v[i][j] = a1;
            v0->v[i][j] = a0;
        }
    }
}

inline void veck_decompose(PolyVecK *v1, PolyVecK *v0, const PolyVecK *v) {
    for (int i = 0; i < kK; ++i) {
        for (int j = 0; j < 256; ++j) {
            int32_t a0;
            v1->v[i][j] = decompose(&a0, v->v[i][j]);
            v0->v[i][j] = a0;
        }
    }
}

/* Returns the total number of hint bits, which the caller rejects if it
 * exceeds omega -- the signature has room for exactly that many. */
inline unsigned int veck_make_hint(PolyVecK *h, const PolyVecK *v0,
                                   const PolyVecK *v1) {
    unsigned int s = 0;
    for (int i = 0; i < kK; ++i) {
        for (int j = 0; j < 256; ++j) {
            h->v[i][j] = static_cast<int32_t>(
                make_hint(v0->v[i][j], v1->v[i][j]));
            s += static_cast<unsigned int>(h->v[i][j]);
        }
    }
    return s;
}

inline void veck_use_hint(PolyVecK *w, const PolyVecK *u, const PolyVecK *h) {
    for (int i = 0; i < kK; ++i) {
        for (int j = 0; j < 256; ++j) {
            w->v[i][j] = use_hint(u->v[i][j],
                                  static_cast<unsigned>(h->v[i][j]));
        }
    }
}

inline void veck_pack_w1(unsigned char *r, const PolyVecK *v) {
    for (int i = 0; i < kK; ++i) {
        polyw1_pack(r + i * kPolyW1Packed, v->v[i]);
    }
}

/* ---------------------------------------------------------------------
 * Key and signature encoding. The sizes are fixed by the parameter
 * set, and they are asserted rather than assumed: a wrong length here
 * is a key another implementation cannot read.
 * ------------------------------------------------------------------ */

const int kPkBytes = 32 + kK * kPolyT1Packed;                 /* 1952 */
const int kSkBytes = 2 * 32 + kTrBytes + kL * kPolyEtaPacked
                     + kK * kPolyEtaPacked + kK * kPolyT0Packed; /* 4032 */
const int kSigBytes = kCtildeBytes + kL * kPolyZPacked
                      + kOmega + kK;                          /* 3309 */

void pack_pk(unsigned char *pk, const unsigned char rho[32],
             const PolyVecK *t1) {
    std::memcpy(pk, rho, 32);
    for (int i = 0; i < kK; ++i) {
        polyt1_pack(pk + 32 + i * kPolyT1Packed, t1->v[i]);
    }
}

void unpack_pk(unsigned char rho[32], PolyVecK *t1,
               const unsigned char *pk) {
    std::memcpy(rho, pk, 32);
    for (int i = 0; i < kK; ++i) {
        polyt1_unpack(t1->v[i], pk + 32 + i * kPolyT1Packed);
    }
}

void pack_sk(unsigned char *sk, const unsigned char rho[32],
             const unsigned char tr[64], const unsigned char key[32],
             const PolyVecK *t0, const PolyVecL *s1, const PolyVecK *s2) {
    std::memcpy(sk, rho, 32); sk += 32;
    std::memcpy(sk, key, 32); sk += 32;
    std::memcpy(sk, tr, static_cast<size_t>(kTrBytes)); sk += kTrBytes;
    for (int i = 0; i < kL; ++i) { polyeta_pack(sk, s1->v[i]); sk += kPolyEtaPacked; }
    for (int i = 0; i < kK; ++i) { polyeta_pack(sk, s2->v[i]); sk += kPolyEtaPacked; }
    for (int i = 0; i < kK; ++i) { polyt0_pack(sk, t0->v[i]); sk += kPolyT0Packed; }
}

void unpack_sk(unsigned char rho[32], unsigned char tr[64],
               unsigned char key[32], PolyVecK *t0, PolyVecL *s1,
               PolyVecK *s2, const unsigned char *sk) {
    std::memcpy(rho, sk, 32); sk += 32;
    std::memcpy(key, sk, 32); sk += 32;
    std::memcpy(tr, sk, static_cast<size_t>(kTrBytes)); sk += kTrBytes;
    for (int i = 0; i < kL; ++i) { polyeta_unpack(s1->v[i], sk); sk += kPolyEtaPacked; }
    for (int i = 0; i < kK; ++i) { polyeta_unpack(s2->v[i], sk); sk += kPolyEtaPacked; }
    for (int i = 0; i < kK; ++i) { polyt0_unpack(t0->v[i], sk); sk += kPolyT0Packed; }
}

/* The hint encoding is the compact one: the positions of the set bits
 * within each polynomial, followed by a running count per polynomial.
 * It is why the signature is 3309 bytes and not K*256 bits larger. */
void pack_sig(unsigned char *sig, const unsigned char *c,
              const PolyVecL *z, const PolyVecK *h) {
    std::memmove(sig, c, static_cast<size_t>(kCtildeBytes));  /* sign_mu passes sig as both */
    sig += kCtildeBytes;
    for (int i = 0; i < kL; ++i) {
        polyz_pack(sig + i * kPolyZPacked, z->v[i]);
    }
    sig += kL * kPolyZPacked;
    std::memset(sig, 0, static_cast<size_t>(kOmega + kK));
    int k = 0;
    for (int i = 0; i < kK; ++i) {
        for (int j = 0; j < 256; ++j) {
            if (h->v[i][j] != 0) sig[k++] = static_cast<unsigned char>(j);
        }
        sig[kOmega + i] = static_cast<unsigned char>(k);
    }
}

/* Returns 1 on a malformed signature. The checks are not decoration:
 * a hint list that is unsorted or over-long, or padding that is not
 * zero, would let one signature be re-encoded several ways, and a
 * verifier that accepted them would accept a mauled signature. */
int unpack_sig(unsigned char *c, PolyVecL *z, PolyVecK *h,
               const unsigned char *sig) {
    std::memcpy(c, sig, static_cast<size_t>(kCtildeBytes));
    sig += kCtildeBytes;
    for (int i = 0; i < kL; ++i) {
        polyz_unpack(z->v[i], sig + i * kPolyZPacked);
    }
    sig += kL * kPolyZPacked;
    int k = 0;
    for (int i = 0; i < kK; ++i) {
        for (int j = 0; j < 256; ++j) h->v[i][j] = 0;
        if (sig[kOmega + i] < k || sig[kOmega + i] > kOmega) return 1;
        for (int j = k; j < sig[kOmega + i]; ++j) {
            /* strictly increasing, so the encoding is canonical */
            if (j > k && sig[j] <= sig[j - 1]) return 1;
            h->v[i][sig[j]] = 1;
        }
        k = sig[kOmega + i];
    }
    /* the unused tail must be zero */
    for (int j = k; j < kOmega; ++j) if (sig[j]) return 1;
    return 0;
}

/* ---------------------------------------------------------------------
 * FIPS 204 keypair, sign and verify.
 * ------------------------------------------------------------------ */

void keypair_from_seed(unsigned char *pk, unsigned char *sk,
                       const unsigned char seed[32]) {
    unsigned char seedbuf[2 * 32 + 64];
    unsigned char pre[34];
    std::memcpy(pre, seed, 32);
    /* the parameter set is bound into the seed expansion, so the same
     * 32 bytes cannot produce a key for two different parameter sets */
    pre[32] = static_cast<unsigned char>(kK);
    pre[33] = static_cast<unsigned char>(kL);
    rmbl_shake256(seedbuf, sizeof seedbuf, pre, 34);
    RMBL_MLDSA_DECLASSIFY(seedbuf, 32); /* rho is published in pk */
    const unsigned char *rho = seedbuf;
    const unsigned char *rhoprime = seedbuf + 32;
    const unsigned char *key = rhoprime + 64;

    PolyVecL mat[kK];
    PolyVecL s1, s1hat;
    PolyVecK s2, t1, t0;
    matrix_expand(mat, rho);
    vecl_uniform_eta(&s1, rhoprime, 0);
    veck_uniform_eta(&s2, rhoprime, static_cast<uint16_t>(kL));
    s1hat = s1;
    vecl_ntt(&s1hat);
    matrix_pointwise_montgomery(&t1, mat, &s1hat);
    veck_reduce(&t1);
    veck_invntt(&t1);
    veck_add(&t1, &t1, &s2);
    veck_caddq(&t1);
    veck_power2round(&t1, &t0, &t1);
    pack_pk(pk, rho, &t1);
    unsigned char tr[64];
    rmbl_shake256(tr, static_cast<size_t>(kTrBytes), pk,
                  static_cast<size_t>(kPkBytes));
    pack_sk(sk, rho, tr, key, &t0, &s1, &s2);
    rmbl_ct::wipe(seedbuf, sizeof seedbuf);
    rmbl_ct::wipe(pre, sizeof pre);
    rmbl_ct::wipe(&s1, sizeof s1);
    rmbl_ct::wipe(&s2, sizeof s2);
    rmbl_ct::wipe(&s1hat, sizeof s1hat);
    rmbl_ct::wipe(&t0, sizeof t0);
}

/* `rnd` is the 32 bytes of per-signature randomness. Passing zeros
 * gives the deterministic variant, which is what the KATs use and what
 * makes this checkable against another implementation at all. */
/* FIPS 204's ML-DSA.Sign is the INTERNAL routine with a domain
 * separator prepended to the message hash:
 *
 *   mu = CRH(tr, 0x00 || len(ctx) || ctx, M)
 *
 * Omitting it produces signatures that match pq-crystals'
 * crypto_sign_signature_INTERNAL byte for byte and that liboqs, which
 * implements the standard, correctly refuses. The reference parity
 * alone would have shipped something non-interoperable; only the
 * cross-check against the library being replaced caught it.
 */
/* mu = CRH(tr, M'), where M' is
 *
 *   pure:      0x00 || |ctx| || ctx || M
 *   pre-hashed: 0x01 || |ctx| || ctx || OID(PH) || PH(M)
 *
 * The leading byte is the domain separator FIPS 204 section 5.4 adds,
 * and it is what stops a pre-hashed signature from being presented as a
 * pure one over the digest bytes.
 *
 * `oid` is the DER-encoded object identifier of the pre-hash function,
 * supplied by the caller because the choice of pre-hash is the caller's
 * and the standard binds the identifier rather than the output length.
 */
void compute_mu(unsigned char mu[64], const unsigned char tr[64],
                const unsigned char *m, size_t mlen,
                const unsigned char *ctx, size_t ctxlen,
                const unsigned char *oid, size_t oidlen) {
    RmblKeccak st;
    rmbl_keccak_init(&st, 136, 0x1f);
    rmbl_keccak_absorb(&st, tr, static_cast<size_t>(kTrBytes));
    unsigned char pre[2];
    pre[0] = (oidlen > 0) ? 1 : 0;
    pre[1] = static_cast<unsigned char>(ctxlen);
    rmbl_keccak_absorb(&st, pre, 2);
    if (ctxlen > 0) rmbl_keccak_absorb(&st, ctx, ctxlen);
    if (oidlen > 0) rmbl_keccak_absorb(&st, oid, oidlen);
    rmbl_keccak_absorb(&st, m, mlen);
    rmbl_keccak_finalize(&st);
    rmbl_keccak_squeeze(&st, mu, static_cast<size_t>(kCrhBytes));
}

/* tr = H(pk, 64). A verifier holding only the public key needs this to
 * reach mu, which is why external-mu verification is possible at all. */
void tr_from_pk(unsigned char tr[64], const unsigned char *pk) {
    rmbl_shake256(tr, static_cast<size_t>(kTrBytes), pk,
                  static_cast<size_t>(kPkBytes));
}

/* Sign a message digest mu that was computed elsewhere -- the
 * ExternalMu-ML-DSA interface. It exists so a device holding the key
 * never has to receive the message: everything below this point uses
 * only mu. */
int sign_mu(unsigned char *sig, const unsigned char mu[64],
             const unsigned char rnd[32], const unsigned char *sk);

int verify_mu(const unsigned char *sig, const unsigned char mu[64],
              const unsigned char *pk);

int sign_internal(unsigned char *sig, const unsigned char *m, size_t mlen,
                   const unsigned char *ctx, size_t ctxlen,
                   const unsigned char rnd[32], const unsigned char *sk) {
    /* only tr is needed up here, and it sits at a fixed offset: the
     * secret key is rho || K || tr || s1 || s2 || t0 */
    unsigned char mu[64];
    compute_mu(mu, sk + 64, m, mlen, ctx, ctxlen, NULL, 0);
    return sign_mu(sig, mu, rnd, sk);
}

/* The pre-hashed variant, HashML-DSA. Identical below mu. */
int sign_prehash(unsigned char *sig, const unsigned char *phm, size_t phlen,
                  const unsigned char *ctx, size_t ctxlen,
                  const unsigned char *oid, size_t oidlen,
                  const unsigned char rnd[32], const unsigned char *sk) {
    unsigned char mu[64];
    compute_mu(mu, sk + 64, phm, phlen, ctx, ctxlen, oid, oidlen);
    return sign_mu(sig, mu, rnd, sk);
}

int sign_mu(unsigned char *sig, const unsigned char mu[64],
            const unsigned char rnd[32], const unsigned char *sk) {
    unsigned char rho[32], tr[64], key[32], rhoprime[64];
    PolyVecL mat[kK], s1, y, z;
    PolyVecK t0, s2, w1, w0, h;
    int32_t cp[256];
    rmbl_ct::Guard gkey(key, sizeof key), grp(rhoprime, sizeof rhoprime),
        gs1(&s1, sizeof s1), gy(&y, sizeof y), gz(&z, sizeof z),
        gt0(&t0, sizeof t0), gs2(&s2, sizeof s2), gw0(&w0, sizeof w0);
    unpack_sk(rho, tr, key, &t0, &s1, &s2, sk);
    RMBL_MLDSA_DECLASSIFY(rho, 32); /* rho is published in pk */
    /* A key that is the right length but not a key: s1 and s2 are packed in
     * [-eta, eta], so a coefficient outside it can only come from corrupt
     * bytes. Signing with it would reject every candidate for ever. */
    if (vecl_chknorm(&s1, kEta + 1) || veck_chknorm(&s2, kEta + 1)) return -1;

    RmblKeccak st;
    /* rhoprime = CRH(key, rnd, mu) */
    rmbl_keccak_init(&st, 136, 0x1f);
    rmbl_keccak_absorb(&st, key, 32);
    rmbl_keccak_absorb(&st, rnd, 32);
    rmbl_keccak_absorb(&st, mu, static_cast<size_t>(kCrhBytes));
    rmbl_keccak_finalize(&st);
    rmbl_keccak_squeeze(&st, rhoprime, static_cast<size_t>(kCrhBytes));

    matrix_expand(mat, rho);
    vecl_ntt(&s1);
    veck_ntt(&s2);
    veck_ntt(&t0);

    uint16_t nonce = 0;
    for (int attempt = 0; attempt < rmbl_mldsa_core::kMaxSignAttempts; ++attempt) {
        vecl_uniform_gamma1(&y, rhoprime, nonce++);
        z = y;
        vecl_ntt(&z);
        matrix_pointwise_montgomery(&w1, mat, &z);
        veck_reduce(&w1);
        veck_invntt(&w1);
        veck_caddq(&w1);
        veck_decompose(&w1, &w0, &w1);
        veck_pack_w1(sig, &w1);

        rmbl_keccak_init(&st, 136, 0x1f);
        rmbl_keccak_absorb(&st, mu, static_cast<size_t>(kCrhBytes));
        rmbl_keccak_absorb(&st, sig,
                           static_cast<size_t>(kK * kPolyW1Packed));
        rmbl_keccak_finalize(&st);
        rmbl_keccak_squeeze(&st, sig, static_cast<size_t>(kCtildeBytes));
        RMBL_MLDSA_DECLASSIFY(sig, static_cast<size_t>(kCtildeBytes)); /* c~ is the signature's first field */

        poly_challenge(cp, sig);
        ntt(cp);

        vecl_pointwise_poly(&z, cp, &s1);
        vecl_invntt(&z);
        vecl_add(&z, &z, &y);
        vecl_reduce(&z);
        if (vecl_chknorm(&z, kGamma1 - kBeta)) continue;

        veck_pointwise_poly(&h, cp, &s2);
        veck_invntt(&h);
        veck_sub(&w0, &w0, &h);
        veck_reduce(&w0);
        if (veck_chknorm(&w0, kGamma2 - kBeta)) continue;

        veck_pointwise_poly(&h, cp, &t0);
        veck_invntt(&h);
        veck_reduce(&h);
        if (veck_chknorm(&h, kGamma2)) continue;

        veck_add(&w0, &w0, &h);
        unsigned int n = veck_make_hint(&h, &w0, &w1);
        RMBL_MLDSA_DECLASSIFY(&n, sizeof n); /* the hint count and positions are published */
        RMBL_MLDSA_DECLASSIFY(&h, sizeof h);
        if (n > static_cast<unsigned int>(kOmega)) continue;

        pack_sig(sig, sig, &z, &h);
        return 0;
    }
    return -1;  /* a sound key accepts within a handful of attempts */
}


/* =====================================================================
 * First-order masked signing: FIPS 204 ML-DSA.Sign_internal with every
 * value that depends on the secret key or on y held as two shares.
 *
 * s1, s2, t0 and the key K are split into fresh shares as soon as they
 * are unpacked; y comes out of a masked SHAKE256 (rho'' itself from a
 * masked SHAKE256 over K's shares) as Boolean shares of its packed bits,
 * converted to arithmetic shares mod q (rmbl_masked.h, sec_b2a). The
 * linear algebra (NTT, A*y, c*s1, c*s2, c*t0) runs on each share in its
 * own pass. Four things are unmasked, each a value the algorithm
 * publishes or one bit of control flow it already reveals:
 *
 *   - w1 = HighBits(w): it is hashed into the challenge, and a verifier
 *     recomputes it from the signature. It is revealed through per-lane
 *     comparisons whose outcomes are exactly the bits of w1;
 *   - the three rejection decisions (||z||, ||r0||, ||c t0||), each as a
 *     single bit: the AND of the masked per-coefficient tests;
 *   - HighBits(w - c s2 + c t0), from which the hint is computed: the
 *     verifier recomputes it too (it is HighBits(A z - c t1 2^d));
 *   - z, once the signature is accepted and z is part of it.
 *
 * The output is byte-identical to sign_mu(): the same rho'', the same y,
 * the same accept/reject decisions (tests compare the two).
 * ===================================================================== */
namespace msk {

using rmbl_masked::Bs;
using rmbl_masked::Rng;
using rmbl_masked::kDsa;

const int32_t kHigh = (kQ - 1) / (2 * kGamma2);   /* 44 or 16 values of HighBits */
#if MLDSA_GAMMA1 == (1 << 17)
const int kZBits = 18;
#else
const int kZBits = 20;
#endif

inline int32_t canon(int32_t a) { return caddq(reduce32(a)); }

template <class V>
inline void canon_all(V *v) {
    int32_t *p = &v->v[0][0];
    for (size_t i = 0; i < sizeof(V) / sizeof(int32_t); ++i) p[i] = canon(p[i]);
}

/* fresh arithmetic shares of every coefficient of v */
template <class V>
inline void split(V *v0, V *v1, const V *v, Rng &rng) {
    const int32_t *p = &v->v[0][0];
    int32_t *p0 = &v0->v[0][0], *p1 = &v1->v[0][0];
    for (size_t i = 0; i < sizeof(V) / sizeof(int32_t); ++i) {
        const int32_t r = rmbl_masked::rand_mod(rng, kQ);
        p0[i] = r;
        p1[i] = rmbl_masked::cadd_mod(canon(p[i]) - r, kQ);
    }
}

/* y for one polynomial from the masked rho'': SHAKE256(rho'' || nonce) through the masked
 * sponge, unpacked bit by bit on each share (unpacking is linear over GF(2)), converted to
 * arithmetic shares and turned into gamma1 - value, as polyz_unpack does. */
inline void poly_gamma1(int32_t *a0, int32_t *a1, const unsigned char rp0[64],
                        const unsigned char rp1[64], uint16_t nonce, Rng &rng) {
    unsigned char in0[66], in1[66];
    std::memcpy(in0, rp0, 64);
    std::memcpy(in1, rp1, 64);
    in0[64] = static_cast<unsigned char>(nonce & 0xff);
    in0[65] = static_cast<unsigned char>(nonce >> 8);
    in1[64] = in1[65] = 0;
    unsigned char b0[kPolyZPacked], b1[kPolyZPacked];
    rmbl_ct::Guard g0(b0, sizeof b0), g1(b1, sizeof b1), gi0(in0, sizeof in0), gi1(in1, sizeof in1);
    rmbl_masked::sponge_masked(b0, b1, sizeof b0, in0, in1, sizeof in0, 136, 0x1f, rng);
    for (int g = 0; g < 8; ++g) {
        Bs v;
        for (int s = 0; s < 2; ++s) {
            const unsigned char *buf = s ? b1 : b0;
            for (int b = 0; b < kZBits; ++b) {
                uint32_t w = 0;
                for (int j = 0; j < 32; ++j) {
                    const size_t pos = static_cast<size_t>(32 * g + j) * kZBits + static_cast<size_t>(b);
                    w |= static_cast<uint32_t>((buf[pos >> 3] >> (pos & 7u)) & 1u) << j;
                }
                v.w[s][b] = w;
            }
            for (int b = kZBits; b < rmbl_masked::kMaxBits; ++b) v.w[s][b] = 0;
        }
        int32_t c0[32], c1[32];
        rmbl_masked::sec_b2a(c0, c1, v, rng, kDsa);
        for (int j = 0; j < 32; ++j) {
            a0[32 * g + j] = rmbl_masked::cadd_mod(kGamma1 - c0[j], kQ);
            a1[32 * g + j] = rmbl_masked::cadd_mod(-c1[j], kQ);
        }
    }
}

/* b' for 32 lanes of a = a0 + a1 mod q, as Boolean shares: a + gamma2 - 1, less q - 1 when
 * that reaches q - 1. Then HighBits(a) = floor(b' / (2 gamma2)) for every a, the top
 * interval (which FIPS 204 Decompose folds to 0) included. */
inline void bprime(Bs &bp, const int32_t *a0, const int32_t *a1, Rng &rng) {
    Bs t, a, b, bm;
    rmbl_masked::share_sum(t, a0, a1, rng, kDsa);
    rmbl_masked::sec_reduce_q(a, t, rng, kDsa);
    int32_t c[32], nc[32];
    for (int j = 0; j < 32; ++j) {
        c[j] = kGamma2 - 1;
        nc[j] = (1 << kDsa.bits) - (kQ - 1);
    }
    rmbl_masked::sec_add_public(b, a, c, kDsa.bits, rng);
    rmbl_masked::sec_add_public(bm, b, nc, kDsa.bits, rng);
    uint32_t s0, s1;
    rmbl_masked::sec_less_const(s0, s1, b, kQ - 1, rng, kDsa);
    rmbl_masked::sec_select(bp, s0, s1, b, bm, kDsa.bits, rng);
}

/* HighBits per lane, revealed by a binary search whose comparisons each reveal one bit of
 * the result and nothing else. */
inline void reveal_highbits(int32_t *w1, const Bs &bp, Rng &rng) {
    for (int j = 0; j < 32; ++j) w1[j] = 0;
    for (int p = 32; p >= 1; p >>= 1) {
        int32_t thr[32];
        for (int j = 0; j < 32; ++j) {
            const int32_t c = w1[j] + p;
            thr[j] = c <= kHigh - 1 ? 2 * c * kGamma2 : (1 << (kDsa.bits - 1)) - 1;
        }
        uint32_t s0, s1;
        rmbl_masked::sec_less(s0, s1, bp, thr, rng, kDsa);
        uint32_t ge = ~(s0 ^ s1);   /* bits of w1, which the signature publishes */
        RMBL_MLDSA_DECLASSIFY(&ge, sizeof ge);
        for (int j = 0; j < 32; ++j) w1[j] += p & -static_cast<int32_t>((ge >> j) & 1u);
    }
}

/* Lane j set when LowBits(v) lies inside +-(gamma2 - beta - 1), given HighBits(v) == w1: the
 * r0 check of FIPS 204. If HighBits(v) differs from w1 the test fails, as the FIPS check
 * would (|LowBits| >= gamma2 - beta then). The top interval's low bits are one less than
 * b' - (gamma2 - 1) (Decompose subtracts one there), hence the bound beta + 1 at w1 = 0. */
inline void lowbits_ok(uint32_t &o0, uint32_t &o1, const Bs &bp, const int32_t *w1, Rng &rng) {
    int32_t lo[32], hi[32];
    for (int j = 0; j < 32; ++j) {
        const int32_t base = 2 * kGamma2 * w1[j];
        lo[j] = base + (w1[j] == 0 ? kBeta + 1 : kBeta);
        hi[j] = base + 2 * kGamma2 - kBeta - 1;
    }
    uint32_t a0, a1, b0, b1;
    rmbl_masked::sec_less(a0, a1, bp, lo, rng, kDsa);
    rmbl_masked::sec_less(b0, b1, bp, hi, rng, kDsa);
    rmbl_masked::sec_and(o0, o1, static_cast<uint32_t>(~a0), a1, b0, b1, rng.u32());
}

/* Shares of an all-lanes AND accumulated over a whole vector; reveals the one bit. */
struct AllOk {
    uint32_t a0 = 0xffffffffu, a1 = 0;
    void add(uint32_t o0, uint32_t o1, Rng &rng) {
        uint32_t z0, z1;
        rmbl_masked::sec_and(z0, z1, a0, a1, o0, o1, rng.u32());
        a0 = z0;
        a1 = z1;
    }
    int reveal(Rng &rng) const {
        uint32_t b0, b1;
        rmbl_masked::sec_all_lanes(b0, b1, a0, a1, rng);
        int ok = static_cast<int>((b0 ^ b1) & 1u);
        RMBL_MLDSA_DECLASSIFY(&ok, sizeof ok);   /* the accept/reject decision */
        return ok;
    }
};

/* ||a||_inf < B for every coefficient of a vector of shares */
template <class V>
inline int norm_ok(const V *m0, const V *m1, int32_t B, Rng &rng) {
    int32_t lo[32], w[32];
    for (int j = 0; j < 32; ++j) {
        lo[j] = kQ - B + 1;
        w[j] = 2 * B - 1;
    }
    AllOk acc;
    const int n = static_cast<int>(sizeof(V) / sizeof(int32_t));
    const int32_t *p0 = &m0->v[0][0], *p1 = &m1->v[0][0];
    for (int i = 0; i < n; i += 32) {
        uint32_t o0, o1;
        rmbl_masked::sec_in_interval(o0, o1, p0 + i, p1 + i, lo, w, rng, kDsa);
        acc.add(o0, o1, rng);
    }
    return acc.reveal(rng);
}

struct Work {
    PolyVecL s1[2], y[2], z[2];
    PolyVecK s2[2], t0[2], w[2], v[2], u[2];
};

}  // namespace msk

int sign_mu_masked(unsigned char *sig, const unsigned char mu[64],
                   const unsigned char rnd[32], const unsigned char *sk,
                   rmbl_masked::Rng &rng) {
    unsigned char rho[32], tr[64], key[32];
    unsigned char k0[32], k1[32], in0[128], in1[128], rp0[64], rp1[64];
    rmbl_ct::Guard gkey(key, sizeof key), gk0(k0, sizeof k0), gk1(k1, sizeof k1), gi0(in0, sizeof in0),
        gi1(in1, sizeof in1), gr0(rp0, sizeof rp0), gr1(rp1, sizeof rp1);
    std::vector<PolyVecL> mat(kK);
    std::vector<msk::Work> work(1);
    msk::Work &W = work[0];
    {
        PolyVecL s1;
        PolyVecK t0, s2;
        rmbl_ct::Guard gs1(&s1, sizeof s1), gs2(&s2, sizeof s2), gt0(&t0, sizeof t0);
        unpack_sk(rho, tr, key, &t0, &s1, &s2, sk);
        RMBL_MLDSA_DECLASSIFY(rho, 32); /* rho is published in pk */
        if (vecl_chknorm(&s1, kEta + 1) || veck_chknorm(&s2, kEta + 1)) return -1;
        msk::split(&W.s1[0], &W.s1[1], &s1, rng);
        msk::split(&W.s2[0], &W.s2[1], &s2, rng);
        msk::split(&W.t0[0], &W.t0[1], &t0, rng);
    }
    for (int i = 0; i < 32; ++i) {
        k0[i] = static_cast<unsigned char>(rng.u32());
        k1[i] = static_cast<unsigned char>(key[i] ^ k0[i]);
    }
    rmbl_ct::wipe(key, sizeof key);
    /* rho'' = H(K || rnd || mu), K masked; rnd and mu ride on share 0 */
    std::memcpy(in0, k0, 32);
    std::memcpy(in0 + 32, rnd, 32);
    std::memcpy(in0 + 64, mu, 64);
    std::memcpy(in1, k1, 32);
    std::memset(in1 + 32, 0, 96);
    rmbl_masked::sponge_masked(rp0, rp1, 64, in0, in1, 128, 136, 0x1f, rng);

    matrix_expand(mat.data(), rho);
    for (int s = 0; s < 2; ++s) {
        vecl_ntt(&W.s1[s]);
        veck_ntt(&W.s2[s]);
        veck_ntt(&W.t0[s]);
    }

    PolyVecK w1, hu, h;
    PolyVecL zp;
    int32_t cp[256];
    RmblKeccak st;
    uint16_t nonce = 0;
    int rc = -1;
    for (int attempt = 0; attempt < rmbl_mldsa_core::kMaxSignAttempts; ++attempt) {
        for (int i = 0; i < kL; ++i) {
            msk::poly_gamma1(W.y[0].v[i], W.y[1].v[i], rp0, rp1, static_cast<uint16_t>(kL * nonce + i), rng);
        }
        ++nonce;
        for (int s = 0; s < 2; ++s) {
            W.z[s] = W.y[s];
            vecl_ntt(&W.z[s]);
            matrix_pointwise_montgomery(&W.w[s], mat.data(), &W.z[s]);
            veck_reduce(&W.w[s]);
            veck_invntt(&W.w[s]);
            msk::canon_all(&W.w[s]);
        }
        for (int i = 0; i < kK; ++i) {
            for (int g = 0; g < 8; ++g) {
                rmbl_masked::Bs bp;
                msk::bprime(bp, &W.w[0].v[i][32 * g], &W.w[1].v[i][32 * g], rng);
                msk::reveal_highbits(&w1.v[i][32 * g], bp, rng);
            }
        }
        veck_pack_w1(sig, &w1);
        rmbl_keccak_init(&st, 136, 0x1f);
        rmbl_keccak_absorb(&st, mu, static_cast<size_t>(kCrhBytes));
        rmbl_keccak_absorb(&st, sig, static_cast<size_t>(kK * kPolyW1Packed));
        rmbl_keccak_finalize(&st);
        rmbl_keccak_squeeze(&st, sig, static_cast<size_t>(kCtildeBytes));
        RMBL_MLDSA_DECLASSIFY(sig, static_cast<size_t>(kCtildeBytes)); /* c~ is the signature's first field */
        poly_challenge(cp, sig);
        ntt(cp);

        /* z = y + c s1 */
        for (int s = 0; s < 2; ++s) {
            vecl_pointwise_poly(&W.z[s], cp, &W.s1[s]);
            vecl_invntt(&W.z[s]);
            vecl_add(&W.z[s], &W.z[s], &W.y[s]);
            msk::canon_all(&W.z[s]);
        }
        if (!msk::norm_ok(&W.z[0], &W.z[1], kGamma1 - kBeta, rng)) continue;

        /* v = w - c s2, and its low bits */
        for (int s = 0; s < 2; ++s) {
            veck_pointwise_poly(&W.v[s], cp, &W.s2[s]);
            veck_invntt(&W.v[s]);
            veck_sub(&W.v[s], &W.w[s], &W.v[s]);
            msk::canon_all(&W.v[s]);
        }
        {
            msk::AllOk acc;
            for (int i = 0; i < kK; ++i) {
                for (int g = 0; g < 8; ++g) {
                    rmbl_masked::Bs bp;
                    msk::bprime(bp, &W.v[0].v[i][32 * g], &W.v[1].v[i][32 * g], rng);
                    uint32_t o0, o1;
                    msk::lowbits_ok(o0, o1, bp, &w1.v[i][32 * g], rng);
                    acc.add(o0, o1, rng);
                }
            }
            if (!acc.reveal(rng)) continue;
        }

        /* c t0 */
        for (int s = 0; s < 2; ++s) {
            veck_pointwise_poly(&W.u[s], cp, &W.t0[s]);
            veck_invntt(&W.u[s]);
            msk::canon_all(&W.u[s]);
        }
        if (!msk::norm_ok(&W.u[0], &W.u[1], kGamma2, rng)) continue;

        /* the hint: HighBits(w - c s2 + c t0) against w1 */
        for (int s = 0; s < 2; ++s) {
            veck_add(&W.u[s], &W.v[s], &W.u[s]);
            msk::canon_all(&W.u[s]);
        }
        unsigned int n = 0;
        for (int i = 0; i < kK; ++i) {
            for (int g = 0; g < 8; ++g) {
                rmbl_masked::Bs bp;
                msk::bprime(bp, &W.u[0].v[i][32 * g], &W.u[1].v[i][32 * g], rng);
                msk::reveal_highbits(&hu.v[i][32 * g], bp, rng);
            }
            for (int j = 0; j < 256; ++j) {
                h.v[i][j] = hu.v[i][j] != w1.v[i][j] ? 1 : 0;
                n += static_cast<unsigned int>(h.v[i][j]);
            }
        }
        if (n > static_cast<unsigned int>(kOmega)) continue;

        /* accepted: z is part of the signature */
        for (int i = 0; i < kL; ++i) {
            for (int j = 0; j < 256; ++j) {
                int32_t zz = W.z[0].v[i][j] + W.z[1].v[i][j];
                zz -= kQ & -static_cast<int32_t>(zz >= kQ);
                zz -= kQ & -static_cast<int32_t>(zz > (kQ - 1) / 2);
                zp.v[i][j] = zz;
            }
        }
        RMBL_MLDSA_DECLASSIFY(&zp, sizeof zp);
        pack_sig(sig, sig, &zp, &h);
        rc = 0;
        break;
    }
    rmbl_ct::wipe(&W, sizeof W);
    return rc;
}

/* The masked variants of the two signing interfaces above mu. */
int sign_internal_masked(unsigned char *sig, const unsigned char *m, size_t mlen,
                         const unsigned char *ctx, size_t ctxlen,
                         const unsigned char rnd[32], const unsigned char *sk,
                         rmbl_masked::Rng &rng) {
    unsigned char mu[64];
    compute_mu(mu, sk + 64, m, mlen, ctx, ctxlen, NULL, 0);
    return sign_mu_masked(sig, mu, rnd, sk, rng);
}

int sign_prehash_masked(unsigned char *sig, const unsigned char *phm, size_t phlen,
                        const unsigned char *ctx, size_t ctxlen,
                        const unsigned char *oid, size_t oidlen,
                        const unsigned char rnd[32], const unsigned char *sk,
                        rmbl_masked::Rng &rng) {
    unsigned char mu[64];
    compute_mu(mu, sk + 64, phm, phlen, ctx, ctxlen, oid, oidlen);
    return sign_mu_masked(sig, mu, rnd, sk, rng);
}

int verify_internal(const unsigned char *sig, const unsigned char *m,
                    size_t mlen, const unsigned char *ctx, size_t ctxlen,
                    const unsigned char *pk) {
    unsigned char tr[64], mu[64];
    tr_from_pk(tr, pk);
    compute_mu(mu, tr, m, mlen, ctx, ctxlen, NULL, 0);
    return verify_mu(sig, mu, pk);
}

int verify_prehash(const unsigned char *sig, const unsigned char *phm,
                   size_t phlen, const unsigned char *ctx, size_t ctxlen,
                   const unsigned char *oid, size_t oidlen,
                   const unsigned char *pk) {
    unsigned char tr[64], mu[64];
    tr_from_pk(tr, pk);
    compute_mu(mu, tr, phm, phlen, ctx, ctxlen, oid, oidlen);
    return verify_mu(sig, mu, pk);
}

int verify_mu(const unsigned char *sig, const unsigned char mu[64],
              const unsigned char *pk) {
    unsigned char rho[32], c[64], c2[64];
    unsigned char buf[kK * kPolyW1Packed];
    PolyVecL mat[kK], z;
    PolyVecK t1, w1, h;
    int32_t cp[256];

    unpack_pk(rho, &t1, pk);
    if (unpack_sig(c, &z, &h, sig)) return -1;
    if (vecl_chknorm(&z, kGamma1 - kBeta)) return -1;

    RmblKeccak st;
    poly_challenge(cp, c);
    matrix_expand(mat, rho);
    vecl_ntt(&z);
    matrix_pointwise_montgomery(&w1, mat, &z);
    ntt(cp);
    veck_shiftl(&t1);
    veck_ntt(&t1);
    veck_pointwise_poly(&t1, cp, &t1);
    veck_sub(&w1, &w1, &t1);
    veck_reduce(&w1);
    veck_invntt(&w1);
    veck_caddq(&w1);
    veck_use_hint(&w1, &w1, &h);
    veck_pack_w1(buf, &w1);

    rmbl_keccak_init(&st, 136, 0x1f);
    rmbl_keccak_absorb(&st, mu, static_cast<size_t>(kCrhBytes));
    rmbl_keccak_absorb(&st, buf, sizeof buf);
    rmbl_keccak_finalize(&st);
    rmbl_keccak_squeeze(&st, c2, static_cast<size_t>(kCtildeBytes));
    /* constant-time-ish comparison: no early exit on the first
     * differing byte */
    unsigned char diff = 0;
    for (int i = 0; i < kCtildeBytes; ++i) diff |= c[i] ^ c2[i];
    return diff == 0 ? 0 : -1;
}

}  // namespace MLDSA_NS
