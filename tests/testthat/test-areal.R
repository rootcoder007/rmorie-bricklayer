# Areal statistics for region-coded tables.
#
# Anchors outside the module: stats::poisson.test for the exact interval,
# stats::qpois for the funnel limits, the defining identity of indirect
# standardisation (the expected counts must total the observed ones), the
# known extremes of Moran's I on a line of areas, and the null
# expectation -1/(n-1) recomputed by hand.

test_that("indirect standardisation conserves the total", {
  d <- data.frame(
    region = rep(c("North", "South", "East"), each = 2),
    age = rep(c("18 to 24", "25 to 49"), 3),
    n = c(30, 45, 12, 60, 8, 20),
    pop = c(1000, 6000, 900, 9000, 400, 3500),
    stringsAsFactors = FALSE
  )

  # THE defining property: applying the overall rates back to the whole
  # population must reproduce the overall total. If it does not, the
  # expected counts are not a standardisation of anything.
  for (st in list(NULL, d$age)) {
    e <- expcnts(d$n, d$pop, d$region, strata = st)
    expect_identical(sum(e$expected), sum(d$n))
    expect_identical(sum(e$observed), sum(d$n))
    expect_identical(sum(e$population), sum(d$pop))
    expect_identical(e$area, sort(unique(d$region)))
  }

  # without strata the expected count is the area's population times the
  # overall rate, which adjusts for SIZE only
  size <- expcnts(d$n, d$pop, d$region)
  overall <- sum(d$n) / sum(d$pop)
  expect_identical(size$expected, size$population * overall)

  # with strata it adjusts for COMPOSITION too, and the two differ
  # whenever an area's mix differs from the whole
  comp <- expcnts(d$n, d$pop, d$region, strata = d$age)
  expect_false(isTRUE(all.equal(size$expected, comp$expected)))
  # recomputed by hand for North, whose rows are the first two
  r_young <- sum(d$n[d$age == "18 to 24"]) / sum(d$pop[d$age == "18 to 24"])
  r_old <- sum(d$n[d$age == "25 to 49"]) / sum(d$pop[d$age == "25 to 49"])
  expect_identical(
    comp$expected[comp$area == "North"],
    1000 * r_young + 6000 * r_old
  )

  # a single stratum is the same as none
  expect_identical(
    expcnts(d$n, d$pop, d$region, strata = rep("x", 6))$expected,
    size$expected
  )
  # one area per row still works
  solo <- expcnts(c(5, 10), c(100, 400), c("a", "b"))
  expect_identical(sum(solo$expected), 15)
  expect_identical(solo$expected, c(100, 400) * (15 / 500))

  expect_error(expcnts(1:3, 1:2, c("a", "b", "c")), "same length")
  expect_error(expcnts(c(-1, 2), c(1, 2), c("a", "b")), "non-negative")
  expect_error(expcnts(c(1, 2), c(0, 2), c("a", "b")), "must be positive")
  expect_error(
    expcnts(c(1, 2), c(1, 2), c("a", "b"), strata = "x"),
    "same length"
  )
})

test_that("the SIR interval is exactly poisson.test's", {
  for (pair in list(
    c(28, 32.3443),
    c(75, 62.28),
    c(3, 5),
    c(0, 5),
    c(1, 1),
    c(500, 400),
    c(2, 0.5)
  )) {
    o <- pair[1L]
    e <- pair[2L]
    got <- stdinc(o, e)
    ref <- stats::poisson.test(o, e)$conf.int
    expect_identical(got$sir, o / e)
    expect_equal(got$lower, ref[1L], tolerance = 1e-9)
    expect_equal(got$upper, ref[2L], tolerance = 1e-9)
  }
  # an observed count of zero has a lower limit of exactly zero, not a
  # negative one
  expect_identical(stdinc(0, 5)$lower, 0)
  expect_gt(stdinc(0, 5)$upper, 0)
  # the interval brackets the ratio
  s <- stdinc(c(30, 12, 3), c(20, 14, 5))
  expect_true(all(s$lower <= s$sir))
  expect_true(all(s$upper >= s$sir))
  # and narrows as the counts grow, which is the whole information story
  wide <- stdinc(3, 3)
  narrow <- stdinc(300, 300)
  expect_gt(wide$upper - wide$lower, narrow$upper - narrow$lower)
  # a ratio of one is never an excess; an extreme one is
  expect_false(stdinc(100, 100)$excess)
  expect_true(stdinc(100, 50)$excess)
  expect_false(stdinc(10, 50)$excess)
  expect_true(stdinc(10, 50)$deficit)
  expect_true(stdinc(10, 50)$significant)
  # an observed count of three carries almost no information, so its
  # interval spans one
  expect_false(stdinc(3, 5)$excess)
  # a stricter level widens it
  expect_lt(
    stdinc(30, 20, conflvl = 0.99)$lower,
    stdinc(30, 20, conflvl = 0.95)$lower
  )
  # labels and recycling
  lab <- stdinc(c(1, 2), 10, area = c("a", "b"))
  expect_identical(lab$area, c("a", "b"))
  expect_identical(lab$expected, c(10, 10))
  expect_error(stdinc(1:3, 1:2), "same length")
  expect_error(stdinc(-1, 5), "non-negative")
  expect_error(stdinc(5, 0), "must be positive")
})

test_that("shrinkage pulls the small areas in and leaves the big alone", {
  o <- c(30, 45, 2)
  e <- c(25, 50, 0.5)
  r <- ebrates(o, e, c("North", "South", "Tiny"))
  expect_identical(r$sir, o / e)
  # the tiny area's raw ratio of four is almost entirely noise, so it is
  # shrunk nearly to the overall rate
  expect_gt(r$shrinkage[3L], 0.9)
  expect_lt(abs(r$eb[3L] - 1), abs(r$sir[3L] - 1))
  # the larger areas keep most of their own signal
  expect_lt(r$shrinkage[1L], r$shrinkage[3L])
  # Shrinkage is ordered inversely to the EXPECTED count, which is the
  # substantive claim: information, not size of effect, decides how much
  # an estimate moves. The counts have to differ from their expected
  # values for there to be any between-area variation to estimate --
  # with every count equal to its expectation the prior variance is
  # zero and everything collapses to the overall rate.
  big <- ebrates(c(12, 90, 1100), c(10, 100, 1000))
  expect_true(all(diff(big$shrinkage) < 0))
  expect_identical(
    big$shrinkage,
    1 -
      c(10, 100, 1000) /
        (c(10, 100, 1000) + big$alpha)
  )
  expect_true(all(r$shrinkage >= 0 & r$shrinkage <= 1))

  # the posterior mean lies between the raw ratio and the overall one
  m <- sum(o) / sum(e)
  for (i in seq_along(o)) {
    expect_gte(r$eb[i], min(r$sir[i], m) - 1e-9)
    expect_lte(r$eb[i], max(r$sir[i], m) + 1e-9)
  }
  # and it is the Clayton-Kaldor form, recomputed from the reported
  # prior
  expect_identical(r$eb, (o + r$nu) / (e + r$alpha))
  expect_identical(r$shrinkage, 1 - e / (e + r$alpha))

  # WHEN THERE IS NO EVIDENCE of real variation between areas -- every
  # observed count equal to its expected one -- every estimate is the
  # overall rate and the shrinkage is total, reported rather than hidden
  none <- ebrates(c(10, 20, 30), c(10, 20, 30))
  expect_identical(none$eb, rep(1, 3))
  expect_identical(none$shrinkage, rep(1, 3))
  expect_true(is.na(none$nu[1L]))

  # a large, genuinely varying set is barely shrunk
  set.seed(8)
  ee <- rep(500, 20)
  oo <- stats::rpois(20L, lambda = ee * rep(c(0.7, 1.3), 10))
  loose <- ebrates(oo, ee)
  expect_true(all(loose$shrinkage < 0.2))

  expect_error(ebrates(1:3, 1:2), "same length")
  expect_error(ebrates(c(1, 2), c(0, 2)), "must be positive")
  expect_error(ebrates(1, 1), "at least two")
})

test_that("the funnel narrows as the expected count grows", {
  f <- fnllim(c(2, 20, 200))
  expect_true(all(c("expected", "level", "lower", "upper") %in% names(f)))
  # the limits are the exact Poisson quantiles on the ratio scale
  for (i in seq_len(nrow(f))) {
    a <- 1 - f$level[i]
    mu <- f$expected[i]
    expect_identical(f$lower[i], stats::qpois(a / 2, mu) / mu)
    expect_identical(f$upper[i], stats::qpois(1 - a / 2, mu) / mu)
  }
  # the width shrinks with the expected count: a ratio of two means
  # nothing at an expected count of two and a great deal at 200
  for (lev in unique(f$level)) {
    w <- f[f$level == lev, ]
    w <- w[order(w$expected), ]
    expect_true(all(diff(w$upper - w$lower) < 0))
  }
  # and at a small expected count the lower limit is zero rather than
  # negative, which a normal funnel would give
  expect_identical(f$lower[f$expected == 2 & f$level == 0.95], 0)
  # the outer limits contain the inner ones
  inner <- f[f$level == 0.95, ]
  outer <- f[f$level == 0.998, ]
  inner <- inner[order(inner$expected), ]
  outer <- outer[order(outer$expected), ]
  expect_true(all(outer$lower <= inner$lower))
  expect_true(all(outer$upper >= inner$upper))
  # the limits bracket the target
  expect_true(all(f$lower <= 1 & f$upper >= 1))
  # a target other than one shifts them
  t2 <- fnllim(20, target = 2)
  expect_true(all(t2$lower <= 2 & t2$upper >= 2))
  expect_error(fnllim(0), "must be positive")
  expect_error(fnllim(10, target = 0), "must be positive")
  expect_error(fnllim(10, lvls = 1), "strictly inside")
})

test_that("Moran's I hits its known extremes on a line of areas", {
  # six areas in a line, each adjacent to the next
  nb <- list(2L, c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), 5L)

  # the null expectation is -1/(n-1), NOT zero: a small negative I is
  # what independence looks like in a small set of areas
  set.seed(1)
  g <- morani(c(1, 2, 3, 4, 5, 6), nb, nperm = 1999L)
  expect_identical(g$expectation, -1 / 5)
  expect_identical(g$n, 6L)
  # a smooth gradient is strongly positively autocorrelated
  expect_gt(g$I, 0.5)
  expect_lt(g$p_value, 0.05)
  # and the permutation null centres on the expectation
  expect_equal(g$nullmean, -1 / 5, tolerance = 0.1)

  # a perfectly alternating pattern reaches the most negative value the
  # row-standardised statistic can take here
  set.seed(1)
  a <- morani(c(1, 6, 1, 6, 1, 6), nb, nperm = 1999L)
  expect_lt(a$I, g$I)
  expect_equal(a$I, -1, tolerance = 1e-9)

  # I computed by hand from the definition, for the gradient
  x <- c(1, 2, 3, 4, 5, 6)
  z <- x - mean(x)
  w <- matrix(0, 6, 6)
  for (i in seq_len(6)) {
    w[i, nb[[i]]] <- 1 / length(nb[[i]])
  }
  want <- (6 / sum(w)) * sum(w * outer(z, z)) / sum(z^2)
  expect_equal(g$I, want, tolerance = 1e-12)
  expect_equal(g$W, sum(w), tolerance = 1e-12)

  # a weight matrix and a neighbour list describe the same graph
  wb <- matrix(0, 6, 6)
  for (i in seq_len(6)) {
    wb[i, nb[[i]]] <- 1
  }
  set.seed(1)
  m <- morani(x, wb, nperm = 1999L)
  expect_identical(m$I, g$I)

  # binary weights give a different statistic, since an area with two
  # neighbours then counts for more than one with a single neighbour
  set.seed(1)
  b <- morani(x, nb, style = "B", nperm = 999L)
  expect_false(isTRUE(all.equal(b$I, g$I)))
  expect_identical(b$W, as.double(sum(lengths(nb))))
  expect_identical(b$style, "B")

  # a permutation p-value counts the observed arrangement in its own
  # null, so it can never be exactly zero
  expect_gt(g$p_value, 0)
  expect_lte(g$p_value, 1)
  # an area is not its own neighbour: including it would put the value
  # on both sides of a product
  set.seed(1)
  self <- morani(
    x,
    lapply(seq_len(6), function(i) {
      sort(unique(c(i, nb[[i]])))
    }),
    nperm = 999L
  )
  expect_identical(self$I, g$I)

  # a constant variable has no variation to correlate: said, not NA
  expect_error(morani(rep(3, 6), nb, nperm = 99L), "constant")

  expect_error(morani(c(1, 2), nb), "at least three areas")
  expect_error(morani(c(1, 2, NA, 4, 5, 6), nb), "missing values")
  expect_error(morani(x, nb[1:3]), "3 entries for 6 areas")
  expect_error(morani(x, matrix(0, 3, 3)), "6 by 6")
  expect_error(morani(x, "not a list"), "list of neighbour indices")
  expect_error(morani(x, list(7L, 1L, 1L, 1L, 1L, 1L)), "outside 1\\.\\.6")
  expect_error(morani(x, rep(list(integer(0)), 6L)), "no area any neighbour")
})

test_that("the areal functions compose on a region-coded table", {
  # the shape an OTIS extract actually has: counts by region and age
  set.seed(12)
  d <- expand.grid(
    region = c("Central", "Eastern", "Northern", "Toronto", "Western"),
    age = c("18 to 24", "25 to 49", "50+"),
    stringsAsFactors = FALSE
  )
  d$pop <- c(rep(c(4000, 3000, 800, 5000, 2500), 3)) *
    rep(c(0.3, 0.55, 0.15), each = 5L)

  # A CONSTANT rate across regions first. There is then no real
  # between-region variation, the moment estimator of the prior
  # variance comes out at zero, and every estimate collapses to the
  # overall rate -- which is the right answer, not a failure, and is
  # reported through total shrinkage.
  d$n <- stats::rpois(nrow(d), lambda = d$pop * 0.01)
  flat <- expcnts(d$n, d$pop, d$region, strata = d$age)
  expect_identical(sum(flat$expected), as.double(sum(d$n)))
  fb <- ebrates(flat$observed, flat$expected, flat$area)
  expect_identical(fb$shrinkage, rep(1, 5L))
  expect_identical(fb$eb, rep(1, 5L))
  # the raw ratios still vary, which is exactly the point: that spread
  # is sampling noise and the shrinkage removes it
  expect_gt(stats::sd(fb$sir), 0.1)
  expect_identical(stats::sd(fb$eb), 0)

  # Now a rate that genuinely DIFFERS by region, which is what the
  # shrinkage is meant to preserve.
  set.seed(13)
  rate <- c(
    Central = 0.006,
    Eastern = 0.011,
    Northern = 0.010,
    Toronto = 0.016,
    Western = 0.012
  )
  d$n <- stats::rpois(nrow(d), lambda = d$pop * rate[d$region])
  e <- expcnts(d$n, d$pop, d$region, strata = d$age)
  expect_identical(sum(e$expected), as.double(sum(d$n)))
  s <- stdinc(e$observed, e$expected, e$area)
  expect_identical(nrow(s), 5L)
  b <- ebrates(e$observed, e$expected, e$area)
  # the shrunk ratios are less spread than the raw ones, which is what
  # borrowing strength does
  expect_lt(stats::sd(b$eb), stats::sd(b$sir))
  # but not collapsed, because the variation is real
  expect_gt(stats::sd(b$eb), 0)
  expect_true(all(b$shrinkage < 1))
  # the region carrying the least information is shrunk the most, which
  # is the claim -- stated against the expected counts rather than
  # against a region name
  expect_identical(
    b$area[which.max(b$shrinkage)],
    b$area[which.min(b$expected)]
  )
  expect_identical(order(b$shrinkage), order(-b$expected))
  # and the funnel limits cover the expected counts these regions have
  f <- fnllim(e$expected)
  expect_identical(nrow(f), 10L)
  expect_true(all(is.finite(f$upper)))
})

test_that("expcnts() and stdinc() drop incomplete rows whole", {
  # dropped from each vector alone, the counts and populations paired the
  # wrong rows (or the lengths stopped differing)
  e <- expcnts(c(1, NA, 3, 4), c(10, 20, NA, 40), c("a", "b", "c", "d"))
  expect_identical(e$area, c("a", "d"))
  expect_identical(e$observed, c(1, 4))
  expect_identical(e$population, c(10, 40))
  expect_identical(e$expected, c(10, 40) * (5 / 50))
  s <- stdinc(c(3, NA, 5), c(2, 4, 5), area = c("x", "y", "z"))
  expect_identical(s$area, c("x", "z"))
  expect_identical(s$sir, c(1.5, 1))
  expect_identical(stdinc(c(3, 4), c(NA, 2))$sir, 2)
  expect_error(stdinc(c(1, 2, NA), c(1, 2)), "same length")
  expect_error(stdinc(c(NA, 2), c(1, NA)), "no area has both")
  expect_error(expcnts(c(1, -1), c(5, 5), c("a", "b")), "non-negative")
})

test_that("fnllim() refuses a target vector and empty or missing levels", {
  expect_error(fnllim(10, target = c(1, 2)), "`target` must be positive: one")
  expect_error(fnllim(10, lvls = NULL), "`lvls` must be one or more levels")
  expect_error(fnllim(10, lvls = NA), "`lvls` must be one or more levels")
  expect_error(
    fnllim(10, lvls = numeric(0)),
    "`lvls` must be one or more levels"
  )
  expect_error(fnllim(10, lvls = c(0.95, NA)), "with no missing value")
  expect_identical(nrow(fnllim(c(2, 20), lvls = 0.95)), 2L)
})

test_that("morani() names `nbrs` in its neighbour errors", {
  x <- c(1, 2, 3, 4)
  expect_error(morani(x, 1), "^morani: `nbrs` must be a list")
  expect_error(morani(x, list(2, 1)), "`nbrs` has 2 entries for 4 areas")
})

test_that("morani() results print as a box", {
  nb <- list(2L, c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), 5L)
  set.seed(1)
  m <- morani(c(1, 2, 3, 4, 5, 6), nb, nperm = 999L)
  expect_s3_class(m, "rmbl_moran")
  expect_type(m, "list")
  expect_box2(m, "Global Moran's I", c("Permutations", "W (row-standardised)"))
  expect_box2(m, "Global Moran's I", "Clustered")
  m0 <- morani(c(1, 2, 3, 4, 5, 6), nb, style = "B", nperm = 0L)
  expect_box2(m0, "Moran", c("not available", "no permutations", "B (weights"))
  m$p_value <- 0.5
  expect_box2(m, "Moran", "No clear spatial pattern")
  m$p_value <- 0.01
  m$I <- -0.9
  expect_box2(m, "Moran", "Dispersed")
})

test_that("stdinc(), ebrates() and expcnts() results print as boxes", {
  s <- stdinc(c(30, 12, 3), c(20, 14, 5), area = c("N", "S", "E"))
  expect_s3_class(s, c("rmbl_sir", "data.frame"))
  expect_box2(s, "Standardised incidence ratios", c("excess", "1.012"))
  expect_box2(s[1:2], "Standardised incidence ratios", "plain table")
  e <- ebrates(c(30, 45, 2), c(25, 50, 0.5))
  expect_s3_class(e, c("rmbl_ebrates", "data.frame"))
  expect_box2(e, "Empirical Bayes rates", c("Prior shape (nu)", "shrinkage"))
  e0 <- ebrates(c(10, 11, 9), c(10, 10, 10))
  expect_box2(e0, "Empirical Bayes rates", c("none", "no more than chance"))
  x <- expcnts(c(30, 45, 12), c(1000, 6000, 900), c("a", "b", "c"))
  expect_s3_class(x, c("rmbl_expected", "data.frame"))
  expect_box2(x, "Expected counts", c("Population", "7,900"))
})

test_that("a subset of an areal result prints as a plain table", {
  expect_df_fallback("rmbl_ebrates", "Empirical Bayes rates")
  expect_df_fallback("rmbl_expected",
    "Expected counts, indirect standardisation")
})
