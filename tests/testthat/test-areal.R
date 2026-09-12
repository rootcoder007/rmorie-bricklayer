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
    pop = c(1000, 6000, 900, 9000, 400, 3500))

  # THE defining property: applying the overall rates back to the whole
  # population must reproduce the overall total. If it does not, the
  # expected counts are not a standardisation of anything.
  for (st in list(NULL, d$age)) {
    e <- expected_counts(d$n, d$pop, d$region, strata = st)
    expect_equal(sum(e$expected), sum(d$n))
    expect_equal(sum(e$observed), sum(d$n))
    expect_equal(sum(e$population), sum(d$pop))
    expect_equal(e$area, sort(unique(d$region)))
  }

  # without strata the expected count is the area's population times the
  # overall rate, which adjusts for SIZE only
  size <- expected_counts(d$n, d$pop, d$region)
  overall <- sum(d$n) / sum(d$pop)
  expect_equal(size$expected, size$population * overall)

  # with strata it adjusts for COMPOSITION too, and the two differ
  # whenever an area's mix differs from the whole
  comp <- expected_counts(d$n, d$pop, d$region, strata = d$age)
  expect_false(isTRUE(all.equal(size$expected, comp$expected)))
  # recomputed by hand for North, whose rows are the first two
  r_young <- sum(d$n[d$age == "18 to 24"]) / sum(d$pop[d$age == "18 to 24"])
  r_old <- sum(d$n[d$age == "25 to 49"]) / sum(d$pop[d$age == "25 to 49"])
  expect_equal(comp$expected[comp$area == "North"],
               1000 * r_young + 6000 * r_old)

  # a single stratum is the same as none
  expect_equal(expected_counts(d$n, d$pop, d$region,
                               strata = rep("x", 6))$expected,
               size$expected)
  # one area per row still works
  solo <- expected_counts(c(5, 10), c(100, 400), c("a", "b"))
  expect_equal(sum(solo$expected), 15)
  expect_equal(solo$expected, c(100, 400) * (15 / 500))

  expect_error(expected_counts(1:3, 1:2, c("a", "b", "c")),
               "same length")
  expect_error(expected_counts(c(-1, 2), c(1, 2), c("a", "b")),
               "non-negative")
  expect_error(expected_counts(c(1, 2), c(0, 2), c("a", "b")),
               "must be positive")
  expect_error(expected_counts(c(1, 2), c(1, 2), c("a", "b"),
                               strata = "x"), "same length")
})

test_that("the SIR interval is exactly poisson.test's", {
  for (pair in list(c(28, 32.3443), c(75, 62.28), c(3, 5), c(0, 5),
                    c(1, 1), c(500, 400), c(2, 0.5))) {
    o <- pair[1L]
    e <- pair[2L]
    got <- sir(o, e)
    ref <- stats::poisson.test(o, e)$conf.int
    expect_equal(got$sir, o / e)
    expect_equal(got$lower, ref[1L], tolerance = 1e-9)
    expect_equal(got$upper, ref[2L], tolerance = 1e-9)
  }
  # an observed count of zero has a lower limit of exactly zero, not a
  # negative one
  expect_equal(sir(0, 5)$lower, 0)
  expect_gt(sir(0, 5)$upper, 0)
  # the interval brackets the ratio
  s <- sir(c(30, 12, 3), c(20, 14, 5))
  expect_true(all(s$lower <= s$sir))
  expect_true(all(s$upper >= s$sir))
  # and narrows as the counts grow, which is the whole information story
  wide <- sir(3, 3)
  narrow <- sir(300, 300)
  expect_gt(wide$upper - wide$lower, narrow$upper - narrow$lower)
  # a ratio of one is never an excess; an extreme one is
  expect_false(sir(100, 100)$excess)
  expect_true(sir(100, 50)$excess)
  expect_true(sir(10, 50)$excess)
  # an observed count of three carries almost no information, so its
  # interval spans one
  expect_false(sir(3, 5)$excess)
  # a stricter level widens it
  expect_lt(sir(30, 20, conf_level = 0.99)$lower,
            sir(30, 20, conf_level = 0.95)$lower)
  # labels and recycling
  lab <- sir(c(1, 2), 10, area = c("a", "b"))
  expect_identical(lab$area, c("a", "b"))
  expect_equal(lab$expected, c(10, 10))
  expect_error(sir(1:3, 1:2), "same length")
  expect_error(sir(-1, 5), "non-negative")
  expect_error(sir(5, 0), "must be positive")
})

test_that("shrinkage pulls the small areas in and leaves the big alone", {
  o <- c(30, 45, 2)
  e <- c(25, 50, 0.5)
  r <- eb_rates(o, e, c("North", "South", "Tiny"))
  expect_equal(r$sir, o / e)
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
  big <- eb_rates(c(12, 90, 1100), c(10, 100, 1000))
  expect_true(all(diff(big$shrinkage) < 0))
  expect_equal(big$shrinkage, 1 - c(10, 100, 1000) /
                 (c(10, 100, 1000) + big$alpha))
  expect_true(all(r$shrinkage >= 0 & r$shrinkage <= 1))

  # the posterior mean lies between the raw ratio and the overall one
  m <- sum(o) / sum(e)
  for (i in seq_along(o)) {
    expect_true(r$eb[i] >= min(r$sir[i], m) - 1e-9)
    expect_true(r$eb[i] <= max(r$sir[i], m) + 1e-9)
  }
  # and it is the Clayton-Kaldor form, recomputed from the reported
  # prior
  expect_equal(r$eb, (o + r$nu) / (e + r$alpha))
  expect_equal(r$shrinkage, 1 - e / (e + r$alpha))

  # WHEN THERE IS NO EVIDENCE of real variation between areas -- every
  # observed count equal to its expected one -- every estimate is the
  # overall rate and the shrinkage is total, reported rather than hidden
  none <- eb_rates(c(10, 20, 30), c(10, 20, 30))
  expect_equal(none$eb, rep(1, 3))
  expect_equal(none$shrinkage, rep(1, 3))
  expect_true(is.na(none$nu[1L]))

  # a large, genuinely varying set is barely shrunk
  set.seed(8)
  ee <- rep(500, 20)
  oo <- stats::rpois(20L, lambda = ee * rep(c(0.7, 1.3), 10))
  loose <- eb_rates(oo, ee)
  expect_true(all(loose$shrinkage < 0.2))

  expect_error(eb_rates(1:3, 1:2), "same length")
  expect_error(eb_rates(c(1, 2), c(0, 2)), "must be positive")
  expect_error(eb_rates(1, 1), "at least two")
})

test_that("the funnel narrows as the expected count grows", {
  f <- funnel_limits(c(2, 20, 200))
  expect_true(all(c("expected", "level", "lower", "upper") %in% names(f)))
  # the limits are the exact Poisson quantiles on the ratio scale
  for (i in seq_len(nrow(f))) {
    a <- 1 - f$level[i]
    mu <- f$expected[i]
    expect_equal(f$lower[i], stats::qpois(a / 2, mu) / mu)
    expect_equal(f$upper[i], stats::qpois(1 - a / 2, mu) / mu)
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
  expect_equal(f$lower[f$expected == 2 & f$level == 0.95], 0)
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
  t2 <- funnel_limits(20, target = 2)
  expect_true(all(t2$lower <= 2 & t2$upper >= 2))
  expect_error(funnel_limits(0), "must be positive")
  expect_error(funnel_limits(10, target = 0), "must be positive")
  expect_error(funnel_limits(10, levels = 1), "strictly inside")
})

test_that("Moran's I hits its known extremes on a line of areas", {
  # six areas in a line, each adjacent to the next
  nb <- list(2L, c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), 5L)

  # the null expectation is -1/(n-1), NOT zero: a small negative I is
  # what independence looks like in a small set of areas
  set.seed(1)
  g <- morans_i(c(1, 2, 3, 4, 5, 6), nb, n_perm = 1999L)
  expect_equal(g$expectation, -1 / 5)
  expect_equal(g$n, 6L)
  # a smooth gradient is strongly positively autocorrelated
  expect_gt(g$I, 0.5)
  expect_lt(g$p_value, 0.05)
  # and the permutation null centres on the expectation
  expect_equal(g$null_mean, -1 / 5, tolerance = 0.1)

  # a perfectly alternating pattern reaches the most negative value the
  # row-standardised statistic can take here
  set.seed(1)
  a <- morans_i(c(1, 6, 1, 6, 1, 6), nb, n_perm = 1999L)
  expect_lt(a$I, g$I)
  expect_equal(a$I, -1, tolerance = 1e-9)

  # I computed by hand from the definition, for the gradient
  x <- c(1, 2, 3, 4, 5, 6)
  z <- x - mean(x)
  w <- matrix(0, 6, 6)
  for (i in seq_len(6)) w[i, nb[[i]]] <- 1 / length(nb[[i]])
  want <- (6 / sum(w)) * sum(w * outer(z, z)) / sum(z^2)
  expect_equal(g$I, want, tolerance = 1e-12)
  expect_equal(g$W, sum(w), tolerance = 1e-12)

  # a weight matrix and a neighbour list describe the same graph
  wb <- matrix(0, 6, 6)
  for (i in seq_len(6)) wb[i, nb[[i]]] <- 1
  set.seed(1)
  m <- morans_i(x, wb, n_perm = 1999L)
  expect_equal(m$I, g$I)

  # binary weights give a different statistic, since an area with two
  # neighbours then counts for more than one with a single neighbour
  set.seed(1)
  b <- morans_i(x, nb, style = "B", n_perm = 999L)
  expect_false(isTRUE(all.equal(b$I, g$I)))
  expect_equal(b$W, sum(lengths(nb)))
  expect_identical(b$style, "B")

  # a permutation p-value counts the observed arrangement in its own
  # null, so it can never be exactly zero
  expect_gt(g$p_value, 0)
  expect_lte(g$p_value, 1)
  # an area is not its own neighbour: including it would put the value
  # on both sides of a product
  set.seed(1)
  self <- morans_i(x, lapply(seq_len(6), function(i) {
    sort(unique(c(i, nb[[i]])))
  }), n_perm = 999L)
  expect_equal(self$I, g$I)

  # a constant variable has no variation to correlate
  flat <- morans_i(rep(3, 6), nb, n_perm = 99L)
  expect_true(is.na(flat$I))

  expect_error(morans_i(c(1, 2), nb), "at least three areas")
  expect_error(morans_i(c(1, 2, NA, 4, 5, 6), nb), "missing values")
  expect_error(morans_i(x, nb[1:3]), "3 entries for 6 areas")
  expect_error(morans_i(x, matrix(0, 3, 3)), "6 by 6")
  expect_error(morans_i(x, "not a list"), "list of neighbour indices")
  expect_error(morans_i(x, list(7L, 1L, 1L, 1L, 1L, 1L)),
               "outside 1\\.\\.6")
  expect_error(morans_i(x, rep(list(integer(0)), 6L)),
               "no area any neighbour")
})

test_that("the areal functions compose on a region-coded table", {
  # the shape an OTIS extract actually has: counts by region and age
  set.seed(12)
  d <- expand.grid(region = c("Central", "Eastern", "Northern",
                              "Toronto", "Western"),
                   age = c("18 to 24", "25 to 49", "50+"),
                   stringsAsFactors = FALSE)
  d$pop <- c(rep(c(4000, 3000, 800, 5000, 2500), 3)) *
    rep(c(0.3, 0.55, 0.15), each = 5L)

  # A CONSTANT rate across regions first. There is then no real
  # between-region variation, the moment estimator of the prior
  # variance comes out at zero, and every estimate collapses to the
  # overall rate -- which is the right answer, not a failure, and is
  # reported through total shrinkage.
  d$n <- stats::rpois(nrow(d), lambda = d$pop * 0.01)
  flat <- expected_counts(d$n, d$pop, d$region, strata = d$age)
  expect_equal(sum(flat$expected), sum(d$n))
  fb <- eb_rates(flat$observed, flat$expected, flat$area)
  expect_equal(fb$shrinkage, rep(1, 5L))
  expect_equal(fb$eb, rep(1, 5L))
  # the raw ratios still vary, which is exactly the point: that spread
  # is sampling noise and the shrinkage removes it
  expect_gt(stats::sd(fb$sir), 0.1)
  expect_equal(stats::sd(fb$eb), 0)

  # Now a rate that genuinely DIFFERS by region, which is what the
  # shrinkage is meant to preserve.
  set.seed(13)
  rate <- c(Central = 0.006, Eastern = 0.011, Northern = 0.010,
            Toronto = 0.016, Western = 0.012)
  d$n <- stats::rpois(nrow(d), lambda = d$pop * rate[d$region])
  e <- expected_counts(d$n, d$pop, d$region, strata = d$age)
  expect_equal(sum(e$expected), sum(d$n))
  s <- sir(e$observed, e$expected, e$area)
  expect_equal(nrow(s), 5L)
  b <- eb_rates(e$observed, e$expected, e$area)
  # the shrunk ratios are less spread than the raw ones, which is what
  # borrowing strength does
  expect_lt(stats::sd(b$eb), stats::sd(b$sir))
  # but not collapsed, because the variation is real
  expect_gt(stats::sd(b$eb), 0)
  expect_true(all(b$shrinkage < 1))
  # the region carrying the least information is shrunk the most, which
  # is the claim -- stated against the expected counts rather than
  # against a region name
  expect_equal(b$area[which.max(b$shrinkage)],
               b$area[which.min(b$expected)])
  expect_equal(order(b$shrinkage), order(-b$expected))
  # and the funnel limits cover the expected counts these regions have
  f <- funnel_limits(e$expected)
  expect_equal(nrow(f), 10L)
  expect_true(all(is.finite(f$upper)))
})
