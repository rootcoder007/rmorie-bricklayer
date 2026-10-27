# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("pubbnd() bounds rounded, suppressed and exact cells", {
  b <- pubbnd(c("120", "x", "<5", "1,200", NA), rnd = 5, suplim = 10)
  expect_s3_class(b, "rmbl_bounds")
  expect_identical(
    b$status,
    c("rounded", "suppressed", "suppressed", "rounded", "missing")
  )
  expect_identical(b$lower, c(117.5, 0, 0, 1197.5, NA))
  expect_identical(b$upper, c(122.5, 9, 4, 1202.5, NA))
  expect_identical(b$value, c(120, NA, NA, 1200, NA))
  expect_identical(attr(b, "bounds")$rounding, 5)
  r <- pubbnd(15, rnd = 5, rndkind = "random")
  expect_identical(c(r$lower, r$upper), c(11, 19))
  e <- pubbnd(c(3, 0))
  expect_identical(e$status, c("exact", "exact"))
  expect_identical(e$lower, e$upper)
  expect_identical(pubbnd(2, rnd = 10)$lower, 0)
  m <- pubbnd(c("--", "7"), supmar = "--", suplim = 3)
  expect_identical(m$upper, c(2, 7))
})

test_that("pubbnd() refuses what it cannot read", {
  expect_error(pubbnd(c("120", "x")), "a suppressed cell has no limit")
  expect_error(pubbnd(c("12", "abc", "abc")), "suppression marks: abc")
  expect_error(pubbnd(1, rnd = -5), "`rnd` must be a positive number")
  expect_error(pubbnd(1, supmar = 1), "`supmar` must be the text markers")
})

test_that("chgenv() carries the bounds through a change and a rate", {
  now <- pubbnd(c(45, 120), rnd = 5)
  prev <- pubbnd(c(40, 100), rnd = 5)
  env <- chgenv(now, prev, pop = c(10000, 20000), prepop = 10000)
  expect_identical(env$chglo, c(42.5, 117.5) - c(42.5, 102.5))
  expect_identical(env$chgup, c(47.5, 122.5) - c(37.5, 97.5))
  expect_equal(
    env$pctlo,
    100 * (c(42.5, 117.5) / c(42.5, 102.5) - 1),
    tolerance = 1e-12
  )
  expect_identical(env$ratelo, 1000 * c(42.5, 117.5) / c(10000, 20000))
  expect_identical(env$prerateup, 1000 * c(42.5, 102.5) / 10000)
  z <- chgenv(pubbnd(12), pubbnd("<5"))
  expect_identical(z$pctup, NA_real_)
  expect_error(chgenv(now, prev[1, ]), "the same number of rows")
  expect_error(chgenv(list(), prev), "`now` must be a data frame")
  expect_error(chgenv(now, 1), "`prev` must be a data frame")
  expect_error(
    chgenv(now, prev, pop = c(1, 2, 3)),
    "`pop` must be one number or one per row (2)",
    fixed = TRUE
  )
})

test_that("yoybnd() adds the envelope to a yoy() table", {
  seg <- data.frame(year = 2021:2023, n = c(40, 45, 60))
  y <- yoy(seg, value = "n", prd = "year")
  yb <- yoybnd(y, rnd = 5)
  expect_s3_class(yb, "rmbl_yoy")
  expect_true(all(c("envpctlo", "envpctup", "compctlo") %in% names(yb)))
  expect_identical(attr(yb, "yoy")$bounds$rounding, 5)
  expect_error(yoybnd(seg, rnd = 5), "`y` must come from yoy()", fixed = TRUE)
})

test_that("pubbnd refuses negative or infinite counts and an infinite rnd", {
  for (x in list(-10, Inf, "-10", c(5, -1))) {
    expect_error(pubbnd(x, rnd = 5), "`x` must hold counts")
  }
  expect_error(pubbnd(5, rnd = Inf), "`rnd` must be a positive number")
  expect_error(pubbnd(5, rnd = c(5, 10)), "`rnd` must be a positive number")
  expect_error(pubbnd(5, suplim = Inf), "`suplim` must be one number")
  expect_identical(pubbnd(c(120, 0), rnd = 5)$upper, c(122.5, 2.5))
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

test_that("publication bounds print as a box", {
  b <- pubbnd(c("10", "<5", NA), rnd = 5)
  o1_expect_box(o1_box(b), b, "Publication bounds", c("Cells", "suppressed"))
  expect_true(any(grepl(
    "value",
    format(b[, "value", drop = FALSE]),
    fixed = TRUE
  )))
})

test_that("chgenv() results print as a box", {
  n0 <- data.frame(lower = c(10, 20), upper = c(14, 24))
  p0 <- data.frame(lower = c(5, 22), upper = c(9, 26))
  e <- chgenv(n0, p0, pop = c(1000, 2000), prepop = c(900, 2100))
  expect_s3_class(e, c("rmbl_change_bounds", "data.frame"))
  expect_box2(e, "Change between published", c("previous rate", "[1, 9]"))
  e2 <- chgenv(n0, p0)
  expect_box2(e2, "Change between published", c("Certain rises", "change %"))
  expect_box2(e2["chglo"], "Change between published", "plain table")
})
