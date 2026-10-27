# SPDX-License-Identifier: AGPL-3.0-or-later

sa_yoy <- function() {
  seg <- data.frame(
    year = rep(2022:2023, each = 3),
    site = rep(c("A", "B", "C"), 2),
    n = c(30, 50, 80, 45, 52, 79),
    stringsAsFactors = FALSE
  )
  yoy(seg, value = "n", prd = "year", by = "site")
}

test_that("yoypv() gives the exact binomial p-value of each change", {
  y <- yoypv(sa_yoy())
  expect_s3_class(y, "rmbl_yoy")
  a <- y$p_value[!is.na(y$p_value) & y$value == 45]
  expect_equal(a, stats::binom.test(45, 75)$p.value, tolerance = 1e-12)
  expect_error(
    yoypv(data.frame(n = 1)),
    "`y` must come from yoy()",
    fixed = TRUE
  )
})

test_that("scanadj() adjusts the p-values and marks the significant rows", {
  x <- data.frame(
    test = c("a", "b", "c"),
    p_value = c(0.001, 0.02, 0.4),
    stringsAsFactors = FALSE
  )
  s <- scanadj(x)
  expect_equal(s$padj, stats::p.adjust(x$p_value, "BH"), tolerance = 1e-12)
  expect_identical(s$significant, c(TRUE, TRUE, FALSE))
  expect_identical(attr(s, "scanadj")$tests, 3L)
  h <- scanadj(x, meth = "holm", alpha = 0.01)
  expect_identical(attr(h, "scanadj")$method, "holm")
  expect_identical(h$significant, c(TRUE, FALSE, FALSE))
  y <- scanadj(sa_yoy())
  expect_true("padj" %in% names(y))
  m <- scanadj(data.frame(p_value = c(NA, 0.5)))
  expect_identical(m$padj, c(NA, 0.5))
})

test_that("scanadj() refuses tables it cannot adjust", {
  expect_error(scanadj(1), "`x` must be a data frame")
  expect_error(scanadj(data.frame(a = 1)), "has no `p_value` column")
  expect_error(
    scanadj(data.frame(p_value = c(0.2, 1.5, -1))),
    "row(s) 2, 3 hold",
    fixed = TRUE
  )
})

test_that("drftcal() estimates the false-alarm rate on identical data", {
  set.seed(1)
  d <- data.frame(a = stats::rnorm(80), b = sample(letters[1:3], 80, TRUE))
  cal <- drftcal(d, n = 3L, seed = 2L)
  expect_s3_class(cal, "rmbl_drift_calibration")
  expect_identical(cal$n, 3L)
  expect_identical(cal$columns$column, c("a", "b"))
  expect_true(all(cal$columns$falsealarmrate >= 0))
  expect_identical(cal$alphafam, 0.01 / 2)
  expect_identical(drftcal(d, n = 3L, seed = 2L), cal)
  expect_output(print(cal), "Identical re-fetches")
  expect_error(drftcal(d[1:3, ]), "at least four rows")
  expect_error(drftcal(d, n = 0L), "`n` must be a whole number of at least 1")
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

test_that("drftcal() prints as a box", {
  set.seed(5)
  d <- data.frame(a = stats::rnorm(40), b = stats::rnorm(40))
  .o2_check(drftcal(d, n = 3), "Drift screen calibration",
    c("Identical re-fetches", "Per-screen alpha"))
})
