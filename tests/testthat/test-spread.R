# spread(): the denominator the source of the data calls for

test_that(
  paste0(
    "sprd() applies Bessel's correction to a sample, none to a census, and ",
    "the FPC"
  ),
  {
    x <- c(12, 15, 9, 20, 14)
    s <- sprd(x)
    expect_identical(s$design, "sample")
    expect_identical(s$variance, stats::var(x))
    expect_identical(s$sd, stats::sd(x))
    expect_identical(s$semean, stats::sd(x) / sqrt(5))
    ce <- sprd(x, des = "census")
    expect_identical(ce$variance, mean((x - mean(x))^2))
    expect_identical(ce$semean, 0)
    expect_identical(sprd(x, N = 5)$design, "census")
    f <- sprd(x, N = 40)
    expect_identical(f$design, "finite")
    expect_identical(f$variance, stats::var(x))
    expect_identical(f$semean, sqrt((1 - 5 / 40) * stats::var(x) / 5))
    expect_output(print(f), "finite-population correction 1 - n/N = 0.875")
    expect_output(print(sprd(x, N = 1000)), "negligible")
  }
)

test_that("sprd() with frequency and reliability weights", {
  fw <- sprd(c(1, 2, 3), w = c(10, 5, 1))
  expect_identical(fw$variance, stats::var(rep(1:3, c(10, 5, 1))))
  expect_identical(fw$mean, mean(rep(1:3, c(10, 5, 1))))
  rw <- sprd(c(1, 2, 3, 4), w = c(1, 1, 1, 1), wtype = "reliability")
  expect_identical(rw$variance, stats::var(1:4))
  rw2 <- sprd(c(1, 2, 3, 4), w = c(1, 2, 1, 2), wtype = "reliability")
  m <- sum(c(1, 2, 1, 2) * 1:4) / 6
  expect_identical(
    rw2$variance,
    sum(c(1, 2, 1, 2) * (1:4 - m)^2) / (6 - 10 / 6)
  )
  expect_identical(rw2$semean, sqrt(sum(c(1, 2, 1, 2)^2 * (1:4 - m)^2)) / 6)
})

test_that("sprd() refuses what it cannot compute", {
  expect_error(sprd(c(1, NA)), "missing values")
  expect_identical(sprd(c(1, NA, 3), narm = TRUE)$mean, 2)
  expect_error(sprd(1:3, des = "finite"), "needs `N`")
  expect_error(sprd(1:3, N = 2), "smaller than")
  expect_error(sprd(1:3, w = 1:2), "one per value")
  expect_true(is.na(sprd(5)$variance))
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

test_that("sprd() prints as a box with its rule", {
  .o2_check(sprd(c(1, 2, 3, 10)), "Mean and spread",
    c("Standard error of the mean", "Rule:", "16.6667"))
})
