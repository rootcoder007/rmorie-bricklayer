# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The variance with the right denominator: Bessel's correction for a sample,
# none for a whole population described as it is, the finite-population
# correction for a sample drawn without replacement, and the denominators
# frequency and reliability weights call for, with the reason given.

#' Variance and standard deviation with the right correction, and why
#'
#' The variance, standard deviation and standard error of the mean of a
#' variable, with the denominator its source calls for: Bessel's \eqn{n - 1}
#' when the values are a sample from a larger population, \eqn{n} when they are
#' the whole population and it is being described, and the finite-population
#' correction when they are a sample drawn without replacement from a known,
#' finite population. \code{design = "auto"} chooses from \code{N}, and the
#' result says which rule it applied and why.
#'
#' @details With \eqn{n} values \eqn{x_i} and mean \eqn{\bar x}: \describe{
#' \item{\code{"sample"}}{values drawn independently from a large population (or
#' from a process). \eqn{s^2 = \sum (x_i - \bar x)^2 / (n - 1)} is unbiased for
#' the population variance: the \eqn{n - 1} (the Bessel correction) makes up for
#' measuring spread around the mean of the sample itself, which is closer to the
#' values than the population mean is. The standard error of the mean is \eqn{s
#' / \sqrt n}.} \item{\code{"census"}}{every unit of the population is observed
#' (a full count, complete administrative records) and the aim is to describe
#' that population: \eqn{\sigma^2 = \sum (x_i - \bar x)^2 / n}, with no
#' correction, because \eqn{\bar x} is the population mean itself; the mean has
#' no sampling error. If the population is instead treated as one realisation of
#' a process (the offences of one year as a draw of what the conditions of the
#' city produce), use \code{"sample"}.} \item{\code{"finite"}}{\eqn{n} units
#' drawn without replacement from \eqn{N}: \eqn{s^2} (with \eqn{n - 1}) is
#' unbiased for the population variance defined with \eqn{N - 1}, and the
#' standard error of the mean is \eqn{\sqrt{(1 - n/N) s^2 / n}}; the factor
#' \eqn{1 - n/N} is the finite-population correction, negligible below a
#' sampling fraction of about 5 percent.} } \code{"auto"} picks \code{"sample"}
#' without \code{N}, \code{"census"} when \eqn{n = N}, and \code{"finite"} when
#' \eqn{n < N}.
#'
#' With weights: frequency weights (each value stands for \eqn{w_i} identical
#' observations) use \eqn{\sum w - 1}; reliability or sampling weights (each
#' value counts \eqn{w_i} times as much) use \eqn{\sum w - \sum w^2 / \sum w},
#' which is \eqn{n - 1} when the weights are equal, and the standard error of
#' the weighted mean is the sandwich \eqn{\sqrt{\sum w_i^2 (x_i - \bar x_w)^2} /
#' \sum w_i}. Survey weights from a complex design need the design itself for a
#' standard error (\code{\link{svydes}}).
#'
#' @param x A numeric vector.
#' @param des \code{"auto"} (default), \code{"sample"}, \code{"census"} or
#'   \code{"finite"}.
#' @param N The population size \eqn{N}, for \code{"finite"} and
#'   \code{"auto"}.
#' @param w Optional non-negative weights, one per value.
#' @param wtype \code{"frequency"} (default) or \code{"reliability"}.
#' @param narm Drop missing values (default \code{FALSE}: they are an error).
#' @return A list of class \code{rmbl_spread} with \code{n}, \code{mean},
#'   \code{variance}, \code{sd}, \code{semean}, \code{design} (the rule
#'   applied), \code{denominator}, and \code{reason} (a sentence). The print
#'   method shows them.
#' @references Cochran WG (1977). Sampling Techniques, 3rd edition. Wiley, New
#'   York, sections 2.4 to 2.6.
#' @seealso \code{\link{svydes}} for weighted surveys with strata and clusters.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' x <- c(12, 15, 9, 20, 14)
#' sprd(x)                                   # a sample: n - 1
#' sprd(x, des = "census")                # the whole population: n
#' sprd(x, N = 40)             # 5 of 40 drawn: finite-population correction
#' sprd(x, N = 5)              # n = N: a census
#' sprd(c(1, 2, 3), w = c(10, 5, 1))   # frequency weights
#' @export
sprd <- function(
  x,
  des = c("auto", "sample", "census", "finite"),
  N = NULL,
  w = NULL,
  wtype = c("frequency", "reliability"),
  narm = FALSE
) {
  des <- .rmbl_arg(des)
  wtype <- .rmbl_arg(wtype)
  x <- .rmbl_num(x, "x")
  .w <- if (is.null(w)) rep(1, length(x)) else .rmbl_num(w, "w")
  xw <- .rmbl_spread_clean(x, .w, narm)
  x <- xw$x
  .w <- xw$w
  n <- length(x)
  .N <- if (is.null(N)) NA_real_ else .rmbl_scalar(N, "N", 1)
  des <- .rmbl_spread_design(des, n, .N)
  sw <- sum(.w)
  m <- sum(.w * x) / sw
  ss <- sum(.w * (x - m)^2)
  freq <- is.null(w) || wtype == "frequency"
  dn <- .rmbl_spread_den(des, freq, is.null(w), .w)
  v <- if (dn$den > 0) ss / dn$den else NA_real_
  se <- switch(
    des,
    census = 0,
    sample = if (freq) sqrt(v / sw) else sqrt(sum(.w^2 * (x - m)^2)) / sw,
    finite = sqrt((1 - n / .N) * v / n)
  )
  dtxt <- dn$dtxt
  reason <- .rmbl_spread_reason(des, n, .N)
  out <- list(
    n = n,
    mean = m,
    variance = v,
    sd = sqrt(v),
    semean = se,
    design = des,
    denominator = dtxt,
    reason = reason
  )
  class(out) <- "rmbl_spread"
  out
}

#' @export
format.rmbl_spread <- function(x, digits = 6L, ...) {
  .rmbl_res_block(
    "Mean and spread",
    facts = list(
      Values = x$n,
      Mean = .rmbl_fmt_num(x$mean, digits),
      Variance = .rmbl_fmt_num(x$variance, digits),
      `Standard deviation` = .rmbl_fmt_num(x$sd, digits),
      `Standard error of the mean` = .rmbl_fmt_num(x$semean, digits),
      Design = x$design,
      Denominator = x$denominator
    ),
    reading = paste0("Rule: ", x$reason, "."),
    digits = digits
  )
}

#' The values and weights of sprd(), checked, with missing ones dropped
#' when asked.
#' @param x The values; missing ones are dropped only with `narm`.
#' @param .w The weights, one per value.
#' @param narm Whether missing values are dropped.
#' @return list(x, w).
#' @noRd
.rmbl_spread_clean <- function(x, .w, narm) {
  if (length(.w) != length(x)) {
    stop("`w` must be one per value", call. = FALSE)
  }
  if (anyNA(x) || anyNA(.w)) {
    if (!isTRUE(narm)) {
      stop("`x` has missing values: drop them, or narm = TRUE", call. = FALSE)
    }
    keep <- !is.na(x) & !is.na(.w)
    x <- x[keep]
    .w <- .w[keep]
  }
  if (length(x) < 1L) {
    stop("`x` has no values", call. = FALSE)
  }
  if (any(.w < 0) || !any(.w > 0)) {
    stop("`w` must be 0 or more, not all 0", call. = FALSE)
  }
  list(x = x, w = .w)
}

#' The design sprd() measures under: "auto" resolved from `N`.
#' @param des The design asked for.
#' @param n The number of values, compared with the population size `.N`.
#' @param .N The population size, or NA.
#' @return One of "sample", "census", "finite".
#' @noRd
.rmbl_spread_design <- function(des, n, .N) {
  if (is.finite(.N) && .N < n) {
    stop("`N` is smaller than the number of values", call. = FALSE)
  }
  if (des == "auto") {
    des <- if (!is.finite(.N)) {
      "sample"
    } else if (n == .N) {
      "census"
    } else {
      "finite"
    }
  }
  if (des == "finite" && !is.finite(.N)) {
    stop("the finite-population correction needs `N`", call. = FALSE)
  }
  des
}

#' The variance denominator of sprd(), and how it is described.
#' @param des The design, such as `"census"` or `"finite"`.
#' @param freq Whether the weights are frequency weights (or absent).
#' @param noweights Whether no weights were given.
#' @param .w The weights, summed for the denominator.
#' @return list(den, dtxt).
#' @noRd
.rmbl_spread_den <- function(des, freq, noweights, .w) {
  sw <- sum(.w)
  if (des == "census") {
    den <- sw
    dtxt <- if (noweights) "n" else "sum of weights"
  } else if (freq) {
    den <- sw - 1
    dtxt <- if (noweights) "n - 1 (Bessel)" else "sum of weights - 1"
  } else {
    den <- sw - sum(.w^2) / sw
    dtxt <- "sum w - sum w^2 / sum w (reliability weights)"
  }
  list(den = den, dtxt = dtxt)
}

#' Why sprd() used its rule, in words.
#' @param des The design named in the reason.
#' @param n The number of values, quoted in the reason.
#' @param .N The population size, or NA.
#' @return One string.
#' @noRd
.rmbl_spread_reason <- function(des, n, .N) {
  switch(
    des,
    sample = paste(
      "the values are a sample from a larger population, so the spread",
      "is measured",
      "around the mean of the sample itself and n - 1 corrects the bias",
      "that causes"
    ),
    census = paste(
      "the values are the whole population and it is described as it",
      "is: the mean",
      "is the population mean, so no correction, and the mean has no",
      "sampling error"
    ),
    finite = sprintf(
      paste(
        "%d of %s units were drawn without replacement: n - 1 for the",
        "variance,",
        "and the finite-population correction 1 - n/N = %.3f for the standard",
        "error%s"
      ),
      n,
      format(.N),
      1 - n / .N,
      if (n / .N < 0.05) " (negligible below a 5% sampling fraction)" else ""
    )
  )
}
