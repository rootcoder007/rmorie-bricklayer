# spread(): the denominator the source of the data calls for

test_that("sprd() applies Bessel's correction to a sample, none to a census, and the FPC", {
  x <- c(12, 15, 9, 20, 14)
  s <- sprd(x)
  expect_identical(s$design, "sample")
  expect_equal(s$variance, stats::var(x))
  expect_equal(s$sd, stats::sd(x))
  expect_equal(s$semean, stats::sd(x) / sqrt(5))
  ce <- sprd(x, des = "census")
  expect_equal(ce$variance, mean((x - mean(x))^2))
  expect_identical(ce$semean, 0)
  expect_identical(sprd(x, N = 5)$design, "census")
  f <- sprd(x, N = 40)
  expect_identical(f$design, "finite")
  expect_equal(f$variance, stats::var(x))
  expect_equal(f$semean, sqrt((1 - 5 / 40) * stats::var(x) / 5))
  expect_output(print(f), "finite-population correction 1 - n/N = 0.875")
  expect_output(print(sprd(x, N = 1000)), "negligible")
})

test_that("sprd() with frequency and reliability weights", {
  fw <- sprd(c(1, 2, 3), w = c(10, 5, 1))
  expect_equal(fw$variance, stats::var(rep(1:3, c(10, 5, 1))))
  expect_equal(fw$mean, mean(rep(1:3, c(10, 5, 1))))
  rw <- sprd(c(1, 2, 3, 4), w = c(1, 1, 1, 1), wtype = "reliability")
  expect_equal(rw$variance, stats::var(1:4))
  rw2 <- sprd(c(1, 2, 3, 4), w = c(1, 2, 1, 2), wtype = "reliability")
  m <- sum(c(1, 2, 1, 2) * 1:4) / 6
  expect_equal(rw2$variance, sum(c(1, 2, 1, 2) * (1:4 - m)^2) / (6 - 10 / 6))
  expect_equal(rw2$semean, sqrt(sum(c(1, 2, 1, 2)^2 * (1:4 - m)^2)) / 6)
})

test_that("sprd() refuses what it cannot compute", {
  expect_error(sprd(c(1, NA)), "missing values")
  expect_equal(sprd(c(1, NA, 3), narm = TRUE)$mean, 2)
  expect_error(sprd(1:3, des = "finite"), "needs `N`")
  expect_error(sprd(1:3, N = 2), "smaller than")
  expect_error(sprd(1:3, w = 1:2), "one per value")
  expect_true(is.na(sprd(5)$variance))
})
