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
#' @description
#' Tests whether a short series (for example five to ten fiscal years of an
#' administrative count) is rising or falling, and estimates the size of the
#' change per period. It uses the Mann-Kendall rank test for monotone trend
#' and the Theil-Sen median-of-slopes estimator: no distributional
#' assumption, resistant to a single aberrant period, and meaningful at the
#' series lengths an annual administrative extract actually has.
#'
#' @details
#' With values \eqn{y_1, \dots, y_n} in period order,
#' \deqn{S = \sum_{i < j} \mathrm{sign}(y_j - y_i),}
#' and Kendall's tau here is \eqn{S / (n(n-1)/2)}, the rank correlation
#' between the value and the period. The Theil-Sen slope is the median of
#' the pairwise slopes \eqn{(y_j - y_i)/(x_j - x_i)};
#' \code{intercept} is the line's intercept from the compiled Theil-Sen
#' routine.
#'
#' For \eqn{n \le 8} the p-value is exact by default: \eqn{S} is computed
#' over every ordering of the observed values (with ties kept, so tied data
#' get the correct conditional null). Otherwise the normal approximation is
#' used, with the tie-corrected variance of \eqn{S} and a continuity
#' correction of one unit toward zero. Exact tables are cached in the
#' session, up to 32 of them. A series whose values are all tied has
#' \eqn{S = 0} in every ordering, so its p-value is 1 at every length.
#'
#' The slope interval is the standard rank-based one: the pairwise slopes
#' are sorted and the interval runs between the order statistics that
#' Mann-Kendall's variance places at the chosen level, so it is consistent
#' with the test rather than derived from a different model. At small
#' \eqn{n} the slopes may not reach the requested confidence; the bound is
#' then the most extreme slope and \code{slopecicla} is \code{TRUE}.
#'
#' Missing periods are dropped and the series is sorted by \code{x}. Errors:
#' fewer than three periods; infinite values; \code{x} and \code{y} of different
#' lengths; a period given twice in \code{x}; a data frame without \code{value}
#' or with a column not found; more than 20,000 periods (the pairwise slopes
#' would not fit in memory); a \code{conflvl} outside (0, 1). \code{exact =
#' TRUE} with \eqn{n > 8} warns and uses the normal approximation.
#'
#' @param y Numeric vector, the series in period order, or a data frame.
#' @param x Numeric vector of periods, default \code{NULL}: the position
#'   \code{1, 2, ...}, which is right for an evenly spaced series. Ignored
#'   when \code{y} is a data frame and \code{prd} is given.
#' @param value,prd Column names (strings), when \code{y} is a data
#'   frame. \code{value} is required; \code{prd} is optional and must be
#'   convertible with \code{as.numeric()}.
#' @param exact Logical or \code{NULL} (the default). Whether to compute the
#'   exact null distribution of Mann-Kendall's \eqn{S} by enumeration.
#'   \code{NULL} uses it up to \code{n = 8} (40,320 orderings); above that
#'   the normal approximation with the tie and continuity corrections is
#'   used.
#' @param alt \code{"two.sided"} (the default), \code{"increasing"}
#'   or \code{"decreasing"}.
#' @param conflvl Number in (0, 1), default 0.95: the confidence level of
#'   the slope interval.
#' @return A list of class \code{rmbl_trend_test} with \code{S},
#'   \code{tau}, \code{p_value}, \code{slope}
#'   (Theil-Sen, in units of \code{y} per unit of \code{x}),
#'   \code{intercept}, \code{slopelo} and \code{slopeup} (the
#'   distribution-free interval), \code{slopecicla} (\code{TRUE} when
#'   the pairwise slopes do not reach the requested confidence on a side, so
#'   that bound is the extreme slope and the true interval is wider),
#'   \code{n}, \code{var_S} (the tie-corrected variance of \eqn{S}),
#'   \code{alternative}, \code{conflvl} and \code{method}.
#' @references
#' Sen, P. K. (1968). Estimates of the regression coefficient based on
#' Kendall's tau. \emph{Journal of the American Statistical Association}
#' 63(324), 1379-1389, for the median-of-slopes estimator and the
#' distribution-free interval.
#'
#' Wilcox, R. R. \emph{Modern Statistics for the Social and Behavioral
#' Sciences: A Practical Introduction} treats Theil-Sen among the regression
#' methods that carry no normality assumption, which is the reason for
#' preferring it on a series this short.
#' @seealso
#' \code{\link{stepchg}}, \code{\link{cnttrnd}}
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Five years of placements.
#' y <- c(402, 377, 190, 268, 331)
#' trndtst(y)
#'
#' # A monotone series is detected even at n = 5, where a regression's
#' # standard error would be nearly uninformative.
#' trndtst(c(1, 2, 3, 4, 5))
#'
#' # One aberrant period does not create a trend.
#' trndtst(c(100, 100, 100, 100, 900))$p_value
#'
#' # From a data frame, testing for a decrease only.
#' d <- data.frame(year = 2019:2023, n = y)
#' trndtst(d, value = "n", prd = "year", alt = "decreasing")$p_value
#'
#' try(trndtst(c(5, 6)))
#' @export
#' @srrstats {G5.7} test-trend-scale.R:34 runs 3,000 periods within a wall-clock
#'   limit with finite Sen bounds, and refuses 20,001 periods.
trndtst <- function(
  y,
  x = NULL,
  value = NULL,
  prd = NULL,
  exact = NULL,
  alt = c(
    "two.sided",
    "increasing",
    "decreasing"
  ),
  conflvl = 0.95
) {
  alt <- .rmbl_arg(alt)
  conflvl <- .rmbl_conf_level(conflvl)
  if (is.data.frame(y)) {
    fr <- .trnd_frame(y, x, value, prd)
    x <- fr$x
    y <- fr$y
  }
  sr <- .trnd_series(y, x)
  x <- sr$x
  y <- sr$y
  n <- length(y)
  mk <- .Call(C_rmbl_mann_kendall, y)
  ts <- .Call(C_rmbl_theil_sen, x, y)
  s <- mk$S
  npairs <- n * (n - 1) / 2
  tau <- s / npairs
  pm <- .trnd_p(y, mk, alt, exact)
  ci <- .rmbl_sen_ci(x, y, mk$var, conflvl)
  out <- list(
    S = s,
    tau = tau,
    p_value = pm$p,
    slope = ts$slope,
    intercept = ts$intercept,
    slopelo = ci[1L],
    slopeup = ci[2L],
    slopecicla = isTRUE(any(attr(ci, "clamped"))),
    n = n,
    var_S = mk$var,
    alternative = alt,
    conflvl = conflvl,
    method = pm$method
  )
  class(out) <- c("rmbl_trend_test", class(out))
  out
}

#' @export
format.rmbl_trend_test <- function(x, digits = 4L, ...) {
  lvl <- x$conflvl
  d <- data.frame(
    term = c("Kendall tau", "Sen slope"),
    estimate = c(x$tau, x$slope),
    interval = c("", .rmbl_fmt_ci(x$slopelo, x$slopeup, digits)),
    p = c(x$p_value, NA_real_),
    stringsAsFactors = FALSE
  )
  names(d)[3L] <- .rmbl_ci_name(lvl)
  .rmbl_res_block(
    "Trend test",
    facts = list(
      Method = x$method,
      Periods = x$n,
      S = x$S,
      Alternative = x$alternative,
      Confidence = .rmbl_lvl(lvl)
    ),
    tables = d,
    reading = .rmbl_trend_reading(x),
    notes = if (isTRUE(x$slopecicla)) {
      "The slope's interval was clamped to the range of the pairwise slopes."
    },
    digits = digits
  )
}

# Exact null distribution of S, memoised: every ordering of n distinct
# ranks is equally likely under the null, so S's distribution is the
# distribution of S over the permutations.
.rmbl_mk_cache <- new.env(parent = emptyenv())

#' A single step change, with the scan's own null distribution
#'
#' @description
#' Asks whether a series shifted to a new level at some point (for example
#' after a policy change) and, if so, where. It scans every admissible
#' split of the series, reports the one with the largest difference between
#' the before and after means, and gives it a p-value from the permutation
#' distribution of the MAXIMUM over splits -- not from the best split's own
#' test, which is the standard way to find a change point in noise.
#'
#' @details
#' For a split after period \eqn{k}, with \eqn{n_a = k} and
#' \eqn{n_b = n - k} periods and means \eqn{\bar y_a}, \eqn{\bar y_b}, the
#' statistic is the between-segment sum of squares
#' \deqn{T_k = \frac{n_a n_b}{n} (\bar y_a - \bar y_b)^2,}
#' over \eqn{k = m, \dots, n - m} with \eqn{m} = \code{minseg}. The
#' observed \eqn{\max_k T_k} is compared with the same maximum over
#' reorderings of the series, and \eqn{p = (1 + \mathrm{count}(T^*_{\max} \ge
#' T_{\max}))/(1 + B)} over \eqn{B} random reorderings. When \eqn{n! \le}
#' \code{nperm} (with the default, \eqn{n \le 7}) every ordering is
#' enumerated, the observed one among them, and the p-value is exact:
#' \eqn{\mathrm{count}(T^*_{\max} \ge T_{\max}) / n!};
#' otherwise \code{nperm} random permutations are drawn under \code{seed},
#' and the caller's random number stream is restored afterwards.
#'
#' The test assumes the periods are exchangeable under no change, so it ignores
#' autocorrelation and smooth trends; a steady trend can produce a
#' \code{"step"}. With very few periods even a clean step cannot reach small
#' p-values (six periods allow only 720 orderings). Missing values are dropped.
#' A series with values beyond 1e150 is scanned in units of its largest absolute
#' value, so the statistic does not overflow; \code{before}, \code{after} and
#' \code{difference} are given back in the units of \code{y}, and
#' \code{statistic} stays in the rescaled units. Errors: infinite values; fewer
#' than \code{2 * minseg} periods; numeric or date \code{x} that is not strictly
#' increasing. A progress bar is shown in an interactive session.
#'
#' @param y Numeric vector, the series in period order.
#' @param x Numeric or date periods, default \code{NULL} (the position),
#'   strictly increasing and not missing where \code{y} has a value. Used only
#'   to label the break.
#' @param minseg Whole number, default 2: the fewest periods allowed on
#'   either side of the break.
#' @param nperm Whole number, default 9999: the number of random
#'   permutations for the null distribution. The exact enumeration is used
#'   instead when \eqn{n!} is at most \code{nperm}.
#' @param seed Integer, default 1: the seed for the permutations, so the
#'   p-value is reproducible.
#' @return A list of class \code{rmbl_step_change} with \code{breakafter}
#'   (the period the series changes
#'   after, from \code{x}), \code{index} (its position), \code{before} and
#'   \code{after} (the segment means), \code{difference} (after minus
#'   before), \code{statistic} (\eqn{T_{\max}}), \code{p_value},
#'   \code{nperm} (orderings or permutations used) and \code{method}.
#' @references
#' The permutation distribution of the maximum over splits, rather than the
#' chosen split's own test, is what makes this a test of whether there is a
#' break rather than a way of locating the largest wobble. See any
#' treatment of the change-point problem, e.g. Coles, S. \emph{An
#' Introduction to Statistical Modeling of Extreme Values} (Springer), which
#' discusses change-point detection alongside the threshold choices that
#' raise the same multiple-comparison issue.
#' @seealso \code{\link{trndtst}}, \code{\link{cnttrnd}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # A step down after the third period. With six periods there are only
#' # 720 orderings, so even a clean step has p near 0.1.
#' stepchg(c(100, 104, 98, 60, 63, 58), x = 2018:2023)
#'
#' # A longer series with the same step is clearly significant.
#' stepchg(c(100, 104, 98, 101, 97, 60, 63, 58, 61, 59), nperm = 999)$p_value
#'
#' # Pure noise: the best split is still found, and is not significant.
#' set.seed(2)
#' stepchg(stats::rnorm(12), nperm = 999)$p_value
#'
#' try(stepchg(c(1, 2, 3)))
#' @export
#' @srrstats {TS1.6} stepchg() refuses numeric or date periods that are not
#'   strictly increasing, and trndtst() refuses duplicated periods; test-srr.R.
stepchg <- function(y, x = NULL, minseg = 2L, nperm = 9999L, seed = 1L) {
  sr <- .step_series(y, x)
  x <- sr$x
  y <- sr$y
  n <- length(y)
  # the statistic is a squared difference of means, so values near 1e300
  # overflowed it to Inf and the p-value was NaN (final audit of 1.0.0, #11); it
  # is scale-free, as is the permutation null, so the series is read in units of
  # its largest value when that is beyond 1e150, or below 1e-150, where the
  # squares underflowed to 0 and every split tied (y * 1e-200 broke after period
  # 2 with p = 1; pre-CRAN audit of 30bed8e) before, after and difference are
  # put back in the units of y at the end
  m <- if (n) max(abs(y)) else 0
  sc <- if (m > 1e150 || (m > 0 && m < 1e-150)) m else 1
  y <- y / sc
  minseg <- .rmbl_scalar(minseg, "minseg", 1, integer = TRUE)
  nperm <- .rmbl_scalar(nperm, "nperm", 1, integer = TRUE)
  .step_check_n(n, minseg)
  # `y` is already reduced to its finite values and the statistic is a
  # weighted squared difference of means, so every split scores a finite
  # number. There is no inadmissible-scan case left to guard against;
  # the earlier guard for one could not fire.
  obs <- .step_stat(y, minseg)
  best <- obs$cuts[which.max(obs$vals)]
  tmax <- max(obs$vals)
  a <- y[seq_len(best)]
  b <- y[(best + 1L):n]

  # The null: the periods are exchangeable, so permute them and take the
  # same MAXIMUM over splits. Comparing the best split against its own
  # null would find a break in any series.
  nl <- .step_null(y, minseg, nperm, seed)
  p <- .step_p(nl$null, tmax, nl$nfact <= nperm)
  out <- list(
    breakafter = x[best],
    index = best,
    before = mean(a) * sc,
    after = mean(b) * sc,
    difference = (mean(b) - mean(a)) * sc,
    statistic = tmax,
    p_value = min(1, p),
    nperm = nl$np,
    method = nl$method
  )
  class(out) <- c("rmbl_step_change", class(out))
  out
}

#' @export
format.rmbl_step_change <- function(x, digits = 4L, ...) {
  .rmbl_res_block(
    "Step change",
    facts = list(
      Method = x$method,
      Permutations = x$nperm,
      `Break after` = format(x$breakafter),
      `Break at index` = x$index
    ),
    tables = data.frame(
      before = x$before,
      after = x$after,
      difference = x$difference,
      statistic = x$statistic,
      p = x$p_value
    ),
    reading = sprintf(
      paste(
        "The best single split is after %s: the mean moves from %s to %s.",
        "The p-value compares that best split with the best split of",
        "shuffled series, so it allows for having searched every split",
        "(p %s)."
      ),
      format(x$breakafter),
      .rmbl_fmt_num(x$before, digits),
      .rmbl_fmt_num(x$after, digits),
      .rmbl_p_txt(x$p_value)
    ),
    digits = digits
  )
}

#' Trend in a count series, as a rate ratio per period
#'
#' @description
#' Estimates the trend in a series of counts (arrests, admissions,
#' incidents per year) as a rate ratio per period: 0.85 means the count
#' falls by 15% a year. It fits a Poisson log-linear model and, when the
#' counts vary more than a Poisson model allows, widens the interval. An
#' offset carries the denominator when the exposure varies, so the trend is
#' then in the rate rather than in the count.
#'
#' @details
#' The model is \eqn{\log \mu_t = \beta_0 + \beta_1 (x_t - \bar x) +
#' \log o_t}, with \eqn{o_t} the offset (1 when none), fitted by iteratively
#' reweighted least squares (at most 50 iterations). The rate ratio is
#' \eqn{e^{\beta_1}}, with a Wald interval \eqn{e^{\beta_1 \pm z\,
#' \mathrm{se}}}.
#'
#' The dispersion is reported because a Poisson fit assumes it is one. It
#' is the Pearson statistic \eqn{\sum (y - \mu)^2/\mu} divided by
#' \eqn{n - 2}. When it exceeds 1.5 the quasi-Poisson interval is returned
#' instead: the standard error is multiplied by the square root of the
#' dispersion and the \eqn{t} distribution on \eqn{n - 2} degrees of freedom
#' replaces the normal, and \code{overdispersed} is set.
#'
#' Missing values are dropped. Errors: negative or fractional counts;
#' \code{x} and \code{y} of different lengths; infinite \code{x}; every count
#' zero; an offset of the wrong length or not positive; fewer than three
#' periods; a \code{conflvl} outside (0, 1). When the counts are zero at
#' one end of the series only (\code{c(0, 0, 5)}) the likelihood rises without
#' bound and there is no finite trend: a warning says so, the rate ratio is
#' \code{Inf} (or 0) and the interval and p-value are \code{NA}. There is a
#' \code{plot()} method for the result.
#'
#' @param y Numeric vector of counts (non-negative whole numbers), in period
#'   order.
#' @param x Numeric vector of periods, default \code{NULL} (the position).
#'   The rate ratio is per unit of \code{x}.
#' @param offset Optional numeric vector of exposures, one per period -- a
#'   population, a number of admissions, a number of days. Positive. The
#'   trend is then in the rate rather than in the count.
#' @param conflvl Number in (0, 1), default 0.95: the confidence level of
#'   the rate-ratio interval.
#' @return A list of class \code{c("rmbl_count_trend", "list")} with
#'   \code{rateratio} (per period), \code{lower}, \code{upper},
#'   \code{p_value} (test of no trend), \code{logslope} (\eqn{\beta_1}),
#'   \code{se} (its standard error, scaled when overdispersed),
#'   \code{fitted} (fitted counts), \code{dispersion}, \code{overdispersed}
#'   (logical), \code{n}, \code{data} (list of the \code{x} and \code{y}
#'   used) and \code{method}.
#' @references
#' Bilder, C. R. and Loughin, T. M. \emph{Analysis of Categorical Data with
#' R}, 2nd edn. Chapman and Hall/CRC, on the quasi-likelihood treatment of
#' an overdispersed Poisson fit: the variance is scaled by an estimated
#' dispersion, which widens the interval while leaving the point estimate
#' alone. That is the behaviour reported here through \code{dispersion} and
#' \code{overdispersed}.
#' @seealso \code{\link{trndtst}}, \code{\link{ratechg}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # A count falling by about 15% a year.
#' set.seed(3)
#' y <- stats::rpois(8, lambda = 200 * 0.85^(0:7))
#' fit <- cnttrnd(y)
#' round(fit$rateratio, 3)
#' c(fit$lower, fit$upper)
#'
#' # With a varying denominator the trend is in the rate.
#' cnttrnd(c(20, 25, 30), offset = c(1000, 1500, 2500))$rateratio
#'
#' # Counts that swing far more than Poisson noise get the wider interval.
#' wild <- cnttrnd(c(10, 50, 5, 60, 8, 70))
#' wild$dispersion
#' wild$method
#'
#' try(cnttrnd(c(1.5, 2, 3)))
#' @export
#' @srrstats {TS5.0} Each result class has a default plot method
#'   (plot.rmbl_count_trend, rmbl_yoy, rmbl_stock_flow, rmbl_event_study);
#'   tested in test-plots.R:236.
cnttrnd <- function(y, x = NULL, offset = NULL, conflvl = 0.95) {
  conflvl <- .rmbl_conf_level(conflvl)
  a <- .ct_finite(.ct_inputs(y, x, offset))
  x <- a$x
  y <- a$y
  logoff <- a$logoff
  n <- length(y)
  # centre the periods so the intercept is interpretable and the normal
  # equations are better conditioned
  xc <- x - mean(x)
  # iteratively reweighted least squares on the two-column design (no glm)
  fit <- .ct_irls(y, xc, logoff)
  beta <- fit$beta
  converged <- fit$converged
  eta <- beta[1L] + beta[2L] * xc + logoff
  mu <- exp(eta)
  diverged <- !converged && any(y == 0 & mu < 1e-8 * max(mu))
  if (diverged) {
    beta[2L] <- .ct_diverged(beta[2L])
  }
  se <- .ct_se(mu, xc, diverged)
  # Pearson dispersion: the Poisson fit assumes this is one, and when it
  # is not the interval below is too narrow
  resid <- (y - mu) / sqrt(mu)
  disp <- if (n > 2L) sum(resid^2) / (n - 2L) else NA_real_
  over <- is.finite(disp) && disp > 1.5
  se_use <- if (over && is.finite(se)) se * sqrt(disp) else se
  inf <- .ct_interval(beta[2L], se_use, over, n, conflvl)
  structure(
    list(
      rateratio = exp(beta[2L]),
      lower = inf$lower,
      upper = inf$upper,
      p_value = inf$p_value,
      logslope = beta[2L],
      se = se_use,
      fitted = mu,
      dispersion = disp,
      overdispersed = over,
      n = n,
      data = list(x = x, y = y),
      method = if (over) {
        "quasi-Poisson (dispersion above 1.5)"
      } else {
        "Poisson log-linear"
      }
    ),
    class = c("rmbl_count_trend", "list")
  )
}

#' @export
format.rmbl_count_trend <- function(x, digits = 4L, ...) {
  .rmbl_res_block(
    "Count trend",
    facts = list(
      Method = x$method,
      Periods = x$n,
      Dispersion = x$dispersion
    ),
    tables = data.frame(
      term = "rate ratio per period",
      estimate = x$rateratio,
      interval = .rmbl_fmt_ci(x$lower %||% NA_real_, x$upper %||% NA_real_),
      p = x$p_value %||% NA_real_,
      stringsAsFactors = FALSE
    ),
    reading = .rmbl_rr_reading(
      "Each period multiplies the expected count by",
      x$rateratio,
      x$lower,
      x$upper
    ),
    notes = if (isTRUE(x$overdispersed)) {
      paste(
        "The counts vary more than a Poisson model allows, so the standard",
        "error is scaled by the square root of the dispersion."
      )
    },
    digits = digits
  )
}

# A bounded memo for the exact Mann-Kendall distributions: at most 32 tables,
# the OLDEST evicted when the 33rd arrives (0.5.8 flushed all 32 at once, so a
# loop over 33 series got no reuse at all; its diff review). Insertion order is
# kept beside the tables.
.rmbl_mk_order <- new.env(parent = emptyenv())

#' Returns the exact null distribution of the Mann-Kendall S for n distinct
#' ranks, memoised.
#' @param n The series length.
#' @return A numeric vector of S, one per permutation.
#' @noRd
.rmbl_mk_exact <- function(n) {
  key <- as.character(n)
  if (!is.null(.rmbl_mk_cache[[key]])) {
    return(.rmbl_mk_cache[[key]])
  }
  perms <- .rmbl_permutations(n)
  s <- apply(perms, 1L, function(p) {
    tot <- 0
    for (i in seq_len(n - 1L)) {
      tot <- tot + sum(sign(p[(i + 1L):n] - p[i]))
    }
    tot
  })
  .rmbl_mk_remember(key, s)
  s
}

#' S over every ordering of the observed values themselves (ties and all).
#' @param y The observed values.
#' @return A numeric vector of S, one per permutation.
#' @noRd
.rmbl_mk_exact_values <- function(y) {
  n <- length(y)
  # memoised on the observed multiset: a loop over short tied series paid
  # 0.6 s per call for the same 40,320 orderings
  key <- paste(c(n, sort(y)), collapse = ",")
  if (!is.null(.rmbl_mk_cache[[key]])) {
    return(.rmbl_mk_cache[[key]])
  }
  perms <- .rmbl_permutations(n)
  s <- apply(perms, 1L, function(p) {
    v <- y[p]
    tot <- 0
    for (i in seq_len(n - 1L)) {
      tot <- tot + sum(sign(v[(i + 1L):n] - v[i]))
    }
    tot
  })
  .rmbl_mk_remember(key, s)
  s
}

#' Lists every permutation of 1 to n.
#' @param n The number of elements.
#' @return An integer matrix with one permutation per row.
#' @noRd
.rmbl_permutations <- function(n) {
  if (n == 1L) {
    return(matrix(1L, 1L, 1L))
  }
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

#' Computes the distribution-free confidence interval of the Theil-Sen slope.
#'
#' Distribution-free interval for the Theil-Sen slope: the pairwise
#' slopes, sorted, cut at the order statistics Mann-Kendall's variance
#' places at the level. Consistent with the test, rather than borrowed
#' from a normal-errors model the data was never claimed to follow.
#' @param x The time points of the Sen slopes.
#' @param y The values of the Sen slopes.
#' @param var_s The variance of the Mann-Kendall S.
#' @param conf_level The confidence level of the Sen slope interval.
#' @return The lower and upper bounds, with a `clamped` attribute for each side.
#' @noRd
.rmbl_sen_ci <- function(x, y, var_s, conf_level) {
  conf_level <- .rmbl_conf_level(conf_level)
  slopes <- .Call(C_rmbl_sen_slopes, as.numeric(x), as.numeric(y))
  m <- length(slopes)
  if (m < 2L || is.na(var_s) || var_s <= 0) {
    return(c(NA_real_, NA_real_))
  }
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  c_alpha <- z * sqrt(var_s)
  lo_rank <- floor((m - c_alpha) / 2)
  hi_rank <- ceiling((m + c_alpha) / 2) + 1
  # A rank off either end means the pairwise slopes do not reach the
  # requested confidence on that side (at n = 5 the 95% lower rank is
  # 0.999, at n = 3 both are off). The bound shown is then the extreme
  # slope and the true interval is wider; the result says so through
  # `slopecicla` rather than presenting the clamp as an interval.
  clamped <- c(lo_rank <= 1, hi_rank >= m)
  lo_rank <- max(1L, min(m, as.integer(lo_rank)))
  hi_rank <- max(1L, min(m, as.integer(hi_rank)))
  structure(c(slopes[lo_rank], slopes[hi_rank]), clamped = clamped)
}

#' cnttrnd()'s counts, periods and offset, checked; the offset on the log
#' scale.
#' @param y,x,offset As for cnttrnd().
#' @return A list: x, y and logoff.
#' @noRd
.ct_inputs <- function(y, x, offset) {
  y <- .rmbl_num(y, "y")
  if (is.null(x)) {
    x <- seq_along(y)
  }
  x <- .rmbl_num(x, "x")
  if (length(x) != length(y)) {
    stop("cnttrnd: `x` and `y` must be the same length", call. = FALSE)
  }
  if (
    any(y < 0, na.rm = TRUE) ||
      any(abs(y - round(y)) > 1e-8, na.rm = TRUE)
  ) {
    stop("`y` must be non-negative whole numbers", call. = FALSE)
  }
  if (any(is.infinite(x))) {
    stop("`x` must not contain infinite values", call. = FALSE)
  }
  if (all(y == 0, na.rm = TRUE)) {
    stop(
      "every count is zero: there is no rate to fit a trend to",
      call. = FALSE
    )
  }
  logoff <- if (is.null(offset)) {
    rep(0, length(y))
  } else {
    off <- .rmbl_num(offset, "offset")
    if (length(off) != length(y)) {
      stop("`offset` must be the same length as `y`", call. = FALSE)
    }
    if (any(off <= 0, na.rm = TRUE)) {
      stop("`offset` must be positive", call. = FALSE)
    }
    log(off)
  }
  list(x = x, y = y, logoff = logoff)
}

#' The Poisson log-linear trend by iteratively reweighted least squares on
#' the two-column design.
#' @param y The counts fitted by the IRLS.
#' @param xc The centred periods.
#' @param logoff The log offset.
#' @return A list: beta and converged.
#' @noRd
.ct_irls <- function(y, xc, logoff) {
  beta <- c(log(max(sum(y), 1) / length(y)) - mean(logoff), 0)
  converged <- FALSE
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
    if (!is.finite(det) || abs(det) < 1e-12) {
      break
    }
    nb <- c(
      (swxx * swz - swx * swxz) / det,
      (sw * swxz - swx * swz) / det
    )
    if (max(abs(nb - beta)) < 1e-10) {
      beta <- nb
      converged <- TRUE
      break
    }
    beta <- nb
  }
  list(beta = beta, converged = converged)
}

#' Keeps the periods of a count series where everything is finite, and
#' refuses fewer than three.
#' @param a The inputs from .ct_inputs(): x, y and logoff.
#' @return The same list, on the finite periods.
#' @noRd
.ct_finite <- function(a) {
  ok <- is.finite(a$x) & is.finite(a$y) & is.finite(a$logoff)
  out <- list(x = a$x[ok], y = a$y[ok], logoff = a$logoff[ok])
  if (length(out$y) < 3L) {
    stop("cnttrnd: a trend needs at least three periods", call. = FALSE)
  }
  out
}

#' Warns of a count trend with no finite estimate.
#'
#' Zero counts at one end only (0, 0, 5): the likelihood rises without bound as
#' the slope grows, so there is no finite estimate and the iterations stop
#' wherever they stop (a rate ratio of 9.7e16, unwarned; CRAN stress test of
#' 0.5.14). glm() warns "fitted rates numerically 0".
#' @param b The log slope where the iterations stopped.
#' @return The slope as reported: Inf or -Inf.
#' @noRd
.ct_diverged <- function(b) {
  warning(
    "the counts are zero at one end of the series, so the trend has ",
    "no finite estimate: ",
    "the rate ratio is reported as ",
    if (b > 0) "Inf" else "0",
    " with no interval",
    call. = FALSE
  )
  sign(b) * Inf
}

#' The standard error of the log slope of a Poisson trend.
#' @param mu The fitted counts.
#' @param xc The centred periods.
#' @param diverged Whether the fit has no finite estimate.
#' @return The standard error, NA when there is none.
#' @noRd
.ct_se <- function(mu, xc, diverged) {
  sw <- sum(mu)
  swx <- sum(mu * xc)
  swxx <- sum(mu * xc * xc)
  det <- sw * swxx - swx^2
  if (!diverged && is.finite(det) && det > 0) sqrt(sw / det) else NA_real_
}

#' The interval and p-value of the rate ratio of a count trend.
#' @param b The log slope.
#' @param se_use Its standard error, scaled for overdispersion.
#' @param over Whether the counts are overdispersed.
#' @param n The number of periods; the t interval has `n - 2` df.
#' @param conflvl The confidence level of the count trend interval.
#' @return A list: \code{lower}, \code{upper} and \code{p_value}.
#' @noRd
.ct_interval <- function(b, se_use, over, n, conflvl) {
  # quasi-likelihood estimates the dispersion from n - 2 residual degrees
  # of freedom, so its reference distribution is t, not normal: on a
  # four-period series z = 1.96 where t = 4.30 is wanted
  z <- if (over) {
    stats::qt(1 - (1 - conflvl) / 2, df = n - 2L)
  } else {
    stats::qnorm(1 - (1 - conflvl) / 2)
  }
  list(
    lower = if (is.finite(se_use)) exp(b - z * se_use) else NA_real_,
    upper = if (is.finite(se_use)) exp(b + z * se_use) else NA_real_,
    p_value = if (is.finite(se_use) && se_use > 0) {
      if (over) {
        2 * stats::pt(-abs(b / se_use), df = n - 2L)
      } else {
        2 * stats::pnorm(-abs(b / se_use))
      }
    } else {
      NA_real_
    }
  )
}

#' Stores an exact Mann-Kendall distribution in the bounded memo.
#' @param key The memo key.
#' @param value The distribution.
#' @return `value`, invisibly.
#' @noRd
.rmbl_mk_remember <- function(key, value) {
  keys <- get0(
    "keys",
    envir = .rmbl_mk_order,
    inherits = FALSE,
    ifnotfound = character()
  )
  keys <- keys[keys %in% ls(.rmbl_mk_cache, all.names = TRUE)]
  if (!key %in% keys) {
    while (length(keys) >= 32L) {
      rm(list = keys[[1L]], envir = .rmbl_mk_cache)
      keys <- keys[-1L]
    }
    keys <- c(keys, key)
  }
  assign("keys", keys, envir = .rmbl_mk_order)
  .rmbl_mk_cache[[key]] <- value
  invisible(value)
}

#' Reads the series of trndtst() from a data frame's columns.
#' @param d The data frame holding `value` and `prd`.
#' @param x The periods given, kept when \code{prd} is NULL.
#' @param value The value column.
#' @param prd The period column, or NULL.
#' @return A list: \code{x} and \code{y}.
#' @noRd
.trnd_frame <- function(d, x, value, prd) {
  if (is.null(value)) {
    stop("`value` is required for a data frame", call. = FALSE)
  }
  if (!value %in% names(d)) {
    stop(sprintf("`value` column not found: %s", value), call. = FALSE)
  }
  if (!is.null(prd)) {
    if (!prd %in% names(d)) {
      stop(sprintf("`prd` column not found: %s", prd), call. = FALSE)
    }
    x <- as.numeric(d[[prd]])
  }
  list(x = x, y = as.numeric(d[[value]]))
}

#' Checks the series of trndtst(), drops its missing periods and sorts it.
#' @param y The values tested for a trend.
#' @param x The periods, or NULL for 1, 2, ...
#' @return A list: \code{x} and \code{y}, sorted by period.
#' @noRd
.trnd_series <- function(y, x) {
  y <- .rmbl_num(y, "y")
  if (is.null(x)) {
    x <- seq_along(y)
  }
  x <- .rmbl_num(x, "x")
  if (length(x) != length(y)) {
    stop("trndtst: `x` and `y` must be the same length", call. = FALSE)
  }
  if (any(is.infinite(y)) || any(is.infinite(x))) {
    # a missing period is dropped; an infinite value is a data error
    stop("`x` and `y` must not contain infinite values", call. = FALSE)
  }
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]
  y <- y[ok]
  if (anyDuplicated(x)) {
    # two values for one period are not a series; Sen's slope would divide by a
    # zero gap
    stop(
      "`x` has duplicated periods: combine the values of each period first",
      call. = FALSE
    )
  }
  ord <- order(x)
  x <- x[ord]
  y <- y[ord]
  n <- length(y)
  if (n < 3L) {
    stop("trndtst: a trend needs at least three periods", call. = FALSE)
  }
  if (n > 20000L) {
    stop(
      sprintf(
        paste0(
          "trndtst() enumerates all n(n-1)/2 pairwise ",
          "slopes for the Sen interval; n = %d would need ",
          "%.1f GB. Aggregate or thin the series first."
        ),
        n,
        n * (n - 1) / 2 * 8 / 1e9
      ),
      call. = FALSE
    )
  }
  list(x = x, y = y)
}

#' The Mann-Kendall p-value: exact up to n = 8 unless asked otherwise, else
#' the normal approximation.
#' @param y The values, sorted by period.
#' @param mk The Mann-Kendall statistic and its variance.
#' @param alt The alternative.
#' @param exact TRUE, FALSE or NULL (exact up to n = 8).
#' @return A list: \code{p} and the \code{method} text.
#' @noRd
.trnd_p <- function(y, mk, alt, exact) {
  n <- length(y)
  if (isTRUE(exact) && n > 8L) {
    warning(
      sprintf(
        paste0(
          "exact = TRUE is available up to n = 8 (n = %d): using the ",
          "normal approximation"
        ),
        n
      ),
      call. = FALSE
    )
  }
  if (is.null(exact)) {
    exact <- n <= 8L
  }
  if (isTRUE(exact) && n <= 8L) {
    .trnd_exact_p(y, mk$S, alt)
  } else {
    .trnd_normal_p(mk, mk$S, alt)
  }
}

#' The exact Mann-Kendall p-value over every ordering, for n of 8 or fewer.
#' @param y The values, sorted by period.
#' @param s The Mann-Kendall S.
#' @param alt The alternative.
#' @return A list: \code{p} and the \code{method} text.
#' @noRd
.trnd_exact_p <- function(y, s, alt) {
  n <- length(y)
  # With ties the null is over the orderings of the OBSERVED multiset,
  # not of n distinct ranks: S is computed with sign(), so tied pairs
  # contribute 0 and the distinct-rank null is wrong in both
  # directions (p = 0.0167 for 1,1,2,2,3,3 where the exact conditional
  # p is 0.0222).
  tied <- anyDuplicated(y) > 0L
  null_s <- if (tied) .rmbl_mk_exact_values(y) else .rmbl_mk_exact(n)
  p <- switch(
    alt,
    increasing = mean(null_s >= s),
    decreasing = mean(null_s <= s),
    two.sided = mean(abs(null_s) >= abs(s))
  )
  method <- if (tied) {
    sprintf(
      paste0(
        "Mann-Kendall, exact over all %d orderings of the observed ",
        "values (ties kept)"
      ),
      length(null_s)
    )
  } else {
    sprintf("Mann-Kendall, exact over all %d orderings", length(null_s))
  }
  list(p = p, method = method)
}

#' The Mann-Kendall p-value by the normal approximation.
#' @param mk The Mann-Kendall statistic and its variance.
#' @param s The Mann-Kendall S.
#' @param alt The alternative.
#' @return A list: \code{p} and the \code{method} text.
#' @noRd
.trnd_normal_p <- function(mk, s, alt) {
  # the continuity correction moves S one unit toward zero, since S
  # changes in steps of two
  z <- if (is.na(mk$var) || mk$var <= 0) {
    NA_real_
  } else {
    (s - sign(s)) / sqrt(mk$var)
  }
  p <- switch(
    alt,
    increasing = stats::pnorm(z, lower.tail = FALSE),
    decreasing = stats::pnorm(z),
    two.sided = 2 * stats::pnorm(-abs(z))
  )
  # every value tied: S is 0 in every ordering, so p is 1 in every direction,
  # as the exact test says at n <= 8 (it was NA past 8; CRAN stress test of
  # 0.5.14)
  if (!is.na(mk$var) && mk$var <= 0) {
    p <- 1
  }
  p <- min(1, p)
  method <- "Mann-Kendall, normal approximation with tie correction"
  list(p = p, method = method)
}

#' Checks the series of stepchg() and drops its missing values.
#' @param y The values searched for a step.
#' @param x The periods, or NULL for 1, 2, ...
#' @return A list: \code{x} and \code{y}.
#' @noRd
.step_series <- function(y, x) {
  y <- .rmbl_num(y, "y")
  if (is.null(x)) {
    x <- seq_along(y)
  }
  if (!is.atomic(x) || is.matrix(x) || length(x) != length(y)) {
    stop("`x` must be one time or position per value of `y`", call. = FALSE)
  }
  if (any(is.infinite(y))) {
    # a missing period is dropped; an infinite value is a data error
    stop("`y` must not contain infinite values", call. = FALSE)
  }
  ok <- is.finite(y)
  y <- y[ok]
  x <- x[ok]
  # the scan splits the series in the order given, so the periods must be
  # numbers or dates in time order: a character or factor x has no order to
  # check, and "40" < "5" (pre-CRAN audit of 30bed8e)
  if (!(is.numeric(x) || inherits(x, c("Date", "POSIXt"))) || is.factor(x)) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`x` must be numbers or dates (the periods), not %s",
        class(x)[1L]
      ),
      call. = FALSE
    )
  }
  if (anyNA(x)) {
    stop(
      .rmbl_fn(),
      "`x` has a missing period where `y` has a value",
      call. = FALSE
    )
  }
  if (is.unsorted(x, strictly = TRUE)) {
    stop(
      .rmbl_fn(),
      "`x` must be strictly increasing: sort the series by period first",
      call. = FALSE
    )
  }
  list(x = x, y = y)
}

# The weighted squared mean difference,
#   (n_a n_b / n) (mean_a - mean_b)^2,
# which is the between-group sum of squares for the split. A
# studentised version would divide by the within-segment spread and so
# return Inf for a segment with no variation -- a PERFECT step, the
# clearest signal there is, which then fell out as inadmissible. The
# permutation null accounts for the spread without the statistic
# having to.
#' Refuses a series too short for a break with \code{minseg} values either side.
#' @param n The number of values, at least twice `minseg`.
#' @param minseg The fewest values either side of a break.
#' @return NULL, invisibly.
#' @noRd
.step_check_n <- function(n, minseg) {
  if (n < 2L * minseg) {
    stop(
      sprintf(
        "need at least %d periods for a break with %d either side",
        2L * minseg,
        minseg
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' The permutation p-value of the largest split statistic.
#' @param null The null statistics.
#' @param tmax The observed statistic.
#' @param enumerated Whether the null is every ordering rather than drawn.
#' @return The p-value, before it is capped at 1.
#' @noRd
.step_p <- function(null, tmax, enumerated) {
  null <- null[is.finite(null)]
  # an ordering that makes the same split as the observed one scores it to
  # rounding
  hit <- null >= tmax - 1e-12 * abs(tmax)
  # Drawn permutations: the observed arrangement counts in its own null --
  # without it a p-value of exactly zero is reportable, and no permutation test
  # can support that. Enumerated: the observed ordering is already one of the
  # n!, and counting it again added one (73/721 for 0.1; CRAN stress test of
  # 0.5.14).
  if (enumerated) mean(hit) else (1 + sum(hit)) / (1 + length(null))
}

#' The split statistic of stepchg() at every admissible break.
#' @param v The values, in period order.
#' @param minseg The fewest values either side of a break.
#' @return A list: \code{cuts}, the breaks, and \code{vals}, the statistic at
#'   each.
#' @noRd
.step_stat <- function(v, minseg) {
  n <- length(v)
  cuts <- seq.int(minseg, n - minseg)
  vals <- vapply(
    cuts,
    function(k) {
      a <- v[seq_len(k)]
      b <- v[(k + 1L):n]
      (length(a) * length(b) / n) * (mean(a) - mean(b))^2
    },
    0
  )
  list(cuts = cuts, vals = vals)
}

#' The null distribution of the largest split statistic of stepchg().
#'
#' Every ordering when there are no more of them than \code{nperm}, else
#' \code{nperm} permutations drawn under \code{seed}.
#' @param y The values permuted under the null.
#' @param minseg The fewest values either side of a break.
#' @param nperm The most permutations.
#' @param seed The seed of the drawn permutations.
#' @return A list: \code{null}, \code{nfact} (the number of orderings, Inf past
#'   8 values), \code{method} and \code{np}, the number of orderings used.
#' @noRd
.step_null <- function(y, minseg, nperm, seed) {
  n <- length(y)
  nfact <- if (n <= 8L) factorial(n) else Inf
  pg <- blprog("step change", .bl_count(min(nfact, nperm)))
  on.exit(pg$done(), add = TRUE)
  if (nfact <= nperm) {
    perms <- .rmbl_permutations(n)
    np <- nrow(perms)
    null <- vapply(
      seq_len(np),
      function(i) {
        pg$update(i - 1L, sprintf("ordering %d/%d", i, np))
        max(.step_stat(y[perms[i, ]], minseg)$vals)
      },
      0
    )
    method <- sprintf("exact over all %d orderings", nrow(perms))
    np <- nrow(perms)
  } else {
    old <- if (exists(".Random.seed", envir = globalenv())) {
      get(".Random.seed", envir = globalenv())
    } else {
      NULL
    }
    .rmbl_local_seed(seed)
    null <- vapply(
      seq_len(nperm),
      function(i) {
        pg$update(i - 1L, sprintf("permutation %d/%d", i, nperm))
        max(.step_stat(sample(y), minseg)$vals)
      },
      0
    )
    if (is.null(old)) {
      suppressWarnings(rm(".Random.seed", envir = globalenv()))
    } else {
      assign(".Random.seed", old, envir = globalenv())
    }
    method <- sprintf("%d permutations of the maximum over splits", nperm)
    np <- nperm
  }
  list(null = null, nfact = nfact, method = method, np = np)
}

# ---- printed reports ---------------------------------------------------------

#' The reading of a Mann-Kendall trend test.
#' @param x A trndtst() result.
#' @return Sentences.
#' @noRd
.rmbl_trend_reading <- function(x) {
  dir <- if (!is.finite(x$tau) || x$tau == 0) {
    "no direction"
  } else if (x$tau > 0) {
    "an upward tendency"
  } else {
    "a downward tendency"
  }
  c(
    sprintf(
      "Kendall's tau of %s means %s (p %s);",
      .rmbl_fmt_num(x$tau),
      dir,
      .rmbl_p_txt(x$p_value)
    ),
    sprintf(
      "the Sen slope says the series moves by about %s per period.",
      .rmbl_fmt_num(x$slope)
    )
  )
}
