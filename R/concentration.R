# Concentration, and association in a contingency table.
#
# The recurring question about an administrative table is whether a few
# units account for most of the total: a handful of individuals holding
# most of the placements, one region holding most of the days. That is a
# concentration measure, and the honest ones come with their own caveats
# -- a Gini computed from banded data inherits the band assumption, and a
# tail index fitted to twelve observations is a number with no precision.

#' Concentration of a total across units
#'
#' @param x Non-negative values, one per unit.
#' @param na.rm Whether to drop missing values. They are dropped either
#'   way; this argument exists so the call reads the same as base R's.
#' @return `gini()` a single number in `[0, 1]`, `NA` when the total is
#'   zero. `lorenz()` a data frame of cumulative population and value
#'   shares, including the origin. `top_share()` a data frame of the
#'   requested fractions, the share each holds, and how many units that
#'   was.
#' @details
#' Gini is the mean absolute difference between pairs of units over twice
#' the mean, which is also twice the area between the Lorenz curve and
#' the diagonal. Zero is a perfectly even spread; the maximum for `n`
#' units is `1 - 1/n`, not 1, so a Gini near 1 requires many units as
#' well as an uneven spread.
#' @references
#' Hedderich, J. and Sachs, L. (2020). *Applied Statistics: Methods
#' Using R*. Springer-Verlag, Berlin Heidelberg. Section 3.14, p. 117,
#' gives the construction used here: the units are placed at equal
#' intervals on the horizontal axis and the cumulated, ascendingly
#' ordered shares of the total on the vertical one, so that the curve is
#' the diagonal exactly when p percent of the units account for p
#' percent of the total, and sags further the greater the
#' concentration.
#' @seealso [hill_tail_index()], [band_sensitivity()]
#' @examples
#' # Ten units holding one each: no concentration.
#' gini(rep(1, 10))
#'
#' # One unit holding everything: the maximum for ten units.
#' gini(c(rep(0, 9), 1))
#' 1 - 1 / 10
#'
#' placements <- c(rep(1, 1200), rep(3, 430), rep(8, 110), rep(20, 38))
#' gini(placements)
#'
#' # What the most frequent few account for.
#' top_share(placements, c(0.01, 0.05, 0.1))
#'
#' head(lorenz(placements))
#' @name concentration
#' @export
gini <- function(x, na.rm = TRUE) {
  x <- .rmbl_conc_input(x)
  .Call(C_rmbl_gini, x)
}

#' @rdname concentration
#' @export
lorenz <- function(x, na.rm = TRUE) {
  x <- .rmbl_conc_input(x)
  r <- .Call(C_rmbl_lorenz, x)
  data.frame(population = r$population, value = r$value)
}

#' @param fractions Fractions of the units, largest first, to report the
#'   share of.
#' @rdname concentration
#' @export
top_share <- function(x, fractions = c(0.01, 0.05, 0.1, 0.25),
                      na.rm = TRUE) {
  x <- .rmbl_conc_input(x)
  f <- as.numeric(fractions)
  r <- .Call(C_rmbl_top_share, x, f)
  data.frame(fraction = f, units = r$units, share = r$share)
}

.rmbl_conc_input <- function(x) {
  if (!is.numeric(x)) {
    stop("`x` must be numeric", call. = FALSE)
  }
  x <- as.numeric(x)
  # a negative value has no place in a share of a total, and treating it
  # as zero would understate the concentration
  if (any(x < 0, na.rm = TRUE)) {
    stop("concentration measures need non-negative values", call. = FALSE)
  }
  x
}

#' Tail index of a heavy-tailed count
#'
#' The Clauset-Shalizi-Newman maximum-likelihood estimator for a discrete
#' power law above a threshold. An exponent near 2 or below means the
#' mean is barely defined and the observed maximum is not informative
#' about the next one, which is the substantive point when a few units
#' dominate a total.
#'
#' @param x Positive values, one per unit.
#' @param x_min Threshold above which the power law is fitted. A power
#'   law is a statement about the tail, so a threshold is required; the
#'   default takes the value that leaves at least 50 observations, or the
#'   minimum if the data are smaller than that.
#' @param discrete Whether the quantity is integer-valued. A count is,
#'   and then the likelihood maximised is the zeta distribution's, whose
#'   normalising constant is a Hurwitz zeta.
#' @param approx For discrete data, whether to use the closed-form
#'   continuity-corrected estimator instead of maximising the exact
#'   likelihood. It is much faster and much worse: the correction is an
#'   asymptotic approximation in `x_min`, and at `x_min = 1` -- where
#'   administrative counts start -- it returns about 2.0 from data
#'   generated with an exponent of 2.5. Off by default for that reason.
#' @param min_tail Fewest tail observations for which an estimate is
#'   reported at all. Below it there is nothing to estimate from and
#'   `alpha` is `NA`.
#' @return A list with `alpha`, its standard error, `x_min`, `n_tail`,
#'   `ks` and `reliable`. `ks` is the Kolmogorov-Smirnov distance
#'   between the fitted tail and the data: a large value means the tail
#'   is not a power law, whatever `alpha` came out as. `reliable` is
#'   `FALSE` when fewer than 50 observations lie in the tail, which is
#'   the sample size Clauset, Shalizi and Newman give as the point below
#'   which the estimate should not be leaned on -- it is reported rather
#'   than enforced, because the right response to a short tail is a
#'   wider interval, not a refusal.
#' @references
#' Clauset, A., Shalizi, C. R. and Newman, M. E. J. (2009). Power-law
#' distributions in empirical data. *SIAM Review* 51(4), 661-703. The
#' estimator and its threshold guidance are theirs; the continuity
#' correction they give in closed form is an asymptotic approximation in
#' `x_min`, which is why the exact likelihood is maximised here instead.
#' (Not in the local corpus; cited from the published paper.)
#' @examples
#' # A continuous Pareto tail with exponent 2.5.
#' set.seed(1)
#' x <- (1 - stats::runif(5000))^(-1 / 1.5)
#' round(hill_tail_index(x, x_min = 1, discrete = FALSE)$alpha, 2)
#'
#' # A discrete power law, where the exact likelihood is needed: the
#' # closed-form correction is badly biased at a threshold of one.
#' k <- 1:10000
#' p <- k^(-2.5) / sum(k^(-2.5))
#' set.seed(2)
#' z <- sample(k, 5000, replace = TRUE, prob = p)
#' c(exact = round(hill_tail_index(z, x_min = 1)$alpha, 2),
#'   approx = round(hill_tail_index(z, x_min = 1, approx = TRUE)$alpha, 2))
#'
#' # A short tail still returns an estimate, marked as not to be leaned
#' # on, and with a standard error that says the same thing.
#' short <- hill_tail_index(c(3, 4, 5, 9), x_min = 3)
#' c(alpha = round(short$alpha, 2), n = short$n_tail,
#'   reliable = short$reliable)
#'
#' # Below `min_tail` there is nothing to estimate from.
#' hill_tail_index(c(3, 4), x_min = 3)$alpha
#' @export
hill_tail_index <- function(x, x_min = NULL, discrete = TRUE,
                            approx = FALSE, min_tail = 3L) {
  x <- as.numeric(x)
  x <- x[is.finite(x) & x > 0]
  if (is.null(x_min)) {
    # enough of a tail to estimate from, or everything if there is not
    s <- sort(x, decreasing = TRUE)
    x_min <- if (length(s) >= 50L) s[50L] else if (length(s)) min(s) else NA_real_
  }
  x_min <- as.numeric(x_min)[1L]
  if (is.na(x_min) || x_min <= 0) {
    stop("`x_min` must be positive", call. = FALSE)
  }
  tail <- x[x >= x_min]
  n <- length(tail)
  min_tail <- max(2L, as.integer(min_tail)[1L])
  if (n < min_tail) {
    return(list(alpha = NA_real_, se = NA_real_, x_min = x_min,
                n_tail = n, ks = NA_real_, reliable = FALSE,
                method = "too few tail observations"))
  }
  logsum <- sum(log(tail))
  if (!is.finite(logsum)) {
    return(list(alpha = NA_real_, se = NA_real_, x_min = x_min,
                n_tail = n, ks = NA_real_, reliable = FALSE,
                method = "not estimable"))
  }
  if (isTRUE(discrete) && !isTRUE(approx)) {
    # The zeta distribution truncated below at x_min:
    #   p(k) = k^-alpha / zeta(alpha, x_min),  k = x_min, x_min + 1, ...
    # so the log-likelihood is
    #   -n log zeta(alpha, x_min) - alpha * sum log k
    # which has no closed-form maximiser and is concave in alpha, so one
    # univariate maximisation settles it.
    nll <- function(a) {
      z <- .rmbl_hurwitz(a, x_min)
      if (!is.finite(z) || z <= 0) return(Inf)
      n * log(z) + a * logsum
    }
    opt <- stats::optimize(nll, interval = c(1.0001, 25), tol = 1e-9)
    alpha <- opt$minimum
    # the observed information, by a central difference on the score:
    # the second derivative of the log-likelihood has no simple form
    # because it needs the zeta's derivatives in the exponent
    h <- 1e-4
    d2 <- (nll(alpha + h) - 2 * nll(alpha) + nll(alpha - h)) / h^2
    se <- if (is.finite(d2) && d2 > 0) sqrt(1 / d2) else NA_real_
    method <- "exact discrete (zeta) maximum likelihood"
    denom <- x_min
    # zeta(alpha, q) / zeta(alpha, x_min) is P(X >= q), so the
    # distribution function at an integer k is 1 - P(X >= k + 1).
    # Using P(X >= k) instead omits the whole point mass at k, which at
    # a threshold of one is about three quarters of the distribution --
    # the fit would be reported as terrible however good it was.
    denom_z <- .rmbl_hurwitz(alpha, x_min)
    cdf <- function(q) {
      1 - vapply(q + 1, function(v) {
        .rmbl_hurwitz(alpha, v) / denom_z
      }, 0)
    }
    ks <- .rmbl_ks_discrete(tail, cdf)
    return(list(alpha = alpha, se = se, x_min = x_min, n_tail = n,
                ks = ks, reliable = n >= 50L, method = method))
  }
  # the continuous Hill estimator, and its continuity-corrected discrete
  # cousin: closed form, exact for a continuous Pareto tail, and only
  # asymptotically right in x_min for a discrete one
  denom <- if (isTRUE(discrete) && x_min > 0.5) x_min - 0.5 else x_min
  ssum <- sum(log(tail / denom))
  if (!is.finite(ssum) || ssum <= 0) {
    return(list(alpha = NA_real_, se = NA_real_, x_min = x_min,
                n_tail = n, ks = NA_real_, reliable = FALSE,
                method = "not estimable"))
  }
  alpha <- 1 + n / ssum
  # the asymptotic standard error of the Hill estimator
  se <- (alpha - 1) / sqrt(n)
  # goodness of fit: the fitted tail's own distribution function against
  # the empirical one. alpha without this is a number fitted to whatever
  # shape the data had.
  ks <- .rmbl_ks_discrete(tail, function(q) 1 - (q / denom)^(1 - alpha),
                          continuous = !isTRUE(discrete))
  list(alpha = alpha, se = se, x_min = x_min, n_tail = n, ks = ks,
       reliable = n >= 50L,
       method = if (isTRUE(discrete)) {
         "continuity-corrected closed form (approximate)"
       } else {
         "continuous Hill maximum likelihood"
       })
}

#' Hurwitz zeta function
#'
#' `zeta(s, q) = sum over k >= 0 of (q + k)^-s`, by Euler-Maclaurin. It
#' is the normalising constant of the discrete power law truncated below
#' at `q`, which is why it is here; `zeta(s, 1)` is the Riemann zeta.
#'
#' @param s Exponent, which must exceed 1 for the series to converge.
#' @param q Lower limit, which must be positive.
#' @return A numeric vector the length of `s`.
#' @examples
#' # The Riemann zeta at even integers has a closed form.
#' c(hurwitz_zeta(2), pi^2 / 6)
#' c(hurwitz_zeta(4), pi^4 / 90)
#'
#' # Apery's constant.
#' hurwitz_zeta(3)
#'
#' # Shifting the lower limit removes exactly the leading term.
#' hurwitz_zeta(2.5, 3) - hurwitz_zeta(2.5, 4)
#' 3^-2.5
#'
#' # Outside the domain of convergence there is no value to return.
#' hurwitz_zeta(1)
#' @export
hurwitz_zeta <- function(s, q = 1) {
  .rmbl_hurwitz(as.numeric(s), as.numeric(q)[1L])
}

.rmbl_hurwitz <- function(s, q) {
  .Call(C_rmbl_hurwitz_zeta, as.numeric(s), as.numeric(q))
}

# Kolmogorov-Smirnov distance between a sample and a fitted
# distribution function, evaluated once per DISTINCT value.
#
# seq_along(sort(x)) / n is not the empirical distribution function when
# there are ties: it steps through a tied block instead of jumping once
# at its end, so at the first member of the block it reads near zero.
# Counts are almost all ties -- at an exponent of 2.5 three quarters of
# the draws are the value one -- so this reported every good fit as a
# terrible one.
.rmbl_ks_discrete <- function(x, cdf, continuous = FALSE) {
  n <- length(x)
  if (!n) return(NA_real_)
  u <- sort(unique(x))
  cnt <- tabulate(match(x, u), nbins = length(u))
  hi <- cumsum(cnt) / n
  theo <- cdf(u)
  ok <- is.finite(theo)
  if (!any(ok)) return(NA_real_)
  d <- abs(hi[ok] - theo[ok])
  if (isTRUE(continuous)) {
    # For a CONTINUOUS fit the supremum can also be attained just below
    # a jump of the empirical function, where it still holds its
    # previous value while the fitted one has moved on.
    lo <- c(0, hi[-length(hi)])
    d <- c(d, abs(lo[ok] - theo[ok]))
  }
  # For a STEP fit both functions jump at the same support points, so
  # just below a jump both hold their previous values and that point is
  # already covered by the previous one. Including the left limit
  # against the right value there compares F_n(u-) with F(u), which
  # differs by the whole point mass at u -- at an exponent of 2.5 that
  # is three quarters of the distribution, and every good fit was
  # reported as a terrible one.
  max(d)
}

#' Association in a contingency table
#'
#' Cramer's V, with the bias correction of Bergsma (2013) available, and
#' the small-expected-count condition reported rather than assumed away.
#'
#' @param tbl A table or matrix of counts.
#' @param bias_correct Whether to apply Bergsma's correction, which
#'   removes most of V's upward bias in a sparse table. Worth having:
#'   uncorrected V on a sparse table reports association that is an
#'   artefact of the table's size.
#' @param min_expected Expected count below which the chi-square
#'   approximation is unreliable. Reported, not enforced.
#' @return A list with `v`, `chisq`, `df`, `p_value`, `n`,
#'   `min_expected`, and `cells_below`, the number of cells whose
#'   expected count falls under the threshold. When any does, `p_value`
#'   comes from a Monte Carlo permutation instead of the chi-square
#'   approximation, and `method` says which was used.
#' @references
#' Bergsma, W. (2013). A bias-correction for Cramer's V and
#' Tschuprow's T. *Journal of the Korean Statistical Society* 42(3),
#' 323-328. (Not in the local corpus; cited from the published paper.)
#' @examples
#' tbl <- rbind(c(120, 80), c(40, 160))
#' cramers_v(tbl)
#'
#' # No association gives a V near zero.
#' cramers_v(rbind(c(100, 100), c(100, 100)))$v
#'
#' # A sparse table's uncorrected V overstates the association.
#' sparse <- rbind(c(3, 1), c(1, 3))
#' c(raw = cramers_v(sparse, bias_correct = FALSE)$v,
#'   corrected = cramers_v(sparse)$v)
#' @export
cramers_v <- function(tbl, bias_correct = TRUE, min_expected = 5) {
  m <- as.matrix(tbl)
  if (any(dim(m) < 2L)) {
    return(list(v = NA_real_, chisq = NA_real_, df = NA_integer_,
                p_value = NA_real_, n = sum(m), min_expected = NA_real_,
                cells_below = NA_integer_, method = "table too small"))
  }
  if (any(m < 0, na.rm = TRUE)) {
    stop("a contingency table cannot hold negative counts", call. = FALSE)
  }
  n <- sum(m)
  if (n == 0) {
    return(list(v = NA_real_, chisq = NA_real_, df = NA_integer_,
                p_value = NA_real_, n = 0, min_expected = NA_real_,
                cells_below = NA_integer_, method = "empty table"))
  }
  ct <- suppressWarnings(stats::chisq.test(m, correct = FALSE))
  chi <- as.numeric(ct$statistic)
  r <- nrow(m)
  k <- ncol(m)
  below <- sum(ct$expected < min_expected)
  # the chi-square approximation rests on the expected counts; when it
  # does not hold, permute instead of reporting a p-value the table
  # cannot support
  method <- "chi-square approximation"
  p <- as.numeric(ct$p.value)
  if (below > 0L) {
    sim <- suppressWarnings(stats::chisq.test(m, simulate.p.value = TRUE,
                                              B = 10000L))
    p <- as.numeric(sim$p.value)
    method <- "Monte Carlo permutation (small expected counts)"
  }
  phi2 <- chi / n
  v <- if (isTRUE(bias_correct)) {
    # Bergsma (2013): correct phi-squared and the dimensions for the bias
    # that makes V rise with the table's size rather than its association
    phi2c <- max(0, phi2 - (r - 1) * (k - 1) / (n - 1))
    rc <- r - (r - 1)^2 / (n - 1)
    kc <- k - (k - 1)^2 / (n - 1)
    den <- min(rc - 1, kc - 1)
    if (den <= 0) NA_real_ else sqrt(phi2c / den)
  } else {
    sqrt(phi2 / min(r - 1, k - 1))
  }
  list(v = v, chisq = chi, df = as.integer(ct$parameter), p_value = p,
       n = n, min_expected = min(ct$expected), cells_below = below,
       method = method)
}
