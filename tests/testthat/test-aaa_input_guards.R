# SPDX-License-Identifier: AGPL-3.0-or-later
# The argument guards every exported function calls.

test_that(".rmbl_arg() matches a choice, defaulting to the first", {
  f <- function(x = c("one", "two")) .rmbl_arg(x)
  expect_identical(f(), "one")
  expect_identical(f("two"), "two")
  expect_identical(f(NULL), "one")
  expect_error(f("three"), "one", fixed = TRUE)
  g <- function(x) .rmbl_arg(x, c("a", "b", "c"), several = TRUE)
  expect_identical(g(c("a", "c")), c("a", "c"))
  expect_error(g(1))
})

test_that("finite inputs and counts are checked", {
  expect_identical(.rmbl_finite_input(c(1, NA, 2), "x"), c(1, 2))
  expect_error(.rmbl_finite_input(c(1, Inf), "x"), "must be finite")
  expect_error(.rmbl_check_counts(c(1, -1), "v"), "non-negative counts")
  expect_error(.rmbl_check_counts(c(1, NA), "v"), "non-negative counts")
  expect_error(.rmbl_num(TRUE, "n"), "number")
  expect_error(.rmbl_num("abc", "n"), "must be numeric")
})

test_that(".rmbl_with_seed() leaves the session's stream as it was", {
  set.seed(42)
  before <- .Random.seed
  a <- .rmbl_with_seed(1, stats::runif(3))
  expect_identical(.Random.seed, before)
  expect_identical(a, .rmbl_with_seed(1, stats::runif(3)))
  expect_length(.rmbl_with_seed(NULL, stats::runif(2)), 2L)
})

test_that("names are swapped through names, dimnames and nested lists", {
  map <- c(old = "new")
  used <- new.env()
  x <- list(old = 1, keep = list(old = 2))
  y <- .rmbl_names_swap(x, map, used)
  expect_named(y, c("new", "keep"))
  expect_named(y$keep, "new")
  expect_identical(used$from, "old")
  m <- matrix(1:4, 2, dimnames = list(c("old", "b"), c("c", "old")))
  z <- .rmbl_names_swap(m, map)
  expect_identical(dimnames(z), list(c("new", "b"), c("c", "new")))
  expect_identical(.rmbl_names_swap(x, character()), x)
})
