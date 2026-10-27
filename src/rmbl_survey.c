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

#include <float.h>
#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
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
        /* the value, not its bits: -0 is 0 (round(-0.3) is -0, and its sign-bit half read as
         * NA_integer_ gave the row an NA key that wiped the other columns' contribution, so reorders
         * among such rows went undetected; final audit of 1.0.0, #3b), and every NaN payload, NA
         * among them, is one value (the R path wrote NA with one payload and the C path another, so
         * a design saved with NA in a double column lost that column in the check) */
        double xi = x[i];
        if (xi == 0.0) xi = 0.0;
        if (ISNAN(xi)) xi = NA_REAL;
        memcpy(b, &xi, sizeof b);   /* native order, as readBin(writeBin(v, raw()), "integer") read it */
        o[i] = rmbl_fold(rmbl_fold((double) b[0]) * 65599.0 + (double) b[1]);
    }
    UNPROTECT(1);
    return out;
}

/* An order-independent digest of a double vector: the same multiset of values in any order gives
 * the same digest, as the SHA-256 of the sorted vector did, without the sort. sort() made a copy
 * as long as the column and a radix sort asks malloc() for working memory of that size again,
 * outside R's heap: with twenty-two columns of 5e6 rows under a 3 GB address-space limit that
 * request failed while R's garbage still held the space ("Failed to allocate working memory for
 * xtmp"; final audit of 1.0.0, #3). Each value's bits (-0 as 0, every NaN as NA, as the row keys
 * read them) are mixed by splitmix64 and summed modulo 2^64 under two seeds: 128 bits, so two
 * different multisets of values collide with probability about 2^-128. */
static uint64_t rmbl_mix64(uint64_t z) {
    z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ULL;
    z = (z ^ (z >> 27)) * 0x94d049bb133111ebULL;
    return z ^ (z >> 31);
}

SEXP C_rmbl_svy_msethash(SEXP x) {
    if (TYPEOF(x) != REALSXP) error("`x` must be a double vector");
    const R_xlen_t n = XLENGTH(x);
    const double *v = REAL(x);
    uint64_t a = 0, b = 0;
    for (R_xlen_t i = 0; i < n; i++) {
        double xi = v[i];
        if (xi == 0.0) xi = 0.0;
        if (ISNAN(xi)) xi = NA_REAL;
        uint64_t bits;
        memcpy(&bits, &xi, sizeof bits);
        a += rmbl_mix64(bits + 0x9e3779b97f4a7c15ULL);
        b += rmbl_mix64(bits ^ 0xd1b54a32d192ed03ULL);
    }
    char hex[33];
    snprintf(hex, sizeof hex, "%016llx%016llx", (unsigned long long) a, (unsigned long long) b);
    return mkString(hex);
}

/* One replicate column read against the weight in a single pass, with nothing allocated as long as
 * the column: whether it is the weight (every row within 1e-12 of it), how far off it is at most
 * (relative to the weight, floored at the smallest double), whether it zeroes a weighted row, whether
 * it is one value, whether it is `idv` (the id's values) or the row numbers (`rn`, the row names when
 * numeric, or 1..n), the factor r / w when every row kept carries one (within 1e-9), and the first
 * 4,096 rows kept (the rows the factor rules read). In R each of those was a vector as long as the
 * column, 340 MB live per column at 5e6 rows, and the 5e6 x 20 matrix design did not fit a 3 GB
 * address space (final audit of 1.0.0, #3). */
SEXP C_rmbl_svy_colsumm(SEXP r, SEXP w, SEXP idv, SEXP rn) {
    if (TYPEOF(r) != REALSXP || TYPEOF(w) != REALSXP || XLENGTH(r) != XLENGTH(w)) {
        error("`r` and `w` must be double vectors of one length");
    }
    const R_xlen_t n = XLENGTH(r);
    const double *x = REAL(r), *wv = REAL(w);
    const double *id = (idv != R_NilValue && TYPEOF(idv) == REALSXP && XLENGTH(idv) == n) ? REAL(idv) : NULL;
    const double *rv = (rn != R_NilValue && TYPEOF(rn) == REALSXP && XLENGTH(rn) == n) ? REAL(rn) : NULL;
    int same = 1, anyzero = 0, isid = id != NULL, isrow = 1, isrn = rv != NULL, facconst = 1;
    double maxrel = 0, rmin = R_PosInf, rmax = R_NegInf, q0 = NA_REAL;
    R_xlen_t nk = 0;
    int h[4096];
    for (R_xlen_t i = 0; i < n; i++) {
        const double ri = x[i], wi = wv[i];
        const double wp = wi > DBL_MIN ? wi : DBL_MIN;
        const double d = fabs(ri - wi);
        if (!(d < 1e-12 * wp)) same = 0;
        const double rel = d / wp;
        if (rel > maxrel || ISNAN(rel)) maxrel = ISNAN(rel) ? R_NaReal : rel;
        if (ri == 0 && wi > 0) anyzero = 1;
        if (ri < rmin) rmin = ri;
        if (ri > rmax) rmax = ri;
        if (isid && !(ri == id[i])) isid = 0;
        if (isrow && !(ri == (double) (i + 1))) isrow = 0;
        if (isrn && !(ri == rv[i])) isrn = 0;
        if (ri > 0 && wi > 0) {
            const double q = ri / wi;
            if (nk == 0) q0 = q;
            else if (facconst && !(fabs(q - q0) <= 1e-9 * fabs(q0))) facconst = 0;
            if (nk < 4096) h[nk] = (int) (i + 1);
            nk++;
        }
    }
    const R_xlen_t nh = nk < 4096 ? nk : 4096;
    SEXP hk = PROTECT(allocVector(INTSXP, nh));
    memcpy(INTEGER(hk), h, (size_t) nh * sizeof(int));
    const char *names[] = {"same", "maxrel", "anyzero", "const", "isid", "isrow", "fullfac", "hk", ""};
    SEXP out = PROTECT(mkNamed(VECSXP, names));
    SET_VECTOR_ELT(out, 0, ScalarLogical(same));
    SET_VECTOR_ELT(out, 1, ScalarReal(n ? maxrel : 0));
    SET_VECTOR_ELT(out, 2, ScalarLogical(anyzero));
    SET_VECTOR_ELT(out, 3, ScalarLogical(n > 0 && rmin == rmax));
    SET_VECTOR_ELT(out, 4, ScalarLogical(isid));
    SET_VECTOR_ELT(out, 5, ScalarLogical(isrow || isrn));
    SET_VECTOR_ELT(out, 6, ScalarReal(nk > 0 && facconst ? q0 : NA_REAL));
    SET_VECTOR_ELT(out, 7, hk);
    UNPROTECT(2);
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

/* `idx`: NULL, or the 1-based rows of the replicates that `y`'s rows stand for (a domain's rows
 * only: the n x k numerator and denominator matrices of a 50-domain estimate were the heap peak
 * of 1.9 GB at a million rows; final audit of 1.0.0) */
SEXP C_rmbl_svy_reptotals(SEXP y, SEXP reps, SEXP idx) {
    if (!isReal(y) || !isMatrix(y)) Rf_error("`y` must be a double matrix");
    SEXP dim = getAttrib(y, R_DimSymbol);
    R_xlen_t n = INTEGER(dim)[0];
    int k = INTEGER(dim)[1];
    const int *ix = NULL;
    R_xlen_t nrep_rows = n;
    if (idx != R_NilValue) {
        if (TYPEOF(idx) != INTSXP || XLENGTH(idx) != n) Rf_error("`idx` must be an integer vector of one row index per row of `y`");
        ix = INTEGER(idx);
    }
    /* the replicates as a list of columns, or as one n x B double matrix read in place: a design
     * built on a matrix kept the matrix, not a list copied from it (800 MB more at 5e6 rows and 20
     * replicates; final audit of 1.0.0) */
    const int as_matrix = isReal(reps) && isMatrix(reps);
    R_xlen_t nr;
    if (as_matrix) {
        SEXP rd = getAttrib(reps, R_DimSymbol);
        nrep_rows = INTEGER(rd)[0];
        if (!ix && nrep_rows != n) Rf_error("`reps` must have one row per row of `y`");
        nr = INTEGER(rd)[1];
    } else {
        if (TYPEOF(reps) != VECSXP) Rf_error("`reps` must be a list of replicate weight columns or a double matrix");
        nr = XLENGTH(reps);
        if (nr > INT_MAX) Rf_error("too many replicate weight columns");
        for (R_xlen_t r = 0; r < nr; r++) {
            SEXP w = VECTOR_ELT(reps, r);
            if (r == 0) nrep_rows = XLENGTH(w);
            if (!isReal(w) || XLENGTH(w) != nrep_rows || (!ix && nrep_rows != n))
                Rf_error("replicate weight column %d must be a double vector of length %lld", (int) r + 1,
                         (long long) (ix ? nrep_rows : n));
        }
    }
    if (ix) {
        for (R_xlen_t i = 0; i < n; i++) {
            if (ix[i] < 1 || ix[i] > nrep_rows) Rf_error("`idx` must index the rows of the replicates");
        }
    }
    SEXP out = PROTECT(allocMatrix(REALSXP, (int) nr, k));
    double *o = REAL(out);
    const double *yy = REAL(y);
    for (R_xlen_t r = 0; r < nr; r++) {
        /* registered directly, so no barrier of ours is on the stack and the raise does not return;
         * the error is for a call from R code a barrier runs (as rmbl_csv_poll() has it) */
        if (rmbl_interrupt_pending()) { UNPROTECT(1); rmbl_interrupt_raise_unbarriered(); Rf_error("interrupted"); }
        const double *w = as_matrix ? REAL(reps) + r * nrep_rows : REAL(VECTOR_ELT(reps, r));
        for (int j = 0; j < k; j++) {
            const double *col = yy + (R_xlen_t) j * n;
            double s = 0.0;
            if (ix) {
                for (R_xlen_t i = 0; i < n; i++) s += w[ix[i] - 1] * col[i];
            } else {
                for (R_xlen_t i = 0; i < n; i++) s += w[i] * col[i];
            }
            o[r + (R_xlen_t) j * nr] = s;
        }
    }
    UNPROTECT(1);
    return out;
}
