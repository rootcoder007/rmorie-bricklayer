/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * rmbl_sketch.cpp -- one-pass algorithms for capsules too large to hold
 * in memory.
 *
 * A capsule member can be larger than the session's memory, and the
 * questions asked of it -- how many distinct values, what do the
 * moments look like, give me a fair sample -- do not require holding it.
 * Each routine here answers one of those in a single pass with bounded
 * memory:
 *
 *   * moment MERGING. Chan, Golub & LeVeque's parallel combination,
 *     extended to the third and fourth moments by Terriberry. Exact, not
 *     approximate: chunked accumulation gives bit-comparable results to
 *     one batch pass, so a 10 GB column can be summarised block by
 *     block.
 *   * reservoir sampling (Vitter's Algorithm R). A uniform sample of k
 *     items from a stream of unknown length, every item equally likely,
 *     in O(n) time and O(k) memory.
 *   * HyperLogLog. Distinct-value cardinality in fixed memory, with a
 *     relative standard error of 1.04/sqrt(m). Exact counting needs
 *     memory proportional to the number of distinct values; this needs
 *     16 KB regardless.
 *
 * Hashing for both the reservoir tie-breaks and HyperLogLog reuses the
 * package's SHA-256, so a given input produces the same sketch in every
 * binding of the core -- reproducibility is the point of a capsule, and
 * a sketch that varied between runs would defeat it.
 */

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstddef>
#include <cstring>
#include <random>
#include <vector>

extern "C" void rmbl_sha256_raw(const unsigned char *data, size_t len,
                                unsigned char out[32]);

namespace {

/* First 8 bytes of the SHA-256, big-endian. Deterministic across
 * platforms, which a std::hash would not be. */
uint64_t hash64(const unsigned char *data, size_t len) {
    unsigned char h[32];
    rmbl_sha256_raw(data, len, h);
    uint64_t v = 0;
    for (int i = 0; i < 8; ++i) v = (v << 8) | h[i];
    return v;
}

/* HyperLogLog bias-correction constant. */
double hll_alpha(std::size_t m) {
    switch (m) {
        case 16:  return 0.673;
        case 32:  return 0.697;
        case 64:  return 0.709;
        default:  return 0.7213 / (1.0 + 1.079 / static_cast<double>(m));
    }
}

}  // namespace

extern "C" {

/* Combine two moment accumulators. Each is (n, mean, M2, M3, M4) with
 * M_k the k-th central sum (NOT divided by n). `out` may alias `a`. */
void rmbl_moments_merge(const double *a, const double *b, double *out) {
    const double na = a[0], nb = b[0];
    if (na <= 0) {
        for (int i = 0; i < 5; ++i) out[i] = b[i];
        return;
    }
    if (nb <= 0) {
        for (int i = 0; i < 5; ++i) out[i] = a[i];
        return;
    }
    const double n = na + nb;
    const double delta = b[1] - a[1];
    const double d2 = delta * delta;
    const double d3 = d2 * delta;
    const double d4 = d2 * d2;

    const double mean = a[1] + nb * delta / n;
    const double M2 = a[2] + b[2] + d2 * na * nb / n;
    const double M3 = a[3] + b[3] +
        d3 * na * nb * (na - nb) / (n * n) +
        3.0 * delta * (na * b[2] - nb * a[2]) / n;
    const double M4 = a[4] + b[4] +
        d4 * na * nb * (na * na - na * nb + nb * nb) / (n * n * n) +
        6.0 * d2 * (na * na * b[2] + nb * nb * a[2]) / (n * n) +
        4.0 * delta * (na * b[3] - nb * a[3]) / n;

    out[0] = n;
    out[1] = mean;
    out[2] = M2;
    out[3] = M3;
    out[4] = M4;
}

/* Central sums for one block, in the (n, mean, M2, M3, M4) layout the
 * merge consumes. */
void rmbl_moments_acc(const double *x, R_xlen_t n, double *out) {
    out[0] = out[1] = out[2] = out[3] = out[4] = 0.0;
    if (n < 1) return;
    double mean = 0.0, M2 = 0.0, M3 = 0.0, M4 = 0.0;
    for (R_xlen_t i = 0; i < n; ++i) {
        const double cnt = static_cast<double>(i) + 1.0;
        const double d = x[i] - mean;
        const double dn = d / cnt;
        const double dn2 = dn * dn;
        const double term = d * dn * (cnt - 1.0);
        M4 += term * dn2 * (cnt * cnt - 3.0 * cnt + 3.0) +
              6.0 * dn2 * M2 - 4.0 * dn * M3;
        M3 += term * dn * (cnt - 2.0) - 3.0 * dn * M2;
        M2 += term;
        mean += dn;
    }
    out[0] = static_cast<double>(n);
    out[1] = mean;
    out[2] = M2;
    out[3] = M3;
    out[4] = M4;
}

SEXP C_rmbl_moments_acc(SEXP x) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    SEXP out = PROTECT(Rf_allocVector(REALSXP, 5));
    rmbl_moments_acc(REAL(x), XLENGTH(x), REAL(out));
    UNPROTECT(2);
    return out;
}

SEXP C_rmbl_moments_merge(SEXP a, SEXP b) {
    a = PROTECT(Rf_coerceVector(a, REALSXP));
    b = PROTECT(Rf_coerceVector(b, REALSXP));
    if (XLENGTH(a) != 5 || XLENGTH(b) != 5) {
        UNPROTECT(2);
        Rf_error("each accumulator must have 5 entries");
    }
    SEXP out = PROTECT(Rf_allocVector(REALSXP, 5));
    rmbl_moments_merge(REAL(a), REAL(b), REAL(out));
    UNPROTECT(3);
    return out;
}

/* Vitter's Algorithm R. Fills the reservoir with the first k items,
 * then replaces item j (0-based, j >= k) with probability k/(j+1).
 * Returns the 1-based indices of the retained items. */
SEXP C_rmbl_reservoir(SEXP n_total, SEXP k, SEXP seed) {
    const double nd = Rf_asReal(n_total);
    const R_xlen_t n = static_cast<R_xlen_t>(nd);
    R_xlen_t kk = static_cast<R_xlen_t>(Rf_asReal(k));
    if (n < 0) Rf_error("`n` must be non-negative");
    if (kk < 0) Rf_error("`k` must be non-negative");
    if (kk > n) kk = n;

    std::mt19937_64 rng(static_cast<unsigned long long>(Rf_asReal(seed)));
    std::vector<R_xlen_t> res(static_cast<std::size_t>(kk));
    for (R_xlen_t i = 0; i < kk; ++i) res[static_cast<std::size_t>(i)] = i;
    for (R_xlen_t j = kk; j < n; ++j) {
        std::uniform_int_distribution<R_xlen_t> d(0, j);
        const R_xlen_t t = d(rng);
        if (t < kk) res[static_cast<std::size_t>(t)] = j;
    }
    std::sort(res.begin(), res.end());
    SEXP out = PROTECT(Rf_allocVector(REALSXP, kk));
    for (R_xlen_t i = 0; i < kk; ++i) {
        REAL(out)[i] = static_cast<double>(res[static_cast<std::size_t>(i)] + 1);
    }
    UNPROTECT(1);
    return out;
}

/* HyperLogLog registers for a character vector. `p` is the log2 of the
 * register count; the registers are returned so several chunks can be
 * merged by taking the element-wise maximum. */
SEXP C_rmbl_hll_add(SEXP x, SEXP p_bits, SEXP regs_in) {
    x = PROTECT(Rf_coerceVector(x, STRSXP));
    const int p = Rf_asInteger(p_bits);
    if (p < 4 || p > 20) {
        UNPROTECT(1);
        Rf_error("`p` must be between 4 and 20");
    }
    const std::size_t m = static_cast<std::size_t>(1) << p;
    SEXP out = PROTECT(Rf_allocVector(INTSXP, static_cast<R_xlen_t>(m)));
    int *po = INTEGER(out);
    if (regs_in != R_NilValue &&
        XLENGTH(regs_in) == static_cast<R_xlen_t>(m)) {
        SEXP ri = PROTECT(Rf_coerceVector(regs_in, INTSXP));
        std::memcpy(po, INTEGER(ri), m * sizeof(int));
        UNPROTECT(1);
    } else {
        for (std::size_t i = 0; i < m; ++i) po[i] = 0;
    }

    const R_xlen_t n = XLENGTH(x);
    for (R_xlen_t i = 0; i < n; ++i) {
        SEXP e = STRING_ELT(x, i);
        if (e == NA_STRING) continue;
        const char *s = CHAR(e);
        const uint64_t h = hash64(reinterpret_cast<const unsigned char *>(s),
                                  std::strlen(s));
        /* top p bits select the register, the rest supply the run length */
        const std::size_t idx = static_cast<std::size_t>(h >> (64 - p));
        const uint64_t rest = (h << p) | (static_cast<uint64_t>(1) << (p - 1));
        /* position of the leading 1 in the remaining bits, 1-based */
        int rank = 1;
        uint64_t mask = static_cast<uint64_t>(1) << 63;
        while (rank <= 64 - p && (rest & mask) == 0) {
            ++rank;
            mask >>= 1;
        }
        if (rank > po[idx]) po[idx] = rank;
    }
    UNPROTECT(2);
    return out;
}

/* Cardinality estimate from the registers, with linear counting in the
 * small range where the raw estimator is badly biased. */
SEXP C_rmbl_hll_count(SEXP regs) {
    regs = PROTECT(Rf_coerceVector(regs, INTSXP));
    const std::size_t m = static_cast<std::size_t>(XLENGTH(regs));
    if (m == 0) {
        UNPROTECT(1);
        return Rf_ScalarReal(0.0);
    }
    const int *r = INTEGER(regs);
    double sum = 0.0;
    std::size_t zeros = 0;
    for (std::size_t i = 0; i < m; ++i) {
        sum += std::pow(2.0, -static_cast<double>(r[i]));
        if (r[i] == 0) ++zeros;
    }
    const double md = static_cast<double>(m);
    double est = hll_alpha(m) * md * md / sum;
    if (est <= 2.5 * md && zeros > 0) {
        est = md * std::log(md / static_cast<double>(zeros));
    }
    UNPROTECT(1);
    return Rf_ScalarReal(est);
}

}  // extern "C"
