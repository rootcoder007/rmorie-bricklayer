# SPDX-License-Identifier: AGPL-3.0-or-later

test_that(".rmbl_r_seed() takes whole numbers in range and refuses the rest", {
  expect_identical(.rmbl_r_seed(42), 42L)
  expect_identical(.rmbl_r_seed(-5L), -5L)
  expect_identical(.rmbl_r_seed(2^40), 2^40)
  expect_error(.rmbl_r_seed("1"), "a numeric value")
  expect_error(.rmbl_r_seed(1.5), "single whole number")
  expect_error(.rmbl_r_seed(c(1, 2)), "single whole number")
  expect_error(.rmbl_r_seed(NA_real_), "single whole number")
  expect_error(.rmbl_r_seed(2^53), "single whole number")
})

test_that(".rmbl_local_seed() seeds the caller only and restores the stream", {
  set.seed(7)
  before <- get(".Random.seed", envir = globalenv())
  draw <- function(seed) {
    .rmbl_local_seed(seed)
    stats::runif(3)
  }
  a <- draw(11)
  b <- draw(11)
  expect_identical(a, b)
  expect_identical(get(".Random.seed", envir = globalenv()), before)
  expect_null(.rmbl_local_seed(NULL))
})

test_that("a seed past 2^31 - 1 gives a reproducible stream of its own", {
  draw <- function(seed) {
    .rmbl_local_seed(seed)
    stats::runif(2)
  }
  expect_identical(draw(2^31 + 5), draw(2^31 + 5))
  expect_false(identical(draw(2^31 + 5), draw(2^31 + 6)))
})

test_that(".rmbl_restore_seed() puts back a state or removes one", {
  set.seed(3)
  old <- get(".Random.seed", envir = globalenv())
  stats::runif(1)
  .rmbl_restore_seed(old)
  expect_identical(get(".Random.seed", envir = globalenv()), old)
  .rmbl_restore_seed(NULL)
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  .rmbl_restore_seed(old)
})
