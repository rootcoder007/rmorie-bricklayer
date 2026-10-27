# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("ginicoef spans an even spread to one unit holding everything", {
  expect_equal(as.numeric(ginicoef(rep(1, 10))), 0, tolerance = 1e-12)
  expect_equal(
    as.numeric(ginicoef(c(rep(0, 9), 1))),
    1 - 1 / 10,
    tolerance = 1e-12
  )
  # missing values are dropped
  expect_equal(as.numeric(ginicoef(c(1, 1, NA))), 0, tolerance = 1e-12)
  expect_error(ginicoef(c(0, 0)), "Gini coefficient of a zero total")
  expect_error(ginicoef(c(NA_real_, NA_real_)), "`x` has no values")
  expect_error(ginicoef(c(1, -1)))
  expect_error(ginicoef(c(1, Inf)))
})

test_that("lorenzc runs from the origin to (1, 1)", {
  lz <- lorenzc(c(1, 2, 3, 4))
  expect_s3_class(lz, "data.frame")
  expect_named(lz, c("population", "value"))
  expect_identical(nrow(lz), 5L)
  expect_identical(unlist(lz[1L, ]), c(population = 0, value = 0))
  expect_identical(unlist(lz[5L, ]), c(population = 1, value = 1))
  expect_equal(lz$value[2L], 0.1, tolerance = 1e-12)
})

test_that("topshr gives the share of the largest units and refuses bad fracs", {
  ts <- topshr(rep(1, 100), c(0.1, 0.5, 1))
  expect_named(ts, c("fraction", "units", "share"))
  expect_equal(ts$share, c(0.1, 0.5, 1), tolerance = 1e-12)
  expect_equal(topshr(c(rep(0, 9), 10), 0.1)$share, 1, tolerance = 1e-12)
  expect_error(topshr(1:3, "a"), "numeric shares in \\[0, 1\\]")
  expect_error(topshr(1:3, TRUE), "numeric shares in \\[0, 1\\]")
  expect_error(topshr(1:3, factor(1)), "numeric shares in \\[0, 1\\]")
  expect_error(topshr(1:3, numeric(0)), "must be shares in \\[0, 1\\]")
  expect_error(topshr(1:3, c(0.5, NA)), "must be shares in \\[0, 1\\]")
  expect_error(topshr(1:3, 1.5), "must be shares in \\[0, 1\\]")
})

test_that("hurwzeta matches zeta(2) and its recurrence in q", {
  expect_equal(hurwzeta(2), pi^2 / 6, tolerance = 1e-10)
  expect_equal(hurwzeta(4), pi^4 / 90, tolerance = 1e-10)
  # the recurrence in q: the difference of two shifts is one term, q to the -s
  expect_equal(
    hurwzeta(3, 2.5) - hurwzeta(3, 3.5),
    2.5^-3,
    tolerance = 1e-10
  )
  # zeta(s, 1/2) = (2^s - 1) zeta(s)
  expect_equal(hurwzeta(3, 0.5), 7 * hurwzeta(3), tolerance = 1e-10)
  # Riemann's zeta at a negative whole s: zeta(-1) = -1/12, a trivial zero at -2
  expect_equal(hurwzeta(-1), -1 / 12, tolerance = 1e-10)
  expect_equal(hurwzeta(-2), 0, tolerance = 1e-12)
  # a non-positive whole q is a pole
  expect_true(is.na(hurwzeta(2, -1)))
  # a negative fractional q: a whole s sums the negative terms in closed form
  expect_equal(
    hurwzeta(2, -0.5),
    hurwzeta(2, 0.5) + 0.5^-2,
    tolerance = 1e-10
  )
  expect_true(is.na(hurwzeta(2.5, -0.5)))
  expect_error(hurwzeta(TRUE), "not logical")
  expect_error(hurwzeta(2, c(1, 2)), "single finite number")
  expect_error(hurwzeta(2, Inf), "single finite number")
})

test_that("hilltlidx fits a tail and refuses what it cannot fit", {
  set.seed(1)
  x <- round(1 / stats::runif(500)^(1 / 1.5))
  fit <- hilltlidx(x, xmin = 2)
  expect_gt(fit$alpha, 1)
  expect_identical(fit$xmin, 2)
  expect_match(fit$method, "zeta")
  cont <- hilltlidx(1 / stats::runif(300)^(1 / 2), xmin = 1, discrete = FALSE)
  expect_equal(cont$alpha, 3, tolerance = 0.5)
  expect_match(cont$method, "continuous Hill")
  appr <- hilltlidx(x, xmin = 2, approx = TRUE)
  expect_match(appr$method, "continuity-corrected")
  expect_true(is.na(hilltlidx(c(5, 5, 5, 5), xmin = 5)$alpha))
  expect_error(hilltlidx(x, xmin = "2"), "must be numeric, not logical")
  expect_error(hilltlidx(c(-1, 0)), "no positive finite values")
})

test_that("cramerv measures association and refuses a table too small", {
  perfect <- diag(10, 3)
  v <- cramerv(perfect, biascor = FALSE)
  expect_equal(v$v, 1, tolerance = 1e-12)
  expect_identical(v$df, 4L)
  expect_match(v$method, "Monte Carlo")
  big <- matrix(c(50, 50, 50, 50), 2)
  expect_equal(cramerv(big, biascor = FALSE)$v, 0, tolerance = 1e-12)
  expect_match(cramerv(big)$method, "chi-square approximation")
  small <- cramerv(matrix(c(3, 0, 4, 0), 2))
  expect_true(is.na(small$v))
  expect_match(small$method, "after dropping empty rows/columns")
  expect_error(cramerv(matrix(c(1, -1, 2, 3), 2)))
})

test_that("topshr(), hilltlidx() and cramerv() results print as boxes", {
  set.seed(3)
  tp <- topshr(stats::rexp(500))
  expect_s3_class(tp, c("rmbl_top_share", "data.frame"))
  expect_box2(tp, "Top shares of a total", c("1%", "equal shares"))
  h <- hilltlidx(stats::rpois(300, 3) + 1L)
  expect_s3_class(h, "rmbl_tail_index")
  expect_type(h, "list")
  expect_box2(h, "Power-law tail index", c("Tail observations", "above 2"))
  h$alpha <- 1.8
  h$reliable <- FALSE
  expect_box2(h, "Power-law tail index", c("barely defined", "not reliable"))
  h0 <- hilltlidx(c(1, 1, 1))
  expect_box2(h0, "Power-law tail index", c("not estimated", "No exponent"))
  v <- cramerv(matrix(c(20, 5, 7, 30), 2))
  expect_s3_class(v, "rmbl_cramerv")
  expect_box2(v, "Cramer's V", c("Chi-square", "< 0.001", "unlikely"))
  v1 <- cramerv(matrix(c(2, 1, 1, 3), 2))
  expect_box2(v1, "Cramer's V", c("Monte Carlo", "could be chance"))
  v0 <- cramerv(matrix(c(5, 3, 0, 0), 2))
  expect_s3_class(v0, "rmbl_cramerv")
  expect_box2(v0, "Cramer's V", c("not available", "no association"))
  v$p_value <- NA_real_
  expect_box2(v, "Cramer's V", "the row fixes the column).")
})

# ---- ginicoef() prints as a box and stays a number --------------------------

test_that("ginicoef() returns a boxed measure that computes as a number", {
  g <- ginicoef(c(rep(1, 1200), rep(3, 430), rep(20, 38)))
  expect_s3_class(g, c("rmbl_gini", "rmbl_measure", "numeric"))
  expect_identical(attr(g, "lakner")$n, 1668L)
  expect_false(inherits(g * 2, "rmbl_measure"))
  expect_false(inherits(c(g, g), "rmbl_measure"))
  expect_identical(as.numeric(g), .rmbl_measure_plain(g))
  out <- expect_box2(g, "Gini coefficient", c("Units 1,668", "concentrated"))
  expect_gt(length(out), 3L)
  even <- paste(format(ginicoef(rep(2, 10))), collapse = " ")
  expect_match(even, "close to equal shares", fixed = TRUE)
  top <- paste(format(ginicoef(c(rep(0, 9), 1))), collapse = " ")
  expect_match(top, "very highly concentrated", fixed = TRUE)
})

test_that("a concentration result without its record prints plainly", {
  expect_df_fallback("rmbl_top_share", "Top shares of a total")
  expect_plain_measure("rmbl_gini")
})
