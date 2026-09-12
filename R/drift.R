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
#' The largest vertical gap between the two empirical distribution
#' functions, with the asymptotic two-sided p-value from the Kolmogorov
#' distribution. Distribution-free: it assumes nothing about the shape of
#' either sample, which is what makes it the right first test on a column
#' whose distribution was never specified.
#'
#' The p-value is the ASYMPTOTIC one, \eqn{2\sum_k (-1)^{k-1}
#' e^{-2k^2t^2}} with \eqn{t = \sqrt{n_{\mathrm{eff}}}D}. It is accurate
#' for moderate samples and conservative for small ones; for an exact
#' small-sample p-value use [stats::ks.test()]. Ties are handled by
#' comparing the two EDFs at each distinct value, so tied data does not
#' produce a warning the way `ks.test()` does.
#'
#' @param x,y Numeric vectors, the reference and the new sample.
#' @return A named length-3 numeric: `statistic` (the KS \eqn{D}),
#'   `p_value`, and `n_eff` (the harmonic-style effective size
#'   \eqn{n_xn_y/(n_x+n_y)}).
#' @seealso [drift_psi()], [drift_chisq()], [capsule_drift()]
#' @examples
#' set.seed(1)
#' ref <- stats::rnorm(200)
#'
#' # The same distribution: a small D and a large p-value.
#' drift_ks(ref, stats::rnorm(200))
#'
#' # A shifted distribution is detected.
#' drift_ks(ref, stats::rnorm(200, mean = 0.8))
#'
#' # So is a change in spread alone, which a mean comparison would miss.
#' drift_ks(ref, stats::rnorm(200, sd = 2.5))
#'
#' # The statistic agrees with stats::ks.test().
#' a <- stats::rnorm(60); b <- stats::rnorm(45, 0.6)
#' all.equal(drift_ks(a, b)[["statistic"]],
#'           as.numeric(suppressWarnings(stats::ks.test(a, b))$statistic))
#'
#' # Identical samples have nothing to report.
#' drift_ks(ref, ref)[["statistic"]]
#' @export
drift_ks <- function(x, y) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  x <- x[!is.na(x)]
  y <- y[!is.na(y)]
  if (length(x) < 1L || length(y) < 1L) {
    stop("both samples must have at least one non-missing value",
         call. = FALSE)
  }
  out <- .Call(C_rmbl_ks, x, y)
  names(out) <- c("statistic", "p_value", "n_eff")
  out
}

#' Population stability index and Jensen-Shannon divergence (C backend)
#'
#' Two summaries of how far a new binned distribution has moved from a
#' reference one.
#'
#' The population stability index is
#' \eqn{\sum_i (p_i - q_i)\log(p_i/q_i)} -- the symmetrised
#' Kullback-Leibler divergence of the two discrete distributions. The
#' conventional reading, from credit-risk monitoring where it originates,
#' is that below 0.1 is stable, 0.1 to 0.25 warrants a look, and above
#' 0.25 is a material shift.
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
#' @param x,y Numeric vectors, the reference and the new sample. Binned
#'   on the quantiles of `x`, so the reference defines the bins.
#' @param bins Number of bins (default 10).
#' @param eps Floor applied to empty bins in the PSI (default 1e-6).
#' @return A named length-2 numeric: `psi` and `js_divergence`.
#' @references Wu D, Olson DL (2010). Enterprise risk management:
#'   coping with model risk in a large bank. *Journal of the Operational
#'   Research Society* 61(2), 179--190. \doi{10.1057/jors.2008.144}
#'
#'   Lin J (1991). Divergence measures based on the Shannon entropy.
#'   *IEEE Transactions on Information Theory* 37(1), 145--151.
#'   \doi{10.1109/18.61115}
#' @examples
#' set.seed(2)
#' ref <- stats::rnorm(500)
#'
#' # Same distribution: both indices near zero.
#' drift_psi(ref, stats::rnorm(500))
#'
#' # A shift both indices register.
#' drift_psi(ref, stats::rnorm(500, mean = 1))
#'
#' # A sample compared with itself has moved nowhere at all.
#' drift_psi(ref, ref)
#'
#' # The Jensen-Shannon divergence is bounded by log(2), whatever the
#' # shift, which is what makes it comparable across columns.
#' drift_psi(c(1, 1, 1), c(9, 9, 9))[["js_divergence"]] <= log(2)
#' @export
drift_psi <- function(x, y, bins = 10L, eps = 1e-6) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  x <- x[!is.na(x)]
  y <- y[!is.na(y)]
  if (length(x) < 1L || length(y) < 1L) {
    stop("both samples must have at least one non-missing value",
         call. = FALSE)
  }
  bins <- as.integer(bins)
  if (is.na(bins) || bins < 2L) {
    stop("`bins` must be at least 2", call. = FALSE)
  }
  # The reference defines the bin edges, so the comparison asks where the
  # NEW sample sits relative to the pinned one.
  probs <- seq(0, 1, length.out = bins + 1L)
  edges <- unique(.Call(C_rmbl_quantile, x, probs))
  if (length(edges) < 2L) {
    # A constant reference column has no spread to bin; fall back to
    # comparing presence at that single value.
    edges <- c(edges[1L] - 0.5, edges[1L] + 0.5)
  }
  edges[1L] <- -Inf
  edges[length(edges)] <- Inf
  px <- as.numeric(table(cut(x, edges))) / length(x)
  py <- as.numeric(table(cut(y, edges))) / length(y)
  out <- .Call(C_rmbl_psi, px, py, as.numeric(eps))
  names(out) <- c("psi", "js_divergence")
  out
}

#' Chi-square test for a categorical column
#'
#' Pearson's chi-square goodness-of-fit statistic comparing observed
#' category counts with the proportions a capsule was pinned against.
#' Use it where [drift_ks()] cannot apply, because the column is a factor
#' or a set of codes rather than a number.
#'
#' Categories present in one argument and not the other are aligned by
#' name, so a vanished category registers as a shortfall against its
#' expected count.
#'
#' A category that OCCURS but which the reference gives probability zero
#' contradicts the pinned distribution outright, and its chi-square term
#' is unbounded; `statistic` is then `Inf` and `p_value` is `0`. If a new
#' category is a legitimate possibility rather than a contradiction --
#' which it usually is when the reference is itself a finite sample --
#' use [drift_homogeneity()] instead.
#'
#' @param observed Named numeric vector of counts in the new sample, or a
#'   factor/character vector to be tabulated.
#' @param expected Named numeric vector of reference counts or
#'   proportions, or a factor/character vector to be tabulated. Rescaled
#'   to the total of `observed`.
#' @return A named length-3 numeric: `statistic`, `df`, `p_value`.
#' @seealso [stats::chisq.test()] for the full test object.
#' @examples
#' ref <- c(a = 50, b = 30, c = 20)
#'
#' # Counts matching the reference proportions: nothing to report.
#' drift_chisq(c(a = 100, b = 60, c = 40), ref)
#'
#' # A reallocated mix is detected.
#' drift_chisq(c(a = 40, b = 60, c = 100), ref)
#'
#' # Agrees with stats::chisq.test().
#' o <- c(a = 40, b = 60, c = 100)
#' all.equal(drift_chisq(o, ref)[["statistic"]],
#'           as.numeric(stats::chisq.test(o, p = ref / sum(ref))$statistic))
#'
#' # Raw vectors are tabulated for you.
#' drift_chisq(c("a", "a", "b", "b"), c("a", "b"))
#'
#' # A category the reference rules out, but which occurs, is a flat
#' # contradiction rather than a large finite statistic.
#' drift_chisq(c("a", "a", "b", "d"), c("a", "a", "b", "b"))
#'
#' # When a new category is legitimate, compare two samples instead.
#' drift_homogeneity(c("a", "a", "b", "b"), c("a", "a", "b", "d"))
#' @export
drift_chisq <- function(observed, expected) {
  tab <- function(v) {
    if (is.factor(v) || is.character(v)) {
      t <- table(v)
      stats::setNames(as.numeric(t), names(t))
    } else {
      nm <- names(v)
      if (is.null(nm)) {
        stop("a numeric `observed`/`expected` must be named", call. = FALSE)
      }
      stats::setNames(as.numeric(v), nm)
    }
  }
  o <- tab(observed)
  e <- tab(expected)
  lv <- union(names(o), names(e))
  o <- stats::setNames(ifelse(is.na(o[lv]), 0, o[lv]), lv)
  e <- stats::setNames(ifelse(is.na(e[lv]), 0, e[lv]), lv)
  if (sum(o) <= 0) stop("`observed` has no counts", call. = FALSE)
  if (sum(e) <= 0) stop("`expected` has no counts", call. = FALSE)
  # Reference proportions, scaled to the observed total.
  exp_counts <- sum(o) * e / sum(e)
  keep <- exp_counts > 0
  if (!any(keep)) stop("no category has a positive expected count",
                       call. = FALSE)
  df <- max(1L, sum(keep) - 1L)
  # A category the reference assigns probability zero, yet which occurs,
  # contradicts the pinned distribution outright: the chi-square term
  # for it diverges. Report that rather than dropping the category and
  # returning a statistic computed as though it had not appeared.
  if (any(o[!keep] > 0)) {
    return(c(statistic = Inf, df = df, p_value = 0))
  }
  stat <- sum((o[keep] - exp_counts[keep])^2 / exp_counts[keep])
  c(statistic = stat, df = df,
    p_value = 1 - core_gamma_cdf(df / 2, stat / 2))
}

#' Chi-square test of homogeneity for two categorical samples
#'
#' Tests whether two SAMPLES were drawn from the same categorical
#' distribution, by Pearson's chi-square on the 2-by-k contingency table
#' of their counts.
#'
#' # Why this and not [drift_chisq()]
#'
#' [drift_chisq()] compares observed counts against a distribution taken
#' as KNOWN -- proportions fixed by a specification. When the reference is
#' itself a finite sample, that treatment ignores the reference's own
#' sampling error, understates the variance of the comparison, and so
#' reports drift too readily. A homogeneity test estimates the shared
#' distribution from the pooled margins and carries the uncertainty of
#' both samples, which is the right test when comparing a pinned extract
#' with a fresh fetch. [capsule_drift()] therefore uses this one.
#'
#' Categories present in only one sample are aligned by name and given
#' zero counts, so an appearing or vanishing level registers.
#'
#' @param x,y Factor or character vectors (or named count vectors) --
#'   the reference and the new sample.
#' @return A named length-3 numeric: `statistic`, `df`, `p_value`.
#' @seealso [drift_chisq()] for a known reference distribution,
#'   [stats::chisq.test()] for the full test object.
#' @examples
#' set.seed(1)
#' a <- sample(c("x", "y", "z"), 300, TRUE)
#' b <- sample(c("x", "y", "z"), 300, TRUE)
#'
#' # Two draws from the same distribution: no evidence of a difference.
#' drift_homogeneity(a, b)
#'
#' # A reallocated mix is detected.
#' drift_homogeneity(a, sample(c("x", "y", "z"), 300, TRUE,
#'                             prob = c(0.7, 0.2, 0.1)))
#'
#' # Agrees with stats::chisq.test() on the 2-by-k table.
#' tab <- rbind(table(a), table(b))
#' all.equal(drift_homogeneity(a, b)[["statistic"]],
#'           as.numeric(stats::chisq.test(tab)$statistic))
#'
#' # It is more conservative than treating the reference as known, which
#' # is exactly the point.
#' drift_homogeneity(a, b)[["p_value"]] >= drift_chisq(b, a)[["p_value"]]
#' @export
drift_homogeneity <- function(x, y) {
  tab <- function(v) {
    if (is.factor(v) || is.character(v)) {
      t <- table(as.character(v))
      stats::setNames(as.numeric(t), names(t))
    } else {
      nm <- names(v)
      if (is.null(nm)) {
        stop("a numeric `x`/`y` must be named", call. = FALSE)
      }
      stats::setNames(as.numeric(v), nm)
    }
  }
  cx <- tab(x)
  cy <- tab(y)
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
  keep <- pooled > 0
  if (!any(keep)) {
    stop("no category has a positive expected count", call. = FALSE)
  }
  stat <- sum((cx[keep] - ex[keep])^2 / ex[keep]) +
    sum((cy[keep] - ey[keep])^2 / ey[keep])
  df <- max(1L, sum(keep) - 1L)
  c(statistic = stat, df = df,
    p_value = 1 - core_gamma_cdf(df / 2, stat / 2))
}

#' Benford first-digit test
#'
#' Compares the distribution of leading significant digits in `x` with
#' Benford's law, \eqn{P(d) = \log_{10}(1 + 1/d)}. Naturally occurring
#' quantities that span several orders of magnitude follow it closely;
#' figures that were rounded, truncated, capped, re-scaled, or invented
#' typically do not. That makes it a cheap screen for a numeric column
#' that arrived looking plausible but is not the measurement it claims to
#' be.
#'
#' It is a SCREEN, not a verdict. Columns with a narrow range, a unit
#' floor or ceiling, or an assigned-identifier structure (postcodes, year
#' fields, prices ending in 99) legitimately violate Benford's law. Treat
#' a small p-value as a reason to look, never as evidence of fabrication.
#'
#' Zeros and non-finite values have no leading significant digit and are
#' excluded; the sign is ignored.
#'
#' @param x Numeric vector.
#' @return A list of class `bricklayer_benford`: `counts` (observed
#'   digit frequencies 1--9), `expected`, `proportion`,
#'   `statistic`, `df`, `p_value`, and `n`.
#' @references Benford F (1938). The law of anomalous numbers.
#'   *Proceedings of the American Philosophical Society* 78(4), 551--572.
#' @examples
#' # A quantity spanning several orders of magnitude follows the law.
#' set.seed(3)
#' benford_test(10^stats::runif(2000, 0, 6))
#'
#' # Digits drawn uniformly do not.
#' benford_test(as.numeric(paste0(sample(1:9, 2000, TRUE), "000")))
#'
#' # The expected proportions are the closed form.
#' b <- benford_test(10^stats::runif(500, 0, 5))
#' all.equal(b$expected / b$n, log10(1 + 1 / (1:9)))
#'
#' # Zeros carry no leading digit and are excluded from n.
#' benford_test(c(0, 0, 1, 2, 3))$n
#' @export
benford_test <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x) & x != 0]
  if (length(x) < 1L) {
    stop("`x` has no finite non-zero values to take a leading digit from",
         call. = FALSE)
  }
  counts <- .Call(C_rmbl_first_digit_counts, x)
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
              p_value = 1 - core_gamma_cdf(df / 2, stat / 2),
              n = n)
  class(out) <- c("bricklayer_benford", "list")
  out
}

#' Compare a fetched data frame with the one a capsule was pinned against
#'
#' Runs the appropriate drift test on every shared column and collects
#' the verdicts in one report: [drift_ks()] plus [drift_psi()] for a
#' numeric column, [drift_homogeneity()] for a categorical one. Columns
#' that appeared or vanished are listed separately, since no test applies
#' to them.
#'
#' The categorical test is the two-sample homogeneity test, NOT
#' [drift_chisq()]'s goodness-of-fit against a known distribution: the
#' reference here is itself a finite sample, and ignoring its sampling
#' error would report drift too readily.
#'
#' This is the check that a byte-level digest cannot make. A re-released
#' extract legitimately has a different SHA-256 while being the same data
#' statistically; conversely a column can keep its name, type and row
#' count while having been silently rescaled. `capsule_drift()` asks
#' whether the DATA moved.
#'
#' @param reference Data frame the capsule was built from.
#' @param current Data frame just fetched.
#' @param alpha Significance level for the `drifted` flag (default 0.01;
#'   deliberately stricter than 0.05 because a wide table runs many
#'   tests).
#' @param psi_threshold PSI above which a numeric column is flagged even
#'   when its p-value is not significant (default 0.25, the conventional
#'   "material shift" line).
#' @param psi_min_n Minimum size BOTH samples must reach before
#'   `psi_threshold` is allowed to flag a column on its own (default
#'   1000). The PSI bands are large-sample heuristics with no calibrated
#'   null distribution: on a few hundred rows, binning noise alone
#'   routinely pushes the index past 0.25, so applying the threshold
#'   there manufactures drift. Below this size the flag rests on the
#'   Kolmogorov-Smirnov p-value, which is calibrated, and the PSI is
#'   still reported as an effect size.
#' @param bins Bins passed to [drift_psi()] (default 10).
#' @return A list of class `bricklayer_drift`: `columns` (a data frame,
#'   one row per shared column, with `column`, `type`, `statistic`,
#'   `p_value`, `psi`, `js_divergence` and `drifted`), `added`,
#'   `removed`, `n_reference`, `n_current`, `alpha`, and `any_drift`.
#' @seealso [validate_schema()] for the structural check, which this
#'   complements rather than replaces.
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
#' d <- capsule_drift(ref, same)
#' d$any_drift
#'
#' # A silently rescaled column, and a new category, are both caught.
#' moved <- same
#' moved$size <- moved$size * 3
#' moved$grade[1:100] <- "z"
#' capsule_drift(ref, moved)
#'
#' # The PSI is always reported as an effect size, but on a sample this
#' # small it is not allowed to raise the flag by itself -- binning noise
#' # alone would clear 0.25. Lower psi_min_n to override that.
#' capsule_drift(ref, same)$columns$psi
#'
#' # Structural changes are reported rather than tested.
#' capsule_drift(ref, same[, c("value", "grade")])$removed
#' @export
capsule_drift <- function(reference, current, alpha = 0.01,
                          psi_threshold = 0.25, psi_min_n = 1000L,
                          bins = 10L) {
  if (!is.data.frame(reference) || !is.data.frame(current)) {
    stop("`reference` and `current` must both be data frames", call. = FALSE)
  }
  alpha <- as.numeric(alpha)
  if (length(alpha) != 1L || is.na(alpha) || alpha <= 0 || alpha >= 1) {
    stop("`alpha` must be a single value strictly inside (0, 1)",
         call. = FALSE)
  }
  psi_min_n <- as.integer(psi_min_n)
  if (length(psi_min_n) != 1L || is.na(psi_min_n) || psi_min_n < 0L) {
    stop("`psi_min_n` must be a single non-negative integer", call. = FALSE)
  }
  shared <- intersect(names(reference), names(current))
  added <- setdiff(names(current), names(reference))
  removed <- setdiff(names(reference), names(current))

  rows <- lapply(shared, function(nm) {
    a <- reference[[nm]]
    b <- current[[nm]]
    numeric_col <- is.numeric(a) && is.numeric(b)
    if (numeric_col) {
      av <- a[!is.na(a)]
      bv <- b[!is.na(b)]
      if (length(av) < 1L || length(bv) < 1L) {
        return(data.frame(column = nm, type = "numeric",
                          statistic = NA_real_, p_value = NA_real_,
                          psi = NA_real_, js_divergence = NA_real_,
                          drifted = NA, stringsAsFactors = FALSE))
      }
      k <- drift_ks(av, bv)
      p <- drift_psi(av, bv, bins = bins)
      # The p-value is calibrated; the PSI band is a heuristic that only
      # means anything once both samples are large.
      psi_flag <- length(av) >= psi_min_n && length(bv) >= psi_min_n &&
        p[["psi"]] > psi_threshold
      data.frame(column = nm, type = "numeric",
                 statistic = k[["statistic"]], p_value = k[["p_value"]],
                 psi = p[["psi"]], js_divergence = p[["js_divergence"]],
                 drifted = k[["p_value"]] < alpha || psi_flag,
                 stringsAsFactors = FALSE)
    } else {
      av <- as.character(a)
      bv <- as.character(b)
      av <- av[!is.na(av)]
      bv <- bv[!is.na(bv)]
      if (length(av) < 1L || length(bv) < 1L) {
        return(data.frame(column = nm, type = "categorical",
                          statistic = NA_real_, p_value = NA_real_,
                          psi = NA_real_, js_divergence = NA_real_,
                          drifted = NA, stringsAsFactors = FALSE))
      }
      cs <- drift_homogeneity(av, bv)
      data.frame(column = nm, type = "categorical",
                 statistic = cs[["statistic"]], p_value = cs[["p_value"]],
                 psi = NA_real_, js_divergence = NA_real_,
                 drifted = cs[["p_value"]] < alpha,
                 stringsAsFactors = FALSE)
    }
  })

  cols <- if (length(rows)) do.call(rbind, rows) else
    data.frame(column = character(0), type = character(0),
               statistic = numeric(0), p_value = numeric(0),
               psi = numeric(0), js_divergence = numeric(0),
               drifted = logical(0), stringsAsFactors = FALSE)

  out <- list(columns = cols, added = added, removed = removed,
              n_reference = nrow(reference), n_current = nrow(current),
              alpha = alpha,
              any_drift = any(cols$drifted, na.rm = TRUE) ||
                length(added) > 0L || length(removed) > 0L)
  class(out) <- c("bricklayer_drift", "list")
  out
}
