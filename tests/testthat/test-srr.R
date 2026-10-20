# Tests written for the rOpenSci statistical standards; each block names the standards it meets.

#' @srrstats {G5.6b} plndid() recovers polex()'s built-in effect of -3 to within 0.5 under six seeds.
test_that("plndid() recovers the built-in effect under several seeds", {
  for (s in c(1, 2, 3, 4, 5, 20240101)) {
    est <- plndid(polex(s), "district", "month", "crmrate", "reformed")$estimate
    expect_lt(abs(est + 3), 0.5)
  }
})

#' @srrstats {G5.9} Noise susceptibility is tested for ginicoef(), trndtst() and svyest() (G5.9a) and cbootmean()
#'   (G5.9b).
#' @srrstats {G5.9a} Relative noise of .Machine$double.eps leaves ginicoef(), the trndtst() slope and p-value, and
#'   the svyest() estimate and SE unchanged to 1e-10.
test_that("trivial noise does not move the estimates", {
  eps <- .Machine$double.eps
  set.seed(3)
  g <- stats::rexp(200)
  expect_equal(ginicoef(g * (1 + eps * stats::runif(200, -1, 1))), ginicoef(g), tolerance = 1e-10)
  y <- c(402, 377, 190, 268, 331, 420, 455)
  a <- trndtst(y)
  b <- trndtst(y * (1 + eps * rep_len(c(1, -1), 7)))
  expect_equal(b$slope, a$slope, tolerance = 1e-10)
  expect_equal(b$p_value, a$p_value, tolerance = 1e-10)
  d <- data.frame(s = rep(c("a", "b"), each = 10), w = rep(c(2, 3), each = 10), y = (1:20) / 3)
  des <- svydes(d, w = "w", strata = "s")
  d2 <- d
  d2$y <- d$y * (1 + eps * rep_len(c(1, -1), 20))
  e1 <- svyest(des, d, "y")
  e2 <- svyest(des, d2, "y")
  expect_equal(e2$estimate, e1$estimate, tolerance = 1e-10)
  expect_equal(e2$se, e1$se, tolerance = 1e-10)
})

#' @srrstats {G5.9b} cbootmean() under five seeds gives replicate means within 0.01 of the sample mean and SEs
#'   within 5% of the formula SE.
test_that("bootstrap results agree across seeds within tolerance", {
  set.seed(7)
  x <- stats::rnorm(60, mean = 5)
  se <- stats::sd(x) / sqrt(length(x))
  for (s in 11:15) {
    b <- cbootmean(x, B = 3000, seed = s)
    expect_equal(mean(b), mean(x), tolerance = 0.01 / mean(x))
    expect_equal(stats::sd(b), se, tolerance = 0.05)
  }
})

#' @srrstats {EA6.0d} The yoy(), rtcalc(), cpsdrft()$columns and profcols() frames are checked column by column for
#'   their class.
test_that("the main result frames have the documented column classes", {
  y <- yoy(data.frame(year = 2019:2023, n = c(10, 12, 9, 15, 20)), "n", "year")
  expect_identical(vapply(y, function(z) class(z)[1L], ""),
                   c(year = "integer", value = "numeric", previous = "numeric", change = "numeric",
                     pctchg = "numeric", flag = "character", pctlo = "numeric", pctup = "numeric",
                     verdict = "character"))
  r <- rtcalc(data.frame(g = c("a", "b"), k = c(5, 9), pop = c(1000, 2000)), "k", "pop", by = "g")
  expect_identical(vapply(r, function(z) class(z)[1L], ""),
                   c(g = "character", count = "numeric", population = "numeric", rate = "numeric",
                     lower = "numeric", upper = "numeric", flag = "character"))
  set.seed(1)
  a <- data.frame(u = stats::rnorm(50), v = stats::runif(50))
  cd <- cpsdrft(a, transform(a, u = u + 1))
  expect_identical(vapply(cd$columns, function(z) class(z)[1L], ""),
                   c(column = "character", type = "character", statistic = "numeric", p_value = "numeric",
                     psi = "numeric", jsdiv = "numeric", unseen_share = "numeric", drifted = "logical",
                     note = "character"))
  pc <- profcols(a)
  cls <- vapply(pc, function(z) class(z)[1L], "")
  expect_identical(unname(cls[c("column", "type", "hist", "top")]), rep("character", 4L))
  expect_identical(unname(cls[c("n", "n_missing", "n_distinct", "nzero", "nneg", "ninf", "n_outliers")]),
                   rep("integer", 7L))
  expect_true(all(cls[c("pct_missing", "mean", "sd", "median", "mad", "min", "max", "skewness",
                        "q25", "q50", "q75")] == "numeric"))
})

#' @srrstats {TS3.0} trcprog()'s interval for the completion year widens as the target moves further away (total 94,
#'   150, 300).
test_that("the completion-year interval widens with the horizon", {
  w <- vapply(c(94, 150, 300), function(tot) {
    p <- trcprog(total = tot)
    p$cmplbylate - p$cmplbyearly
  }, 0)
  expect_true(all(diff(w) > 0))
})

test_that("stepchg() and trndtst() refuse periods out of order or repeated", {
  expect_error(stepchg(c(1, 2, 3, 4, 5, 6), x = c(1, 3, 2, 4, 5, 6)), "strictly increasing")
  expect_error(stepchg(c(1, 2, 3, 4, 5, 6), x = c(1, 2, 2, 4, 5, 6)), "strictly increasing")
  expect_identical(stepchg(c(100, 104, 98, 60, 63, 58), x = 2018:2023)$breakafter, 2020L)
  expect_error(trndtst(c(1, 2, 3, 4), x = c(1, 2, 2, 3)), "duplicated periods")
})

test_that("stepchg() gives the means of a huge series in its own units", {
  y <- c(1, 1.1, 0.9, 3, 3.2, 2.9)
  big <- stepchg(y * 1e200)
  small <- stepchg(y)
  expect_equal(big$before, small$before * 1e200, tolerance = 1e-12)
  expect_equal(big$after, small$after * 1e200, tolerance = 1e-12)
  expect_equal(big$difference, small$difference * 1e200, tolerance = 1e-12)
  expect_identical(big$index, small$index)
})

test_that("chwkfit() warns when the branching ratio sits on its bound", {
  set.seed(1)
  tm <- sort(100 + cumsum(stats::rexp(150, 20)))
  expect_warning(f <- chwkfit(tm, 1000), "upper bound 0.99")
  expect_identical(f$atbound, "eta")
})

test_that("yoy() compares ordered-factor periods by level order", {
  d <- data.frame(q = factor(c("Q1", "Q2", "Q4"), levels = paste0("Q", 1:4), ordered = TRUE),
                  n = c(10, 12, 15))
  r <- yoy(d, "n", "q")
  expect_identical(as.character(r$q), paste0("Q", 1:4))
  expect_true(is.ordered(r$q))
  expect_identical(r$previous, c(NA, 10, 12, NA))
  expect_identical(r$flag[3L], "no data")
  r <- yoy(d, "n", "q", complete = FALSE)
  expect_identical(r$previous, c(NA, 10, NA))
  # unordered: no order, so no comparison
  d$q <- factor(as.character(d$q))
  expect_true(all(is.na(yoy(d, "n", "q")$previous)))
  expect_error(yoy(list(1)), "a numeric or integer vector, or a ts, not list")
})

test_that("fylbl() refuses a fractional year, as documented", {
  expect_error(fylbl(2023.7), "whole years")
  expect_identical(fylbl(2023), "2022/23")
})
