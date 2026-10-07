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
#include "rmbl_prehash.h"
#include "rmbl_mask_rng.h"

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

/* `masked`: TRUE signs with the first-order masked signer (sign_mu_masked), FALSE with the
 * plain one; the two return the same bytes for the same rnd. */
static bool mldsa_masked(SEXP masked) {
    if (TYPEOF(masked) != LGLSXP || XLENGTH(masked) != 1 || LOGICAL(masked)[0] == NA_LOGICAL) {
        Rf_error("`masked` must be TRUE or FALSE");
    }
    return LOGICAL(masked)[0] != 0;
}

static int mldsa_mode(SEXP mode) {
    if (TYPEOF(mode) != INTSXP || XLENGTH(mode) != 1) {
        Rf_error("`mode` must be a single integer: 44, 65 or 87");
    }
    return INTEGER(mode)[0];
}

/* ML-DSA (FIPS 204) public interface. Sizes are fixed by the parameter
 * set and reported so a caller never has to guess. */
SEXP C_rmbl_mldsa_sizes_impl(SEXP mode) {
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

SEXP C_rmbl_mldsa_keypair_impl(SEXP mode, SEXP seed) {
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

SEXP C_rmbl_mldsa_sign_impl(SEXP mode, SEXP sk, SEXP msg, SEXP ctx, SEXP rnd,
                       SEXP prehash, SEXP masked) {
    if (TYPEOF(msg) != RAWSXP) Rf_error("`msg` must be a raw vector");
    if (TYPEOF(ctx) != RAWSXP || XLENGTH(ctx) > 255) {
        Rf_error("`ctx` must be a raw vector of at most 255 bytes");
    }
    if (TYPEOF(rnd) != RAWSXP || XLENGTH(rnd) != 32) {
        Rf_error("`rnd` must be a raw vector of 32 bytes");
    }
    const bool use_mask = mldsa_masked(masked);
    RMBL_MLDSA_DISPATCH(mldsa_mode(mode), {
        if (TYPEOF(sk) != RAWSXP || XLENGTH(sk) != M::kSkBytes) {
            Rf_error("`sk` must be a raw vector of %d bytes", M::kSkBytes);
        }
        rmbl_prehash::Result ph;
        rmbl_prehash::apply(rmbl_prehash::name_of(prehash), RAW(msg),
                            static_cast<size_t>(XLENGTH(msg)), &ph);
        SEXP sig = PROTECT(Rf_allocVector(RAWSXP, M::kSigBytes));
        int rc;
        bool failed = false;
        if (use_mask) {
            MaskRng *mr = new MaskRng();
            rmbl_masked::Rng rng;  /* assigned, not braced: a comma would split the macro argument */
            rng.fn = mask_rng_u32;
            rng.ctx = mr;
            if (ph.oid_len > 0) {
                rc = M::sign_prehash_masked(RAW(sig), ph.digest, ph.digest_len, RAW(ctx),
                                            static_cast<size_t>(XLENGTH(ctx)), ph.oid,
                                            ph.oid_len, RAW(rnd), RAW(sk), rng);
            } else {
                rc = M::sign_internal_masked(RAW(sig), RAW(msg),
                                             static_cast<size_t>(XLENGTH(msg)), RAW(ctx),
                                             static_cast<size_t>(XLENGTH(ctx)), RAW(rnd),
                                             RAW(sk), rng);
            }
            failed = mr->failed;
            rmbl_ct::wipe(mr->buf, sizeof mr->buf);
            delete mr;
        } else if (ph.oid_len > 0) {
            rc = M::sign_prehash(RAW(sig), ph.digest, ph.digest_len, RAW(ctx),
                                 static_cast<size_t>(XLENGTH(ctx)), ph.oid,
                                 ph.oid_len, RAW(rnd), RAW(sk));
        } else {
            rc = M::sign_internal(RAW(sig), RAW(msg),
                                  static_cast<size_t>(XLENGTH(msg)), RAW(ctx),
                                  static_cast<size_t>(XLENGTH(ctx)), RAW(rnd),
                                  RAW(sk));
        }
        UNPROTECT(1);
        if (failed) Rf_error("the operating system's random source failed during masked signing");
        if (rc != 0) Rf_error("%s", rmbl_mldsa_core::kSignFailed);
        return sig;
    });
}

SEXP C_rmbl_mldsa_verify_impl(SEXP mode, SEXP pk, SEXP msg, SEXP ctx, SEXP sig,
                         SEXP prehash) {
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
        rmbl_prehash::Result ph;
        rmbl_prehash::apply(rmbl_prehash::name_of(prehash), RAW(msg),
                            static_cast<size_t>(XLENGTH(msg)), &ph);
        const int r = ph.oid_len > 0
            ? M::verify_prehash(RAW(sig), ph.digest, ph.digest_len,
                                RAW(ctx),
                                static_cast<size_t>(XLENGTH(ctx)),
                                ph.oid, ph.oid_len, RAW(pk))
            : M::verify_internal(RAW(sig), RAW(msg),
                                 static_cast<size_t>(XLENGTH(msg)),
                                 RAW(ctx),
                                 static_cast<size_t>(XLENGTH(ctx)),
                                 RAW(pk));
        return Rf_ScalarLogical(r == 0);
    });
}


/* ExternalMu-ML-DSA. mu is the only thing the signer needs, so a device
 * holding the key never has to see the message -- which is the point:
 * the message can be streamed past a boundary the key does not cross.
 * mu still binds the public key (through tr) and the context, so it is
 * not a bare digest and cannot be moved between keys. */
SEXP C_rmbl_mldsa_mu_impl(SEXP mode, SEXP pk, SEXP msg, SEXP ctx, SEXP prehash) {
    if (TYPEOF(msg) != RAWSXP) Rf_error("`msg` must be a raw vector");
    if (TYPEOF(ctx) != RAWSXP || XLENGTH(ctx) > 255) {
        Rf_error("`ctx` must be a raw vector of at most 255 bytes");
    }
    RMBL_MLDSA_DISPATCH(mldsa_mode(mode), {
        if (TYPEOF(pk) != RAWSXP || XLENGTH(pk) != M::kPkBytes) {
            Rf_error("`pk` must be a raw vector of %d bytes", M::kPkBytes);
        }
        rmbl_prehash::Result ph;
        rmbl_prehash::apply(rmbl_prehash::name_of(prehash), RAW(msg),
                            static_cast<size_t>(XLENGTH(msg)), &ph);
        unsigned char tr[64];
        M::tr_from_pk(tr, RAW(pk));
        SEXP out = PROTECT(Rf_allocVector(RAWSXP, 64));
        if (ph.oid_len > 0) {
            M::compute_mu(RAW(out), tr, ph.digest, ph.digest_len, RAW(ctx),
                          static_cast<size_t>(XLENGTH(ctx)), ph.oid,
                          ph.oid_len);
        } else {
            M::compute_mu(RAW(out), tr, RAW(msg),
                          static_cast<size_t>(XLENGTH(msg)), RAW(ctx),
                          static_cast<size_t>(XLENGTH(ctx)), NULL, 0);
        }
        UNPROTECT(1);
        return out;
    });
}

/* The pre-hash digest alone, by the name capsule_sign() takes: what the
 * NIST ACVP SHA-2 / SHA-3 vectors check, through the same table signing
 * uses. Internal. */
SEXP C_rmbl_prehash_digest_impl(SEXP name, SEXP msg) {
    if (TYPEOF(msg) != RAWSXP) Rf_error("`msg` must be a raw vector");
    const char *nm = rmbl_prehash::name_of(name);
    unsigned char out[rmbl_prehash::kMaxDigest];
    size_t len = 0;
    unsigned char arc = 0;
    if (!rmbl_prehash::digest(nm, RAW(msg), static_cast<size_t>(XLENGTH(msg)),
                              out, &len, &arc)) {
        Rf_error("`prehash` must be one of " RMBL_PREHASH_NAMES);
    }
    SEXP r = PROTECT(Rf_allocVector(RAWSXP, static_cast<R_xlen_t>(len)));
    std::memcpy(RAW(r), out, len);
    UNPROTECT(1);
    return r;
}

SEXP C_rmbl_mldsa_sign_mu_impl(SEXP mode, SEXP sk, SEXP mu, SEXP rnd, SEXP masked) {
    if (TYPEOF(mu) != RAWSXP || XLENGTH(mu) != 64) {
        Rf_error("`mu` must be a raw vector of 64 bytes");
    }
    if (TYPEOF(rnd) != RAWSXP || XLENGTH(rnd) != 32) {
        Rf_error("`rnd` must be a raw vector of 32 bytes");
    }
    const bool use_mask = mldsa_masked(masked);
    RMBL_MLDSA_DISPATCH(mldsa_mode(mode), {
        if (TYPEOF(sk) != RAWSXP || XLENGTH(sk) != M::kSkBytes) {
            Rf_error("`sk` must be a raw vector of %d bytes", M::kSkBytes);
        }
        SEXP sig = PROTECT(Rf_allocVector(RAWSXP, M::kSigBytes));
        int rc;
        bool failed = false;
        if (use_mask) {
            MaskRng *mr = new MaskRng();
            rmbl_masked::Rng rng;
            rng.fn = mask_rng_u32;
            rng.ctx = mr;
            rc = M::sign_mu_masked(RAW(sig), RAW(mu), RAW(rnd), RAW(sk), rng);
            failed = mr->failed;
            rmbl_ct::wipe(mr->buf, sizeof mr->buf);
            delete mr;
        } else {
            rc = M::sign_mu(RAW(sig), RAW(mu), RAW(rnd), RAW(sk));
        }
        UNPROTECT(1);
        if (failed) Rf_error("the operating system's random source failed during masked signing");
        if (rc != 0) Rf_error("%s", rmbl_mldsa_core::kSignFailed);
        return sig;
    });
}

SEXP C_rmbl_mldsa_verify_mu_impl(SEXP mode, SEXP pk, SEXP mu, SEXP sig) {
    if (TYPEOF(mu) != RAWSXP || XLENGTH(mu) != 64) {
        return Rf_ScalarLogical(FALSE);
    }
    RMBL_MLDSA_DISPATCH(mldsa_mode(mode), {
        if (TYPEOF(pk) != RAWSXP || XLENGTH(pk) != M::kPkBytes ||
            TYPEOF(sig) != RAWSXP || XLENGTH(sig) != M::kSigBytes) {
            return Rf_ScalarLogical(FALSE);
        }
        const int r = M::verify_mu(RAW(sig), RAW(mu), RAW(pk));
        return Rf_ScalarLogical(r == 0);
    });
}

}  // extern "C"

/* The seven arithmetic probes (.Call entry points for zetas, NTT, reduce,
 * sample, round, pack, unpack) that once verified this layer against the
 * reference implementation are gone: nothing in R/ or tests/ called them,
 * they were unguarded, and the schemes built on them are verified end to
 * end against OpenSSL 3.5 instead. */
