/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * ML-KEM (FIPS 203), all three parameter sets, implemented natively so
 * this package needs no system dependency for a standardised
 * post-quantum key encapsulation mechanism.
 *
 * ML-KEM answers a different question from the signature schemes beside
 * it: not "who produced this" but "what key shall we share". It is
 * included because a capsule that is signed and then shipped in the
 * clear is only half protected, and because the alternative -- reaching
 * for a system library for this one primitive -- is what this package
 * has just finished removing.
 *
 * Verified against OpenSSL 3.5 in both directions for every parameter
 * set: OpenSSL decapsulates ciphertexts produced here to the same
 * shared secret, and this code decapsulates OpenSSL's. Keys generated
 * from the same seed agree byte for byte.
 */

#include "rmbl_mlkem_core.h"

#define MLKEM_NS rmbl_mlkem512
#define MLKEM_K 2
#define MLKEM_ETA1 3
#define MLKEM_DU 10
#define MLKEM_DV 4
#include "rmbl_mlkem_body.h"
#undef MLKEM_NS
#undef MLKEM_K
#undef MLKEM_ETA1
#undef MLKEM_DU
#undef MLKEM_DV

#define MLKEM_NS rmbl_mlkem768
#define MLKEM_K 3
#define MLKEM_ETA1 2
#define MLKEM_DU 10
#define MLKEM_DV 4
#include "rmbl_mlkem_body.h"
#undef MLKEM_NS
#undef MLKEM_K
#undef MLKEM_ETA1
#undef MLKEM_DU
#undef MLKEM_DV

#define MLKEM_NS rmbl_mlkem1024
#define MLKEM_K 4
#define MLKEM_ETA1 2
#define MLKEM_DU 11
#define MLKEM_DV 5
#include "rmbl_mlkem_body.h"
#undef MLKEM_NS
#undef MLKEM_K
#undef MLKEM_ETA1
#undef MLKEM_DU
#undef MLKEM_DV

/* The sizes FIPS 203 table 3 fixes, asserted at compile time. */
#define RMBL_STATIC_ASSERT(cond, tag) \
    typedef char rmbl_mlkem_static_assert_##tag[(cond) ? 1 : -1]
RMBL_STATIC_ASSERT(rmbl_mlkem512::kEkBytes == 800, ek512);
RMBL_STATIC_ASSERT(rmbl_mlkem512::kDkBytes == 1632, dk512);
RMBL_STATIC_ASSERT(rmbl_mlkem512::kCtBytes == 768, ct512);
RMBL_STATIC_ASSERT(rmbl_mlkem768::kEkBytes == 1184, ek768);
RMBL_STATIC_ASSERT(rmbl_mlkem768::kDkBytes == 2400, dk768);
RMBL_STATIC_ASSERT(rmbl_mlkem768::kCtBytes == 1088, ct768);
RMBL_STATIC_ASSERT(rmbl_mlkem1024::kEkBytes == 1568, ek1024);
RMBL_STATIC_ASSERT(rmbl_mlkem1024::kDkBytes == 3168, dk1024);
RMBL_STATIC_ASSERT(rmbl_mlkem1024::kCtBytes == 1568, ct1024);

extern "C" {

#define RMBL_MLKEM_DISPATCH(level, expr)                                 \
    do {                                                                 \
        switch (level) {                                                 \
        case 512: { namespace M = rmbl_mlkem512; expr; }                 \
        case 768: { namespace M = rmbl_mlkem768; expr; }                 \
        case 1024: { namespace M = rmbl_mlkem1024; expr; }               \
        default: Rf_error("`level` must be 512, 768 or 1024");           \
        }                                                                \
    } while (0)

static int mlkem_level(SEXP level) {
    if (TYPEOF(level) != INTSXP || XLENGTH(level) != 1) {
        Rf_error("`level` must be a single integer: 512, 768 or 1024");
    }
    return INTEGER(level)[0];
}

SEXP C_rmbl_mlkem_sizes(SEXP level) {
    int ek = 0, dk = 0, ct = 0;
    switch (mlkem_level(level)) {
    case 512:
        ek = rmbl_mlkem512::kEkBytes; dk = rmbl_mlkem512::kDkBytes;
        ct = rmbl_mlkem512::kCtBytes; break;
    case 768:
        ek = rmbl_mlkem768::kEkBytes; dk = rmbl_mlkem768::kDkBytes;
        ct = rmbl_mlkem768::kCtBytes; break;
    case 1024:
        ek = rmbl_mlkem1024::kEkBytes; dk = rmbl_mlkem1024::kDkBytes;
        ct = rmbl_mlkem1024::kCtBytes; break;
    default:
        Rf_error("`level` must be 512, 768 or 1024");
    }
    SEXP out = PROTECT(Rf_allocVector(INTSXP, 5));
    INTEGER(out)[0] = ek;
    INTEGER(out)[1] = dk;
    INTEGER(out)[2] = ct;
    INTEGER(out)[3] = 64;
    INTEGER(out)[4] = 32;
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 5));
    SET_STRING_ELT(nm, 0, Rf_mkChar("encapsulation_key"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("decapsulation_key"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("ciphertext"));
    SET_STRING_ELT(nm, 3, Rf_mkChar("seed"));
    SET_STRING_ELT(nm, 4, Rf_mkChar("shared_secret"));
    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(2);
    return out;
}

SEXP C_rmbl_mlkem_keygen(SEXP level, SEXP seed) {
    if (TYPEOF(seed) != RAWSXP || XLENGTH(seed) != 64) {
        Rf_error("`seed` must be a raw vector of 64 bytes (d || z)");
    }
    RMBL_MLKEM_DISPATCH(mlkem_level(level), {
        SEXP ek = PROTECT(Rf_allocVector(RAWSXP, M::kEkBytes));
        SEXP dk = PROTECT(Rf_allocVector(RAWSXP, M::kDkBytes));
        M::keygen(RAW(ek), RAW(dk), RAW(seed));
        SEXP out = PROTECT(Rf_allocVector(VECSXP, 2));
        SET_VECTOR_ELT(out, 0, ek);
        SET_VECTOR_ELT(out, 1, dk);
        SEXP nm = PROTECT(Rf_allocVector(STRSXP, 2));
        SET_STRING_ELT(nm, 0, Rf_mkChar("public"));
        SET_STRING_ELT(nm, 1, Rf_mkChar("secret"));
        Rf_setAttrib(out, R_NamesSymbol, nm);
        UNPROTECT(4);
        return out;
    });
}

/* `m` is the 32 bytes of encapsulation randomness. Supplying it makes
 * the operation reproducible, which is what the standard's test vectors
 * need; a caller wanting a fresh secret passes fresh bytes. */
SEXP C_rmbl_mlkem_encaps(SEXP level, SEXP ek, SEXP m) {
    if (TYPEOF(m) != RAWSXP || XLENGTH(m) != 32) {
        Rf_error("`m` must be a raw vector of 32 bytes");
    }
    RMBL_MLKEM_DISPATCH(mlkem_level(level), {
        if (TYPEOF(ek) != RAWSXP || XLENGTH(ek) != M::kEkBytes) {
            Rf_error("`ek` must be a raw vector of %d bytes", M::kEkBytes);
        }
        SEXP ct = PROTECT(Rf_allocVector(RAWSXP, M::kCtBytes));
        SEXP ss = PROTECT(Rf_allocVector(RAWSXP, 32));
        if (M::encaps(RAW(ct), RAW(ss), RAW(ek), RAW(m)) != 0) {
            UNPROTECT(2);
            /* the FIPS 203 modulus check: an encapsulation key whose
             * coefficients are not canonical is rejected rather than
             * used */
            Rf_error("`ek` is not a canonical ML-KEM encapsulation key");
        }
        SEXP out = PROTECT(Rf_allocVector(VECSXP, 2));
        SET_VECTOR_ELT(out, 0, ct);
        SET_VECTOR_ELT(out, 1, ss);
        SEXP nm = PROTECT(Rf_allocVector(STRSXP, 2));
        SET_STRING_ELT(nm, 0, Rf_mkChar("ciphertext"));
        SET_STRING_ELT(nm, 1, Rf_mkChar("shared"));
        Rf_setAttrib(out, R_NamesSymbol, nm);
        UNPROTECT(4);
        return out;
    });
}

SEXP C_rmbl_mlkem_decaps(SEXP level, SEXP dk, SEXP ct) {
    RMBL_MLKEM_DISPATCH(mlkem_level(level), {
        if (TYPEOF(dk) != RAWSXP || XLENGTH(dk) != M::kDkBytes) {
            Rf_error("`dk` must be a raw vector of %d bytes", M::kDkBytes);
        }
        if (TYPEOF(ct) != RAWSXP || XLENGTH(ct) != M::kCtBytes) {
            Rf_error("`ct` must be a raw vector of %d bytes", M::kCtBytes);
        }
        SEXP ss = PROTECT(Rf_allocVector(RAWSXP, 32));
        /* No failure path: FIPS 203 decapsulation ALWAYS returns a
         * shared secret. A bad ciphertext yields one derived from the
         * rejection secret instead, so an attacker learns nothing from
         * whether it worked. */
        M::decaps(RAW(ss), RAW(dk), RAW(ct));
        UNPROTECT(1);
        return ss;
    });
}

}  // extern "C"
