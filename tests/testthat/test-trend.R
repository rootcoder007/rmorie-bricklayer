# SPDX-License-Identifier: AGPL-3.0-or-later

# Short-series trend: Mann-Kendall with Sen's slope, the step-change scan and
# the Poisson count trend.

test_that("trndtst() finds a monotone trend and its slope", {
  r <- trndtst(c(1, 3, 2, 5, 6, 8))
  expect_identical(r$n, 6L)
  expect_identical(r$S, 13)
  expect_match(r$method, "exact over all 720 orderings")
  expect_lt(r$p_value, 0.05)
  expect_gt(r$slope, 0)
  # past eight periods the normal approximation is used
  big <- trndtst(1:12 + rep(c(0, 0.5), 6))
  expect_match(big$method, "normal approximation")
  expect_warning(
    trndtst(1:12, exact = TRUE),
    "exact = TRUE is available up to n = 8"
  )
  # ties are held in the exact null
  expect_match(trndtst(c(1, 1, 2, 2, 3, 3))$method, "ties kept")
  # every value tied: p is 1
  expect_identical(trndtst(rep(2, 10))$p_value, 1)
})

test_that("trndtst() reads a data frame and refuses a bad series", {
  d <- data.frame(t = c(3, 1, 2, 4), v = c(30, 10, 20, 40))
  r <- trndtst(d, value = "v", prd = "t")
  expect_identical(r$S, 6)
  expect_error(trndtst(d), "`value` is required")
  expect_error(trndtst(d, value = "w"), "`value` column not found: w")
  expect_error(trndtst(d, value = "v", prd = "p"), "`prd` column not found")
  expect_error(trndtst(1:3, x = 1:2), "must be the same length")
  expect_error(trndtst(c(1, Inf, 3)), "must not contain infinite values")
  expect_error(trndtst(1:2), "at least three periods")
  expect_error(trndtst(1:4, x = c(1, 1, 2, 3)), "duplicated periods")
})

test_that("stepchg() finds the break and an exact or drawn p-value", {
  y <- c(1, 1, 1, 1, 5, 5, 5)
  r <- stepchg(y)
  expect_identical(r$index, 4L)
  expect_identical(r$breakafter, 4L)
  expect_identical(r$difference, 4)
  expect_match(r$method, "exact over all 5040 orderings")
  p <- stepchg(c(rep(1, 6), rep(4, 6)), nperm = 99L, seed = 3L)
  expect_match(p$method, "99 permutations")
  expect_identical(p$nperm, 99L)
  expect_identical(stepchg(c(rep(1, 6), rep(4, 6)), nperm = 99L, seed = 3L), p)
  expect_error(stepchg(1:3), "need at least 4 periods")
  expect_error(stepchg(1:4, x = c(1, 3, 2, 4)), "strictly increasing")
  expect_error(stepchg(1:4, x = letters[1:4]), "must be numbers or dates")
  expect_error(stepchg(c(1, Inf, 2, 3)), "must not contain infinite values")
  # a scale near the edge of double range is read in its own units
  expect_identical(stepchg(y * 1e200)$index, 4L)
})

test_that("cnttrnd() estimates a rate ratio per period", {
  r <- cnttrnd(c(10, 20, 40, 80))
  expect_s3_class(r, "rmbl_count_trend")
  expect_equal(r$rateratio, 2, tolerance = 1e-6)
  expect_lt(r$lower, 2)
  expect_gt(r$upper, 2)
  expect_false(r$overdispersed)
  expect_identical(r$method, "Poisson log-linear")
  expect_warning(assign("z", cnttrnd(c(0, 0, 5))), "no finite estimate")
  expect_identical(z$rateratio, Inf)
  expect_true(is.na(z$lower))
  expect_error(cnttrnd(c(1, 2)), "at least three periods")
  ci <- .ct_interval(log(2), 0.1, FALSE, 4L, 0.95)
  expect_equal(
    ci$lower,
    exp(log(2) - stats::qnorm(0.975) * 0.1),
    tolerance = 1e-12
  )
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

test_that("the trend tests print as boxes and keep their values", {
  tt <- trndtst(c(1, 3, 2, 5, 4, 6))
  expect_s3_class(tt, c("rmbl_trend_test", "list"))
  expect_identical(tt$S, 11)
  .o2_check(tt, "Trend test", c("Kendall tau", "Sen slope", "upward"))
  sc <- stepchg(c(1, 1, 1, 5, 5, 5), nperm = 99)
  expect_s3_class(sc, c("rmbl_step_change", "list"))
  expect_identical(sc$index, 3L)
  .o2_check(sc, "Step change", c("Break after", "from 1 to 5"))
  .o2_check(cnttrnd(c(5, 7, 9, 12, 15)), "Count trend",
    c("rate ratio per period", "rise"))
})

test_that("a short series notes its clamped slope interval", {
  r <- trndtst(c(2, 1, 4, 3, 5))
  expect_true(r$slopecicla)
  expect_match(box_text(r), "clamped to the range of the pairwise slopes",
    fixed = TRUE)
  flat <- list(tau = 0, p_value = 1, slope = 0)
  expect_match(.rmbl_trend_reading(flat)[1L], "means no direction",
    fixed = TRUE)
})
