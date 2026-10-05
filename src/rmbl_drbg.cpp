/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * R entry points for AES-256 and the CTR_DRBG (rmbl_drbg_core.h). The state (Key, V) lives on the
 * R side; each call takes it, advances it and hands it back with the output. Lengths are checked
 * in R and again here.
 */
#include <cstring>
#include <R.h>
#include <Rinternals.h>

#include "rmbl_drbg_core.h"

namespace {

using rmbl_drbg::CtrDrbg;
using rmbl_drbg::SEEDLEN;

void need_raw(SEXP x, R_xlen_t lo, R_xlen_t hi, const char *what) {
    if (TYPEOF(x) != RAWSXP || XLENGTH(x) < lo || XLENGTH(x) > hi) {
        if (lo == hi) Rf_error("`%s` must be a raw vector of %d bytes", what, static_cast<int>(lo));
        Rf_error("`%s` must be a raw vector of %d to %d bytes", what, static_cast<int>(lo), static_cast<int>(hi));
    }
}

/* list(key, v[, out]) with every vector allocated before the state is copied out of C */
SEXP state_list(const CtrDrbg &d, SEXP out) {
    const int n = out == R_NilValue ? 2 : 3;
    SEXP res = PROTECT(Rf_allocVector(VECSXP, n));
    SEXP k = PROTECT(Rf_allocVector(RAWSXP, 32));
    SEXP v = PROTECT(Rf_allocVector(RAWSXP, 16));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, n));
    std::memcpy(RAW(k), d.key, 32);
    std::memcpy(RAW(v), d.v, 16);
    SET_VECTOR_ELT(res, 0, k);
    SET_VECTOR_ELT(res, 1, v);
    SET_STRING_ELT(nm, 0, Rf_mkChar("key"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("v"));
    if (n == 3) {
        SET_VECTOR_ELT(res, 2, out);
        SET_STRING_ELT(nm, 2, Rf_mkChar("out"));
    }
    Rf_setAttrib(res, R_NamesSymbol, nm);
    UNPROTECT(4);
    return res;
}

void load(CtrDrbg &d, SEXP key, SEXP v) {
    need_raw(key, 32, 32, "key");
    need_raw(v, 16, 16, "v");
    std::memcpy(d.key, RAW(key), 32);
    std::memcpy(d.v, RAW(v), 16);
}

} // namespace

extern "C" {

SEXP C_rmbl_aes256_encrypt(SEXP key, SEXP blocks) {
    need_raw(key, 32, 32, "key");
    if (TYPEOF(blocks) != RAWSXP || XLENGTH(blocks) % 16 != 0) {
        Rf_error("`blocks` must be a raw vector whose length is a multiple of 16");
    }
    SEXP out = PROTECT(Rf_allocVector(RAWSXP, XLENGTH(blocks)));
    rmbl_drbg::Aes256 aes;
    aes.init(RAW(key));
    for (R_xlen_t i = 0; i < XLENGTH(blocks); i += 16) aes.encrypt(RAW(out) + i, RAW(blocks) + i);
    UNPROTECT(1);
    return out;
}

SEXP C_rmbl_drbg_instantiate(SEXP entropy, SEXP pers) {
    need_raw(entropy, SEEDLEN, SEEDLEN, "entropy");
    need_raw(pers, 0, SEEDLEN, "personalization");
    CtrDrbg d;
    d.instantiate(RAW(entropy), RAW(pers), static_cast<size_t>(XLENGTH(pers)));
    return state_list(d, R_NilValue);
}

SEXP C_rmbl_drbg_reseed(SEXP key, SEXP v, SEXP entropy, SEXP add) {
    need_raw(entropy, SEEDLEN, SEEDLEN, "entropy");
    need_raw(add, 0, SEEDLEN, "additional");
    CtrDrbg d;
    load(d, key, v);
    d.reseed(RAW(entropy), RAW(add), static_cast<size_t>(XLENGTH(add)));
    return state_list(d, R_NilValue);
}

SEXP C_rmbl_drbg_generate(SEXP key, SEXP v, SEXP n, SEXP add) {
    need_raw(add, 0, SEEDLEN, "additional");
    const int len = Rf_asInteger(n);
    if (len == NA_INTEGER || len < 1 || len > 65536) Rf_error("`n` must be between 1 and 65536 bytes");
    CtrDrbg d;
    load(d, key, v);
    SEXP out = PROTECT(Rf_allocVector(RAWSXP, len));
    d.generate(RAW(out), static_cast<size_t>(len), RAW(add), static_cast<size_t>(XLENGTH(add)));
    SEXP res = state_list(d, out);
    UNPROTECT(1);
    return res;
}

/* "aesni" or "portable"; `portable = TRUE` forces the portable cipher (tests compare) */
SEXP C_rmbl_aes_backend(SEXP portable) {
    if (TYPEOF(portable) == LGLSXP && XLENGTH(portable) == 1 && LOGICAL(portable)[0] != NA_LOGICAL) {
        rmbl_drbg::force_portable() = LOGICAL(portable)[0] ? 1 : 0;
    }
    return Rf_mkString(!rmbl_drbg::force_portable() && rmbl_drbg::have_aesni() ? "aesni" : "portable");
}

} // extern "C"
