# Statistical kernels in the compiled core.
#
# Anchors outside the package: base R's own implementations
# (stats::sd, var, quantile type 7, median, mad, mean(trim=),
# weighted.mean, cor(method="spearman"), rank, cov, dnorm(log=),
# pgamma, pexp), closed-form moment definitions written out by hand, and
# for the Hawkes likelihood an independent recomputation of the same
# recursion in R.

test_that("core_sd and core_dist agree with base R", {
  set.seed(1)
  x <- stats::rnorm(80)
  y <- stats::rnorm(80)
  expect_equal(core_sd(x), stats::sd(x))
  expect_equal(core_sd(1:10), stats::sd(1:10))
  # ddof = 0 is the population figure
  expect_equal(core_sd(x, ddof = 0), sqrt(mean((x - mean(x))^2)))
  expect_equal(core_sd(x)^2, stats::var(x))
  # a constant vector has no spread
  expect_equal(core_sd(rep(4, 10)), 0)
  # a single observation has no sample standard deviation to report
  expect_true(is.na(core_sd(5)))

  expect_equal(core_dist(c(0, 0), c(3, 4)), 5)
  expect_equal(core_dist(x, y), sqrt(sum((x - y)^2)))
  # a point is zero from itself, and the metric is symmetric
  expect_equal(core_dist(x, x), 0)
  expect_equal(core_dist(x, y), core_dist(y, x))
  # and it satisfies the triangle inequality
  z <- stats::rnorm(80)
  expect_true(core_dist(x, z) <= core_dist(x, y) + core_dist(y, z))
  expect_error(core_dist(1:3, 1:4), "same length")
})

test_that("core_normal_logpdf is dnorm on the log scale", {
  x <- seq(-4, 4, by = 0.25)
  expect_equal(core_normal_logpdf(x), stats::dnorm(x, log = TRUE))
  expect_equal(core_normal_logpdf(x, 0.3, 1.7),
               stats::dnorm(x, 0.3, 1.7, log = TRUE))
  # exponentiating recovers the density
  expect_equal(exp(core_normal_logpdf(x, -1, 2)), stats::dnorm(x, -1, 2))
  # the peak is -log(sd sqrt(2 pi))
  expect_equal(core_normal_logpdf(5, mean = 5, sd = 2),
               -log(2 * sqrt(2 * pi)))
  # it stays finite where the density itself underflows to zero
  expect_equal(stats::dnorm(50), 0)
  expect_true(is.finite(core_normal_logpdf(50)))
  expect_equal(core_normal_logpdf(50), stats::dnorm(50, log = TRUE))
  # a non-positive scale is not a distribution
  expect_true(is.nan(core_normal_logpdf(0, 0, 0)))
  expect_true(is.nan(core_normal_logpdf(0, 0, -1)))
})

test_that("core_moments computes all four moments in one pass", {
  set.seed(2)
  x <- stats::rnorm(200, mean = 3, sd = 2)
  m <- core_moments(x)
  expect_named(m, c("mean", "variance", "skewness", "kurtosis"))
  expect_equal(m[["mean"]], mean(x))
  expect_equal(m[["variance"]], stats::var(x))
  # the shape statistics are the sample-moment definitions
  cm <- function(k) mean((x - mean(x))^k)
  expect_equal(m[["skewness"]], cm(3) / cm(2)^1.5)
  expect_equal(m[["kurtosis"]], cm(4) / cm(2)^2 - 3)

  # a symmetric sample has no skew
  expect_equal(core_moments(c(-2, -1, 0, 1, 2))[["skewness"]], 0)
  # kurtosis is reported as EXCESS, so a normal sample sits near zero and
  # a heavy-tailed one above it
  expect_lt(abs(core_moments(stats::rnorm(5000))[["kurtosis"]]), 0.4)
  expect_gt(core_moments(c(rep(0, 50), -20, 20))[["kurtosis"]], 5)
  # a right tail gives positive skew
  expect_gt(core_moments(c(rep(1, 20), 50))[["skewness"]], 0)
  expect_lt(core_moments(c(rep(1, 20), -50))[["skewness"]], 0)
  # the one-pass recurrence is numerically stable at a large offset,
  # where a naive sum-of-squares loses the variance entirely
  big <- 1e9 + c(1, 2, 3, 4, 5)
  expect_equal(core_moments(big)[["variance"]], stats::var(big))

  # a shape statistic that is not defined is NaN rather than a guess
  expect_true(is.nan(core_moments(c(1, 2))[["skewness"]]))
  expect_true(is.nan(core_moments(c(1, 2, 3))[["kurtosis"]]))
  expect_true(is.nan(core_moments(1)[["variance"]]))
  # a constant vector has no scale to standardise by
  expect_true(is.nan(core_moments(rep(2, 10))[["skewness"]]))
  # NA propagates rather than being silently dropped
  expect_true(all(is.nan(core_moments(c(1, 2, NA, 4)))))
})

test_that("core_quantile is the type-7 quantile", {
  set.seed(3)
  x <- stats::rnorm(97)
  pr <- c(0, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 1)
  expect_equal(unname(core_quantile(x, pr)),
               unname(stats::quantile(x, pr, type = 7)))
  expect_equal(names(core_quantile(x, c(0.25, 0.5))), c("25%", "50%"))
  # the extremes are the sample extremes
  expect_equal(unname(core_quantile(x, 0)), min(x))
  expect_equal(unname(core_quantile(x, 1)), max(x))
  # a tiny sample still interpolates the way base R does
  expect_equal(unname(core_quantile(c(1, 2), 0.5)), 1.5)
  expect_equal(unname(core_quantile(5, c(0, 0.5, 1))), rep(5, 3))
  # quantiles are non-decreasing in p
  expect_true(all(diff(core_quantile(x, seq(0, 1, by = 0.05))) >= 0))
  expect_error(core_quantile(x, 1.5), "\\[0, 1\\]")
  expect_error(core_quantile(x, -0.1), "\\[0, 1\\]")
  expect_error(core_quantile(x, numeric(0)), "empty")
  expect_error(core_quantile(x, NA), "\\[0, 1\\]")
})

test_that("the robust summaries agree with base R and resist outliers", {
  x <- c(2, 4, 4, 4, 5, 5, 7, 9)
  expect_equal(core_median(x), stats::median(x))
  expect_equal(core_mad(x), stats::mad(x))
  expect_equal(core_mad(x, constant = 1), stats::mad(x, constant = 1))
  expect_equal(core_iqr(x), unname(stats::IQR(x)))
  set.seed(4)
  y <- stats::rnorm(150)
  expect_equal(core_median(y), stats::median(y))
  expect_equal(core_mad(y), stats::mad(y))
  expect_equal(core_iqr(y), unname(stats::IQR(y)))
  # an even-length sample averages the two middle values
  expect_equal(core_median(c(1, 2, 3, 4)), 2.5)

  # the fences are drawn k IQRs beyond the quartiles
  f <- core_tukey_fences(x)
  q <- stats::quantile(x, c(0.25, 0.75), type = 7)
  expect_equal(f[["lower"]], unname(q[1] - 1.5 * (q[2] - q[1])))
  expect_equal(f[["upper"]], unname(q[2] + 1.5 * (q[2] - q[1])))
  expect_named(f, c("lower", "upper"))
  # a wider k gives a wider interval
  f3 <- core_tukey_fences(x, k = 3)
  expect_lt(f3[["lower"]], f[["lower"]])
  expect_gt(f3[["upper"]], f[["upper"]])
  # and the fences identify the planted outlier
  wild <- c(x, 1000)
  fw <- core_tukey_fences(wild)
  expect_equal(wild[wild < fw[["lower"]] | wild > fw[["upper"]]], 1000)

  # robustness: one wild value moves the mean far and the median barely
  expect_gt(abs(mean(wild) - mean(x)), 100)
  expect_lte(abs(core_median(wild) - core_median(x)), 1)
  # NA propagates
  expect_true(is.na(core_median(c(1, NA))))
  expect_true(is.na(core_mad(c(1, NA))))
})

test_that("trimmed and winsorized means behave as documented", {
  x <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 100)
  for (tr in c(0, 0.05, 0.1, 0.2, 0.3, 0.4)) {
    expect_equal(core_trimmed_mean(x, tr), mean(x, trim = tr))
  }
  # trim = 0 is the plain mean; trim = 0.5 is the median
  expect_equal(core_trimmed_mean(x, 0), mean(x))
  expect_equal(core_trimmed_mean(x, 0.5), core_median(x))
  expect_equal(core_winsorized_mean(x, 0.5), core_median(x))

  # the winsorized mean pulls the tails in rather than dropping them, so
  # it stays below the raw mean when there is one high outlier
  expect_lt(core_winsorized_mean(x, 0.1), mean(x))
  # computed by hand: replace the 100 with 9 and the 1 with 2. On this
  # sample the two coincide, because the trimmed pair happens to average
  # to the same value as the pulled-in pair
  expect_equal(core_winsorized_mean(x, 0.1),
               mean(c(2, 2, 3, 4, 5, 6, 7, 8, 9, 9)))
  expect_equal(core_trimmed_mean(x, 0.1), core_winsorized_mean(x, 0.1))
  # where the tails are asymmetric they separate: with two high outliers
  # winsorizing keeps some of their weight and trimming discards it
  asym <- c(1, 2, 3, 4, 5, 6, 7, 8, 500, 900)
  expect_gt(core_winsorized_mean(asym, 0.1), core_trimmed_mean(asym, 0.1))
  # on a symmetric sample with no outliers all three agree
  s <- c(1, 2, 3, 4, 5)
  expect_equal(core_trimmed_mean(s, 0.2), mean(s))
  expect_equal(core_winsorized_mean(s, 0.2), mean(s))
  # trimming more can only move the estimate toward the median, though
  # successive trims can land on the same value
  tms <- vapply(c(0, 0.1, 0.2, 0.3, 0.4, 0.5),
                function(t) core_trimmed_mean(x, t), 0)
  expect_true(all(diff(tms) <= 0))
  expect_lt(tms[length(tms)], tms[1])

  expect_true(is.nan(core_trimmed_mean(x, 0.6)))
  expect_true(is.nan(core_trimmed_mean(x, -0.1)))
  expect_true(is.na(core_trimmed_mean(c(1, NA), 0.1)))
})

test_that("core_weighted matches base R and reduces correctly", {
  x <- c(10, 20, 30, 40)
  w <- c(1, 1, 2, 4)
  r <- core_weighted(x, w)
  expect_named(r, c("mean", "variance"))
  expect_equal(r[["mean"]], stats::weighted.mean(x, w))
  # equal weights recover the unweighted moments exactly
  eq <- core_weighted(x, rep(1, 4))
  expect_equal(eq[["mean"]], mean(x))
  expect_equal(eq[["variance"]], stats::var(x))
  expect_equal(core_weighted(x, rep(3, 4))[["mean"]], mean(x))
  # the weighted variance is the reliability-weight estimator
  sw <- sum(w)
  sw2 <- sum(w^2)
  mu <- sum(w * x) / sw
  expect_equal(r[["variance"]], sum(w * (x - mu)^2) / (sw - sw2 / sw))
  # scaling every weight leaves both moments unchanged
  expect_equal(core_weighted(x, w * 7)[["mean"]], r[["mean"]])
  expect_equal(core_weighted(x, w * 7)[["variance"]], r[["variance"]])
  # a dominant weight pulls the mean onto that observation
  expect_equal(core_weighted(x, c(1, 1, 1, 1e6))[["mean"]], 40,
               tolerance = 1e-3)
  # a zero weight is the same as dropping the observation
  expect_equal(core_weighted(x, c(1, 1, 1, 0))[["mean"]], mean(x[1:3]))

  expect_error(core_weighted(1:3, 1:4), "same length")
  expect_error(core_weighted(x, c(-1, 1, 1, 1)), "non-negative")
  expect_true(is.nan(core_weighted(x, rep(0, 4))[["mean"]]))
})

test_that("Spearman's rho and the midranks match stats::cor and rank", {
  set.seed(5)
  x <- stats::rnorm(120)
  y <- stats::rnorm(120)
  expect_equal(core_cor_spearman(x, y), stats::cor(x, y, method = "spearman"))
  # ties get midranks, which is what makes the agreement hold
  xt <- c(1, 2, 2, 2, 5, 5, 7)
  yt <- c(3, 1, 1, 4, 4, 9, 2)
  expect_equal(core_cor_spearman(xt, yt),
               stats::cor(xt, yt, method = "spearman"))
  expect_equal(core_midranks(xt), rank(xt))
  expect_equal(core_midranks(yt), rank(yt))
  expect_equal(core_midranks(c(5, 5, 5)), rep(2, 3))
  expect_equal(core_midranks(c(3, 1, 2)), c(3, 1, 2))

  # a monotone relationship is rho = 1 even where it is far from linear
  m <- 1:20
  expect_equal(core_cor_spearman(m, m^3), 1)
  expect_equal(core_cor_spearman(m, -exp(m / 5)), -1)
  # invariant to any order-preserving transformation of either variable
  expect_equal(core_cor_spearman(x, y), core_cor_spearman(exp(x), y))
  expect_equal(core_cor_spearman(x, y), core_cor_spearman(x, y^3 * 2))
  # bounded, and zero for a constant column since there is no ordering
  expect_true(abs(core_cor_spearman(x, y)) <= 1)
  expect_true(is.nan(core_cor_spearman(x, rep(1, 120))))
  expect_error(core_cor_spearman(1:3, 1:4), "same length")
})

test_that("core_cov matches stats::cov and keeps its names", {
  set.seed(6)
  X <- cbind(a = stats::rnorm(50), b = stats::rnorm(50), c = stats::rnorm(50))
  expect_equal(core_cov(X), stats::cov(X))
  expect_equal(dimnames(core_cov(X)), list(colnames(X), colnames(X)))
  # the diagonal is the column variances and the matrix is symmetric
  expect_equal(diag(core_cov(X)), apply(X, 2, stats::var))
  expect_equal(core_cov(X), t(core_cov(X)))
  # the off-diagonal is the pairwise covariance
  expect_equal(core_cov(X)["a", "b"], stats::cov(X[, "a"], X[, "b"]))
  # data frames and integer matrices are accepted
  df <- data.frame(u = 1:5, v = c(2, 1, 4, 3, 6))
  expect_equal(core_cov(df), stats::cov(df))
  expect_equal(core_cov(cbind(1:5, 5:1)), stats::cov(cbind(1:5, 5:1)),
               ignore_attr = TRUE)
  # a single column is a 1x1 variance
  expect_equal(as.numeric(core_cov(cbind(z = 1:6))), stats::var(1:6))

  expect_error(core_cov(1:5), "matrix or data frame")
  expect_error(core_cov(data.frame(a = 1:3, b = letters[1:3])),
               "must be numeric")
})

test_that("bootstrap replicate means are reproducible and unbiased", {
  set.seed(7)
  x <- stats::rnorm(60, mean = 5)
  b <- core_bootstrap_mean(x, B = 3000, seed = 11)
  expect_length(b, 3000L)
  # the same seed reproduces the replicates exactly
  expect_identical(core_bootstrap_mean(x, 3000, seed = 11), b)
  expect_false(identical(core_bootstrap_mean(x, 3000, seed = 12), b))
  # the replicates centre on the sample mean, and their spread estimates
  # the standard error. The bootstrap SE is itself a random quantity, so
  # this is a loose agreement by nature, not an identity
  expect_equal(mean(b), mean(x), tolerance = 0.02)
  expect_equal(stats::sd(b), stats::sd(x) / sqrt(length(x)),
               tolerance = 0.1)
  # every replicate is a mean of values drawn from x, so all lie inside
  # the sample range
  expect_true(all(b >= min(x) & b <= max(x)))
  # the core uses its own generator, so R's stream is untouched
  set.seed(99)
  before <- stats::runif(1)
  set.seed(99)
  invisible(core_bootstrap_mean(x, 50, seed = 3))
  expect_equal(stats::runif(1), before)
  # a constant sample bootstraps to that constant
  expect_equal(unique(core_bootstrap_mean(rep(2, 10), 20, seed = 1)), 2)
  expect_error(core_bootstrap_mean(x, 0), ">= 1")
})

test_that("IPW weights invert the clamped propensity score", {
  treat <- c(1, 0, 1, 0)
  e <- c(0.5, 0.25, 0.02, 0.9)
  expect_equal(core_ipw_weights(treat, e),
               c(1 / 0.5, 1 / 0.75, 1 / 0.02, 1 / 0.1))
  # a balanced score gives weight 2 to either arm
  expect_equal(core_ipw_weights(c(1, 0), c(0.5, 0.5)), c(2, 2))
  # the clamp bites before the inversion, so it bounds the weight
  expect_equal(core_ipw_weights(1, 0.001, trim_lo = 0.05), 1 / 0.05)
  expect_equal(core_ipw_weights(0, 0.999, trim_hi = 0.95), 1 / 0.05)
  # a tighter clamp can only shrink an extreme weight
  expect_lt(core_ipw_weights(1, 0.02, trim_lo = 0.10),
            core_ipw_weights(1, 0.02, trim_lo = 0.01))
  # logical indicators work
  expect_equal(core_ipw_weights(c(TRUE, FALSE), c(0.4, 0.4)),
               c(1 / 0.4, 1 / 0.6))
  # every weight is at least 1, since a probability cannot exceed one
  expect_true(all(core_ipw_weights(treat, e) >= 1))
  expect_error(core_ipw_weights(1:3, 1:4), "same length")
  expect_error(core_ipw_weights(1, 0.5, trim_lo = 0), "trim_lo")
  expect_error(core_ipw_weights(1, 0.5, trim_lo = 0.9, trim_hi = 0.1),
               "trim_lo")
})

test_that("core_gamma_cdf is the unit-rate gamma distribution function", {
  q <- c(0.01, 0.5, 1, 2, 4, 12, 40)
  for (a in c(0.5, 1, 2, 3.5, 10)) {
    expect_equal(core_gamma_cdf(a, q), stats::pgamma(q, shape = a))
  }
  # shape 1 is the exponential
  expect_equal(core_gamma_cdf(1, q), stats::pexp(q))
  # it is a distribution function: 0 at the origin, rising to 1
  expect_equal(core_gamma_cdf(2, 0), 0)
  expect_equal(core_gamma_cdf(2, 1e4), 1)
  expect_true(all(diff(core_gamma_cdf(3, seq(0, 20, by = 0.5))) >= 0))
  expect_true(all(core_gamma_cdf(3, q) >= 0 & core_gamma_cdf(3, q) <= 1))
  # the chi-square tail built from it matches stats::pchisq
  for (df in c(1, 2, 5, 8)) {
    for (stat in c(0.5, 2, 6, 15)) {
      expect_equal(1 - core_gamma_cdf(df / 2, stat / 2),
                   stats::pchisq(stat, df, lower.tail = FALSE))
    }
  }
  expect_error(core_gamma_cdf(0, 1), "single positive")
  expect_error(core_gamma_cdf(c(1, 2), 1), "single positive")
})

test_that("the Hawkes likelihood matches an independent recomputation", {
  set.seed(8)
  times <- sort(stats::runif(50, 0, 12))
  horizon <- 12

  a0 <- -0.4
  eta <- 0.35
  beta <- 1.1
  got <- core_hawkes_nll(times, horizon, "exponential", c(a0, eta, beta))
  # the O(n) recursion written out again in R
  nu <- exp(a0)
  A <- 0
  log_sum <- 0
  for (i in seq_along(times)) {
    if (i == 1L) {
      lam <- nu
    } else {
      A <- exp(-beta * (times[i] - times[i - 1L])) * (A + beta)
      lam <- nu + eta * A
    }
    log_sum <- log_sum + log(lam)
  }
  integral <- nu * horizon + sum(eta * (1 - exp(-beta * (horizon - times))))
  expect_equal(got, -(log_sum - integral))

  # the other three kernels are finite and take two shape parameters
  for (k in c("weibull", "lomax", "gamma")) {
    v <- core_hawkes_nll(times, horizon, k, c(a0, eta, 2, 1.5))
    expect_true(is.finite(v))
    expect_false(identical(v, 1e12))
  }

  # a branching ratio at or above one is not a stationary process, and is
  # reported as the sentinel rather than a number an optimiser would
  # happily walk toward
  expect_equal(core_hawkes_nll(times, horizon, "exponential",
                               c(a0, 1.5, beta)), 1e12)
  expect_equal(core_hawkes_nll(times, horizon, "exponential",
                               c(a0, 0, beta)), 1e12)
  expect_equal(core_hawkes_nll(times, horizon, "exponential",
                               c(a0, eta, 100)), 1e12)
  expect_equal(core_hawkes_nll(times, horizon, "exponential",
                               c(50, eta, beta)), 1e12)

  # a stronger baseline raises the intensity everywhere, so an
  # implausibly low one fits worse than a fitted value
  fit <- stats::optim(c(a0, eta, beta),
                      function(p) core_hawkes_nll(times, horizon,
                                                  "exponential", p))
  expect_lt(fit$value, got + 1e-8)
  expect_lt(fit$value, core_hawkes_nll(times, horizon, "exponential",
                                       c(-3, 0.9, 5)))

  expect_error(core_hawkes_nll(times, horizon, "exponential", c(1, 2)),
               "length 3")
  expect_error(core_hawkes_nll(times, horizon, "gamma", c(1, 2, 3)),
               "length 4")
  expect_error(core_hawkes_nll(c(3, 1, 2), horizon, "exponential",
                               c(a0, eta, beta)), "sorted")
  expect_error(core_hawkes_nll(times, -1, "exponential", c(a0, eta, beta)),
               "positive")
  expect_error(core_hawkes_nll(c(1, 20), 10, "exponential",
                               c(a0, eta, beta)), "within")
  expect_error(core_hawkes_nll(c(1, NA), 10, "exponential",
                               c(a0, eta, beta)), "NA")
  expect_error(core_hawkes_nll(times, horizon, "cauchy", c(1, 2, 3)))
})
