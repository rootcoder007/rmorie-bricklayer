# SPDX-License-Identifier: AGPL-3.0-or-later
# Hawkes fits: the shared uniforms, the jitter of tied times, the INAR route
# and the input checks.

test_that("cunif() is reproducible and checks n", {
  u <- cunif(5, 1)
  expect_length(u, 5L)
  expect_true(all(u >= 0 & u < 1))
  expect_identical(cunif(5, 1), u)
  expect_false(identical(cunif(5, 2), u))
  expect_length(cunif(0, 1), 0L)
  expect_error(cunif(-1, 1), "non-negative whole number")
  expect_error(cunif(1.5, 1), "non-negative whole number")
  expect_error(cunif(c(1, 2), 1), "non-negative whole number")
  expect_error(cunif(3e9, 1), "at most 2147483647")
})

test_that("chwkjit() spreads tied times inside their resolution", {
  j <- chwkjit(c(0, 0, 0, 2))
  expect_length(j, 4L)
  expect_false(anyDuplicated(j) > 0L)
  expect_identical(j, sort(j))
  expect_true(all(j[1:3] >= 0 & j[1:3] < 1))
  expect_gte(j[[4L]], 2)
  expect_lt(j[[4L]], 3)
  expect_lte(max(chwkjit(c(0, 1, 2), hor = 2)), 2)
  expect_error(chwkjit(c(0, 5), hor = 3), "must not exceed")
  expect_error(chwkjit(c(0, NA)), "finite numbers")
  expect_error(chwkjit(c(0, Inf)), "finite numbers")
  expect_error(chwkjit(1, res = 0), "positive finite")
})

test_that("chwkfit() refuses too few events, a bad eps and a bad start", {
  set.seed(1)
  times <- sort(stats::runif(400, 0, 100))
  expect_error(chwkfit(times[1:20], 100), "too few events")
  expect_error(chwkfit(times, 100, eps = 2), "`eps` must be a single number")
  expect_error(
    chwkfit(times, 100, start = c(1, 2)),
    "`start` must have length 3"
  )
  expect_error(chwkfit(times * 1e-12, 1e-10), "outside what the fit")
})

test_that("the INAR route gives a branching ratio inside its box", {
  set.seed(1)
  times <- sort(stats::runif(400, 0, 100))
  f <- chwkfit(times, 100, meth = "inar")
  expect_identical(f$method, "inar")
  expect_gte(f$braratio, 0)
  expect_lt(f$braratio, 1)
  expect_length(f$theta, 3L)
  expect_true(f$converged)
  expect_true(is.finite(f$nll))
})

test_that("Levinson-Durbin solves the Yule-Walker system", {
  # an AR(1) with coefficient one half
  expect_equal(
    .rmbl_hk_levinson(c(1, 0.5, 0.25), 2L),
    c(0.5, 0),
    tolerance = 1e-12
  )
  expect_equal(.rmbl_hk_levinson(c(2, 1), 1L), 0.5, tolerance = 1e-12)
})

test_that("a chwkfit() result prints as a box", {
  set.seed(2)
  tm <- sort(stats::runif(200, 0, 50))
  f <- chwkfit(tm, 50, "weibull")
  expect_s3_class(f, "rmbl_hawkes_fit")
  expect_type(f, "list")
  expect_box2(
    f,
    "Hawkes process fit",
    c("Branching ratio (eta)", "lambda", "Residual KS test", "On the box")
  )
  f$kspva <- 0.001
  f$atbound <- "eta"
  expect_box2(f, "Hawkes process fit", c("misses some", "on the box"))
  f$theta <- f$theta[-1L]
  f$kspva <- NA_real_
  expect_box2(f, "Hawkes process fit", c("theta1", "no residual check"))
})
