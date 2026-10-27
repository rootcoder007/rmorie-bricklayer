# SPDX-License-Identifier: AGPL-3.0-or-later

pw_data <- function() {
  set.seed(11)
  x <- stats::rnorm(40)
  data.frame(x = x, y = stats::rnorm(40))
}

pw_stat <- function(z) stats::cor(z$x, z$y)

pw_inject <- function(z, size) {
  z$y <- z$y + size * z$x
  z
}

test_that("cpspwr() detects a large injected effect and not size zero", {
  pw <- cpspwr(
    pw_data(),
    pw_stat,
    pw_inject,
    sizes = c(0, 3),
    trt = "x",
    n = 19L,
    reps = 2L,
    seed = 3
  )
  expect_s3_class(pw, "bricklayer_power")
  expect_identical(pw$curve$size, c(0, 3))
  expect_identical(pw$curve$reps, c(2L, 2L))
  expect_identical(pw$curve$detected[[2L]], 2L)
  expect_identical(pw$smadet, 3)
  expect_identical(pw$n, 19L)
  expect_identical(pw$treatment, "x")
  expect_identical(pw$false_positive_rate, pw$curve$rate[[1L]])
  out <- format(pw)
  expect_type(out, "character")
  expect_true(any(grepl("smallest size detected", out, fixed = TRUE)))
  expect_output(print(pw), "Positive controls")
})

test_that("cpspwr() with the same seed gives the same curve", {
  a <- cpspwr(
    pw_data(),
    pw_stat,
    pw_inject,
    sizes = 0.2,
    trt = "x",
    n = 19L,
    reps = 2L,
    seed = 9
  )
  b <- cpspwr(
    pw_data(),
    pw_stat,
    pw_inject,
    sizes = 0.2,
    trt = "x",
    n = 19L,
    reps = 2L,
    seed = 9
  )
  expect_identical(a$curve, b$curve)
  # size 0 is always tried
  expect_identical(a$curve$size, c(0, 0.2))
})

test_that("cpspwr() refuses inputs it cannot use", {
  d <- pw_data()
  expect_error(
    cpspwr(list(), pw_stat, pw_inject, trt = "x"),
    "at least 4 rows"
  )
  expect_error(
    cpspwr(d, "cor", pw_inject, trt = "x"),
    "must both be functions"
  )
  expect_error(cpspwr(d, pw_stat, pw_inject), "`trt` is required")
  expect_error(
    cpspwr(d, pw_stat, pw_inject, trt = "w"),
    "`trt` is not a column"
  )
  expect_error(
    cpspwr(d, pw_stat, pw_inject, trt = "x", n = 3L),
    "`n` must be at least 9"
  )
  expect_error(
    cpspwr(d, pw_stat, pw_inject, trt = "x", n = 19L, reps = 0L),
    "`reps` must be at least 1"
  )
  expect_error(
    cpspwr(d, pw_stat, pw_inject, trt = "x", n = 9L),
    "no size could ever be detected",
    fixed = TRUE
  )
})

test_that("cpspwr() reports no detection when nothing is detected", {
  pw <- cpspwr(
    pw_data(),
    pw_stat,
    function(z, size) z,
    sizes = 0.1,
    trt = "x",
    n = 19L,
    reps = 1L,
    seed = 2
  )
  expect_identical(pw$smadet, NA_real_)
  expect_true(any(grepl("no size was detected", format(pw), fixed = TRUE)))
})

test_that("cpspwr refuses missing, infinite or no sizes, and names trt", {
  d <- data.frame(x = 1:5, y = 1:5)
  st <- function(z) 1
  inj <- function(d, s) d
  for (s in list(NA, NaN, Inf, c(0.2, NA), numeric(0))) {
    expect_error(
      cpspwr(d, st, inj, sizes = s, trt = "x"),
      "cpspwr: `sizes` must be finite numbers"
    )
  }
  expect_error(
    cpspwr(d, st, inj, trt = function() 1),
    "cpspwr: `trt` must be data"
  )
})

# Prints `x` on an ASCII console: the lines and what print() returned.
o1_box <- function(x, ...) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  tmp <- withr::local_tempfile()
  v <- withr::with_output_sink(tmp, withVisible(print(x, ...)))
  list(out = readLines(tmp), v = v)
}

# The box's frame, its title and the facts expected in it.
o1_expect_box <- function(b, x, title, facts = character()) {
  expect_false(b$v$visible)
  expect_identical(b$v$value, x)
  expect_match(b$out[1L], "^\\+-- ")
  expect_true(grepl(title, b$out[1L], fixed = TRUE))
  expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  for (f in facts) {
    expect_true(any(grepl(f, b$out, fixed = TRUE)), info = f)
  }
}

test_that("positive controls print as a box", {
  pw <- list(
    curve = data.frame(size = c(0, 1), detected = c(0L, 2L), reps = c(2L, 2L),
      rate = c(0, 1)),
    alpha = 0.05,
    n = 19L,
    reps = 2L,
    treatment = "x",
    smadet = 1,
    false_positive_rate = 0
  )
  class(pw) <- c("bricklayer_power", "list")
  o1_expect_box(o1_box(pw), pw, "Positive controls", c("2/2", "Smallest"))
  pw$smadet <- NA_real_
  expect_true(any(grepl("no size was detected", format(pw), fixed = TRUE)))
})
