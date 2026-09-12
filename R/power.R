# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Positive controls: the half of the argument that falsification cannot
# make.
#
# capsule_falsify() breaks the association on purpose and checks the
# statistic collapses. Every control in it can refute and none can
# confirm: a statistic that is simply insensitive -- too little data,
# too much noise, a test with no power against the alternative that
# matters -- passes every one of them by failing to see anything at all.
#
# The check that answers that is the opposite experiment. Inject an
# effect of known size into the data and see whether the procedure finds
# it. A null result from a procedure that could not have detected a real
# effect of the size at issue is not evidence of absence, and the only
# way to know which you have is to try.

#' Detect an injected effect of known size
#'
#' Adds an effect of each given size to the data, reruns the whole
#' detection procedure, and reports how often it was found. The result is a
#' power curve, and the smallest size detected reliably is the smallest
#' effect the analysis could have seen.
#'
#' This is the positive control that
#' [capsule_falsify()] lacks: its four are
#' all negative. Those establish that the finding is not an artefact; this
#' establishes that a real effect would not have been missed. A study that
#' passes every falsification control and has no power against the effect
#' it was looking for has not found that the effect is absent -- it has
#' found nothing either way, and the two are routinely reported as the same
#' thing.
#'
#' @param data A data frame.
#' @param statistic A function of one data frame returning
#' a single finite number.
#' @param inject A function of `(data, size)` returning
#' the data with an effect of that size added. It is the caller's, because
#' what counts as an effect of size 0.2 is a modelling decision and not
#' something this function can guess.
#' @param sizes Effect sizes to try. `0` is added if
#' absent, since the detection rate there is the false-positive rate and
#' belongs on the same curve.
#' @param treatment Column permuted to build the null, as
#' in [capsule_falsify()].
#' @param n Permutations per test.
#' @param reps Repetitions per size. The detection rate at each
#' size is out of this many, so its resolution is `1 / reps`.
#' @param alpha Significance threshold for counting a
#' detection.
#' @param seed Optional integer seed.
#' @return A list of class `bricklayer_power`: a `curve` data
#' frame ( `size`, `detected`, `reps`, `rate`) , the
#' `alpha` used, and `smallest_detected`, the smallest size found
#' at a rate of at least 0.8 -- `NA` when no size reached it.
#' @seealso [capsule_falsify()] for the
#' negative controls.
#' @examples
#' set.seed(1)
#' d <- data.frame(x = rnorm(120), y = rnorm(120))
#' # inject a linear effect of x on y
#' inj <- function(z, size) {
#'   z$y <- z$y + size * z$x
#'   z
#' }
#' pw <- capsule_power(d, function(z) cor(z$x, z$y), inj,
#'                     sizes = c(0, 0.3, 0.6), treatment = "x",
#'                     n = 99, reps = 5, seed = 42)
#' pw$curve
#'
#' # The rate at size 0 estimates the false-positive rate. With few
#' # repetitions it is usually 0, because alpha is small -- five draws
#' # at 0.05 come up empty about three times in four -- so read it as a
#' # sanity check that it is not LARGE, not as an estimate of alpha.
#' pw$curve[pw$curve$size == 0, "rate"]
#' @export
capsule_power <- function(data, statistic, inject, sizes = c(0, 0.2, 0.5),
                          treatment = NULL, n = 99L, reps = 10L,
                          alpha = 0.05, seed = NULL) {
  if (!is.data.frame(data) || nrow(data) < 4L) {
    stop("`data` must be a data frame with at least 4 rows", call. = FALSE)
  }
  if (!is.function(statistic) || !is.function(inject)) {
    stop("`statistic` and `inject` must both be functions", call. = FALSE)
  }
  if (is.null(treatment)) {
    stop("`treatment` is required: the permutation null is built by ",
         "shuffling it, and without one there is nothing to detect ",
         "against", call. = FALSE)
  }
  treatment <- as.character(treatment)[1L]
  if (!treatment %in% names(data)) {
    stop("`treatment` is not a column of `data`", call. = FALSE)
  }
  sizes <- sort(unique(c(0, as.numeric(sizes))))
  n <- as.integer(n)[1L]
  reps <- as.integer(reps)[1L]
  if (is.na(n) || n < 9L) stop("`n` must be at least 9", call. = FALSE)
  if (is.na(reps) || reps < 1L) stop("`reps` must be at least 1",
                                     call. = FALSE)
  if (1 / (n + 1) > alpha) {
    stop(sprintf(paste0("with %d permutations the smallest p-value is ",
                        "%.4g, which is above alpha = %.4g: no size ",
                        "could ever be detected"),
                 n, 1 / (n + 1), alpha), call. = FALSE)
  }
  if (!is.null(seed)) set.seed(as.integer(seed)[1L])

  rows <- lapply(sizes, function(sz) {
    hits <- 0L
    usable <- 0L
    for (r in seq_len(reps)) {
      d <- tryCatch(inject(data, sz), error = function(e) NULL)
      if (!is.data.frame(d)) next
      obs <- tryCatch(as.numeric(statistic(d))[1L],
                      error = function(e) NA_real_)
      if (!is.finite(obs)) next
      null <- vapply(seq_len(n), function(i) {
        z <- d
        z[[treatment]] <- sample(z[[treatment]])
        tryCatch(as.numeric(statistic(z))[1L], error = function(e) NA_real_)
      }, numeric(1))
      ok <- is.finite(null)
      if (!any(ok)) next
      p <- (1 + sum(abs(null[ok]) >= abs(obs))) / (1 + sum(ok))
      usable <- usable + 1L
      if (p <= alpha) hits <- hits + 1L
    }
    data.frame(size = sz, detected = hits, reps = usable,
               rate = if (usable > 0L) hits / usable else NA_real_,
               stringsAsFactors = FALSE)
  })
  curve <- do.call(rbind, rows)
  rownames(curve) <- NULL
  pos <- curve[curve$size > 0 & !is.na(curve$rate) & curve$rate >= 0.8, ]
  out <- list(curve = curve, alpha = alpha, n = n, reps = reps,
              treatment = treatment,
              smallest_detected = if (nrow(pos)) min(pos$size) else
                NA_real_,
              false_positive_rate =
                curve$rate[curve$size == 0][1L])
  class(out) <- c("bricklayer_power", "list")
  out
}

#' @export
format.bricklayer_power <- function(x, ...) {
  c(.rmbl_rule("Positive controls: an injected effect of known size"),
    sprintf("  %d permutations, %d repetition(s) per size, alpha %.3g",
            x$n, x$reps, x$alpha),
    .rmbl_rule(),
    sprintf("  size %-10.4g detected %2d/%-2d  rate %s", x$curve$size,
            x$curve$detected, x$curve$reps,
            ifelse(is.na(x$curve$rate), "  --",
                   sprintf("%.2f", x$curve$rate))),
    .rmbl_rule(),
    if (is.na(x$smallest_detected))
      "  no size was detected at a rate of 0.8: this analysis could not"
    else
      sprintf("  smallest size detected at a rate of 0.8: %.4g",
              x$smallest_detected),
    if (is.na(x$smallest_detected))
      "  have seen any of the effects tried, so a null result from it"
    else
      "  a null result is informative only about effects at least this",
    if (is.na(x$smallest_detected))
      "  says nothing about whether an effect is there"
    else
      "  large; smaller ones would have been missed",
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_power <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}
