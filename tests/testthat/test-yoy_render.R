# SPDX-License-Identifier: AGPL-3.0-or-later
# Year-over-year tables rendered as an HTML page and as PDF pages.

yoy_demo <- function() {
  d <- data.frame(
    year = rep(2019:2023, each = 2),
    region = rep(c("North", "South"), 5),
    n = c(31, 402, 28, 377, 12, 190, 19, 268, 24, 331),
    stringsAsFactors = FALSE
  )
  yoy(d, value = "n", prd = "year", by = "region", dir = "lower")
}

test_that("yoyhtml() writes a page with a row per change and the notes", {
  y <- yoy_demo()
  h <- withr::local_tempfile(fileext = ".html")
  expect_identical(yoyhtml(y, h, title = "Placements <by> region"), h)
  txt <- paste(readLines(h, encoding = "UTF-8"), collapse = "\n")
  expect_match(txt, "<!DOCTYPE html>", fixed = TRUE)
  expect_match(txt, "<title>Placements &lt;by&gt; region</title>", fixed = TRUE)
  expect_match(txt, "--bad:", fixed = TRUE)
  expect_match(txt, "<th>region</th>", fixed = TRUE)
  per <- gregexpr("<td class=\"per\">", txt, fixed = TRUE)[[1L]]
  expect_length(per, 10L)
  yoyhtml(y, h, pal = "safe", bars = FALSE, intv = FALSE, notes = "a note")
  txt <- paste(readLines(h, encoding = "UTF-8"), collapse = "\n")
  expect_match(txt, "<li>a note</li>", fixed = TRUE)
  expect_error(yoyhtml(data.frame(), h), "must be an rmbl_yoy object")
  expect_error(yoyhtml(y, NULL), "file path or a connection")
  expect_error(yoyhtml(y, h, notes = 1), "yoyhtml: `notes` must be text")
})

test_that("yoypdf() writes the pages and checks its sizes", {
  y <- yoy_demo()
  p <- withr::local_tempfile(fileext = ".pdf")
  expect_identical(yoypdf(y, p, notes = "a note"), p)
  expect_true(file.exists(p))
  expect_identical(rawToChar(readBin(p, "raw", 4L)), "%PDF")
  expect_error(yoypdf(y, p, width = 1), "width")
  expect_error(yoypdf(y, p, notes = NA_character_), "yoypdf: `notes` must be")
  expect_error(yoypdf(list(), p), "must be an rmbl_yoy object")
})

test_that("the PDF pages hold the rows that fit, notes after them", {
  plan <- .yoy_pdf_plan(100L, character(), 8.5)
  expect_identical(sum(lengths(plan$pages)), 100L)
  expect_gt(length(plan$pages), 1L)
  expect_false(plan$notes_own_pages)
  many <- .yoy_pdf_plan(.yoy_rows_per_page(8.5), rep("n", 50), 8.5)
  expect_true(many$notes_own_pages)
  expect_identical(
    .yoy_head_cells(list(by = "g", period = "p", value = "v"), TRUE, TRUE),
    c("g", "p", "v", "previous", "change", "points", "interval")
  )
})

test_that("yoyhtml() and yoypdf() name `pal` and check their flags (D2, D6)", {
  y <- yoy(data.frame(year = 2019:2021, n = c(5, 7, 9)), "n", "year")
  f <- tempfile(fileext = ".html")
  p <- tempfile(fileext = ".pdf")
  on.exit(unlink(c(f, p)), add = TRUE)
  expect_error(yoyhtml(y, f, pal = "rainbow"), "yoyhtml: `pal` must be one of")
  expect_error(yoypdf(y, p, pal = "rainbow"), "yoypdf: `pal` must be one of")
  expect_error(yoyhtml(y, f, bars = "yes"), "`bars` must be TRUE or FALSE")
  expect_error(yoyhtml(y, f, intv = NA), "`intv` must be TRUE or FALSE")
  expect_error(yoypdf(y, p, intv = 1), "`intv` must be TRUE or FALSE")
  expect_identical(yoyhtml(y, f, pal = "safe", bars = FALSE), f)
})
