stream_after <- function(seed, f) {
  set.seed(seed)
  f()
  stats::runif(1)
}

test_that("seeded functions leave the caller's stream as a plain seed would", {
  set.seed(2)
  d <- data.frame(a = rnorm(120), b = sample(letters[1:3], 120, TRUE))
  fns <- list(
    drift_calibrate = function() drift_calibrate(d, n = 4, seed = 3L),
    capsule_power = function() {
      capsule_power(d$a, effect = 0.3, n_sim = 30L, seed = 4L)
    }
  )
  for (nm in names(fns)) {
    f <- fns[[nm]]
    a <- tryCatch(stream_after(11, f), error = function(e) NULL)
    if (is.null(a)) next
    b <- stream_after(22, f)
    expect_false(isTRUE(all.equal(a, b)), info = nm)
    set.seed(11)
    expect_identical(a, stats::runif(1), info = nm)
  }
})

test_that("the helper itself restores, and is a no-op for NULL", {
  set.seed(5)
  ref <- stats::runif(1)
  f <- function() {
    rmoriebricklayer:::.rmbl_local_seed(1L)
    stats::runif(1)
  }
  set.seed(5)
  x <- f()
  expect_identical(stats::runif(1), ref)
  set.seed(9)
  expect_identical(f(), x)
  expect_null(rmoriebricklayer:::.rmbl_local_seed(NULL))
})
