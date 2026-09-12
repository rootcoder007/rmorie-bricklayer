/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Keccak-f[1600], SHA-3 and the SHAKE extendable-output functions of
 * FIPS 202.
 *
 * These are here because ML-DSA (FIPS 204) is defined entirely in terms
 * of SHAKE128 and SHAKE256, and SLH-DSA (FIPS 205) has SHAKE parameter
 * sets alongside its SHA-2 ones. Implementing them removes the only
 * reason this package had an optional system dependency on liboqs.
 *
 * The permutation is the standard one: 24 rounds of theta, rho, pi, chi
 * and iota over a 5-by-5 array of 64-bit lanes. Nothing here is
 * clever -- the round constants and rotation offsets are the published
 * tables, and the sponge is absorb-then-squeeze with the pad10*1
 * padding and the domain byte FIPS 202 assigns to each function.
 *
 * Verified against the published NIST vectors and against the
 * pq-crystals reference implementation; see
 * tests/testthat/test-keccak.R.
 */

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>

#include <R.h>
#include <Rinternals.h>

namespace {

/* Round constants, FIPS 202 Table 1 (iota). */
const uint64_t kRC[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL,
    0x8000000080008000ULL, 0x000000000000808bULL, 0x0000000080000001ULL,
    0x8000000080008081ULL, 0x8000000000008009ULL, 0x000000000000008aULL,
    0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
    0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL,
    0x8000000000008003ULL, 0x8000000000008002ULL, 0x8000000000000080ULL,
    0x000000000000800aULL, 0x800000008000000aULL, 0x8000000080008081ULL,
    0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
};

/* Rotation offsets for rho, indexed [x + 5*y]. */
const int kRho[25] = {
     0,  1, 62, 28, 27,
    36, 44,  6, 55, 20,
     3, 10, 43, 25, 39,
    41, 45, 15, 21,  8,
    18,  2, 61, 56, 14
};

inline uint64_t rotl64(uint64_t x, int n) {
    return n == 0 ? x : ((x << n) | (x >> (64 - n)));
}

/* Index tables for rho/pi and chi, computed at compile time from the
 * formulas rather than written out. The previous form evaluated `% 5`
 * inside the innermost loops, which is a division on every lane of
 * every round; these turn the whole round into straight-line code the
 * compiler can unroll.
 *
 * Lane (x, y) lives at index x + 5y, which is the layout kRho is
 * indexed by, so the tables must use the same convention. */
struct KeccakTables {
    int theta_d[5];  /* c index contributing d for column x */
    int theta_r[5];  /* c index rotated into d for column x */
};

constexpr KeccakTables make_keccak_tables() {
    KeccakTables t{};
    for (int x = 0; x < 5; ++x) {
        t.theta_d[x] = (x + 4) % 5;
        t.theta_r[x] = (x + 1) % 5;
    }
    return t;
}

constexpr KeccakTables kT = make_keccak_tables();

void keccak_f1600(uint64_t a[25]) {
    for (int round = 0; round < 24; ++round) {
        /* theta */
        uint64_t c[5];
        for (int x = 0; x < 5; ++x) {
            c[x] = a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20];
        }
        uint64_t d[5];
        for (int x = 0; x < 5; ++x) {
            d[x] = c[kT.theta_d[x]] ^ rotl64(c[kT.theta_r[x]], 1);
        }
        /* theta, rho and pi: b[pi(i)] = rot(a[i] ^ d[x], r[i]).
         * Written out with literal indices -- generated from the
         * formulas, not transcribed -- so that no division or
         * array indexing survives into the inner loop. */
        uint64_t b[25];
        b[ 0] = rotl64(a[ 0] ^ d[0], kRho[ 0]);
        b[10] = rotl64(a[ 1] ^ d[1], kRho[ 1]);
        b[20] = rotl64(a[ 2] ^ d[2], kRho[ 2]);
        b[ 5] = rotl64(a[ 3] ^ d[3], kRho[ 3]);
        b[15] = rotl64(a[ 4] ^ d[4], kRho[ 4]);
        b[16] = rotl64(a[ 5] ^ d[0], kRho[ 5]);
        b[ 1] = rotl64(a[ 6] ^ d[1], kRho[ 6]);
        b[11] = rotl64(a[ 7] ^ d[2], kRho[ 7]);
        b[21] = rotl64(a[ 8] ^ d[3], kRho[ 8]);
        b[ 6] = rotl64(a[ 9] ^ d[4], kRho[ 9]);
        b[ 7] = rotl64(a[10] ^ d[0], kRho[10]);
        b[17] = rotl64(a[11] ^ d[1], kRho[11]);
        b[ 2] = rotl64(a[12] ^ d[2], kRho[12]);
        b[12] = rotl64(a[13] ^ d[3], kRho[13]);
        b[22] = rotl64(a[14] ^ d[4], kRho[14]);
        b[23] = rotl64(a[15] ^ d[0], kRho[15]);
        b[ 8] = rotl64(a[16] ^ d[1], kRho[16]);
        b[18] = rotl64(a[17] ^ d[2], kRho[17]);
        b[ 3] = rotl64(a[18] ^ d[3], kRho[18]);
        b[13] = rotl64(a[19] ^ d[4], kRho[19]);
        b[14] = rotl64(a[20] ^ d[0], kRho[20]);
        b[24] = rotl64(a[21] ^ d[1], kRho[21]);
        b[ 9] = rotl64(a[22] ^ d[2], kRho[22]);
        b[19] = rotl64(a[23] ^ d[3], kRho[23]);
        b[ 4] = rotl64(a[24] ^ d[4], kRho[24]);
        /* chi */
        a[ 0] = b[ 0] ^ ((~b[ 1]) & b[ 2]);
        a[ 1] = b[ 1] ^ ((~b[ 2]) & b[ 3]);
        a[ 2] = b[ 2] ^ ((~b[ 3]) & b[ 4]);
        a[ 3] = b[ 3] ^ ((~b[ 4]) & b[ 0]);
        a[ 4] = b[ 4] ^ ((~b[ 0]) & b[ 1]);
        a[ 5] = b[ 5] ^ ((~b[ 6]) & b[ 7]);
        a[ 6] = b[ 6] ^ ((~b[ 7]) & b[ 8]);
        a[ 7] = b[ 7] ^ ((~b[ 8]) & b[ 9]);
        a[ 8] = b[ 8] ^ ((~b[ 9]) & b[ 5]);
        a[ 9] = b[ 9] ^ ((~b[ 5]) & b[ 6]);
        a[10] = b[10] ^ ((~b[11]) & b[12]);
        a[11] = b[11] ^ ((~b[12]) & b[13]);
        a[12] = b[12] ^ ((~b[13]) & b[14]);
        a[13] = b[13] ^ ((~b[14]) & b[10]);
        a[14] = b[14] ^ ((~b[10]) & b[11]);
        a[15] = b[15] ^ ((~b[16]) & b[17]);
        a[16] = b[16] ^ ((~b[17]) & b[18]);
        a[17] = b[17] ^ ((~b[18]) & b[19]);
        a[18] = b[18] ^ ((~b[19]) & b[15]);
        a[19] = b[19] ^ ((~b[15]) & b[16]);
        a[20] = b[20] ^ ((~b[21]) & b[22]);
        a[21] = b[21] ^ ((~b[22]) & b[23]);
        a[22] = b[22] ^ ((~b[23]) & b[24]);
        a[23] = b[23] ^ ((~b[24]) & b[20]);
        a[24] = b[24] ^ ((~b[20]) & b[21]);
        /* iota */
        a[0] ^= kRC[round];
    }
}

inline uint64_t load64(const unsigned char *p) {
    uint64_t v = 0;
    for (int i = 0; i < 8; ++i) v |= static_cast<uint64_t>(p[i]) << (8 * i);
    return v;
}

inline void store64(unsigned char *p, uint64_t v) {
    for (int i = 0; i < 8; ++i) p[i] = static_cast<unsigned char>(v >> (8 * i));
}

}  // namespace

/* The sponge state, exposed so ML-DSA can squeeze incrementally rather
 * than asking for a fixed output length up front -- its rejection
 * sampling does not know in advance how many bytes it will need. */
struct RmblKeccak {
    uint64_t s[25];
    size_t rate;        /* bytes absorbed per permutation */
    unsigned char pad;  /* domain separation byte */
    size_t pos;         /* bytes buffered in the current block */
    bool squeezing;
};

extern "C" {

void rmbl_keccak_init(RmblKeccak *st, size_t rate, unsigned char pad) {
    std::memset(st->s, 0, sizeof st->s);
    st->rate = rate;
    st->pad = pad;
    st->pos = 0;
    st->squeezing = false;
}

void rmbl_keccak_absorb(RmblKeccak *st, const unsigned char *in, size_t len) {
    /* XOR into the rate portion, permuting whenever a block fills. The
     * whole-lane path matters: the post-quantum schemes here absorb
     * tens of millions of short buffers per signature, and a byte at a
     * time costs a shift and a divide on each one. */
    while (len > 0) {
        size_t take = (st->rate - st->pos < len) ? st->rate - st->pos : len;
        size_t i = 0;
        if ((st->pos & 7u) == 0) {
            for (; i + 8 <= take; i += 8) {
                const size_t j = st->pos + i;
                uint64_t v = 0;
                for (int k = 0; k < 8; ++k) {
                    v |= static_cast<uint64_t>(in[i + static_cast<size_t>(k)])
                         << (8 * k);
                }
                st->s[j / 8] ^= v;
            }
        }
        for (; i < take; ++i) {
            const size_t j = st->pos + i;
            st->s[j / 8] ^= static_cast<uint64_t>(in[i]) << (8 * (j % 8));
        }
        st->pos += take;
        in += take;
        len -= take;
        if (st->pos == st->rate) {
            keccak_f1600(st->s);
            st->pos = 0;
        }
    }
}

/* pad10*1 with the function's domain byte, per FIPS 202 section B.2. */
void rmbl_keccak_finalize(RmblKeccak *st) {
    st->s[st->pos / 8] ^=
        static_cast<uint64_t>(st->pad) << (8 * (st->pos % 8));
    const size_t last = st->rate - 1;
    st->s[last / 8] ^= 0x80ULL << (8 * (last % 8));
    keccak_f1600(st->s);
    st->pos = 0;
    st->squeezing = true;
}

void rmbl_keccak_squeeze(RmblKeccak *st, unsigned char *out, size_t len) {
    if (!st->squeezing) rmbl_keccak_finalize(st);
    while (len > 0) {
        if (st->pos == st->rate) {
            keccak_f1600(st->s);
            st->pos = 0;
        }
        const size_t give = (st->rate - st->pos < len) ? st->rate - st->pos : len;
        for (size_t i = 0; i < give; ++i) {
            const size_t j = st->pos + i;
            out[i] = static_cast<unsigned char>(st->s[j / 8] >> (8 * (j % 8)));
        }
        st->pos += give;
        out += give;
        len -= give;
    }
}

/* One-shot forms. SHAKE uses the 0x1f domain byte and SHA-3 uses 0x06;
 * the rate is 200 - 2 * (security strength in bytes). */
void rmbl_shake128(unsigned char *out, size_t outlen,
                   const unsigned char *in, size_t inlen) {
    RmblKeccak st;
    rmbl_keccak_init(&st, 168, 0x1f);
    rmbl_keccak_absorb(&st, in, inlen);
    rmbl_keccak_squeeze(&st, out, outlen);
}

void rmbl_shake256(unsigned char *out, size_t outlen,
                   const unsigned char *in, size_t inlen) {
    RmblKeccak st;
    rmbl_keccak_init(&st, 136, 0x1f);
    rmbl_keccak_absorb(&st, in, inlen);
    rmbl_keccak_squeeze(&st, out, outlen);
}

void rmbl_sha3_256(unsigned char out[32], const unsigned char *in,
                   size_t inlen) {
    RmblKeccak st;
    rmbl_keccak_init(&st, 136, 0x06);
    rmbl_keccak_absorb(&st, in, inlen);
    rmbl_keccak_squeeze(&st, out, 32);
}

void rmbl_sha3_512(unsigned char out[64], const unsigned char *in,
                   size_t inlen) {
    RmblKeccak st;
    rmbl_keccak_init(&st, 72, 0x06);
    rmbl_keccak_absorb(&st, in, inlen);
    rmbl_keccak_squeeze(&st, out, 64);
}

/* R entry points, for testing the primitive directly against the
 * published vectors. */
SEXP C_rmbl_shake(SEXP which, SEXP x, SEXP outlen) {
    const int w = Rf_asInteger(which);
    const R_xlen_t n = Rf_asInteger(outlen);
    if (n < 0) Rf_error("`outlen` must be non-negative");
    std::vector<unsigned char> in;
    if (TYPEOF(x) == RAWSXP) {
        in.assign(RAW(x), RAW(x) + XLENGTH(x));
    } else {
        SEXP sx = PROTECT(Rf_coerceVector(x, STRSXP));
        const char *s = CHAR(STRING_ELT(sx, 0));
        in.assign(s, s + std::strlen(s));
        UNPROTECT(1);
    }
    std::vector<unsigned char> out(static_cast<size_t>(n));
    if (w == 128) {
        rmbl_shake128(out.data(), out.size(), in.data(), in.size());
    } else if (w == 256) {
        rmbl_shake256(out.data(), out.size(), in.data(), in.size());
    } else if (w == 3256) {
        out.resize(32);
        rmbl_sha3_256(out.data(), in.data(), in.size());
    } else if (w == 3512) {
        out.resize(64);
        rmbl_sha3_512(out.data(), in.data(), in.size());
    } else {
        Rf_error("unknown function selector");
    }
    SEXP res = PROTECT(Rf_allocVector(RAWSXP, static_cast<R_xlen_t>(out.size())));
    if (!out.empty()) std::memcpy(RAW(res), out.data(), out.size());
    UNPROTECT(1);
    return res;
}

}  // extern "C"
