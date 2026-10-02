old_sen_ci <- function(x, y, var_s, conf_level) {
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

test_that("the Sen interval in C matches the former R loop exactly", {
  set.seed(8)
  x <- c(1:25, 25, 26:40)   # one repeated x: that pair contributes no slope
  y <- 0.3 * x + rnorm(length(x))
  mk <- .Call(rmoriebricklayer:::C_rmbl_mann_kendall, y[order(x)])
  new <- rmoriebricklayer:::.rmbl_sen_ci(sort(x), y[order(x)], mk$var, 0.95)
  old <- old_sen_ci(sort(x), y[order(x)], mk$var, 0.95)
  expect_identical(new, old)
})

test_that("trend_test scales to thousands of periods, refuses absurd sizes", {
  set.seed(9)
  y <- cumsum(rnorm(3000))
  t0 <- proc.time()[["elapsed"]]
  r <- trend_test(y)
  expect_lt(proc.time()[["elapsed"]] - t0, 30)
  expect_true(is.finite(r$slope_lower) && is.finite(r$slope_upper))
  expect_error(trend_test(seq_len(20001)), "20001")
})

test_that("step_change leaves the session's random state as it found it, present or not", {
  y <- c(1, 1.2, 0.9, 1.1, 1, 0.8, 5, 5.1, 4.9, 5.2, 5, 4.8)
  suppressWarnings(rm(".Random.seed", envir = globalenv()))
  r <- step_change(y, n_perm = 50L, seed = 3L)
  expect_identical(r$index, 6L)
  expect_false(exists(".Random.seed", envir = globalenv()))
  set.seed(11)
  before <- get(".Random.seed", envir = globalenv())
  step_change(y, n_perm = 50L, seed = 3L)
  expect_identical(get(".Random.seed", envir = globalenv()), before)
})
