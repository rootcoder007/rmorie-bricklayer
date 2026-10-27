# SPDX-License-Identifier: AGPL-3.0-or-later

# Period labels: fiscal-year names and labels that never move a number.

test_that("fylbl() names a fiscal year by its two calendar years", {
  expect_identical(fylbl(c(2023, 2024)), c("2022/23", "2023/24"))
  expect_identical(fylbl(2000, sep = "-", short = FALSE), "1999-2000")
  expect_identical(fylbl(c("2010", NA)), c("2009/10", NA))
  expect_identical(fylbl(NA_real_), NA_character_)
  expect_error(fylbl(list(2020)), "must be numeric or character years")
  expect_error(fylbl(0), "must be positive years")
  expect_error(fylbl(2024.5), "must be whole years")
  expect_null(.yoy_check_endyear(2024))
})

test_that("yoylbl() labels the periods and leaves the values alone", {
  d <- data.frame(year = 2021:2023, n = c(100, 120, 90))
  y <- yoy(d, value = "n", prd = "year")
  f <- yoylbl(y, function(p) fylbl(p))
  expect_identical(f$perlbl, c("2020/21", "2021/22", "2022/23"))
  expect_true(attr(f, "yoy")$perlbl)
  expect_identical(f$value, y$value)
  m <- yoylbl(y, c("2022" = "2022 (COVID)"))
  expect_identical(m$perlbl, c("2021", "2022 (COVID)", "2023"))
  u <- yoylbl(y, c("a", "b", "c"))
  expect_identical(u$perlbl, c("a", "b", "c"))
  expect_error(yoylbl(d, "a"), "must be an rmbl_yoy object")
  expect_error(yoylbl(y, c("a", "b")), "`labels` has 2 entries for 3")
  expect_error(yoylbl(y, function(p) "one"), "one label per row")
  expect_error(yoylbl(y, list(1)), "must be a function of the periods")
})

test_that("fylbl() checks `short` (C1)", {
  expect_error(
    fylbl(2023, short = "no"),
    "fylbl: `short` must be TRUE or FALSE"
  )
  expect_error(fylbl(2023, short = NA), "`short` must be TRUE or FALSE")
  expect_identical(fylbl(2023, short = FALSE), "2022/2023")
})
