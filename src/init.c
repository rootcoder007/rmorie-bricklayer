/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * init.c -- DLL registration for rmoriebricklayer.
 *
 * Two things happen here:
 *   1. The .Call entry points used by rmoriebricklayer's own R wrappers
 *      are registered (R_registerRoutines + R_useDynamicSymbols FALSE).
 *   2. The plain-C kernels are published with R_RegisterCCallable so that
 *      packages declaring `LinkingTo: rmoriebricklayer` can resolve them
 *      at load time via the inline shims in inst/include/rmoriebricklayer.h.
 */

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <stddef.h>

/* .Call wrappers (defined in rmbl_core.c) */
extern SEXP C_rmbl_mean(SEXP);
extern SEXP C_rmbl_var(SEXP);
extern SEXP C_rmbl_cor(SEXP, SEXP);
extern SEXP C_rmbl_normal_pdf(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_sha256(SEXP);
/* .Call wrappers (rmbl_core.cpp) -- vendored morie kernels, now bound */
extern SEXP C_rmbl_sd(SEXP, SEXP);
extern SEXP C_rmbl_euclid(SEXP, SEXP);
extern SEXP C_rmbl_normal_logpdf(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_ipw(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_bootstrap_mean(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_gamma_cdf(SEXP, SEXP);
extern SEXP C_rmbl_hawkes_nll(SEXP, SEXP, SEXP, SEXP);
/* .Call wrappers (rmbl_stats.cpp) -- bricklayer's own statistics */
extern SEXP C_rmbl_moments(SEXP);
extern SEXP C_rmbl_quantile(SEXP, SEXP);
extern SEXP C_rmbl_median(SEXP);
extern SEXP C_rmbl_mad(SEXP, SEXP);
extern SEXP C_rmbl_trimmed_mean(SEXP, SEXP);
extern SEXP C_rmbl_winsorized_mean(SEXP, SEXP);
extern SEXP C_rmbl_weighted(SEXP, SEXP);
extern SEXP C_rmbl_cor_spearman(SEXP, SEXP);
extern SEXP C_rmbl_midranks(SEXP);
extern SEXP C_rmbl_cov_matrix(SEXP);
extern SEXP C_rmbl_ks(SEXP, SEXP);
extern SEXP C_rmbl_psi(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_first_digit_counts(SEXP);
/* .Call wrappers (rmbl_digest.cpp) -- provenance digests */
extern SEXP C_rmbl_sha512(SEXP);
extern SEXP C_rmbl_crc32(SEXP);
/* rmbl_series.cpp: concentration and short-series trend */
extern SEXP C_rmbl_gini(SEXP);
extern SEXP C_rmbl_lorenz(SEXP);
extern SEXP C_rmbl_top_share(SEXP, SEXP);
extern SEXP C_rmbl_mann_kendall(SEXP);
extern SEXP C_rmbl_theil_sen(SEXP, SEXP);
extern SEXP C_rmbl_hurwitz_zeta(SEXP, SEXP);
extern SEXP C_rmbl_hmac_sha256(SEXP, SEXP);
extern SEXP C_rmbl_digest_equal(SEXP, SEXP);
extern SEXP C_rmbl_merkle_root(SEXP);
extern SEXP C_rmbl_merkle_leaves(SEXP);
extern SEXP C_rmbl_merkle_proof(SEXP, SEXP);
/* .Call wrappers (rmbl_pqc.cpp) -- post-quantum capsule signatures */
extern SEXP C_rmbl_xmss_keygen(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_xmss_sign(SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_xmss_verify(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_pqc_backends(void);
extern SEXP C_rmbl_oqs_keygen(SEXP);
extern SEXP C_rmbl_oqs_sign(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_oqs_verify(SEXP, SEXP, SEXP, SEXP);
/* .Call wrappers (rmbl_sketch.cpp) -- one-pass sketches */
extern SEXP C_rmbl_moments_acc(SEXP);
extern SEXP C_rmbl_moments_merge(SEXP, SEXP);
extern SEXP C_rmbl_reservoir(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_hll_add(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_hll_count(SEXP);
/* .Call wrappers (rmbl_kdf.cpp) -- BLAKE2b, PBKDF2, OS entropy */
extern SEXP C_rmbl_blake2b(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_pbkdf2(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_os_random(SEXP);
/* .Call wrappers (defined in rmbl_fetch.cpp) -- libcurl fetch + wayback */
extern SEXP C_rmbl_fetch_fallback(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_wayback(SEXP, SEXP);
/* .Call wrappers (defined in rmbl_siu.cpp) -- vendored SIU parse/resolve */
extern SEXP C_rmbl_siu_html_to_text(SEXP);
extern SEXP C_rmbl_siu_parse_html(SEXP);
extern SEXP C_rmbl_siu_to_iso_date(SEXP);
extern SEXP C_rmbl_siu_strip_boilerplate(SEXP);
extern SEXP C_rmbl_siu_resolve_so(SEXP);
extern SEXP C_rmbl_siu_schema(SEXP);

/* plain-C kernels (defined in rmbl_core.c) -- the cross-package API */
extern double rmbl_mean(const double *, R_xlen_t);
extern double rmbl_var(const double *, R_xlen_t);
extern double rmbl_cor_pearson(const double *, const double *, R_xlen_t);
extern double rmbl_normal_pdf(double, double, double);
extern void   rmbl_sha256_hex(const unsigned char *, size_t, char *);
extern void   rmbl_sha256_raw(const unsigned char *, size_t, unsigned char *);
extern double rmbl_sd(const double *, R_xlen_t, int);
extern double rmbl_euclid_dist(const double *, const double *, R_xlen_t);
extern double rmbl_normal_logpdf(double, double, double);
extern void   rmbl_ipw_weights(const double *, const double *, R_xlen_t,
                               double, double, double *);
extern void   rmbl_bootstrap_mean(const double *, R_xlen_t, R_xlen_t,
                                  unsigned long long, double *);
extern double rmbl_gamma_cdf(double, double);
extern double rmbl_hawkes_nll(const double *, R_xlen_t, double, int,
                              const double *, R_xlen_t);
extern void   rmbl_moments(const double *, R_xlen_t, double *);
extern void   rmbl_quantile(const double *, R_xlen_t, const double *,
                            R_xlen_t, double *);
extern double rmbl_median(const double *, R_xlen_t);
extern double rmbl_mad(const double *, R_xlen_t, double);
extern double rmbl_trimmed_mean(const double *, R_xlen_t, double);
extern double rmbl_winsorized_mean(const double *, R_xlen_t, double);
extern double rmbl_weighted_mean(const double *, const double *, R_xlen_t);
extern double rmbl_weighted_var(const double *, const double *, R_xlen_t);
extern double rmbl_cor_spearman(const double *, const double *, R_xlen_t);
extern void   rmbl_midranks(const double *, R_xlen_t, double *);
extern void   rmbl_cov_matrix(const double *, R_xlen_t, R_xlen_t, double *);
extern double rmbl_ks_two_sample(const double *, R_xlen_t, const double *,
                                 R_xlen_t);
extern double rmbl_ks_pvalue(double, double);
extern double rmbl_psi(const double *, const double *, R_xlen_t, double);
extern double rmbl_js_divergence(const double *, const double *, R_xlen_t);
extern void   rmbl_sha512_hex(const unsigned char *, size_t, char *);
extern void   rmbl_hmac_sha256_hex(const unsigned char *, size_t,
                                   const unsigned char *, size_t, char *);
extern int    rmbl_digest_equal(const char *, const char *, size_t);
extern void   rmbl_moments_acc(const double *, R_xlen_t, double *);
extern void   rmbl_moments_merge(const double *, const double *, double *);
extern int    rmbl_blake2b(const unsigned char *, size_t,
                           const unsigned char *, size_t, int,
                           unsigned char *);
extern void   rmbl_pbkdf2_sha256(const unsigned char *, size_t,
                                 const unsigned char *, size_t, int, int,
                                 unsigned char *);
extern int    rmbl_os_random(unsigned char *, size_t);
/* fetch kernels (defined in rmbl_fetch.cpp) -- the cross-package fetch API */
extern int  rmbl_fetch_with_fallback(const char *, const char *, const char *, int);
extern int  rmbl_wayback_snapshot(const char *, char *, int, int);

static const R_CallMethodDef CallEntries[] = {
    {"C_rmbl_mean",           (DL_FUNC) &C_rmbl_mean,           1},
    {"C_rmbl_var",            (DL_FUNC) &C_rmbl_var,            1},
    {"C_rmbl_cor",            (DL_FUNC) &C_rmbl_cor,            2},
    {"C_rmbl_normal_pdf",     (DL_FUNC) &C_rmbl_normal_pdf,     3},
    {"C_rmbl_sha256",         (DL_FUNC) &C_rmbl_sha256,         1},
    {"C_rmbl_fetch_fallback", (DL_FUNC) &C_rmbl_fetch_fallback, 4},
    {"C_rmbl_wayback",        (DL_FUNC) &C_rmbl_wayback,        2},
    {"C_rmbl_siu_html_to_text",      (DL_FUNC) &C_rmbl_siu_html_to_text,      1},
    {"C_rmbl_siu_parse_html",        (DL_FUNC) &C_rmbl_siu_parse_html,        1},
    {"C_rmbl_siu_to_iso_date",       (DL_FUNC) &C_rmbl_siu_to_iso_date,       1},
    {"C_rmbl_siu_strip_boilerplate", (DL_FUNC) &C_rmbl_siu_strip_boilerplate, 1},
    {"C_rmbl_siu_resolve_so",        (DL_FUNC) &C_rmbl_siu_resolve_so,        1},
    {"C_rmbl_siu_schema",            (DL_FUNC) &C_rmbl_siu_schema,            1},
    {"C_rmbl_sd",                (DL_FUNC) &C_rmbl_sd,                2},
    {"C_rmbl_euclid",            (DL_FUNC) &C_rmbl_euclid,            2},
    {"C_rmbl_normal_logpdf",     (DL_FUNC) &C_rmbl_normal_logpdf,     3},
    {"C_rmbl_ipw",               (DL_FUNC) &C_rmbl_ipw,               4},
    {"C_rmbl_bootstrap_mean",    (DL_FUNC) &C_rmbl_bootstrap_mean,    3},
    {"C_rmbl_gamma_cdf",         (DL_FUNC) &C_rmbl_gamma_cdf,         2},
    {"C_rmbl_hawkes_nll",        (DL_FUNC) &C_rmbl_hawkes_nll,        4},
    {"C_rmbl_moments",           (DL_FUNC) &C_rmbl_moments,           1},
    {"C_rmbl_quantile",          (DL_FUNC) &C_rmbl_quantile,          2},
    {"C_rmbl_median",            (DL_FUNC) &C_rmbl_median,            1},
    {"C_rmbl_mad",               (DL_FUNC) &C_rmbl_mad,               2},
    {"C_rmbl_trimmed_mean",      (DL_FUNC) &C_rmbl_trimmed_mean,      2},
    {"C_rmbl_winsorized_mean",   (DL_FUNC) &C_rmbl_winsorized_mean,   2},
    {"C_rmbl_weighted",          (DL_FUNC) &C_rmbl_weighted,          2},
    {"C_rmbl_cor_spearman",      (DL_FUNC) &C_rmbl_cor_spearman,      2},
    {"C_rmbl_midranks",          (DL_FUNC) &C_rmbl_midranks,          1},
    {"C_rmbl_cov_matrix",        (DL_FUNC) &C_rmbl_cov_matrix,        1},
    {"C_rmbl_ks",                (DL_FUNC) &C_rmbl_ks,                2},
    {"C_rmbl_psi",               (DL_FUNC) &C_rmbl_psi,               3},
    {"C_rmbl_first_digit_counts",(DL_FUNC) &C_rmbl_first_digit_counts, 1},
    {"C_rmbl_sha512",            (DL_FUNC) &C_rmbl_sha512,            1},
    {"C_rmbl_crc32",             (DL_FUNC) &C_rmbl_crc32,             1},
    {"C_rmbl_gini",              (DL_FUNC) &C_rmbl_gini,              1},
    {"C_rmbl_lorenz",            (DL_FUNC) &C_rmbl_lorenz,            1},
    {"C_rmbl_top_share",         (DL_FUNC) &C_rmbl_top_share,         2},
    {"C_rmbl_mann_kendall",      (DL_FUNC) &C_rmbl_mann_kendall,      1},
    {"C_rmbl_theil_sen",         (DL_FUNC) &C_rmbl_theil_sen,         2},
    {"C_rmbl_hurwitz_zeta",      (DL_FUNC) &C_rmbl_hurwitz_zeta,      2},
    {"C_rmbl_hmac_sha256",       (DL_FUNC) &C_rmbl_hmac_sha256,       2},
    {"C_rmbl_digest_equal",      (DL_FUNC) &C_rmbl_digest_equal,      2},
    {"C_rmbl_merkle_root",       (DL_FUNC) &C_rmbl_merkle_root,       1},
    {"C_rmbl_merkle_leaves",     (DL_FUNC) &C_rmbl_merkle_leaves,     1},
    {"C_rmbl_merkle_proof",      (DL_FUNC) &C_rmbl_merkle_proof,      2},
    {"C_rmbl_xmss_keygen",       (DL_FUNC) &C_rmbl_xmss_keygen,       3},
    {"C_rmbl_xmss_sign",         (DL_FUNC) &C_rmbl_xmss_sign,         5},
    {"C_rmbl_xmss_verify",       (DL_FUNC) &C_rmbl_xmss_verify,       7},
    {"C_rmbl_pqc_backends",      (DL_FUNC) &C_rmbl_pqc_backends,      0},
    {"C_rmbl_oqs_keygen",        (DL_FUNC) &C_rmbl_oqs_keygen,        1},
    {"C_rmbl_oqs_sign",          (DL_FUNC) &C_rmbl_oqs_sign,          3},
    {"C_rmbl_oqs_verify",        (DL_FUNC) &C_rmbl_oqs_verify,        4},
    {"C_rmbl_moments_acc",       (DL_FUNC) &C_rmbl_moments_acc,       1},
    {"C_rmbl_moments_merge",     (DL_FUNC) &C_rmbl_moments_merge,     2},
    {"C_rmbl_reservoir",         (DL_FUNC) &C_rmbl_reservoir,         3},
    {"C_rmbl_hll_add",           (DL_FUNC) &C_rmbl_hll_add,           3},
    {"C_rmbl_hll_count",         (DL_FUNC) &C_rmbl_hll_count,         1},
    {"C_rmbl_blake2b",           (DL_FUNC) &C_rmbl_blake2b,           3},
    {"C_rmbl_pbkdf2",            (DL_FUNC) &C_rmbl_pbkdf2,            4},
    {"C_rmbl_os_random",         (DL_FUNC) &C_rmbl_os_random,         1},
    {NULL, NULL, 0}
};

void R_init_rmoriebricklayer(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);

    /* Publish the linkable kernels for sibling packages. */
    R_RegisterCCallable("rmoriebricklayer", "rmbl_mean",        (DL_FUNC) rmbl_mean);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_var",         (DL_FUNC) rmbl_var);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_cor_pearson", (DL_FUNC) rmbl_cor_pearson);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_normal_pdf",  (DL_FUNC) rmbl_normal_pdf);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_sha256_hex",  (DL_FUNC) rmbl_sha256_hex);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_fetch_with_fallback", (DL_FUNC) rmbl_fetch_with_fallback);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_wayback_snapshot",    (DL_FUNC) rmbl_wayback_snapshot);

    /* 0.4.0: the previously unbound morie kernels, bricklayer's own
       statistics, and the provenance digests. */
    R_RegisterCCallable("rmoriebricklayer", "rmbl_sha256_raw",     (DL_FUNC) rmbl_sha256_raw);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_sd",             (DL_FUNC) rmbl_sd);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_euclid_dist",    (DL_FUNC) rmbl_euclid_dist);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_normal_logpdf",  (DL_FUNC) rmbl_normal_logpdf);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_ipw_weights",    (DL_FUNC) rmbl_ipw_weights);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_bootstrap_mean", (DL_FUNC) rmbl_bootstrap_mean);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_gamma_cdf",      (DL_FUNC) rmbl_gamma_cdf);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_hawkes_nll",     (DL_FUNC) rmbl_hawkes_nll);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_moments",        (DL_FUNC) rmbl_moments);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_quantile",       (DL_FUNC) rmbl_quantile);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_median",         (DL_FUNC) rmbl_median);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_mad",            (DL_FUNC) rmbl_mad);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_trimmed_mean",   (DL_FUNC) rmbl_trimmed_mean);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_winsorized_mean",(DL_FUNC) rmbl_winsorized_mean);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_weighted_mean",  (DL_FUNC) rmbl_weighted_mean);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_weighted_var",   (DL_FUNC) rmbl_weighted_var);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_cor_spearman",   (DL_FUNC) rmbl_cor_spearman);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_midranks",       (DL_FUNC) rmbl_midranks);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_cov_matrix",     (DL_FUNC) rmbl_cov_matrix);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_ks_two_sample",  (DL_FUNC) rmbl_ks_two_sample);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_ks_pvalue",      (DL_FUNC) rmbl_ks_pvalue);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_psi",            (DL_FUNC) rmbl_psi);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_js_divergence",  (DL_FUNC) rmbl_js_divergence);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_sha512_hex",     (DL_FUNC) rmbl_sha512_hex);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_hmac_sha256_hex",(DL_FUNC) rmbl_hmac_sha256_hex);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_digest_equal",   (DL_FUNC) rmbl_digest_equal);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_moments_acc",   (DL_FUNC) rmbl_moments_acc);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_moments_merge", (DL_FUNC) rmbl_moments_merge);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_blake2b",       (DL_FUNC) rmbl_blake2b);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_pbkdf2_sha256", (DL_FUNC) rmbl_pbkdf2_sha256);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_os_random",     (DL_FUNC) rmbl_os_random);
}
