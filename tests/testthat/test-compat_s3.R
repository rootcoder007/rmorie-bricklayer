# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("1.1.1 no longer exports rate(), rate_change() or share()", {
  ex <- getNamespaceExports("rmoriebricklayer")
  expect_false(any(c("rate", "rate_change", "share") %in% ex))
  expect_true(all(c("rtcalc", "ratechg", "shrs", "yoy_summary") %in% ex))
})

test_that("the old generics refuse what their methods do not take", {
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
  expect_output(print(s))
  expect_type(format(s), "character")
})
