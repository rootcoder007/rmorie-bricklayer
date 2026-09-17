test_that("core_mean and its dependants survive where base R does", {
  expect_identical(core_mean(rep(1e308, 3)), 1e308)
  expect_identical(core_mean(rep(1e120, 3)), 1e120)
  expect_identical(core_var(rep(1e120, 3)), 0)
  expect_identical(core_var(rep(1e308, 3)), 0)
  expect_identical(core_mean(c(1, Inf)), Inf)
  expect_true(is.na(core_mean(c(1, NA))))
  set.seed(3)
  x <- stats::rnorm(1000, 1e6, 1)
  expect_identical(core_mean(x), mean(x))
  expect_equal(core_var(x), stats::var(x), tolerance = 1e-14)
})

test_that("the running-mean fallback matches mean() and cannot overflow", {
  r <- rmoriebricklayer:::.core_mean_running
  expect_identical(r(rep(1e308, 3)), 1e308)
  expect_equal(r(c(1e308, 1e308, -1e308)), 1e308 / 3, tolerance = 1e-15)
  expect_equal(r(c(-1e308, 1e308, 1e308, -1e308)), 0)
  expect_true(is.na(r(numeric(0))))
  expect_true(is.na(r(c(1, NA))))
  set.seed(4)
  x <- stats::rnorm(500, 1e6, 1)
  expect_equal(r(x), mean(x), tolerance = 1e-12)
  expect_equal(r(1:10), 5.5)
})

test_that("core_moments survives the extremes and keeps its definitions", {
  m <- core_moments(rep(1e308, 3))
  expect_identical(unname(m[c("mean", "variance")]), c(1e308, 0))
  expect_true(all(is.nan(m[c("skewness", "kurtosis")])))  # no spread: undefined
  x <- c(1e150, 2e150, 4e150, 8e150)
  m <- core_moments(x)
  cm <- function(k) mean(((x - mean(x)) / 1e150)^k)
  expect_equal(m[["mean"]], mean(x))
  expect_equal(m[["variance"]], stats::var(x / 1e150) * 1e300,
               tolerance = 1e-12)
  expect_equal(m[["skewness"]], cm(3) / cm(2)^1.5)
  expect_equal(m[["kurtosis"]], cm(4) / cm(2)^2 - 3)
  set.seed(6)
  y <- stats::rnorm(300, 5, 2)
  m <- core_moments(y)
  cy <- function(k) mean((y - mean(y))^k)
  expect_equal(m[["mean"]], mean(y))
  expect_equal(m[["variance"]], stats::var(y))
  expect_equal(m[["skewness"]], cy(3) / cy(2)^1.5)
  expect_equal(m[["kurtosis"]], cy(4) / cy(2)^2 - 3)
  # the streaming accumulator no longer squares its first value
  st <- summary_stats(online_summary(rep(1e308, 3)))
  expect_identical(unname(st[c("mean", "variance")]), c(1e308, 0))
  st <- summary_stats(summary_update(online_summary(c(1e300, 3e300)), 5e300))
  expect_equal(st[["mean"]], 3e300)
  expect_equal(st[["variance"]], stats::var(c(1, 3, 5)) * 1e600,
               tolerance = 1e-12)
})

test_that("json_gzip_decode refuses input that is not a gzip member", {
  expect_error(json_gzip_decode(""), "gzip member")
  expect_error(json_gzip_decode(raw(0)), "gzip member")
  expect_error(json_gzip_decode(charToRaw("abc")), "gzip member")
  expect_error(json_gzip_decode(-1), "gzip member")
  enc <- json_gzip_encode(list(a = 1, b = "x"))
  expect_equal(json_gzip_decode(enc), list(a = 1, b = "x"))
})
