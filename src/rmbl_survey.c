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

int rmbl_interrupt_pending(void);
void rmbl_interrupt_raise_unbarriered(void);

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
