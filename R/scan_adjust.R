# SPDX-License-Identifier: AGPL-3.0-or-later

#' Exact p-values for the rows of a year-over-year table
#'
#' @description
#' Adds a two-sided exact p-value to each row of a period-over-period change
#' table of counts from \code{\link{yoy}}, testing whether the count changed
#' by more than chance between the two periods. Use it when you want a test
#' to go with each change, and then pass the table to
#' \code{\link{scanadj}} to correct for the number of rows tested.
#'
#' @details
#' For count units the interval in [yoy()] is the exact conditional
#' binomial interval for the ratio of two Poisson means; this is the
#' matching two-sided test. The test conditions on
#' the total of the two periods and asks whether the split is
#' compatible with equal means: with current count \eqn{a} and previous
#' count \eqn{b}, \eqn{a \sim \mathrm{Binomial}(a + b, 1/2)} under the null,
#' and the p-value is that of \code{stats::binom.test(a, a + b, p = 0.5)}.
#' The two periods are treated as having equal exposure; for changing
#' populations use \code{\link{ratechg}} and \code{\link{scanadj}},
#' which weight by the exposures. Counts are rounded to whole numbers.
#'
#' Errors: \code{y} not a \code{yoy()} result; a \code{yoy()} result whose
#' units are not counts (percentages and measured values have no Poisson
#' test). A progress indicator is shown for long tables in an interactive
#' session.
#'
#' @param y An \code{rmbl_yoy} object from \code{\link{yoy}} with
#'   \code{units = "count"}.
#' @return \code{y}, with its class and attributes, and an added numeric
#'   \code{p_value} column; \code{NA} where there is no comparison period or
#'   both counts are zero.
#' @seealso \code{\link{scanadj}}, \code{\link{yoy}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' seg <- data.frame(year = rep(2022:2023, each = 3),
#'                   site = rep(c("A", "B", "C"), 2),
#'                   n = c(30, 50, 80, 45, 52, 79))
#' y <- yoy(seg, value = "n", prd = "year", by = "site")
#' yoypv(y)$p_value
#'
#' # the same test by hand for site A: 45 against 30
#' stats::binom.test(45, 75)$p.value
#'
#' # anything that is not a yoy() table is refused
#' try(yoypv(seg))
#' @export
yoypv <- function(y) {
  if (!inherits(y, "rmbl_yoy")) {
    stop("yoypv: `y` must come from yoy()", call. = FALSE)
  }
  m <- attr(y, "yoy")
  if (!identical(m$units, "count")) {
    stop("exact p-values need count units; yoy() was run with units = \"",
         m$units, "\"", call. = FALSE)
  }
  y$p_value <- .exact_ratio_p(y$value, y$previous)
  y
}

#' Computes exact conditional p-values for the equality of two Poisson rates.
#'
#' Two-sided exact conditional test of v1 / w1 == v2 / w2 for Poisson
#' counts: given the total, v1 ~ Binomial(v1 + v2, w1 / (w1 + w2)).
#' @param v1 The first counts.
#' @param v2 The second counts.
#' @param w1 The first exposures, recycled.
#' @param w2 The second exposures, recycled.
#' @return A vector of p-values, NA where a comparison cannot be made.
#' @noRd
.exact_ratio_p <- function(v1, v2, w1 = 1, w2 = 1) {
  n <- length(v1)
  w1 <- rep_len(w1, n)
  w2 <- rep_len(w2, n)
  p <- rep(NA_real_, n)
  pg <- blprog("exact p-values", n)
  on.exit(pg$done(), add = TRUE)
  for (i in seq_len(n)) {
    pg$update(i - 1L, sprintf("comparison %d/%d", i, n))
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
#' @description
#' A change table over fifty institutions is fifty tests. Reporting the
#' raw p-values invites reading the largest of fifty noise draws as a
#' finding. This adds `padj` (Benjamini-Hochberg by default, which
#' controls the false discovery rate over the scan) and `significant`
#' at level `alpha` after adjustment. Exact p-values are computed where
#' the object does not carry them: the conditional binomial test for
#' [yoy()] counts and for [ratechg()]
#' (with the exposures as the
#' binomial weights).
#'
#' @details
#' For a \code{ratechg()} table, conditional on the two counts' total
#' the current count is binomial with success probability
#' \eqn{t_a / (t_a + t_b)}, the share of the combined exposure in the
#' current period, and the p-value is the two-sided exact binomial test of
#' that. Rows without a p-value (no comparison period, both counts zero)
#' are left out of the adjustment, so the number of tests is the number of
#' rows with a p-value; it is recorded in the \code{scanadj} attribute.
#'
#' The adjustment is \code{stats::p.adjust(p, method)}: \code{"BH"} controls
#' the expected proportion of false discoveries among the rows declared
#' significant, which suits a screen; \code{"holm"} and \code{"bonferroni"}
#' control the chance of any false discovery, which a claim about one
#' specific row needs. A row is \code{significant} when its adjusted p-value
#' is strictly below \code{alpha}.
#'
#' Errors: \code{x} not a data frame; no \code{p_value} column and not a
#' \code{yoy()} or \code{ratechg()} result; a \code{yoy()} result
#' without count units; a p-value outside \eqn{[0, 1]}; a method unknown to
#' \code{p.adjust()}.
#'
#' @param x An \code{rmbl_yoy} or \code{rmbl_rate_change} object, or any
#'   data frame with a \code{p_value} column.
#' @param meth Character, default \code{"BH"}. It can be any method of
#'   \code{\link[stats]{p.adjust}} (\code{"BH"}, \code{"holm"},
#'   \code{"bonferroni"}, \code{"BY"}, \code{"hochberg"}, \code{"hommel"},
#'   \code{"fdr"}, \code{"none"}).
#' @param alpha Number, default 0.05: the level at which \code{significant}
#'   is decided, applied to the adjusted p-values.
#' @return \code{x} with \code{p_value} (if it was missing),
#'   \code{padj} (numeric, \code{NA} where \code{p_value} is) and
#'   \code{significant} (logical) columns; the class and attributes of
#'   \code{x} are kept, and a \code{scanadj} attribute lists
#'   \code{method}, \code{alpha} and \code{tests}.
#' @seealso \code{\link{yoypv}}, \code{\link{falsfam}} for a
#'   family of falsification results, \code{\link{drftcal}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' seg <- data.frame(year = rep(2022:2023, each = 3),
#'                   site = rep(c("A", "B", "C"), 2),
#'                   n = c(30, 50, 80, 45, 52, 79))
#' y <- yoy(seg, value = "n", prd = "year", by = "site")
#' scanadj(y)[, c("site", "pctchg", "p_value", "padj")]
#'
#' # family-wise control instead of the false discovery rate
#' scanadj(y, meth = "holm")$padj
#'
#' # any table with a p_value column
#' scanadj(data.frame(test = c("a", "b", "c"), p_value = c(0.001, 0.02, 0.4)))
#'
#' try(scanadj(data.frame(p_value = 1.5)))
#' @export
scanadj <- function(x, meth = "BH", alpha = 0.05) {
  if (!is.data.frame(x)) {
    stop("`x` must be a data frame", call. = FALSE)
  }
  # p.adjust()'s methods, and one level in (0, 1): match.arg() and `$<-` refused them in their own
  # words (CRAN stress test of 0.5.14)
  meth <- .rmbl_arg(meth, stats::p.adjust.methods)
  alpha <- .rmbl_conf_level(alpha, "alpha")
  if (inherits(x, "rmbl_yoy") && is.null(x$p_value)) {
    x <- yoypv(x)
  } else if (inherits(x, "rmbl_rate_change") && is.null(x$p_value)) {
    x$p_value <- .exact_ratio_p(x$count, x$precnt,
                                x$population, x$prepop)
  } else if (is.null(x$p_value)) {
    stop(paste0("`x` has no `p_value` column and is not a yoy() or ",
                "ratechg() result"), call. = FALSE)
  }
  ok <- !is.na(x$p_value)
  if (any(x$p_value[ok] < 0 | x$p_value[ok] > 1)) {
    bad <- which(ok & (x$p_value < 0 | x$p_value > 1))
    stop("`p_value` must lie in [0, 1]; row(s) ", paste(bad, collapse = ", "),
         " hold ", paste(format(x$p_value[bad]), collapse = ", "),
         ". Nothing outside that range is a probability, so no adjustment ",
         "or significance decision is made.", call. = FALSE)
  }
  adj <- rep(NA_real_, nrow(x))
  if (any(ok)) adj[ok] <- stats::p.adjust(x$p_value[ok], method = meth)
  x$padj <- adj
  x$significant <- !is.na(adj) & adj < alpha
  attr(x, "scanadj") <- list(method = meth, alpha = alpha,
                                 tests = sum(ok))
  x
}

#' Calibrate the drift screens on data known not to have drifted
#'
#' @description
#' [cpsdrft()] flags a column when a
#' Kolmogorov-Smirnov, chi-square
#' or population-stability screen fires. How often that happens when
#' nothing has changed is the false-alarm rate of the screen on this
#' capsule, and it depends on the columns, their sizes and `alpha`. This
#' estimates it by splitting the same data at random into two halves
#' `n` times and running the screens on the halves, which is the null of
#' \dQuote{a re-fetch of identical data}. A capsule whose screens fire on 30
#' percent of identical re-fetches needs a smaller `alpha` or fewer screened
#' columns before a drift verdict means anything.
#'
#' @details
#' Each split draws \code{floor(nrow(data) / 2)} rows at random as the
#' reference and uses the rest as the current table, then runs
#' \code{\link{cpsdrft}} on the pair. A column's false-alarm rate is
#' the share of splits on which it was flagged; \code{anyflag} is the share
#' of splits on which any column was. Each half has half the rows of the
#' real data, so the rates describe a comparison at that size: smaller
#' samples make the p-value screens less sensitive, and the PSI screen only
#' counts once both halves reach \code{psiminn} rows.
#'
#' The splits are drawn under \code{seed} and the caller's random number
#' stream is restored afterwards (\code{seed = NULL} uses and advances the
#' current stream instead). Run time is about \code{n} times one
#' \code{cpsdrft()} call; a progress bar is shown in an interactive
#' session.
#'
#' Errors: \code{data} not a data frame with at least four rows; \code{n}
#' not a whole number of at least 1; any error from \code{cpsdrft()}.
#'
#' @param data The capsule's data frame.
#' @param n Whole number, default 50: the number of random half-splits.
#' @param alpha Number in (0, 1), default 0.01: the significance level
#'   passed to [cpsdrft()].
#' @param seed Integer or \code{NULL}, default 1: the seed for the splits.
#' @param ... Further arguments to [cpsdrft()], such
#'   as
#'   \code{psithr}, \code{psiminn}, \code{bins} or
#'   \code{idelvls}.
#' @return A list of class `rmbl_drift_calibration`: `columns` (a data frame
#'   of `column` and `falsealarmrate`, the share of splits on which it was
#'   flagged), `anyflag` (share of splits with at least one flag), `alpha`,
#'   `n`, and `alphafam` (`alpha` divided by the number of
#'   columns:
#'   the Bonferroni per-screen level that would hold the family-wise
#'   false-alarm rate at `alpha`). The print method lists the columns that
#'   fired.
#' @seealso \code{\link{cpsdrft}}, \code{\link{scanadj}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' d <- data.frame(a = rnorm(400), b = sample(letters[1:4], 400, TRUE))
#' drftcal(d, n = 10)
#'
#' # a stricter level, and the per-column rates
#' cal <- drftcal(d, n = 10, alpha = 0.001)
#' cal$columns
#'
#' try(drftcal(d[1:3, ]))
#' @export
drftcal <- function(data, n = 50L, alpha = 0.01, seed = 1L, ...) {
  if (!is.data.frame(data) || nrow(data) < 4L) {
    stop("`data` must be a data frame with at least four rows",
         call. = FALSE)
  }
  n <- .rmbl_num(n, "n", integer = TRUE)
  # a rate needs at least one split (n = 0 returned NaN and the plot then failed)
  if (length(n) != 1L || is.na(n) || n < 1L) stop("`n` must be a whole number of at least 1", call. = FALSE)
  .rmbl_local_seed(seed)
  hits <- NULL
  any_flag <- logical(n)
  pg <- blprog("drift calibration", n)
  on.exit(pg$done(), add = TRUE)
  for (i in seq_len(n)) {
    pg$update(i - 1L, sprintf("split %d/%d", i, n))
    idx <- sample.int(nrow(data), nrow(data) %/% 2L)
    res <- cpsdrft(data[idx, , drop = FALSE],
                         data[-idx, , drop = FALSE], alpha = alpha, ...)
    cols <- res$columns
    flagged <- !is.na(cols$drifted) & cols$drifted
    if (is.null(hits)) hits <- stats::setNames(numeric(nrow(cols)), cols$column)
    hits[cols$column] <- hits[cols$column] + as.numeric(flagged)
    any_flag[i] <- any(flagged)
  }
  columns <- data.frame(column = names(hits), falsealarmrate = hits / n,
                        stringsAsFactors = FALSE)
  structure(list(columns = columns, anyflag = mean(any_flag), alpha = alpha,
                 n = n, alphafam = alpha / max(1L, nrow(columns))),
            class = "rmbl_drift_calibration")
}

#' @export
print.rmbl_drift_calibration <- function(x, ...) {
  cat(sprintf("Drift screens on %d identical re-fetches (alpha = %g)\n",
              x$n, x$alpha))
  cat(sprintf("  at least one column flagged: %.0f%% of re-fetches\n",
              100 * x$anyflag))
  worst <- x$columns[order(-x$columns$falsealarmrate), , drop = FALSE]
  worst <- worst[worst$falsealarmrate > 0, , drop = FALSE]
  if (nrow(worst)) {
    cat("  columns that fire on identical data:\n")
    for (i in seq_len(min(8L, nrow(worst)))) {
      cat(sprintf("    %-28s %5.1f%%\n", worst$column[i],
                  100 * worst$falsealarmrate[i]))
    }
  } else {
    cat("  no column fired on identical data\n")
  }
  cat(sprintf("  per-screen alpha for a family-wise %g: %.2g\n",
              x$alpha, x$alphafam))
  invisible(x)
}
