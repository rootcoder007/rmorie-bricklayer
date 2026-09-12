/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * rmbl_digest.cpp -- bricklayer's provenance digests beyond SHA-256.
 *
 * bricklayer-specific (not part of morie's vendored numeric core):
 *
 *   * SHA-512      (FIPS 180-4) -- a wider digest for long-lived pins.
 *   * HMAC-SHA-256 (RFC 2104)   -- lets a manifest be SIGNED with a key,
 *                                  so provenance can be authenticated and
 *                                  not merely checked for corruption.
 *   * CRC-32       (ITU V.42 / zip, reflected polynomial 0xEDB88320) --
 *                                  a cheap integrity check for very large
 *                                  capsule members, where SHA-256 over
 *                                  gigabytes is the wrong tool.
 *   * Merkle tree over SHA-256 leaves -- identifies WHICH chunk of a
 *                                  capsule changed, not merely that the
 *                                  whole file did, and proves a chunk's
 *                                  membership with log2(n) hashes.
 *
 * The SHA-256 compression function is NOT duplicated here: the raw
 * digest comes from rmbl_sha256_raw in rmbl_core.cpp, so there is one
 * implementation of it in the package.
 *
 * Odd levels of the Merkle tree PROMOTE the unpaired node rather than
 * duplicating it. Duplicating the last leaf makes two distinct leaf
 * sets hash to the same root (the CVE-2012-2459 shape); promotion does
 * not.
 */

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include <cstdint>
#include <cstddef>
#include <cstring>
#include <string>
#include <vector>

/* The one SHA-256 in this package (rmbl_core.cpp). */
extern "C" void rmbl_sha256_raw(const unsigned char *data, size_t len,
                                unsigned char out[32]);

namespace {

const char kHex[] = "0123456789abcdef";

inline void hexlify(const unsigned char *bytes, size_t n, char *out) {
    for (size_t i = 0; i < n; ++i) {
        out[i * 2] = kHex[(bytes[i] >> 4) & 0xf];
        out[i * 2 + 1] = kHex[bytes[i] & 0xf];
    }
    out[n * 2] = '\0';
}

/* ---------------- SHA-512 (FIPS 180-4) ---------------- */

const uint64_t kSha512K[80] = {
    0x428a2f98d728ae22ULL, 0x7137449123ef65cdULL, 0xb5c0fbcfec4d3b2fULL,
    0xe9b5dba58189dbbcULL, 0x3956c25bf348b538ULL, 0x59f111f1b605d019ULL,
    0x923f82a4af194f9bULL, 0xab1c5ed5da6d8118ULL, 0xd807aa98a3030242ULL,
    0x12835b0145706fbeULL, 0x243185be4ee4b28cULL, 0x550c7dc3d5ffb4e2ULL,
    0x72be5d74f27b896fULL, 0x80deb1fe3b1696b1ULL, 0x9bdc06a725c71235ULL,
    0xc19bf174cf692694ULL, 0xe49b69c19ef14ad2ULL, 0xefbe4786384f25e3ULL,
    0x0fc19dc68b8cd5b5ULL, 0x240ca1cc77ac9c65ULL, 0x2de92c6f592b0275ULL,
    0x4a7484aa6ea6e483ULL, 0x5cb0a9dcbd41fbd4ULL, 0x76f988da831153b5ULL,
    0x983e5152ee66dfabULL, 0xa831c66d2db43210ULL, 0xb00327c898fb213fULL,
    0xbf597fc7beef0ee4ULL, 0xc6e00bf33da88fc2ULL, 0xd5a79147930aa725ULL,
    0x06ca6351e003826fULL, 0x142929670a0e6e70ULL, 0x27b70a8546d22ffcULL,
    0x2e1b21385c26c926ULL, 0x4d2c6dfc5ac42aedULL, 0x53380d139d95b3dfULL,
    0x650a73548baf63deULL, 0x766a0abb3c77b2a8ULL, 0x81c2c92e47edaee6ULL,
    0x92722c851482353bULL, 0xa2bfe8a14cf10364ULL, 0xa81a664bbc423001ULL,
    0xc24b8b70d0f89791ULL, 0xc76c51a30654be30ULL, 0xd192e819d6ef5218ULL,
    0xd69906245565a910ULL, 0xf40e35855771202aULL, 0x106aa07032bbd1b8ULL,
    0x19a4c116b8d2d0c8ULL, 0x1e376c085141ab53ULL, 0x2748774cdf8eeb99ULL,
    0x34b0bcb5e19b48a8ULL, 0x391c0cb3c5c95a63ULL, 0x4ed8aa4ae3418acbULL,
    0x5b9cca4f7763e373ULL, 0x682e6ff3d6b2b8a3ULL, 0x748f82ee5defb2fcULL,
    0x78a5636f43172f60ULL, 0x84c87814a1f0ab72ULL, 0x8cc702081a6439ecULL,
    0x90befffa23631e28ULL, 0xa4506cebde82bde9ULL, 0xbef9a3f7b2c67915ULL,
    0xc67178f2e372532bULL, 0xca273eceea26619cULL, 0xd186b8c721c0c207ULL,
    0xeada7dd6cde0eb1eULL, 0xf57d4f7fee6ed178ULL, 0x06f067aa72176fbaULL,
    0x0a637dc5a2c898a6ULL, 0x113f9804bef90daeULL, 0x1b710b35131c471bULL,
    0x28db77f523047d84ULL, 0x32caab7b40c72493ULL, 0x3c9ebe0a15c9bebcULL,
    0x431d67c49c100d4cULL, 0x4cc5d4becb3e42b6ULL, 0x597f299cfc657e2aULL,
    0x5fcb6fab3ad6faecULL, 0x6c44198c4a475817ULL
};

inline uint64_t rotr64(uint64_t x, unsigned k) {
    return (x >> k) | (x << (64 - k));
}

struct sha512_ctx {
    uint8_t  buf[128];
    size_t   buflen;
    uint64_t bitlen_lo;
    uint64_t bitlen_hi;
    uint64_t h[8];
};

void sha512_compress(sha512_ctx *c, const uint8_t blk[128]) {
    uint64_t w[80];
    for (int i = 0; i < 16; ++i) {
        w[i] = 0;
        for (int j = 0; j < 8; ++j) {
            w[i] = (w[i] << 8) | blk[i * 8 + j];
        }
    }
    for (int i = 16; i < 80; ++i) {
        const uint64_t s0 = rotr64(w[i - 15], 1) ^ rotr64(w[i - 15], 8) ^
                            (w[i - 15] >> 7);
        const uint64_t s1 = rotr64(w[i - 2], 19) ^ rotr64(w[i - 2], 61) ^
                            (w[i - 2] >> 6);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    uint64_t a = c->h[0], b = c->h[1], cc = c->h[2], d = c->h[3];
    uint64_t e = c->h[4], f = c->h[5], g = c->h[6], hh = c->h[7];
    for (int i = 0; i < 80; ++i) {
        const uint64_t S1 = rotr64(e, 14) ^ rotr64(e, 18) ^ rotr64(e, 41);
        const uint64_t ch = (e & f) ^ ((~e) & g);
        const uint64_t t1 = hh + S1 + ch + kSha512K[i] + w[i];
        const uint64_t S0 = rotr64(a, 28) ^ rotr64(a, 34) ^ rotr64(a, 39);
        const uint64_t mj = (a & b) ^ (a & cc) ^ (b & cc);
        const uint64_t t2 = S0 + mj;
        hh = g; g = f; f = e; e = d + t1;
        d = cc; cc = b; b = a; a = t1 + t2;
    }
    c->h[0] += a; c->h[1] += b; c->h[2] += cc; c->h[3] += d;
    c->h[4] += e; c->h[5] += f; c->h[6] += g; c->h[7] += hh;
}

void sha512_init(sha512_ctx *c) {
    c->buflen = 0;
    c->bitlen_lo = 0;
    c->bitlen_hi = 0;
    c->h[0] = 0x6a09e667f3bcc908ULL; c->h[1] = 0xbb67ae8584caa73bULL;
    c->h[2] = 0x3c6ef372fe94f82bULL; c->h[3] = 0xa54ff53a5f1d36f1ULL;
    c->h[4] = 0x510e527fade682d1ULL; c->h[5] = 0x9b05688c2b3e6c1fULL;
    c->h[6] = 0x1f83d9abfb41bd6bULL; c->h[7] = 0x5be0cd19137e2179ULL;
}

void sha512_update(sha512_ctx *c, const uint8_t *data, size_t len) {
    /* In bulk, for the same reason as SHA-256: a branch per byte is
     * what the hash-based signature schemes cannot afford. */
    const auto bump = [c]() {
        const uint64_t before = c->bitlen_lo;
        c->bitlen_lo += 1024;
        if (c->bitlen_lo < before) ++c->bitlen_hi;
    };
    if (c->buflen > 0) {
        const size_t want = 128u - c->buflen;
        const size_t take = (len < want) ? len : want;
        std::memcpy(c->buf + c->buflen, data, take);
        c->buflen += take;
        data += take;
        len -= take;
        if (c->buflen == 128) {
            sha512_compress(c, c->buf);
            bump();
            c->buflen = 0;
        }
    }
    while (len >= 128) {
        sha512_compress(c, data);
        bump();
        data += 128;
        len -= 128;
    }
    if (len > 0) {
        std::memcpy(c->buf, data, len);
        c->buflen = len;
    }
}

void sha512_final(sha512_ctx *c, uint8_t out[64]) {
    const uint64_t before = c->bitlen_lo;
    c->bitlen_lo += static_cast<uint64_t>(c->buflen) * 8ULL;
    if (c->bitlen_lo < before) ++c->bitlen_hi;

    size_t i = c->buflen;
    c->buf[i++] = 0x80;
    if (i > 112) {
        while (i < 128) c->buf[i++] = 0x00;
        sha512_compress(c, c->buf);
        i = 0;
    }
    while (i < 112) c->buf[i++] = 0x00;
    for (int j = 7; j >= 0; --j) {
        c->buf[i++] = static_cast<uint8_t>((c->bitlen_hi >> (j * 8)) & 0xff);
    }
    for (int j = 7; j >= 0; --j) {
        c->buf[i++] = static_cast<uint8_t>((c->bitlen_lo >> (j * 8)) & 0xff);
    }
    sha512_compress(c, c->buf);
    for (int k = 0; k < 8; ++k) {
        for (int j = 0; j < 8; ++j) {
            out[k * 8 + j] =
                static_cast<uint8_t>((c->h[k] >> (56 - j * 8)) & 0xff);
        }
    }
}

/* ---------------- CRC-32 (reflected 0xEDB88320) ---------------- */

uint32_t crc32_table[256];
bool crc32_ready = false;

void crc32_init_table(void) {
    for (uint32_t i = 0; i < 256; ++i) {
        uint32_t c = i;
        for (int k = 0; k < 8; ++k) {
            c = (c & 1u) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
        }
        crc32_table[i] = c;
    }
    crc32_ready = true;
}

}  // namespace

extern "C" {

/* The state after one 128-byte block, and a resume from it -- the
 * SHA-512 half of what rmbl_sha256_midstate() exists for. */
/* SHA-1 (FIPS 180-4).
 *
 * Present for exactly one purpose: an OCSP CertID identifies a
 * certificate by the SHA-1 hashes of its issuer's name and public key
 * (RFC 6960 section 4.1.1), and a responder keyed on anything else
 * answers "unauthorized". It is NOT used to verify any signature here,
 * and must not be: SHA-1 collisions are practical.
 */
void rmbl_sha1_raw(const unsigned char *data, size_t len,
                   unsigned char out[20]) {
    uint32_t h0 = 0x67452301u, h1 = 0xEFCDAB89u, h2 = 0x98BADCFEu;
    uint32_t h3 = 0x10325476u, h4 = 0xC3D2E1F0u;
    const uint64_t bits = static_cast<uint64_t>(len) * 8u;
    /* one buffer for the message plus its padding, processed in blocks */
    const size_t total = ((len + 9u + 63u) / 64u) * 64u;
    std::vector<unsigned char> buf(total, 0);
    if (len > 0) std::memcpy(buf.data(), data, len);
    buf[len] = 0x80;
    for (int i = 0; i < 8; ++i) {
        buf[total - 1 - static_cast<size_t>(i)] =
            static_cast<unsigned char>(bits >> (8 * i));
    }
    for (size_t off = 0; off < total; off += 64) {
        uint32_t w[80];
        for (int i = 0; i < 16; ++i) {
            w[i] = (static_cast<uint32_t>(buf[off + 4 * i]) << 24) |
                   (static_cast<uint32_t>(buf[off + 4 * i + 1]) << 16) |
                   (static_cast<uint32_t>(buf[off + 4 * i + 2]) << 8) |
                   static_cast<uint32_t>(buf[off + 4 * i + 3]);
        }
        for (int i = 16; i < 80; ++i) {
            const uint32_t v = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16];
            w[i] = (v << 1) | (v >> 31);
        }
        uint32_t a = h0, b = h1, c = h2, d = h3, e = h4;
        for (int i = 0; i < 80; ++i) {
            uint32_t f, k;
            if (i < 20) {
                f = (b & c) | ((~b) & d);
                k = 0x5A827999u;
            } else if (i < 40) {
                f = b ^ c ^ d;
                k = 0x6ED9EBA1u;
            } else if (i < 60) {
                f = (b & c) | (b & d) | (c & d);
                k = 0x8F1BBCDCu;
            } else {
                f = b ^ c ^ d;
                k = 0xCA62C1D6u;
            }
            const uint32_t t = ((a << 5) | (a >> 27)) + f + e + k + w[i];
            e = d;
            d = c;
            c = (b << 30) | (b >> 2);
            b = a;
            a = t;
        }
        h0 += a; h1 += b; h2 += c; h3 += d; h4 += e;
    }
    const uint32_t hs[5] = {h0, h1, h2, h3, h4};
    for (int i = 0; i < 5; ++i) {
        for (int j = 0; j < 4; ++j) {
            out[4 * i + j] =
                static_cast<unsigned char>(hs[i] >> (24 - 8 * j));
        }
    }
}

/* SHA-384 (FIPS 180-4): the SHA-512 compression function with a
 * different initial state, truncated to 48 bytes. Needed because
 * ecdsa-with-SHA384 is a certificate signature algorithm in common use,
 * and a verifier that cannot compute the digest cannot check the
 * signature. */
void rmbl_sha384_raw(const unsigned char *data, size_t len,
                     unsigned char out[48]) {
    sha512_ctx c;
    sha512_init(&c);
    /* the SHA-384 initial state */
    c.h[0] = 0xcbbb9d5dc1059ed8ULL;
    c.h[1] = 0x629a292a367cd507ULL;
    c.h[2] = 0x9159015a3070dd17ULL;
    c.h[3] = 0x152fecd8f70e5939ULL;
    c.h[4] = 0x67332667ffc00b31ULL;
    c.h[5] = 0x8eb44a8768581511ULL;
    c.h[6] = 0xdb0c2e0d64f98fa7ULL;
    c.h[7] = 0x47b5481dbefa4fa4ULL;
    unsigned char full[64];
    sha512_update(&c, data, len);
    sha512_final(&c, full);
    std::memcpy(out, full, 48);
}

void rmbl_sha512_midstate(const unsigned char block[128],
                          uint64_t state_out[8]) {
    sha512_ctx c;
    sha512_init(&c);
    sha512_compress(&c, block);
    std::memcpy(state_out, c.h, sizeof c.h);
}

void rmbl_sha512_finish(const uint64_t state_in[8], size_t prefix_blocks,
                        const unsigned char *tail, size_t taillen,
                        unsigned char out[64]) {
    sha512_ctx c;
    sha512_init(&c);
    std::memcpy(c.h, state_in, sizeof c.h);
    c.bitlen_lo = static_cast<uint64_t>(prefix_blocks) * 1024u;
    c.bitlen_hi = 0;
    c.buflen = 0;
    sha512_update(&c, tail, taillen);
    sha512_final(&c, out);
}

void rmbl_sha512_hex(const unsigned char *data, size_t len, char out[129]) {
    sha512_ctx c;
    uint8_t h[64];
    sha512_init(&c);
    sha512_update(&c, data, len);
    sha512_final(&c, h);
    hexlify(h, 64, out);
}

/* The same digest as raw bytes. The SHA-2 instantiation of SLH-DSA
 * (FIPS 205) truncates it to n, so it needs the bytes rather than the
 * hex spelling. */
void rmbl_sha512_raw(const unsigned char *data, size_t len,
                     unsigned char out[64]) {
    sha512_ctx c;
    sha512_init(&c);
    sha512_update(&c, data, len);
    sha512_final(&c, out);
}

uint32_t rmbl_crc32(const unsigned char *data, size_t len) {
    if (!crc32_ready) crc32_init_table();
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < len; ++i) {
        c = crc32_table[(c ^ data[i]) & 0xffu] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFFu;
}

/* HMAC-SHA-256 (RFC 2104): H((K' ^ opad) || H((K' ^ ipad) || msg)),
 * with K' the key hashed down to 32 bytes when longer than the 64-byte
 * block and zero-padded to 64 otherwise. */
void rmbl_hmac_sha256_hex(const unsigned char *key, size_t keylen,
                          const unsigned char *msg, size_t msglen,
                          char out[65]) {
    unsigned char k0[64];
    std::memset(k0, 0, sizeof(k0));
    if (keylen > 64) {
        unsigned char kh[32];
        rmbl_sha256_raw(key, keylen, kh);
        std::memcpy(k0, kh, 32);
    } else {
        std::memcpy(k0, key, keylen);
    }

    std::vector<unsigned char> inner(64 + msglen);
    for (int i = 0; i < 64; ++i) inner[static_cast<size_t>(i)] = k0[i] ^ 0x36;
    if (msglen > 0) std::memcpy(inner.data() + 64, msg, msglen);
    unsigned char ih[32];
    rmbl_sha256_raw(inner.data(), inner.size(), ih);

    unsigned char outer[64 + 32];
    for (int i = 0; i < 64; ++i) outer[i] = k0[i] ^ 0x5c;
    std::memcpy(outer + 64, ih, 32);
    unsigned char oh[32];
    rmbl_sha256_raw(outer, sizeof(outer), oh);
    hexlify(oh, 32, out);
}

/* Constant-time digest comparison: a verifier must not leak how much of
 * a supplied tag was correct through its timing. */
int rmbl_digest_equal(const char *a, const char *b, size_t n) {
    unsigned char diff = 0;
    for (size_t i = 0; i < n; ++i) {
        diff = static_cast<unsigned char>(
            diff | (static_cast<unsigned char>(a[i]) ^
                    static_cast<unsigned char>(b[i])));
    }
    return diff == 0 ? 1 : 0;
}

}  // extern "C"

namespace {

/* Merkle level reduction over raw 32-byte digests. An unpaired node is
 * promoted unchanged. */
std::vector<unsigned char> merkle_reduce(const std::vector<unsigned char> &lvl) {
    const size_t nodes = lvl.size() / 32;
    std::vector<unsigned char> up;
    up.reserve(((nodes + 1) / 2) * 32);
    size_t i = 0;
    while (i + 1 < nodes) {
        unsigned char pair[64];
        std::memcpy(pair, lvl.data() + i * 32, 32);
        std::memcpy(pair + 32, lvl.data() + (i + 1) * 32, 32);
        unsigned char h[32];
        rmbl_sha256_raw(pair, 64, h);
        up.insert(up.end(), h, h + 32);
        i += 2;
    }
    if (i < nodes) {
        up.insert(up.end(), lvl.data() + i * 32, lvl.data() + (i + 1) * 32);
    }
    return up;
}

/* Level-0 digests from a list of raw vectors. Chunks are BYTES: a chunk
 * may contain a zero byte, and nothing here goes through a C string, so
 * the digest of a chunk is the digest of exactly the bytes supplied.
 * The R layer is responsible for normalising its argument to this shape
 * (see .rmbl_chunk_bytes), which keeps the byte sequence for a character
 * chunk identical to what earlier versions hashed. */
std::vector<unsigned char> leaves_from_chunks(SEXP x) {
    const R_xlen_t n = XLENGTH(x);
    std::vector<unsigned char> lvl;
    lvl.reserve(static_cast<size_t>(n) * 32);
    for (R_xlen_t i = 0; i < n; ++i) {
        SEXP e = VECTOR_ELT(x, i);
        if (TYPEOF(e) != RAWSXP) {
            Rf_error("each chunk must be a raw vector");
        }
        unsigned char h[32];
        rmbl_sha256_raw(RAW(e), static_cast<size_t>(XLENGTH(e)), h);
        lvl.insert(lvl.end(), h, h + 32);
    }
    return lvl;
}

/* Shared entry guard: the three Merkle entry points all take the same
 * normalised list of raw chunks. */
void check_chunk_list(SEXP x) {
    if (TYPEOF(x) != VECSXP) {
        Rf_error("`chunks` must be a list of raw vectors");
    }
}

}  // namespace

extern "C" {

SEXP C_rmbl_sha512(SEXP x) {
    char out[129];
    if (TYPEOF(x) == RAWSXP) {
        rmbl_sha512_hex(RAW(x), static_cast<size_t>(XLENGTH(x)), out);
        return Rf_mkString(out);
    }
    x = PROTECT(Rf_coerceVector(x, STRSXP));
    const R_xlen_t n = XLENGTH(x);
    SEXP res = PROTECT(Rf_allocVector(STRSXP, n));
    for (R_xlen_t i = 0; i < n; ++i) {
        const char *s = CHAR(STRING_ELT(x, i));
        rmbl_sha512_hex(reinterpret_cast<const unsigned char *>(s),
                        std::strlen(s), out);
        SET_STRING_ELT(res, i, Rf_mkChar(out));
    }
    UNPROTECT(2);
    return res;
}

SEXP C_rmbl_crc32(SEXP x) {
    if (TYPEOF(x) == RAWSXP) {
        return Rf_ScalarReal(static_cast<double>(
            rmbl_crc32(RAW(x), static_cast<size_t>(XLENGTH(x)))));
    }
    x = PROTECT(Rf_coerceVector(x, STRSXP));
    const R_xlen_t n = XLENGTH(x);
    SEXP res = PROTECT(Rf_allocVector(REALSXP, n));
    for (R_xlen_t i = 0; i < n; ++i) {
        const char *s = CHAR(STRING_ELT(x, i));
        REAL(res)[i] = static_cast<double>(
            rmbl_crc32(reinterpret_cast<const unsigned char *>(s),
                       std::strlen(s)));
    }
    UNPROTECT(2);
    return res;
}

SEXP C_rmbl_hmac_sha256(SEXP key, SEXP msg) {
    std::vector<unsigned char> kb, mb;
    if (TYPEOF(key) == RAWSXP) {
        kb.assign(RAW(key), RAW(key) + XLENGTH(key));
    } else {
        SEXP k = PROTECT(Rf_coerceVector(key, STRSXP));
        const char *s = CHAR(STRING_ELT(k, 0));
        kb.assign(s, s + std::strlen(s));
        UNPROTECT(1);
    }
    if (TYPEOF(msg) == RAWSXP) {
        mb.assign(RAW(msg), RAW(msg) + XLENGTH(msg));
    } else {
        SEXP m = PROTECT(Rf_coerceVector(msg, STRSXP));
        const char *s = CHAR(STRING_ELT(m, 0));
        mb.assign(s, s + std::strlen(s));
        UNPROTECT(1);
    }
    char out[65];
    rmbl_hmac_sha256_hex(kb.data(), kb.size(), mb.data(), mb.size(), out);
    return Rf_mkString(out);
}

SEXP C_rmbl_digest_equal(SEXP a, SEXP b) {
    a = PROTECT(Rf_coerceVector(a, STRSXP));
    b = PROTECT(Rf_coerceVector(b, STRSXP));
    const char *sa = CHAR(STRING_ELT(a, 0));
    const char *sb = CHAR(STRING_ELT(b, 0));
    int eq = 0;
    if (std::strlen(sa) == std::strlen(sb)) {
        eq = rmbl_digest_equal(sa, sb, std::strlen(sa));
    }
    UNPROTECT(2);
    return Rf_ScalarLogical(eq);
}

SEXP C_rmbl_merkle_root(SEXP x) {
    check_chunk_list(x);
    if (XLENGTH(x) < 1) return Rf_ScalarString(NA_STRING);
    std::vector<unsigned char> lvl = leaves_from_chunks(x);
    while (lvl.size() > 32) lvl = merkle_reduce(lvl);
    char out[65];
    hexlify(lvl.data(), 32, out);
    return Rf_mkString(out);
}

/* Leaf hashes, one per chunk -- the level-0 digests the root is built
 * from, so a caller can see WHICH chunk moved. */
SEXP C_rmbl_merkle_leaves(SEXP x) {
    check_chunk_list(x);
    const R_xlen_t n = XLENGTH(x);
    std::vector<unsigned char> lvl = leaves_from_chunks(x);
    SEXP res = PROTECT(Rf_allocVector(STRSXP, n));
    char out[65];
    for (R_xlen_t i = 0; i < n; ++i) {
        hexlify(lvl.data() + static_cast<size_t>(i) * 32, 32, out);
        SET_STRING_ELT(res, i, Rf_mkChar(out));
    }
    UNPROTECT(1);
    return res;
}

/* Inclusion proof for leaf `index` (1-based): the sibling digests from
 * the leaf up to the root, with the side each sibling sits on. */
SEXP C_rmbl_merkle_proof(SEXP x, SEXP index) {
    check_chunk_list(x);
    const R_xlen_t n = XLENGTH(x);
    R_xlen_t pos = static_cast<R_xlen_t>(Rf_asInteger(index)) - 1;
    if (n < 1 || pos < 0 || pos >= n) {
        Rf_error("`index` must be between 1 and the number of chunks");
    }
    std::vector<unsigned char> lvl = leaves_from_chunks(x);
    std::vector<std::string> sib;
    std::vector<int> side;   /* 0 = sibling on the left, 1 = on the right */
    char out[65];
    while (lvl.size() > 32) {
        const size_t nodes = lvl.size() / 32;
        const size_t p = static_cast<size_t>(pos);
        if (p + 1 == nodes && (nodes % 2 == 1)) {
            /* promoted: no sibling at this level */
            pos = static_cast<R_xlen_t>(p / 2);
        } else if (p % 2 == 0) {
            hexlify(lvl.data() + (p + 1) * 32, 32, out);
            sib.push_back(out);
            side.push_back(1);
            pos = static_cast<R_xlen_t>(p / 2);
        } else {
            hexlify(lvl.data() + (p - 1) * 32, 32, out);
            sib.push_back(out);
            side.push_back(0);
            pos = static_cast<R_xlen_t>(p / 2);
        }
        lvl = merkle_reduce(lvl);
    }
    const R_xlen_t m = static_cast<R_xlen_t>(sib.size());
    SEXP sh = PROTECT(Rf_allocVector(STRSXP, m));
    SEXP sd = PROTECT(Rf_allocVector(STRSXP, m));
    for (R_xlen_t i = 0; i < m; ++i) {
        SET_STRING_ELT(sh, i, Rf_mkChar(sib[static_cast<size_t>(i)].c_str()));
        SET_STRING_ELT(sd, i,
            Rf_mkChar(side[static_cast<size_t>(i)] == 1 ? "right" : "left"));
    }
    SEXP res = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(res, 0, sh);
    SET_VECTOR_ELT(res, 1, sd);
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(nm, 0, Rf_mkChar("sibling"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("side"));
    Rf_setAttrib(res, R_NamesSymbol, nm);
    UNPROTECT(4);
    return res;
}

}  // extern "C"
