/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * rmbl_stats.cpp -- bricklayer's own statistical kernels.
 *
 * These are NOT part of morie's vendored numeric core (morie_core.h,
 * whose canonical copy lives in the morie repository and must not be
 * edited here). They are bricklayer-specific additions: the robust and
 * distributional summaries a data capsule needs to describe a column and
 * to decide whether a freshly fetched column still matches the one the
 * capsule was pinned against.
 *
 * Every kernel is published with R_RegisterCCallable (see init.c) so
 * sibling packages reach one compiled copy via
 * `LinkingTo: rmoriebricklayer`.
 *
 * Conventions, consistent with the rest of the core:
 *   * plain raw pointers + sizes, no R types in the kernels;
 *   * NA/NaN propagate -- there is no na.rm, callers drop them first;
 *   * a kernel with nothing to compute returns NaN rather than erroring.
 */

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <vector>

namespace {

const double kMadConstant = 1.4826022185056018;  /* 1 / qnorm(3/4) */

inline bool has_nan(const double *a, R_xlen_t n) {
    for (R_xlen_t i = 0; i < n; ++i) {
        if (std::isnan(a[i])) return true;
    }
    return false;
}

/* Type-7 quantile (R's default) on an already-sorted buffer. */
inline double quantile7_sorted(const std::vector<double> &v, double p) {
    const R_xlen_t n = static_cast<R_xlen_t>(v.size());
    if (n == 0) return std::nan("");
    if (n == 1) return v[0];
    const double h = (static_cast<double>(n) - 1.0) * p;
    double fl = std::floor(h);
    R_xlen_t lo = static_cast<R_xlen_t>(fl);
    if (lo < 0) lo = 0;
    if (lo >= n - 1) return v[n - 1];
    return v[lo] + (h - fl) * (v[lo + 1] - v[lo]);
}

inline double median_sorted(const std::vector<double> &v) {
    return quantile7_sorted(v, 0.5);
}

/* Midranks: tied values share the average of the ranks they span. */
inline void midranks(const double *a, R_xlen_t n, double *out) {
    std::vector<R_xlen_t> ord(static_cast<std::size_t>(n));
    for (R_xlen_t i = 0; i < n; ++i) ord[static_cast<std::size_t>(i)] = i;
    std::sort(ord.begin(), ord.end(),
              [&](R_xlen_t i, R_xlen_t j) { return a[i] < a[j]; });
    R_xlen_t i = 0;
    while (i < n) {
        R_xlen_t j = i;
        while (j + 1 < n && a[ord[static_cast<std::size_t>(j + 1)]] ==
                            a[ord[static_cast<std::size_t>(i)]]) {
            ++j;
        }
        /* ranks i+1 .. j+1 average to (i + j + 2) / 2 */
        const double r = (static_cast<double>(i) + static_cast<double>(j) + 2.0) / 2.0;
        for (R_xlen_t k = i; k <= j; ++k) out[ord[static_cast<std::size_t>(k)]] = r;
        i = j + 1;
    }
}

}  // namespace

extern "C" {

/* ---------------------------------------------------------------- */
/* One-pass central moments (Welford / Terriberry).                  */
/* out[0..3] = mean, variance (n-1), skewness, excess kurtosis.      */
/* The higher moments use the sample-moment definitions m3 / m2^1.5  */
/* and m4 / m2^2 - 3, with m_k the k-th central moment divided by n. */
/* ---------------------------------------------------------------- */
void rmbl_moments(const double *a, R_xlen_t n, double *out) {
    out[0] = out[1] = out[2] = out[3] = std::nan("");
    if (n < 1) return;
    if (has_nan(a, n)) return;

    double mean = 0.0, m2 = 0.0, m3 = 0.0, m4 = 0.0;
    for (R_xlen_t i = 0; i < n; ++i) {
        const double cnt = static_cast<double>(i) + 1.0;
        const double d = a[i] - mean;
        const double dn = d / cnt;
        const double dn2 = dn * dn;
        const double term = d * dn * (cnt - 1.0);
        m4 += term * dn2 * (cnt * cnt - 3.0 * cnt + 3.0) +
              6.0 * dn2 * m2 - 4.0 * dn * m3;
        m3 += term * dn * (cnt - 2.0) - 3.0 * dn * m2;
        m2 += term;
        mean += dn;
    }
    const double dn_all = static_cast<double>(n);
    out[0] = mean;
    out[1] = (n > 1) ? m2 / (dn_all - 1.0) : std::nan("");
    if (n > 2 && m2 > 0.0) {
        const double s2 = m2 / dn_all;
        out[2] = (m3 / dn_all) / std::pow(s2, 1.5);
    }
    if (n > 3 && m2 > 0.0) {
        const double s2 = m2 / dn_all;
        out[3] = (m4 / dn_all) / (s2 * s2) - 3.0;
    }
}

/* Type-7 quantiles at arbitrary probabilities. */
void rmbl_quantile(const double *a, R_xlen_t n, const double *probs,
                   R_xlen_t np, double *out) {
    if (n < 1 || has_nan(a, n)) {
        for (R_xlen_t k = 0; k < np; ++k) out[k] = std::nan("");
        return;
    }
    std::vector<double> v(a, a + n);
    std::sort(v.begin(), v.end());
    for (R_xlen_t k = 0; k < np; ++k) out[k] = quantile7_sorted(v, probs[k]);
}

double rmbl_median(const double *a, R_xlen_t n) {
    if (n < 1 || has_nan(a, n)) return std::nan("");
    std::vector<double> v(a, a + n);
    std::sort(v.begin(), v.end());
    return median_sorted(v);
}

/* Median absolute deviation, scaled to be consistent for the normal
 * standard deviation when `constant` is 1.4826. */
double rmbl_mad(const double *a, R_xlen_t n, double constant) {
    if (n < 1 || has_nan(a, n)) return std::nan("");
    std::vector<double> v(a, a + n);
    std::sort(v.begin(), v.end());
    const double med = median_sorted(v);
    for (R_xlen_t i = 0; i < n; ++i) v[static_cast<std::size_t>(i)] = std::fabs(a[i] - med);
    std::sort(v.begin(), v.end());
    return constant * median_sorted(v);
}

double rmbl_mad_constant(void) { return kMadConstant; }

/* Symmetric trimmed mean: drop floor(n * trim) values from each end,
 * matching base R's mean(x, trim = ). */
double rmbl_trimmed_mean(const double *a, R_xlen_t n, double trim) {
    if (n < 1 || has_nan(a, n)) return std::nan("");
    if (!(trim >= 0.0) || trim > 0.5) return std::nan("");
    std::vector<double> v(a, a + n);
    std::sort(v.begin(), v.end());
    if (trim >= 0.5) return median_sorted(v);
    const R_xlen_t k = static_cast<R_xlen_t>(std::floor(static_cast<double>(n) * trim));
    double s = 0.0;
    for (R_xlen_t i = k; i < n - k; ++i) s += v[static_cast<std::size_t>(i)];
    return s / static_cast<double>(n - 2 * k);
}

/* Winsorized mean: the same tails are pulled in to the surviving
 * extremes rather than discarded, so every observation still counts. */
double rmbl_winsorized_mean(const double *a, R_xlen_t n, double trim) {
    if (n < 1 || has_nan(a, n)) return std::nan("");
    if (!(trim >= 0.0) || trim > 0.5) return std::nan("");
    std::vector<double> v(a, a + n);
    std::sort(v.begin(), v.end());
    const R_xlen_t k = static_cast<R_xlen_t>(std::floor(static_cast<double>(n) * trim));
    if (2 * k >= n) return median_sorted(v);
    const double lo = v[static_cast<std::size_t>(k)];
    const double hi = v[static_cast<std::size_t>(n - k - 1)];
    double s = 0.0;
    for (R_xlen_t i = 0; i < n; ++i) {
        double z = v[static_cast<std::size_t>(i)];
        if (z < lo) z = lo;
        if (z > hi) z = hi;
        s += z;
    }
    return s / static_cast<double>(n);
}

double rmbl_weighted_mean(const double *a, const double *w, R_xlen_t n) {
    if (n < 1 || has_nan(a, n) || has_nan(w, n)) return std::nan("");
    double sw = 0.0, s = 0.0;
    for (R_xlen_t i = 0; i < n; ++i) {
        sw += w[i];
        s += w[i] * a[i];
    }
    if (sw == 0.0) return std::nan("");
    return s / sw;
}

/* Reliability weights: the unbiased estimator with the sum-of-weights
 * denominator corrected by the sum of squared weights. */
double rmbl_weighted_var(const double *a, const double *w, R_xlen_t n) {
    if (n < 2 || has_nan(a, n) || has_nan(w, n)) return std::nan("");
    double sw = 0.0, sw2 = 0.0;
    for (R_xlen_t i = 0; i < n; ++i) {
        sw += w[i];
        sw2 += w[i] * w[i];
    }
    if (sw <= 0.0 || sw * sw == sw2) return std::nan("");
    const double m = rmbl_weighted_mean(a, w, n);
    double s = 0.0;
    for (R_xlen_t i = 0; i < n; ++i) {
        const double d = a[i] - m;
        s += w[i] * d * d;
    }
    return s / (sw - sw2 / sw);
}

/* Spearman's rho: Pearson correlation of the midranks, so ties are
 * handled the way stats::cor(method = "spearman") handles them. */
double rmbl_cor_spearman(const double *x, const double *y, R_xlen_t n) {
    if (n < 2 || has_nan(x, n) || has_nan(y, n)) return std::nan("");
    std::vector<double> rx(static_cast<std::size_t>(n));
    std::vector<double> ry(static_cast<std::size_t>(n));
    midranks(x, n, rx.data());
    midranks(y, n, ry.data());
    double sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0;
    for (R_xlen_t i = 0; i < n; ++i) {
        const double a = rx[static_cast<std::size_t>(i)];
        const double b = ry[static_cast<std::size_t>(i)];
        sx += a;
        sy += b;
        sxx += a * a;
        syy += b * b;
        sxy += a * b;
    }
    const double dn = static_cast<double>(n);
    const double num = dn * sxy - sx * sy;
    const double den = (dn * sxx - sx * sx) * (dn * syy - sy * sy);
    if (den <= 0.0) return std::nan("");
    return num / std::sqrt(den);
}

void rmbl_midranks(const double *a, R_xlen_t n, double *out) {
    if (n < 1) return;
    midranks(a, n, out);
}

/* Column covariance matrix (n - 1 denominator), column-major in and out. */
void rmbl_cov_matrix(const double *x, R_xlen_t n, R_xlen_t p, double *out) {
    if (n < 2) {
        for (R_xlen_t k = 0; k < p * p; ++k) out[k] = std::nan("");
        return;
    }
    std::vector<double> mu(static_cast<std::size_t>(p), 0.0);
    for (R_xlen_t j = 0; j < p; ++j) {
        double s = 0.0;
        for (R_xlen_t i = 0; i < n; ++i) s += x[j * n + i];
        mu[static_cast<std::size_t>(j)] = s / static_cast<double>(n);
    }
    for (R_xlen_t j = 0; j < p; ++j) {
        for (R_xlen_t k = j; k < p; ++k) {
            double s = 0.0;
            for (R_xlen_t i = 0; i < n; ++i) {
                s += (x[j * n + i] - mu[static_cast<std::size_t>(j)]) *
                     (x[k * n + i] - mu[static_cast<std::size_t>(k)]);
            }
            const double v = s / (static_cast<double>(n) - 1.0);
            out[k * p + j] = v;
            out[j * p + k] = v;
        }
    }
}

/* Two-sample Kolmogorov-Smirnov statistic: the largest vertical gap
 * between the two empirical distribution functions. */
double rmbl_ks_two_sample(const double *x, R_xlen_t nx,
                          const double *y, R_xlen_t ny) {
    if (nx < 1 || ny < 1 || has_nan(x, nx) || has_nan(y, ny)) {
        return std::nan("");
    }
    std::vector<double> a(x, x + nx), b(y, y + ny);
    std::sort(a.begin(), a.end());
    std::sort(b.begin(), b.end());
    R_xlen_t i = 0, j = 0;
    double d = 0.0;
    while (i < nx && j < ny) {
        const double v = std::min(a[static_cast<std::size_t>(i)],
                                  b[static_cast<std::size_t>(j)]);
        while (i < nx && a[static_cast<std::size_t>(i)] == v) ++i;
        while (j < ny && b[static_cast<std::size_t>(j)] == v) ++j;
        const double gap = std::fabs(static_cast<double>(i) / static_cast<double>(nx) -
                                     static_cast<double>(j) / static_cast<double>(ny));
        if (gap > d) d = gap;
    }
    return d;
}

/* Asymptotic two-sided KS p-value: the Kolmogorov distribution tail
 * 2 sum_{k>=1} (-1)^(k-1) exp(-2 k^2 t^2). */
double rmbl_ks_pvalue(double d, double n_eff) {
    if (!(d > 0.0) || !(n_eff > 0.0)) return 1.0;
    const double t = std::sqrt(n_eff) * d;
    if (t < 1e-12) return 1.0;
    double s = 0.0;
    for (int k = 1; k <= 200; ++k) {
        const double term = std::exp(-2.0 * static_cast<double>(k) *
                                     static_cast<double>(k) * t * t);
        s += ((k % 2 == 1) ? 1.0 : -1.0) * term;
        if (term < 1e-16) break;
    }
    double p = 2.0 * s;
    if (p < 0.0) p = 0.0;
    if (p > 1.0) p = 1.0;
    return p;
}

/* Population stability index over shared bin proportions, and the
 * Jensen-Shannon divergence of the same two discrete distributions.
 * Both take already-normalised proportions; zero cells are floored at
 * `eps` so a missing category does not send the index to infinity. */
double rmbl_psi(const double *p, const double *q, R_xlen_t k, double eps) {
    if (k < 1) return std::nan("");
    double s = 0.0;
    for (R_xlen_t i = 0; i < k; ++i) {
        const double a = (p[i] > eps) ? p[i] : eps;
        const double b = (q[i] > eps) ? q[i] : eps;
        s += (a - b) * std::log(a / b);
    }
    return s;
}

double rmbl_js_divergence(const double *p, const double *q, R_xlen_t k) {
    if (k < 1) return std::nan("");
    double s = 0.0;
    for (R_xlen_t i = 0; i < k; ++i) {
        const double a = p[i], b = q[i];
        const double m = 0.5 * (a + b);
        if (a > 0.0) s += 0.5 * a * std::log(a / m);
        if (b > 0.0) s += 0.5 * b * std::log(b / m);
    }
    if (s < 0.0) s = 0.0;
    return s;
}

/* Leading significant decimal digit of |x|, or 0 when there is none. */
int rmbl_first_digit(double x) {
    if (!std::isfinite(x)) return 0;
    double v = std::fabs(x);
    if (v == 0.0) return 0;
    while (v < 1.0) v *= 10.0;
    while (v >= 10.0) v /= 10.0;
    int d = static_cast<int>(v);
    if (d < 1) d = 1;
    if (d > 9) d = 9;
    return d;
}

void rmbl_first_digit_counts(const double *a, R_xlen_t n, double *out) {
    for (int d = 0; d < 9; ++d) out[d] = 0.0;
    for (R_xlen_t i = 0; i < n; ++i) {
        const int d = rmbl_first_digit(a[i]);
        if (d >= 1 && d <= 9) out[d - 1] += 1.0;
    }
}

/* ---------------------------------------------------------------- */
/* .Call wrappers                                                    */
/* ---------------------------------------------------------------- */

SEXP C_rmbl_moments(SEXP x) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    SEXP out = PROTECT(Rf_allocVector(REALSXP, 4));
    rmbl_moments(REAL(x), XLENGTH(x), REAL(out));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 4));
    SET_STRING_ELT(nm, 0, Rf_mkChar("mean"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("variance"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("skewness"));
    SET_STRING_ELT(nm, 3, Rf_mkChar("kurtosis"));
    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(3);
    return out;
}

SEXP C_rmbl_quantile(SEXP x, SEXP probs) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    probs = PROTECT(Rf_coerceVector(probs, REALSXP));
    R_xlen_t np = XLENGTH(probs);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, np));
    rmbl_quantile(REAL(x), XLENGTH(x), REAL(probs), np, REAL(out));
    UNPROTECT(3);
    return out;
}

SEXP C_rmbl_median(SEXP x) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    double r = rmbl_median(REAL(x), XLENGTH(x));
    UNPROTECT(1);
    return Rf_ScalarReal(r);
}

SEXP C_rmbl_mad(SEXP x, SEXP constant) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    double r = rmbl_mad(REAL(x), XLENGTH(x), Rf_asReal(constant));
    UNPROTECT(1);
    return Rf_ScalarReal(r);
}

SEXP C_rmbl_trimmed_mean(SEXP x, SEXP trim) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    double r = rmbl_trimmed_mean(REAL(x), XLENGTH(x), Rf_asReal(trim));
    UNPROTECT(1);
    return Rf_ScalarReal(r);
}

SEXP C_rmbl_winsorized_mean(SEXP x, SEXP trim) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    double r = rmbl_winsorized_mean(REAL(x), XLENGTH(x), Rf_asReal(trim));
    UNPROTECT(1);
    return Rf_ScalarReal(r);
}

SEXP C_rmbl_weighted(SEXP x, SEXP w) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    w = PROTECT(Rf_coerceVector(w, REALSXP));
    R_xlen_t n = XLENGTH(x);
    if (XLENGTH(w) != n) {
        UNPROTECT(2);
        Rf_error("`x` and `w` must have the same length");
    }
    SEXP out = PROTECT(Rf_allocVector(REALSXP, 2));
    REAL(out)[0] = rmbl_weighted_mean(REAL(x), REAL(w), n);
    REAL(out)[1] = rmbl_weighted_var(REAL(x), REAL(w), n);
    UNPROTECT(3);
    return out;
}

SEXP C_rmbl_cor_spearman(SEXP x, SEXP y) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    y = PROTECT(Rf_coerceVector(y, REALSXP));
    if (XLENGTH(x) != XLENGTH(y)) {
        UNPROTECT(2);
        Rf_error("`x` and `y` must have the same length");
    }
    double r = rmbl_cor_spearman(REAL(x), REAL(y), XLENGTH(x));
    UNPROTECT(2);
    return Rf_ScalarReal(r);
}

SEXP C_rmbl_midranks(SEXP x) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    R_xlen_t n = XLENGTH(x);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    rmbl_midranks(REAL(x), n, REAL(out));
    UNPROTECT(2);
    return out;
}

SEXP C_rmbl_cov_matrix(SEXP x) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    SEXP dim = Rf_getAttrib(x, R_DimSymbol);
    if (dim == R_NilValue || XLENGTH(dim) != 2) {
        UNPROTECT(1);
        Rf_error("`x` must be a matrix");
    }
    R_xlen_t n = INTEGER(dim)[0], p = INTEGER(dim)[1];
    SEXP out = PROTECT(Rf_allocMatrix(REALSXP, static_cast<int>(p),
                                      static_cast<int>(p)));
    rmbl_cov_matrix(REAL(x), n, p, REAL(out));
    UNPROTECT(2);
    return out;
}

SEXP C_rmbl_ks(SEXP x, SEXP y) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    y = PROTECT(Rf_coerceVector(y, REALSXP));
    R_xlen_t nx = XLENGTH(x), ny = XLENGTH(y);
    double d = rmbl_ks_two_sample(REAL(x), nx, REAL(y), ny);
    double ne = (nx > 0 && ny > 0)
        ? (static_cast<double>(nx) * static_cast<double>(ny)) /
          (static_cast<double>(nx) + static_cast<double>(ny))
        : 0.0;
    SEXP out = PROTECT(Rf_allocVector(REALSXP, 3));
    REAL(out)[0] = d;
    REAL(out)[1] = std::isnan(d) ? std::nan("") : rmbl_ks_pvalue(d, ne);
    REAL(out)[2] = ne;
    UNPROTECT(3);
    return out;
}

SEXP C_rmbl_psi(SEXP p, SEXP q, SEXP eps) {
    p = PROTECT(Rf_coerceVector(p, REALSXP));
    q = PROTECT(Rf_coerceVector(q, REALSXP));
    if (XLENGTH(p) != XLENGTH(q)) {
        UNPROTECT(2);
        Rf_error("`p` and `q` must have the same length");
    }
    SEXP out = PROTECT(Rf_allocVector(REALSXP, 2));
    REAL(out)[0] = rmbl_psi(REAL(p), REAL(q), XLENGTH(p), Rf_asReal(eps));
    REAL(out)[1] = rmbl_js_divergence(REAL(p), REAL(q), XLENGTH(p));
    UNPROTECT(3);
    return out;
}

SEXP C_rmbl_first_digit_counts(SEXP x) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    SEXP out = PROTECT(Rf_allocVector(REALSXP, 9));
    rmbl_first_digit_counts(REAL(x), XLENGTH(x), REAL(out));
    UNPROTECT(2);
    return out;
}

}  // extern "C"
