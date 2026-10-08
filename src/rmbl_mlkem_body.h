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
    /* (t << d) / q, rounded to nearest; (t << d) + q/2 < 2^23 for d <= 11 */
    t = rmbl_mlkem_core::div_q((t << d) + kQ / 2) & ((1u << d) - 1u);
    return static_cast<uint16_t>(t);
}

inline int16_t decompress(uint16_t x, int d) {
    return static_cast<int16_t>(
        ((static_cast<uint32_t>(x) * kQ) + (1u << (d - 1))) >> d);
}

/* Constant-time testing hook (inst/ctcheck): a value the specification
 * publishes anyway -- the matrix seed rho, which is part of the encapsulation key -- is declared public to the checker here,
 * so the branch that follows is not reported. A no-op in the package. */
#ifndef RMBL_MLKEM_DECLASSIFY
#define RMBL_MLKEM_DECLASSIFY(ptr, len) ((void)0)
#endif

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
        /* every bit is written, set or clear: a branch here would make
         * the packing time of the secret key depend on its bits */
        for (int b = 0; b < d; ++b) {
            const size_t p = bit + static_cast<size_t>(b);
            out[p >> 3] = static_cast<unsigned char>(
                out[p >> 3] | (((v >> b) & 1u) << (p & 7u)));
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
    rmbl_ct::Guard gs(seed, sizeof seed);
    std::memcpy(seed, sigma, 32);
    seed[32] = nonce;
    std::vector<unsigned char> buf(static_cast<size_t>(64) * eta);
    rmbl_ct::Guard gb(buf.data(), buf.size());
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
    rmbl_ct::Guard gg(g, sizeof g), gd(din, sizeof din);
    std::memcpy(din, d, 32);
    din[32] = static_cast<unsigned char>(kK);
    rmbl_sha3_512(g, din, 33);
    RMBL_MLKEM_DECLASSIFY(g, 32); /* rho is published in ek */
    const unsigned char *rho = g;
    const unsigned char *sigma = g + 32;

    PolyVec mat[kK], s, e, t;
    rmbl_ct::Guard gs(&s, sizeof s), ge(&e, sizeof e);
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
    rmbl_ct::Guard gr(&r, sizeof r), ge1(&e1, sizeof e1), ge2(e2, sizeof e2),
        gmp(mp, sizeof mp), gv(v, sizeof v);
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
    rmbl_ct::Guard gs(&s, sizeof s), gw(w, sizeof w);
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
    rmbl_ct::Guard gi(g_in, sizeof g_in), gg(g, sizeof g);
    std::memcpy(g_in, m, 32);
    rmbl_sha3_256(g_in + 32, ek, static_cast<size_t>(kEkBytes));
    rmbl_sha3_512(g, g_in, 64);
    if (pke_encrypt(ct, ek, m, g + 32) != 0) return 1;
    std::memcpy(shared, g, 32);
    return 0;
}

/* The Fujisaki-Okamoto tail of decapsulation: shared = g when the re-encryption ct2 equals
 * the ciphertext (and re-encryption did not fail), K-bar otherwise, with no branch and no
 * early exit (inst/dudect times this function on its own). */
inline void fo_select(unsigned char shared[32], const unsigned char g[32], const unsigned char kbar[32],
                      const unsigned char *ct2, const unsigned char *ct, int bad) {
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
    /* clang saw that the mask is 0 or 0xff and turned the select back into
     * a branch on the secret; an opaque copy stops that reasoning */
    const unsigned char mask = static_cast<unsigned char>(rmbl_ct::barrier(-(nz & 1u)));
    for (int i = 0; i < 32; ++i) {
        shared[i] = static_cast<unsigned char>(
            (g[i] & ~mask) | (kbar[i] & mask));
    }
}

void decaps(unsigned char shared[32], const unsigned char *dk,
            const unsigned char *ct) {
    const unsigned char *ek = dk + kDkPkeBytes;
    const unsigned char *h = dk + kDkPkeBytes + kEkBytes;
    const unsigned char *z = h + 32;
    /* the decapsulation key carries the encapsulation key and its hash:
     * both are the public key, so the modulus check re-encryption runs on
     * them is not a branch on a secret */
    RMBL_MLKEM_DECLASSIFY(const_cast<unsigned char *>(ek), static_cast<size_t>(kEkBytes) + 32);
    unsigned char mp[32], g_in[64], g[64], kbar[32];
    rmbl_ct::Guard gm(mp, sizeof mp), gi(g_in, sizeof g_in), gg(g, sizeof g), gk(kbar, sizeof kbar);
    std::vector<unsigned char> ct2(static_cast<size_t>(kCtBytes));

    pke_decrypt(mp, dk, ct);
    std::memcpy(g_in, mp, 32);
    std::memcpy(g_in + 32, h, 32);
    rmbl_sha3_512(g, g_in, 64);

    /* K-bar = J(z || c): the shared secret returned when the ciphertext
     * does not re-encrypt to itself. */
    std::vector<unsigned char> jin(32 + static_cast<size_t>(kCtBytes));
    rmbl_ct::Guard gj(jin.data(), 32); /* z, the implicit-rejection secret */
    std::memcpy(jin.data(), z, 32);
    std::memcpy(jin.data() + 32, ct, static_cast<size_t>(kCtBytes));
    rmbl_shake256(kbar, 32, jin.data(), jin.size());

    const int bad = pke_encrypt(ct2.data(), ek, mp, g + 32);
    fo_select(shared, g, kbar, ct2.data(), ct, bad);
}


/* ------------------------------------------------------------------ *
 * Masked decapsulation: FIPS 203 ML-KEM.Decaps with every value that
 * depends on the secret key held as two shares (first-order masking,
 * rmbl_masked.h). The output is the same shared secret decaps() returns,
 * for every ciphertext, valid or not.
 *
 *   s-hat       arithmetic shares, split afresh from the key on entry
 *   w = v - s.u computed share by share (linear)
 *   m'          Boolean shares, by masked decoding (Compress_1)
 *   (K', r)     masked SHA3-512 of m' || h
 *   K-bar       masked SHAKE256 of z || c, z split on entry
 *   c'          re-encryption under masked r: masked PRF, masked
 *               centred-binomial noise, share-by-share arithmetic,
 *               m' brought back to arithmetic shares
 *   c' == c     masked decompressed comparison: every coefficient of c'
 *               is tested, in shares, against the public interval that
 *               compresses to the ciphertext's value, and the answers are
 *               ANDed in shares; the result is never unmasked
 *   K           masked selection of K' or K-bar, unmasked as the output
 *
 * What is not masked: decoding the 12-bit key encoding into coefficients
 * (the key arrives as plain bytes; masking starts from there), and the
 * public values (u, v, A-hat, t-hat, h, the ciphertext).
 * ------------------------------------------------------------------ */

inline void canon(int16_t a[256]) {
    for (int i = 0; i < 256; ++i) a[i] = to_positive(barrett_reduce(a[i]));
}

/* the cyclic interval of canonical x with Compress_d(x) == c, for every c */
inline void compress_intervals(int16_t *lo, int16_t *w, int d) {
    const int n = 1 << d;
    for (int c = 0; c < n; ++c) { lo[c] = 0; w[c] = 0; }
    for (int x = 0; x < kQ; ++x) {
        const uint16_t c = compress(static_cast<int16_t>(x), d);
        const uint16_t prev = compress(static_cast<int16_t>((x + kQ - 1) % kQ), d);
        ++w[c];
        if (prev != c) lo[c] = static_cast<int16_t>(x);
    }
}

inline void masked_prf_cbd(int16_t p0[256], int16_t p1[256], const unsigned char sig0[32],
                           const unsigned char sig1[32], unsigned char nonce, int eta,
                           rmbl_masked::Rng &rng) {
    unsigned char in0[33], in1[33], b0[192], b1[192];
    std::memcpy(in0, sig0, 32);
    std::memcpy(in1, sig1, 32);
    in0[32] = nonce;
    in1[32] = 0;
    rmbl_masked::sponge_masked(b0, b1, static_cast<size_t>(64 * eta), in0, in1, 33, 136, 0x1f, rng);
    for (int g = 0; g < 8; ++g) rmbl_masked::sec_cbd32(p0 + 32 * g, p1 + 32 * g, b0, b1, 32 * g, eta, rng);
}

void decaps_masked(unsigned char shared[32], const unsigned char *dk, const unsigned char *ct,
                   rmbl_masked::Rng &rng) {
    const unsigned char *ek = dk + kDkPkeBytes;
    const unsigned char *h = ek + kEkBytes;
    const unsigned char *z = h + 32;
    RMBL_MLKEM_DECLASSIFY(const_cast<unsigned char *>(ek), static_cast<size_t>(kEkBytes) + 32);

    /* 1. the secret key, split into fresh arithmetic shares */
    PolyVec s0, s1;
    for (int i = 0; i < kK; ++i) {
        int16_t raw[256];
        byte_decode(raw, dk + i * kPolyBytes, 12);
        /* share 0 first (fresh randomness), then share 1 = v - share 0, in separate passes */
        for (int j = 0; j < 256; ++j) s0.v[i][j] = rmbl_masked::rand_q(rng);
        rmbl_masked::rmbl_mask_scrub();
        for (int j = 0; j < 256; ++j) {
            const int16_t v = to_positive(barrett_reduce(raw[j]));
            s1.v[i][j] = static_cast<int16_t>(rmbl_masked::cadd_q(static_cast<int32_t>(v) - s0.v[i][j]));
        }
        rmbl_masked::rmbl_mask_scrub();
        rmbl_ct::wipe(raw, sizeof raw);
    }

    /* 2. the public ciphertext parts */
    PolyVec u;
    int16_t v[256];
    for (int i = 0; i < kK; ++i) {
        int16_t c[256];
        byte_decode(c, ct + i * kPolyCompressedU, kDu);
        for (int j = 0; j < 256; ++j) u.v[i][j] = decompress(static_cast<uint16_t>(c[j]), kDu);
        ntt(u.v[i]);
    }
    {
        int16_t c[256];
        byte_decode(c, ct + kK * kPolyCompressedU, kDv);
        for (int j = 0; j < 256; ++j) v[j] = decompress(static_cast<uint16_t>(c[j]), kDv);
    }

    /* 3. w = v - s.u, share by share */
    int16_t w0[256], w1[256];
    vec_dot(w0, &s0, &u);
    invntt(w0);
    poly_sub(w0, v, w0);
    canon(w0);
    rmbl_masked::rmbl_mask_scrub();
    vec_dot(w1, &s1, &u);
    invntt(w1);
    for (int j = 0; j < 256; ++j) w1[j] = static_cast<int16_t>(-w1[j]);
    canon(w1);
    rmbl_masked::rmbl_mask_scrub();

    /* 4. m' = Compress_1(w), as Boolean shares */
    unsigned char m0[32], m1[32];
    uint32_t mw0[8], mw1[8];
    for (int g = 0; g < 8; ++g) {
        rmbl_masked::sec_decode1(mw0[g], mw1[g], w0 + 32 * g, w1 + 32 * g, rng);
    }
    for (int g = 0; g < 8; ++g)
        for (int t = 0; t < 4; ++t) m0[4 * g + t] = static_cast<unsigned char>(mw0[g] >> (8 * t));
    rmbl_masked::rmbl_mask_scrub();
    for (int g = 0; g < 8; ++g)
        for (int t = 0; t < 4; ++t) m1[4 * g + t] = static_cast<unsigned char>(mw1[g] >> (8 * t));
    rmbl_masked::rmbl_mask_scrub();

    /* 5. (K', r) = G(m' || h) */
    unsigned char gi0[64], gi1[64], g0[64], g1[64];
    std::memcpy(gi0, m0, 32);
    std::memcpy(gi0 + 32, h, 32);
    rmbl_masked::rmbl_mask_scrub();
    std::memcpy(gi1, m1, 32);
    std::memset(gi1 + 32, 0, 32);
    rmbl_masked::sponge_masked(g0, g1, 64, gi0, gi1, 64, 72, 0x06, rng);

    /* 6. K-bar = J(z || c), z split afresh */
    unsigned char kb0[32], kb1[32];
    {
        std::vector<unsigned char> j0(32 + static_cast<size_t>(kCtBytes)), j1(32 + static_cast<size_t>(kCtBytes), 0);
        for (int i = 0; i < 32; ++i) j1[static_cast<size_t>(i)] = static_cast<unsigned char>(rng.u32());
        rmbl_masked::rmbl_mask_scrub();
        for (int i = 0; i < 32; ++i) j0[static_cast<size_t>(i)] = static_cast<unsigned char>(z[i] ^ j1[static_cast<size_t>(i)]);
        rmbl_masked::rmbl_mask_scrub();
        std::memcpy(j0.data() + 32, ct, static_cast<size_t>(kCtBytes));
        rmbl_masked::sponge_masked(kb0, kb1, 32, j0.data(), j1.data(), j0.size(), 136, 0x1f, rng);
        rmbl_ct::wipe(j0.data(), 32);
        rmbl_ct::wipe(j1.data(), 32);
    }

    /* 7. re-encryption of m' under r, in shares */
    PolyVec mat[kK], t;
    int bad = 0;
    for (int i = 0; i < kK; ++i) {
        byte_decode(t.v[i], ek + i * kPolyBytes, 12);
        for (int j = 0; j < 256; ++j) bad |= t.v[i][j] >= kQ;
    }
    matrix_expand(mat, ek + kK * kPolyBytes, true);
    PolyVec r0, r1, e10, e11;
    int16_t e20[256], e21[256];
    unsigned char nonce = 0;
    for (int i = 0; i < kK; ++i) masked_prf_cbd(r0.v[i], r1.v[i], g0 + 32, g1 + 32, nonce++, kEta1, rng);
    for (int i = 0; i < kK; ++i) masked_prf_cbd(e10.v[i], e11.v[i], g0 + 32, g1 + 32, nonce++, kEta2, rng);
    masked_prf_cbd(e20, e21, g0 + 32, g1 + 32, nonce++, kEta2, rng);
    for (int i = 0; i < kK; ++i) ntt(r0.v[i]);
    rmbl_masked::rmbl_mask_scrub();
    for (int i = 0; i < kK; ++i) ntt(r1.v[i]);
    rmbl_masked::rmbl_mask_scrub();
    PolyVec u0, u1;
    for (int i = 0; i < kK; ++i) {
        vec_dot(u0.v[i], &mat[i], &r0);
        invntt(u0.v[i]);
        poly_add(u0.v[i], u0.v[i], e10.v[i]);
        canon(u0.v[i]);
    }
    rmbl_masked::rmbl_mask_scrub();
    for (int i = 0; i < kK; ++i) {
        vec_dot(u1.v[i], &mat[i], &r1);
        invntt(u1.v[i]);
        poly_add(u1.v[i], u1.v[i], e11.v[i]);
        canon(u1.v[i]);
    }
    rmbl_masked::rmbl_mask_scrub();
    int16_t v0[256], v1[256];
    vec_dot(v0, &t, &r0);
    invntt(v0);
    poly_add(v0, v0, e20);
    rmbl_masked::rmbl_mask_scrub();
    vec_dot(v1, &t, &r1);
    invntt(v1);
    poly_add(v1, v1, e21);
    /* + Decompress_1(m'): m' back to arithmetic shares, times (q + 1) / 2 */
    for (int g = 0; g < 8; ++g) {
        rmbl_masked::Bs mb;
        for (int b = 0; b < rmbl_masked::kMaxBits; ++b) mb.w[0][b] = mb.w[1][b] = 0;
        rmbl_masked::m_pub(rmbl_masked::pz(&mb.w[0][0], &mb.w[1][0], &mw0[g], &mw1[g]), 0, 3);
        int16_t c0[32], c1[32];
        rmbl_masked::sec_b2a(c0, c1, mb, rng);
        for (int j = 0; j < 32; ++j)
            v0[32 * g + j] = barrett_reduce(static_cast<int16_t>(v0[32 * g + j] + static_cast<int16_t>(rmbl_mlkem_core::mod_q(static_cast<uint32_t>(c0[j]) * ((kQ + 1) / 2)))));
        rmbl_masked::rmbl_mask_scrub();
        for (int j = 0; j < 32; ++j)
            v1[32 * g + j] = barrett_reduce(static_cast<int16_t>(v1[32 * g + j] + static_cast<int16_t>(rmbl_mlkem_core::mod_q(static_cast<uint32_t>(c1[j]) * ((kQ + 1) / 2)))));
        rmbl_masked::rmbl_mask_scrub();
    }
    canon(v0);
    rmbl_masked::rmbl_mask_scrub();
    canon(v1);
    rmbl_masked::rmbl_mask_scrub();

    /* 8. masked comparison of c' with c, decompressed */
    rmbl_masked::AllOk all;
    {
        std::vector<int16_t> lo(static_cast<size_t>(1) << kDu), wd(static_cast<size_t>(1) << kDu);
        compress_intervals(lo.data(), wd.data(), kDu);
        for (int i = 0; i < kK; ++i) {
            int16_t c[256];
            byte_decode(c, ct + i * kPolyCompressedU, kDu);
            for (int g = 0; g < 8; ++g) {
                int16_t l[32], w[32];
                for (int j = 0; j < 32; ++j) {
                    l[j] = lo[static_cast<size_t>(c[32 * g + j])];
                    w[j] = wd[static_cast<size_t>(c[32 * g + j])];
                }
                uint32_t o[2];
                rmbl_masked::sec_in_interval(o[0], o[1], u0.v[i] + 32 * g, u1.v[i] + 32 * g, l, w, rng);
                all.add(o, rng);
            }
        }
        std::vector<int16_t> lov(static_cast<size_t>(1) << kDv), wdv(static_cast<size_t>(1) << kDv);
        compress_intervals(lov.data(), wdv.data(), kDv);
        int16_t c[256];
        byte_decode(c, ct + kK * kPolyCompressedU, kDv);
        for (int g = 0; g < 8; ++g) {
            int16_t l[32], w[32];
            for (int j = 0; j < 32; ++j) {
                l[j] = lov[static_cast<size_t>(c[32 * g + j])];
                w[j] = wdv[static_cast<size_t>(c[32 * g + j])];
            }
            uint32_t o[2];
            rmbl_masked::sec_in_interval(o[0], o[1], v0 + 32 * g, v1 + 32 * g, l, w, rng);
            all.add(o, rng);
        }
    }
    /* fold the 32 lanes into bit 0 */
    uint32_t ok[2];
    rmbl_masked::sec_all_lanes(ok, all.a, rng);
    /* a non-canonical encapsulation key never re-encrypts (public) */
    const uint32_t keep = static_cast<uint32_t>(bad) - 1u;   /* 0 when bad */
    rmbl_masked::m_pub(rmbl_masked::pz(ok, ok + 1, ok, ok + 1), keep & 1u, 1);

    /* 9. K = ok ? K' : K-bar, selected in shares, then unmasked */
    uint32_t msk[2];
    rmbl_masked::m_pub(rmbl_masked::pz(msk, msk + 1, ok, ok + 1), 0, 4);   /* bit 0 -> all ones */
    uint32_t kp[2][8], kbw[2][8];
    for (int i = 0; i < 8; ++i) {
        std::memcpy(&kp[0][i], g0 + 4 * i, 4);
        std::memcpy(&kbw[0][i], kb0 + 4 * i, 4);
    }
    rmbl_masked::rmbl_mask_scrub();
    for (int i = 0; i < 8; ++i) {
        std::memcpy(&kp[1][i], g1 + 4 * i, 4);
        std::memcpy(&kbw[1][i], kb1 + 4 * i, 4);
    }
    rmbl_masked::rmbl_mask_scrub();
    for (int i = 0; i < 8; ++i) {
        uint32_t d[2], t2[2], k[2];
        rmbl_masked::m_xor(rmbl_masked::pz(d, d + 1, &kp[0][i], &kp[1][i], &kbw[0][i], &kbw[1][i]));
        rmbl_masked::and2(t2, msk, d, rng.u32());
        rmbl_masked::m_xor(rmbl_masked::pz(k, k + 1, &kbw[0][i], &kbw[1][i], t2, t2 + 1));
        const uint32_t out = k[0] ^ k[1];   /* the shared secret, the output */
        std::memcpy(shared + 4 * i, &out, 4);
    }
    /* every share pair that touched m', K' or K-bar: the two halves of a value are
     * as sensitive as the value, and a memory-disclosure elsewhere must not find
     * either half (the plain path guards m' and K-bar the same way) */
    rmbl_ct::wipe(kp, sizeof kp);
    rmbl_ct::wipe(kbw, sizeof kbw);
    rmbl_ct::wipe(&s0, sizeof s0);
    rmbl_ct::wipe(&s1, sizeof s1);
    rmbl_ct::wipe(&u, sizeof u);
    rmbl_ct::wipe(v, sizeof v);
    rmbl_ct::wipe(w0, sizeof w0);
    rmbl_ct::wipe(w1, sizeof w1);
    rmbl_ct::wipe(mw0, sizeof mw0);
    rmbl_ct::wipe(mw1, sizeof mw1);
    rmbl_ct::wipe(gi0, sizeof gi0);
    rmbl_ct::wipe(gi1, sizeof gi1);
    rmbl_ct::wipe(g0, sizeof g0);
    rmbl_ct::wipe(g1, sizeof g1);
    rmbl_ct::wipe(kb0, sizeof kb0);
    rmbl_ct::wipe(kb1, sizeof kb1);
    rmbl_ct::wipe(m0, sizeof m0);
    rmbl_ct::wipe(m1, sizeof m1);
}

}  // namespace MLKEM_NS
