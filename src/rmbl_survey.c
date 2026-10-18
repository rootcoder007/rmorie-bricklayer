/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Replicate totals for design-based survey estimation: for every replicate
 * weight column w_r and every analysis column y_j, t[r, j] = sum_i w_r[i] y_j[i].
 * The replicate weights are read straight from the list of columns the data
 * frame already holds (CSUS 2023: 1,000 columns of 36,180 rows), so they are
 * never copied into an n x R matrix; the analysis columns arrive as one n x k
 * matrix. Every buffer is R-allocated and PROTECTed, so the interrupt test
 * between replicates can stop and raise with nothing to free by hand.
 */
#include <R.h>
#include <Rinternals.h>

#include <limits.h>
#include <math.h>
#include <string.h>

int rmbl_interrupt_pending(void);
void rmbl_interrupt_raise_unbarriered(void);
void rmbl_sha256_hex(const unsigned char *, size_t, char *);

/* The row key of a double column, value by value: its two 32-bit halves folded modulo 2^31 - 1, the
 * arithmetic .svy_rowkey_digests() did in R (the same doubles, so the same keys), without the copies
 * that cost: writeBin(), readBin() and four vectors as long as the column, 1.1 GB of transients for a
 * check of two columns at 5e6 rows (CRAN stress test of 0.5.14, #8). */
static double rmbl_fold(double x) { return x - 2147483647.0 * floor(x / 2147483647.0); }

SEXP C_rmbl_svy_dblcode(SEXP v) {
    if (TYPEOF(v) != REALSXP) error("`v` must be a double vector");
    const R_xlen_t n = XLENGTH(v);
    SEXP out = PROTECT(allocVector(REALSXP, n));
    const double *x = REAL(v);
    double *o = REAL(out);
    for (R_xlen_t i = 0; i < n; i++) {
        int b[2];
        memcpy(b, x + i, sizeof b);   /* native order, as readBin(writeBin(v, raw()), "integer") read it */
        /* readBin() read a half of 0x80000000 (the sign bit of -0, for one) as NA_integer_, and the key
         * was NA: kept, so a design's stored keys are the ones it is checked against */
        if (b[0] == INT_MIN || b[1] == INT_MIN) {
            o[i] = NA_REAL;
            continue;
        }
        o[i] = rmbl_fold(rmbl_fold((double) b[0]) * 65599.0 + (double) b[1]);
    }
    UNPROTECT(1);
    return out;
}

/* SHA-256 of a double vector's bytes, as core_sha256(writeBin(x, raw())) gives it, without the copy */
SEXP C_rmbl_sha256_real(SEXP x) {
    if (TYPEOF(x) != REALSXP) error("`x` must be a double vector");
    char hex[65];
    rmbl_sha256_hex((const unsigned char *) REAL(x), (size_t) XLENGTH(x) * sizeof(double), hex);
    hex[64] = '\0';
    return mkString(hex);
}

SEXP C_rmbl_svy_reptotals(SEXP y, SEXP reps) {
    if (!isReal(y) || !isMatrix(y)) Rf_error("`y` must be a double matrix");
    if (TYPEOF(reps) != VECSXP) Rf_error("`reps` must be a list of replicate weight columns");
    SEXP dim = getAttrib(y, R_DimSymbol);
    R_xlen_t n = INTEGER(dim)[0];
    int k = INTEGER(dim)[1];
    R_xlen_t nr = XLENGTH(reps);
    if (nr > INT_MAX) Rf_error("too many replicate weight columns");
    for (R_xlen_t r = 0; r < nr; r++) {
        SEXP w = VECTOR_ELT(reps, r);
        if (!isReal(w) || XLENGTH(w) != n)
            Rf_error("replicate weight column %d must be a double vector of length %lld", (int) r + 1,
                     (long long) n);
    }
    SEXP out = PROTECT(allocMatrix(REALSXP, (int) nr, k));
    double *o = REAL(out);
    const double *yy = REAL(y);
    for (R_xlen_t r = 0; r < nr; r++) {
        if (rmbl_interrupt_pending()) {
            UNPROTECT(1);
            rmbl_interrupt_raise_unbarriered();
            Rf_error("interrupted");   /* not reached when R raises the interrupt */
        }
        const double *w = REAL(VECTOR_ELT(reps, r));
        for (int j = 0; j < k; j++) {
            const double *col = yy + (R_xlen_t) j * n;
            double s = 0.0;
            for (R_xlen_t i = 0; i < n; i++) s += w[i] * col[i];
            o[r + (R_xlen_t) j * nr] = s;
        }
    }
    UNPROTECT(1);
    return out;
}
