# Little's MCAR test and the EM estimator behind it.
#
# The EM estimator is anchored EXACTLY: with no missing values it must
# reproduce the column means and the maximum-likelihood (1/n) covariance,
# which an incorrect E-step would not. The test itself is anchored on its
# operating characteristics -- correctly calibrated under true MCAR
# (rejecting at about the nominal rate) and powerful against a mechanism
# that depends on an observed variable. Those are properties a broken
# implementation fails.

test_that("EM reproduces the ML estimates when nothing is missing", {
  set.seed(81)
  n <- 300
  x <- stats::rnorm(n, mean = 2, sd = 3)
  y <- x * 0.5 + stats::rnorm(n)
  df <- data.frame(x = x, y = y)

  fit <- mcar_test(df)
  # the mean is the column mean
  expect_equal(unname(fit$mu), c(mean(x), mean(y)))
  # the covariance is the ML one, which divides by n rather than n - 1
  expect_equal(unname(fit$sigma), unname(stats::cov(cbind(x, y)) *
                                          (n - 1) / n))
  # complete data is a single pattern, so there is nothing to test
  expect_equal(fit$n_patterns, 1L)
  expect_equal(fit$df, 0)
  expect_true(is.na(fit$p_value))
  expect_false(is.na(fit$note))
  expect_match(fit$note, "nothing to test")
  # and it converges immediately
  expect_lte(fit$iterations, 3L)
})

test_that("EM recovers the parameters under missingness", {
  set.seed(82)
  n <- 2000
  x <- stats::rnorm(n)
  y <- x + stats::rnorm(n)              # var(y) = 2, cov(x, y) = 1
  df <- data.frame(x = x, y = y)
  df$y[sample(n, 600)] <- NA            # MCAR

  fit <- mcar_test(df)
  # the estimates are close to the truth despite 30% of y missing
  expect_equal(unname(fit$mu), c(0, 0), tolerance = 0.1)
  expect_equal(fit$sigma[1, 1], 1, tolerance = 0.1)
  expect_equal(fit$sigma[2, 2], 2, tolerance = 0.15)
  expect_equal(fit$sigma[1, 2], 1, tolerance = 0.1)
  # the covariance is symmetric and positive definite
  expect_equal(fit$sigma, t(fit$sigma))
  expect_true(all(eigen(fit$sigma, symmetric = TRUE)$values > 0))
  expect_equal(fit$n_patterns, 2L)
  expect_equal(fit$df, 1)
  expect_true(fit$iterations >= 1L)

  # the estimates beat complete-case analysis is not the claim; the
  # claim is that they are consistent, so a bigger sample is closer
  expect_true(is.finite(fit$p_value))
  expect_true(fit$p_value >= 0 && fit$p_value <= 1)
})

test_that("the test is calibrated under true MCAR", {
  skip_on_cran()
  # Missingness decided by a coin flip cannot depend on the data, so the
  # test should reject at about its nominal rate and no more. A broken
  # statistic or the wrong degrees of freedom shows up here immediately.
  rejections <- 0L
  n_sim <- 200L
  pvals <- numeric(n_sim)
  for (s in seq_len(n_sim)) {
    set.seed(9000L + s)
    a <- stats::rnorm(200)
    b <- a * 0.5 + stats::rnorm(200)
    d <- data.frame(a = a, b = b)
    d$b[sample(200, 60)] <- NA
    p <- mcar_test(d)$p_value
    pvals[s] <- p
    if (!is.na(p) && p < 0.05) rejections <- rejections + 1L
  }
  rate <- rejections / n_sim
  # the nominal rate is 0.05; allow generous simulation slack
  expect_lt(rate, 0.15)
  expect_gt(rate, 0.005)
  # and the p-values are roughly uniform, which is the stronger claim
  expect_gt(stats::ks.test(pvals, "punif")$p.value, 0.01)
})

test_that("the test detects missingness that depends on the data", {
  skip_on_cran()
  # Here y is missing exactly when x is large, so the pattern with y
  # observed has a shifted mean of x -- which is what the statistic
  # measures.
  detections <- 0L
  n_sim <- 40L
  for (s in seq_len(n_sim)) {
    set.seed(9500L + s)
    a <- stats::rnorm(300)
    b <- a * 0.5 + stats::rnorm(300)
    d <- data.frame(a = a, b = b)
    d$b[a > 0.3] <- NA
    p <- mcar_test(d)$p_value
    if (!is.na(p) && p < 0.05) detections <- detections + 1L
  }
  # this is a strong, systematic departure: it should almost always be
  # caught
  expect_gt(detections / n_sim, 0.8)
})

test_that("the statistic is the documented quadratic form", {
  set.seed(83)
  n <- 400
  df <- data.frame(a = stats::rnorm(n), b = stats::rnorm(n))
  df$b[1:120] <- NA
  fit <- mcar_test(df)

  # recompute d^2 by hand from the returned estimates: two patterns,
  # one observing only `a` and one observing both
  X <- as.matrix(df)
  obs <- !is.na(X)
  codes <- apply(obs, 1L, function(r) paste0(as.integer(r), collapse = ""))
  d2 <- 0
  dfsum <- 0
  for (code in unique(codes)) {
    rows <- which(codes == code)
    o <- which(obs[rows[1L], ])
    xbar <- colMeans(X[rows, o, drop = FALSE])
    diff <- xbar - fit$mu[o]
    Sj <- fit$sigma[o, o, drop = FALSE]
    d2 <- d2 + length(rows) * as.numeric(t(diff) %*% solve(Sj) %*% diff)
    dfsum <- dfsum + length(o)
  }
  expect_equal(fit$statistic, d2, tolerance = 1e-6)
  expect_equal(fit$df, dfsum - 2)
  # and the p-value is the chi-square tail
  expect_equal(fit$p_value,
               stats::pchisq(fit$statistic, fit$df, lower.tail = FALSE),
               tolerance = 1e-8)
  expect_gte(fit$statistic, 0)
})

test_that("mcar_test handles the awkward inputs", {
  set.seed(84)
  df <- data.frame(a = stats::rnorm(100), b = stats::rnorm(100),
                   g = sample(letters[1:3], 100, TRUE),
                   stringsAsFactors = FALSE)
  df$b[1:20] <- NA
  # a non-numeric column cannot enter a moment, so it is dropped loudly
  expect_warning(r <- mcar_test(df), "non-numeric")
  expect_equal(r$n_vars, 2L)

  # three columns and several patterns still works
  z <- data.frame(a = stats::rnorm(300), b = stats::rnorm(300),
                  c = stats::rnorm(300))
  z$b[1:80] <- NA
  z$c[200:260] <- NA
  r3 <- mcar_test(z)
  expect_equal(r3$n_vars, 3L)
  expect_gte(r3$n_patterns, 3L)
  expect_gt(r3$df, 0)
  expect_true(is.finite(r3$p_value))

  # a wholly missing column carries nothing and is dropped
  w <- data.frame(a = stats::rnorm(50), b = stats::rnorm(50),
                  dead = rep(NA_real_, 50))
  w$b[1:10] <- NA
  expect_equal(mcar_test(w)$n_vars, 2L)
  # a wholly missing row belongs to no pattern
  rr <- data.frame(a = c(stats::rnorm(50), NA), b = c(stats::rnorm(50), NA))
  rr$b[1:10] <- NA
  expect_lte(mcar_test(rr)$n_used, 50L)

  # a matrix is accepted
  expect_true(is.finite(mcar_test(as.matrix(z))$statistic))
  expect_output(print(mcar_test(z)), "Little's MCAR test")
  expect_output(print(mcar_test(z)), "power")

  expect_error(mcar_test(data.frame(a = 1:10)), "at least two numeric")
  expect_error(mcar_test(1:10), "data frame or a numeric matrix")
})
