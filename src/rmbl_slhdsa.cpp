/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * SLH-DSA (FIPS 205), every parameter set the standard defines -- six
 * SHAKE and six SHA-2 -- implemented natively so this package needs no
 * system dependency for a standardised post-quantum signature.
 *
 * The hypertree, WOTS+ and FORS machinery is in rmbl_slhdsa_body.h,
 * included once per parameter set. The two hash instantiations differ
 * in more than the hash function: the SHA-2 one compresses the address
 * from 32 bytes to 22 and moves every field in it, uses HMAC for the
 * message randomiser and MGF1 for the digest, and switches from SHA-256
 * to SHA-512 for the multi-block tweakable hash at 192-bit security and
 * above (but not for the single-block one, even there).
 *
 * Verified against OpenSSL 3.5 in both directions for every parameter
 * set, over several message and context lengths. Two things diverge
 * from the round-3 SPHINCS+ submission and both had to be found by that
 * cross-check rather than by reference parity, because a wrong choice
 * still verifies against itself:
 *
 *   - FIPS 205 prepends (0x00, |ctx|, ctx) to the message, exactly as
 *     FIPS 204 does for ML-DSA. SPHINCS+ does not.
 *   - FIPS 205 reads the FORS indices out of the digest with base_2b,
 *     most significant bit first. SPHINCS+ read each group of a bits
 *     least significant bit first, which selects a different leaf from
 *     every tree.
 */

#include "rmbl_slhdsa_core.h"
#include "rmbl_prehash.h"

#define SLH_NS rmbl_slhdsa_shake_128s
#define SLH_N 16
#define SLH_H 63
#define SLH_D 7
#define SLH_A 12
#define SLH_K 14
#define SLH_SHA2 0
#include "rmbl_slhdsa_body.h"
#undef SLH_NS
#undef SLH_N
#undef SLH_H
#undef SLH_D
#undef SLH_A
#undef SLH_K
#undef SLH_SHA2

#define SLH_NS rmbl_slhdsa_shake_128f
#define SLH_N 16
#define SLH_H 66
#define SLH_D 22
#define SLH_A 6
#define SLH_K 33
#define SLH_SHA2 0
#include "rmbl_slhdsa_body.h"
#undef SLH_NS
#undef SLH_N
#undef SLH_H
#undef SLH_D
#undef SLH_A
#undef SLH_K
#undef SLH_SHA2

#define SLH_NS rmbl_slhdsa_shake_192s
#define SLH_N 24
#define SLH_H 63
#define SLH_D 7
#define SLH_A 14
#define SLH_K 17
#define SLH_SHA2 0
#include "rmbl_slhdsa_body.h"
#undef SLH_NS
#undef SLH_N
#undef SLH_H
#undef SLH_D
#undef SLH_A
#undef SLH_K
#undef SLH_SHA2

#define SLH_NS rmbl_slhdsa_shake_192f
#define SLH_N 24
#define SLH_H 66
#define SLH_D 22
#define SLH_A 8
#define SLH_K 33
#define SLH_SHA2 0
#include "rmbl_slhdsa_body.h"
#undef SLH_NS
#undef SLH_N
#undef SLH_H
#undef SLH_D
#undef SLH_A
#undef SLH_K
#undef SLH_SHA2

#define SLH_NS rmbl_slhdsa_shake_256s
#define SLH_N 32
#define SLH_H 64
#define SLH_D 8
#define SLH_A 14
#define SLH_K 22
#define SLH_SHA2 0
#include "rmbl_slhdsa_body.h"
#undef SLH_NS
#undef SLH_N
#undef SLH_H
#undef SLH_D
#undef SLH_A
#undef SLH_K
#undef SLH_SHA2

#define SLH_NS rmbl_slhdsa_shake_256f
#define SLH_N 32
#define SLH_H 68
#define SLH_D 17
#define SLH_A 9
#define SLH_K 35
#define SLH_SHA2 0
#include "rmbl_slhdsa_body.h"
#undef SLH_NS
#undef SLH_N
#undef SLH_H
#undef SLH_D
#undef SLH_A
#undef SLH_K
#undef SLH_SHA2

#define SLH_NS rmbl_slhdsa_sha2_128s
#define SLH_N 16
#define SLH_H 63
#define SLH_D 7
#define SLH_A 12
#define SLH_K 14
#define SLH_SHA2 1
#include "rmbl_slhdsa_body.h"
#undef SLH_NS
#undef SLH_N
#undef SLH_H
#undef SLH_D
#undef SLH_A
#undef SLH_K
#undef SLH_SHA2

#define SLH_NS rmbl_slhdsa_sha2_128f
#define SLH_N 16
#define SLH_H 66
#define SLH_D 22
#define SLH_A 6
#define SLH_K 33
#define SLH_SHA2 1
#include "rmbl_slhdsa_body.h"
#undef SLH_NS
#undef SLH_N
#undef SLH_H
#undef SLH_D
#undef SLH_A
#undef SLH_K
#undef SLH_SHA2

#define SLH_NS rmbl_slhdsa_sha2_192s
#define SLH_N 24
#define SLH_H 63
#define SLH_D 7
#define SLH_A 14
#define SLH_K 17
#define SLH_SHA2 1
#include "rmbl_slhdsa_body.h"
#undef SLH_NS
#undef SLH_N
#undef SLH_H
#undef SLH_D
#undef SLH_A
#undef SLH_K
#undef SLH_SHA2

#define SLH_NS rmbl_slhdsa_sha2_192f
#define SLH_N 24
#define SLH_H 66
#define SLH_D 22
#define SLH_A 8
#define SLH_K 33
#define SLH_SHA2 1
#include "rmbl_slhdsa_body.h"
#undef SLH_NS
#undef SLH_N
#undef SLH_H
#undef SLH_D
#undef SLH_A
#undef SLH_K
#undef SLH_SHA2

#define SLH_NS rmbl_slhdsa_sha2_256s
#define SLH_N 32
#define SLH_H 64
#define SLH_D 8
#define SLH_A 14
#define SLH_K 22
#define SLH_SHA2 1
#include "rmbl_slhdsa_body.h"
#undef SLH_NS
#undef SLH_N
#undef SLH_H
#undef SLH_D
#undef SLH_A
#undef SLH_K
#undef SLH_SHA2

#define SLH_NS rmbl_slhdsa_sha2_256f
#define SLH_N 32
#define SLH_H 68
#define SLH_D 17
#define SLH_A 9
#define SLH_K 35
#define SLH_SHA2 1
#include "rmbl_slhdsa_body.h"
#undef SLH_NS
#undef SLH_N
#undef SLH_H
#undef SLH_D
#undef SLH_A
#undef SLH_K
#undef SLH_SHA2

/* Compile-time confirmation that each parameter set produces the sizes
 * FIPS 205 tables. A wrong derived constant would otherwise surface
 * only as a signature another implementation cannot read. */
#define RMBL_STATIC_ASSERT(cond, tag) \
    typedef char rmbl_slh_static_assert_##tag[(cond) ? 1 : -1]
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_128s::kSigBytes == 7856, sigshake128s);
/* the stack buffer in thash must hold the widest input any caller
 * passes, at every parameter set */
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_256f::kThashMax >=
                   32 + 32 + 35 * 32, thashmax256f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_256s::kThashMax >=
                   128 + 22 + 22 * 32, thashmax256s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_128s::kPkBytes == 32, pkshake128s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_128s::kSkBytes == 64, skshake128s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_128f::kSigBytes == 17088, sigshake128f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_128f::kPkBytes == 32, pkshake128f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_128f::kSkBytes == 64, skshake128f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_192s::kSigBytes == 16224, sigshake192s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_192s::kPkBytes == 48, pkshake192s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_192s::kSkBytes == 96, skshake192s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_192f::kSigBytes == 35664, sigshake192f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_192f::kPkBytes == 48, pkshake192f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_192f::kSkBytes == 96, skshake192f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_256s::kSigBytes == 29792, sigshake256s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_256s::kPkBytes == 64, pkshake256s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_256s::kSkBytes == 128, skshake256s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_256f::kSigBytes == 49856, sigshake256f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_256f::kPkBytes == 64, pkshake256f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_shake_256f::kSkBytes == 128, skshake256f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_128s::kSigBytes == 7856, sigsha2128s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_128s::kPkBytes == 32, pksha2128s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_128s::kSkBytes == 64, sksha2128s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_128f::kSigBytes == 17088, sigsha2128f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_128f::kPkBytes == 32, pksha2128f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_128f::kSkBytes == 64, sksha2128f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_192s::kSigBytes == 16224, sigsha2192s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_192s::kPkBytes == 48, pksha2192s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_192s::kSkBytes == 96, sksha2192s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_192f::kSigBytes == 35664, sigsha2192f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_192f::kPkBytes == 48, pksha2192f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_192f::kSkBytes == 96, sksha2192f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_256s::kSigBytes == 29792, sigsha2256s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_256s::kPkBytes == 64, pksha2256s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_256s::kSkBytes == 128, sksha2256s);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_256f::kSigBytes == 49856, sigsha2256f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_256f::kPkBytes == 64, pksha2256f);
RMBL_STATIC_ASSERT(rmbl_slhdsa_sha2_256f::kSkBytes == 128, sksha2256f);

extern "C" {

/* Dispatch on the parameter set, named as FIPS 205 names it. */
#define RMBL_SLHDSA_DISPATCH(name, expr)                                 \
    do {                                                                 \
        if (std::strcmp(name, "SLH-DSA-SHAKE-128s") == 0) {   \
            namespace S = rmbl_slhdsa_shake_128s; expr;                       \
        }                                                 \
        if (std::strcmp(name, "SLH-DSA-SHAKE-128f") == 0) {   \
            namespace S = rmbl_slhdsa_shake_128f; expr;                       \
        }                                                 \
        if (std::strcmp(name, "SLH-DSA-SHAKE-192s") == 0) {   \
            namespace S = rmbl_slhdsa_shake_192s; expr;                       \
        }                                                 \
        if (std::strcmp(name, "SLH-DSA-SHAKE-192f") == 0) {   \
            namespace S = rmbl_slhdsa_shake_192f; expr;                       \
        }                                                 \
        if (std::strcmp(name, "SLH-DSA-SHAKE-256s") == 0) {   \
            namespace S = rmbl_slhdsa_shake_256s; expr;                       \
        }                                                 \
        if (std::strcmp(name, "SLH-DSA-SHAKE-256f") == 0) {   \
            namespace S = rmbl_slhdsa_shake_256f; expr;                       \
        }                                                 \
        if (std::strcmp(name, "SLH-DSA-SHA2-128s") == 0) {   \
            namespace S = rmbl_slhdsa_sha2_128s; expr;                       \
        }                                                 \
        if (std::strcmp(name, "SLH-DSA-SHA2-128f") == 0) {   \
            namespace S = rmbl_slhdsa_sha2_128f; expr;                       \
        }                                                 \
        if (std::strcmp(name, "SLH-DSA-SHA2-192s") == 0) {   \
            namespace S = rmbl_slhdsa_sha2_192s; expr;                       \
        }                                                 \
        if (std::strcmp(name, "SLH-DSA-SHA2-192f") == 0) {   \
            namespace S = rmbl_slhdsa_sha2_192f; expr;                       \
        }                                                 \
        if (std::strcmp(name, "SLH-DSA-SHA2-256s") == 0) {   \
            namespace S = rmbl_slhdsa_sha2_256s; expr;                       \
        }                                                 \
        if (std::strcmp(name, "SLH-DSA-SHA2-256f") == 0) {   \
            namespace S = rmbl_slhdsa_sha2_256f; expr;                       \
        }                                                 \
        Rf_error("unknown SLH-DSA parameter set: %s", name);          \
    } while (0)

static const char *slhdsa_set(SEXP set) {
    if (TYPEOF(set) != STRSXP || XLENGTH(set) != 1) {
        Rf_error("`set` must be a single parameter set name");
    }
    return CHAR(STRING_ELT(set, 0));
}

SEXP C_rmbl_slhdsa_sizes(SEXP set) {
    RMBL_SLHDSA_DISPATCH(slhdsa_set(set), {
        SEXP out = PROTECT(Rf_allocVector(INTSXP, 4));
        INTEGER(out)[0] = S::kPkBytes;
        INTEGER(out)[1] = S::kSkBytes;
        INTEGER(out)[2] = S::kSigBytes;
        INTEGER(out)[3] = 3 * S::kN;
        SEXP nm = PROTECT(Rf_allocVector(STRSXP, 4));
        SET_STRING_ELT(nm, 0, Rf_mkChar("public_key"));
        SET_STRING_ELT(nm, 1, Rf_mkChar("secret_key"));
        SET_STRING_ELT(nm, 2, Rf_mkChar("signature"));
        SET_STRING_ELT(nm, 3, Rf_mkChar("seed"));
        Rf_setAttrib(out, R_NamesSymbol, nm);
        UNPROTECT(2);
        return out;
    });
}

SEXP C_rmbl_slhdsa_keypair(SEXP set, SEXP seed) {
    RMBL_SLHDSA_DISPATCH(slhdsa_set(set), {
        if (TYPEOF(seed) != RAWSXP || XLENGTH(seed) != 3 * S::kN) {
            Rf_error("`seed` must be a raw vector of %d bytes", 3 * S::kN);
        }
        SEXP pk = PROTECT(Rf_allocVector(RAWSXP, S::kPkBytes));
        SEXP sk = PROTECT(Rf_allocVector(RAWSXP, S::kSkBytes));
        S::seed_keypair(RAW(pk), RAW(sk), RAW(seed));
        SEXP out = PROTECT(Rf_allocVector(VECSXP, 2));
        SET_VECTOR_ELT(out, 0, pk);
        SET_VECTOR_ELT(out, 1, sk);
        SEXP nm = PROTECT(Rf_allocVector(STRSXP, 2));
        SET_STRING_ELT(nm, 0, Rf_mkChar("public"));
        SET_STRING_ELT(nm, 1, Rf_mkChar("secret"));
        Rf_setAttrib(out, R_NamesSymbol, nm);
        UNPROTECT(4);
        return out;
    });
}

SEXP C_rmbl_slhdsa_sign(SEXP set, SEXP sk, SEXP msg, SEXP ctx,
                        SEXP opt_rand, SEXP prehash) {
    if (TYPEOF(msg) != RAWSXP) Rf_error("`msg` must be a raw vector");
    if (TYPEOF(ctx) != RAWSXP || XLENGTH(ctx) > 255) {
        Rf_error("`ctx` must be a raw vector of at most 255 bytes");
    }
    RMBL_SLHDSA_DISPATCH(slhdsa_set(set), {
        if (TYPEOF(sk) != RAWSXP || XLENGTH(sk) != S::kSkBytes) {
            Rf_error("`sk` must be a raw vector of %d bytes", S::kSkBytes);
        }
        if (TYPEOF(opt_rand) != RAWSXP || XLENGTH(opt_rand) != S::kN) {
            Rf_error("`opt_rand` must be a raw vector of %d bytes", S::kN);
        }
        SEXP sig = PROTECT(Rf_allocVector(RAWSXP, S::kSigBytes));
        rmbl_prehash::Result ph;
        rmbl_prehash::apply(rmbl_prehash::name_of(prehash), RAW(msg),
                            static_cast<size_t>(XLENGTH(msg)), &ph);
        if (ph.oid_len > 0) {
            S::sign(RAW(sig), ph.digest, ph.digest_len, RAW(ctx),
                    static_cast<size_t>(XLENGTH(ctx)), RAW(opt_rand),
                    RAW(sk), ph.oid, ph.oid_len);
        } else {
            S::sign(RAW(sig), RAW(msg), static_cast<size_t>(XLENGTH(msg)),
                    RAW(ctx), static_cast<size_t>(XLENGTH(ctx)),
                    RAW(opt_rand), RAW(sk), NULL, 0);
        }
        UNPROTECT(1);
        return sig;
    });
}

SEXP C_rmbl_slhdsa_verify(SEXP set, SEXP pk, SEXP msg, SEXP ctx, SEXP sig,
                          SEXP prehash) {
    if (TYPEOF(msg) != RAWSXP) Rf_error("`msg` must be a raw vector");
    if (TYPEOF(ctx) != RAWSXP || XLENGTH(ctx) > 255) {
        return Rf_ScalarLogical(FALSE);
    }
    RMBL_SLHDSA_DISPATCH(slhdsa_set(set), {
        /* a key or signature of the wrong length is "not verified",
         * never an error: a verifier treats unparseable input as
         * failure */
        if (TYPEOF(pk) != RAWSXP || XLENGTH(pk) != S::kPkBytes ||
            TYPEOF(sig) != RAWSXP) {
            return Rf_ScalarLogical(FALSE);
        }
        rmbl_prehash::Result ph;
        rmbl_prehash::apply(rmbl_prehash::name_of(prehash), RAW(msg),
                            static_cast<size_t>(XLENGTH(msg)), &ph);
        const int r = ph.oid_len > 0
            ? S::verify(RAW(sig), static_cast<size_t>(XLENGTH(sig)),
                        ph.digest, ph.digest_len, RAW(ctx),
                        static_cast<size_t>(XLENGTH(ctx)), RAW(pk),
                        ph.oid, ph.oid_len)
            : S::verify(RAW(sig), static_cast<size_t>(XLENGTH(sig)),
                        RAW(msg), static_cast<size_t>(XLENGTH(msg)),
                        RAW(ctx), static_cast<size_t>(XLENGTH(ctx)),
                        RAW(pk), NULL, 0);
        return Rf_ScalarLogical(r == 0);
    });
}

}  // extern "C"
