/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * ML-DSA (FIPS 204), all three parameter sets, implemented natively so
 * this package needs no system dependency for a standardised
 * post-quantum signature.
 *
 * The mode-independent arithmetic -- Montgomery reduction, the NTT and
 * its inverse over Z_q[X]/(X^256+1) -- lives in rmbl_mldsa_core.h and
 * is shared. Everything whose array sizes or packed field widths depend
 * on the parameter set lives in rmbl_mldsa_body.h, which is included
 * once per set below.
 *
 * Verified against OpenSSL 3.5 in both directions for every parameter
 * set: OpenSSL verifies signatures produced here and this code verifies
 * OpenSSL's, over several message and context lengths. That
 * cross-check, not reference parity, is what establishes conformance --
 * pq-crystals' crypto_sign_signature_internal omits FIPS 204's
 * (0x00, |ctx|, ctx) domain separator, so matching it byte for byte
 * proves nothing about interoperability.
 */

#include "rmbl_mldsa_core.h"

#define MLDSA_NS rmbl_mldsa44
#define MLDSA_K 4
#define MLDSA_L 4
#define MLDSA_ETA 2
#define MLDSA_TAU 39
#define MLDSA_BETA 78
#define MLDSA_GAMMA1 (1 << 17)
#define MLDSA_GAMMA2_DEN 88
#define MLDSA_OMEGA 80
#define MLDSA_CTILDE 32
#include "rmbl_mldsa_body.h"
#undef MLDSA_NS
#undef MLDSA_K
#undef MLDSA_L
#undef MLDSA_ETA
#undef MLDSA_TAU
#undef MLDSA_BETA
#undef MLDSA_GAMMA1
#undef MLDSA_GAMMA2_DEN
#undef MLDSA_OMEGA
#undef MLDSA_CTILDE

#define MLDSA_NS rmbl_mldsa65
#define MLDSA_K 6
#define MLDSA_L 5
#define MLDSA_ETA 4
#define MLDSA_TAU 49
#define MLDSA_BETA 196
#define MLDSA_GAMMA1 (1 << 19)
#define MLDSA_GAMMA2_DEN 32
#define MLDSA_OMEGA 55
#define MLDSA_CTILDE 48
#include "rmbl_mldsa_body.h"
#undef MLDSA_NS
#undef MLDSA_K
#undef MLDSA_L
#undef MLDSA_ETA
#undef MLDSA_TAU
#undef MLDSA_BETA
#undef MLDSA_GAMMA1
#undef MLDSA_GAMMA2_DEN
#undef MLDSA_OMEGA
#undef MLDSA_CTILDE

#define MLDSA_NS rmbl_mldsa87
#define MLDSA_K 8
#define MLDSA_L 7
#define MLDSA_ETA 2
#define MLDSA_TAU 60
#define MLDSA_BETA 120
#define MLDSA_GAMMA1 (1 << 19)
#define MLDSA_GAMMA2_DEN 32
#define MLDSA_OMEGA 75
#define MLDSA_CTILDE 64
#include "rmbl_mldsa_body.h"
#undef MLDSA_NS
#undef MLDSA_K
#undef MLDSA_L
#undef MLDSA_ETA
#undef MLDSA_TAU
#undef MLDSA_BETA
#undef MLDSA_GAMMA1
#undef MLDSA_GAMMA2_DEN
#undef MLDSA_OMEGA
#undef MLDSA_CTILDE

/* The probe entry points below predate the other two parameter sets and
 * exercise mode 3, which this alias keeps them doing. */
namespace rmbl_mldsa = rmbl_mldsa65;

/* Compile-time confirmation that each parameter set produces the sizes
 * FIPS 204 tables. A wrong packed width would otherwise surface only as
 * a signature another implementation cannot read. */
#define RMBL_STATIC_ASSERT(cond, tag) \
    typedef char rmbl_static_assert_##tag[(cond) ? 1 : -1]
RMBL_STATIC_ASSERT(rmbl_mldsa44::kPkBytes == 1312, pk44);
RMBL_STATIC_ASSERT(rmbl_mldsa44::kSkBytes == 2560, sk44);
RMBL_STATIC_ASSERT(rmbl_mldsa44::kSigBytes == 2420, sig44);
RMBL_STATIC_ASSERT(rmbl_mldsa65::kPkBytes == 1952, pk65);
RMBL_STATIC_ASSERT(rmbl_mldsa65::kSkBytes == 4032, sk65);
RMBL_STATIC_ASSERT(rmbl_mldsa65::kSigBytes == 3309, sig65);
RMBL_STATIC_ASSERT(rmbl_mldsa87::kPkBytes == 2592, pk87);
RMBL_STATIC_ASSERT(rmbl_mldsa87::kSkBytes == 4896, sk87);
RMBL_STATIC_ASSERT(rmbl_mldsa87::kSigBytes == 4627, sig87);

extern "C" {

/* Dispatch on the parameter set. The three instantiations share no
 * mutable state, so this is a plain switch and not a vtable. */
#define RMBL_MLDSA_DISPATCH(mode, expr)                                  \
    do {                                                                 \
        switch (mode) {                                                  \
        case 44: { namespace M = rmbl_mldsa44; expr; }                   \
        case 65: { namespace M = rmbl_mldsa65; expr; }                   \
        case 87: { namespace M = rmbl_mldsa87; expr; }                   \
        default: Rf_error("`mode` must be 44, 65 or 87");                \
        }                                                                \
    } while (0)

static int mldsa_mode(SEXP mode) {
    if (TYPEOF(mode) != INTSXP || XLENGTH(mode) != 1) {
        Rf_error("`mode` must be a single integer: 44, 65 or 87");
    }
    return INTEGER(mode)[0];
}

/* ML-DSA (FIPS 204) public interface. Sizes are fixed by the parameter
 * set and reported so a caller never has to guess. */
SEXP C_rmbl_mldsa_sizes(SEXP mode) {
    int pkb = 0, skb = 0, sgb = 0;
    switch (mldsa_mode(mode)) {
    case 44:
        pkb = rmbl_mldsa44::kPkBytes; skb = rmbl_mldsa44::kSkBytes;
        sgb = rmbl_mldsa44::kSigBytes; break;
    case 65:
        pkb = rmbl_mldsa65::kPkBytes; skb = rmbl_mldsa65::kSkBytes;
        sgb = rmbl_mldsa65::kSigBytes; break;
    case 87:
        pkb = rmbl_mldsa87::kPkBytes; skb = rmbl_mldsa87::kSkBytes;
        sgb = rmbl_mldsa87::kSigBytes; break;
    default:
        Rf_error("`mode` must be 44, 65 or 87");
    }
    SEXP out = PROTECT(Rf_allocVector(INTSXP, 4));
    INTEGER(out)[0] = pkb;
    INTEGER(out)[1] = skb;
    INTEGER(out)[2] = sgb;
    INTEGER(out)[3] = 32;
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 4));
    SET_STRING_ELT(nm, 0, Rf_mkChar("public_key"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("secret_key"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("signature"));
    SET_STRING_ELT(nm, 3, Rf_mkChar("seed"));
    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(2);
    return out;
}

SEXP C_rmbl_mldsa_keypair(SEXP mode, SEXP seed) {
    if (TYPEOF(seed) != RAWSXP || XLENGTH(seed) != 32) {
        Rf_error("`seed` must be a raw vector of 32 bytes");
    }
    RMBL_MLDSA_DISPATCH(mldsa_mode(mode), {
        SEXP pk = PROTECT(Rf_allocVector(RAWSXP, M::kPkBytes));
        SEXP sk = PROTECT(Rf_allocVector(RAWSXP, M::kSkBytes));
        M::keypair_from_seed(RAW(pk), RAW(sk), RAW(seed));
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

SEXP C_rmbl_mldsa_sign(SEXP mode, SEXP sk, SEXP msg, SEXP ctx, SEXP rnd) {
    if (TYPEOF(msg) != RAWSXP) Rf_error("`msg` must be a raw vector");
    if (TYPEOF(ctx) != RAWSXP || XLENGTH(ctx) > 255) {
        Rf_error("`ctx` must be a raw vector of at most 255 bytes");
    }
    if (TYPEOF(rnd) != RAWSXP || XLENGTH(rnd) != 32) {
        Rf_error("`rnd` must be a raw vector of 32 bytes");
    }
    RMBL_MLDSA_DISPATCH(mldsa_mode(mode), {
        if (TYPEOF(sk) != RAWSXP || XLENGTH(sk) != M::kSkBytes) {
            Rf_error("`sk` must be a raw vector of %d bytes", M::kSkBytes);
        }
        SEXP sig = PROTECT(Rf_allocVector(RAWSXP, M::kSigBytes));
        M::sign_internal(RAW(sig), RAW(msg),
                         static_cast<size_t>(XLENGTH(msg)), RAW(ctx),
                         static_cast<size_t>(XLENGTH(ctx)), RAW(rnd),
                         RAW(sk));
        UNPROTECT(1);
        return sig;
    });
}

SEXP C_rmbl_mldsa_verify(SEXP mode, SEXP pk, SEXP msg, SEXP ctx, SEXP sig) {
    if (TYPEOF(msg) != RAWSXP) Rf_error("`msg` must be a raw vector");
    if (TYPEOF(ctx) != RAWSXP || XLENGTH(ctx) > 255) {
        return Rf_ScalarLogical(FALSE);
    }
    RMBL_MLDSA_DISPATCH(mldsa_mode(mode), {
        /* a key or signature of the wrong length is "not verified",
         * never an error: a verifier treats unparseable input as
         * failure */
        if (TYPEOF(pk) != RAWSXP || XLENGTH(pk) != M::kPkBytes ||
            TYPEOF(sig) != RAWSXP || XLENGTH(sig) != M::kSigBytes) {
            return Rf_ScalarLogical(FALSE);
        }
        const int r = M::verify_internal(RAW(sig), RAW(msg),
                                         static_cast<size_t>(XLENGTH(msg)),
                                         RAW(ctx),
                                         static_cast<size_t>(XLENGTH(ctx)),
                                         RAW(pk));
        return Rf_ScalarLogical(r == 0);
    });
}


}  // extern "C"

extern "C" {

/* Test entry points. The arithmetic layer is verified against the
 * reference implementation before anything is built on top of it. */
SEXP C_rmbl_mldsa_zetas(void) {
    SEXP out = PROTECT(Rf_allocVector(INTSXP, 256));
    for (int i = 0; i < 256; ++i) INTEGER(out)[i] = rmbl_mldsa_core::zetas().z[i];
    UNPROTECT(1);
    return out;
}

SEXP C_rmbl_mldsa_ntt(SEXP x, SEXP inverse) {
    if (XLENGTH(x) != 256) Rf_error("need 256 coefficients");
    int32_t a[256];
    SEXP xi = PROTECT(Rf_coerceVector(x, INTSXP));
    for (int i = 0; i < 256; ++i) a[i] = INTEGER(xi)[i];
    UNPROTECT(1);
    if (Rf_asLogical(inverse)) {
        rmbl_mldsa::invntt_tomont(a);
    } else {
        rmbl_mldsa::ntt(a);
    }
    SEXP out = PROTECT(Rf_allocVector(INTSXP, 256));
    for (int i = 0; i < 256; ++i) INTEGER(out)[i] = a[i];
    UNPROTECT(1);
    return out;
}

/* Sampling test hooks: each sampler is checked against the reference
 * before the signature scheme is built on it. */
SEXP C_rmbl_mldsa_sample(SEXP which, SEXP seed, SEXP nonce) {
    using namespace rmbl_mldsa;
    const int w = Rf_asInteger(which);
    const uint16_t nc = static_cast<uint16_t>(Rf_asInteger(nonce));
    if (TYPEOF(seed) != RAWSXP) Rf_error("`seed` must be a raw vector");
    const unsigned char *sd = RAW(seed);
    const R_xlen_t sn = XLENGTH(seed);
    int32_t a[256];
    if (w == 0) {
        if (sn != 32) Rf_error("uniform needs a 32-byte seed");
        poly_uniform(a, sd, nc);
    } else if (w == 1) {
        if (sn != 64) Rf_error("eta needs a 64-byte seed");
        poly_uniform_eta(a, sd, nc);
    } else if (w == 2) {
        if (sn != 64) Rf_error("gamma1 needs a 64-byte seed");
        poly_uniform_gamma1(a, sd, nc);
    } else if (w == 3) {
        if (sn != kCtildeBytes) Rf_error("challenge needs a 48-byte seed");
        poly_challenge(a, sd);
    } else {
        Rf_error("unknown sampler");
    }
    SEXP out = PROTECT(Rf_allocVector(INTSXP, 256));
    for (int i = 0; i < 256; ++i) INTEGER(out)[i] = a[i];
    UNPROTECT(1);
    return out;
}

/* Rounding and packing hooks, checked against the reference before the
 * signature scheme is built on them. */
SEXP C_rmbl_mldsa_round(SEXP x, SEXP which, SEXP hints) {
    using namespace rmbl_mldsa;
    const int w = Rf_asInteger(which);
    const R_xlen_t n = XLENGTH(x);
    SEXP xi = PROTECT(Rf_coerceVector(x, INTSXP));
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    SEXP hi = R_NilValue;
    if (w == 3) hi = PROTECT(Rf_coerceVector(hints, INTSXP));
    for (R_xlen_t i = 0; i < n; ++i) {
        const int32_t v = INTEGER(xi)[i];
        int32_t a0;
        if (w == 0) {
            INTEGER(out)[i] = decompose(&a0, v);
        } else if (w == 1) {
            decompose(&a0, v);
            INTEGER(out)[i] = a0;
        } else if (w == 2) {
            const int32_t a1 = decompose(&a0, v);
            INTEGER(out)[i] = static_cast<int>(make_hint(a0, a1));
        } else if (w == 3) {
            INTEGER(out)[i] = use_hint(v, static_cast<unsigned>(INTEGER(hi)[i]));
        } else {
            Rf_error("unknown rounding selector");
        }
    }
    UNPROTECT(w == 3 ? 3 : 2);
    return out;
}

SEXP C_rmbl_mldsa_pack(SEXP x, SEXP which) {
    using namespace rmbl_mldsa;
    const int w = Rf_asInteger(which);
    if (XLENGTH(x) != 256) Rf_error("need 256 coefficients");
    int32_t a[256];
    SEXP xi = PROTECT(Rf_coerceVector(x, INTSXP));
    for (int i = 0; i < 256; ++i) a[i] = INTEGER(xi)[i];
    UNPROTECT(1);
    int len = 0;
    unsigned char buf[1024];
    if (w == 0) { polyt1_pack(buf, a); len = kPolyT1Packed; }
    else if (w == 1) { polyt0_pack(buf, a); len = kPolyT0Packed; }
    else if (w == 2) { polyeta_pack(buf, a); len = kPolyEtaPacked; }
    else if (w == 3) { polyz_pack(buf, a); len = kPolyZPacked; }
    else if (w == 4) { polyw1_pack(buf, a); len = kPolyW1Packed; }
    else Rf_error("unknown packer");
    SEXP out = PROTECT(Rf_allocVector(RAWSXP, len));
    std::memcpy(RAW(out), buf, static_cast<size_t>(len));
    UNPROTECT(1);
    return out;
}

SEXP C_rmbl_mldsa_unpack(SEXP bytes, SEXP which) {
    using namespace rmbl_mldsa;
    const int w = Rf_asInteger(which);
    if (TYPEOF(bytes) != RAWSXP) Rf_error("`bytes` must be raw");
    int32_t a[256];
    const unsigned char *b = RAW(bytes);
    if (w == 0) polyt1_unpack(a, b);
    else if (w == 1) polyt0_unpack(a, b);
    else if (w == 2) polyeta_unpack(a, b);
    else if (w == 3) polyz_unpack(a, b);
    else Rf_error("unknown unpacker");
    SEXP out = PROTECT(Rf_allocVector(INTSXP, 256));
    for (int i = 0; i < 256; ++i) INTEGER(out)[i] = a[i];
    UNPROTECT(1);
    return out;
}

SEXP C_rmbl_mldsa_reduce(SEXP x, SEXP which) {
    const int w = Rf_asInteger(which);
    const R_xlen_t n = XLENGTH(x);
    SEXP xi = PROTECT(Rf_coerceVector(x, INTSXP));
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    for (R_xlen_t i = 0; i < n; ++i) {
        const int32_t v = INTEGER(xi)[i];
        if (w == 0) {
            INTEGER(out)[i] = rmbl_mldsa::reduce32(v);
        } else if (w == 1) {
            INTEGER(out)[i] = rmbl_mldsa::caddq(v);
        } else if (w == 2) {
            int32_t a0, a1;
            rmbl_mldsa::power2round(v, &a0, &a1);
            INTEGER(out)[i] = a1;
        } else if (w == 3) {
            int32_t a0, a1;
            rmbl_mldsa::power2round(v, &a0, &a1);
            INTEGER(out)[i] = a0;
        } else {
            INTEGER(out)[i] = rmbl_mldsa::montgomery_reduce(
                static_cast<int64_t>(v));
        }
    }
    UNPROTECT(2);
    return out;
}

}  // extern "C"
