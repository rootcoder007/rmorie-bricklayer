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

/* .Call wrappers (rmbl_core.cpp) -- the first kernels and SHA-256 */
extern SEXP C_rmbl_mean(SEXP);
extern SEXP C_rmbl_mean_running(SEXP);
extern SEXP C_rmbl_var(SEXP);
extern SEXP C_rmbl_cor(SEXP, SEXP);
extern SEXP C_rmbl_normal_pdf(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_sha256(SEXP);
extern SEXP C_rmbl_sha256_chunk(SEXP, SEXP, SEXP);
/* .Call wrappers (rmbl_core.cpp) -- vendored morie kernels, now bound */
extern SEXP C_rmbl_sd(SEXP, SEXP);
extern SEXP C_rmbl_euclid(SEXP, SEXP);
extern SEXP C_rmbl_normal_logpdf(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_ipw(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_bootstrap_mean(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_bounded_draw(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_gamma_cdf(SEXP, SEXP);
extern SEXP C_rmbl_hawkes_nll_grad(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_hawkes_rescaled(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_hawkes_intensity(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_hawkes_em_pass(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_hawkes_cdf_sum(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_uniforms(SEXP, SEXP);
extern SEXP C_rmbl_hawkes_fit_pbfgs(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
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
extern SEXP C_rmbl_hash_two_part(SEXP, SEXP);
extern SEXP C_rmbl_crc32(SEXP);
/* rmbl_series.cpp: concentration and short-series trend */
extern SEXP C_rmbl_gini(SEXP);
extern SEXP C_rmbl_lorenz(SEXP);
extern SEXP C_rmbl_top_share(SEXP, SEXP);
extern SEXP C_rmbl_mann_kendall(SEXP);
extern SEXP C_rmbl_theil_sen(SEXP, SEXP);
extern SEXP C_rmbl_sen_slopes(SEXP, SEXP);
extern SEXP C_rmbl_hurwitz_zeta(SEXP, SEXP);
/* rmbl_keccak.cpp: FIPS 202 */
extern SEXP C_rmbl_shake(SEXP, SEXP, SEXP);
/* rmbl_slhdsa.cpp: the FIPS 204/205 pre-hash and the internal SLH-DSA functions */
extern SEXP C_rmbl_prehash_digest(SEXP, SEXP);
extern SEXP C_rmbl_slhdsa_sign_internal(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_slhdsa_verify_internal(SEXP, SEXP, SEXP, SEXP);
/* rmbl_mldsa_ntt.cpp: FIPS 204 */
extern SEXP C_rmbl_mldsa_sizes(SEXP);
extern SEXP C_rmbl_mldsa_keypair(SEXP, SEXP);
extern SEXP C_rmbl_mldsa_sign(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_mldsa_mu(SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_mldsa_sign_mu(SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_mldsa_verify_mu(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_mldsa_verify(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);

/* rmbl_strtod.cpp: correctly rounded decimal conversion, both ways */
extern SEXP C_rmbl_strtod(SEXP);
extern SEXP C_rmbl_dtoa17(SEXP);
/* rmbl_mgf1.cpp: HMAC and MGF1, for the SHA-2 instantiation of FIPS 205
 * and exposed so their published vectors can be asserted */
extern SEXP C_rmbl_sha1(SEXP);
extern SEXP C_rmbl_sha384(SEXP);
extern SEXP C_rmbl_hmac_shax(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_mgf1(SEXP, SEXP, SEXP);

/* rmbl_ecdsa.cpp: ECDSA verification over the NIST prime curves */
extern SEXP C_rmbl_ecdsa_verify(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_ec_mul(SEXP, SEXP);
extern SEXP C_rmbl_ec_order(SEXP);

/* rmbl_fetch.cpp: the requests with a body or headers, and the native spinner */
extern SEXP C_rmbl_http_post(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_http_put(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_http_get(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_wait_label(SEXP, SEXP, SEXP);
/* rmbl_asn1.cpp: DER parsing and the RSA operation, for RFC 3161 */
extern SEXP C_rmbl_der_parse(SEXP);
extern SEXP C_rmbl_rsa_recover(SEXP, SEXP, SEXP);

/* rmbl_mlkem.cpp: FIPS 203 key encapsulation */
extern SEXP C_rmbl_mlkem_sizes(SEXP);
extern SEXP C_rmbl_mlkem_keygen(SEXP, SEXP);
extern SEXP C_rmbl_mlkem_encaps(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_mlkem_decaps(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_mlkem_decaps_masked(SEXP, SEXP, SEXP);

/* rmbl_hqc.cpp: HQC-KEM (code-based key encapsulation) */
extern SEXP C_rmbl_hqc_sizes(SEXP);
extern SEXP C_rmbl_hqc_keygen(SEXP, SEXP);
extern SEXP C_rmbl_hqc_encaps(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_hqc_decaps(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_hqc_backend(SEXP);
extern SEXP C_rmbl_hqc_selftest(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_hqc4_sizes(SEXP);
extern SEXP C_rmbl_hqc4_keygen(SEXP, SEXP);
extern SEXP C_rmbl_hqc4_encaps(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_hqc4_decaps(SEXP, SEXP, SEXP);

/* rmbl_drbg.cpp: AES-256 and the SP 800-90A CTR_DRBG */
extern SEXP C_rmbl_aes256_encrypt(SEXP, SEXP);
extern SEXP C_rmbl_drbg_instantiate(SEXP, SEXP);
extern SEXP C_rmbl_drbg_reseed(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_drbg_generate(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_aes_backend(SEXP);

/* rmbl_slhdsa.cpp: FIPS 205 */
extern SEXP C_rmbl_slhdsa_sizes(SEXP);
extern SEXP C_rmbl_slhdsa_keypair(SEXP, SEXP);
extern SEXP C_rmbl_slhdsa_sign(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_slhdsa_verify(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
/* rmbl_series.cpp: Moran's I */
extern SEXP C_rmbl_morans_i(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
/* rmbl_series.cpp plain-C kernels, for LinkingTo consumers */
extern double   rmbl_gini(const double *, R_xlen_t);
extern double   rmbl_top_share(const double *, R_xlen_t, double, R_xlen_t *);
extern R_xlen_t rmbl_lorenz(const double *, R_xlen_t, double *, double *);
extern void     rmbl_mann_kendall(const double *, R_xlen_t, double *,
                                  double *, R_xlen_t *);
extern void     rmbl_theil_sen(const double *, const double *, R_xlen_t,
                               double *, double *);
extern double   rmbl_hurwitz_zeta(double, double);
/* rmbl_digest.cpp: HMAC, the constant-time comparison and the Merkle tree */
extern SEXP C_rmbl_hmac_sha256(SEXP, SEXP);
extern SEXP C_rmbl_digest_equal(SEXP, SEXP);
extern SEXP C_rmbl_merkle_root(SEXP, SEXP);
extern SEXP C_rmbl_merkle_leaves(SEXP, SEXP);
extern SEXP C_rmbl_merkle_proof(SEXP, SEXP, SEXP);
/* .Call wrappers (rmbl_pqc.cpp) -- post-quantum capsule signatures */
extern SEXP C_rmbl_xmss_keygen(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_xmss_sign(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_xmss_verify(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP,
                               SEXP);
extern SEXP C_rmbl_pqc_backends(void);
/* .Call wrappers (rmbl_sketch.cpp) -- one-pass sketches */
extern SEXP C_rmbl_moments_acc(SEXP);
extern SEXP C_rmbl_json_fast(SEXP, SEXP, SEXP);   /* rmbl_json.cpp */
extern SEXP C_rmbl_svy_dblcode(SEXP);       /* rmbl_survey.c */
extern SEXP C_rmbl_sha256_real(SEXP);       /* rmbl_survey.c */
extern SEXP C_rmbl_svy_msethash(SEXP);      /* rmbl_survey.c */
extern SEXP C_rmbl_svy_colsumm(SEXP, SEXP, SEXP, SEXP); /* rmbl_survey.c */
extern SEXP C_rmbl_moments_merge(SEXP, SEXP);
extern SEXP C_rmbl_reservoir(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_hll_add(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_hll_count(SEXP);
/* .Call wrappers (rmbl_kdf.cpp) -- BLAKE2b, PBKDF2, OS entropy */
extern SEXP C_rmbl_blake2b(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_pbkdf2(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_os_random(SEXP);
/* .Call wrappers (defined in rmbl_fetch.cpp) -- libcurl fetch + wayback */
extern SEXP C_rmbl_fetch_fallback(SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_http_download(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_redirect_check(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_url_check(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_net_probe(SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_wayback(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_wayback_into(SEXP, SEXP, SEXP, SEXP);
/* .Call wrappers (defined in rmbl_siu.cpp) -- vendored SIU parse/resolve */
extern SEXP C_rmbl_siu_html_to_text(SEXP);
extern SEXP C_rmbl_siu_parse_html(SEXP);
extern SEXP C_rmbl_siu_to_iso_date(SEXP);
extern SEXP C_rmbl_siu_resolve_so(SEXP);
extern SEXP C_rmbl_siu_schema(SEXP);

/* plain-C kernels -- the cross-package API: rmbl_core.cpp (the first block, through
 * rmbl_hawkes_nll), rmbl_stats.cpp, rmbl_digest.cpp (SHA-512, HMAC, the comparison),
 * rmbl_sketch.cpp (moments) and rmbl_kdf.cpp (BLAKE2b, PBKDF2, OS entropy) */
extern double rmbl_mean(const double *, R_xlen_t);
extern double rmbl_mean_running(const double *, R_xlen_t);
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
extern int    rmbl_pbkdf2_sha256(const unsigned char *, size_t,
                                 const unsigned char *, size_t, int, int,
                                 unsigned char *);
extern int    rmbl_os_random(unsigned char *, size_t);
/* fetch kernels (defined in rmbl_fetch.cpp) -- the cross-package fetch API */
extern int  rmbl_fetch_with_fallback(const char *, const char *, const char *, int);
extern int  rmbl_wayback_snapshot(const char *, char *, int, int);

/* the used-index record's file lock (rmbl_flock.c) */
extern SEXP C_rmbl_flock_acquire(SEXP, SEXP);
extern SEXP C_rmbl_flock_release(SEXP);
extern SEXP C_rmbl_flock_with(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_env_wipe(SEXP);
extern SEXP C_rmbl_path_kind(SEXP);
extern SEXP C_rmbl_write_file_checked(SEXP, SEXP, SEXP);
extern SEXP C_rmbl_gunzip_checked(SEXP, SEXP);   /* rmbl_gunzip.c */
extern SEXP C_rmbl_gunzip_count(SEXP, SEXP);     /* rmbl_gunzip.c */
extern SEXP C_rmbl_csv_split(SEXP, SEXP);   /* rmbl_csv.c */
/* rmbl_progress.c: .bl_readline's check that raises a pending Ctrl-C before the terminal read
 * starts, and the progress bar and spinner */
extern SEXP C_rmbl_check_interrupt(void);
extern SEXP C_rmbl_progress_frame(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
extern SEXP C_rmbl_progress_spinner(SEXP, SEXP);
/* replicate totals for survey estimation (rmbl_survey.c) */
extern SEXP C_rmbl_svy_reptotals(SEXP, SEXP, SEXP);
/* rmbl_progress.c: the progress bar and spinner, for LinkingTo consumers */
extern int rmbl_progress_bar(double, double, int, int, int, int, int, int, int, char *, int);
extern const char *rmbl_progress_spinner(double, int);

static const R_CallMethodDef CallEntries[] = {
    {"C_rmbl_flock_acquire",  (DL_FUNC) &C_rmbl_flock_acquire,  2},
    {"C_rmbl_flock_release",  (DL_FUNC) &C_rmbl_flock_release,  1},
    {"C_rmbl_flock_with",     (DL_FUNC) &C_rmbl_flock_with,     3},
    {"C_rmbl_env_wipe",       (DL_FUNC) &C_rmbl_env_wipe,       1},
    {"C_rmbl_path_kind",      (DL_FUNC) &C_rmbl_path_kind,      1},
    {"C_rmbl_write_file_checked", (DL_FUNC) &C_rmbl_write_file_checked, 3},
    {"C_rmbl_gunzip_checked",     (DL_FUNC) &C_rmbl_gunzip_checked,     2},
    {"C_rmbl_gunzip_count",       (DL_FUNC) &C_rmbl_gunzip_count,       2},
    {"C_rmbl_json_fast",          (DL_FUNC) &C_rmbl_json_fast,          3},
    {"C_rmbl_svy_dblcode",        (DL_FUNC) &C_rmbl_svy_dblcode,        1},
    {"C_rmbl_sha256_real",        (DL_FUNC) &C_rmbl_sha256_real,        1},
    {"C_rmbl_svy_msethash",       (DL_FUNC) &C_rmbl_svy_msethash,       1},
    {"C_rmbl_svy_colsumm",        (DL_FUNC) &C_rmbl_svy_colsumm,        4},
    {"C_rmbl_csv_split",          (DL_FUNC) &C_rmbl_csv_split,          2},
    {"C_rmbl_check_interrupt",    (DL_FUNC) &C_rmbl_check_interrupt,    0},
    {"C_rmbl_progress_frame",     (DL_FUNC) &C_rmbl_progress_frame,     7},
    {"C_rmbl_progress_spinner",   (DL_FUNC) &C_rmbl_progress_spinner,   2},
    {"C_rmbl_svy_reptotals",      (DL_FUNC) &C_rmbl_svy_reptotals,      3},
    {"C_rmbl_mean",           (DL_FUNC) &C_rmbl_mean,           1},
    {"C_rmbl_mean_running",   (DL_FUNC) &C_rmbl_mean_running,   1},
    {"C_rmbl_var",            (DL_FUNC) &C_rmbl_var,            1},
    {"C_rmbl_cor",            (DL_FUNC) &C_rmbl_cor,            2},
    {"C_rmbl_normal_pdf",     (DL_FUNC) &C_rmbl_normal_pdf,     3},
    {"C_rmbl_sha256",         (DL_FUNC) &C_rmbl_sha256,         1},
    {"C_rmbl_sha256_chunk",   (DL_FUNC) &C_rmbl_sha256_chunk,   3},
    {"C_rmbl_sha512",         (DL_FUNC) &C_rmbl_sha512,         1},
    {"C_rmbl_hash_two_part",  (DL_FUNC) &C_rmbl_hash_two_part,  2},
    {"C_rmbl_fetch_fallback", (DL_FUNC) &C_rmbl_fetch_fallback, 5},
    {"C_rmbl_http_download",  (DL_FUNC) &C_rmbl_http_download,  7},
    {"C_rmbl_redirect_check", (DL_FUNC) &C_rmbl_redirect_check, 4},
    {"C_rmbl_wayback",        (DL_FUNC) &C_rmbl_wayback,        3},
    {"C_rmbl_wayback_into",   (DL_FUNC) &C_rmbl_wayback_into,   4},
    {"C_rmbl_url_check",      (DL_FUNC) &C_rmbl_url_check,      4},
    {"C_rmbl_net_probe",      (DL_FUNC) &C_rmbl_net_probe,      4},
    {"C_rmbl_siu_html_to_text",      (DL_FUNC) &C_rmbl_siu_html_to_text,      1},
    {"C_rmbl_siu_parse_html",        (DL_FUNC) &C_rmbl_siu_parse_html,        1},
    {"C_rmbl_siu_to_iso_date",       (DL_FUNC) &C_rmbl_siu_to_iso_date,       1},
    {"C_rmbl_siu_resolve_so",        (DL_FUNC) &C_rmbl_siu_resolve_so,        1},
    {"C_rmbl_siu_schema",            (DL_FUNC) &C_rmbl_siu_schema,            1},
    {"C_rmbl_sd",                (DL_FUNC) &C_rmbl_sd,                2},
    {"C_rmbl_euclid",            (DL_FUNC) &C_rmbl_euclid,            2},
    {"C_rmbl_normal_logpdf",     (DL_FUNC) &C_rmbl_normal_logpdf,     3},
    {"C_rmbl_ipw",               (DL_FUNC) &C_rmbl_ipw,               4},
    {"C_rmbl_bootstrap_mean",    (DL_FUNC) &C_rmbl_bootstrap_mean,    3},
    {"C_rmbl_bounded_draw",      (DL_FUNC) &C_rmbl_bounded_draw,      3},
    {"C_rmbl_gamma_cdf",         (DL_FUNC) &C_rmbl_gamma_cdf,         2},
    {"C_rmbl_hawkes_nll_grad",   (DL_FUNC) &C_rmbl_hawkes_nll_grad,   12},
    {"C_rmbl_hawkes_rescaled",   (DL_FUNC) &C_rmbl_hawkes_rescaled,   7},
    {"C_rmbl_hawkes_intensity",  (DL_FUNC) &C_rmbl_hawkes_intensity,  7},
    {"C_rmbl_hawkes_em_pass",    (DL_FUNC) &C_rmbl_hawkes_em_pass,    6},
    {"C_rmbl_hawkes_cdf_sum",    (DL_FUNC) &C_rmbl_hawkes_cdf_sum,    4},
    {"C_rmbl_uniforms",          (DL_FUNC) &C_rmbl_uniforms,          2},
    {"C_rmbl_hawkes_fit_pbfgs",  (DL_FUNC) &C_rmbl_hawkes_fit_pbfgs,  13},
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
    {"C_rmbl_crc32",             (DL_FUNC) &C_rmbl_crc32,             1},
    {"C_rmbl_gini",              (DL_FUNC) &C_rmbl_gini,              1},
    {"C_rmbl_lorenz",            (DL_FUNC) &C_rmbl_lorenz,            1},
    {"C_rmbl_top_share",         (DL_FUNC) &C_rmbl_top_share,         2},
    {"C_rmbl_mann_kendall",      (DL_FUNC) &C_rmbl_mann_kendall,      1},
    {"C_rmbl_theil_sen",         (DL_FUNC) &C_rmbl_theil_sen,         2},
    {"C_rmbl_sen_slopes",        (DL_FUNC) &C_rmbl_sen_slopes,        2},
    {"C_rmbl_hurwitz_zeta",      (DL_FUNC) &C_rmbl_hurwitz_zeta,      2},
    {"C_rmbl_shake",             (DL_FUNC) &C_rmbl_shake,             3},
    {"C_rmbl_prehash_digest",    (DL_FUNC) &C_rmbl_prehash_digest,    2},
    {"C_rmbl_slhdsa_sign_internal", (DL_FUNC) &C_rmbl_slhdsa_sign_internal, 4},
    {"C_rmbl_slhdsa_verify_internal", (DL_FUNC) &C_rmbl_slhdsa_verify_internal, 4},
    {"C_rmbl_mldsa_sizes",       (DL_FUNC) &C_rmbl_mldsa_sizes,       1},
    {"C_rmbl_mldsa_keypair",     (DL_FUNC) &C_rmbl_mldsa_keypair,     2},
    {"C_rmbl_mldsa_sign",        (DL_FUNC) &C_rmbl_mldsa_sign,        7},
    {"C_rmbl_mldsa_mu",          (DL_FUNC) &C_rmbl_mldsa_mu,          5},
    {"C_rmbl_mldsa_sign_mu",     (DL_FUNC) &C_rmbl_mldsa_sign_mu,     5},
    {"C_rmbl_mldsa_verify_mu",   (DL_FUNC) &C_rmbl_mldsa_verify_mu,   4},
    {"C_rmbl_mldsa_verify",      (DL_FUNC) &C_rmbl_mldsa_verify,      6},
    {"C_rmbl_strtod",             (DL_FUNC) &C_rmbl_strtod,             1},
    {"C_rmbl_dtoa17",             (DL_FUNC) &C_rmbl_dtoa17,             1},
    {"C_rmbl_sha1",               (DL_FUNC) &C_rmbl_sha1,               1},
    {"C_rmbl_sha384",             (DL_FUNC) &C_rmbl_sha384,             1},
    {"C_rmbl_hmac_shax",         (DL_FUNC) &C_rmbl_hmac_shax,         3},
    {"C_rmbl_mgf1",              (DL_FUNC) &C_rmbl_mgf1,              3},
    {"C_rmbl_ecdsa_verify",       (DL_FUNC) &C_rmbl_ecdsa_verify,       6},
    {"C_rmbl_ec_mul",             (DL_FUNC) &C_rmbl_ec_mul,             2},
    {"C_rmbl_ec_order",           (DL_FUNC) &C_rmbl_ec_order,           1},
    {"C_rmbl_http_post", (DL_FUNC) &C_rmbl_http_post, 6},
    {"C_rmbl_http_put", (DL_FUNC) &C_rmbl_http_put, 6},
    {"C_rmbl_http_get",  (DL_FUNC) &C_rmbl_http_get,  4},
    {"C_rmbl_wait_label", (DL_FUNC) &C_rmbl_wait_label, 3},
    {"C_rmbl_der_parse",         (DL_FUNC) &C_rmbl_der_parse,         1},
    {"C_rmbl_rsa_recover",       (DL_FUNC) &C_rmbl_rsa_recover,       3},
    {"C_rmbl_mlkem_sizes",       (DL_FUNC) &C_rmbl_mlkem_sizes,       1},
    {"C_rmbl_mlkem_keygen",      (DL_FUNC) &C_rmbl_mlkem_keygen,      2},
    {"C_rmbl_mlkem_encaps",      (DL_FUNC) &C_rmbl_mlkem_encaps,      3},
    {"C_rmbl_mlkem_decaps",      (DL_FUNC) &C_rmbl_mlkem_decaps,      3},
    {"C_rmbl_mlkem_decaps_masked", (DL_FUNC) &C_rmbl_mlkem_decaps_masked, 3},
    {"C_rmbl_hqc_sizes",         (DL_FUNC) &C_rmbl_hqc_sizes,         1},
    {"C_rmbl_hqc_keygen",        (DL_FUNC) &C_rmbl_hqc_keygen,        2},
    {"C_rmbl_hqc_encaps",        (DL_FUNC) &C_rmbl_hqc_encaps,        4},
    {"C_rmbl_hqc_decaps",        (DL_FUNC) &C_rmbl_hqc_decaps,        3},
    {"C_rmbl_hqc_backend",       (DL_FUNC) &C_rmbl_hqc_backend,       1},
    {"C_rmbl_hqc_selftest",      (DL_FUNC) &C_rmbl_hqc_selftest,      3},
    {"C_rmbl_hqc4_sizes",        (DL_FUNC) &C_rmbl_hqc4_sizes,        1},
    {"C_rmbl_hqc4_keygen",       (DL_FUNC) &C_rmbl_hqc4_keygen,       2},
    {"C_rmbl_hqc4_encaps",       (DL_FUNC) &C_rmbl_hqc4_encaps,       4},
    {"C_rmbl_hqc4_decaps",       (DL_FUNC) &C_rmbl_hqc4_decaps,       3},
    {"C_rmbl_aes256_encrypt",    (DL_FUNC) &C_rmbl_aes256_encrypt,    2},
    {"C_rmbl_drbg_instantiate",  (DL_FUNC) &C_rmbl_drbg_instantiate,  2},
    {"C_rmbl_drbg_reseed",       (DL_FUNC) &C_rmbl_drbg_reseed,       4},
    {"C_rmbl_drbg_generate",     (DL_FUNC) &C_rmbl_drbg_generate,     4},
    {"C_rmbl_aes_backend",       (DL_FUNC) &C_rmbl_aes_backend,       1},
    {"C_rmbl_slhdsa_sizes",     (DL_FUNC) &C_rmbl_slhdsa_sizes,     1},
    {"C_rmbl_slhdsa_keypair",   (DL_FUNC) &C_rmbl_slhdsa_keypair,   2},
    {"C_rmbl_slhdsa_sign",      (DL_FUNC) &C_rmbl_slhdsa_sign,      6},
    {"C_rmbl_slhdsa_verify",    (DL_FUNC) &C_rmbl_slhdsa_verify,    6},
    {"C_rmbl_morans_i",          (DL_FUNC) &C_rmbl_morans_i,          7},
    {"C_rmbl_hmac_sha256",       (DL_FUNC) &C_rmbl_hmac_sha256,       2},
    {"C_rmbl_digest_equal",      (DL_FUNC) &C_rmbl_digest_equal,      2},
    {"C_rmbl_merkle_root",       (DL_FUNC) &C_rmbl_merkle_root,       2},
    {"C_rmbl_merkle_leaves",     (DL_FUNC) &C_rmbl_merkle_leaves,     2},
    {"C_rmbl_merkle_proof",      (DL_FUNC) &C_rmbl_merkle_proof,      3},
    {"C_rmbl_xmss_keygen",       (DL_FUNC) &C_rmbl_xmss_keygen,       3},
    {"C_rmbl_xmss_sign",         (DL_FUNC) &C_rmbl_xmss_sign,         6},
    {"C_rmbl_xmss_verify",       (DL_FUNC) &C_rmbl_xmss_verify,       8},
    {"C_rmbl_pqc_backends",      (DL_FUNC) &C_rmbl_pqc_backends,      0},
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
    R_RegisterCCallable("rmoriebricklayer", "rmbl_gini",       (DL_FUNC) rmbl_gini);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_top_share",  (DL_FUNC) rmbl_top_share);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_lorenz",     (DL_FUNC) rmbl_lorenz);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_mann_kendall", (DL_FUNC) rmbl_mann_kendall);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_progress_bar", (DL_FUNC) rmbl_progress_bar);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_progress_spinner", (DL_FUNC) rmbl_progress_spinner);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_theil_sen",  (DL_FUNC) rmbl_theil_sen);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_hurwitz_zeta", (DL_FUNC) rmbl_hurwitz_zeta);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_mean",        (DL_FUNC) rmbl_mean);
    R_RegisterCCallable("rmoriebricklayer", "rmbl_mean_running", (DL_FUNC) rmbl_mean_running);
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
