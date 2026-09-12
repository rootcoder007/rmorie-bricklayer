# Banded categories, concentration, association and short-series trend:
# the statistics a published administrative table needs.
#
# Anchors outside the module: pi^2/6, pi^4/90 and Apery's constant for
# the Hurwitz zeta; the mean-absolute-difference definition of Gini,
# computed independently; stats::cor.test's Kendall tau; stats::glm's
# Poisson fit; stats::chisq.test; simulation from distributions whose
# parameters are known; and closed forms recomputed by hand.

test_that("band labels parse to the bounds they state", {
  b <- parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
  expect_equal(b$lower, c(1, 2, 6, 11))
  expect_equal(b$upper, c(1, 5, 10, NA))
  expect_equal(b$open_upper, c(FALSE, FALSE, FALSE, TRUE))
  expect_equal(b$open_lower, rep(FALSE, 4L))
  # "greater than 10" on integer data starts at 11, not at 10: the
  # difference is a whole unit of the quantity being measured
  expect_equal(parse_bands("Greater than 10", integer_scale = FALSE)$lower,
               10)

  # the age bands these datasets use
  a <- parse_bands(c("18 to 24", "25 to 49", "50+"))
  expect_equal(a$lower, c(18, 25, 50))
  expect_equal(a$upper, c(24, 49, NA))
  expect_true(a$open_upper[3L])
  # "50+" includes 50; "over 50" does not
  expect_equal(parse_bands("50+")$lower, 50)
  expect_equal(parse_bands("over 50")$lower, 51)
  expect_equal(parse_bands("50+", closed_upper = FALSE)$lower, 51)

  # open lower bands
  l <- parse_bands(c("<18", "under 18", "less than 18", "17 or less"))
  expect_equal(l$upper, c(17, 17, 17, 17))
  expect_true(all(l$open_lower))
  expect_true(all(is.na(l$lower)))

  # the dash family, which publishers mix freely
  for (lab in c("18-24", "18 - 24", "18–24", "18—24",
                "18 through 24")) {
    p <- parse_bands(lab)
    expect_equal(p$lower, 18, info = lab)
    expect_equal(p$upper, 24, info = lab)
  }
  # an INCLUSIVE wording includes its own number and the exclusive one
  # starts a unit higher, so the two patterns must not shadow each other
  expect_equal(parse_bands("65 and over")$lower, 65)
  expect_equal(parse_bands("over 65")$lower, 66)
  expect_equal(parse_bands("3 or more")$lower, 3)
  expect_equal(parse_bands("more than 3")$lower, 4)
  expect_true(parse_bands("3 or more")$open_upper)
  # and the same on the lower side
  expect_equal(parse_bands("17 and under")$upper, 17)
  expect_equal(parse_bands("under 17")$upper, 16)
  expect_equal(parse_bands("17 or less")$upper, 17)
  expect_equal(parse_bands("less than 17")$upper, 16)

  # an unrecognised label is reported as unparsed rather than guessed at
  u <- parse_bands(c("unknown", "not stated", "", NA))
  expect_true(all(is.na(u$lower)))
  expect_true(all(is.na(u$upper)))
  expect_equal(nrow(u), 4L)
  expect_identical(u$label[1L], "unknown")
  expect_equal(parse_bands("1.5 to 2.5")$upper, 2.5)
})

test_that("a band's representative value states its rule", {
  b <- parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
  mid <- band_values(b)
  expect_equal(mid$value[1:3], c(1, 3.5, 8))
  # the open band has no midpoint, so the value rests on an assumption
  # and the row is marked
  expect_equal(mid$assumed, c(FALSE, FALSE, FALSE, TRUE))
  expect_equal(mid$value[4L], (11 + 22) / 2)
  expect_equal(band_values(b, open_upper_cap = 40)$value[4L], (11 + 40) / 2)
  # the lower and upper rules bracket whatever the truth is
  lo <- band_values(b, rule = "lower")$value
  hi <- band_values(b, rule = "upper", open_upper_cap = 40)$value
  expect_true(all(lo <= mid$value))
  expect_true(all(hi[1:3] >= mid$value[1:3]))
  expect_equal(lo, c(1, 2, 6, 11))
  g <- band_values(b, rule = "geometric")$value
  expect_equal(g[2L], sqrt(2 * 5))
  # the geometric mean is undefined at zero, so the band falls back
  zero <- band_values(parse_bands("0 to 4"), rule = "geometric")$value
  expect_equal(zero, 2)
  ol <- band_values(parse_bands("under 18"), open_lower_floor = 0)
  expect_equal(ol$value, 8.5)
  expect_true(ol$assumed)
  expect_equal(band_values(c("2 to 5"))$value, 3.5)
  expect_error(band_values(data.frame(a = 1)), "parse_bands")
})

test_that("expanding a banded table reproduces the counts", {
  x <- expand_bands(c("1", "2 to 5", "Greater than 5"),
                    counts = c(10, 4, 2), open_upper_cap = 12)
  expect_length(x, 16L)
  expect_equal(sum(x == 1), 10L)
  expect_equal(sum(x == 3.5), 4L)
  expect_equal(sum(x == 9), 2L)
  # an unparseable band contributes nothing rather than NA values that
  # would poison every statistic computed downstream
  y <- expand_bands(c("1", "unknown"), counts = c(3, 5))
  expect_length(y, 3L)
  expect_false(anyNA(y))
  expect_equal(length(expand_bands(c("1", "2 to 5"), c(0, 0))), 0L)
  expect_error(expand_bands(c("1", "2 to 5"), counts = 1), "2 bands")
  expect_error(expand_bands("1", counts = -1), "non-negative")
})

test_that("the open band's cap is reported as the assumption it is", {
  b <- parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
  counts <- c(1200, 430, 110, 38)
  s <- band_sensitivity(b, counts)
  expect_s3_class(s, "rmbl_band_sensitivity")
  expect_true(all(c("cap", "value") %in% names(s)))
  expect_gt(nrow(s), 5L)
  expect_true(all(is.finite(s$value)))
  # a concentration measure RISES as the open band's cap rises, because
  # the same 38 units are given more of the total
  expect_true(all(diff(s$value) >= -1e-9))
  expect_true(is.finite(attr(s, "span")))
  expect_gt(attr(s, "span"), 0)
  m <- band_sensitivity(b, counts, statistic = mean)
  expect_true(all(diff(m$value) >= -1e-9))
  # at a given cap it agrees with computing it directly
  direct <- mean(expand_bands(b, counts, open_upper_cap = m$cap[3L]))
  expect_equal(m$value[3L], direct)
  e <- band_sensitivity(b, counts, caps = c(11, 50, 200))
  expect_equal(e$cap, c(11, 50, 200))
  expect_output(print(e), "Sensitivity to the open top band")
  expect_output(print(e), "span over the caps tried")
  # a closed set of bands has nothing to be sensitive to, and says so
  expect_error(band_sensitivity(parse_bands(c("1", "2 to 5")), c(1, 2)),
               "nothing to be sensitive to")
  expect_error(band_sensitivity(b, c(1, 2)), "4 bands")
})

test_that("Gini is the mean absolute difference over twice the mean", {
  # the definition, computed independently
  for (x in list(c(1, 2, 3, 4, 5), c(1, 1, 1, 8), c(3, 7),
                 c(0, 0, 0, 5), rep(4, 7), c(2, 2, 3, 100))) {
    want <- mean(abs(outer(x, x, "-"))) / (2 * mean(x))
    expect_equal(gini(x), want, tolerance = 1e-12)
  }
  expect_equal(gini(rep(1, 10)), 0)
  expect_equal(gini(rep(7.5, 100)), 0)
  # the MAXIMUM for n units is 1 - 1/n, not one: a Gini near one needs
  # many units as well as an uneven spread
  for (n in c(2L, 5L, 10L, 100L)) {
    expect_equal(gini(c(rep(0, n - 1L), 1)), 1 - 1 / n)
  }
  # scale invariance: doubling every value changes no share
  x <- c(1, 4, 9, 16)
  expect_equal(gini(x), gini(2 * x))
  expect_equal(gini(x), gini(1000 * x))
  expect_equal(gini(5), 0)
  # a total of zero has no distribution to be unequal about
  expect_true(is.na(gini(c(0, 0, 0))))
  expect_true(is.na(gini(numeric(0))))
  expect_equal(gini(c(1, 2, 3, NA)), gini(c(1, 2, 3)))
  expect_error(gini(c(1, -1)), "non-negative")
  expect_error(gini(c("a", "b")), "must be numeric")
})

test_that("the Lorenz curve is Gini's own geometry", {
  x <- c(1, 1, 2, 6)
  l <- lorenz(x)
  expect_equal(nrow(l), length(x) + 1L)
  expect_equal(l$population[1L], 0)
  expect_equal(l$value[1L], 0)
  expect_equal(l$population[nrow(l)], 1)
  expect_equal(l$value[nrow(l)], 1)
  # the shares, by hand: sorted 1, 1, 2, 6 with a total of 10
  expect_equal(l$value, c(0, 0.1, 0.2, 0.4, 1))
  expect_equal(l$population, c(0, 0.25, 0.5, 0.75, 1))
  # the curve never rises above the diagonal, and is convex
  expect_true(all(l$value <= l$population + 1e-12))
  expect_true(all(diff(diff(l$value)) >= -1e-12))

  # GINI IS TWICE THE AREA between the diagonal and the curve, which
  # ties the two functions together
  for (x in list(c(1, 1, 2, 6), c(1, 2, 3, 4, 5), c(2, 2, 3, 100),
                 c(rep(1, 20), 50))) {
    l <- lorenz(x)
    area <- sum(diff(l$population) *
                  (l$value[-1] + l$value[-nrow(l)]) / 2)
    expect_equal(gini(x), 1 - 2 * area, tolerance = 1e-12)
  }
  e <- lorenz(rep(3, 5))
  expect_equal(e$value, e$population)
})

test_that("the top share counts whole units", {
  x <- c(rep(1, 90), rep(10, 10))
  t <- top_share(x, c(0.01, 0.05, 0.1, 0.25))
  # the top 10% of 100 units is 10 units, holding 100 of the total 190
  expect_equal(t$units, c(1L, 5L, 10L, 25L))
  expect_equal(t$share[3L], 100 / 190)
  s <- sort(x, decreasing = TRUE)
  for (i in seq_len(nrow(t))) {
    expect_equal(t$share[i], sum(s[seq_len(t$units[i])]) / sum(s))
  }
  # the count ROUNDS UP, so the top 10% of 25 units is three of them
  expect_equal(top_share(seq_len(25), 0.1)$units, 3L)
  expect_equal(top_share(x, 1)$share, 1)
  expect_equal(top_share(x, 1)$units, 100L)
  expect_equal(top_share(x, 0)$units, 0L)
  expect_equal(top_share(x, 0)$share, 0)
  m <- top_share(x, seq(0.05, 1, by = 0.05))
  expect_true(all(diff(m$share) >= -1e-12))
  expect_true(is.na(top_share(x, 1.5)$share))
  expect_true(is.na(top_share(x, -0.1)$share))
  expect_true(is.na(top_share(numeric(0), 0.1)$share))
})

test_that("the Hurwitz zeta matches its published values", {
  # the Riemann zeta at even integers has a closed form
  expect_equal(hurwitz_zeta(2), pi^2 / 6, tolerance = 1e-13)
  expect_equal(hurwitz_zeta(4), pi^4 / 90, tolerance = 1e-13)
  expect_equal(hurwitz_zeta(6), pi^6 / 945, tolerance = 1e-13)
  # and Apery's constant at three
  expect_equal(hurwitz_zeta(3), 1.2020569031595943, tolerance = 1e-13)
  expect_equal(hurwitz_zeta(1.5), 2.612375348685488, tolerance = 1e-11)
  # shifting the lower limit removes exactly the leading term, which is
  # a functional identity rather than a numerical coincidence
  for (s in c(1.2, 2, 2.5, 4, 9)) {
    for (q in c(1, 2, 3.5, 10)) {
      expect_equal(hurwitz_zeta(s, q) - hurwitz_zeta(s, q + 1),
                   q^-s, tolerance = 1e-12)
    }
  }
  expect_equal(hurwitz_zeta(2, 2), pi^2 / 6 - 1, tolerance = 1e-13)
  expect_equal(hurwitz_zeta(c(2, 4)), c(pi^2 / 6, pi^4 / 90),
               tolerance = 1e-13)
  expect_true(all(diff(hurwitz_zeta(seq(1.5, 10, by = 0.5))) < 0))
  expect_equal(hurwitz_zeta(60), 1, tolerance = 1e-12)
  # outside the domain of convergence there is no value to return
  expect_true(is.na(hurwitz_zeta(1)))
  expect_true(is.na(hurwitz_zeta(0.5)))
  expect_true(is.na(hurwitz_zeta(2, 0)))
  expect_true(is.na(hurwitz_zeta(2, -1)))
})

test_that("the tail index recovers an exponent it was given", {
  # A CONTINUOUS Pareto tail: the closed-form Hill estimator is the
  # maximum-likelihood one here, so it should land on the truth.
  set.seed(1)
  for (a in c(1.5, 2, 3)) {
    x <- (1 - stats::runif(20000))^(-1 / a)
    f <- hill_tail_index(x, x_min = 1, discrete = FALSE)
    expect_equal(f$alpha, a + 1, tolerance = 0.05)
    expect_lt(f$ks, 0.02)
    expect_match(f$method, "continuous")
  }

  # A DISCRETE power law at a threshold of one, which is where
  # administrative counts start. The continuity-corrected closed form is
  # an asymptotic approximation IN the threshold and is badly biased
  # here; maximising the zeta likelihood is not.
  k <- 1:20000
  for (al in c(2, 2.5, 3)) {
    p <- k^(-al) / sum(k^(-al))
    set.seed(11)
    z <- sample(k, 20000L, replace = TRUE, prob = p)
    exact <- hill_tail_index(z, x_min = 1)
    approx <- hill_tail_index(z, x_min = 1, approx = TRUE)
    expect_equal(exact$alpha, al, tolerance = 0.05)
    expect_match(exact$method, "exact discrete")
    # the exact fit is close; the approximation is not, and its own
    # goodness-of-fit statistic says so rather than leaving the reader
    # to trust the number
    expect_lt(exact$ks, 0.01)
    expect_gt(approx$ks, 0.1)
    expect_lt(approx$alpha, al - 0.1)
  }

  # data that is NOT a power law gets an alpha and a large distance, so
  # the distance is the thing to read
  set.seed(5)
  g <- stats::rpois(5000L, 4) + 1L
  expect_gt(hill_tail_index(g, x_min = 1)$ks, 0.2)

  # the standard error shrinks with the tail's size
  k2 <- 1:5000
  p2 <- k2^(-2.5) / sum(k2^(-2.5))
  set.seed(3)
  small <- hill_tail_index(sample(k2, 200L, TRUE, p2), x_min = 1)
  set.seed(3)
  big <- hill_tail_index(sample(k2, 20000L, TRUE, p2), x_min = 1)
  expect_lt(big$se, small$se)

  # a threshold selects the tail, and is reported back
  t3 <- hill_tail_index(c(1, 1, 1, 5, 6, 7, 8, 20), x_min = 5)
  expect_equal(t3$x_min, 5)
  expect_equal(t3$n_tail, 5L)
  # a short tail still gets an estimate, marked as not to be leaned on
  short <- hill_tail_index(c(3, 4, 5, 9), x_min = 3)
  expect_true(is.finite(short$alpha))
  expect_false(short$reliable)
  expect_equal(short$n_tail, 4L)
  # the flag turns over at the sample size the literature gives, and is
  # about the sample size rather than about the fit
  expect_true(hill_tail_index(sample(k2, 200L, TRUE, p2),
                              x_min = 1)$reliable)
  # below the minimum there is nothing to estimate from
  expect_true(is.na(hill_tail_index(c(3, 4), x_min = 3)$alpha))
  expect_match(hill_tail_index(c(3, 4), x_min = 3)$method, "too few")
  expect_true(is.na(hill_tail_index(numeric(0), x_min = 1)$alpha))
  # and the minimum is settable
  expect_true(is.finite(hill_tail_index(c(3, 4), x_min = 3,
                                        min_tail = 2L)$alpha))
  auto <- hill_tail_index(c(rep(1, 100), 2:60))
  expect_true(is.finite(auto$x_min))
  expect_error(hill_tail_index(1:10, x_min = 0), "must be positive")
})

test_that("Cramer's V agrees with the chi-square it is built on", {
  tbl <- rbind(c(120, 80), c(40, 160))
  got <- cramers_v(tbl, bias_correct = FALSE)
  ct <- stats::chisq.test(tbl, correct = FALSE)
  expect_equal(got$chisq, as.numeric(ct$statistic))
  expect_equal(got$p_value, as.numeric(ct$p.value))
  expect_equal(got$df, 1L)
  expect_equal(got$n, 400)
  # V is phi for a 2x2 table: the square root of chi-square over n
  expect_equal(got$v, sqrt(as.numeric(ct$statistic) / 400))

  none <- cramers_v(rbind(c(100, 100), c(100, 100)))
  expect_equal(none$v, 0)
  expect_equal(none$p_value, 1)
  perfect <- cramers_v(rbind(c(100, 0), c(0, 100)), bias_correct = FALSE)
  expect_equal(perfect$v, 1)
  expect_true(got$v >= 0 && got$v <= 1)

  # Bergsma's correction reduces V, and reduces it most in a sparse
  # table -- where the uncorrected figure reports the table's size
  # rather than its association
  sparse <- rbind(c(3, 1), c(1, 3))
  raw <- cramers_v(sparse, bias_correct = FALSE)$v
  corrected <- cramers_v(sparse)$v
  expect_lt(corrected, raw)
  # on plenty of data the two nearly agree
  big <- rbind(c(3000, 1000), c(1000, 3000))
  expect_equal(cramers_v(big)$v, cramers_v(big, bias_correct = FALSE)$v,
               tolerance = 0.01)

  # a small expected count makes the chi-square approximation
  # unreliable, so it is counted and the p-value permuted instead
  expect_gt(cramers_v(sparse)$cells_below, 0L)
  expect_match(cramers_v(sparse)$method, "permutation")
  expect_match(cramers_v(tbl)$method, "approximation")
  expect_equal(cramers_v(tbl)$cells_below, 0L)
  expect_true(cramers_v(sparse)$p_value > 0 &&
                cramers_v(sparse)$p_value <= 1)

  three <- rbind(c(50, 30, 20), c(20, 50, 30), c(30, 20, 50))
  t3 <- cramers_v(three, bias_correct = FALSE)
  expect_equal(t3$df, 4L)
  expect_equal(t3$v, sqrt(as.numeric(
    stats::chisq.test(three, correct = FALSE)$statistic) / (300 * 2)))

  # degenerate tables degrade rather than erroring
  expect_true(is.na(cramers_v(matrix(1:3, nrow = 1))$v))
  expect_match(cramers_v(matrix(1:3, nrow = 1))$method, "too small")
  expect_true(is.na(cramers_v(matrix(0, 2, 2))$v))
  expect_match(cramers_v(matrix(0, 2, 2))$method, "empty")
  expect_error(cramers_v(rbind(c(-1, 2), c(3, 4))), "negative counts")
})

test_that("the trend test is Kendall's tau against the period", {
  # tau from this and from cor.test must agree, since both are S over
  # the number of pairs
  for (y in list(c(1, 2, 3, 4, 5), c(5, 4, 3, 2, 1),
                 c(402, 377, 190, 268, 331), c(1, 3, 2, 5, 4, 6))) {
    got <- trend_test(y)
    ref <- suppressWarnings(
      stats::cor.test(seq_along(y), y, method = "kendall"))
    expect_equal(got$tau, as.numeric(ref$estimate), tolerance = 1e-9)
  }
  up <- trend_test(1:6)
  expect_equal(up$tau, 1)
  expect_equal(up$S, 15)
  expect_equal(trend_test(6:1)$S, -15)
  expect_equal(trend_test(6:1)$tau, -1)
  # the slope is the resistant one: exactly one per period here
  expect_equal(up$slope, 1)
  expect_equal(trend_test(seq(10, 50, by = 10))$slope, 10)

  # the exact p-value is a count of orderings. At n = 5 only two of the
  # 120 orderings are monotone, so a monotone series has p = 2/120.
  five <- trend_test(1:5)
  expect_equal(five$p_value, 2 / 120)
  expect_match(five$method, "exact over all 120")
  expect_equal(trend_test(1:5, alternative = "increasing")$p_value,
               1 / 120)
  expect_equal(trend_test(1:5, alternative = "decreasing")$p_value, 1)
  # and it agrees with cor.test's own exact p-values
  for (y in list(c(1, 3, 2, 4, 5), c(2, 1, 4, 3, 5), c(3, 1, 2, 5, 4))) {
    ref <- suppressWarnings(
      stats::cor.test(seq_along(y), y, method = "kendall", exact = TRUE))
    expect_equal(trend_test(y)$p_value, as.numeric(ref$p.value),
                 tolerance = 1e-9)
  }
  # above the enumeration limit the approximation takes over, and says so
  long <- trend_test(c(1, 3, 2, 5, 4, 7, 6, 9, 8, 11))
  expect_match(long$method, "normal approximation")
  expect_lt(long$p_value, 0.01)
  expect_match(trend_test(1:5, exact = FALSE)$method, "normal")

  # one aberrant period does not make a trend, which is the point of a
  # rank test and a median slope
  expect_gt(trend_test(c(100, 100, 100, 100, 900))$p_value, 0.05)
  expect_equal(trend_test(c(100, 100, 100, 100, 900))$slope, 0)

  # ties reduce the variance of S, and the correction is applied
  flat <- trend_test(c(5, 5, 5, 5, 5))
  expect_equal(flat$S, 0)
  expect_equal(flat$var_S, 0)
  expect_equal(flat$p_value, 1)

  t <- trend_test(c(402, 377, 190, 268, 331))
  expect_lte(t$slope_lower, t$slope)
  expect_gte(t$slope_upper, t$slope)

  d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
  expect_equal(trend_test(d, value = "n", period = "year")$slope, t$slope)
  expect_equal(trend_test(d$n, x = d$year)$slope, t$slope)
  # unevenly spaced periods change the slope, since it is per unit of x
  expect_false(isTRUE(all.equal(
    trend_test(c(1, 2, 3), x = c(1, 2, 10))$slope, 1)))
  expect_error(trend_test(d, value = "nope"), "not found")
  expect_error(trend_test(d, value = "n", period = "nope"), "not found")
  expect_error(trend_test(data.frame(a = 1)), "`value` is required")
  expect_error(trend_test(c(1, 2)), "at least three periods")
  expect_error(trend_test(1:5, x = 1:3), "same length")
})

test_that("the step test uses the scan's own null, not the best split's", {
  s <- step_change(c(100, 104, 98, 60, 63, 58))
  expect_equal(s$index, 3L)
  expect_equal(s$break_after, 3)
  expect_equal(s$before, mean(c(100, 104, 98)))
  expect_equal(s$after, mean(c(60, 63, 58)))
  expect_equal(s$difference, s$after - s$before)
  expect_lt(s$difference, 0)
  expect_match(s$method, "exact over all 720")

  # PURE NOISE must not produce a significant break. Comparing the best
  # split against its own null would: the maximum over four splits is
  # not distributed like one split's statistic.
  ps <- vapply(seq_len(30L), function(i) {
    set.seed(1000L + i)
    step_change(stats::rnorm(10), n_perm = 499L, seed = i)$p_value
  }, 0)
  expect_lt(sum(ps < 0.05), 6L)
  expect_true(all(ps >= 0 & ps <= 1))

  # a permutation p-value can never be exactly zero: the observed
  # arrangement is one of the arrangements and counts in its own null
  expect_gt(step_change(c(1, 1, 1, 100, 100, 100))$p_value, 0)

  # A PERFECT step has zero variation inside each segment. A studentised
  # statistic is infinite there and would be discarded as inadmissible,
  # so the clearest possible break would be reported as no break at all.
  perfect <- step_change(c(1, 1, 1, 9, 9, 9), min_segment = 3L)
  expect_equal(perfect$index, 3L)
  expect_equal(perfect$before, 1)
  expect_equal(perfect$after, 9)

  # An exact permutation test on six points has a FLOOR. The only
  # orderings that separate three low values from three high ones are
  # the 3! * 3! arrangements within each side, twice for the two
  # directions, so p cannot fall below (1 + 72) / (1 + 720) however
  # clear the step is: six points are six points.
  clear <- step_change(c(1, 2, 1, 100, 101, 99))
  expect_equal(clear$p_value, (1 + 2 * 36) / (1 + 720), tolerance = 1e-9)
  expect_equal(clear$index, 3L)
  # With more periods the floor drops, by the same combinatorial
  # argument: eight points split four and four give 2 * (4!)^2 / 8!,
  # about 0.029. The sampled p-value should sit near that floor and
  # below the six-point one, which is the whole gain from two more
  # years of data.
  floor6 <- (1 + 2 * factorial(3)^2) / (1 + 720)
  floor8 <- 2 * factorial(4)^2 / factorial(8)
  eight <- step_change(c(1, 2, 1, 2, 100, 101, 99, 100),
                       n_perm = 4999L, seed = 5L)
  expect_lt(eight$p_value, floor6)
  # 4999 samples of a probability near 0.029 carry a relative standard
  # error of about 8%, so the tolerance is on that scale rather than on
  # the arithmetic's
  expect_equal(eight$p_value, floor8, tolerance = 0.25)
  expect_gte(eight$p_value, floor8 * 0.9)
  expect_equal(eight$index, 4L)

  expect_error(step_change(c(1, 2, 3), min_segment = 2L),
               "at least 4 periods")

  # the periods label the break without entering the arithmetic
  lab <- step_change(c(100, 104, 98, 60, 63, 58), x = 2018:2023)
  expect_equal(lab$break_after, 2020)
  expect_equal(lab$index, 3L)
  expect_equal(lab$difference, s$difference)

  # the p-value is reproducible, and does not disturb the caller's RNG
  set.seed(99)
  y <- stats::rnorm(14)
  a <- step_change(y, n_perm = 199L, seed = 7L)$p_value
  b <- step_change(y, n_perm = 199L, seed = 7L)$p_value
  expect_equal(a, b)
  set.seed(99)
  expect_equal(stats::rnorm(14), y)
  set.seed(123)
  keep <- stats::runif(1)
  set.seed(123)
  invisible(step_change(y, n_perm = 99L, seed = 3L))
  expect_equal(stats::runif(1), keep)
})

test_that("the count trend is glm's Poisson fit", {
  set.seed(3)
  y <- stats::rpois(10L, lambda = 200 * 0.85^(0:9))
  got <- count_trend(y)
  xc <- seq_along(y) - mean(seq_along(y))
  ref <- stats::glm(y ~ xc, family = stats::poisson())
  # the rate ratio and its standard error must be glm's, because the
  # model is the same model
  expect_equal(got$log_slope, as.numeric(stats::coef(ref)[2L]),
               tolerance = 1e-8)
  expect_equal(got$rate_ratio, exp(as.numeric(stats::coef(ref)[2L])),
               tolerance = 1e-8)
  expect_equal(got$se, summary(ref)$coefficients[2L, 2L],
               tolerance = 1e-6)
  expect_equal(unname(got$fitted), unname(stats::fitted(ref)),
               tolerance = 1e-7)
  expect_lt(got$rate_ratio, 1)
  expect_lt(got$upper, 1)
  expect_lt(got$p_value, 0.001)
  expect_lt(got$lower, got$rate_ratio)
  expect_gt(got$upper, got$rate_ratio)
  expect_false(got$overdispersed)

  # with an OFFSET the trend is in the rate, not in the count: a count
  # that rises while its denominator rises faster is a falling rate
  up <- c(20, 25, 30)
  off <- c(1000, 1500, 2500)
  r <- count_trend(up, offset = off)
  expect_lt(r$rate_ratio, 1)
  ro <- stats::glm(up ~ I(seq_along(up) - mean(seq_along(up))),
                   family = stats::poisson(), offset = log(off))
  expect_equal(r$log_slope, as.numeric(stats::coef(ro)[2L]),
               tolerance = 1e-7)
  # and without it the same counts are a rising trend
  expect_gt(count_trend(up)$rate_ratio, 1)

  # overdispersion widens the interval rather than being ignored, since
  # a Poisson interval assumes a dispersion of one
  set.seed(4)
  od <- stats::rnbinom(20L, mu = 100, size = 1.2)
  o <- count_trend(od)
  expect_true(o$overdispersed)
  expect_gt(o$dispersion, 1.5)
  expect_match(o$method, "quasi-Poisson")
  po <- stats::glm(od ~ I(seq_along(od) - mean(seq_along(od))),
                   family = stats::poisson())
  expect_gt(o$se, summary(po)$coefficients[2L, 2L])
  # and the point estimate is unchanged by the dispersion, which scales
  # only the standard error
  expect_equal(o$log_slope, as.numeric(stats::coef(po)[2L]),
               tolerance = 1e-7)

  flat <- count_trend(rep(100L, 8L))
  expect_equal(flat$rate_ratio, 1, tolerance = 1e-6)
  expect_gt(flat$p_value, 0.9)

  expect_error(count_trend(c(1.5, 2, 3)), "whole numbers")
  expect_error(count_trend(c(-1, 2, 3)), "whole numbers")
  expect_error(count_trend(c(1, 2)), "at least three")
  expect_error(count_trend(c(1, 2, 3), offset = c(1, 2)), "same length")
  expect_error(count_trend(c(1, 2, 3), offset = c(1, 0, 2)), "positive")
  expect_error(count_trend(c(1, 2, 3), x = 1:2), "same length")
})
