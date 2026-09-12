/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * rmoriebricklayer.h -- public C API of the rmorie ecosystem core.
 *
 * Sibling packages connect to the shared backend by adding
 *
 *     LinkingTo: rmoriebricklayer
 *
 * to their DESCRIPTION and then, in their own C/C++ sources:
 *
 *     #include <rmoriebricklayer.h>
 *     double m = rmbl_mean(REAL(x), XLENGTH(x));
 *
 * Each symbol resolves once (lazily) through R_GetCCallable against the
 * loaded rmoriebricklayer DLL -- no duplicated kernels, one source of
 * truth. This header is for CONSUMERS; rmoriebricklayer itself defines
 * the real functions in src/rmbl_core.c and must NOT include this file.
 */

#ifndef RMORIEBRICKLAYER_H
#define RMORIEBRICKLAYER_H

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

static R_INLINE double rmbl_mean(const double *x, R_xlen_t n) {
    static double (*fn)(const double *, R_xlen_t) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, R_xlen_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_mean");
    return fn(x, n);
}

static R_INLINE double rmbl_var(const double *x, R_xlen_t n) {
    static double (*fn)(const double *, R_xlen_t) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, R_xlen_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_var");
    return fn(x, n);
}

static R_INLINE double rmbl_cor_pearson(const double *x, const double *y, R_xlen_t n) {
    static double (*fn)(const double *, const double *, R_xlen_t) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, const double *, R_xlen_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_cor_pearson");
    return fn(x, y, n);
}

static R_INLINE double rmbl_normal_pdf(double x, double mu, double sigma) {
    static double (*fn)(double, double, double) = NULL;
    if (fn == NULL)
        fn = (double (*)(double, double, double))
             R_GetCCallable("rmoriebricklayer", "rmbl_normal_pdf");
    return fn(x, mu, sigma);
}

static R_INLINE void rmbl_sha256_hex(const unsigned char *data, size_t len, char *out /* >= 65 */) {
    static void (*fn)(const unsigned char *, size_t, char *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const unsigned char *, size_t, char *))
             R_GetCCallable("rmoriebricklayer", "rmbl_sha256_hex");
    fn(data, len, out);
}

/* Download `url` to `path`; on failure fall back to `wayback` (pass "" to
 * auto-resolve a snapshot). Returns 0 live-ok, 1 wayback-ok, -1 both-failed.
 * The shared libcurl fetch foundation -- one implementation, every package. */
static R_INLINE int rmbl_fetch_with_fallback(const char *url, const char *wayback,
                                             const char *path, int timeout_s) {
    static int (*fn)(const char *, const char *, const char *, int) = NULL;
    if (fn == NULL)
        fn = (int (*)(const char *, const char *, const char *, int))
             R_GetCCallable("rmoriebricklayer", "rmbl_fetch_with_fallback");
    return fn(url, wayback, path, timeout_s);
}

/* Resolve a Wayback snapshot URL for `url` into `out` (cap bytes). Returns
 * bytes written (0 if none archived). */
static R_INLINE int rmbl_wayback_snapshot(const char *url, char *out, int cap, int timeout_s) {
    static int (*fn)(const char *, char *, int, int) = NULL;
    if (fn == NULL)
        fn = (int (*)(const char *, char *, int, int))
             R_GetCCallable("rmoriebricklayer", "rmbl_wayback_snapshot");
    return fn(url, out, cap, timeout_s);
}


/* ------------------------------------------------------------------ */
/* 0.4.0 additions.                                                    */
/*                                                                     */
/* Two groups: morie kernels that were compiled in all along but had   */
/* no shim here, so no sibling could reach them; and bricklayer's own  */
/* statistics and provenance digests. rmorie and rmoriedata should     */
/* call these rather than carrying their own copy -- that is the whole */
/* point of the shared core.                                           */
/* ------------------------------------------------------------------ */

static R_INLINE double rmbl_sd(const double *x, R_xlen_t n, int ddof) {
    static double (*fn)(const double *, R_xlen_t, int) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, R_xlen_t, int))
             R_GetCCallable("rmoriebricklayer", "rmbl_sd");
    return fn(x, n, ddof);
}

static R_INLINE double rmbl_euclid_dist(const double *a, const double *b,
                                        R_xlen_t n) {
    static double (*fn)(const double *, const double *, R_xlen_t) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, const double *, R_xlen_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_euclid_dist");
    return fn(a, b, n);
}

static R_INLINE double rmbl_normal_logpdf(double x, double mu, double sigma) {
    static double (*fn)(double, double, double) = NULL;
    if (fn == NULL)
        fn = (double (*)(double, double, double))
             R_GetCCallable("rmoriebricklayer", "rmbl_normal_logpdf");
    return fn(x, mu, sigma);
}

static R_INLINE void rmbl_ipw_weights(const double *treat,
                                      const double *propensity, R_xlen_t n,
                                      double trim_lo, double trim_hi,
                                      double *out) {
    static void (*fn)(const double *, const double *, R_xlen_t, double,
                      double, double *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const double *, const double *, R_xlen_t, double,
                       double, double *))
             R_GetCCallable("rmoriebricklayer", "rmbl_ipw_weights");
    fn(treat, propensity, n, trim_lo, trim_hi, out);
}

static R_INLINE void rmbl_bootstrap_mean(const double *x, R_xlen_t n,
                                         R_xlen_t B, unsigned long long seed,
                                         double *out) {
    static void (*fn)(const double *, R_xlen_t, R_xlen_t, unsigned long long,
                      double *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const double *, R_xlen_t, R_xlen_t, unsigned long long,
                       double *))
             R_GetCCallable("rmoriebricklayer", "rmbl_bootstrap_mean");
    fn(x, n, B, seed, out);
}

static R_INLINE double rmbl_gamma_cdf(double shape, double x) {
    static double (*fn)(double, double) = NULL;
    if (fn == NULL)
        fn = (double (*)(double, double))
             R_GetCCallable("rmoriebricklayer", "rmbl_gamma_cdf");
    return fn(shape, x);
}

static R_INLINE double rmbl_hawkes_nll(const double *t, R_xlen_t n, double T,
                                       int kernel, const double *par,
                                       R_xlen_t npar) {
    static double (*fn)(const double *, R_xlen_t, double, int,
                        const double *, R_xlen_t) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, R_xlen_t, double, int,
                         const double *, R_xlen_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_hawkes_nll");
    return fn(t, n, T, kernel, par, npar);
}

/* out[0..3] = mean, variance (n-1), skewness, excess kurtosis. */
static R_INLINE void rmbl_moments(const double *x, R_xlen_t n, double *out) {
    static void (*fn)(const double *, R_xlen_t, double *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const double *, R_xlen_t, double *))
             R_GetCCallable("rmoriebricklayer", "rmbl_moments");
    fn(x, n, out);
}

static R_INLINE void rmbl_quantile(const double *x, R_xlen_t n,
                                   const double *probs, R_xlen_t np,
                                   double *out) {
    static void (*fn)(const double *, R_xlen_t, const double *, R_xlen_t,
                      double *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const double *, R_xlen_t, const double *, R_xlen_t,
                       double *))
             R_GetCCallable("rmoriebricklayer", "rmbl_quantile");
    fn(x, n, probs, np, out);
}

static R_INLINE double rmbl_median(const double *x, R_xlen_t n) {
    static double (*fn)(const double *, R_xlen_t) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, R_xlen_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_median");
    return fn(x, n);
}

/* --- concentration and short-series trend (rmbl_series.cpp) --------- */

/* Gini. NA_REAL when the total is zero or any value is negative. */
static R_INLINE double rmbl_gini(const double *x, R_xlen_t n) {
    static double (*fn)(const double *, R_xlen_t) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, R_xlen_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_gini");
    return fn(x, n);
}

/* Share of the total held by the largest ceil(frac * n) units. `units`
 * receives that count and may be NULL. */
static R_INLINE double rmbl_top_share(const double *x, R_xlen_t n,
                                      double frac, R_xlen_t *units) {
    static double (*fn)(const double *, R_xlen_t, double, R_xlen_t *) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, R_xlen_t, double, R_xlen_t *))
             R_GetCCallable("rmoriebricklayer", "rmbl_top_share");
    return fn(x, n, frac, units);
}

/* Lorenz curve into buffers of length n + 1 (the origin is included).
 * Returns the number of points written, 0 on refusal. */
static R_INLINE R_xlen_t rmbl_lorenz(const double *x, R_xlen_t n,
                                     double *population, double *value) {
    static R_xlen_t (*fn)(const double *, R_xlen_t, double *, double *) = NULL;
    if (fn == NULL)
        fn = (R_xlen_t (*)(const double *, R_xlen_t, double *, double *))
             R_GetCCallable("rmoriebricklayer", "rmbl_lorenz");
    return fn(x, n, population, value);
}

/* Mann-Kendall S and its tie-corrected variance. `used` receives the
 * number of finite observations and may be NULL. */
static R_INLINE void rmbl_mann_kendall(const double *y, R_xlen_t n,
                                       double *S, double *var,
                                       R_xlen_t *used) {
    static void (*fn)(const double *, R_xlen_t, double *, double *,
                      R_xlen_t *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const double *, R_xlen_t, double *, double *,
                       R_xlen_t *))
             R_GetCCallable("rmoriebricklayer", "rmbl_mann_kendall");
    fn(y, n, S, var, used);
}

/* Theil-Sen median-of-slopes line. */
static R_INLINE void rmbl_theil_sen(const double *x, const double *y,
                                    R_xlen_t n, double *slope,
                                    double *intercept) {
    static void (*fn)(const double *, const double *, R_xlen_t, double *,
                      double *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const double *, const double *, R_xlen_t, double *,
                       double *))
             R_GetCCallable("rmoriebricklayer", "rmbl_theil_sen");
    fn(x, y, n, slope, intercept);
}

/* Hurwitz zeta, sum over k >= 0 of (q + k)^-s. NA_REAL unless s > 1 and
 * q > 0. The normalising constant of the discrete power law. */
static R_INLINE double rmbl_hurwitz_zeta(double s, double q) {
    static double (*fn)(double, double) = NULL;
    if (fn == NULL)
        fn = (double (*)(double, double))
             R_GetCCallable("rmoriebricklayer", "rmbl_hurwitz_zeta");
    return fn(s, q);
}

static R_INLINE double rmbl_mad(const double *x, R_xlen_t n, double constant) {
    static double (*fn)(const double *, R_xlen_t, double) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, R_xlen_t, double))
             R_GetCCallable("rmoriebricklayer", "rmbl_mad");
    return fn(x, n, constant);
}

static R_INLINE double rmbl_trimmed_mean(const double *x, R_xlen_t n,
                                         double trim) {
    static double (*fn)(const double *, R_xlen_t, double) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, R_xlen_t, double))
             R_GetCCallable("rmoriebricklayer", "rmbl_trimmed_mean");
    return fn(x, n, trim);
}

static R_INLINE double rmbl_winsorized_mean(const double *x, R_xlen_t n,
                                            double trim) {
    static double (*fn)(const double *, R_xlen_t, double) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, R_xlen_t, double))
             R_GetCCallable("rmoriebricklayer", "rmbl_winsorized_mean");
    return fn(x, n, trim);
}

static R_INLINE double rmbl_weighted_mean(const double *x, const double *w,
                                          R_xlen_t n) {
    static double (*fn)(const double *, const double *, R_xlen_t) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, const double *, R_xlen_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_weighted_mean");
    return fn(x, w, n);
}

static R_INLINE double rmbl_weighted_var(const double *x, const double *w,
                                         R_xlen_t n) {
    static double (*fn)(const double *, const double *, R_xlen_t) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, const double *, R_xlen_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_weighted_var");
    return fn(x, w, n);
}

static R_INLINE double rmbl_cor_spearman(const double *x, const double *y,
                                         R_xlen_t n) {
    static double (*fn)(const double *, const double *, R_xlen_t) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, const double *, R_xlen_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_cor_spearman");
    return fn(x, y, n);
}

static R_INLINE void rmbl_midranks(const double *x, R_xlen_t n, double *out) {
    static void (*fn)(const double *, R_xlen_t, double *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const double *, R_xlen_t, double *))
             R_GetCCallable("rmoriebricklayer", "rmbl_midranks");
    fn(x, n, out);
}

/* Column-major in and out; `out` must hold p * p doubles. */
static R_INLINE void rmbl_cov_matrix(const double *x, R_xlen_t n, R_xlen_t p,
                                     double *out) {
    static void (*fn)(const double *, R_xlen_t, R_xlen_t, double *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const double *, R_xlen_t, R_xlen_t, double *))
             R_GetCCallable("rmoriebricklayer", "rmbl_cov_matrix");
    fn(x, n, p, out);
}

static R_INLINE double rmbl_ks_two_sample(const double *x, R_xlen_t nx,
                                          const double *y, R_xlen_t ny) {
    static double (*fn)(const double *, R_xlen_t, const double *,
                        R_xlen_t) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, R_xlen_t, const double *, R_xlen_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_ks_two_sample");
    return fn(x, nx, y, ny);
}

static R_INLINE double rmbl_ks_pvalue(double d, double n_eff) {
    static double (*fn)(double, double) = NULL;
    if (fn == NULL)
        fn = (double (*)(double, double))
             R_GetCCallable("rmoriebricklayer", "rmbl_ks_pvalue");
    return fn(d, n_eff);
}

static R_INLINE double rmbl_psi(const double *p, const double *q, R_xlen_t k,
                                double eps) {
    static double (*fn)(const double *, const double *, R_xlen_t,
                        double) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, const double *, R_xlen_t, double))
             R_GetCCallable("rmoriebricklayer", "rmbl_psi");
    return fn(p, q, k, eps);
}

static R_INLINE double rmbl_js_divergence(const double *p, const double *q,
                                          R_xlen_t k) {
    static double (*fn)(const double *, const double *, R_xlen_t) = NULL;
    if (fn == NULL)
        fn = (double (*)(const double *, const double *, R_xlen_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_js_divergence");
    return fn(p, q, k);
}

/* `out` must hold 32 bytes. */
static R_INLINE void rmbl_sha256_raw(const unsigned char *data, size_t len,
                                     unsigned char *out) {
    static void (*fn)(const unsigned char *, size_t, unsigned char *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const unsigned char *, size_t, unsigned char *))
             R_GetCCallable("rmoriebricklayer", "rmbl_sha256_raw");
    fn(data, len, out);
}

/* `out` must hold 129 bytes (128 hex characters plus the terminator). */
static R_INLINE void rmbl_sha512_hex(const unsigned char *data, size_t len,
                                     char *out) {
    static void (*fn)(const unsigned char *, size_t, char *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const unsigned char *, size_t, char *))
             R_GetCCallable("rmoriebricklayer", "rmbl_sha512_hex");
    fn(data, len, out);
}

/* `out` must hold 65 bytes. */
static R_INLINE void rmbl_hmac_sha256_hex(const unsigned char *key,
                                          size_t keylen,
                                          const unsigned char *msg,
                                          size_t msglen, char *out) {
    static void (*fn)(const unsigned char *, size_t, const unsigned char *,
                      size_t, char *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const unsigned char *, size_t, const unsigned char *,
                       size_t, char *))
             R_GetCCallable("rmoriebricklayer", "rmbl_hmac_sha256_hex");
    fn(key, keylen, msg, msglen, out);
}

/* Constant-time digest comparison: use this, not strcmp, on any tag an
   untrusted party supplied. */
static R_INLINE int rmbl_digest_equal(const char *a, const char *b,
                                      size_t n) {
    static int (*fn)(const char *, const char *, size_t) = NULL;
    if (fn == NULL)
        fn = (int (*)(const char *, const char *, size_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_digest_equal");
    return fn(a, b, n);
}


/* One-pass moment accumulation and exact merging: (n, mean, M2, M3, M4)
   with M_k the k-th central SUM. Accumulate per block, merge the blocks,
   and the result matches a single batch pass. */
static R_INLINE void rmbl_moments_acc(const double *x, R_xlen_t n,
                                      double *out) {
    static void (*fn)(const double *, R_xlen_t, double *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const double *, R_xlen_t, double *))
             R_GetCCallable("rmoriebricklayer", "rmbl_moments_acc");
    fn(x, n, out);
}

static R_INLINE void rmbl_moments_merge(const double *a, const double *b,
                                        double *out) {
    static void (*fn)(const double *, const double *, double *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const double *, const double *, double *))
             R_GetCCallable("rmoriebricklayer", "rmbl_moments_merge");
    fn(a, b, out);
}


/* BLAKE2b: keyed or unkeyed, any digest length 1..64. Returns 0 on
   success. */
static R_INLINE int rmbl_blake2b(const unsigned char *msg, size_t msglen,
                                 const unsigned char *key, size_t keylen,
                                 int outlen, unsigned char *out) {
    static int (*fn)(const unsigned char *, size_t, const unsigned char *,
                     size_t, int, unsigned char *) = NULL;
    if (fn == NULL)
        fn = (int (*)(const unsigned char *, size_t, const unsigned char *,
                      size_t, int, unsigned char *))
             R_GetCCallable("rmoriebricklayer", "rmbl_blake2b");
    return fn(msg, msglen, key, keylen, outlen, out);
}

static R_INLINE void rmbl_pbkdf2_sha256(const unsigned char *pass,
                                        size_t passlen,
                                        const unsigned char *salt,
                                        size_t saltlen, int iterations,
                                        int dklen, unsigned char *out) {
    static void (*fn)(const unsigned char *, size_t, const unsigned char *,
                      size_t, int, int, unsigned char *) = NULL;
    if (fn == NULL)
        fn = (void (*)(const unsigned char *, size_t, const unsigned char *,
                       size_t, int, int, unsigned char *))
             R_GetCCallable("rmoriebricklayer", "rmbl_pbkdf2_sha256");
    fn(pass, passlen, salt, saltlen, iterations, dklen, out);
}

/* Operating-system CSPRNG. Returns 0 on success; a non-zero return MUST
   be treated as fatal, never as a reason to fall back to a weaker
   source. */
static R_INLINE int rmbl_os_random(unsigned char *out, size_t n) {
    static int (*fn)(unsigned char *, size_t) = NULL;
    if (fn == NULL)
        fn = (int (*)(unsigned char *, size_t))
             R_GetCCallable("rmoriebricklayer", "rmbl_os_random");
    return fn(out, n);
}

#ifdef __cplusplus
}
#endif

#endif /* RMORIEBRICKLAYER_H */
