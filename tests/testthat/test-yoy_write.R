# SPDX-License-Identifier: AGPL-3.0-or-later
# Year-over-year tables written as delimited text, JSON and Markdown.

yoy_small <- function() {
  d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
  yoy(d, value = "n", prd = "year")
}

test_that("yoymd() writes an aligned Markdown table", {
  y <- yoy_small()
  md <- yoymd(y, NULL)
  lines <- strsplit(md, "\n", fixed = TRUE)[[1L]]
  expect_match(lines[[1L]], "^\\| year +\\| +n \\| previous")
  expect_match(lines[[2L]], "^\\| -{3,} \\| -+: \\|")
  expect_length(unique(nchar(lines[1:7], type = "width")), 1L)
  plain <- yoymd(y, NULL, align = FALSE)
  expect_match(plain, "| --- | --: |", fixed = TRUE)
  f <- withr::local_tempfile(fileext = ".md")
  expect_identical(yoymd(y, f), f)
  expect_identical(readLines(f)[[1L]], lines[[1L]])
  expect_error(yoymd(data.frame(), NULL), "must be an rmbl_yoy object")
})

test_that("the rule under the header marks right-aligned columns", {
  expect_identical(.yoy_md_rule(c(3L, 5L), c(FALSE, TRUE)), "| --- | ----: |")
  expect_identical(.yoy_md_rule(c(0L, 0L), c(TRUE, FALSE)), "| --: | --- |")
})

test_that("delimited text quotes what needs it and keeps its rows", {
  y <- yoy_small()
  csv <- yoycsv(y, NULL)
  rows <- utils::read.csv(text = csv, comment.char = "#")
  expect_identical(nrow(rows), 5L)
  expect_true("pctchg" %in% names(rows))
  tsv <- yoytsv(y, NULL, meta = FALSE)
  expect_false(grepl("#", tsv, fixed = TRUE))
  expect_match(tsv, "year\tvalue", fixed = TRUE)
  expect_error(yoycsv(data.frame(), NULL), "rmbl_yoy")
})

test_that("the writers check their flags and digits (D6, D7)", {
  y <- yoy(data.frame(year = 2019:2021, n = c(5, 7, 9)), "n", "year")
  expect_error(yoycsv(y, NULL, meta = "TRUE"), "yoycsv: `meta` must be TRUE")
  expect_error(yoytsv(y, NULL, meta = NA), "yoytsv: `meta` must be TRUE")
  expect_error(yoyjs(y, NULL, pretty = "no"), "yoyjs: `pretty` must be TRUE")
  expect_error(yoymd(y, NULL, align = 2), "yoymd: `align` must be TRUE")
  for (w in list(yoycsv, yoytsv, yoyjs)) {
    expect_error(w(y, NULL, digits = -1), "one whole number from 0 to 15")
    expect_error(w(y, NULL, digits = c(1, 2)), "one whole number from 0 to 15")
  }
  expect_false(grepl("^#", yoycsv(y, NULL, meta = FALSE)))
  expect_match(yoycsv(y, NULL, digits = 1), "40")
})
