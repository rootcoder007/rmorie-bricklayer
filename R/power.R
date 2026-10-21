# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Positive controls: the half of the argument that falsification cannot
# make.
#
# cpsfals() breaks the association on purpose and checks the
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
#' effect the analysis could have seen. Use it before reporting a null
#' result, to show whether the analysis could have found an effect of the
#' size that matters.
#'
#' @details
#' This is the positive control that
#' [cpsfals()] lacks: its four are
#' all negative. Those establish that the finding is not an artefact; this
#' establishes that a real effect would not have been missed. A study that
#' passes every falsification control and has no power against the effect
#' it was looking for has not found that the effect is absent -- it has
#' found nothing either way, and the two are routinely reported as the same
#' thing.
#'
#' For each size (0 is always added) and each of \code{reps} repetitions,
#' the statistic is computed on the data passed through the injector, as
#' \code{inject(data, size)}, and a permutation null is built by shuffling the
#' \code{trt} column \code{n} times and recomputing the statistic. The
#' two-sided permutation p-value is
#' \deqn{p = \frac{1 + \#\{|T^*| \ge |T|\}}{1 + n_{ok}}}
#' over the \eqn{n_{ok}} permutations with a finite statistic (Phipson and
#' Smyth's correction, so \eqn{p} is never 0), and the effect counts as
#' detected when \eqn{p \le \alpha}. A repetition whose injection or
#' observed statistic fails (error or non-finite value) is skipped and not
#' counted in \code{reps}. Since the data are the same in every repetition,
#' \code{inject} should add randomness of its own (new noise, a resampled
#' effect) when repetitions are meant to differ; otherwise only the
#' permutations vary.
#'
#' The cost is \eqn{|sizes| \times reps \times (n + 1)} evaluations of
#' \code{stat}. A progress bar is drawn on stderr unless
#' \code{options(morie.quiet = TRUE)}. With \code{seed}, R's random number
#' state is set for the run and restored afterwards; without it, the run
#' uses and advances the session's generator.
#'
#' Errors: \code{data} not a data frame of at least 4 rows;
#' \code{stat} or \code{inject} not a function; \code{trt}
#' missing or not a column; \code{n} below 9; \code{reps} below 1; \code{n}
#' so small that \eqn{1/(n+1) > \alpha}, so that nothing could ever be
#' detected.
#'
#' @param data A data frame.
#' @param stat A function of one data frame returning
#'   a single finite number (for example a correlation or a difference in
#'   means).
#' @param inject A function of \code{(data, size)} returning
#'   the data with an effect of that size added. It is the caller's, because
#'   what counts as an effect of size 0.2 is a modelling decision and not
#'   something this function can guess.
#' @param sizes Numeric vector of effect sizes to try (default
#'   \code{c(0, 0.2, 0.5)}). \code{0} is added if absent, since the detection
#'   rate there is the false-positive rate and belongs on the same curve.
#'   Duplicates are removed and the sizes sorted.
#' @param trt Name of the column permuted to build the null, as
#'   in [cpsfals()]. Required.
#' @param n Permutations per test, a whole number of at least 9 (default
#'   99).
#' @param reps Repetitions per size, a whole number of at least 1 (default
#'   10). The detection rate at each size is out of this many, so its
#'   resolution is \code{1 / reps}.
#' @param alpha Significance threshold for counting a
#'   detection (default 0.05).
#' @param seed Optional integer seed; \code{NULL} (the default) uses the
#'   session's random number state.
#' @return A list of class \code{c("bricklayer_power", "list")}:
#'   \describe{
#'     \item{\code{curve}}{data frame with one row per size: \code{size},
#'       \code{detected} (integer), \code{reps} (integer, the usable repetitions)
#'       and \code{rate} (\code{detected / reps}, \code{NA} when none was usable).}
#'     \item{\code{alpha}, \code{n}, \code{reps}, \code{treatment}}{the settings used.}
#'     \item{\code{smadet}}{the smallest positive size found at a rate of
#'       at least 0.8, or \code{NA} when no size reached it.}
#'     \item{\code{false_positive_rate}}{the rate at size 0.}
#'   }
#' @seealso [cpsfals()] for the
#' negative controls.
#' @examples
#' set.seed(1)
#' d <- data.frame(x = rnorm(120), y = rnorm(120))
#' # inject a linear effect of x on y
#' inj <- function(z, size) {
#'   z$y <- z$y + size * z$x
#'   z
#' }
#' pw <- cpspwr(d, function(z) cor(z$x, z$y), inj,
#'                     sizes = c(0, 0.3, 0.6), trt = "x",
#'                     n = 99, reps = 5, seed = 42)
#' pw$curve
#' pw
#'
#' # The rate at size 0 estimates the false-positive rate. With few
#' # repetitions it is usually 0, because alpha is small -- five draws
#' # at 0.05 come up empty about three times in four -- so read it as a
#' # sanity check that it is not LARGE, not as an estimate of alpha.
#' pw$curve[pw$curve$size == 0, "rate"]
#'
#' # an injection with fresh noise each time, and effects too small to be
#' # detected in four repetitions: the smallest detected size is NA
#' inj2 <- function(z, size) {
#'   z$y <- z$y + size * z$x + stats::rnorm(nrow(z), sd = 0.5)
#'   z
#' }
#' cpspwr(d, function(z) cor(z$x, z$y), inj2, sizes = c(0.1, 0.2),
#'               trt = "x", n = 49, reps = 4, seed = 7)$smadet
#'
#' # too few permutations to ever reach alpha = 0.05
#' try(cpspwr(d, function(z) cor(z$x, z$y), inj, trt = "x", n = 9))
#' @export
cpspwr <- function(data, stat, inject, sizes = c(0, 0.2, 0.5),
                          trt = NULL, n = 99L, reps = 10L,
                          alpha = 0.05, seed = NULL) {
  .rmbl_no_fn(treatment = trt)
  if (!is.data.frame(data) || nrow(data) < 4L) {
    stop("cpspwr: `data` must be a data frame with at least 4 rows", call. = FALSE)
  }
  if (!is.function(stat) || !is.function(inject)) {
    stop("`stat` and `inject` must both be functions", call. = FALSE)
  }
  if (is.null(trt)) {
    stop("`trt` is required: the permutation null is built by ",
         "shuffling it, and without one there is nothing to detect ",
         "against", call. = FALSE)
  }
  trt <- as.character(trt)[1L]
  if (!trt %in% names(data)) {
    stop("cpspwr: `trt` is not a column of `data`", call. = FALSE)
  }
  sizes <- sort(unique(c(0, .rmbl_num(sizes, "sizes"))))
  n <- .rmbl_num(n, "n", integer = TRUE)[1L]
  reps <- .rmbl_num(reps, "reps", integer = TRUE)[1L]
  if (is.na(n) || n < 9L) stop("`n` must be at least 9", call. = FALSE)
  alpha <- .rmbl_conf_level(alpha, "alpha")
  if (is.na(reps) || reps < 1L) stop("`reps` must be at least 1",
                                     call. = FALSE)
  if (1 / (n + 1) > alpha) {
    stop(sprintf(paste0("with %d permutations the smallest p-value is ",
                        "%.4g, which is above alpha = %.4g: no size ",
                        "could ever be detected"),
                 n, 1 / (n + 1), alpha), call. = FALSE)
  }
  if (!is.null(seed)) seed <- .rmbl_r_seed(seed)
  if (!is.null(seed)) .rmbl_local_seed(seed)

  pg <- blprog("power curve", length(sizes) * reps)
  on.exit(pg$done(), add = TRUE)
  rows <- lapply(seq_along(sizes), function(si) {
    sz <- sizes[[si]]
    hits <- 0L
    usable <- 0L
    for (r in seq_len(reps)) {
      pg$update((si - 1L) * reps + r - 1L, sprintf("size %s, rep %d/%d", format(sz), r, reps))
      d <- tryCatch(inject(data, sz), error = .rmbl_or(NULL))
      if (!is.data.frame(d)) next
      obs <- tryCatch(as.numeric(stat(d))[1L],
                      error = .rmbl_or(NA_real_))
      if (!is.finite(obs)) next
      null <- vapply(seq_len(n), function(i) {
        z <- d
        z[[trt]] <- sample(z[[trt]])
        tryCatch(as.numeric(stat(z))[1L], error = .rmbl_or(NA_real_))
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
              treatment = trt,
              smadet = if (nrow(pos)) min(pos$size) else
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
    if (is.na(x$smadet))
      "  no size was detected at a rate of 0.8: this analysis could not"
    else
      sprintf("  smallest size detected at a rate of 0.8: %.4g",
              x$smadet),
    if (is.na(x$smadet))
      "  have seen any of the effects tried, so a null result from it"
    else
      "  a null result is informative only about effects at least this",
    if (is.na(x$smadet))
      "  says nothing about whether an effect is there"
    else
      "  large; smaller ones would have been missed",
    .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_power
print.bricklayer_power <- .rmbl_print_via_format
