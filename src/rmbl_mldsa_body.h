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
#if MLDSA_ETA == 2
        if (t0 < 15) {
            t0 = t0 - (205 * t0 >> 10) * 5;
            a[ctr++] = 2 - static_cast<int32_t>(t0);
        }
        if (t1 < 15 && ctr < len) {
            t1 = t1 - (205 * t1 >> 10) * 5;
            a[ctr++] = 2 - static_cast<int32_t>(t1);
        }
#else
        if (t0 < 9) a[ctr++] = 4 - static_cast<int32_t>(t0);
        if (t1 < 9 && ctr < len) a[ctr++] = 4 - static_cast<int32_t>(t1);
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
    std::memcpy(ext, seed, 64);
    ext[64] = static_cast<unsigned char>(nonce & 0xff);
    ext[65] = static_cast<unsigned char>(nonce >> 8);
    RmblKeccak st;
    rmbl_keccak_init(&st, 136, 0x1f);
    rmbl_keccak_absorb(&st, ext, 66);
    rmbl_keccak_finalize(&st);
    unsigned char buf[136 * 2];
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
 * comparison is written branch-free on the sign bit because it runs on
 * secret data during signing, and a data-dependent branch there is a
 * timing side channel. */
inline int poly_chknorm(const int32_t a[256], int32_t B) {
    if (B > (kQ - 1) / 8) return 1;
    for (int i = 0; i < 256; ++i) {
        int32_t t = a[i] >> 31;
        t = a[i] - (t & 2 * a[i]);
        if (t >= B) return 1;
    }
    return 0;
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
    std::memcpy(sig, c, static_cast<size_t>(kCtildeBytes));
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
void sign_mu(unsigned char *sig, const unsigned char mu[64],
             const unsigned char rnd[32], const unsigned char *sk);

int verify_mu(const unsigned char *sig, const unsigned char mu[64],
              const unsigned char *pk);

void sign_internal(unsigned char *sig, const unsigned char *m, size_t mlen,
                   const unsigned char *ctx, size_t ctxlen,
                   const unsigned char rnd[32], const unsigned char *sk) {
    /* only tr is needed up here, and it sits at a fixed offset: the
     * secret key is rho || K || tr || s1 || s2 || t0 */
    unsigned char mu[64];
    compute_mu(mu, sk + 64, m, mlen, ctx, ctxlen, NULL, 0);
    sign_mu(sig, mu, rnd, sk);
}

/* The pre-hashed variant, HashML-DSA. Identical below mu. */
void sign_prehash(unsigned char *sig, const unsigned char *phm, size_t phlen,
                  const unsigned char *ctx, size_t ctxlen,
                  const unsigned char *oid, size_t oidlen,
                  const unsigned char rnd[32], const unsigned char *sk) {
    unsigned char mu[64];
    compute_mu(mu, sk + 64, phm, phlen, ctx, ctxlen, oid, oidlen);
    sign_mu(sig, mu, rnd, sk);
}

void sign_mu(unsigned char *sig, const unsigned char mu[64],
             const unsigned char rnd[32], const unsigned char *sk) {
    unsigned char rho[32], tr[64], key[32], rhoprime[64];
    PolyVecL mat[kK], s1, y, z;
    PolyVecK t0, s2, w1, w0, h;
    int32_t cp[256];
    unpack_sk(rho, tr, key, &t0, &s1, &s2, sk);

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
    for (;;) {
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
        const unsigned int n = veck_make_hint(&h, &w0, &w1);
        if (n > static_cast<unsigned int>(kOmega)) continue;

        pack_sig(sig, sig, &z, &h);
        return;
    }
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
