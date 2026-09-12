/* Concentration and short-series trend kernels.
 *
 * These are the statistics that a published administrative table needs
 * and that a long-series time-series toolkit does not supply. An annual
 * open-data extract is five to ten points: an ARIMA fitted to it is
 * arithmetic without meaning, whereas a rank-based trend test and a
 * median-of-slopes estimator say exactly as much as five points can
 * support.
 *
 * Theil-Sen and the permutation scan are here rather than in R because
 * both are quadratic or worse in the series length and the permutation
 * null needs thousands of replicates; the concentration measures are
 * here so a table with millions of rows does not pay for an R-level
 * sort per call.
 */

/* The C++ standard headers come FIRST. R's Rinternals.h defines a macro
 * named `length`, and libc++'s <locale> -- which <functional> pulls in --
 * has member functions of that name, so including the R headers first
 * makes the macro rewrite them and the build fails on macOS with "too
 * many arguments provided to function-like macro invocation". <functional>
 * is not needed here either way; std::greater is replaced by a comparator
 * below. */
#include <algorithm>
#include <cmath>
#include <utility>
#include <vector>

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Random.h>

namespace {

/* Gini, from the sorted values.
 *
 *   G = (2 * sum_i i * x_(i) - (n + 1) * sum x) / (n * sum x)
 *
 * which is the mean absolute difference over twice the mean, arranged so
 * that one pass over the sorted data does it. Undefined when the total
 * is zero: there is no distribution of nothing to be unequal about.
 */
double gini_sorted(std::vector<double> &v) {
    const size_t n = v.size();
    if (n == 0) return NA_REAL;
    std::sort(v.begin(), v.end());
    long double total = 0.0L;
    long double weighted = 0.0L;
    for (size_t i = 0; i < n; ++i) {
        total += v[i];
        weighted += static_cast<long double>(i + 1) * v[i];
    }
    if (total <= 0.0L) return NA_REAL;
    const long double nn = static_cast<long double>(n);
    return static_cast<double>(
        (2.0L * weighted - (nn + 1.0L) * total) / (nn * total));
}

/* Finite, non-negative values only. A negative value has no place in a
 * concentration measure built on shares of a total, and silently
 * treating one as zero would understate the concentration. */
bool collect(SEXP x, std::vector<double> &out, bool *saw_negative) {
    const R_xlen_t n = XLENGTH(x);
    const double *p = REAL(x);
    *saw_negative = false;
    out.clear();
    out.reserve(static_cast<size_t>(n));
    for (R_xlen_t i = 0; i < n; ++i) {
        if (ISNA(p[i]) || ISNAN(p[i]) || !R_FINITE(p[i])) continue;
        if (p[i] < 0) { *saw_negative = true; return false; }
        out.push_back(p[i]);
    }
    return true;
}

}  // namespace

extern "C" {

SEXP C_rmbl_gini(SEXP x) {
    std::vector<double> v;
    bool neg = false;
    if (!collect(x, v, &neg)) {
        Rf_error("concentration measures need non-negative values");
    }
    return Rf_ScalarReal(gini_sorted(v));
}

/* Lorenz curve: the cumulative share of the total held by the smallest
 * p of the units, including the (0, 0) origin so the curve can be
 * plotted and integrated as it stands. */
SEXP C_rmbl_lorenz(SEXP x) {
    std::vector<double> v;
    bool neg = false;
    if (!collect(x, v, &neg)) {
        Rf_error("concentration measures need non-negative values");
    }
    const size_t n = v.size();
    std::sort(v.begin(), v.end());
    long double total = 0.0L;
    for (size_t i = 0; i < n; ++i) total += v[i];
    SEXP pop = PROTECT(Rf_allocVector(REALSXP, static_cast<R_xlen_t>(n) + 1));
    SEXP val = PROTECT(Rf_allocVector(REALSXP, static_cast<R_xlen_t>(n) + 1));
    REAL(pop)[0] = 0.0;
    REAL(val)[0] = 0.0;
    long double run = 0.0L;
    for (size_t i = 0; i < n; ++i) {
        run += v[i];
        REAL(pop)[i + 1] = static_cast<double>(i + 1) /
                           static_cast<double>(n);
        REAL(val)[i + 1] = total > 0.0L
            ? static_cast<double>(run / total) : NA_REAL;
    }
    SEXP res = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(res, 0, pop);
    SET_VECTOR_ELT(res, 1, val);
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(nm, 0, Rf_mkChar("population"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("value"));
    Rf_setAttrib(res, R_NamesSymbol, nm);
    UNPROTECT(4);
    return res;
}

/* Share of the total held by the largest `frac` of the units.
 *
 * The count of units taken is ceil(frac * n), so "the top 10%" of 25
 * units is 3 units rather than 2.5 of them. Reporting which count was
 * used is the caller's business; the fraction alone is not enough to
 * reconstruct it. */
SEXP C_rmbl_top_share(SEXP x, SEXP fracs) {
    std::vector<double> v;
    bool neg = false;
    if (!collect(x, v, &neg)) {
        Rf_error("concentration measures need non-negative values");
    }
    const size_t n = v.size();
    std::sort(v.begin(), v.end(),
              [](double a, double b) { return a > b; });
    long double total = 0.0L;
    for (size_t i = 0; i < n; ++i) total += v[i];
    const R_xlen_t m = XLENGTH(fracs);
    const double *f = REAL(fracs);
    SEXP share = PROTECT(Rf_allocVector(REALSXP, m));
    SEXP took = PROTECT(Rf_allocVector(INTSXP, m));
    for (R_xlen_t j = 0; j < m; ++j) {
        if (n == 0 || total <= 0.0L || ISNAN(f[j]) || f[j] < 0 || f[j] > 1) {
            REAL(share)[j] = NA_REAL;
            INTEGER(took)[j] = NA_INTEGER;
            continue;
        }
        size_t k = static_cast<size_t>(
            std::ceil(f[j] * static_cast<double>(n) - 1e-9));
        if (k > n) k = n;
        long double run = 0.0L;
        for (size_t i = 0; i < k; ++i) run += v[i];
        REAL(share)[j] = static_cast<double>(run / total);
        INTEGER(took)[j] = static_cast<int>(k);
    }
    SEXP res = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(res, 0, share);
    SET_VECTOR_ELT(res, 1, took);
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(nm, 0, Rf_mkChar("share"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("units"));
    Rf_setAttrib(res, R_NamesSymbol, nm);
    UNPROTECT(4);
    return res;
}

/* Mann-Kendall S and its variance, with the tie correction.
 *
 *   S = sum over i < j of sign(y_j - y_i)
 *   Var(S) = [n(n-1)(2n+5) - sum_t t(t-1)(2t+5)] / 18
 *
 * where t runs over the sizes of the groups of tied values. Dropping the
 * tie term overstates the variance's shrinkage and so overstates
 * significance, which matters most on exactly the short integer series
 * this is for. */
SEXP C_rmbl_mann_kendall(SEXP y) {
    const R_xlen_t n = XLENGTH(y);
    const double *p = REAL(y);
    std::vector<double> v;
    v.reserve(static_cast<size_t>(n));
    for (R_xlen_t i = 0; i < n; ++i) {
        if (!ISNAN(p[i]) && R_FINITE(p[i])) v.push_back(p[i]);
    }
    const R_xlen_t m = static_cast<R_xlen_t>(v.size());
    double s = 0.0;
    for (R_xlen_t i = 0; i + 1 < m; ++i) {
        for (R_xlen_t j = i + 1; j < m; ++j) {
            const double d = v[static_cast<size_t>(j)] -
                             v[static_cast<size_t>(i)];
            if (d > 0) s += 1.0; else if (d < 0) s -= 1.0;
        }
    }
    std::vector<double> sorted(v);
    std::sort(sorted.begin(), sorted.end());
    long double tiesum = 0.0L;
    R_xlen_t i = 0;
    while (i < m) {
        R_xlen_t j = i;
        while (j + 1 < m &&
               sorted[static_cast<size_t>(j + 1)] ==
                 sorted[static_cast<size_t>(i)]) ++j;
        const long double t = static_cast<long double>(j - i + 1);
        if (t > 1.0L) tiesum += t * (t - 1.0L) * (2.0L * t + 5.0L);
        i = j + 1;
    }
    const long double nn = static_cast<long double>(m);
    const double var = m < 2 ? NA_REAL : static_cast<double>(
        (nn * (nn - 1.0L) * (2.0L * nn + 5.0L) - tiesum) / 18.0L);
    SEXP res = PROTECT(Rf_allocVector(VECSXP, 3));
    SET_VECTOR_ELT(res, 0, Rf_ScalarReal(m < 2 ? NA_REAL : s));
    SET_VECTOR_ELT(res, 1, Rf_ScalarReal(var));
    SET_VECTOR_ELT(res, 2, Rf_ScalarInteger(static_cast<int>(m)));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(nm, 0, Rf_mkChar("S"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("var"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("n"));
    Rf_setAttrib(res, R_NamesSymbol, nm);
    UNPROTECT(2);
    return res;
}

/* Theil-Sen: the median of the pairwise slopes, and the intercept that
 * puts the line through the median residual. Quadratic in n, which is
 * why it is here, and resistant to a single aberrant period, which is
 * why it is preferred to least squares on a five-point series. */
SEXP C_rmbl_theil_sen(SEXP x, SEXP y) {
    const R_xlen_t n = XLENGTH(x);
    const double *px = REAL(x);
    const double *py = REAL(y);
    std::vector<double> xs;
    std::vector<double> ys;
    for (R_xlen_t i = 0; i < n; ++i) {
        if (ISNAN(px[i]) || ISNAN(py[i]) ||
            !R_FINITE(px[i]) || !R_FINITE(py[i])) continue;
        xs.push_back(px[i]);
        ys.push_back(py[i]);
    }
    const size_t m = xs.size();
    std::vector<double> slopes;
    slopes.reserve(m * (m > 0 ? m - 1 : 0) / 2);
    for (size_t i = 0; i + 1 < m; ++i) {
        for (size_t j = i + 1; j < m; ++j) {
            const double dx = xs[j] - xs[i];
            /* a pair sharing an x contributes no slope, rather than an
             * infinite one */
            if (dx == 0.0) continue;
            slopes.push_back((ys[j] - ys[i]) / dx);
        }
    }
    double slope = NA_REAL;
    double intercept = NA_REAL;
    if (!slopes.empty()) {
        const size_t k = slopes.size();
        std::nth_element(slopes.begin(), slopes.begin() + k / 2,
                         slopes.end());
        if (k % 2 == 1) {
            slope = slopes[k / 2];
        } else {
            const double hi = slopes[k / 2];
            double lo = -R_PosInf;
            for (size_t i = 0; i < k / 2; ++i) {
                if (slopes[i] > lo) lo = slopes[i];
            }
            slope = 0.5 * (lo + hi);
        }
        std::vector<double> resid(m);
        for (size_t i = 0; i < m; ++i) resid[i] = ys[i] - slope * xs[i];
        std::nth_element(resid.begin(), resid.begin() + m / 2, resid.end());
        if (m % 2 == 1) {
            intercept = resid[m / 2];
        } else {
            const double hi = resid[m / 2];
            double lo = -R_PosInf;
            for (size_t i = 0; i < m / 2; ++i) {
                if (resid[i] > lo) lo = resid[i];
            }
            intercept = 0.5 * (lo + hi);
        }
    }
    SEXP res = PROTECT(Rf_allocVector(VECSXP, 3));
    SET_VECTOR_ELT(res, 0, Rf_ScalarReal(slope));
    SET_VECTOR_ELT(res, 1, Rf_ScalarReal(intercept));
    SET_VECTOR_ELT(res, 2, Rf_ScalarReal(
        static_cast<double>(slopes.size())));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(nm, 0, Rf_mkChar("slope"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("intercept"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("pairs"));
    Rf_setAttrib(res, R_NamesSymbol, nm);
    UNPROTECT(2);
    return res;
}

/* Hurwitz zeta, zeta(s, q) = sum_{k>=0} (q + k)^-s, by Euler-Maclaurin.
 *
 * This is the normalising constant of the discrete power law (the zeta
 * distribution truncated below at q), and it is needed because the
 * continuity-corrected Hill estimator -- which is what the literature's
 * closed form gives -- is only a good approximation for a LARGE lower
 * threshold. At a threshold of one, where administrative counts
 * actually start, it recovers 2.0 from data generated with an exponent
 * of 2.5. Maximising the exact likelihood needs this function, so it is
 * computed properly rather than by truncating the sum.
 *
 * Direct terms up to q + N, then the integral tail, then the
 * Bernoulli-number corrections. N = 16 with six correction terms is
 * good to near machine precision for s > 1.
 */
SEXP C_rmbl_hurwitz_zeta(SEXP s_, SEXP q_) {
    const R_xlen_t n = XLENGTH(s_);
    const double *sv = REAL(s_);
    const double q = Rf_asReal(q_);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    /* B_2j / (2j)!, written as the quotient of the two so each entry
     * can be read against a table rather than trusted as a decimal */
    static const double bfac[6] = {
        (1.0 / 6.0) / 2.0,              /* B2  =  1/6     , 2!  */
        (-1.0 / 30.0) / 24.0,           /* B4  = -1/30    , 4!  */
        (1.0 / 42.0) / 720.0,           /* B6  =  1/42    , 6!  */
        (-1.0 / 30.0) / 40320.0,        /* B8  = -1/30    , 8!  */
        (5.0 / 66.0) / 3628800.0,       /* B10 =  5/66    , 10! */
        (-691.0 / 2730.0) / 479001600.0 /* B12 = -691/2730, 12! */
    };
    const int N = 16;
    for (R_xlen_t i = 0; i < n; ++i) {
        const double s = sv[i];
        if (ISNAN(s) || s <= 1.0 || q <= 0.0) {
            REAL(out)[i] = NA_REAL;
            continue;
        }
        long double acc = 0.0L;
        for (int k = 0; k < N; ++k) {
            acc += std::pow(static_cast<long double>(q + k), -s);
        }
        const long double a = static_cast<long double>(q + N);
        acc += std::pow(a, 1.0L - s) / (s - 1.0L);
        acc += 0.5L * std::pow(a, -s);
        /* sum_j coef_j * (s)_{2j-1} * a^{-s-2j+1} */
        long double poch = s;             /* (s)_1 */
        for (int j = 1; j <= 6; ++j) {
            acc += bfac[j - 1] * poch *
                   std::pow(a, -s - 2.0L * j + 1.0L);
            /* advance (s)_{2j-1} to (s)_{2j+1} */
            poch *= (s + 2.0L * j - 1.0L) * (s + 2.0L * j);
        }
        REAL(out)[i] = static_cast<double>(acc);
    }
    UNPROTECT(1);
    return out;
}

/* Global Moran's I over a neighbour list, with a permutation null.
 *
 *   I = (n / W) * sum_ij w_ij z_i z_j / sum_i z_i^2,  z = x - mean(x)
 *
 * The neighbour list arrives flattened -- `idx` holds the 0-based
 * neighbours of every area end to end, `start` and `len` say where each
 * area's block begins and how long it is, and `wts` holds the matching
 * weights -- because an areal dataset is sparse and a dense n-by-n
 * matrix is the wrong shape for it.
 *
 * The permutation loop is here rather than in R because it is the inner
 * loop: thousands of reassignments of the values over the areas, each
 * re-walking the whole neighbour list.
 */
SEXP C_rmbl_morans_i(SEXP x_, SEXP idx_, SEXP start_, SEXP len_,
                     SEXP wts_, SEXP nperm_, SEXP seed_) {
    const R_xlen_t n = XLENGTH(x_);
    const double *x = REAL(x_);
    const int *idx = INTEGER(idx_);
    const int *start = INTEGER(start_);
    const int *len = INTEGER(len_);
    const double *wts = REAL(wts_);
    const R_xlen_t nperm = static_cast<R_xlen_t>(Rf_asInteger(nperm_));

    if (n < 3) Rf_error("Moran's I needs at least three areas");

    long double total = 0.0L;
    for (R_xlen_t i = 0; i < n; ++i) {
        if (ISNAN(x[i])) Rf_error("`x` must not contain missing values");
        total += x[i];
    }
    const double mean = static_cast<double>(total / n);
    std::vector<double> z(static_cast<size_t>(n));
    long double ss = 0.0L;
    for (R_xlen_t i = 0; i < n; ++i) {
        z[static_cast<size_t>(i)] = x[i] - mean;
        ss += z[static_cast<size_t>(i)] * z[static_cast<size_t>(i)];
    }
    long double wsum = 0.0L;
    for (R_xlen_t i = 0; i < n; ++i) {
        for (int k = 0; k < len[i]; ++k) wsum += wts[start[i] + k];
    }
    if (ss <= 0.0L || wsum <= 0.0L) {
        SEXP out = PROTECT(Rf_allocVector(VECSXP, 4));
        SET_VECTOR_ELT(out, 0, Rf_ScalarReal(NA_REAL));
        SET_VECTOR_ELT(out, 1, Rf_ScalarReal(NA_REAL));
        SET_VECTOR_ELT(out, 2, Rf_ScalarReal(static_cast<double>(wsum)));
        SET_VECTOR_ELT(out, 3, Rf_allocVector(REALSXP, 0));
        SEXP nm = PROTECT(Rf_allocVector(STRSXP, 4));
        SET_STRING_ELT(nm, 0, Rf_mkChar("I"));
        SET_STRING_ELT(nm, 1, Rf_mkChar("cross"));
        SET_STRING_ELT(nm, 2, Rf_mkChar("W"));
        SET_STRING_ELT(nm, 3, Rf_mkChar("null"));
        Rf_setAttrib(out, R_NamesSymbol, nm);
        UNPROTECT(2);
        return out;
    }

    /* the lagged cross-product, sum_ij w_ij z_i z_j */
    auto cross_of = [&](const std::vector<double> &v) {
        long double acc = 0.0L;
        for (R_xlen_t i = 0; i < n; ++i) {
            const double zi = v[static_cast<size_t>(i)];
            for (int k = 0; k < len[i]; ++k) {
                acc += wts[start[i] + k] *
                       zi * v[static_cast<size_t>(idx[start[i] + k])];
            }
        }
        return acc;
    };
    const long double cross = cross_of(z);
    const double I = static_cast<double>(
        (static_cast<long double>(n) / wsum) * cross / ss);

    SEXP null = PROTECT(Rf_allocVector(REALSXP, nperm));
    if (nperm > 0) {
        /* R's own stream, so set.seed() in the caller governs it and the
         * p-value is reproducible */
        GetRNGstate();
        std::vector<double> p(z);
        for (R_xlen_t b = 0; b < nperm; ++b) {
            /* Fisher-Yates over the centred values: the null is that the
             * values are assigned to areas at random, so the sum of
             * squares is invariant and only the cross-product moves */
            for (R_xlen_t i = n - 1; i > 0; --i) {
                const R_xlen_t j = static_cast<R_xlen_t>(
                    unif_rand() * static_cast<double>(i + 1));
                std::swap(p[static_cast<size_t>(i)],
                          p[static_cast<size_t>(j < 0 ? 0 : j)]);
            }
            REAL(null)[b] = static_cast<double>(
                (static_cast<long double>(n) / wsum) * cross_of(p) / ss);
        }
        PutRNGstate();
    }
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 4));
    SET_VECTOR_ELT(out, 0, Rf_ScalarReal(I));
    SET_VECTOR_ELT(out, 1, Rf_ScalarReal(static_cast<double>(cross)));
    SET_VECTOR_ELT(out, 2, Rf_ScalarReal(static_cast<double>(wsum)));
    SET_VECTOR_ELT(out, 3, null);
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 4));
    SET_STRING_ELT(nm, 0, Rf_mkChar("I"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("cross"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("W"));
    SET_STRING_ELT(nm, 3, Rf_mkChar("null"));
    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(3);
    return out;
}

}  // extern "C"
