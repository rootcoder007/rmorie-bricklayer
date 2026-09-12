#ifndef RMBL_PREHASH_H
#define RMBL_PREHASH_H

/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * The pre-hash step shared by HashML-DSA (FIPS 204 section 5.4) and
 * HashSLH-DSA (FIPS 205 section 10.2.2).
 *
 * Both standards sign
 *
 *   M' = 0x01 || |ctx| || ctx || OID(PH) || PH(M)
 *
 * where OID(PH) is the DER encoding of the pre-hash function's object
 * identifier. Binding the identifier, not just the digest, is what
 * stops a signature over a SHA-256 digest from being replayed as one
 * over a SHAKE128 digest of the same length: without it the two M'
 * values would be identical.
 *
 * The pure variants use 0x00 and no OID, which is why passing a zero
 * OID length through the same code path selects them.
 */

#include <cstddef>
#include <cstring>

#include <R.h>
#include <Rinternals.h>

extern "C" void rmbl_sha256_raw(const unsigned char *, size_t,
                                unsigned char[32]);
extern "C" void rmbl_sha512_raw(const unsigned char *, size_t,
                                unsigned char[64]);
extern "C" void rmbl_shake128(unsigned char *, size_t,
                              const unsigned char *, size_t);
extern "C" void rmbl_shake256(unsigned char *, size_t,
                              const unsigned char *, size_t);

namespace rmbl_prehash {

/* Room for the largest digest any of the four produces. */
const int kMaxDigest = 64;

struct Result {
    unsigned char digest[kMaxDigest];
    size_t digest_len;
    const unsigned char *oid;
    size_t oid_len;
};

/* DER: OBJECT IDENTIFIER, length 9, then the NIST hash arc
 * 2.16.840.1.101.3.4.2.x. The final byte is what distinguishes them. */
inline const unsigned char *oid_for(int which) {
    static const unsigned char kSha256[] = {
        0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01
    };
    static const unsigned char kSha512[] = {
        0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x03
    };
    static const unsigned char kShake128[] = {
        0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x0B
    };
    static const unsigned char kShake256[] = {
        0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x0C
    };
    switch (which) {
    case 1: return kSha256;
    case 2: return kSha512;
    case 3: return kShake128;
    default: return kShake256;
    }
}

/* Applies the named pre-hash. `name` is "" or "none" for the pure
 * variant, in which case the message passes through untouched and no
 * OID is attached. An unknown name is an error rather than a silent
 * fall-back to pure signing, which would produce a signature the caller
 * did not ask for. */
inline void apply(const char *name, const unsigned char *m, size_t mlen,
                  Result *out) {
    out->oid = NULL;
    out->oid_len = 0;
    out->digest_len = 0;
    if (name == NULL || name[0] == '\0' || std::strcmp(name, "none") == 0) {
        return;
    }
    int which = 0;
    if (std::strcmp(name, "sha256") == 0) {
        which = 1;
        rmbl_sha256_raw(m, mlen, out->digest);
        out->digest_len = 32;
    } else if (std::strcmp(name, "sha512") == 0) {
        which = 2;
        rmbl_sha512_raw(m, mlen, out->digest);
        out->digest_len = 64;
    } else if (std::strcmp(name, "shake128") == 0) {
        which = 3;
        /* FIPS 204 fixes the output at 256 bits for SHAKE128 and 512
         * for SHAKE256; the function is extendable but the pre-hash is
         * not a free choice. */
        rmbl_shake128(out->digest, 32, m, mlen);
        out->digest_len = 32;
    } else if (std::strcmp(name, "shake256") == 0) {
        which = 4;
        rmbl_shake256(out->digest, 64, m, mlen);
        out->digest_len = 64;
    } else {
        Rf_error("`prehash` must be one of none, sha256, sha512, "
                 "shake128, shake256");
    }
    out->oid = oid_for(which);
    out->oid_len = 11;
}

/* The name as an R argument, defaulting to pure when absent. */
inline const char *name_of(SEXP prehash) {
    if (prehash == R_NilValue) return "";
    if (TYPEOF(prehash) != STRSXP || XLENGTH(prehash) != 1) {
        Rf_error("`prehash` must be a single string");
    }
    return CHAR(STRING_ELT(prehash, 0));
}

}  // namespace rmbl_prehash

#endif
