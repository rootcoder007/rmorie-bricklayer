# spread(): the denominator the source of the data calls for

test_that("spread() applies Bessel's correction to a sample, none to a census, and the FPC", {
  x <- c(12, 15, 9, 20, 14)
  s <- spread(x)
  expect_identical(s$design, "sample")
  expect_equal(s$variance, stats::var(x))
  expect_equal(s$sd, stats::sd(x))
  expect_equal(s$se_mean, stats::sd(x) / sqrt(5))
  ce <- spread(x, design = "census")
  expect_equal(ce$variance, mean((x - mean(x))^2))
  expect_identical(ce$se_mean, 0)
  expect_identical(spread(x, population_size = 5)$design, "census")
  f <- spread(x, population_size = 40)
  expect_identical(f$design, "finite")
  expect_equal(f$variance, stats::var(x))
  expect_equal(f$se_mean, sqrt((1 - 5 / 40) * stats::var(x) / 5))
  expect_output(print(f), "finite-population correction 1 - n/N = 0.875")
  expect_output(print(spread(x, population_size = 1000)), "negligible")
})

test_that("spread() with frequency and reliability weights", {
  fw <- spread(c(1, 2, 3), weights = c(10, 5, 1))
  expect_equal(fw$variance, stats::var(rep(1:3, c(10, 5, 1))))
  expect_equal(fw$mean, mean(rep(1:3, c(10, 5, 1))))
  rw <- spread(c(1, 2, 3, 4), weights = c(1, 1, 1, 1), weights_type = "reliability")
  expect_equal(rw$variance, stats::var(1:4))
  rw2 <- spread(c(1, 2, 3, 4), weights = c(1, 2, 1, 2), weights_type = "reliability")
  m <- sum(c(1, 2, 1, 2) * 1:4) / 6
  expect_equal(rw2$variance, sum(c(1, 2, 1, 2) * (1:4 - m)^2) / (6 - 10 / 6))
  expect_equal(rw2$se_mean, sqrt(sum(c(1, 2, 1, 2)^2 * (1:4 - m)^2)) / 6)
})

test_that("spread() refuses what it cannot compute", {
  expect_error(spread(c(1, NA)), "missing values")
  expect_equal(spread(c(1, NA, 3), na_rm = TRUE)$mean, 2)
  expect_error(spread(1:3, design = "finite"), "needs `population_size`")
  expect_error(spread(1:3, population_size = 2), "smaller than")
  expect_error(spread(1:3, weights = 1:2), "one per value")
  expect_true(is.na(spread(5)$variance))
})
