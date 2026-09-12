/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * rmbl_kdf.cpp -- BLAKE2b, PBKDF2 and operating-system entropy.
 *
 * Three gaps this closes, all of them about keys rather than data:
 *
 *   * OS ENTROPY. A signing key is only as unguessable as the bytes it
 *     was built from. R exposes no cryptographic random source in base,
 *     and mixing the clock, the process id and R's Mersenne Twister --
 *     all of which an attacker can narrow down -- is not a substitute.
 *     rmbl_os_random reads the platform's CSPRNG and reports failure
 *     rather than silently degrading.
 *   * PBKDF2-HMAC-SHA256 (RFC 8018). Turns a passphrase a person can
 *     remember into a key of full width, at a deliberately tunable cost,
 *     so capsule_sign(scheme = "hmac") does not need its caller to
 *     manage raw key bytes.
 *   * BLAKE2b (RFC 7693). A modern digest that is faster than SHA-256 in
 *     software, takes a key natively (so it is a MAC without the HMAC
 *     construction), and produces any digest length from 1 to 64 bytes.
 */

#if defined(_WIN32)
/* Before the R headers: windows.h and R both define TRUE/FALSE, and
 * windows.h additionally defines ERROR, which R_ext uses as an enum
 * name. Including it first and then dropping the offending macros is
 * the order that compiles cleanly. */
#include <windows.h>
/* RtlGenRandom, the Windows CSPRNG. advapi32 exports it as
 * SystemFunction036 with no public header, so it is declared here --
 * the documented way to reach it, and it avoids pulling in bcrypt for a
 * handful of bytes. */
extern "C" BOOLEAN NTAPI SystemFunction036(PVOID buffer, ULONG length);
#undef ERROR
#undef TRUE
#undef FALSE
#undef length
#endif

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include <cstdint>
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

extern "C" void rmbl_sha256_raw(const unsigned char *data, size_t len,
                                unsigned char out[32]);
extern "C" void rmbl_hmac_sha256_hex(const unsigned char *key, size_t keylen,
                                     const unsigned char *msg, size_t msglen,
                                     char out[65]);

namespace {

const char kHex[] = "0123456789abcdef";

void hexlify(const unsigned char *b, size_t n, std::string &out) {
    out.resize(n * 2);
    for (size_t i = 0; i < n; ++i) {
        out[i * 2] = kHex[(b[i] >> 4) & 0xf];
        out[i * 2 + 1] = kHex[b[i] & 0xf];
    }
}

/* ---------------- BLAKE2b (RFC 7693) ---------------- */

const uint64_t kIV[8] = {
    0x6a09e667f3bcc908ULL, 0xbb67ae8584caa73bULL, 0x3c6ef372fe94f82bULL,
    0xa54ff53a5f1d36f1ULL, 0x510e527fade682d1ULL, 0x9b05688c2b3e6c1fULL,
    0x1f83d9abfb41bd6bULL, 0x5be0cd19137e2179ULL
};

const uint8_t kSigma[12][16] = {
    { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15},
    {14,10, 4, 8, 9,15,13, 6, 1,12, 0, 2,11, 7, 5, 3},
    {11, 8,12, 0, 5, 2,15,13,10,14, 3, 6, 7, 1, 9, 4},
    { 7, 9, 3, 1,13,12,11,14, 2, 6, 5,10, 4, 0,15, 8},
    { 9, 0, 5, 7, 2, 4,10,15,14, 1,11,12, 6, 8, 3,13},
    { 2,12, 6,10, 0,11, 8, 3, 4,13, 7, 5,15,14, 1, 9},
    {12, 5, 1,15,14,13, 4,10, 0, 7, 6, 3, 9, 2, 8,11},
    {13,11, 7,14,12, 1, 3, 9, 5, 0,15, 4, 8, 6, 2,10},
    { 6,15,14, 9,11, 3, 0, 8,12, 2,13, 7, 1, 4,10, 5},
    {10, 2, 8, 4, 7, 6, 1, 5,15,11, 9,14, 3,12,13, 0},
    { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15},
    {14,10, 4, 8, 9,15,13, 6, 1,12, 0, 2,11, 7, 5, 3}
};

inline uint64_t rotr64(uint64_t x, unsigned k) {
    return (x >> k) | (x << (64 - k));
}

struct blake2b_ctx {
    uint8_t  buf[128];
    size_t   buflen;
    uint64_t h[8];
    uint64_t t[2];
    int      outlen;
};

void b2b_g(uint64_t *v, int a, int b, int c, int d, uint64_t x, uint64_t y) {
    v[a] = v[a] + v[b] + x;
    v[d] = rotr64(v[d] ^ v[a], 32);
    v[c] = v[c] + v[d];
    v[b] = rotr64(v[b] ^ v[c], 24);
    v[a] = v[a] + v[b] + y;
    v[d] = rotr64(v[d] ^ v[a], 16);
    v[c] = v[c] + v[d];
    v[b] = rotr64(v[b] ^ v[c], 63);
}

void b2b_compress(blake2b_ctx *c, int last) {
    uint64_t v[16], m[16];
    for (int i = 0; i < 8; ++i) v[i] = c->h[i];
    for (int i = 0; i < 8; ++i) v[i + 8] = kIV[i];
    v[12] ^= c->t[0];
    v[13] ^= c->t[1];
    if (last) v[14] = ~v[14];
    for (int i = 0; i < 16; ++i) {
        uint64_t w = 0;
        for (int j = 7; j >= 0; --j) {
            w = (w << 8) | c->buf[i * 8 + j];   /* little-endian */
        }
        m[i] = w;
    }
    for (int r = 0; r < 12; ++r) {
        const uint8_t *s = kSigma[r];
        b2b_g(v, 0, 4,  8, 12, m[s[0]],  m[s[1]]);
        b2b_g(v, 1, 5,  9, 13, m[s[2]],  m[s[3]]);
        b2b_g(v, 2, 6, 10, 14, m[s[4]],  m[s[5]]);
        b2b_g(v, 3, 7, 11, 15, m[s[6]],  m[s[7]]);
        b2b_g(v, 0, 5, 10, 15, m[s[8]],  m[s[9]]);
        b2b_g(v, 1, 6, 11, 12, m[s[10]], m[s[11]]);
        b2b_g(v, 2, 7,  8, 13, m[s[12]], m[s[13]]);
        b2b_g(v, 3, 4,  9, 14, m[s[14]], m[s[15]]);
    }
    for (int i = 0; i < 8; ++i) c->h[i] ^= v[i] ^ v[i + 8];
}

int b2b_init(blake2b_ctx *c, int outlen, const unsigned char *key,
             size_t keylen) {
    if (outlen < 1 || outlen > 64 || keylen > 64) return -1;
    for (int i = 0; i < 8; ++i) c->h[i] = kIV[i];
    /* parameter block: digest length, key length, fanout 1, depth 1 */
    c->h[0] ^= 0x01010000ULL ^ (static_cast<uint64_t>(keylen) << 8) ^
               static_cast<uint64_t>(outlen);
    c->t[0] = 0;
    c->t[1] = 0;
    c->buflen = 0;
    c->outlen = outlen;
    std::memset(c->buf, 0, 128);
    if (keylen > 0) {
        /* the key occupies one whole padded block before the message */
        std::memcpy(c->buf, key, keylen);
        c->buflen = 128;
    }
    return 0;
}

void b2b_update(blake2b_ctx *c, const unsigned char *in, size_t inlen) {
    for (size_t i = 0; i < inlen; ++i) {
        if (c->buflen == 128) {
            c->t[0] += 128;
            if (c->t[0] < 128) ++c->t[1];
            b2b_compress(c, 0);
            c->buflen = 0;
            std::memset(c->buf, 0, 128);
        }
        c->buf[c->buflen++] = in[i];
    }
}

void b2b_final(blake2b_ctx *c, unsigned char *out) {
    c->t[0] += static_cast<uint64_t>(c->buflen);
    if (c->t[0] < static_cast<uint64_t>(c->buflen)) ++c->t[1];
    while (c->buflen < 128) c->buf[c->buflen++] = 0;
    b2b_compress(c, 1);
    for (int i = 0; i < c->outlen; ++i) {
        out[i] = static_cast<unsigned char>(
            (c->h[i >> 3] >> (8 * (i & 7))) & 0xff);
    }
}

}  // namespace

extern "C" {

int rmbl_blake2b(const unsigned char *msg, size_t msglen,
                 const unsigned char *key, size_t keylen, int outlen,
                 unsigned char *out) {
    blake2b_ctx c;
    if (b2b_init(&c, outlen, key, keylen) != 0) return -1;
    b2b_update(&c, msg, msglen);
    b2b_final(&c, out);
    return 0;
}

/* PBKDF2-HMAC-SHA256 (RFC 8018 section 5.2). */
void rmbl_pbkdf2_sha256(const unsigned char *pass, size_t passlen,
                        const unsigned char *salt, size_t saltlen,
                        int iterations, int dklen, unsigned char *out) {
    const int hlen = 32;
    if (dklen < 1 || iterations < 1) return;
    /* An explicit bound the compiler can see: without it saltlen + 4 is
     * an unprovable expression and the fortified memcpy warns. */
    const size_t kMaxSalt = 1u << 20;
    if (saltlen > kMaxSalt) return;
    const int blocks = (dklen + hlen - 1) / hlen;

    std::vector<unsigned char> block;
    block.reserve(saltlen + 4);
    if (salt != NULL && saltlen > 0) {
        block.assign(salt, salt + saltlen);
    }
    block.resize(saltlen + 4, 0);
    char hexbuf[65];

    auto hmac_raw = [&](const unsigned char *m, size_t mlen,
                        unsigned char o[32]) {
        rmbl_hmac_sha256_hex(pass, passlen, m, mlen, hexbuf);
        for (int i = 0; i < 32; ++i) {
            const char hi = hexbuf[i * 2], lo = hexbuf[i * 2 + 1];
            const int a = (hi <= '9') ? hi - '0' : hi - 'a' + 10;
            const int b = (lo <= '9') ? lo - '0' : lo - 'a' + 10;
            o[i] = static_cast<unsigned char>((a << 4) | b);
        }
    };

    for (int i = 1; i <= blocks; ++i) {
        block[saltlen + 0] = static_cast<unsigned char>((i >> 24) & 0xff);
        block[saltlen + 1] = static_cast<unsigned char>((i >> 16) & 0xff);
        block[saltlen + 2] = static_cast<unsigned char>((i >> 8) & 0xff);
        block[saltlen + 3] = static_cast<unsigned char>(i & 0xff);
        unsigned char u[32], t[32];
        hmac_raw(block.data(), block.size(), u);
        std::memcpy(t, u, 32);
        for (int j = 1; j < iterations; ++j) {
            hmac_raw(u, 32, u);
            for (int k = 0; k < 32; ++k) t[k] ^= u[k];
        }
        const int off = (i - 1) * hlen;
        const int take = (dklen - off < hlen) ? (dklen - off) : hlen;
        std::memcpy(out + off, t, static_cast<size_t>(take));
    }
}

/* Operating-system entropy. Returns 0 on success, -1 if no CSPRNG could
 * be read -- the caller must treat that as fatal rather than falling
 * back to something guessable. */
int rmbl_os_random(unsigned char *out, size_t n) {
#if defined(_WIN32)
    /* ULONG is 32-bit, so a very large request has to be filled in
     * chunks rather than truncated. */
    size_t done = 0;
    while (done < n) {
        const size_t want = (n - done > 0x10000000u) ? 0x10000000u
                                                     : (n - done);
        if (!SystemFunction036(out + done, static_cast<ULONG>(want))) {
            return -1;
        }
        done += want;
    }
    return 0;
#else
    FILE *f = std::fopen("/dev/urandom", "rb");
    if (f == NULL) return -1;
    const size_t got = std::fread(out, 1, n, f);
    std::fclose(f);
    return (got == n) ? 0 : -1;
#endif
}

SEXP C_rmbl_blake2b(SEXP x, SEXP key, SEXP outlen) {
    const int ol = Rf_asInteger(outlen);
    if (ol < 1 || ol > 64) Rf_error("`length` must be between 1 and 64 bytes");
    std::vector<unsigned char> kb;
    if (key != R_NilValue) {
        if (TYPEOF(key) == RAWSXP) {
            kb.assign(RAW(key), RAW(key) + XLENGTH(key));
        } else {
            SEXP k = PROTECT(Rf_coerceVector(key, STRSXP));
            const char *s = CHAR(STRING_ELT(k, 0));
            kb.assign(s, s + std::strlen(s));
            UNPROTECT(1);
        }
        if (kb.size() > 64) Rf_error("`key` must be at most 64 bytes");
    }
    std::vector<unsigned char> ob(static_cast<size_t>(ol));
    std::string hex;

    if (TYPEOF(x) == RAWSXP) {
        if (rmbl_blake2b(RAW(x), static_cast<size_t>(XLENGTH(x)),
                         kb.empty() ? NULL : kb.data(), kb.size(), ol,
                         ob.data()) != 0) {
            Rf_error("BLAKE2b initialisation failed");
        }
        hexlify(ob.data(), ob.size(), hex);
        return Rf_mkString(hex.c_str());
    }
    x = PROTECT(Rf_coerceVector(x, STRSXP));
    const R_xlen_t n = XLENGTH(x);
    SEXP res = PROTECT(Rf_allocVector(STRSXP, n));
    for (R_xlen_t i = 0; i < n; ++i) {
        const char *s = CHAR(STRING_ELT(x, i));
        rmbl_blake2b(reinterpret_cast<const unsigned char *>(s),
                     std::strlen(s), kb.empty() ? NULL : kb.data(),
                     kb.size(), ol, ob.data());
        hexlify(ob.data(), ob.size(), hex);
        SET_STRING_ELT(res, i, Rf_mkChar(hex.c_str()));
    }
    UNPROTECT(2);
    return res;
}

SEXP C_rmbl_pbkdf2(SEXP pass, SEXP salt, SEXP iterations, SEXP dklen) {
    const int iter = Rf_asInteger(iterations);
    const int dk = Rf_asInteger(dklen);
    if (iter < 1) Rf_error("`iterations` must be at least 1");
    if (dk < 1 || dk > 1024) Rf_error("`length` must be between 1 and 1024");

    std::vector<unsigned char> pb, sb;
    if (TYPEOF(pass) == RAWSXP) {
        pb.assign(RAW(pass), RAW(pass) + XLENGTH(pass));
    } else {
        SEXP p = PROTECT(Rf_coerceVector(pass, STRSXP));
        const char *s = CHAR(STRING_ELT(p, 0));
        pb.assign(s, s + std::strlen(s));
        UNPROTECT(1);
    }
    if (TYPEOF(salt) == RAWSXP) {
        sb.assign(RAW(salt), RAW(salt) + XLENGTH(salt));
    } else {
        SEXP s2 = PROTECT(Rf_coerceVector(salt, STRSXP));
        const char *s = CHAR(STRING_ELT(s2, 0));
        sb.assign(s, s + std::strlen(s));
        UNPROTECT(1);
    }
    std::vector<unsigned char> out(static_cast<size_t>(dk));
    rmbl_pbkdf2_sha256(pb.data(), pb.size(), sb.data(), sb.size(), iter, dk,
                       out.data());
    std::string hex;
    hexlify(out.data(), out.size(), hex);
    return Rf_mkString(hex.c_str());
}

SEXP C_rmbl_os_random(SEXP n) {
    const int nn = Rf_asInteger(n);
    if (nn < 1 || nn > 1048576) {
        Rf_error("`n` must be between 1 and 1048576 bytes");
    }
    std::vector<unsigned char> buf(static_cast<size_t>(nn));
    if (rmbl_os_random(buf.data(), buf.size()) != 0) {
        return R_NilValue;   /* the R layer decides how to react */
    }
    SEXP out = PROTECT(Rf_allocVector(RAWSXP, nn));
    std::memcpy(RAW(out), buf.data(), buf.size());
    UNPROTECT(1);
    return out;
}

}  // extern "C"
