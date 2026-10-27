# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("the 0.5.13 generics call the new functions with the new names", {
  d <- data.frame(n = c(5, 8, 3), pop = c(1000, 1200, 900))
  expect_identical(
    .rmbl_new_names(rate(d, count = "n", population = "pop")),
    rtcalc(d, count = "n", pop = "pop")
  )
  expect_identical(
    .rmbl_new_names(rate(10, population = 1000)),
    rtcalc(10, pop = 1000)
  )
  expect_identical(
    .rmbl_new_names(share(d, count = "n")),
    shrs(d, count = "n")
  )
  expect_identical(
    .rmbl_new_names(share(c(1, 2, 3))),
    .rmbl_new_names(share(c(1, 2, 3), conf_level = 0.95))
  )
})

test_that("the old generics refuse what their methods do not take", {
  expect_error(rate_change(1:3), "data frame")
  expect_error(yoy_summary(1), "yoy")
})

test_that("an old-named result prints, formats and summarises", {
  y <- yoy(
    data.frame(year = 2019:2022, n = c(10, 12, 9, 15)),
    value = "n",
    prd = "year"
  )
  s <- yoy_summary(y)
  expect_identical(.rmbl_new_names(s), yoysmry(y))
  expect_output(print(rate(10, population = 1000)))
  expect_type(format(rate(10, population = 1000)), "character")
})
