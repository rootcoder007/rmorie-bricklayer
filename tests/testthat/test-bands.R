# SPDX-License-Identifier: AGPL-3.0-or-later

# Banded labels: parsing, placement inside each band, the open band's cap
# and the expansion back to one value per unit.

test_that("prsbands() reads closed, open and unparseable labels", {
  b <- prsbands(c("1", "2 to 5", "1,000 to 2,499", "50+", "under 18", "?"))
  expect_identical(b$lower, c(1, 2, 1000, 50, NA, NA))
  expect_identical(b$upper, c(1, 5, 2499, NA, 17, NA))
  expect_identical(b$openup, c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE))
  expect_identical(b$openlo, c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE))
  expect_error(prsbands(1:3), "must be character band labels")
})

test_that("bandvals() places each band by the rule asked for", {
  b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
  # "Greater than 10" is 11 to 22 on an integer scale
  expect_identical(bandvals(b)$value, c(1, 3.5, 8, 16.5))
  expect_identical(bandvals(b, rule = "lower")$value, c(1, 2, 6, 11))
  expect_identical(
    bandvals(b, rule = "upper", openupcap = 40)$value,
    c(1, 5, 10, 40)
  )
  expect_equal(
    bandvals(b, rule = "geometric", openupcap = 40)$value,
    c(1, sqrt(10), sqrt(60), sqrt(11 * 40)),
    tolerance = 1e-12
  )
  expect_identical(bandvals(b)$assumed, c(FALSE, FALSE, FALSE, TRUE))
  # a band touching zero falls back to the midpoint under the geometric rule
  z <- bandvals(c("0 to 4", "5 to 9"), rule = "geometric")
  expect_identical(z$value[1], 2)
})

test_that("bandvals() fills an open bottom band from the floor", {
  v <- bandvals(c("under 5", "5 to 9", "10+"), openloflr = 1)
  # "under 5" is 1 to 4 here
  expect_identical(v$value, c(2.5, 7, 15))
  expect_identical(bandvals(c("under 5", "5 to 9"))$value[1], 2)
  expect_error(
    bandvals(c("under 5", "5 to 9"), openloflr = 6),
    "lies above the band's own upper bound"
  )
})

test_that("bandvals() refuses a bad cap, factor or table", {
  b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
  expect_error(bandvals(b, openupcap = 5), "lies below the band's own lower")
  expect_error(bandvals(b, openupfac = 0), "must be one positive number")
  expect_error(
    bandvals(data.frame(a = 1)),
    "must come from prsbands"
  )
})

test_that("bandsens() reports how far a statistic moves with the cap", {
  b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
  counts <- c(1200, 430, 110, 38)
  s <- bandsens(b, counts, stat = mean, caps = c(20, 12, 50, 20))
  expect_s3_class(s, "rmbl_band_sensitivity")
  expect_identical(s$cap, c(12, 20, 50))
  per <- function(cap) mean(rep(bandvals(b, openupcap = cap)$value, counts))
  expect_equal(s$value, vapply(s$cap, per, 0), tolerance = 1e-12)
  expect_equal(
    attr(s, "span"),
    max(s$value) - min(s$value),
    tolerance = 1e-12
  )
  expect_identical(attr(s, "base"), 11)
  # the default sweep: twelve caps from 1.05 to 20 times the open band's base
  d <- bandsens(b, counts)
  expect_length(d$cap, 12L)
  expect_equal(min(d$cap), 1.05 * 11, tolerance = 1e-12)
  expect_equal(max(d$cap), 20 * 11, tolerance = 1e-12)
  # a statistic that does not return one number gives NA
  expect_true(all(is.na(bandsens(b, counts, stat = range)$value)))
  expect_output(print(s), "Sensitivity to the open top band")
})

test_that("bandsens() refuses what it cannot vary", {
  expect_error(bandsens(c("1", "2 to 5"), c(10, 4)), "no open upper band")
  expect_error(
    bandsens(c("1", "2+"), c(10, 4, 1)),
    "`cnts` has 3 entries for 2 bands"
  )
  expect_error(
    bandsens(c("1", "2+"), c(10, 4), stat = "mean"),
    "must be a function"
  )
})

test_that("expbands() repeats each value by its count", {
  x <- expbands(c("1", "2 to 5", "Greater than 5"), c(2, 1, 1), openupcap = 9)
  expect_identical(x, c(1, 1, 3.5, 7.5))
  expect_error(
    expbands(c("1", "not stated"), c(3, 2)),
    "could not be placed: 'not stated'"
  )
  expect_warning(
    assign("y", expbands(c("1", "not stated"), c(3, 2), drpunp = TRUE)),
    "2 unit\\(s\\) in 1 band\\(s\\)"
  )
  expect_identical(y, c(1, 1, 1))
  expect_error(expbands(c("1", "2"), c(1, -1)), "must be non-negative")
  expect_error(expbands(c("1", "2"), 1), "`cnts` has 1 entries for 2 bands")
})

test_that("prsbands() flags must be TRUE or FALSE", {
  # clsup = "TRUE" parsed as FALSE: the opposite of what was asked
  expect_error(prsbands("50+", clsup = "TRUE"), "`clsup` must be TRUE or FALSE")
  expect_error(prsbands("50+", clsup = NA), "`clsup` must be TRUE or FALSE")
  expect_error(prsbands("over 15", intsca = 1), "`intsca` must be TRUE or")
  expect_identical(prsbands("50+", clsup = FALSE)$lower, 51)
})

test_that("the band functions name `bands` for labels that are not text", {
  expect_error(
    expbands(1:3, c(1, 2, 3)),
    "^expbands: `bands` must be character band labels"
  )
  expect_error(bandsens(1:3, c(1, 2, 3)), "`bands` must be character band")
  expect_error(bandvals(1:3), "`bands` must be character band labels")
  expect_error(prsbands(1:3), "^prsbands: `x` must be character band labels")
})

test_that("bandsens() refuses missing, infinite or empty caps", {
  b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
  cn <- c(1200, 430, 110, 38)
  expect_error(bandsens(b, cn, caps = NA), "`caps` must be one or more finite")
  expect_error(bandsens(b, cn, caps = c(20, NA)), "with no missing value")
  expect_error(bandsens(b, cn, caps = numeric(0)), "`caps` must be one or more")
  expect_error(bandsens(b, cn, caps = Inf), "`caps` must be one or more finite")
  expect_identical(nrow(bandsens(b, cn, caps = c(20, 12))), 2L)
})

# ---- boxed printouts ---------------------------------------------------------

# print() of a result in an 80-column ASCII console: the lines, whether the
# value was visible, and the value.
.o2_box <- function(x, ...) {
  withr::local_options(rmoriebricklayer.width = 80, rmoriebricklayer.numcol = 1)
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  out <- utils::capture.output({
    r <- withVisible(print(x, ...))
  })
  list(out = out, vis = r$visible, value = r$value)
}

# The checks every boxed printout passes: an ASCII box under its title, no
# line past the console, print() returning its argument invisibly, format()
# giving character lines that hold the facts.
.o2_check <- function(x, title, facts = character(0)) {
  b <- .o2_box(x)
  testthat::expect_false(b$vis)
  testthat::expect_identical(b$value, x)
  testthat::expect_true(startsWith(b$out[1L], paste0("+-- ", title, " -")))
  testthat::expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  testthat::expect_true(all(nchar(b$out) <= 80L))
  txt <- format(x)
  testthat::expect_type(txt, "character")
  # the text with the box and the wrapping taken out, for phrases
  flat <- gsub("[| ]+", " ", paste(b$out, collapse = " "))
  for (f in facts) {
    testthat::expect_true(grepl(f, flat, fixed = TRUE), info = f)
  }
  invisible(b$out)
}

test_that("bandsens() prints as a box with its caution", {
  s <- bandsens(c("0-9", "10-19", "20+"), c(10, 5, 2))
  .o2_check(s, "Sensitivity to the open top band's assumed cap",
    c("Caps tried", "Report the range"))
})

test_that("a subset of a band sensitivity prints as a plain table", {
  expect_df_fallback("rmbl_band_sensitivity",
    "Sensitivity to the open top band")
})
