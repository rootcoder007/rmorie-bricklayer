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
extern "C" void rmbl_sha224_raw(const unsigned char *, size_t,
                                unsigned char[28]);
extern "C" void rmbl_sha384_raw(const unsigned char *, size_t,
                                unsigned char[48]);
extern "C" void rmbl_sha512_raw(const unsigned char *, size_t,
                                unsigned char[64]);
extern "C" void rmbl_sha512t_raw(int, const unsigned char *, size_t,
                                 unsigned char *);
extern "C" void rmbl_sha3_224(unsigned char *, const unsigned char *, size_t);
extern "C" void rmbl_sha3_256(unsigned char *, const unsigned char *, size_t);
extern "C" void rmbl_sha3_384(unsigned char *, const unsigned char *, size_t);
extern "C" void rmbl_sha3_512(unsigned char *, const unsigned char *, size_t);
extern "C" void rmbl_shake128(unsigned char *, size_t,
                              const unsigned char *, size_t);
extern "C" void rmbl_shake256(unsigned char *, size_t,
                              const unsigned char *, size_t);

namespace rmbl_prehash {

/* Room for the largest digest any of them produces. */
const int kMaxDigest = 64;

struct Result {
    unsigned char digest[kMaxDigest];
    size_t digest_len;
    const unsigned char *oid;
    size_t oid_len;
};

/* Every approved hash function FIPS 204 section 5.4 and FIPS 205 section
 * 10.2 admit as a pre-hash, by the name the R side uses, the last arc of
 * its OID under 2.16.840.1.101.3.4.2 and its output length. SHAKE128 and
 * SHAKE256 are fixed at 256 and 512 bits: the function is extendable but
 * the pre-hash is not a free choice. */
struct Entry {
    const char *name;
    unsigned char arc;
    size_t len;
};
inline const Entry *table(size_t *n) {
    static const Entry kTable[] = {
        {"sha224", 0x04, 28},     {"sha256", 0x01, 32},
        {"sha384", 0x02, 48},     {"sha512", 0x03, 64},
        {"sha512_224", 0x05, 28}, {"sha512_256", 0x06, 32},
        {"sha3_224", 0x07, 28},   {"sha3_256", 0x08, 32},
        {"sha3_384", 0x09, 48},   {"sha3_512", 0x0A, 64},
        {"shake128", 0x0B, 32},   {"shake256", 0x0C, 64},
    };
    *n = sizeof kTable / sizeof kTable[0];
    return kTable;
}

/* DER: OBJECT IDENTIFIER, length 9, then the NIST hash arc
 * 2.16.840.1.101.3.4.2.x. The final byte is what distinguishes them. */
inline const unsigned char *oid_for(unsigned char arc) {
    static unsigned char kOid[13][11];
    static bool ready = false;
    if (!ready) {
        for (int a = 0; a < 13; ++a) {
            const unsigned char base[11] = {0x06, 0x09, 0x60, 0x86, 0x48, 0x01,
                                            0x65, 0x03, 0x04, 0x02, 0x00};
            std::memcpy(kOid[a], base, 11);
            kOid[a][10] = static_cast<unsigned char>(a);
        }
        ready = true;
    }
    return kOid[arc];
}

/* The digest alone, for a name in the table; false for any other name. */
inline bool digest(const char *name, const unsigned char *m, size_t mlen,
                   unsigned char *out, size_t *outlen, unsigned char *arc) {
    size_t n = 0;
    const Entry *t = table(&n);
    for (size_t i = 0; i < n; ++i) {
        if (std::strcmp(name, t[i].name) != 0) continue;
        switch (t[i].arc) {
        case 0x04: rmbl_sha224_raw(m, mlen, out); break;
        case 0x01: rmbl_sha256_raw(m, mlen, out); break;
        case 0x02: rmbl_sha384_raw(m, mlen, out); break;
        case 0x03: rmbl_sha512_raw(m, mlen, out); break;
        case 0x05: rmbl_sha512t_raw(224, m, mlen, out); break;
        case 0x06: rmbl_sha512t_raw(256, m, mlen, out); break;
        case 0x07: rmbl_sha3_224(out, m, mlen); break;
        case 0x08: rmbl_sha3_256(out, m, mlen); break;
        case 0x09: rmbl_sha3_384(out, m, mlen); break;
        case 0x0A: rmbl_sha3_512(out, m, mlen); break;
        case 0x0B: rmbl_shake128(out, 32, m, mlen); break;
        default:   rmbl_shake256(out, 64, m, mlen); break;
        }
        *outlen = t[i].len;
        *arc = t[i].arc;
        return true;
    }
    return false;
}

#define RMBL_PREHASH_NAMES "none, sha224, sha256, sha384, sha512, sha512_224, " \
    "sha512_256, sha3_224, sha3_256, sha3_384, sha3_512, shake128, shake256"

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
    unsigned char arc = 0;
    if (!digest(name, m, mlen, out->digest, &out->digest_len, &arc)) {
        Rf_error("`prehash` must be one of " RMBL_PREHASH_NAMES);
    }
    out->oid = oid_for(arc);
    out->oid_len = 11;
}

/* The name as an R argument, defaulting to pure when absent. */
inline const char *name_of(SEXP prehash) {
    if (prehash == R_NilValue) return "";
    if (TYPEOF(prehash) != STRSXP || XLENGTH(prehash) != 1) {
        Rf_error("`prehash` must be a single string");
    }
    if (STRING_ELT(prehash, 0) == NA_STRING) Rf_error("`prehash` must not be NA");
    return CHAR(STRING_ELT(prehash, 0));
}

}  // namespace rmbl_prehash

#endif
