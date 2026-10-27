# SPDX-License-Identifier: AGPL-3.0-or-later

# The printed change table and its summary.

test_that("print() shows each period's change and the footer", {
  d <- data.frame(year = 2021:2023, n = c(100, 120, 90))
  y <- yoy(d, value = "n", prd = "year")
  out <- capture.output(print(y, color = FALSE))
  expect_true(any(grepl("change %", out, fixed = TRUE)))
  expect_true(any(grepl("2023", out, fixed = TRUE)))
  expect_true(any(grepl("-25", out, fixed = TRUE)))
  expect_identical(print(y, color = FALSE), y)
  more <- capture.output(print(y, color = FALSE, n = 1))
  expect_true(any(grepl("... 2 more rows", more, fixed = TRUE)))
  cols <- .yoy_print_cols(as.data.frame(y), attr(y, "yoy"), "pctchg", 1L, FALSE)
  expect_identical(cols$value, c("100", "120", "90"))
  expect_output(print(y[0, ]), "no periods")
})

test_that("yoysmry() gives the span, total and compound change", {
  d <- data.frame(year = 2021:2023, n = c(100, 120, 90))
  s <- yoysmry(yoy(d, value = "n", prd = "year"))
  expect_identical(s$first, 100)
  expect_identical(s$last, 90)
  expect_equal(s$totalpct, -10, tolerance = 1e-12)
  expect_equal(s$cagrpct, 100 * (0.9^(1 / 2) - 1), tolerance = 1e-12)
  expect_identical(c(s$up, s$down, s$flat), c(1L, 1L, 0L))
  g <- data.frame(
    year = rep(2021:2022, 2),
    g = rep(c("a", "b"), each = 2),
    n = c(10, 20, 30, 15),
    stringsAsFactors = FALSE
  )
  sg <- yoysmry(yoy(g, value = "n", prd = "year", by = "g"))
  expect_identical(sg$g, c("a", "b"))
  expect_identical(sg$totalpct, c(100, -50))
  expect_type(yoypals(), "character")
  expect_true("diverging" %in% yoypals())
})

test_that("yoysmry() spans text periods in the order yoy() reads (C18)", {
  d <- data.frame(
    p = c("Mar 2021", "Jan 2021", "Feb 2021"),
    n = c(30, 10, 20),
    stringsAsFactors = FALSE
  )
  s <- yoysmry(yoy(d, "n", "p"))
  expect_identical(c(s$from, s$to), c("Jan 2021", "Mar 2021"))
  expect_equal(s$totalpct, 200, tolerance = 1e-12)
  ws <- data.frame(
    s = c("fall", "spring"),
    n = c(4, 1),
    stringsAsFactors = FALSE
  )
  y <- yoy(ws, "n", "s", prdord = c("spring", "summer", "fall"))
  expect_identical(yoysmry(y)$from, "spring")
})

test_that("yoysmry() gives NA, with the reason, for periods with no order", {
  d <- data.frame(p = c("b", "a"), n = c(1, 2), stringsAsFactors = FALSE)
  y <- suppressWarnings(yoy(d, "n", "p"))
  expect_warning(yoysmry(y), "yoysmry: the periods have no order")
  s <- suppressWarnings(yoysmry(y))
  expect_true(all(is.na(s[c("from", "to", "first", "last")])))
  expect_true(is.na(s$totalpct))
  expect_true(is.na(s$cagrpct))
  expect_identical(s$periods, 2L)
  # by groups: one warning, not one per group
  g <- data.frame(
    p = c("b", "a", "b", "a"),
    k = c("x", "x", "y", "y"),
    n = 1:4,
    stringsAsFactors = FALSE
  )
  yg <- suppressWarnings(yoy(g, "n", "p", by = "k"))
  w <- testthat::capture_warnings(yoysmry(yg))
  sg <- suppressWarnings(yoysmry(yg))
  expect_length(w, 1L)
  expect_true(all(is.na(sg$totalpct)))
  # the writers say nothing more: yoy() has warned already
  expect_silent(yoyjs(y, NULL))
})

# ---- printed boxes -----------------------------------------------------------

# format() gives the plain lines of one titled block; print() draws them as a
# box that fits an 80-column console, ASCII where the console takes no Unicode,
# and returns the object invisibly.
expect_box <- function(x, title, has = character()) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  withr::local_options(rmoriebricklayer.width = 80, rmoriebricklayer.numcol = 1)
  txt <- format(x)
  expect_type(txt, "character")
  expect_true(grepl(title, txt[1L], fixed = TRUE), info = txt[1L])
  flat <- paste(txt, collapse = "\n")
  for (h in has) {
    expect_true(grepl(h, flat, fixed = TRUE), info = h)
  }
  out <- utils::capture.output(print(x))
  expect_output(expect_invisible(print(x)), "+-- ", fixed = TRUE)
  expect_identical(withr::with_output_sink(nullfile(), print(x)), x)
  expect_match(out[1L], "^\\+-- ")
  expect_match(out[length(out)], "^\\+-+\\+$")
  expect_true(all(nchar(out) == nchar(out[1L])))
  expect_true(all(nchar(out) <= 79L))
  invisible(out)
}

test_that("a change table prints as a box with its settings", {
  d <- data.frame(year = 2021:2023, n = c(100, 120, 90))
  y <- yoy(d, value = "n", prd = "year", dir = "lower")
  out <- expect_box(
    y,
    "Change in n by year",
    c("Rows", "lower values", "change %", "lag 1 period", "units: count")
  )
  expect_true(any(grepl("-25", out, fixed = TRUE)))
  # colour goes on the rows only when asked for, and the box still closes
  col <- utils::capture.output(print(y, color = TRUE))
  expect_true(any(grepl("\033[38;2;", col, fixed = TRUE)))
  expect_false(any(grepl("\033", format(y), fixed = TRUE)))
  expect_true(any(grepl("\033", format(y, color = TRUE), fixed = TRUE)))
  # an empty table is one line, and a subset a plain table
  expect_identical(format(y[0, ]), "<rmbl_yoy: no periods>")
  expect_output(print(y[, c("year", "value")]), "value")
  g <- yoy(
    data.frame(
      year = rep(2020:2021, 2),
      g = rep(c("a", "b"), each = 2),
      n = 1:4,
      stringsAsFactors = FALSE
    ),
    value = "n",
    prd = "year",
    by = "g",
    minbase = 0
  )
  expect_box(g, "Change in n by year", "2 (by g)")
  expect_identical(
    .yoy_footer(attr(y, "yoy")),
    paste(.yoy_footer_bits(attr(y, "yoy")), collapse = .yg(" \u00b7 "))
  )
})

test_that("yoysmry() results print as a box", {
  y <- yoy(data.frame(year = 2019:2023, n = c(10, 12, 9, 15, 16)), "n", "year")
  s <- yoysmry(y)
  expect_s3_class(s, c("rmbl_yoy_summary", "data.frame"))
  out <- expect_box2(s, "Year-over-year summary", c("2019", "cagrpct"))
  expect_false(any(grepl("2,019", out, fixed = TRUE)))
  s$from <- s$to <- NA
  expect_box2(s, "Year-over-year summary", "have no order")
  expect_box2(s["up"], "Year-over-year summary", "plain table")
})
