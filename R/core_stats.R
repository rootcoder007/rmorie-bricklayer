# SPDX-License-Identifier: AGPL-3.0-or-later
#
# R bindings for the statistical kernels in the compiled core. Two
# groups live here:
#
#   * kernels vendored from morie (morie_core.h) that were already
#     compiled into this package but had no binding, so nothing could
#     reach them: the standard deviation, Euclidean distance, the normal
#     log-density, trimmed IPW weights, bootstrap replicate means, the
#     regularized incomplete gamma function, and the Hawkes likelihood;
#   * bricklayer's own robust and distributional summaries
#     (rmbl_stats.cpp), which morie does not carry.
#
# Every one is also published through `LinkingTo: rmoriebricklayer`, so
# rmorie and rmoriedata call the same compiled copy rather than their
# own.

#' Standard deviation and Euclidean distance (C backend)
#'
#' `core_sd()` is the square root of the variance computed by the shared
#' core; `core_dist()` is the Euclidean distance between two equal-length
#' vectors.
#'
#' NA/NaN propagate -- there is no `na.rm`. Call [stats::na.omit()] first
#' if you need NA handling.
#'
#' @param x,a,b Numeric vectors (coerced with [as.numeric()]).
#' @param ddof Denominator degrees of freedom. The default `1` gives the
#'   sample standard deviation, matching [stats::sd()]; `0` gives the
#'   population figure.
#' @return A length-1 numeric.
#' @seealso [core_moments()] for the mean, variance, skewness and
#'   kurtosis in a single pass.
#' @examples
#' # Sample standard deviation, matching stats::sd().
#' core_sd(c(2, 4, 4, 4, 5, 5, 7, 9))
#' all.equal(core_sd(1:10), stats::sd(1:10))
#'
#' # ddof = 0 divides by n instead of n - 1.
#' core_sd(1:10, ddof = 0)
#' all.equal(core_sd(1:10, ddof = 0), sqrt(mean((1:10 - mean(1:10))^2)))
#'
#' # Euclidean distance between two points.
#' core_dist(c(0, 0), c(3, 4))     # 5
#' core_dist(1:5, 1:5)             # 0 -- a point is zero from itself
#' @name rmbl_core_spread
#' @export
core_sd <- function(x, ddof = 1L) {
  .Call(C_rmbl_sd, as.numeric(x), as.integer(ddof))
}

#' @rdname rmbl_core_spread
#' @export
core_dist <- function(a, b) {
  a <- as.numeric(a)
  b <- as.numeric(b)
  if (length(a) != length(b)) {
    stop("`a` and `b` must have the same length", call. = FALSE)
  }
  .Call(C_rmbl_euclid, a, b)
}

#' Normal log-density (C backend)
#'
#' The logarithm of the normal density, computed directly rather than as
#' `log(dnorm(x))`, so it stays finite far into the tails where the
#' density itself underflows to zero.
#'
#' @param x Numeric vector of quantiles.
#' @param mean Distribution mean (length-1, default 0).
#' @param sd Distribution standard deviation (length-1, default 1, > 0).
#' @return A numeric vector the length of `x`. Equivalent to
#'   `stats::dnorm(x, mean, sd, log = TRUE)`.
#' @examples
#' core_normal_logpdf(c(-1, 0, 1))
#'
#' # Identical to stats::dnorm(log = TRUE).
#' all.equal(core_normal_logpdf(-2:2, 0.3, 1.7),
#'           stats::dnorm(-2:2, 0.3, 1.7, log = TRUE))
#'
#' # Still finite where the density itself underflows to zero.
#' stats::dnorm(50)                  # 0
#' core_normal_logpdf(50)            # about -1251
#' @export
core_normal_logpdf <- function(x, mean = 0, sd = 1) {
  .Call(C_rmbl_normal_logpdf, as.numeric(x), as.numeric(mean), as.numeric(sd))
}

#' Mean, variance, skewness and kurtosis in one pass (C backend)
#'
#' A single streaming pass (Welford's recurrence, extended to the third
#' and fourth central moments) over `x`. One pass matters for capsule
#' members large enough that reading the column twice is the expensive
#' part.
#'
#' The variance uses the `n - 1` denominator, matching [stats::var()].
#' The shape statistics use the *sample moment* definitions
#' \eqn{m_3 / m_2^{3/2}} and \eqn{m_4 / m_2^2 - 3}, with \eqn{m_k} the
#' k-th central moment divided by `n` -- so kurtosis is reported as
#' EXCESS kurtosis and a normal sample sits near zero, not near three.
#'
#' @param x Numeric vector (coerced with [as.numeric()]).
#' @return A named length-4 numeric: `mean`, `variance`, `skewness`,
#'   `kurtosis`. `skewness` needs at least 3 observations and `kurtosis`
#'   at least 4; both are `NaN` below that, as is everything if `x`
#'   contains NA/NaN.
#' @references Welford BP (1962). Note on a method for calculating
#'   corrected sums of squares and products. *Technometrics* 4(3),
#'   419--420. \doi{10.1080/00401706.1962.10490022}
#' @examples
#' core_moments(c(2, 4, 4, 4, 5, 5, 7, 9))
#'
#' # The first two entries agree with base R.
#' m <- core_moments(1:10)
#' all.equal(m[["mean"]], mean(1:10))
#' all.equal(m[["variance"]], stats::var(1:10))
#'
#' # A symmetric sample has no skew; excess kurtosis is near 0 for normal
#' # data and positive for a heavy-tailed sample.
#' core_moments(c(-2, -1, 0, 1, 2))[["skewness"]]
#' core_moments(c(rep(0, 20), -8, 8))[["kurtosis"]] > 0
#'
#' # Too short to define a shape statistic: NaN rather than a guess.
#' core_moments(c(1, 2))
#' @export
core_moments <- function(x) .Call(C_rmbl_moments, as.numeric(x))

#' Quantiles, median and robust spread (C backend)
#'
#' `core_quantile()` is the type-7 quantile, which is R's default, so it
#' agrees with `stats::quantile(x, probs, type = 7)`. `core_median()` is
#' the 50% point. `core_mad()` is the median absolute deviation, scaled
#' by `constant` so that it estimates the standard deviation of a normal
#' sample. `core_iqr()` is the interquartile range and
#' `core_tukey_fences()` the outlier fences drawn at `k` IQRs beyond the
#' quartiles.
#'
#' These are the robust counterparts of [core_moments()]: a single
#' corrupted row can move a mean or a variance arbitrarily far, but moves
#' a median or a MAD hardly at all -- which is what you want when
#' deciding whether a freshly fetched column is still the column a
#' capsule was pinned against.
#'
#' @param x Numeric vector (coerced with [as.numeric()]).
#' @param probs Numeric vector of probabilities in \[0, 1\].
#' @param constant Scale factor for `core_mad()`. The default `1.4826`
#'   makes the MAD consistent for the standard deviation under
#'   normality, and is the same rounded value [stats::mad()] uses, so the
#'   two agree exactly. The unrounded consistency constant is
#'   `1 / qnorm(3/4)` = 1.4826022185...; pass it explicitly if you want
#'   the extra digits, or `1` for the unscaled median deviation.
#' @param k Fence width in IQRs (default 1.5, Tukey's convention; 3 is
#'   the usual "far out" cutoff).
#' @return `core_quantile()` returns a numeric vector the length of
#'   `probs`; `core_median()`, `core_mad()` and `core_iqr()` a length-1
#'   numeric; `core_tukey_fences()` a named length-2 numeric (`lower`,
#'   `upper`).
#' @examples
#' x <- c(2, 4, 4, 4, 5, 5, 7, 9)
#' core_quantile(x, c(0.25, 0.5, 0.75))
#' all.equal(core_quantile(x, c(0.1, 0.9)),
#'           as.numeric(stats::quantile(x, c(0.1, 0.9))))
#'
#' core_median(x)
#' core_mad(x)
#' all.equal(core_mad(x), stats::mad(x))
#' core_mad(x, constant = 1)                  # unscaled median deviation
#' core_mad(x, constant = 1 / stats::qnorm(3/4))  # unrounded constant
#'
#' core_iqr(x)
#' core_tukey_fences(x)
#'
#' # Robustness: one wild value barely moves the median, but moves the
#' # mean a long way.
#' wild <- c(x, 1000)
#' c(mean = mean(wild), median = core_median(wild))
#'
#' # Values outside the fences are the candidates to inspect.
#' f <- core_tukey_fences(wild)
#' wild[wild < f[["lower"]] | wild > f[["upper"]]]
#' @name rmbl_core_robust
#' @export
core_quantile <- function(x, probs = c(0, 0.25, 0.5, 0.75, 1)) {
  probs <- as.numeric(probs)
  if (length(probs) == 0L) stop("`probs` is empty", call. = FALSE)
  if (anyNA(probs) || any(probs < 0 | probs > 1)) {
    stop("`probs` must lie in [0, 1]", call. = FALSE)
  }
  out <- .Call(C_rmbl_quantile, as.numeric(x), probs)
  names(out) <- paste0(format(100 * probs, trim = TRUE), "%")
  out
}

#' @rdname rmbl_core_robust
#' @export
core_median <- function(x) .Call(C_rmbl_median, as.numeric(x))

#' @rdname rmbl_core_robust
#' @export
core_mad <- function(x, constant = 1.4826) {
  .Call(C_rmbl_mad, as.numeric(x), as.numeric(constant))
}

#' @rdname rmbl_core_robust
#' @export
core_iqr <- function(x) {
  q <- .Call(C_rmbl_quantile, as.numeric(x), c(0.25, 0.75))
  q[2L] - q[1L]
}

#' @rdname rmbl_core_robust
#' @export
core_tukey_fences <- function(x, k = 1.5) {
  q <- .Call(C_rmbl_quantile, as.numeric(x), c(0.25, 0.75))
  iqr <- q[2L] - q[1L]
  c(lower = q[1L] - k * iqr, upper = q[2L] + k * iqr)
}

#' Trimmed and winsorized means (C backend)
#'
#' Two ways to stop a handful of extreme rows dominating a column's
#' centre. `core_trimmed_mean()` DISCARDS the `floor(n * trim)` largest
#' and smallest values, matching `mean(x, trim = )`.
#' `core_winsorized_mean()` instead PULLS THEM IN to the most extreme
#' surviving values, so every observation still contributes weight --
#' usually the better choice when the extremes are real measurements
#' rather than errors.
#'
#' @param x Numeric vector (coerced with [as.numeric()]).
#' @param trim Proportion trimmed from *each* end, in \[0, 0.5\]. At
#'   `0.5` both reduce to the median.
#' @return A length-1 numeric.
#' @examples
#' x <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 100)
#'
#' mean(x)                               # dragged up by the 100
#' core_trimmed_mean(x, 0.1)             # the 100 and the 1 dropped
#' core_winsorized_mean(x, 0.1)          # the 100 pulled back to 9
#'
#' # Agrees with base R's own trimming.
#' all.equal(core_trimmed_mean(x, 0.2), mean(x, trim = 0.2))
#'
#' # trim = 0 is the plain mean; trim = 0.5 is the median.
#' all.equal(core_trimmed_mean(x, 0), mean(x))
#' all.equal(core_trimmed_mean(x, 0.5), core_median(x))
#' @name rmbl_core_trimmed
#' @export
core_trimmed_mean <- function(x, trim = 0.1) {
  .Call(C_rmbl_trimmed_mean, as.numeric(x), as.numeric(trim))
}

#' @rdname rmbl_core_trimmed
#' @export
core_winsorized_mean <- function(x, trim = 0.1) {
  .Call(C_rmbl_winsorized_mean, as.numeric(x), as.numeric(trim))
}

#' Weighted mean and variance (C backend)
#'
#' The weights are treated as RELIABILITY weights (how precisely each
#' observation is known), so the variance carries the bias correction
#' \eqn{\sum w - \sum w^2 / \sum w} in the denominator rather than
#' `n - 1`. With every weight equal to 1 it reduces exactly to
#' [stats::var()].
#'
#' @param x Numeric vector of observations.
#' @param w Numeric vector of non-negative weights, the same length as
#'   `x`.
#' @return A named length-2 numeric: `mean` and `variance`.
#' @examples
#' x <- c(10, 20, 30, 40)
#' w <- c(1, 1, 2, 4)
#' core_weighted(x, w)
#'
#' # The mean agrees with base R.
#' all.equal(core_weighted(x, w)[["mean"]], stats::weighted.mean(x, w))
#'
#' # Equal weights recover the unweighted variance.
#' all.equal(core_weighted(x, rep(1, 4))[["variance"]], stats::var(x))
#'
#' # A single dominant weight pulls the mean onto that observation.
#' core_weighted(x, c(1, 1, 1, 1000))[["mean"]]
#' @export
core_weighted <- function(x, w) {
  x <- as.numeric(x)
  w <- as.numeric(w)
  if (length(x) != length(w)) {
    stop("`x` and `w` must have the same length", call. = FALSE)
  }
  if (any(w < 0, na.rm = TRUE)) {
    stop("`w` must be non-negative", call. = FALSE)
  }
  out <- .Call(C_rmbl_weighted, x, w)
  names(out) <- c("mean", "variance")
  out
}

#' Rank correlation and midranks (C backend)
#'
#' `core_cor_spearman()` is Spearman's rho: the Pearson correlation of
#' the ranks, so it measures monotone association rather than linear
#' association and is unaffected by any order-preserving transformation
#' of either variable. `core_midranks()` exposes the ranks themselves;
#' tied values share the average of the ranks they span, which is what
#' makes the result agree with [stats::cor()] on tied data.
#'
#' @param x,y Numeric vectors of the same length.
#' @return `core_cor_spearman()` a length-1 numeric in \[-1, 1\];
#'   `core_midranks()` a numeric vector the length of `x`.
#' @examples
#' x <- c(1, 2, 3, 4, 5)
#' y <- c(2, 4, 9, 16, 25)
#'
#' # Perfectly monotone but not linear: rho is 1 where Pearson is not.
#' core_cor_spearman(x, y)
#' core_cor(x, y)
#'
#' # Agrees with stats::cor(), ties included.
#' xt <- c(1, 2, 2, 2, 5, 5, 7)
#' yt <- c(3, 1, 1, 4, 4, 9, 2)
#' all.equal(core_cor_spearman(xt, yt), stats::cor(xt, yt, method = "spearman"))
#'
#' # Tied values share the average of the ranks they cover.
#' core_midranks(xt)
#' all.equal(core_midranks(xt), rank(xt))
#'
#' # Invariant to any monotone rescaling.
#' all.equal(core_cor_spearman(x, y), core_cor_spearman(exp(x), log(y)))
#' @name rmbl_core_rank
#' @export
core_cor_spearman <- function(x, y) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  if (length(x) != length(y)) {
    stop("`x` and `y` must have the same length", call. = FALSE)
  }
  .Call(C_rmbl_cor_spearman, x, y)
}

#' @rdname rmbl_core_rank
#' @export
core_midranks <- function(x) .Call(C_rmbl_midranks, as.numeric(x))

#' Covariance matrix of a numeric matrix (C backend)
#'
#' Column covariances with the `n - 1` denominator, matching
#' [stats::cov()]. Column names are carried through to both dimensions of
#' the result.
#'
#' @param x A numeric matrix or data frame of numeric columns (rows =
#'   observations, columns = variables).
#' @return A symmetric `ncol(x)` by `ncol(x)` numeric matrix.
#' @examples
#' X <- cbind(a = c(1, 2, 3, 4), b = c(2, 4, 7, 8), c = c(5, 3, 2, 1))
#' core_cov(X)
#'
#' # Agrees with stats::cov().
#' all.equal(core_cov(X), stats::cov(X))
#'
#' # The diagonal is the column variances.
#' all.equal(diag(core_cov(X)), apply(X, 2, stats::var))
#'
#' # Data frames are accepted.
#' core_cov(data.frame(u = 1:5, v = c(2, 1, 4, 3, 6)))
#' @export
core_cov <- function(x) {
  if (is.data.frame(x)) {
    if (!all(vapply(x, is.numeric, logical(1)))) {
      stop("every column of `x` must be numeric", call. = FALSE)
    }
    x <- as.matrix(x)
  }
  if (!is.matrix(x)) stop("`x` must be a matrix or data frame", call. = FALSE)
  storage.mode(x) <- "double"
  out <- .Call(C_rmbl_cov_matrix, x)
  cn <- colnames(x)
  if (!is.null(cn)) dimnames(out) <- list(cn, cn)
  out
}

#' Bootstrap replicate means (C backend)
#'
#' `B` resamples of `x`, drawn with replacement and each the same length
#' as `x`, with the mean of every resample returned. The resampling uses
#' the core's own 64-bit Mersenne Twister seeded by `seed`, NOT R's RNG,
#' so a given `seed` reproduces the same replicates in every binding of
#' the core and R's own random stream is left untouched.
#'
#' @param x Numeric vector to resample.
#' @param B Number of bootstrap replicates (default 1000).
#' @param seed Seed for the core's generator (default 42).
#' @return A numeric vector of length `B`: the replicate means.
#' @examples
#' set.seed(1)
#' x <- stats::rnorm(50, mean = 5)
#'
#' reps <- core_bootstrap_mean(x, B = 500, seed = 7)
#' length(reps)
#'
#' # The replicates centre on the sample mean, and their spread estimates
#' # the standard error.
#' c(sample = mean(x), bootstrap = mean(reps))
#' c(bootstrap_se = stats::sd(reps), formula_se = stats::sd(x) / sqrt(length(x)))
#'
#' # A percentile confidence interval for the mean.
#' stats::quantile(reps, c(0.025, 0.975))
#'
#' # Reproducible: the same seed gives the same replicates, and R's own
#' # random stream is not consumed.
#' identical(core_bootstrap_mean(x, 100, seed = 1),
#'           core_bootstrap_mean(x, 100, seed = 1))
#' @export
core_bootstrap_mean <- function(x, B = 1000L, seed = 42L) {
  B <- as.numeric(B)
  if (length(B) != 1L || is.na(B) || B < 1) {
    stop("`B` must be a single number >= 1", call. = FALSE)
  }
  .Call(C_rmbl_bootstrap_mean, as.numeric(x), B, as.numeric(seed))
}

#' Trimmed inverse-probability weights (C backend)
#'
#' The inverse-probability-of-treatment weights \eqn{1/e} for the
#' treated and \eqn{1/(1-e)} for the untreated, with the propensity score
#' clamped into `[trim_lo, trim_hi]` FIRST. Clamping matters: an
#' untrimmed score near 0 or 1 produces a weight large enough for one
#' observation to dominate the entire estimate.
#'
#' @param treat Numeric or logical treatment indicator; `1`/`TRUE` is
#'   treated.
#' @param propensity Numeric vector of propensity scores, the same length
#'   as `treat`.
#' @param trim_lo,trim_hi Clamp bounds for the score (defaults 0.01 and
#'   0.99).
#' @return A numeric vector of weights the length of `treat`.
#' @examples
#' treat <- c(1, 0, 1, 0)
#' e <- c(0.5, 0.25, 0.02, 0.9)
#'
#' core_ipw_weights(treat, e)
#'
#' # A balanced score gives weight 2 to either arm.
#' core_ipw_weights(c(1, 0), c(0.5, 0.5))
#'
#' # Without trimming the third observation would carry weight 50; the
#' # default clamp holds it to 100 at the 0.01 floor, and a looser floor
#' # tames it further.
#' core_ipw_weights(treat, e, trim_lo = 0.10)
#'
#' # Logical treatment indicators work too.
#' core_ipw_weights(c(TRUE, FALSE), c(0.4, 0.4))
#' @export
core_ipw_weights <- function(treat, propensity, trim_lo = 0.01,
                             trim_hi = 0.99) {
  treat <- as.numeric(treat)
  propensity <- as.numeric(propensity)
  if (length(treat) != length(propensity)) {
    stop("`treat` and `propensity` must have the same length", call. = FALSE)
  }
  trim_lo <- as.numeric(trim_lo)
  trim_hi <- as.numeric(trim_hi)
  if (!(trim_lo > 0 && trim_hi < 1 && trim_lo < trim_hi)) {
    stop("need 0 < `trim_lo` < `trim_hi` < 1", call. = FALSE)
  }
  .Call(C_rmbl_ipw, treat, propensity, trim_lo, trim_hi)
}

#' Regularized incomplete gamma function (C backend)
#'
#' The lower regularized incomplete gamma function \eqn{P(a, x)}, which
#' is the CDF of a Gamma distribution with shape `a` and unit rate.
#' Exposed because it is the building block of the chi-square tail used
#' by [drift_chisq()] and [benford_test()].
#'
#' @param shape Shape parameter \eqn{a} (length-1, > 0).
#' @param x Numeric vector of quantiles (>= 0).
#' @return A numeric vector the length of `x`, each entry in \[0, 1\].
#' @examples
#' core_gamma_cdf(3.5, c(0.5, 1, 4, 12))
#'
#' # Identical to the unit-rate gamma CDF.
#' all.equal(core_gamma_cdf(3.5, c(0.5, 1, 4, 12)),
#'           stats::pgamma(c(0.5, 1, 4, 12), shape = 3.5))
#'
#' # Shape 1 is the exponential distribution.
#' all.equal(core_gamma_cdf(1, c(0.5, 2)), stats::pexp(c(0.5, 2)))
#'
#' # A chi-square tail on k degrees of freedom is 1 - P(k/2, q/2).
#' 1 - core_gamma_cdf(2 / 2, 5.99 / 2)      # about 0.05 on 2 df
#' @export
core_gamma_cdf <- function(shape, x) {
  shape <- as.numeric(shape)
  if (length(shape) != 1L || is.na(shape) || shape <= 0) {
    stop("`shape` must be a single positive number", call. = FALSE)
  }
  .Call(C_rmbl_gamma_cdf, shape, as.numeric(x))
}

#' Hawkes-process negative log-likelihood (C backend)
#'
#' The negative log-likelihood of a univariate self-exciting Hawkes
#' process with constant baseline on `[0, horizon]`, for the event times
#' `times`. A Hawkes process is the natural model for arrivals that
#' trigger further arrivals -- repeat calls to a service, aftershocks,
#' retweet cascades, revisions to an open-data release.
#'
#' Four triggering kernels are available. `"exponential"` is memoryless
#' and evaluates by an O(n) recursion; the other three are not, so they
#' cost O(n^2).
#'
#' Parameters are passed on the scales the kernel is defined on:
#' `par = c(a0, eta, ...)` where `a0` is the LOG baseline intensity
#' (\eqn{\nu = e^{a0}}) and `eta` the branching ratio in (0, 1) -- the
#' expected number of children per event, so the process is stationary
#' only for `eta < 1`. The remaining entries are the kernel's own shape
#' parameters: `beta` (exponential), `alpha, lambda` (Weibull),
#' `alpha, c` (Lomax), `alpha, beta` (gamma).
#'
#' @param times Sorted numeric vector of event times in `[0, horizon]`.
#' @param horizon End of the observation window (length-1, > 0).
#' @param kernel One of `"exponential"`, `"weibull"`, `"lomax"`,
#'   `"gamma"`.
#' @param par Numeric parameter vector, as described above: length 3 for
#'   `"exponential"`, length 4 for the others.
#' @return A length-1 numeric: the negative log-likelihood, to be
#'   MINIMISED. A parameter set outside the core's feasible region
#'   returns the sentinel `1e12` rather than erroring, so the value can
#'   be handed straight to [stats::optim()] without the optimiser
#'   walking off the domain.
#' @references Hawkes AG (1971). Spectra of some self-exciting and
#'   mutually exciting point processes. *Biometrika* 58(1), 83--90.
#'   \doi{10.1093/biomet/58.1.83}
#' @examples
#' set.seed(4)
#' times <- sort(stats::runif(40, 0, 10))
#'
#' # Exponential kernel: log-baseline -0.5, branching 0.3, decay 1.2.
#' core_hawkes_nll(times, 10, "exponential", c(-0.5, 0.3, 1.2))
#'
#' # Lower is better, so this is what an optimiser minimises.
#' nll <- function(p) core_hawkes_nll(times, 10, "exponential", p)
#' fit <- stats::optim(c(-0.5, 0.3, 1.2), nll)
#' fit$par
#'
#' # A branching ratio at or above 1 is not a stationary process, and is
#' # reported as the infeasible sentinel rather than a number.
#' core_hawkes_nll(times, 10, "exponential", c(-0.5, 1.5, 1.2)) == 1e12
#'
#' # The heavier-tailed kernels take two shape parameters.
#' core_hawkes_nll(times, 10, "gamma", c(-0.5, 0.3, 2, 1.5))
#' @export
core_hawkes_nll <- function(times, horizon,
                            kernel = c("exponential", "weibull", "lomax",
                                       "gamma"),
                            par) {
  kernel <- match.arg(kernel)
  code <- switch(kernel, exponential = 0L, weibull = 1L, lomax = 2L,
                 gamma = 3L)
  times <- as.numeric(times)
  if (anyNA(times)) stop("`times` must not contain NA", call. = FALSE)
  if (length(times) > 1L && any(diff(times) < 0)) {
    stop("`times` must be sorted in increasing order", call. = FALSE)
  }
  horizon <- as.numeric(horizon)
  if (length(horizon) != 1L || is.na(horizon) || horizon <= 0) {
    stop("`horizon` must be a single positive number", call. = FALSE)
  }
  if (length(times) > 0L && (min(times) < 0 || max(times) > horizon)) {
    stop("`times` must lie within [0, horizon]", call. = FALSE)
  }
  par <- as.numeric(par)
  need <- if (code == 0L) 3L else 4L
  if (length(par) != need) {
    stop(sprintf("the %s kernel needs `par` of length %d", kernel, need),
         call. = FALSE)
  }
  .Call(C_rmbl_hawkes_nll, times, horizon, code, par)
}
