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
#include "rmbl_entry.h"

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
 * merge consumes. Two passes, as var() does: the mean (a running mean, which
 * cannot overflow, then var()'s correction by the mean residual), then the
 * central sums of the residuals. The one-pass update lost 9 of 16 digits of
 * the variance of values near 1e8 with a spread of 1 (CRAN stress test of
 * 0.5.14). */
void rmbl_moments_acc(const double *x, R_xlen_t n, double *out) {
    out[0] = out[1] = out[2] = out[3] = out[4] = 0.0;
    if (n < 1) return;
    double mean = 0.0;
    for (R_xlen_t i = 0; i < n; ++i) mean += (x[i] - mean) / (static_cast<double>(i) + 1.0);
    double r = 0.0;
    for (R_xlen_t i = 0; i < n; ++i) r += x[i] - mean;
    mean += r / static_cast<double>(n);
    double M2 = 0.0, M3 = 0.0, M4 = 0.0;
    for (R_xlen_t i = 0; i < n; ++i) {
        const double d = x[i] - mean;
        const double d2 = d * d;
        M2 += d2;
        M3 += d2 * d;
        M4 += d2 * d2;
    }
    out[0] = static_cast<double>(n);
    out[1] = mean;
    out[2] = M2;
    out[3] = M3;
    out[4] = M4;
}

SEXP C_rmbl_moments_acc_impl(SEXP x) {
    x = PROTECT(Rf_coerceVector(x, REALSXP));
    SEXP out = PROTECT(Rf_allocVector(REALSXP, 5));
    rmbl_moments_acc(REAL(x), XLENGTH(x), REAL(out));
    UNPROTECT(2);
    return out;
}

SEXP C_rmbl_moments_merge_impl(SEXP a, SEXP b) {
    a = PROTECT(Rf_coerceVector(a, REALSXP));
    b = PROTECT(Rf_coerceVector(b, REALSXP));
    if (XLENGTH(a) != 5 || XLENGTH(b) != 5) {
        UNPROTECT(2);
        RMBL_ARG_ERROR("each accumulator must have 5 entries");
    }
    SEXP out = PROTECT(Rf_allocVector(REALSXP, 5));
    rmbl_moments_merge(REAL(a), REAL(b), REAL(out));
    UNPROTECT(3);
    return out;
}

namespace {

/* The full 128-bit product of two 64-bit words, in portable C++ (no
 * __int128, which -pedantic refuses). */
inline void mul_64x64(std::uint64_t a, std::uint64_t b, std::uint64_t &hi, std::uint64_t &lo) {
    const std::uint64_t a0 = a & 0xFFFFFFFFULL, a1 = a >> 32;
    const std::uint64_t b0 = b & 0xFFFFFFFFULL, b1 = b >> 32;
    const std::uint64_t p00 = a0 * b0, p01 = a0 * b1, p10 = a1 * b0, p11 = a1 * b1;
    const std::uint64_t mid = (p00 >> 32) + (p01 & 0xFFFFFFFFULL) + (p10 & 0xFFFFFFFFULL);
    hi = p11 + (p01 >> 32) + (p10 >> 32) + (mid >> 32);
    lo = (mid << 32) | (p00 & 0xFFFFFFFFULL);
}

/* An unbiased draw from [0, s), s >= 1: Lemire's multiply-and-reject
 * ("Fast random integer generation in an interval", ACM TOMACS 2019) on the
 * engine's raw 64-bit outputs. std::uniform_int_distribution would do the
 * same job, but its algorithm is the standard library's choice, so a seed
 * gave one sample under libstdc++ (Linux, Windows) and another under libc++
 * (macOS); mt19937_64's output sequence is fixed by the standard, and so is
 * this. */
inline std::uint64_t bounded_draw(std::mt19937_64 &rng, std::uint64_t s) {
    std::uint64_t hi, lo;
    mul_64x64(static_cast<std::uint64_t>(rng()), s, hi, lo);
    if (lo < s) {
        const std::uint64_t t = (0 - s) % s;   /* 2^64 mod s */
        while (lo < t) mul_64x64(static_cast<std::uint64_t>(rng()), s, hi, lo);
    }
    return hi;
}

}  // namespace

/* Vitter's Algorithm R. Fills the reservoir with the first k items,
 * then replaces item j (0-based, j >= k) with probability k/(j+1).
 * Returns the 1-based indices of the retained items. */
SEXP C_rmbl_reservoir_impl(SEXP n_total, SEXP k, SEXP seed) {
    const double nd = Rf_asReal(n_total), kd = Rf_asReal(k), sd = Rf_asReal(seed);
    if (!R_FINITE(nd) || nd < 0 || nd > 9007199254740992.0) RMBL_ARG_ERROR("`n` must be a non-negative count");
    if (!R_FINITE(kd) || kd < 0) RMBL_ARG_ERROR("`k` must be a non-negative count");
    if (nd != std::floor(nd) || kd != std::floor(kd)) RMBL_ARG_ERROR("`n` and `k` must be whole numbers");
    if (kd > 100000000.0) RMBL_ARG_ERROR("`k` above 1e8 would need more memory than a sample should");
    /* a NaN or negative seed cast to an unsigned integer is undefined behaviour */
    if (!R_FINITE(sd) || sd < 0 || sd != std::floor(sd) || sd >= 9007199254740992.0)
        RMBL_ARG_ERROR("`seed` must be a whole number in [0, 2^53)");
    const R_xlen_t n = static_cast<R_xlen_t>(nd);
    R_xlen_t kk = static_cast<R_xlen_t>(kd);
    if (kk > n) kk = n;

    std::mt19937_64 rng(static_cast<unsigned long long>(sd));
    std::vector<R_xlen_t> res(static_cast<std::size_t>(kk));
    for (R_xlen_t i = 0; i < kk; ++i) res[static_cast<std::size_t>(i)] = i;
    for (R_xlen_t j = kk; j < n; ++j) {
        /* n runs to 2^53: Ctrl-C ended nothing (37.9 s for 3e9; CRAN stress test of 0.5.14) */
        if ((j & 0xFFFFF) == 0) rmbl::check_interrupt();
        const R_xlen_t t = static_cast<R_xlen_t>(bounded_draw(rng, static_cast<std::uint64_t>(j) + 1));
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
SEXP C_rmbl_hll_add_impl(SEXP x, SEXP p_bits, SEXP regs_in) {
    x = PROTECT(Rf_coerceVector(x, STRSXP));
    const int p = Rf_asInteger(p_bits);
    if (p < 4 || p > 20) {
        UNPROTECT(1);
        RMBL_ARG_ERROR("`p` must be between 4 and 20");
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
        /* the UTF-8 bytes of the string, so "cafe" with an accented e in UTF-8 and in latin1
         * is one value, not two (review of 1.0.0, M10); the translation's
         * buffer is released each time round */
        const void *vmax = vmaxget();
        const char *s = Rf_translateCharUTF8(e);
        const uint64_t h = hash64(reinterpret_cast<const unsigned char *>(s),
                                  std::strlen(s));
        vmaxset(vmax);
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
SEXP C_rmbl_hll_count_impl(SEXP regs) {
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
