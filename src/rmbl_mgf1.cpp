/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * HMAC (RFC 2104) and MGF1 (RFC 8017 B.2.1) over SHA-256 and SHA-512.
 *
 * These exist for the SHA-2 instantiation of SLH-DSA (FIPS 205), whose
 * message randomiser is an HMAC and whose message digest is an MGF1,
 * over SHA-256 below 192-bit security and SHA-512 at or above it.
 *
 * Neither hash is reimplemented here: rmbl_sha256_raw (rmbl_core.cpp)
 * and rmbl_sha512_raw (rmbl_digest.cpp) are the single implementations,
 * already checked against the FIPS 180-4 vectors, and this file calls
 * them. A second copy of a hash function is a second thing that can be
 * subtly wrong.
 */

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>

#include <R.h>
#include <Rinternals.h>

extern "C" void rmbl_sha256_raw(const unsigned char *data, size_t len,
                                unsigned char out[32]);
extern "C" void rmbl_sha512_raw(const unsigned char *data, size_t len,
                                unsigned char out[64]);
extern "C" void rmbl_sha384_raw(const unsigned char *data, size_t len,
                                unsigned char out[48]);

namespace {

/* Dispatch on the digest length, which is 32 or 64 and nothing else. */
inline void shax(int outlen, const unsigned char *data, size_t len,
                 unsigned char *out) {
    if (outlen == 64) {
        rmbl_sha512_raw(data, len, out);
    } else {
        rmbl_sha256_raw(data, len, out);
    }
}

}  // namespace

extern "C" {

/* The block size follows from the digest -- 64 bytes for SHA-256, 128
 * for SHA-512 -- and pairing them wrongly would give a MAC that is
 * sound and non-standard at the same time. */
void rmbl_hmac_shax(int outlen, const unsigned char *key, size_t keylen,
                    const unsigned char *msg, size_t msglen,
                    unsigned char *out) {
    const size_t block = (outlen == 64) ? 128u : 64u;
    std::vector<unsigned char> k(block, 0);
    if (keylen > block) {
        shax(outlen, key, keylen, k.data());
    } else if (keylen > 0) {
        std::memcpy(k.data(), key, keylen);
    }
    std::vector<unsigned char> inner(block);
    for (size_t i = 0; i < block; ++i) {
        inner[i] = static_cast<unsigned char>(k[i] ^ 0x36);
    }
    inner.insert(inner.end(), msg, msg + msglen);
    unsigned char ih[64];
    shax(outlen, inner.data(), inner.size(), ih);
    std::vector<unsigned char> outer(block);
    for (size_t i = 0; i < block; ++i) {
        outer[i] = static_cast<unsigned char>(k[i] ^ 0x5c);
    }
    outer.insert(outer.end(), ih, ih + outlen);
    shax(outlen, outer.data(), outer.size(), out);
}

/* H(seed || i) for i = 0, 1, 2, ..., truncated to `outlen`, with the
 * counter written big-endian in four bytes. */
void rmbl_mgf1_shax(int hashlen, unsigned char *out, size_t outlen,
                    const unsigned char *seed, size_t seedlen) {
    const size_t hlen = (hashlen == 64) ? 64u : 32u;
    std::vector<unsigned char> buf(seed, seed + seedlen);
    buf.resize(seedlen + 4u);
    unsigned char h[64];
    size_t done = 0;
    for (uint32_t ctr = 0; done < outlen; ++ctr) {
        for (size_t i = 0; i < 4u; ++i) {
            buf[seedlen + i] =
                static_cast<unsigned char>(ctr >> (8u * (3u - i)));
        }
        shax(hashlen, buf.data(), buf.size(), h);
        const size_t take = (outlen - done) < hlen ? (outlen - done) : hlen;
        std::memcpy(out + done, h, take);
        done += take;
    }
}

/* Exposed so the RFC 4231 and RFC 8017 vectors can be asserted from the
 * test suite rather than trusted. */
/* Exposed so the FIPS 180-4 SHA-384 vectors can be asserted. */
SEXP C_rmbl_sha384(SEXP x) {
    if (TYPEOF(x) != RAWSXP) Rf_error("`x` must be a raw vector");
    SEXP out = PROTECT(Rf_allocVector(RAWSXP, 48));
    rmbl_sha384_raw(RAW(x), static_cast<size_t>(XLENGTH(x)), RAW(out));
    UNPROTECT(1);
    return out;
}

SEXP C_rmbl_hmac_shax(SEXP bits, SEXP key, SEXP msg) {
    if (TYPEOF(bits) != INTSXP || XLENGTH(bits) != 1) {
        Rf_error("`bits` must be 256 or 512");
    }
    if (INTEGER(bits)[0] != 256 && INTEGER(bits)[0] != 512) {
        Rf_error("`bits` must be 256 or 512");
    }
    if (TYPEOF(key) != RAWSXP || TYPEOF(msg) != RAWSXP) {
        Rf_error("`key` and `msg` must be raw vectors");
    }
    const int n = (INTEGER(bits)[0] == 512) ? 64 : 32;
    SEXP out = PROTECT(Rf_allocVector(RAWSXP, n));
    rmbl_hmac_shax(n, RAW(key), static_cast<size_t>(XLENGTH(key)),
                   RAW(msg), static_cast<size_t>(XLENGTH(msg)), RAW(out));
    UNPROTECT(1);
    return out;
}

SEXP C_rmbl_mgf1(SEXP bits, SEXP seed, SEXP outlen) {
    if (TYPEOF(bits) != INTSXP || XLENGTH(bits) != 1) {
        Rf_error("`bits` must be 256 or 512");
    }
    if (INTEGER(bits)[0] != 256 && INTEGER(bits)[0] != 512) {
        Rf_error("`bits` must be 256 or 512");
    }
    if (TYPEOF(seed) != RAWSXP) Rf_error("`seed` must be a raw vector");
    if (TYPEOF(outlen) != INTSXP || XLENGTH(outlen) != 1 ||
        INTEGER(outlen)[0] < 1) {
        Rf_error("`outlen` must be a positive integer");
    }
    const int n = (INTEGER(bits)[0] == 512) ? 64 : 32;
    SEXP out = PROTECT(Rf_allocVector(RAWSXP, INTEGER(outlen)[0]));
    rmbl_mgf1_shax(n, RAW(out), static_cast<size_t>(XLENGTH(out)),
                   RAW(seed), static_cast<size_t>(XLENGTH(seed)));
    UNPROTECT(1);
    return out;
}

}  // extern "C"
