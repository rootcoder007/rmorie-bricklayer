/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * rmbl_core.cpp -- the shared C-ABI backend for the rmorie ecosystem.
 *
 * Single source of truth: the numeric kernels below DELEGATE to
 * morie::core::* from the vendored morie_core.h, whose canonical copy is
 * libmorie/morie_core.hpp in the `morie` repository. morie is the origin
 * of the arithmetic; bricklayer does not reimplement it -- it merely
 * re-exposes morie's header-only C++ kernels behind a stable C ABI so
 * sibling R packages can reach one compiled copy via
 * `LinkingTo: rmoriebricklayer` + R_RegisterCCallable (see init.c). The
 * Python side of morie binds the same header through nanobind, so R,
 * Python, and every R sibling compute bit-identical results by
 * construction.
 *
 * SHA-256 (provenance hashing) is bricklayer's own addition -- it is not
 * part of morie's numeric core -- and lives here unchanged.
 *
 * To resync the kernels after an upstream change:
 *   cp morie/libmorie/morie_core.hpp rmorie-bricklayer/bricklayer/src/morie_core.h
 */

/* R_NO_REMAP: do not expose the unprefixed R API aliases (length, error,
 * allocVector, ...). R's `length` macro otherwise collides with the
 * std::locale member that <complex> (pulled in by morie_core.h) drags in.
 * We use the Rf_-prefixed names throughout, so this is a no-op otherwise. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <cstring>
#include <cstdint>
#include <cstddef>

#include "morie_core.h"   /* vendored canonical morie kernels (morie::core) */

/* ------------------------------------------------------------------ */
/* SHA-256 -- self-contained, public-domain style (FIPS 180-4).        */
/* bricklayer-specific (not part of morie's numeric core); verified    */
/* against the standard "abc" vector in tests/testthat/test-core.R.    */
/* ------------------------------------------------------------------ */

namespace {

struct sha256_ctx {
    uint8_t  data[64];
    uint32_t datalen;
    uint64_t bitlen;
    uint32_t state[8];
};

#define ROTR(a,b) (((a) >> (b)) | ((a) << (32 - (b))))
#define CHs(x,y,z)  (((x) & (y)) ^ (~(x) & (z)))
#define MAJs(x,y,z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x)  (ROTR(x,2)  ^ ROTR(x,13) ^ ROTR(x,22))
#define EP1(x)  (ROTR(x,6)  ^ ROTR(x,11) ^ ROTR(x,25))
#define SIG0(x) (ROTR(x,7)  ^ ROTR(x,18) ^ ((x) >> 3))
#define SIG1(x) (ROTR(x,17) ^ ROTR(x,19) ^ ((x) >> 10))

const uint32_t kSha[64] = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

void sha256_transform(sha256_ctx *ctx, const uint8_t data[64]) {
    uint32_t a,b,c,d,e,f,g,h,t1,t2,m[64];
    int i, j;
    for (i = 0, j = 0; i < 16; i++, j += 4)
        m[i] = ((uint32_t)data[j] << 24) | ((uint32_t)data[j+1] << 16) |
               ((uint32_t)data[j+2] << 8) | ((uint32_t)data[j+3]);
    for (; i < 64; i++)
        m[i] = SIG1(m[i-2]) + m[i-7] + SIG0(m[i-15]) + m[i-16];

    a = ctx->state[0]; b = ctx->state[1]; c = ctx->state[2]; d = ctx->state[3];
    e = ctx->state[4]; f = ctx->state[5]; g = ctx->state[6]; h = ctx->state[7];

    for (i = 0; i < 64; i++) {
        t1 = h + EP1(e) + CHs(e,f,g) + kSha[i] + m[i];
        t2 = EP0(a) + MAJs(a,b,c);
        h = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
    }

    ctx->state[0] += a; ctx->state[1] += b; ctx->state[2] += c; ctx->state[3] += d;
    ctx->state[4] += e; ctx->state[5] += f; ctx->state[6] += g; ctx->state[7] += h;
}

void sha256_init(sha256_ctx *ctx) {
    ctx->datalen = 0; ctx->bitlen = 0;
    ctx->state[0] = 0x6a09e667; ctx->state[1] = 0xbb67ae85;
    ctx->state[2] = 0x3c6ef372; ctx->state[3] = 0xa54ff53a;
    ctx->state[4] = 0x510e527f; ctx->state[5] = 0x9b05688c;
    ctx->state[6] = 0x1f83d9ab; ctx->state[7] = 0x5be0cd19;
}

void sha256_update(sha256_ctx *ctx, const uint8_t *data, size_t len) {
    for (size_t i = 0; i < len; i++) {
        ctx->data[ctx->datalen] = data[i];
        ctx->datalen++;
        if (ctx->datalen == 64) {
            sha256_transform(ctx, ctx->data);
            ctx->bitlen += 512;
            ctx->datalen = 0;
        }
    }
}

void sha256_final(sha256_ctx *ctx, uint8_t hash[32]) {
    uint32_t i = ctx->datalen;
    ctx->data[i++] = 0x80;
    if (ctx->datalen < 56) {
        while (i < 56) ctx->data[i++] = 0x00;
    } else {
        while (i < 64) ctx->data[i++] = 0x00;
        sha256_transform(ctx, ctx->data);
        std::memset(ctx->data, 0, 56);
    }
    ctx->bitlen += (uint64_t) ctx->datalen * 8;
    ctx->data[63] = (uint8_t)(ctx->bitlen);
    ctx->data[62] = (uint8_t)(ctx->bitlen >> 8);
    ctx->data[61] = (uint8_t)(ctx->bitlen >> 16);
    ctx->data[60] = (uint8_t)(ctx->bitlen >> 24);
    ctx->data[59] = (uint8_t)(ctx->bitlen >> 32);
    ctx->data[58] = (uint8_t)(ctx->bitlen >> 40);
    ctx->data[57] = (uint8_t)(ctx->bitlen >> 48);
    ctx->data[56] = (uint8_t)(ctx->bitlen >> 56);
    sha256_transform(ctx, ctx->data);

    for (i = 0; i < 8; i++) {
        hash[i*4]   = (uint8_t)(ctx->state[i] >> 24);
        hash[i*4+1] = (uint8_t)(ctx->state[i] >> 16);
        hash[i*4+2] = (uint8_t)(ctx->state[i] >> 8);
        hash[i*4+3] = (uint8_t)(ctx->state[i]);
    }
}

}  // namespace

/* ------------------------------------------------------------------ */
/* Public C ABI -- the registered, linkable kernels.                   */
/* Stats delegate to morie::core (single source of truth); SHA-256 is  */
/* bricklayer's own. extern "C" so init.c (C) links them unmangled.    */
/* ------------------------------------------------------------------ */

extern "C" {

double rmbl_mean(const double *x, R_xlen_t n) {
    return morie::core::mean(x, static_cast<std::size_t>(n));
}

double rmbl_var(const double *x, R_xlen_t n) {
    return morie::core::variance(x, static_cast<std::size_t>(n), 1);  // n-1, like R var()
}

double rmbl_cor_pearson(const double *x, const double *y, R_xlen_t n) {
    return morie::core::cor_pearson(x, y, static_cast<std::size_t>(n));
}

double rmbl_normal_pdf(double x, double mu, double sigma) {
    if (sigma <= 0.0) return R_NaN;
    double out;
    morie::core::normal_pdf(&x, 1, mu, sigma, &out);
    return out;
}

/* Raw 32-byte digest. rmbl_digest.cpp (HMAC, Merkle) calls this so the
 * package has exactly one SHA-256 compression function. */
void rmbl_sha256_raw(const unsigned char *data, size_t len,
                     unsigned char out[32]) {
    sha256_ctx ctx;
    sha256_init(&ctx);
    sha256_update(&ctx, data, len);
    sha256_final(&ctx, (uint8_t *) out);
}

void rmbl_sha256_hex(const unsigned char *data, size_t len, char out[65]) {
    sha256_ctx ctx;
    uint8_t hash[32];
    static const char hx[] = "0123456789abcdef";
    sha256_init(&ctx);
    sha256_update(&ctx, data, len);
    sha256_final(&ctx, hash);
    for (int i = 0; i < 32; i++) {
        out[i*2]   = hx[(hash[i] >> 4) & 0xf];
        out[i*2+1] = hx[hash[i] & 0xf];
    }
    out[64] = '\0';
}

/* The vendored morie kernels below were already compiled into this
 * package but had no binding, so no caller could reach them. They
 * delegate unchanged -- the arithmetic still has a single home in
 * morie_core.h. */

double rmbl_sd(const double *x, R_xlen_t n, int ddof) {
    return morie::core::stddev(x, static_cast<std::size_t>(n), ddof);
}

double rmbl_euclid_dist(const double *a, const double *b, R_xlen_t n) {
    return morie::core::euclid_dist(a, b, static_cast<std::size_t>(n));
}

double rmbl_normal_logpdf(double x, double mu, double sigma) {
    if (sigma <= 0.0) return R_NaN;
    double out;
    morie::core::normal_logpdf(&x, 1, mu, sigma, &out);
    return out;
}

void rmbl_ipw_weights(const double *treat, const double *propensity,
                      R_xlen_t n, double trim_lo, double trim_hi,
                      double *out) {
    morie::core::trimmed_ipw_weights(treat, propensity,
                                     static_cast<std::size_t>(n),
                                     trim_lo, trim_hi, out);
}

void rmbl_bootstrap_mean(const double *x, R_xlen_t n, R_xlen_t B,
                         unsigned long long seed, double *out) {
    morie::core::bootstrap_mean(x, static_cast<std::size_t>(n),
                                static_cast<std::size_t>(B), seed, out);
}

double rmbl_gamma_cdf(double shape, double x) {
    return morie::core::gamma_cdf_regularized(shape, x);
}

/* Hawkes negative log-likelihood, constant baseline. kernel: 0 =
 * exponential (O(n) recursion), 1 = Weibull, 2 = Lomax, 3 = gamma.
 * `par` is (a0, eta, p1[, p2]); the exponential takes one kernel
 * parameter and the rest take two. An infeasible parameter set returns
 * morie's sentinel (1e12) rather than erroring. */
double rmbl_hawkes_nll(const double *t, R_xlen_t n, double T, int kernel,
                       const double *par, R_xlen_t npar) {
    const std::size_t nn = static_cast<std::size_t>(n);
    if (kernel == 0) {
        if (npar < 3) return R_NaN;
        return morie::core::hawkes_ll_exp_const(t, nn, T, par[0], par[1],
                                                par[2]);
    }
    if (npar < 4) return R_NaN;
    if (kernel == 1) {
        return morie::core::hawkes_ll_weibull_const(t, nn, T, par[0], par[1],
                                                    par[2], par[3]);
    }
    if (kernel == 2) {
        return morie::core::hawkes_ll_lomax_const(t, nn, T, par[0], par[1],
                                                  par[2], par[3]);
    }
    if (kernel == 3) {
        return morie::core::hawkes_ll_gamma_const(t, nn, T, par[0], par[1],
                                                  par[2], par[3]);
    }
    return R_NaN;
}

/* ---- .Call wrappers: bricklayer's own R-facing API ---- */

SEXP C_rmbl_sd(SEXP x, SEXP ddof) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    double r = rmbl_sd(REAL(x), XLENGTH(x), Rf_asInteger(ddof));
    UNPROTECT(1);
    return Rf_ScalarReal(r);
}

SEXP C_rmbl_euclid(SEXP a, SEXP b) {
    a = PROTECT(Rf_coerceVector(a, REALSXP));
    b = PROTECT(Rf_coerceVector(b, REALSXP));
    if (XLENGTH(a) != XLENGTH(b)) {
        UNPROTECT(2);
        Rf_error("a and b must have the same length");
    }
    double r = rmbl_euclid_dist(REAL(a), REAL(b), XLENGTH(a));
    UNPROTECT(2);
    return Rf_ScalarReal(r);
}

SEXP C_rmbl_normal_logpdf(SEXP x, SEXP mu, SEXP sigma) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    double m = Rf_asReal(mu), s = Rf_asReal(sigma);
    R_xlen_t n = XLENGTH(x);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    double *px = REAL(x), *po = REAL(out);
    for (R_xlen_t i = 0; i < n; i++) po[i] = rmbl_normal_logpdf(px[i], m, s);
    UNPROTECT(2);
    return out;
}

SEXP C_rmbl_ipw(SEXP treat, SEXP propensity, SEXP trim_lo, SEXP trim_hi) {
    treat = PROTECT(Rf_coerceVector(treat, REALSXP));
    propensity = PROTECT(Rf_coerceVector(propensity, REALSXP));
    R_xlen_t n = XLENGTH(treat);
    if (XLENGTH(propensity) != n) {
        UNPROTECT(2);
        Rf_error("`treat` and `propensity` must have the same length");
    }
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    rmbl_ipw_weights(REAL(treat), REAL(propensity), n, Rf_asReal(trim_lo),
                     Rf_asReal(trim_hi), REAL(out));
    UNPROTECT(3);
    return out;
}

SEXP C_rmbl_bootstrap_mean(SEXP x, SEXP B, SEXP seed) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    R_xlen_t nb = (R_xlen_t) Rf_asReal(B);
    if (nb < 1) {
        UNPROTECT(1);
        Rf_error("`B` must be at least 1");
    }
    SEXP out = PROTECT(Rf_allocVector(REALSXP, nb));
    rmbl_bootstrap_mean(REAL(x), XLENGTH(x), nb,
                        (unsigned long long) Rf_asReal(seed), REAL(out));
    UNPROTECT(2);
    return out;
}

SEXP C_rmbl_gamma_cdf(SEXP shape, SEXP x) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    double a = Rf_asReal(shape);
    R_xlen_t n = XLENGTH(x);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    for (R_xlen_t i = 0; i < n; i++) REAL(out)[i] = rmbl_gamma_cdf(a, REAL(x)[i]);
    UNPROTECT(2);
    return out;
}

SEXP C_rmbl_hawkes_nll(SEXP t, SEXP T, SEXP kernel, SEXP par) {
    t = PROTECT(Rf_coerceVector(t, REALSXP));
    par = PROTECT(Rf_coerceVector(par, REALSXP));
    double r = rmbl_hawkes_nll(REAL(t), XLENGTH(t), Rf_asReal(T),
                               Rf_asInteger(kernel), REAL(par), XLENGTH(par));
    UNPROTECT(2);
    return Rf_ScalarReal(r);
}


SEXP C_rmbl_mean(SEXP x) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    double r = rmbl_mean(REAL(x), XLENGTH(x));
    UNPROTECT(1);
    return Rf_ScalarReal(r);
}

SEXP C_rmbl_var(SEXP x) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    double r = rmbl_var(REAL(x), XLENGTH(x));
    UNPROTECT(1);
    return Rf_ScalarReal(r);
}

SEXP C_rmbl_cor(SEXP x, SEXP y) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    y = PROTECT(Rf_coerceVector(y, REALSXP));
    if (XLENGTH(x) != XLENGTH(y)) {
        UNPROTECT(2);
        Rf_error("x and y must have the same length");
    }
    double r = rmbl_cor_pearson(REAL(x), REAL(y), XLENGTH(x));
    UNPROTECT(2);
    return Rf_ScalarReal(r);
}

SEXP C_rmbl_normal_pdf(SEXP x, SEXP mu, SEXP sigma) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    double m = Rf_asReal(mu), s = Rf_asReal(sigma);
    R_xlen_t n = XLENGTH(x);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    double *px = REAL(x), *po = REAL(out);
    for (R_xlen_t i = 0; i < n; i++) po[i] = rmbl_normal_pdf(px[i], m, s);
    UNPROTECT(2);
    return out;
}

SEXP C_rmbl_sha256(SEXP x) {
    const unsigned char *data;
    size_t len;
    char out[65];
    if (TYPEOF(x) == RAWSXP) {
        data = (const unsigned char *) RAW(x);
        len  = (size_t) XLENGTH(x);
    } else if (TYPEOF(x) == STRSXP && XLENGTH(x) >= 1) {
        SEXP s = STRING_ELT(x, 0);
        if (s == NA_STRING) return Rf_ScalarString(NA_STRING);
        data = (const unsigned char *) CHAR(s);
        len  = std::strlen((const char *) data);
    } else {
        Rf_error("rmbl_sha256 expects a length-1 character vector or a raw vector");
    }
    rmbl_sha256_hex(data, len, out);
    return Rf_mkString(out);
}

}  // extern "C"
