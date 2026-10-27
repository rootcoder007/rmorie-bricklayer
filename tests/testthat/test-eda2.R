# SPDX-License-Identifier: AGPL-3.0-or-later
# Mahalanobis outliers, runs of missing values and the missingness map.

test_that("mahaoutl() puts a planted outlier first", {
  set.seed(2)
  df <- data.frame(a = stats::rnorm(60), b = stats::rnorm(60))
  df[1L, ] <- c(9, -9)
  for (robust in c(TRUE, FALSE)) {
    r <- mahaoutl(df, robust = robust)
    expect_s3_class(r, "bricklayer_outliers")
    expect_identical(r$row[[1L]], 1L)
    expect_true(r$outlier[[1L]])
    expect_identical(nrow(r), 60L)
    expect_identical(attr(r, "robust"), robust)
  }
})

test_that("mahaoutl() keeps incomplete rows last, unscored", {
  set.seed(3)
  df <- data.frame(a = stats::rnorm(30), b = stats::rnorm(30))
  df$a[5L] <- NA
  r <- mahaoutl(df)
  expect_identical(nrow(r), 30L)
  expect_identical(r$row[[30L]], 5L)
  expect_true(is.na(r$distance[[30L]]))
  expect_true(is.na(r$outlier[[30L]]))
})

test_that("mahaoutl() refuses what has no distance", {
  set.seed(4)
  df <- data.frame(a = stats::rnorm(20), b = stats::rnorm(20))
  expect_error(mahaoutl(list(1)), "must be a data frame")
  expect_error(mahaoutl(data.frame(g = letters)), "no numeric columns")
  expect_error(mahaoutl(df, alpha = 2), "strictly inside")
  expect_error(mahaoutl(df[1:2, ]), "more complete rows than columns")
  dup <- df
  dup$c <- dup$a
  expect_error(mahaoutl(dup), "collinear")
})

test_that("missruns() finds runs of missing values", {
  d <- data.frame(x = c(1, NA, NA, 4, NA), y = c(NA, NA, NA, 1, 2))
  r <- missruns(d)
  expect_s3_class(r, "bricklayer_runs")
  expect_identical(r$column, c("y", "x"))
  expect_identical(r$start, c(1L, 2L))
  expect_identical(r$length, c(3L, 2L))
  expect_identical(nrow(missruns(d, minrun = 4L)), 0L)
  expect_identical(nrow(missruns(data.frame(z = 1:3))), 0L)
  expect_error(missruns(1:3), "must be a data frame")
  expect_error(missruns(d, minrun = 0), "positive integer")
})

test_that("missgrid() draws one row per bin", {
  d <- data.frame(x = c(1, NA, NA, 4), y = c(NA, 2, 3, 4))
  out <- utils::capture.output({
    lines <- missgrid(d, height = 2L)
  })
  expect_type(lines, "character")
  expect_length(grep("^ +[0-9]+ ", lines), 2L)
  expect_true(any(grepl("legend", lines, fixed = TRUE)))
  expect_gt(length(out), 0L)
  expect_error(missgrid(1:3), "must be a data frame")
  expect_error(missgrid(d, height = 0), "positive integer")
})

test_that("mahaoutl() refuses a `robust` that is not TRUE or FALSE", {
  d <- data.frame(a = c(1, 3, 2, 5, 4, 6), b = c(2, 1, 4, 3, 6, 5))
  expect_error(mahaoutl(d, robust = "yes"), "`robust` must be TRUE or FALSE")
  expect_error(mahaoutl(d, robust = NA), "`robust` must be TRUE or FALSE")
  expect_error(mahaoutl(d, robust = c(TRUE, FALSE)), "`robust` must be TRUE")
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

test_that("outliers and missing runs print as boxes", {
  set.seed(7)
  d <- data.frame(a = c(stats::rnorm(50), 9), b = stats::rnorm(51))
  out <- .o2_check(mahaoutl(d), "Mahalanobis outliers (robust)",
    c("of 51 rows beyond alpha", "more rows"))
  expect_true(any(grepl("^\\|    51 ", out)))
  .o2_check(missruns(data.frame(a = c(1, NA, NA, NA, 2))),
    "Runs of consecutive missing values", c("Longest run", "3"))
  .o2_check(missruns(data.frame(a = 1:3)),
    "Runs of consecutive missing values", "(none)")
})

# ---- restored logpvalue and result-driven reading ----------------------------

test_that("mahaoutl()'s box shows logpvalue and reads the outliers found", {
  set.seed(1)
  df <- data.frame(height = stats::rnorm(200, 170, 10))
  df$weight <- df$height * 0.5 + stats::rnorm(200, 0, 5)
  clean <- gsub("\\s+", " ", paste(format(mahaoutl(df)), collapse = " "))
  expect_match(clean, "logpvalue", fixed = TRUE)
  expect_match(clean, "No row lies beyond alpha = 0.001; the farthest",
    fixed = TRUE)
  df[1, ] <- list(height = 155, weight = 100)
  out <- gsub("\\s+", " ", paste(format(mahaoutl(df)), collapse = " "))
  expect_match(out, "1 of 200 rows lie beyond alpha = 0.001: row 1",
    fixed = TRUE)
})
