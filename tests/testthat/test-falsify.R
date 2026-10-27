# SPDX-License-Identifier: AGPL-3.0-or-later

fals_data <- function() {
  set.seed(1)
  x <- stats::rnorm(60)
  data.frame(x = x, y = 2 * x + stats::rnorm(60))
}

test_that("a real association passes its controls, reproducibly", {
  d <- fals_data()
  st <- function(z) stats::cor(z$x, z$y)
  r <- cpsfals(d, st, trt = "x", n = 49, seed = 42)
  expect_s3_class(r, "bricklayer_falsification")
  expect_identical(
    r$controls$control,
    c("permutation", "placebo", "random_common_cause", "subset_stability")
  )
  expect_true(r$controls$passed[r$controls$control == "permutation"])
  expect_true(r$controls$passed[r$controls$control == "random_common_cause"])
  expect_length(r$permutation, 49L)
  expect_identical(r, cpsfals(d, st, trt = "x", n = 49, seed = 42))
  expect_type(format(r), "character")
})

test_that("without a treatment the permutation controls are skipped", {
  r <- cpsfals(fals_data(), function(z) mean(z$y), n = 19, seed = 1)
  expect_identical(r$controls$passed[1:2], c(NA, NA))
  expect_match(r$controls$detail[1L], "skipped", fixed = TRUE)
  expect_null(r$permutation)
  expect_null(r$treatment)
})

test_that("a statistic that fails on every subset fails stability", {
  st <- function(z) if (nrow(z) == 60L) 1 else stop("too few")
  r <- cpsfals(fals_data(), st, n = 9, seed = 1)
  expect_false(r$controls$passed[r$controls$control == "subset_stability"])
})

test_that("cpsfals() refuses bad input in words", {
  d <- fals_data()
  st <- function(z) mean(z$y)
  expect_error(cpsfals(d[1:3, ], st), "at least 4 rows")
  expect_error(cpsfals(d, 1), "must be a function")
  expect_error(cpsfals(d, st, n = 5), "at least 9")
  expect_error(cpsfals(d, st, subfrac = 1), "between 0 and 1")
  expect_error(cpsfals(d, st, trt = "nope"), "not a column")
  expect_error(cpsfals(d, function(z) c(1, 2), n = 9), "one finite number")
  expect_error(cpsfals(d, function(z) stop("boom"), n = 9), "boom")
})

test_that("cpsfals names trt", {
  expect_error(
    cpsfals(data.frame(x = 1), function(z) 1, trt = function() 1),
    "cpsfals: `trt` must be data"
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

test_that("falsification controls print as a box", {
  r <- list(
    observed = 1.5,
    controls = data.frame(
      control = c("permutation", "placebo"),
      passed = c(TRUE, NA),
      p_value = c(0.01, NA),
      detail = c("p = 0.01", "skipped"),
      stringsAsFactors = FALSE
    ),
    n = 99L,
    treatment = "t",
    rng_kind = "Mersenne-Twister",
    seed = 3
  )
  class(r) <- c("bricklayer_falsification", "list")
  b <- o1_box(r)
  o1_expect_box(b, r, "Falsification controls", c("99", "Seed", "skipped"))
  r$controls$passed[1L] <- FALSE
  expect_true(any(grepl("control failed", format(r), fixed = TRUE)))
})
