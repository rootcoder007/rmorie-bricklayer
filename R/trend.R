# Trend in a short annual series.
#
# An open-data extract is five to ten fiscal years. Fitting an ARIMA to
# it is arithmetic without meaning: there is no autocorrelation
# structure to identify, and the coefficient standard errors are
# fictions. What five points can support is a rank-based test of
# monotone trend, a resistant slope, and -- for counts -- a rate ratio
# per period with an exact-enough interval.
#
# The step test is here because "did it change when the policy changed"
# is the question actually asked of these series, and the honest answer
# needs the whole scan's null distribution, not the best split's
# nominal p-value.

#' Trend in a short series
#'
#' The Mann-Kendall rank test for monotone trend with the Theil-Sen
#' median-of-slopes estimator: no distributional assumption, resistant to a
#' single aberrant period, and meaningful at the series lengths an annual
#' administrative extract actually has.
#'
#' @param y The series, in period order, or a data frame.
#' @param x The periods. Defaults to the position, which is right
#' for an evenly spaced series.
#' @param value,period Column names, when `y` is a
#' data frame.
#' @param exact Whether to compute the exact null distribution
#' of Mann-Kendall's S by enumeration. Feasible and used by default up to
#' `n = 8` (40,320 orderings); above that the normal approximation
#' with the tie and continuity corrections is used.
#' @param alternative `"two.sided"`,
#' `"increasing"` or `"decreasing"`.
#' @param conf_level Confidence level for the slope
#' interval.
#' @return A list with `S`, `tau`, `p_value`, `slope`
#' (Theil-Sen), `intercept`, `slope_lower` / `slope_upper`
#' (the distribution-free interval), `n` and `method`.
#' @details
#' Kendall's tau here is S over the number of comparable pairs, so it is
#' the rank correlation between the value and the period.
#'
#' The slope interval is the standard rank-based one: the pairwise slopes
#' are sorted and the interval runs between the order statistics that
#' Mann-Kendall's variance places at the chosen level, so it is consistent
#' with the test rather than derived from a different model.
#' @references
#' Sen, P. K. (1968). Estimates of the regression coefficient based on
#' Kendall's tau. *Journal of the American Statistical Association*
#' 63(324), 1379-1389, for the median-of-slopes estimator and the
#' distribution-free interval.
#'
#' Wilcox, R. R. *Modern Statistics for the Social and Behavioral Sciences:
#' A Practical Introduction* treats Theil-Sen among the regression methods
#' that carry no normality assumption, which is the reason for preferring
#' it on a series this short.
#' @seealso
#' [step_change()],
#' [count_trend()]
#' @examples
#' # Five years of placements.
#' y <- c(402, 377, 190, 268, 331)
#' trend_test(y)
#'
#' # A monotone series is detected even at n = 5, where a regression's
#' # standard error would be nearly uninformative.
#' trend_test(c(1, 2, 3, 4, 5))
#'
#' # One aberrant period does not create a trend.
#' trend_test(c(100, 100, 100, 100, 900))$p_value
#'
#' # From a data frame.
#' d <- data.frame(year = 2019:2023, n = y)
#' trend_test(d, value = "n", period = "year")$slope
#' @export
trend_test <- function(y, x = NULL, value = NULL, period = NULL,
                       exact = NULL,
                       alternative = c("two.sided", "increasing",
                                       "decreasing"),
                       conf_level = 0.95) {
  alternative <- match.arg(alternative)
  if (is.data.frame(y)) {
    if (is.null(value)) stop("`value` is required for a data frame",
                             call. = FALSE)
    d <- y
    if (!value %in% names(d)) {
      stop(sprintf("`value` column not found: %s", value), call. = FALSE)
    }
    if (!is.null(period)) {
      if (!period %in% names(d)) {
        stop(sprintf("`period` column not found: %s", period),
             call. = FALSE)
      }
      x <- as.numeric(d[[period]])
    }
    y <- as.numeric(d[[value]])
  }
  y <- as.numeric(y)
  if (is.null(x)) x <- seq_along(y)
  x <- as.numeric(x)
  if (length(x) != length(y)) {
    stop("`x` and `y` must be the same length", call. = FALSE)
  }
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]
  y <- y[ok]
  ord <- order(x)
  x <- x[ord]
  y <- y[ord]
  n <- length(y)
  if (n < 3L) {
    stop("a trend needs at least three periods", call. = FALSE)
  }
  mk <- .Call(C_rmbl_mann_kendall, y)
  ts <- .Call(C_rmbl_theil_sen, x, y)
  s <- mk$S
  npairs <- n * (n - 1) / 2
  tau <- s / npairs
  if (is.null(exact)) exact <- n <= 8L
  if (isTRUE(exact) && n <= 8L) {
    null_s <- .rmbl_mk_exact(n)
    p <- switch(alternative,
      increasing = mean(null_s >= s),
      decreasing = mean(null_s <= s),
      two.sided = mean(abs(null_s) >= abs(s)))
    method <- sprintf("Mann-Kendall, exact over all %d orderings",
                      length(null_s))
  } else {
    # the continuity correction moves S one unit toward zero, since S
    # changes in steps of two
    z <- if (is.na(mk$var) || mk$var <= 0) NA_real_ else {
      (s - sign(s)) / sqrt(mk$var)
    }
    p <- switch(alternative,
      increasing = stats::pnorm(z, lower.tail = FALSE),
      decreasing = stats::pnorm(z),
      two.sided = 2 * stats::pnorm(-abs(z)))
    p <- min(1, p)
    method <- "Mann-Kendall, normal approximation with tie correction"
  }
  ci <- .rmbl_sen_ci(x, y, mk$var, conf_level)
  list(S = s, tau = tau, p_value = p, slope = ts$slope,
       intercept = ts$intercept, slope_lower = ci[1L],
       slope_upper = ci[2L], n = n, var_S = mk$var,
       alternative = alternative, conf_level = conf_level,
       method = method)
}

# Exact null distribution of S, memoised: every ordering of n distinct
# ranks is equally likely under the null, so S's distribution is the
# distribution of S over the permutations.
.rmbl_mk_cache <- new.env(parent = emptyenv())

.rmbl_mk_exact <- function(n) {
  key <- as.character(n)
  if (!is.null(.rmbl_mk_cache[[key]])) return(.rmbl_mk_cache[[key]])
  perms <- .rmbl_permutations(n)
  s <- apply(perms, 1L, function(p) {
    tot <- 0
    for (i in seq_len(n - 1L)) {
      tot <- tot + sum(sign(p[(i + 1L):n] - p[i]))
    }
    tot
  })
  .rmbl_mk_cache[[key]] <- s
  s
}

.rmbl_permutations <- function(n) {
  if (n == 1L) return(matrix(1L, 1L, 1L))
  sub <- .rmbl_permutations(n - 1L)
  out <- matrix(0L, nrow(sub) * n, n)
  r <- 1L
  for (i in seq_len(nrow(sub))) {
    for (pos in seq_len(n)) {
      row <- integer(n)
      row[pos] <- n
      row[-pos] <- sub[i, ]
      out[r, ] <- row
      r <- r + 1L
    }
  }
  out
}

# Distribution-free interval for the Theil-Sen slope: the pairwise
# slopes, sorted, cut at the order statistics Mann-Kendall's variance
# places at the level. Consistent with the test, rather than borrowed
# from a normal-errors model the data was never claimed to follow.
.rmbl_sen_ci <- function(x, y, var_s, conf_level) {
  n <- length(y)
  slopes <- numeric(0)
  for (i in seq_len(n - 1L)) {
    for (j in (i + 1L):n) {
      dx <- x[j] - x[i]
      if (dx != 0) slopes <- c(slopes, (y[j] - y[i]) / dx)
    }
  }
  m <- length(slopes)
  if (m < 2L || is.na(var_s) || var_s <= 0) return(c(NA_real_, NA_real_))
  slopes <- sort(slopes)
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  c_alpha <- z * sqrt(var_s)
  lo_rank <- floor((m - c_alpha) / 2)
  hi_rank <- ceiling((m + c_alpha) / 2) + 1
  lo_rank <- max(1L, min(m, as.integer(lo_rank)))
  hi_rank <- max(1L, min(m, as.integer(hi_rank)))
  c(slopes[lo_rank], slopes[hi_rank])
}

#' A single step change, with the scan's own null distribution
#'
#' Scans every admissible split of the series, reports the one with the
#' largest mean difference, and gives it a p-value from the permutation
#' distribution of the MAXIMUM over splits -- not from the best split's own
#' test, which is the standard way to find a change point in noise.
#'
#' @param y The series, in period order.
#' @param x The periods. Used only for labelling the break.
#' @param min_segment Fewest periods either side of the
#' break.
#' @param n_perm Permutations for the null distribution. The
#' exact enumeration is used instead when the series is short enough for
#' it.
#' @param seed Seed for the permutations, so the p-value is
#' reproducible.
#' @return A list with `break_after` (the period the series changes
#' after), `index`, `before`, `after`, `difference`,
#' `statistic`, `p_value`, `n_perm` and `method`.
#' @references
#' The permutation distribution of the maximum over splits, rather than the
#' chosen split's own test, is what makes this a test of whether there is a
#' break rather than a way of locating the largest wobble. See any
#' treatment of the change-point problem, e.g. Coles, S. *An Introduction
#' to Statistical Modeling of Extreme Values* (Springer), which discusses
#' change-point detection alongside the threshold choices that raise the
#' same multiple-comparison issue.
#' @examples
#' # A clear step down after the third period.
#' step_change(c(100, 104, 98, 60, 63, 58))
#'
#' # Pure noise: the best split is still found, and is not significant.
#' set.seed(2)
#' step_change(stats::rnorm(12))$p_value
#' @export
step_change <- function(y, x = NULL, min_segment = 2L, n_perm = 9999L,
                        seed = 1L) {
  y <- as.numeric(y)
  if (is.null(x)) x <- seq_along(y)
  ok <- is.finite(y)
  y <- y[ok]
  x <- x[ok]
  n <- length(y)
  min_segment <- as.integer(min_segment)
  if (n < 2L * min_segment) {
    stop(sprintf(
      "need at least %d periods for a break with %d either side",
      2L * min_segment, min_segment), call. = FALSE)
  }
  # The weighted squared mean difference,
  #   (n_a n_b / n) (mean_a - mean_b)^2,
  # which is the between-group sum of squares for the split. A
  # studentised version would divide by the within-segment spread and so
  # return Inf for a segment with no variation -- a PERFECT step, the
  # clearest signal there is, which then fell out as inadmissible. The
  # permutation null accounts for the spread without the statistic
  # having to.
  stat <- function(v) {
    n <- length(v)
    cuts <- seq.int(min_segment, n - min_segment)
    vals <- vapply(cuts, function(k) {
      a <- v[seq_len(k)]
      b <- v[(k + 1L):n]
      (length(a) * length(b) / n) * (mean(a) - mean(b))^2
    }, 0)
    list(cuts = cuts, vals = vals)
  }
  # `y` is already reduced to its finite values and the statistic is a
  # weighted squared difference of means, so every split scores a finite
  # number. There is no inadmissible-scan case left to guard against;
  # the earlier guard for one could not fire.
  obs <- stat(y)
  best <- obs$cuts[which.max(obs$vals)]
  tmax <- max(obs$vals)
  a <- y[seq_len(best)]
  b <- y[(best + 1L):n]

  # The null: the periods are exchangeable, so permute them and take the
  # same MAXIMUM over splits. Comparing the best split against its own
  # null would find a break in any series.
  nfact <- if (n <= 8L) factorial(n) else Inf
  if (nfact <= n_perm) {
    perms <- .rmbl_permutations(n)
    null <- apply(perms, 1L, function(p) max(stat(y[p])$vals))
    method <- sprintf("exact over all %d orderings", nrow(perms))
    np <- nrow(perms)
  } else {
    old <- if (exists(".Random.seed", envir = globalenv())) {
      get(".Random.seed", envir = globalenv())
    } else {
      NULL
    }
    set.seed(seed)
    null <- vapply(seq_len(n_perm),
                   function(i) max(stat(sample(y))$vals), 0)
    if (is.null(old)) {
      suppressWarnings(rm(".Random.seed", envir = globalenv()))
    } else {
      assign(".Random.seed", old, envir = globalenv())
    }
    method <- sprintf("%d permutations of the maximum over splits", n_perm)
    np <- n_perm
  }
  null <- null[is.finite(null)]
  # the observed value is one of the arrangements, so it counts in its
  # own null -- without it a p-value of exactly zero is reportable, and
  # no permutation test can support that
  p <- (1 + sum(null >= tmax)) / (1 + length(null))
  list(break_after = x[best], index = best, before = mean(a),
       after = mean(b), difference = mean(b) - mean(a),
       statistic = tmax, p_value = min(1, p), n_perm = np,
       method = method)
}

#' Trend in a count series, as a rate ratio per period
#'
#' Fits a Poisson log-linear trend by iteratively reweighted least squares
#' and reports the multiplicative change per period, which is what a count
#' series' trend actually is. An offset carries the denominator when the
#' exposure varies.
#'
#' @param y Counts, in period order.
#' @param x Periods. Defaults to the position.
#' @param offset Exposure for each period -- a population, a
#' number of admissions, a number of days. The trend is then in the rate
#' rather than in the count.
#' @param conf_level Confidence level for the rate ratio.
#' @return A list with `rate_ratio` (per period), its interval,
#' `p_value`, the fitted values, the dispersion, and
#' `overdispersed`.
#' @details
#' The dispersion is reported because a Poisson fit assumes it is one. When
#' it is well above one the interval is too narrow, and the quasi-Poisson
#' interval -- which scales the standard error by the square root of the
#' dispersion -- is returned instead, with `overdispersed` set.
#' @references
#' Bilder, C. R. and Loughin, T. M. *Analysis of Categorical Data with
#' R*, 2nd edn. Chapman and Hall/CRC, on the quasi-likelihood treatment of
#' an overdispersed Poisson fit: the variance is scaled by an estimated
#' dispersion, which widens the interval while leaving the point estimate
#' alone. That is the behaviour reported here through `dispersion` and
#' `overdispersed`.
#' @examples
#' # A count falling by about 15% a year.
#' set.seed(3)
#' y <- stats::rpois(8, lambda = 200 * 0.85^(0:7))
#' fit <- count_trend(y)
#' round(fit$rate_ratio, 3)
#'
#' # With a varying denominator the trend is in the rate.
#' count_trend(c(20, 25, 30), offset = c(1000, 1500, 2500))$rate_ratio
#' @export
count_trend <- function(y, x = NULL, offset = NULL, conf_level = 0.95) {
  y <- as.numeric(y)
  if (is.null(x)) x <- seq_along(y)
  x <- as.numeric(x)
  if (length(x) != length(y)) {
    stop("`x` and `y` must be the same length", call. = FALSE)
  }
  if (any(y < 0, na.rm = TRUE) ||
        any(abs(y - round(y)) > 1e-8, na.rm = TRUE)) {
    stop("`y` must be non-negative whole numbers", call. = FALSE)
  }
  logoff <- if (is.null(offset)) {
    rep(0, length(y))
  } else {
    off <- as.numeric(offset)
    if (length(off) != length(y)) {
      stop("`offset` must be the same length as `y`", call. = FALSE)
    }
    if (any(off <= 0, na.rm = TRUE)) {
      stop("`offset` must be positive", call. = FALSE)
    }
    log(off)
  }
  ok <- is.finite(x) & is.finite(y) & is.finite(logoff)
  x <- x[ok]
  y <- y[ok]
  logoff <- logoff[ok]
  n <- length(y)
  if (n < 3L) stop("a trend needs at least three periods", call. = FALSE)
  # centre the periods so the intercept is interpretable and the normal
  # equations are better conditioned
  xc <- x - mean(x)
  # iteratively reweighted least squares on the two-column design; the
  # model is small enough to solve directly and needs no glm machinery
  beta <- c(log(max(sum(y), 1) / n) - mean(logoff), 0)
  for (iter in seq_len(50L)) {
    eta <- beta[1L] + beta[2L] * xc + logoff
    mu <- exp(eta)
    mu[mu < 1e-10] <- 1e-10
    z <- eta - logoff + (y - mu) / mu
    w <- mu
    sw <- sum(w)
    swx <- sum(w * xc)
    swxx <- sum(w * xc * xc)
    swz <- sum(w * z)
    swxz <- sum(w * xc * z)
    det <- sw * swxx - swx^2
    if (!is.finite(det) || abs(det) < 1e-12) break
    nb <- c((swxx * swz - swx * swxz) / det,
            (sw * swxz - swx * swz) / det)
    if (max(abs(nb - beta)) < 1e-10) { beta <- nb; break }
    beta <- nb
  }
  eta <- beta[1L] + beta[2L] * xc + logoff
  mu <- exp(eta)
  w <- mu
  sw <- sum(w)
  swx <- sum(w * xc)
  swxx <- sum(w * xc * xc)
  det <- sw * swxx - swx^2
  se <- if (is.finite(det) && det > 0) sqrt(sw / det) else NA_real_
  # Pearson dispersion: the Poisson fit assumes this is one, and when it
  # is not the interval below is too narrow
  resid <- (y - mu) / sqrt(mu)
  disp <- if (n > 2L) sum(resid^2) / (n - 2L) else NA_real_
  over <- is.finite(disp) && disp > 1.5
  se_use <- if (over && is.finite(se)) se * sqrt(disp) else se
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  list(rate_ratio = exp(beta[2L]),
       lower = if (is.finite(se_use)) exp(beta[2L] - z * se_use) else NA_real_,
       upper = if (is.finite(se_use)) exp(beta[2L] + z * se_use) else NA_real_,
       p_value = if (is.finite(se_use) && se_use > 0) {
         2 * stats::pnorm(-abs(beta[2L] / se_use))
       } else {
         NA_real_
       },
       log_slope = beta[2L], se = se_use, fitted = mu,
       dispersion = disp, overdispersed = over, n = n,
       method = if (over) {
         "quasi-Poisson (dispersion above 1.5)"
       } else {
         "Poisson log-linear"
       })
}
