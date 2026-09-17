# SPDX-License-Identifier: AGPL-3.0-or-later

#' Exact p-values for the rows of a year-over-year table
#'
#' For count units the interval in [yoy()] is the exact conditional
#' binomial interval for the ratio of two Poisson means; this is the
#' matching two-sided test, so a scan over many groups can be corrected
#' for multiple comparisons with
#' [scan_adjust()]. The test conditions on
#' the total of the two periods and asks whether the split is
#' compatible with equal means.
#'
#' @param y An `rmbl_yoy` object with count units.
#' @return `y` with a `p_value` column; `NA` where there is no
#'   comparison period or both counts are zero.
#' @examples
#' seg <- data.frame(year = rep(2022:2023, each = 3),
#'                   site = rep(c("A", "B", "C"), 2),
#'                   n = c(30, 50, 80, 45, 52, 79))
#' y <- yoy(seg, value = "n", period = "year", by = "site")
#' yoy_pvalues(y)$p_value
#' @export
yoy_pvalues <- function(y) {
  if (!inherits(y, "rmbl_yoy")) {
    stop("`y` must come from yoy()", call. = FALSE)
  }
  m <- attr(y, "yoy")
  if (!identical(m$units, "count")) {
    stop("exact p-values need count units; yoy() was run with units = \"",
         m$units, "\"", call. = FALSE)
  }
  y$p_value <- .exact_ratio_p(y$value, y$previous)
  y
}

# Two-sided exact conditional test of v1 / w1 == v2 / w2 for Poisson
# counts: given the total, v1 ~ Binomial(v1 + v2, w1 / (w1 + w2)).
.exact_ratio_p <- function(v1, v2, w1 = 1, w2 = 1) {
  n <- length(v1)
  w1 <- rep_len(w1, n)
  w2 <- rep_len(w2, n)
  p <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    if (is.na(v1[i]) || is.na(v2[i]) || is.na(w1[i]) || is.na(w2[i])) next
    tot <- v1[i] + v2[i]
    if (tot <= 0 || w1[i] <= 0 || w2[i] <= 0) next
    p[i] <- stats::binom.test(round(v1[i]), round(tot),
                              p = w1[i] / (w1[i] + w2[i]))$p.value
  }
  p
}

#' Adjust a scan of many comparisons for multiple testing
#'
#' A change table over fifty institutions is fifty tests. Reporting the
#' raw p-values invites reading the largest of fifty noise draws as a
#' finding. This adds `p_adjusted` (Benjamini-Hochberg by default, which
#' controls the false discovery rate over the scan) and `significant`
#' at level `alpha` after adjustment. Exact p-values are computed where
#' the object does not carry them: the conditional binomial test for
#' [yoy()] counts and for [rate_change()]
#' (with the exposures as the
#' binomial weights).
#'
#' @param x An `rmbl_yoy` or `rmbl_rate_change` object, or any data frame
#'   with a `p_value` column.
#' @param method Adjustment passed to [stats::p.adjust()];
#'   `"BH"`
#'   (false discovery rate) by default, `"holm"` for family-wise control.
#' @param alpha Level at which `significant` is decided.
#' @return `x` with `p_value` (if it was missing), `p_adjusted` and
#'   `significant`; the class and attributes of `x` are kept.
#' @examples
#' seg <- data.frame(year = rep(2022:2023, each = 3),
#'                   site = rep(c("A", "B", "C"), 2),
#'                   n = c(30, 50, 80, 45, 52, 79))
#' y <- yoy(seg, value = "n", period = "year", by = "site")
#' scan_adjust(y)[, c("site", "pct_change", "p_value", "p_adjusted")]
#' @export
scan_adjust <- function(x, method = "BH", alpha = 0.05) {
  if (!is.data.frame(x)) {
    stop("`x` must be a data frame", call. = FALSE)
  }
  if (inherits(x, "rmbl_yoy") && is.null(x$p_value)) {
    x <- yoy_pvalues(x)
  } else if (inherits(x, "rmbl_rate_change") && is.null(x$p_value)) {
    x$p_value <- .exact_ratio_p(x$count, x$previous_count,
                                x$population, x$previous_population)
  } else if (is.null(x$p_value)) {
    stop(paste0("`x` has no `p_value` column and is not a yoy() or ",
                "rate_change() result"), call. = FALSE)
  }
  ok <- !is.na(x$p_value)
  adj <- rep(NA_real_, nrow(x))
  if (any(ok)) adj[ok] <- stats::p.adjust(x$p_value[ok], method = method)
  x$p_adjusted <- adj
  x$significant <- !is.na(adj) & adj < alpha
  attr(x, "scan_adjust") <- list(method = method, alpha = alpha,
                                 tests = sum(ok))
  x
}

#' Calibrate the drift screens on data known not to have drifted
#'
#' [capsule_drift()] flags a column when a
#' Kolmogorov-Smirnov, chi-square
#' or population-stability screen fires. How often that happens when
#' nothing has changed is the false-alarm rate of the screen on this
#' capsule, and it depends on the columns, their sizes and `alpha`. This
#' estimates it by splitting the same data at random into two halves
#' `n` times and running the screens on the halves, which is the null of
#' "a re-fetch of identical data". A capsule whose screens fire on 30% of
#' identical re-fetches needs a smaller `alpha` or fewer screened
#' columns before a drift verdict means anything.
#'
#' @param data The capsule's data frame.
#' @param n Number of random half-splits.
#' @param alpha Significance level passed to [capsule_drift()].
#' @param seed Seed for the splits.
#' @param ... Passed to [capsule_drift()].
#' @return A list of class `rmbl_drift_calibration`: `columns` (per
#'   column, the share of splits on which it was flagged), `any_flag`
#'   (share of splits with at least one flag), `alpha`, `n`, and
#'   `alpha_familywise` (the per-screen level that would hold the
#'   family-wise false-alarm rate at `alpha`, Bonferroni).
#' @examples
#' set.seed(1)
#' d <- data.frame(a = rnorm(400), b = sample(letters[1:4], 400, TRUE))
#' drift_calibrate(d, n = 10)
#' @export
drift_calibrate <- function(data, n = 50L, alpha = 0.01, seed = 1L, ...) {
  if (!is.data.frame(data) || nrow(data) < 4L) {
    stop("`data` must be a data frame with at least four rows",
         call. = FALSE)
  }
  n <- as.integer(n)
  .rmbl_local_seed(seed)
  hits <- NULL
  any_flag <- logical(n)
  for (i in seq_len(n)) {
    idx <- sample.int(nrow(data), nrow(data) %/% 2L)
    res <- capsule_drift(data[idx, , drop = FALSE],
                         data[-idx, , drop = FALSE], alpha = alpha, ...)
    cols <- res$columns
    flagged <- !is.na(cols$drifted) & cols$drifted
    if (is.null(hits)) hits <- stats::setNames(numeric(nrow(cols)), cols$column)
    hits[cols$column] <- hits[cols$column] + as.numeric(flagged)
    any_flag[i] <- any(flagged)
  }
  columns <- data.frame(column = names(hits), false_alarm_rate = hits / n,
                        stringsAsFactors = FALSE)
  structure(list(columns = columns, any_flag = mean(any_flag), alpha = alpha,
                 n = n, alpha_familywise = alpha / max(1L, nrow(columns))),
            class = "rmbl_drift_calibration")
}

#' @export
print.rmbl_drift_calibration <- function(x, ...) {
  cat(sprintf("Drift screens on %d identical re-fetches (alpha = %g)\n",
              x$n, x$alpha))
  cat(sprintf("  at least one column flagged: %.0f%% of re-fetches\n",
              100 * x$any_flag))
  worst <- x$columns[order(-x$columns$false_alarm_rate), , drop = FALSE]
  worst <- worst[worst$false_alarm_rate > 0, , drop = FALSE]
  if (nrow(worst)) {
    cat("  columns that fire on identical data:\n")
    for (i in seq_len(min(8L, nrow(worst)))) {
      cat(sprintf("    %-28s %5.1f%%\n", worst$column[i],
                  100 * worst$false_alarm_rate[i]))
    }
  } else {
    cat("  no column fired on identical data\n")
  }
  cat(sprintf("  per-screen alpha for a family-wise %g: %.2g\n",
              x$alpha, x$alpha_familywise))
  invisible(x)
}
