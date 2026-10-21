# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Distributional drift: the question a data capsule exists to answer.
#
# A pinned schema and a SHA-256 tell you whether the bytes changed. They
# cannot tell you whether the DISTRIBUTION changed -- a re-released
# open-data extract with different bytes may be statistically the same
# data, or byte-identical column names may hide a silently rescaled
# column. These tests answer that second question, which is the one that
# invalidates a downstream result.

#' Two-sample Kolmogorov-Smirnov test (C backend)
#'
#' @description
#' Tests whether two numeric samples come from the same distribution, for
#' example a column in a pinned data extract and the same column in a fresh
#' download. It needs no assumption about the shape of either distribution,
#' and it reacts to any kind of change: a shift, a change in spread, or a
#' change in shape. It is the numeric test that
#' [cpsdrft()] runs on
#' every shared numeric or date column.
#'
#' @details
#' The statistic is the largest vertical gap between the two empirical distribution
#' functions, with the asymptotic two-sided p-value from the Kolmogorov
#' distribution. Distribution-free: it assumes nothing about the shape of
#' either sample, which is what makes it the right first test on a column
#' whose distribution was never specified.
#'
#' The p-value is the ASYMPTOTIC one, \eqn{2\sum_k (-1)^{k-1} e^{-2k^2t^2}}
#' with \eqn{t = \sqrt{n_{\mathrm{eff}}}D}. It is accurate for moderate
#' samples and conservative for small ones; for an exact small-sample
#' p-value use [stats::ks.test()]. Ties are
#' handled by comparing the two EDFs at each distinct value, so tied data
#' does not produce a warning the way `ks.test()` does.
#'
#' Missing values are dropped. Errors: non-numeric input (character,
#' factor, list), any infinite value, or no non-missing value left in
#' either sample. One value per sample is enough to compute the statistic,
#' but the p-value is only meaningful for samples of a few dozen or more.
#'
#' @param x,y Numeric vectors, the reference and the new sample. Logical
#'   vectors are read as 0/1.
#' @return A named length-3 numeric: `statistic` (the KS \eqn{D}) ,
#' `p_value`, and `neff` (the harmonic-style effective size
#'   \eqn{n_xn_y/(n_x+n_y)}).
#' @seealso
#' [drftpsi()],
#' [drftchisq()],
#' [cpsdrft()]
#' @examples
#' set.seed(1)
#' ref <- stats::rnorm(200)
#'
#' # The same distribution: a small D and a large p-value.
#' drftks(ref, stats::rnorm(200))
#'
#' # A shifted distribution is detected.
#' drftks(ref, stats::rnorm(200, mean = 0.8))
#'
#' # So is a change in spread alone, which a mean comparison would miss.
#' drftks(ref, stats::rnorm(200, sd = 2.5))
#'
#' # The statistic agrees with stats::ks.test().
#' a <- stats::rnorm(60); b <- stats::rnorm(45, 0.6)
#' all.equal(drftks(a, b)[["statistic"]],
#'           as.numeric(suppressWarnings(stats::ks.test(a, b))$statistic))
#'
#' # Identical samples have nothing to report.
#' drftks(ref, ref)[["statistic"]]
#' @export
#' @srrstats {G5.8c} All-NA input errors "at least one non-missing" (test-drift.R:46); identical values give Gini 0
#'   (test-tables.R:148).
drftks <- function(x, y) {
  x <- .rmbl_finite_input(x, "x", min_n = 1L)
  y <- .rmbl_finite_input(y, "y", min_n = 1L)
  x <- x[!is.na(x)]   # minn = 1L above: at least one value remains in each
  y <- y[!is.na(y)]
  out <- .Call(C_rmbl_ks, x, y)
  names(out) <- c("statistic", "p_value", "neff")
  out
}

#' Population stability index and Jensen-Shannon divergence (C backend)
#'
#' @description
#' Two effect-size summaries of how far the distribution of a numeric
#' column has moved from a reference sample. Both samples are binned on the
#' reference's quantiles and the two sets of bin shares are compared. Unlike
#' a p-value they do not grow with the sample size, so they say how large a
#' shift is rather than whether it is detectable.
#' [cpsdrft()] reports
#' both for every numeric column.
#'
#' @details
#' Binning: values are rounded to 12 significant digits (so a formatting
#' difference between two releases does not move tied values across an
#' edge), the `bins + 1` quantiles of `x` are computed, duplicates are
#' removed, and the interior quantiles become right-closed cut points with
#' open ends at \eqn{\pm\infty}. When the reference has fewer than three
#' distinct quantiles (a constant or nearly constant column), every distinct
#' quantile is a cut point instead. The bin shares \eqn{p_i} (reference) and
#' \eqn{q_i} (new) are the proportions of each sample in each bin.
#'
#' The population stability index is
#' \eqn{\sum_i (p_i - q_i)\log(p_i/q_i)} -- the symmetrised
#' Kullback-Leibler divergence of the two discrete distributions. The
#' conventional reading, from credit-risk monitoring where it originates,
#' is that below 0.1 is stable, 0.1 to 0.25 warrants a look, and above 0.25
#' is a material shift.
#'
#' The Jensen-Shannon divergence is
#' \eqn{\tfrac12 KL(p\|m) + \tfrac12 KL(q\|m)} with \eqn{m} the mixture
#' \eqn{(p+q)/2}. Unlike PSI it is bounded -- by \eqn{\log 2} in nats --
#' so it is comparable across columns with different numbers of bins, and
#' it is finite even when a category is absent from one side.
#'
#' Empty bins are floored at `eps` for the PSI only, since
#' \eqn{\log(0)} would otherwise send it to infinity on a single missing
#' category.
#'
#' Missing values are dropped. Errors: non-numeric or infinite input, an
#' empty sample, `bins` not a whole number from 2 to 1,000,000, `eps` not
#' strictly between 0 and 1. The PSI bands quoted above are heuristics with
#' no calibrated null distribution; on a few hundred rows binning noise alone
#' can exceed 0.25 (see `psiminn` in
#' [cpsdrft()]).
#'
#' @param x,y Numeric vectors, the reference and the new sample.
#' Binned on the quantiles of `x`, so the reference defines the bins.
#' @param bins Whole number, default 10: the number of quantile bins of the
#' reference. Fewer bins are used when the reference has tied quantiles.
#' @param eps Floor applied to empty bins in the PSI (default
#' 1e-6), any value in (0, 1). An empty bin contributes
#' \eqn{(p - eps)\log(p/eps)} to the index, so the floor is part of the
#' statistic: the default reports the raw index, and a larger floor (0.01,
#' 0.05) smooths an empty bin toward that share, which dampens the PSI.
#' Compare runs only at one `eps`.
#' @return A named length-2 numeric: `psi` (non-negative, unbounded) and
#' `jsdiv` (in nats, between 0 and \eqn{\log 2 \approx 0.693}).
#' @seealso [drftks()],
#'   [cpsdrft()].
#' @references Wu D, Olson DL (2010). Enterprise risk management: coping
#' with model risk in a large bank. *Journal of the Operational Research
#' Society* 61(2), 179--190. \doi{10.1057/jors.2008.144}
#'
#' Lin J (1991). Divergence measures based on the Shannon entropy.
#'   *IEEE Transactions on Information Theory* 37(1), 145--151.
#'   \doi{10.1109/18.61115}
#' @examples
#' set.seed(2)
#' ref <- stats::rnorm(500)
#'
#' # Same distribution: both indices near zero.
#' drftpsi(ref, stats::rnorm(500))
#'
#' # A shift both indices register.
#' drftpsi(ref, stats::rnorm(500, mean = 1))
#'
#' # A sample compared with itself has moved nowhere at all.
#' drftpsi(ref, ref)
#'
#' # The Jensen-Shannon divergence is bounded by log(2), whatever the
#' # shift, which is what makes it comparable across columns.
#' drftpsi(c(1, 1, 1), c(9, 9, 9))[["jsdiv"]] <= log(2)
#'
#' # a coarser binning, and a larger floor that damps an empty bin
#' drftpsi(ref, stats::rnorm(500, mean = 1), bins = 4)
#' drftpsi(ref, stats::rnorm(500, mean = 1), eps = 0.01)
#'
#' try(drftpsi(ref, ref, bins = 1))
#' @export
drftpsi <- function(x, y, bins = 10L, eps = 1e-6) {
  x <- .rmbl_finite_input(x, "x", min_n = 1L)
  y <- .rmbl_finite_input(y, "y", min_n = 1L)
  x <- x[!is.na(x)]   # minn = 1L above: at least one value remains in each
  y <- y[!is.na(y)]
  bins <- .rmbl_num(bins, "bins", integer = TRUE)
  if (length(bins) != 1L || is.na(bins) || bins < 2L) {
    stop("`bins` must be one whole number of at least 2", call. = FALSE)
  }
  if (bins > 1e6) {
    stop("`bins` must be at most 1,000,000 (a bin per value is already the finest it gets)", call. = FALSE)
  }
  eps <- .rmbl_num(eps, "eps")
  if (length(eps) != 1L || is.na(eps) || eps <= 0 || eps >= 1) {
    stop("`eps` must be a positive floor below one (0 < eps < 1)", call. = FALSE)
  }
  s <- .rmbl_psi_shares(x, y, bins)
  out <- .Call(C_rmbl_psi, s$px, s$py, as.numeric(eps))
  names(out) <- c("psi", "jsdiv")
  out
}

#' Bins two samples on the reference's quantiles, as drftpsi() does.
#'
#' The bin edges and the two sets of bin shares behind the PSI; cpsdrft() keeps them so a plot
#' or a report can show where the index comes from.
#' @param x,y The reference and the new sample, finite and non-empty.
#' @param bins The number of quantile bins of the reference.
#' @return A list: `edges` (from -Inf to Inf), `px` and `py` (the shares per bin).
#' @noRd
.rmbl_psi_shares <- function(x, y, bins) {
  # Values within a part in 1e12 of each other are the same value: cut()
  # is right-closed, and a float-formatting difference between two
  # releases of a file moved whole bins of tied integers across an edge.
  x <- signif(x, 12)
  y <- signif(y, 12)
  # The reference defines the bin edges, so the comparison asks where the
  # NEW sample sits relative to the pinned one.
  probs <- seq(0, 1, length.out = bins + 1L)
  q <- unique(.Call(C_rmbl_quantile, x, probs))
  # The outer quantiles (the reference's min and max) become open ends so
  # the new sample's tails land in a bin. When the reference has fewer
  # than three distinct quantiles -- a constant column, or one that is
  # mostly a single value with a thin tail -- every distinct value is a
  # cut point instead: replacing the ends with +-Inf left ONE bin, and a
  # column rescaled by 1000x reported PSI = 0.
  edges <- if (length(q) >= 3L) {
    c(-Inf, q[-c(1L, length(q))], Inf)
  } else {
    c(-Inf, q, Inf)
  }
  list(edges = edges,
       px = as.numeric(table(cut(x, edges))) / length(x),
       py = as.numeric(table(cut(y, edges))) / length(y))
}

#' Chi-square test for a categorical column
#'
#' @description
#' Tests whether the category counts of a new sample agree with a reference
#' distribution that is taken as known, such as proportions fixed by a
#' specification or a published breakdown. It is Pearson's chi-square
#' goodness-of-fit test. When the reference is itself a sample, use
#' [drfthomog()], which accounts for the
#' reference's own sampling
#' error.
#'
#' @details
#' Pearson's chi-square goodness-of-fit statistic comparing observed
#' category counts with the proportions a capsule was pinned against. Use
#' it where [drftks()] cannot apply, because the
#' column is a factor or a set of codes rather than a number.
#'
#' Categories present in one argument and not the other are aligned by
#' name, so a vanished category registers as a shortfall against its
#' expected count.
#'
#' A category that OCCURS but which the reference gives probability zero
#' contradicts the pinned distribution outright, and its chi-square term is
#' unbounded; `statistic` is then `Inf` and `p_value` is
#' `0`. If a new category is a legitimate possibility rather than a
#' contradiction -- which it usually is when the reference is itself a
#' finite sample -- use
#' [drfthomog()] instead.
#'
#' With \eqn{O_j} the observed counts and \eqn{E_j = N e_j / \sum e} the
#' reference scaled to the observed total \eqn{N},
#' \deqn{X^2 = \sum_j \frac{(O_j - E_j)^2}{E_j}}
#' over the categories with \eqn{E_j > 0}, on \eqn{k - 1} degrees of freedom.
#' The p-value is the upper tail of the chi-square distribution, computed
#' directly (not as one minus the lower tail), so it does not round to zero
#' early. With a single category there is nothing to test: `df` is 0 and
#' both p-values are `NA`. The chi-square approximation is poor when
#' expected counts are below about 5;
#' [stats::chisq.test()] with
#' `simulate.p.value = TRUE` is an alternative there.
#'
#' Errors: a numeric vector without names; negative, infinite or missing
#' counts; a total of zero on either side.
#'
#' @param obs Named numeric vector of counts in the
#' new sample, or a factor/character vector to be tabulated.
#' @param expd Named numeric vector of reference counts
#' or proportions, or a factor/character vector to be tabulated. Rescaled
#' to the total of `obs`.
#' @return A named length-4 numeric: `statistic`, `df`,
#' `p_value` and `logpvalue`, the natural log of the upper tail, which
#' keeps its information where `p_value` underflows to 0.
#' @seealso [drfthomog()],
#'   [cpsdrft()],
#' [stats::chisq.test()] for the full test object.
#' @examples
#' ref <- c(a = 50, b = 30, c = 20)
#'
#' # Counts matching the reference proportions: nothing to report.
#' drftchisq(c(a = 100, b = 60, c = 40), ref)
#'
#' # A reallocated mix is detected.
#' drftchisq(c(a = 40, b = 60, c = 100), ref)
#'
#' # Agrees with stats::chisq.test().
#' o <- c(a = 40, b = 60, c = 100)
#' all.equal(drftchisq(o, ref)[["statistic"]],
#'           as.numeric(stats::chisq.test(o, p = ref / sum(ref))$statistic))
#'
#' # Raw vectors are tabulated for you.
#' drftchisq(c("a", "a", "b", "b"), c("a", "b"))
#'
#' # A category the reference rules out, but which occurs, is a flat
#' # contradiction rather than a large finite statistic.
#' drftchisq(c("a", "a", "b", "d"), c("a", "a", "b", "b"))
#'
#' # When a new category is legitimate, compare two samples instead.
#' drfthomog(c("a", "a", "b", "b"), c("a", "a", "b", "d"))
#' @export
drftchisq <- function(obs, expd) {
  tab <- function(v) {
    if (is.factor(v) || is.character(v)) {
      t <- table(v)
      stats::setNames(as.numeric(t), names(t))
    } else {
      nm <- names(v)
      if (is.null(nm)) {
        stop("a numeric `obs`/`expd` must be named", call. = FALSE)
      }
      stats::setNames(.rmbl_num(v, "observed / expected"), nm)
    }
  }
  o <- .rmbl_check_counts(tab(obs), "obs")
  e <- .rmbl_check_counts(tab(expd), "expd")
  lv <- union(names(o), names(e))
  o <- stats::setNames(ifelse(is.na(o[lv]), 0, o[lv]), lv)
  e <- stats::setNames(ifelse(is.na(e[lv]), 0, e[lv]), lv)
  if (sum(o) <= 0) stop("`obs` has no counts", call. = FALSE)
  if (sum(e) <= 0) stop("`expd` has no counts", call. = FALSE)
  # Reference proportions, scaled to the observed total.
  exp_counts <- sum(o) * e / sum(e)
  keep <- exp_counts > 0   # non-empty: both totals are positive by now
  df <- sum(keep) - 1L
  # A category the reference assigns probability zero, yet which occurs,
  # contradicts the pinned distribution outright: the chi-square term
  # for it diverges. Report that rather than dropping the category and
  # returning a statistic computed as though it had not appeared.
  if (any(o[!keep] > 0)) {
    return(c(statistic = Inf, df = max(1L, df), p_value = 0, logpvalue = -Inf))
  }
  stat <- sum((o[keep] - exp_counts[keep])^2 / exp_counts[keep])
  if (df < 1L) {
    # one category on both sides: nothing to test, and df = 0 is not a
    # chi-square distribution
    return(c(statistic = stat, df = 0, p_value = NA_real_, logpvalue = NA_real_))
  }
  c(statistic = stat, df = df, p_value = .rmbl_chisq_p(stat, df),
    logpvalue = .rmbl_chisq_logp(stat, df))
}

#' Returns the upper tail of a chi-square distribution.
#'
#' The upper tail of a chi-square, computed AS the upper tail. The former
#' 1 - cgamcdf(df / 2, stat / 2) underflowed to exactly 0 once the
#' lower tail rounded to 1 (stat >= 74.9 at df = 2), and \dQuote{p = 0} is a
#' number a reader quotes.
#' @param stat The chi-square statistic.
#' @param df Its degrees of freedom.
#' @return The upper-tail probability.
#' @noRd
.rmbl_chisq_p <- function(stat, df) {
  stats::pchisq(stat, df, lower.tail = FALSE)
}

#' Returns the upper tail of a chi-square distribution on the log scale.
#'
#' The same tail on the log scale: a double cannot hold exp(-2536), so
#' `p_value` is 0 there while `logpvalue` still says how far below.
#' @param stat The chi-square statistic.
#' @param df Its degrees of freedom.
#' @return The log of the upper-tail probability.
#' @noRd
.rmbl_chisq_logp <- function(stat, df) {
  stats::pchisq(stat, df, lower.tail = FALSE, log.p = TRUE)
}

#' Chi-square test of homogeneity for two categorical samples
#'
#' @description
#' Tests whether two samples of a categorical variable (for example race,
#' offence type or region in an old and a new data extract) were drawn from
#' the same distribution, by Pearson's chi-square on the 2-by-k contingency
#' table of their counts. Use it to ask whether the mix of categories has
#' changed between two samples; it is the categorical test that
#' [cpsdrft()] runs.
#'
#' @details
#' With pooled shares \eqn{\hat\pi_j = (x_j + y_j)/(n_x + n_y)} and
#' expected counts \eqn{n_x \hat\pi_j} and \eqn{n_y \hat\pi_j},
#' \deqn{X^2 = \sum_j \frac{(x_j - n_x\hat\pi_j)^2}{n_x\hat\pi_j} +
#'   \frac{(y_j - n_y\hat\pi_j)^2}{n_y\hat\pi_j}}
#' on \eqn{k - 1} degrees of freedom. Three branches, named in the `method`
#' attribute:
#' \itemize{
#'   \item `"chi-square approximation"`: every expected count is at least
#'     5; the p-value is the chi-square upper tail.
#'   \item `"Monte Carlo permutation (small expected counts)"`: some
#'     expected count is below 5; the p-value then comes from
#'     [stats::chisq.test()] with `simulate.p.value = TRUE`
#'     and
#'     `B = 10000` tables with the same margins, drawn under `seed`.
#'   \item `"inapplicable: ..."`: a single category, or fewer than two
#'     observations per category (for example two disjoint sets of dates);
#'     no test has power there, so `p_value` is `NA` rather than 1.
#' }
#'
#' Errors: a numeric vector without names; negative, infinite or missing
#' counts; an empty sample.
#'
#' # Why this and not [drftchisq()]
#'
#' [drftchisq()] compares observed counts
#' against a distribution taken as KNOWN -- proportions fixed by a
#' specification. When the reference is itself a finite sample, that
#' treatment ignores the reference's own sampling error, understates the
#' variance of the comparison, and so reports drift too readily. A
#' homogeneity test estimates the shared distribution from the pooled
#' margins and carries the uncertainty of both samples, which is the right
#' test when comparing a pinned extract with a fresh fetch.
#' [cpsdrft()] therefore uses this one.
#'
#' Categories present in only one sample are aligned by name and given zero
#' counts, so an appearing or vanishing level registers.
#'
#' @param x,y Factor or character vectors (or named count
#' vectors) -- the reference and the new sample.
#' @return A named length-4 numeric: `statistic`, `df`,
#' `p_value` and `logpvalue`, the natural log of the upper tail, which
#' keeps its information where `p_value` underflows to 0. On the Monte
#' Carlo branch (sparse tables) `p_value` is floored at 1/(B+1) and
#' `logpvalue` is its log, so it carries no extra range there. The
#' attribute `method` names the branch, or says why the test was
#' inapplicable (one category, no counts).
#' @seealso
#' [drftchisq()] for a known reference
#' distribution, [stats::chisq.test()] for
#' the full test object.
#' @examples
#' set.seed(1)
#' a <- sample(c("x", "y", "z"), 300, TRUE)
#' b <- sample(c("x", "y", "z"), 300, TRUE)
#'
#' # Two draws from the same distribution: no evidence of a difference.
#' drfthomog(a, b)
#'
#' # A reallocated mix is detected.
#' drfthomog(a, sample(c("x", "y", "z"), 300, TRUE,
#'                             prob = c(0.7, 0.2, 0.1)))
#'
#' # Agrees with stats::chisq.test() on the 2-by-k table.
#' tab <- rbind(table(a), table(b))
#' all.equal(drfthomog(a, b)[["statistic"]],
#'           as.numeric(stats::chisq.test(tab)$statistic))
#'
#' # It is more conservative than treating the reference as known, which
#' # is exactly the point.
#' drfthomog(a, b)[["p_value"]] >= drftchisq(b, a)[["p_value"]]
#'
#' # named count vectors, and a small table that takes the Monte Carlo branch
#' drfthomog(c(a = 30, b = 20), c(a = 25, b = 25))
#' attr(drfthomog(c(a = 3, b = 1, c = 2), c(a = 1, b = 4, c = 1)), "method")
#'
#' try(drfthomog(c(1, 2), c(a = 3)))
#' @param seed Integer, default 1: seed for the Monte Carlo branch (small expected
#'   counts). The
#'   draw is made under this seed and the caller's RNG stream is restored,
#'   so the same inputs give the same p-value and nothing downstream moves.
#' @export
drfthomog <- function(x, y, seed = 1L) {
  tab <- function(v) {
    if (is.factor(v) || is.character(v)) {
      t <- table(as.character(v))
      stats::setNames(as.numeric(t), names(t))
    } else {
      nm <- names(v)
      if (is.null(nm)) {
        stop("a numeric `x`/`y` must be named", call. = FALSE)
      }
      stats::setNames(.rmbl_num(v, "x / y"), nm)
    }
  }
  cx <- .rmbl_check_counts(tab(x), "x")
  cy <- .rmbl_check_counts(tab(y), "y")
  lv <- union(names(cx), names(cy))
  cx <- stats::setNames(ifelse(is.na(cx[lv]), 0, cx[lv]), lv)
  cy <- stats::setNames(ifelse(is.na(cy[lv]), 0, cy[lv]), lv)
  nx <- sum(cx)
  ny <- sum(cy)
  if (nx <= 0 || ny <= 0) {
    stop("both samples must have at least one observation", call. = FALSE)
  }
  # Expected counts under a shared distribution estimated from the
  # pooled margins -- this is what carries both samples' uncertainty.
  pooled <- (cx + cy) / (nx + ny)
  ex <- nx * pooled
  ey <- ny * pooled
  keep <- pooled > 0   # nx, ny > 0 above: at least one category is kept
  stat <- sum((cx[keep] - ex[keep])^2 / ex[keep]) +
    sum((cy[keep] - ey[keep])^2 / ey[keep])
  df <- sum(keep) - 1L
  if (df < 1L) {
    out <- c(statistic = stat, df = 0, p_value = NA_real_, logpvalue = NA_real_)
    attr(out, "method") <- "inapplicable: one category"
    return(out)
  }
  # A table whose categories outnumber its observations has one statistic
  # for every arrangement of its margins (two disjoint sets of 400 dates:
  # stat = 800, df = 799, and every table with those margins is the same).
  # No test has power there; the honest answer is "inapplicable", not p = 1.
  if ((nx + ny) / sum(keep) < 2) {
    out <- c(statistic = stat, df = df, p_value = NA_real_, logpvalue = NA_real_)
    attr(out, "method") <- paste0("inapplicable: ", sum(keep), " categories for ",
                                  nx + ny, " observations (fewer than two per category)")
    return(out)
  }
  # The chi-square approximation rests on the expected counts. When any
  # is below 5 the p-value is a Monte Carlo one over tables with the same
  # margins, under a fixed local seed: the caller's RNG stream is left
  # exactly as it was.
  simulated <- min(ex[keep], ey[keep]) < 5
  p <- if (simulated) {
    tab <- rbind(cx[keep], cy[keep])
    .rmbl_with_seed(seed, as.numeric(suppressWarnings(stats::chisq.test(
      tab, simulate.p.value = TRUE, B = 10000L))$p.value))
  } else {
    .rmbl_chisq_p(stat, df)
  }
  out <- c(statistic = stat, df = df, p_value = p,
           logpvalue = if (simulated) log(p) else .rmbl_chisq_logp(stat, df))
  attr(out, "method") <- if (simulated) {
    "Monte Carlo permutation (small expected counts)"
  } else {
    "chi-square approximation"
  }
  out
}

#' Benford first-digit test
#'
#' @description
#' Compares the distribution of leading significant digits in `x` with
#' Benford's law, \eqn{P(d) = \log_{10}(1 + 1/d)}. Naturally occurring
#' quantities that span several orders of magnitude follow it closely;
#' figures that were rounded, truncated, capped, re-scaled, or invented
#' typically do not. That makes it a cheap screen for a numeric column that
#' arrived looking plausible but is not the measurement it claims to be.
#'
#' It is a SCREEN, not a verdict. Columns with a narrow range, a unit floor
#' or ceiling, or an assigned-identifier structure (postcodes, year fields,
#' prices ending in 99) legitimately violate Benford's law. Treat a small
#' p-value as a reason to look, never as evidence of fabrication.
#'
#' @details
#' Zeros and non-finite values have no leading significant digit and are
#' excluded; the sign is ignored.
#'
#' With \eqn{n} usable values, \eqn{O_d} the count with leading digit
#' \eqn{d} and \eqn{E_d = n \log_{10}(1 + 1/d)},
#' \deqn{X^2 = \sum_{d=1}^{9} \frac{(O_d - E_d)^2}{E_d}}
#' on 8 degrees of freedom. The smallest Benford share is 0.046 (digit 9),
#' so the chi-square approximation needs about \eqn{n \ge 110} for every
#' expected count to reach 5; below that treat the p-value as rough.
#' Digits are counted in compiled code in blocks of a million values, and
#' a long vector shows a progress bar in an interactive session
#' (silenced by `options(morie.quiet = TRUE)`). Errors: non-numeric input,
#' or no finite non-zero value.
#'
#' @param x Numeric vector.
#' @return A list of class `bricklayer_benford` with `counts`
#' (observed digit frequencies 1--9), `expected`, `proportion`,
#' `statistic`, `df`, `p_value`, `logpvalue` (the log of the upper
#' tail, which keeps its information where `p_value` underflows to 0),
#' and `n` (the number of values used). `counts`, `expected` and
#' `proportion` are named numeric vectors with names `"1"` to `"9"`. The
#' print method shows the verdict and a bar chart of observed against
#' expected shares.
#' @seealso [drftchisq()],
#'   [cpsdrft()].
#' @references Benford F (1938). The law of anomalous numbers.
#'   *Proceedings of the American Philosophical Society* 78(4), 551--572.
#' @examples
#' # A quantity spanning several orders of magnitude follows the law.
#' set.seed(3)
#' benfordtst(10^stats::runif(2000, 0, 6))
#'
#' # Digits drawn uniformly do not.
#' benfordtst(as.numeric(paste0(sample(1:9, 2000, TRUE), "000")))
#'
#' # The expected proportions are the closed form.
#' b <- benfordtst(10^stats::runif(500, 0, 5))
#' all.equal(unname(b$expected) / b$n, log10(1 + 1 / (1:9)))
#'
#' # Zeros carry no leading digit and are excluded from n.
#' benfordtst(c(0, 0, 1, 2, 3))$n
#'
#' try(benfordtst(c(0, NA)))
#' @export
benfordtst <- function(x) {
  x <- .rmbl_num_input(x, "x")
  x <- x[is.finite(x) & x != 0]
  if (length(x) < 1L) {
    stop("`x` has no finite non-zero values to take a leading digit from",
         call. = FALSE)
  }
  # in blocks of a million, so a long vector shows its progress (the counts add up exactly)
  starts <- seq.int(1, length(x), by = 1e6)
  pg <- blprog("Benford digits", length(x))
  on.exit(pg$done(), add = TRUE)
  counts <- NULL
  for (s in starts) {
    e <- min(length(x), s + 1e6 - 1)
    k <- .Call(C_rmbl_first_digit_counts, x[s:e])
    counts <- if (is.null(counts)) k else counts + k
    pg$update(e, sprintf("%s of %s values", .bl_n(e), .bl_n(length(x))))
  }
  names(counts) <- as.character(1:9)
  n <- sum(counts)
  p <- log10(1 + 1 / (1:9))
  expected <- n * p
  stat <- sum((counts - expected)^2 / expected)
  df <- 8L
  out <- list(counts = counts,
              expected = stats::setNames(expected, as.character(1:9)),
              proportion = counts / n,
              statistic = stat, df = df,
              p_value = .rmbl_chisq_p(stat, df),
              logpvalue = .rmbl_chisq_logp(stat, df),
              n = n)
  class(out) <- c("bricklayer_benford", "list")
  out
}

#' Compare a fetched data frame with the one a capsule was pinned against
#'
#' @description
#' Checks whether the data in a freshly downloaded table still look like the
#' data an analysis was built on, column by column. A digest only says
#' whether the bytes changed; this says whether the distributions changed,
#' which is what invalidates a result. Use it when re-running an analysis on
#' a re-released extract.
#'
#' @details
#' Runs the appropriate drift test on every shared column and collects the
#' verdicts in one report: [drftks()] plus
#' [drftpsi()] for a numeric column,
#' [drfthomog()] for a categorical
#' one. Columns that appeared or vanished are listed separately, since no
#' test applies to them.
#'
#' The categorical test is the two-sample homogeneity test, NOT
#' [drftchisq()] 's goodness-of-fit against a
#' known distribution: the reference here is itself a finite sample, and
#' ignoring its sampling error would report drift too readily.
#'
#' This is the check that a byte-level digest cannot make. A re-released
#' extract legitimately has a different SHA-256 while being the same data
#' statistically; conversely a column can keep its name, type and row count
#' while having been silently rescaled. `cpsdrft()` asks whether
#' the DATA moved.
#'
#' Column types: a column numeric on both sides is `"numeric"`; a character
#' or factor column whose every value is an ISO date (`YYYY-MM-DD`) or
#' date-time on both sides is converted and tested as `"date"`; a
#' categorical column with more than `idelvls` distinct values, or
#' with at least 20 distinct values that number more than a fifth of the
#' rows, is an `"identifier"` and is not tested; anything else is
#' `"categorical"`. Missing values are dropped. For a categorical column the
#' PSI is computed over the reference's categories with every unseen current
#' value pooled into one extra bin.
#'
#' A column is `drifted` when its p-value is below `alpha`, or when its PSI
#' exceeds `psithr` and both samples have at least `psiminn`
#' values. `anydrft` is also `TRUE` when a column was added or removed.
#' Each column runs one or two tests, so with many columns some will fall
#' below `alpha` by chance; see [scanadj()] for a
#' multiplicity
#' correction and [drftcal()] for an empirical
#' false-alarm rate.
#' A progress bar is shown in an interactive session for many columns.
#'
#' Errors: either argument not a data frame; `alpha` not strictly between
#' 0 and 1; `psiminn` negative; `idelvls` below 2.
#'
#' @param ref Data frame the capsule was built from.
#' @param cur Data frame just fetched.
#' @param alpha Significance level for the `drifted` flag
#' (default 0.01; deliberately stricter than 0.05 because a wide table runs
#' many tests).
#' @param psithr PSI above which a numeric
#' column is flagged even when its p-value is not significant (default
#' 0.25, the conventional \dQuote{material shift} line).
#' @param psiminn Minimum size BOTH samples must reach
#' before `psithr` is allowed to flag a column on its own
#' (default 1000). The PSI bands are large-sample heuristics with no
#' calibrated null distribution: on a few hundred rows, binning noise alone
#' routinely pushes the index past 0.25, so applying the threshold there
#' manufactures drift. Below this size the flag rests on the
#' Kolmogorov-Smirnov p-value, which is calibrated, and the PSI is still
#' reported as an effect size.
#' @param bins Bins passed to
#' [drftpsi()] (default 10).
#' @return A list of class `bricklayer_drift` with elements:
#' \describe{
#'   \item{`columns`}{a data frame, one row per shared column, with
#'     `column`, `type` (`"numeric"`, `"date"`, `"categorical"`
#'     or
#'     `"identifier"`), `statistic` (KS \eqn{D} or chi-square), `p_value`,
#'     `psi`, `jsdiv`, `unseen_share` (share of current values the
#'     reference never had; categorical and identifier columns only),
#'     `drifted` (logical, `NA` when no test applies) and `note`
#'     (why a column was not tested, or `""`);}
#'   \item{`added`, `removed`}{character vectors of column names;}
#'   \item{`nref`, `ncur`}{row counts;}
#'   \item{`alpha`, `psithr`, `psiminn`}{the settings used;}
#'   \item{`bands`}{the PSI bands the plots and reports colour by:
#'     `warn` (0.1, or `psithr` when lower) and `fail` (`psithr`);}
#'   \item{`summ`}{one binned summary per shared column, for
#'     [plot()][plot-methods], [drfthtml()] and
#'     [drftapp()]: missing shares,
#'     sizes, summary statistics or the ten largest categories, the PSI bins
#'     with each bin's term of the index, a histogram and first-digit counts.
#'     Never the rows;}
#'   \item{`anydrft`}{logical.}
#' }
#' The print method lists the per-column verdicts, drifted columns first.
#' @seealso
#' [valsch()] for the structural
#' check, which this complements rather than replaces.
#' @examples
#' set.seed(5)
#' ref <- data.frame(
#'   value = stats::rnorm(300),
#'   size = stats::runif(300, 1, 10),
#'   grade = sample(c("a", "b", "c"), 300, TRUE)
#' )
#'
#' # A fresh draw from the same process: no drift.
#' same <- data.frame(
#'   value = stats::rnorm(300),
#'   size = stats::runif(300, 1, 10),
#'   grade = sample(c("a", "b", "c"), 300, TRUE)
#' )
#' d <- cpsdrft(ref, same)
#' d$anydrft
#'
#' # A silently rescaled column, and a new category, are both caught.
#' moved <- same
#' moved$size <- moved$size * 3
#' moved$grade[1:100] <- "z"
#' cpsdrft(ref, moved)
#'
#' # The PSI is always reported as an effect size, but on a sample this
#' # small it is not allowed to raise the flag by itself -- binning noise
#' # alone would clear 0.25. Lower psiminn to override that.
#' cpsdrft(ref, same)$columns$psi
#'
#' # Structural changes are reported rather than tested.
#' cpsdrft(ref, same[, c("value", "grade")])$removed
#'
#' try(cpsdrft(ref, as.matrix(same)))
#' @param idelvls A character column with more distinct values
#'   than this (or at least 20 distinct values covering more than a fifth of
#'   the rows) is an identifier,
#'   not a distribution: it gets `type = "identifier"`, its `unseen_share`
#'   (the fraction of current rows whose value the reference never had) and
#'   `drifted = NA`. Character columns that parse as dates are compared as
#'   dates (`type = "date"`).
#' @param seed Seed for the Monte Carlo branch of the homogeneity test,
#'   [drfthomog()]. The caller's RNG stream is
#'   left
#'   untouched.
#' @export
#' @srrstats {G5.3} test-drift.R:195 checks all(is.finite(d$columns$psi)); similar no-NA checks in test-areal.R:322
#'   and test-census.R:143.
#' @srrstats {EA3.1} A fixed battery (KS, chi-square, PSI, Jensen-Shannon) compares a fetched frame with the pinned
#'   one, column by column, in one report; test-print-methods.R.
cpsdrft <- function(ref, cur, alpha = 0.01,
                          psithr = 0.25, psiminn = 1000L,
                          bins = 10L, idelvls = 100L, seed = 1L) {
  if (!is.data.frame(ref) || !is.data.frame(cur)) {
    stop("`ref` and `cur` must both be data frames", call. = FALSE)
  }
  alpha <- .rmbl_num(alpha, "alpha")
  if (length(alpha) != 1L || is.na(alpha) || alpha <= 0 || alpha >= 1) {
    stop("cpsdrft: `alpha` must be a single value strictly inside (0, 1)",
         call. = FALSE)
  }
  psiminn <- .rmbl_num(psiminn, "psiminn", integer = TRUE)
  if (length(psiminn) != 1L || is.na(psiminn) || psiminn < 0L) {
    stop("`psiminn` must be a single non-negative integer", call. = FALSE)
  }
  idelvls <- .rmbl_num(idelvls, "idelvls", integer = TRUE)
  if (length(idelvls) != 1L || is.na(idelvls) || idelvls < 2L) {
    stop("`idelvls` must be a single integer of at least 2", call. = FALSE)
  }
  shared <- intersect(names(ref), names(cur))
  added <- setdiff(names(cur), names(ref))
  removed <- setdiff(names(ref), names(cur))

  row <- function(nm, type, statistic = NA_real_, p_value = NA_real_,
                  psi = NA_real_, js = NA_real_, unseen = NA_real_,
                  drifted = NA, note = "") {
    data.frame(column = nm, type = type, statistic = statistic,
               p_value = p_value, psi = psi, jsdiv = js,
               unseen_share = unseen, drifted = drifted, note = note,
               stringsAsFactors = FALSE)
  }
  pg <- blprog("drift screen", length(shared))
  on.exit(pg$done(), add = TRUE)
  rows <- lapply(shared, function(nm) {
    pg$tick(info = nm)
    a <- ref[[nm]]
    b <- cur[[nm]]
    numeric_col <- is.numeric(a) && is.numeric(b)
    # a character column of dates is a numeric column in disguise: two
    # disjoint years of daily dates are a shift, not 730 unrelated labels
    if (!numeric_col) {
      da <- .rmbl_as_dates(a)
      db <- .rmbl_as_dates(b)
      if (!is.null(da) && !is.null(db)) {
        a <- da
        b <- db
        numeric_col <- TRUE
      }
    }
    type <- if (inherits(a, "Date") || inherits(a, "POSIXct")) "date" else
      if (numeric_col) "numeric" else "categorical"
    if (numeric_col) {
      av <- as.numeric(a[!is.na(a)])
      bv <- as.numeric(b[!is.na(b)])
      if (length(av) < 1L || length(bv) < 1L) {
        return(row(nm, type, note = "no non-missing values on one side"))
      }
      k <- drftks(av, bv)
      p <- drftpsi(av, bv, bins = bins)
      # The p-value is calibrated; the PSI band is a heuristic that only
      # means anything once both samples are large.
      psi_flag <- length(av) >= psiminn && length(bv) >= psiminn &&
        p[["psi"]] > psithr
      return(row(nm, type, statistic = k[["statistic"]], p_value = k[["p_value"]],
                 psi = p[["psi"]], js = p[["jsdiv"]],
                 drifted = k[["p_value"]] < alpha || psi_flag))
    }
    av <- as.character(a)
    bv <- as.character(b)
    av <- av[!is.na(av)]
    bv <- bv[!is.na(bv)]
    if (length(av) < 1L || length(bv) < 1L) {
      return(row(nm, "categorical", note = "no non-missing values on one side"))
    }
    unseen <- mean(!(bv %in% av))
    n_lv <- length(unique(c(av, bv)))
    # An identifier-like column -- a key, a postcode, free text: more
    # distinct values than `idelvls`, or a value for every
    # fifth row -- has no distribution to compare. Two independent
    # samples of the same 5,000 ids share about half their values, so a
    # divergence over the union of categories read 8.8 and fired on every
    # such column. The share of current rows the reference never saw is
    # reported; the verdict is NA, not a guess.
    # The ratio test needs levels behind it, not rows: on ten rows a
    # five-level factor has "a value for every fifth row" and 0.5.7 returned
    # no verdict for an ordinary small column, while 0.5.8's hundred-row gate
    # scored an 80-row id column as categorical with a PSI of 5 (its diff
    # review). A column with fewer than 20 distinct values is a factor.
    if (n_lv > idelvls ||
        (n_lv >= 20L && n_lv > 0.2 * (length(av) + length(bv)))) {
      return(row(nm, "identifier", unseen = unseen, drifted = NA,
                 note = sprintf("%d distinct values: distribution tests do not apply", n_lv)))
    }
    cs <- drfthomog(av, bv, seed = seed)
    # PSI over the REFERENCE's categories, with every current value the
    # reference lacks pooled into one bin: that is the index's definition
    # (expected bins, actual mass), and it stays near zero when the two
    # samples share a distribution
    lv <- unique(av)
    px <- c(as.numeric(table(factor(av, levels = lv))) / length(av), 0)
    py <- c(as.numeric(table(factor(bv, levels = lv))) / length(bv), unseen)
    ps <- .Call(C_rmbl_psi, px, py, 1e-6)
    psi_flag <- length(av) >= psiminn && length(bv) >= psiminn &&
      ps[[1L]] > psithr
    p_cat <- cs[["p_value"]]
    row(nm, "categorical", statistic = cs[["statistic"]], p_value = p_cat,
        psi = ps[[1L]], js = ps[[2L]], unseen = unseen,
        drifted = if (is.na(p_cat)) psi_flag || NA else p_cat < alpha || psi_flag,
        note = if (is.na(p_cat)) attr(cs, "method") else "")
  })

  cols <- if (length(rows)) do.call(rbind, rows) else
    data.frame(column = character(0), type = character(0),
               statistic = numeric(0), p_value = numeric(0),
               psi = numeric(0), jsdiv = numeric(0),
               unseen_share = numeric(0), drifted = logical(0),
               note = character(0), stringsAsFactors = FALSE)

  # the binned summaries a plot or a report draws from (never the rows themselves)
  summ <- stats::setNames(lapply(seq_along(shared), function(i) {
    .rmbl_drift_summ(ref[[shared[i]]], cur[[shared[i]]], cols$type[i], bins)
  }), shared)
  out <- list(columns = cols, added = added, removed = removed,
              nref = nrow(ref), ncur = nrow(cur),
              alpha = alpha, psithr = psithr, psiminn = psiminn,
              bands = c(warn = min(0.1, psithr), fail = psithr), summ = summ,
              anydrft = any(cols$drifted, na.rm = TRUE) ||
                length(added) > 0L || length(removed) > 0L)
  class(out) <- c("bricklayer_drift", "list")
  out
}


#' The binned summary of one shared column, for the drift plots and reports.
#'
#' What a reader needs to see where a column moved, and nothing that would reproduce its rows: the
#' missing shares, the non-missing sizes, summary statistics (numeric) or the ten largest categories,
#' the PSI bins with each bin's term of the index, a 30-bin histogram on the pooled 0.5-99.5% range
#' (one bin per value for whole numbers over a range under 60), densities and ECDFs on a 64-point grid
#' and matched quantiles (numeric), and the first-digit counts of both samples (numeric, not dates).
#' @param a,b The column in the reference and in the current frame.
#' @param type The column's type as cpsdrft() decided it.
#' @param bins The number of quantile bins (as for drftpsi()).
#' @return A list.
#' @noRd
.rmbl_drift_summ <- function(a, b, type, bins) {
  out <- list(missref = if (length(a)) mean(is.na(a)) else 0, misscur = if (length(b)) mean(is.na(b)) else 0)
  if (type %in% c("numeric", "date")) {
    if (type == "date") {
      a <- .rmbl_as_dates(a)
      b <- .rmbl_as_dates(b)
    }
    out$kind <- if (inherits(a, "Date")) "date" else if (inherits(a, "POSIXct")) "datetime" else "number"
    fmt <- function(v) .bl_drift_iso(v, out$kind)
    av <- as.numeric(a[!is.na(a)])
    bv <- as.numeric(b[!is.na(b)])
    out$nref <- length(av)
    out$ncur <- length(bv)
    if (!length(av) || !length(bv)) return(out)
    q <- function(v) {
      c(mean(v), if (length(v) > 1L) stats::sd(v) else NA_real_,
        stats::quantile(v, c(0, 0.25, 0.5, 0.75, 1), names = FALSE))
    }
    out$stats <- data.frame(stat = c("mean", "sd", "min", "q1", "median", "q3", "max"), ref = q(av), cur = q(bv),
                            stringsAsFactors = FALSE)
    s <- .rmbl_psi_shares(av, bv, bins)
    out$bins <- data.frame(bin = .rmbl_bin_labels(s$edges, fmt), ref = s$px, cur = s$py,
                           contrib = .rmbl_psi_terms(s$px, s$py), stringsAsFactors = FALSE)
    r <- stats::quantile(c(av, bv), c(0.005, 0.995), names = FALSE)
    whole <- all(c(av, bv) == round(c(av, bv))) && diff(range(c(av, bv))) < 60
    if (r[2L] <= r[1L]) r <- r + c(-0.5, 0.5)
    # whole numbers over a short range: one bin per value, so no bin falls between two integers and
    # draws a false gap (a day count over 30 bins narrower than 1)
    if (whole) r <- range(c(av, bv)) + c(-0.5, 0.5)
    br <- if (whole) seq(r[1L], r[2L], by = 1) else seq(r[1L], r[2L], length.out = 31L)
    nb <- length(br) - 1L
    h <- function(v) {
      tabulate(findInterval(pmin(pmax(v, r[1L]), r[2L]), br, rightmost.closed = TRUE, all.inside = TRUE),
               nb) / length(v)
    }
    out$hist <- data.frame(lo = br[-length(br)], hi = br[-1L], ref = h(av), cur = h(bv))
    out <- c(out, .rmbl_drift_curves(av, bv, r))
    if (type == "numeric") out$benford <- .rmbl_benford_pair(av, bv)
    return(out)
  }
  av <- as.character(a)
  bv <- as.character(b)
  av <- av[!is.na(av)]
  bv <- bv[!is.na(bv)]
  out$nref <- length(av)
  out$ncur <- length(bv)
  if (type != "categorical" || !length(av) || !length(bv)) return(out)
  lv <- unique(av)
  unseen <- mean(!(bv %in% av))
  px <- c(as.numeric(table(factor(av, levels = lv))) / length(av), 0)
  py <- c(as.numeric(table(factor(bv, levels = lv))) / length(bv), unseen)
  b <- data.frame(bin = c(lv, "(not in the reference)"), ref = px, cur = py, contrib = .rmbl_psi_terms(px, py),
                  stringsAsFactors = FALSE)
  out$bins <- b[c(rep(TRUE, length(lv)), unseen > 0), , drop = FALSE]
  pooled <- (out$bins$ref * length(av) + out$bins$cur * length(bv)) / (length(av) + length(bv))
  top <- utils::head(order(-pooled), 10L)
  out$top <- data.frame(category = out$bins$bin[top], ref = out$bins$ref[top], cur = out$bins$cur[top],
                        stringsAsFactors = FALSE)
  rownames(out$bins) <- NULL
  out
}

#' The smooth curves of a numeric column: densities and ECDFs on one grid, and matched quantiles.
#'
#' Both densities use one bandwidth (Silverman's, of the pooled values), so a difference between the
#' curves is a difference between the samples, not between two smoothings. 64 grid points over `r`.
#' @param av,bv The reference and current values, finite and non-empty.
#' @param r The range the grid covers.
#' @return A list: `dens` (x, ref, cur: densities), `ecdf` (x, ref, cur: shares at or below x) and `qq`
#'   (p, ref, cur: the quantiles at probabilities 0.02 to 0.98).
#' @noRd
.rmbl_drift_curves <- function(av, bv, r) {
  x <- seq(r[1L], r[2L], length.out = 64L)
  bw <- stats::bw.nrd0(c(av, bv))   # positive even for constant values (it falls back to |x| or 1)
  d <- function(v) stats::density(v, bw = bw, from = r[1L], to = r[2L], n = 64L)$y
  p <- seq(0.02, 0.98, by = 0.04)
  list(dens = data.frame(x = x, ref = d(av), cur = d(bv)),
       ecdf = data.frame(x = x, ref = stats::ecdf(av)(x), cur = stats::ecdf(bv)(x)),
       qq = data.frame(p = p, ref = stats::quantile(av, p, names = FALSE),
                       cur = stats::quantile(bv, p, names = FALSE)))
}

#' Writes values of a numeric, date or date-time column for a reader: ISO 8601 for the last two.
#' @param v The values as numbers (days or seconds since 1970-01-01 for dates and date-times).
#' @param kind \code{"number"}, \code{"date"} or \code{"datetime"}.
#' @return A character vector.
#' @noRd
.bl_drift_iso <- function(v, kind) {
  switch(kind,
    date = format(as.Date(v, origin = "1970-01-01")),
    datetime = format(as.POSIXct(v, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
    trimws(formatC(v, digits = 3, format = "g")))
}

#' Each bin's term of the population stability index, with drftpsi()'s default floor.
#' @param p,q The reference and current shares.
#' @return The terms, which add up to the index.
#' @noRd
.rmbl_psi_terms <- function(p, q) {
  a <- pmax(p, 1e-6)
  b <- pmax(q, 1e-6)
  (a - b) * log(a / b)
}

#' Labels for quantile bins: \dQuote{<= a}, \dQuote{(a, b]}, \dQuote{> b}.
#' @param edges The bin edges, from -Inf to Inf.
#' @param fmt The function that formats an edge.
#' @return One label per bin.
#' @noRd
.rmbl_bin_labels <- function(edges, fmt) {
  lo <- edges[-length(edges)]
  hi <- edges[-1L]
  ifelse(is.infinite(lo), paste0("<= ", fmt(hi)),
         ifelse(is.infinite(hi), paste0("> ", fmt(lo)), paste0("(", fmt(lo), ", ", fmt(hi), "]")))
}

#' First-digit counts of two samples and the current sample's Benford test.
#' @param av,bv The reference and current values, finite.
#' @return A list (`ref`, `cur`: counts of digits 1-9; `n`; `p_value`), or NULL when the current
#'   sample has no non-zero value.
#' @noRd
.rmbl_benford_pair <- function(av, bv) {
  digits <- function(v) {
    v <- v[v != 0]
    if (length(v)) as.numeric(.Call(C_rmbl_first_digit_counts, v)) else rep(0, 9L)
  }
  k <- digits(bv)
  n <- sum(k)
  if (!n) return(NULL)
  e <- n * log10(1 + 1 / (1:9))
  list(ref = digits(av), cur = k, n = n, p_value = .rmbl_chisq_p(sum((k - e)^2 / e), 8L))
}

#' Reads a column of ISO dates or date-times as dates.
#'
#' A character vector that is entirely ISO dates or date-times, as Date /
#' POSIXct; NULL when any value is not (a numeric comparison then makes no
#' sense). NAs are allowed and kept.
#' @param v The column.
#' @return A Date or POSIXct vector, or NULL.
#' @noRd
.rmbl_as_dates <- function(v) {
  if (inherits(v, "Date") || inherits(v, "POSIXct")) return(v)
  if (!is.character(v) && !is.factor(v)) return(NULL)
  v <- as.character(v)
  ok <- !is.na(v)
  if (!any(ok)) return(NULL)
  # a value that looks like a date but is not one ("2020-01-01 25:99")
  # makes the column text, not an error: as.POSIXct() with tryFormats
  # stops on the first unreadable string
  if (all(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", v[ok]))) {
    d <- tryCatch(as.Date(v, format = "%Y-%m-%d"), error = function(e) NULL)
    return(if (is.null(d) || anyNA(d[ok])) NULL else d)
  }
  if (all(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}(:[0-9]{2})?", v[ok]))) {
    d <- tryCatch(as.POSIXct(sub("T", " ", v, fixed = TRUE), tz = "UTC",
                             tryFormats = c("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M")),
                  error = function(e) NULL)
    return(if (is.null(d) || anyNA(d[ok])) NULL else d)
  }
  NULL
}
