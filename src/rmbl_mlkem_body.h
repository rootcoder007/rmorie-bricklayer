/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * The parameter-dependent half of ML-KEM (FIPS 203). Included once per
 * parameter set, with MLKEM_NS and the MLKEM_* parameters defined by
 * the includer -- deliberately NOT guarded against multiple inclusion.
 *
 * Requires: MLKEM_NS, MLKEM_K, MLKEM_ETA1, MLKEM_DU, MLKEM_DV.
 * (eta2 is 2 in every parameter set, so it is not a parameter.)
 */

namespace MLKEM_NS {

using rmbl_mlkem_core::kQ;
using rmbl_mlkem_core::montgomery_reduce;
using rmbl_mlkem_core::barrett_reduce;
using rmbl_mlkem_core::to_positive;
using rmbl_mlkem_core::ntt;
using rmbl_mlkem_core::invntt;
using rmbl_mlkem_core::poly_basemul;

const int kK = MLKEM_K;
const int kEta1 = MLKEM_ETA1;
const int kEta2 = 2;
const int kDu = MLKEM_DU;
const int kDv = MLKEM_DV;

const int kPolyBytes = 384;                       /* 12 bits x 256 */
const int kPolyCompressedU = 32 * kDu;
const int kPolyCompressedV = 32 * kDv;
const int kEkBytes = kK * kPolyBytes + 32;        /* t-hat, then rho */
const int kDkPkeBytes = kK * kPolyBytes;
const int kDkBytes = kDkPkeBytes + kEkBytes + 32 + 32;
const int kCtBytes = kK * kPolyCompressedU + kPolyCompressedV;
const int kSeedBytes = 64;                        /* d || z */
const int kSharedBytes = 32;

typedef int16_t Poly[256];
struct PolyVec { int16_t v[kK][256]; };

/* ------------------------------------------------------------------ *
 * Compression. Each coefficient is rounded to d bits, which is where
 * ML-KEM's ciphertext size comes from and where its decryption failure
 * probability comes from. The rounding is  round(2^d / q * x)  mod 2^d,
 * done with integer arithmetic because a floating-point round here
 * would be platform-dependent.
 * ------------------------------------------------------------------ */
inline uint16_t compress(int16_t x, int d) {
    uint32_t t = static_cast<uint32_t>(
        to_positive(barrett_reduce(x)));
    /* (t << d) / q, rounded to nearest, via the reference's
     * multiply-shift form */
    t = (((t << d) + kQ / 2) / kQ) & ((1u << d) - 1u);
    return static_cast<uint16_t>(t);
}

inline int16_t decompress(uint16_t x, int d) {
    return static_cast<int16_t>(
        ((static_cast<uint32_t>(x) * kQ) + (1u << (d - 1))) >> d);
}

/* ByteEncode_d / ByteDecode_d, for the widths ML-KEM uses. Written as a
 * bit cursor rather than per-width shifts: the widths are 1, 4, 5, 10,
 * 11 and 12 across the parameter sets, and six hand-unrolled pairs is
 * six places for a shift to be wrong. */
inline void byte_encode(unsigned char *out, const int16_t *a, int d,
                        bool canonical) {
    size_t bit = 0;
    std::memset(out, 0, (static_cast<size_t>(d) * 256u) / 8u);
    for (int i = 0; i < 256; ++i) {
        uint32_t v = canonical
            ? static_cast<uint32_t>(to_positive(barrett_reduce(a[i])))
            : static_cast<uint32_t>(a[i]) & ((1u << d) - 1u);
        for (int b = 0; b < d; ++b) {
            if ((v >> b) & 1u) {
                out[(bit + static_cast<size_t>(b)) >> 3] =
                    static_cast<unsigned char>(
                        out[(bit + static_cast<size_t>(b)) >> 3] |
                        (1u << ((bit + static_cast<size_t>(b)) & 7u)));
            }
        }
        bit += static_cast<size_t>(d);
    }
}

inline void byte_decode(int16_t *a, const unsigned char *in, int d) {
    size_t bit = 0;
    for (int i = 0; i < 256; ++i) {
        uint32_t v = 0;
        for (int b = 0; b < d; ++b) {
            const size_t p = bit + static_cast<size_t>(b);
            v |= static_cast<uint32_t>((in[p >> 3] >> (p & 7u)) & 1u) << b;
        }
        a[i] = static_cast<int16_t>(v);
        bit += static_cast<size_t>(d);
    }
}

/* ------------------------------------------------------------------ *
 * Sampling.
 * ------------------------------------------------------------------ */

/* SampleNTT: uniform on Z_q, three bytes giving two twelve-bit
 * candidates, each kept only if below q. The rejection is what makes
 * the distribution uniform rather than biased toward small values. */
inline void sample_ntt(int16_t a[256], const unsigned char rho[32],
                       unsigned char i, unsigned char j) {
    unsigned char seed[34];
    std::memcpy(seed, rho, 32);
    seed[32] = i;
    seed[33] = j;
    RmblKeccak st;
    rmbl_keccak_init(&st, 168, 0x1f);
    rmbl_keccak_absorb(&st, seed, 34);
    rmbl_keccak_finalize(&st);
    unsigned char buf[168];
    int ctr = 0;
    while (ctr < 256) {
        rmbl_keccak_squeeze(&st, buf, sizeof buf);
        for (size_t p = 0; p + 3 <= sizeof buf && ctr < 256; p += 3) {
            const uint16_t d1 = static_cast<uint16_t>(
                buf[p] | (static_cast<uint16_t>(buf[p + 1] & 0x0F) << 8));
            const uint16_t d2 = static_cast<uint16_t>(
                (buf[p + 1] >> 4) | (static_cast<uint16_t>(buf[p + 2]) << 4));
            if (d1 < static_cast<uint16_t>(kQ)) {
                a[ctr++] = static_cast<int16_t>(d1);
            }
            if (d2 < static_cast<uint16_t>(kQ) && ctr < 256) {
                a[ctr++] = static_cast<int16_t>(d2);
            }
        }
    }
}

/* SamplePolyCBD_eta: the centred binomial distribution, as the
 * difference of two eta-bit population counts. */
inline void sample_cbd(int16_t a[256], const unsigned char *buf, int eta) {
    size_t bit = 0;
    for (int i = 0; i < 256; ++i) {
        int x = 0, y = 0;
        for (int b = 0; b < eta; ++b) {
            x += (buf[(bit) >> 3] >> (bit & 7u)) & 1u;
            ++bit;
        }
        for (int b = 0; b < eta; ++b) {
            y += (buf[(bit) >> 3] >> (bit & 7u)) & 1u;
            ++bit;
        }
        a[i] = static_cast<int16_t>(x - y);
    }
}

inline void prf_cbd(int16_t a[256], const unsigned char sigma[32],
                    unsigned char nonce, int eta) {
    unsigned char seed[33];
    std::memcpy(seed, sigma, 32);
    seed[32] = nonce;
    std::vector<unsigned char> buf(static_cast<size_t>(64) * eta);
    rmbl_shake256(buf.data(), buf.size(), seed, 33);
    sample_cbd(a, buf.data(), eta);
}

/* ------------------------------------------------------------------ *
 * Polynomial and vector helpers.
 * ------------------------------------------------------------------ */
inline void poly_add(int16_t r[256], const int16_t a[256],
                     const int16_t b[256]) {
    for (int i = 0; i < 256; ++i) {
        r[i] = static_cast<int16_t>(a[i] + b[i]);
    }
}
inline void poly_sub(int16_t r[256], const int16_t a[256],
                     const int16_t b[256]) {
    for (int i = 0; i < 256; ++i) {
        r[i] = static_cast<int16_t>(a[i] - b[i]);
    }
}
inline void poly_reduce(int16_t a[256]) {
    for (int i = 0; i < 256; ++i) a[i] = barrett_reduce(a[i]);
}

/* The inner product of two vectors in the NTT domain. */
inline void vec_dot(int16_t r[256], const PolyVec *a, const PolyVec *b) {
    int16_t t[256];
    poly_basemul(r, a->v[0], b->v[0]);
    for (int i = 1; i < kK; ++i) {
        poly_basemul(t, a->v[i], b->v[i]);
        poly_add(r, r, t);
    }
    poly_reduce(r);
}

/* A message bit becomes a coefficient of q/2: that gap is what survives
 * the noise, and what decryption rounds back to a bit. */
inline void poly_from_msg(int16_t a[256], const unsigned char msg[32]) {
    for (int i = 0; i < 32; ++i) {
        for (int j = 0; j < 8; ++j) {
            const int16_t mask = static_cast<int16_t>(
                -static_cast<int16_t>((msg[i] >> j) & 1));
            a[8 * i + j] = static_cast<int16_t>(mask & ((kQ + 1) / 2));
        }
    }
}

inline void poly_to_msg(unsigned char msg[32], const int16_t a[256]) {
    std::memset(msg, 0, 32);
    for (int i = 0; i < 32; ++i) {
        for (int j = 0; j < 8; ++j) {
            /* the nearest multiple of q/2, as one compressed bit */
            const uint16_t t = compress(a[8 * i + j], 1);
            msg[i] = static_cast<unsigned char>(msg[i] | (t << j));
        }
    }
}

/* ------------------------------------------------------------------ *
 * K-PKE, the public-key encryption ML-KEM is built from.
 * ------------------------------------------------------------------ */

/* A-hat[i][j] = SampleNTT(rho || j || i). The index order is the
 * standard's and it is transposed relative to the obvious reading: row
 * i, column j is seeded with j FIRST. Getting it the other way round
 * gives a scheme that encapsulates and decapsulates perfectly against
 * itself. */
inline void matrix_expand(PolyVec mat[kK], const unsigned char rho[32],
                          bool transposed) {
    for (int i = 0; i < kK; ++i) {
        for (int j = 0; j < kK; ++j) {
            if (transposed) {
                sample_ntt(mat[i].v[j], rho, static_cast<unsigned char>(i),
                           static_cast<unsigned char>(j));
            } else {
                sample_ntt(mat[i].v[j], rho, static_cast<unsigned char>(j),
                           static_cast<unsigned char>(i));
            }
        }
    }
}

void pke_keygen(unsigned char *ek, unsigned char *dk,
                const unsigned char d[32]) {
    unsigned char g[64];
    /* FIPS 203 appends k to d before hashing: without it the same seed
     * would give related keys at two different parameter sets. */
    unsigned char din[33];
    std::memcpy(din, d, 32);
    din[32] = static_cast<unsigned char>(kK);
    rmbl_sha3_512(g, din, 33);
    const unsigned char *rho = g;
    const unsigned char *sigma = g + 32;

    PolyVec mat[kK], s, e, t;
    matrix_expand(mat, rho, false);
    unsigned char nonce = 0;
    for (int i = 0; i < kK; ++i) prf_cbd(s.v[i], sigma, nonce++, kEta1);
    for (int i = 0; i < kK; ++i) prf_cbd(e.v[i], sigma, nonce++, kEta1);
    for (int i = 0; i < kK; ++i) ntt(s.v[i]);
    for (int i = 0; i < kK; ++i) ntt(e.v[i]);

    for (int i = 0; i < kK; ++i) {
        vec_dot(t.v[i], &mat[i], &s);
        /* the product leaves a factor of 2^-16, which this removes */
        for (int j = 0; j < 256; ++j) {
            t.v[i][j] = montgomery_reduce(
                static_cast<int32_t>(t.v[i][j]) * 1353);
        }
        poly_add(t.v[i], t.v[i], e.v[i]);
        poly_reduce(t.v[i]);
    }

    for (int i = 0; i < kK; ++i) {
        byte_encode(ek + i * kPolyBytes, t.v[i], 12, true);
    }
    std::memcpy(ek + kK * kPolyBytes, rho, 32);
    for (int i = 0; i < kK; ++i) {
        byte_encode(dk + i * kPolyBytes, s.v[i], 12, true);
    }
}

/* Returns 1 if the encapsulation key is not a canonical encoding --
 * FIPS 203's modulus check. Without it a ciphertext could be produced
 * under a key whose coefficients exceed q, which is outside the
 * security argument. */
int pke_encrypt(unsigned char *ct, const unsigned char *ek,
                const unsigned char msg[32], const unsigned char coins[32]) {
    PolyVec mat[kK], t, r, e1, u;
    int16_t v[256], mp[256], e2[256];
    for (int i = 0; i < kK; ++i) {
        byte_decode(t.v[i], ek + i * kPolyBytes, 12);
        for (int j = 0; j < 256; ++j) {
            if (t.v[i][j] >= kQ) return 1;
        }
    }
    const unsigned char *rho = ek + kK * kPolyBytes;
    matrix_expand(mat, rho, true);

    unsigned char nonce = 0;
    for (int i = 0; i < kK; ++i) prf_cbd(r.v[i], coins, nonce++, kEta1);
    for (int i = 0; i < kK; ++i) prf_cbd(e1.v[i], coins, nonce++, kEta2);
    prf_cbd(e2, coins, nonce++, kEta2);
    for (int i = 0; i < kK; ++i) ntt(r.v[i]);

    for (int i = 0; i < kK; ++i) {
        vec_dot(u.v[i], &mat[i], &r);
        invntt(u.v[i]);
        poly_add(u.v[i], u.v[i], e1.v[i]);
        poly_reduce(u.v[i]);
    }
    vec_dot(v, &t, &r);
    invntt(v);
    poly_add(v, v, e2);
    poly_from_msg(mp, msg);
    poly_add(v, v, mp);
    poly_reduce(v);

    for (int i = 0; i < kK; ++i) {
        int16_t c[256];
        for (int j = 0; j < 256; ++j) {
            c[j] = static_cast<int16_t>(compress(u.v[i][j], kDu));
        }
        byte_encode(ct + i * kPolyCompressedU, c, kDu, false);
    }
    {
        int16_t c[256];
        for (int j = 0; j < 256; ++j) {
            c[j] = static_cast<int16_t>(compress(v[j], kDv));
        }
        byte_encode(ct + kK * kPolyCompressedU, c, kDv, false);
    }
    return 0;
}

void pke_decrypt(unsigned char msg[32], const unsigned char *dk,
                 const unsigned char *ct) {
    PolyVec u, s;
    int16_t v[256], w[256];
    for (int i = 0; i < kK; ++i) {
        int16_t c[256];
        byte_decode(c, ct + i * kPolyCompressedU, kDu);
        for (int j = 0; j < 256; ++j) {
            u.v[i][j] = decompress(static_cast<uint16_t>(c[j]), kDu);
        }
    }
    {
        int16_t c[256];
        byte_decode(c, ct + kK * kPolyCompressedU, kDv);
        for (int j = 0; j < 256; ++j) {
            v[j] = decompress(static_cast<uint16_t>(c[j]), kDv);
        }
    }
    for (int i = 0; i < kK; ++i) {
        byte_decode(s.v[i], dk + i * kPolyBytes, 12);
    }
    for (int i = 0; i < kK; ++i) ntt(u.v[i]);
    vec_dot(w, &s, &u);
    invntt(w);
    poly_sub(w, v, w);
    poly_reduce(w);
    poly_to_msg(msg, w);
}

/* ------------------------------------------------------------------ *
 * ML-KEM: K-PKE under the Fujisaki-Okamoto transform.
 * ------------------------------------------------------------------ */

void keygen(unsigned char *ek, unsigned char *dk,
            const unsigned char seed[64]) {
    pke_keygen(ek, dk, seed);
    std::memcpy(dk + kDkPkeBytes, ek, kEkBytes);
    rmbl_sha3_256(dk + kDkPkeBytes + kEkBytes, ek,
                  static_cast<size_t>(kEkBytes));
    /* z, the implicit-rejection secret. It never leaves the decapsulation
     * key and is what makes a bad ciphertext produce a wrong-but-real
     * shared secret rather than an error the attacker can observe. */
    std::memcpy(dk + kDkPkeBytes + kEkBytes + 32, seed + 32, 32);
}

int encaps(unsigned char *ct, unsigned char shared[32],
           const unsigned char *ek, const unsigned char m[32]) {
    unsigned char g_in[64], g[64];
    std::memcpy(g_in, m, 32);
    rmbl_sha3_256(g_in + 32, ek, static_cast<size_t>(kEkBytes));
    rmbl_sha3_512(g, g_in, 64);
    if (pke_encrypt(ct, ek, m, g + 32) != 0) return 1;
    std::memcpy(shared, g, 32);
    return 0;
}

void decaps(unsigned char shared[32], const unsigned char *dk,
            const unsigned char *ct) {
    const unsigned char *ek = dk + kDkPkeBytes;
    const unsigned char *h = dk + kDkPkeBytes + kEkBytes;
    const unsigned char *z = h + 32;
    unsigned char mp[32], g_in[64], g[64], kbar[32];
    std::vector<unsigned char> ct2(static_cast<size_t>(kCtBytes));

    pke_decrypt(mp, dk, ct);
    std::memcpy(g_in, mp, 32);
    std::memcpy(g_in + 32, h, 32);
    rmbl_sha3_512(g, g_in, 64);

    /* K-bar = J(z || c): the shared secret returned when the ciphertext
     * does not re-encrypt to itself. */
    std::vector<unsigned char> jin(32 + static_cast<size_t>(kCtBytes));
    std::memcpy(jin.data(), z, 32);
    std::memcpy(jin.data() + 32, ct, static_cast<size_t>(kCtBytes));
    rmbl_shake256(kbar, 32, jin.data(), jin.size());

    const int bad = pke_encrypt(ct2.data(), ek, mp, g + 32);
    /* Constant-time selection, and no early exit: whether the
     * re-encryption matched must not be observable in timing, because
     * that single bit is exactly what a chosen-ciphertext attack needs. */
    unsigned char diff = static_cast<unsigned char>(bad);
    for (int i = 0; i < kCtBytes; ++i) {
        diff = static_cast<unsigned char>(diff | (ct2[i] ^ ct[i]));
    }
    /* 0xff when any byte differed, 0x00 otherwise, computed by folding
     * the bits down rather than comparing: a comparison here is a
     * branch on secret data. */
    unsigned int nz = diff;
    nz |= nz >> 4;
    nz |= nz >> 2;
    nz |= nz >> 1;
    const unsigned char mask = static_cast<unsigned char>(-(nz & 1u));
    for (int i = 0; i < 32; ++i) {
        shared[i] = static_cast<unsigned char>(
            (g[i] & ~mask) | (kbar[i] & mask));
    }
}

}  // namespace MLKEM_NS
