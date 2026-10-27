# Banded categories, concentration, association and short-series trend:
# the statistics a published administrative table needs.
#
# Anchors outside the module: pi^2/6, pi^4/90 and Apery's constant for
# the Hurwitz zeta; the mean-absolute-difference definition of Gini,
# computed independently; stats::cor.test's Kendall tau; stats::glm's
# Poisson fit; stats::chisq.test; simulation from distributions whose
# parameters are known; and closed forms recomputed by hand.

test_that("band labels parse to the bounds they state", {
  b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
  expect_identical(b$lower, c(1, 2, 6, 11))
  expect_identical(b$upper, c(1, 5, 10, NA))
  expect_identical(b$openup, c(FALSE, FALSE, FALSE, TRUE))
  expect_identical(b$openlo, rep(FALSE, 4L))
  # "greater than 10" on integer data starts at 11, not at 10: the
  # difference is a whole unit of the quantity being measured
  expect_identical(prsbands("Greater than 10", intsca = FALSE)$lower, 10)

  # the age bands these datasets use
  a <- prsbands(c("18 to 24", "25 to 49", "50+"))
  expect_identical(a$lower, c(18, 25, 50))
  expect_identical(a$upper, c(24, 49, NA))
  expect_true(a$openup[3L])
  # "50+" includes 50; "over 50" does not
  expect_identical(prsbands("50+")$lower, 50)
  expect_identical(prsbands("over 50")$lower, 51)
  expect_identical(prsbands("50+", clsup = FALSE)$lower, 51)

  # open lower bands
  l <- prsbands(c("<18", "under 18", "less than 18", "17 or less"))
  expect_identical(l$upper, c(17, 17, 17, 17))
  expect_true(all(l$openlo))
  expect_true(all(is.na(l$lower)))

  # the dash family, which publishers mix freely
  for (lab in c("18-24", "18 - 24", "18–24", "18—24", "18 through 24")) {
    p <- prsbands(lab)
    expect_equal(p$lower, 18, info = lab)
    expect_equal(p$upper, 24, info = lab)
  }
  # an INCLUSIVE wording includes its own number and the exclusive one
  # starts a unit higher, so the two patterns must not shadow each other
  expect_identical(prsbands("65 and over")$lower, 65)
  expect_identical(prsbands("over 65")$lower, 66)
  expect_identical(prsbands("3 or more")$lower, 3)
  expect_identical(prsbands("more than 3")$lower, 4)
  expect_true(prsbands("3 or more")$openup)
  # and the same on the lower side
  expect_identical(prsbands("17 and under")$upper, 17)
  expect_identical(prsbands("under 17")$upper, 16)
  expect_identical(prsbands("17 or less")$upper, 17)
  expect_identical(prsbands("less than 17")$upper, 16)

  # an unrecognised label is reported as unparsed rather than guessed at
  u <- prsbands(c("unknown", "not stated", "", NA))
  expect_true(all(is.na(u$lower)))
  expect_true(all(is.na(u$upper)))
  expect_identical(nrow(u), 4L)
  expect_identical(u$label[1L], "unknown")
  expect_equal(prsbands("1.5 to 2.5")$upper, 2.5)
})

test_that("a band's representative value states its rule", {
  b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
  mid <- bandvals(b)
  expect_equal(mid$value[1:3], c(1, 3.5, 8))
  # the open band has no midpoint, so the value rests on an assumption
  # and the row is marked
  expect_identical(mid$assumed, c(FALSE, FALSE, FALSE, TRUE))
  expect_identical(mid$value[4L], (11 + 22) / 2)
  expect_identical(bandvals(b, openupcap = 40)$value[4L], (11 + 40) / 2)
  # the lower and upper rules bracket whatever the truth is
  lo <- bandvals(b, rule = "lower")$value
  hi <- bandvals(b, rule = "upper", openupcap = 40)$value
  expect_true(all(lo <= mid$value))
  expect_true(all(hi[1:3] >= mid$value[1:3]))
  expect_identical(lo, c(1, 2, 6, 11))
  g <- bandvals(b, rule = "geometric")$value
  expect_identical(g[2L], sqrt(2 * 5))
  # the geometric mean is undefined at zero, so the band falls back
  zero <- bandvals(prsbands("0 to 4"), rule = "geometric")$value
  expect_identical(zero, 2)
  ol <- bandvals(prsbands("under 18"), openloflr = 0)
  expect_equal(ol$value, 8.5)
  expect_true(ol$assumed)
  expect_equal(bandvals("2 to 5")$value, 3.5)
  expect_error(bandvals(data.frame(a = 1)), "prsbands")
})

test_that("expanding a banded table reproduces the counts", {
  x <- expbands(
    c("1", "2 to 5", "Greater than 5"),
    cnts = c(10, 4, 2),
    openupcap = 12
  )
  expect_length(x, 16L)
  expect_identical(sum(x == 1), 10L)
  expect_identical(sum(x == 3.5), 4L)
  expect_identical(sum(x == 9), 2L)
  # an unparseable band with a count is an error by default (dropping its
  # units in silence made every downstream statistic describe a fraction
  # of the data); with drpunp = TRUE it is left out, with a warning
  expect_error(expbands(c("1", "unknown"), cnts = c(3, 5)), "'unknown'")
  expect_warning(
    {
      y <- expbands(c("1", "unknown"), cnts = c(3, 5), drpunp = TRUE)
    },
    "could not be placed"
  )
  expect_length(y, 3L)
  expect_false(anyNA(y))
  expect_length(expbands(c("1", "2 to 5"), c(0, 0)), 0L)
  expect_error(expbands(c("1", "2 to 5"), cnts = 1), "2 bands")
  expect_error(expbands("1", cnts = -1), "non-negative")
})

test_that("the open band's cap is reported as the assumption it is", {
  b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
  counts <- c(1200, 430, 110, 38)
  s <- bandsens(b, counts)
  expect_s3_class(s, "rmbl_band_sensitivity")
  expect_true(all(c("cap", "value") %in% names(s)))
  expect_gt(nrow(s), 5L)
  expect_true(all(is.finite(s$value)))
  # a concentration measure RISES as the open band's cap rises, because
  # the same 38 units are given more of the total
  expect_true(all(diff(s$value) >= -1e-9))
  expect_true(is.finite(attr(s, "span")))
  expect_gt(attr(s, "span"), 0)
  m <- bandsens(b, counts, stat = mean)
  expect_true(all(diff(m$value) >= -1e-9))
  # at a given cap it agrees with computing it directly
  direct <- mean(expbands(b, counts, openupcap = m$cap[3L]))
  expect_identical(m$value[3L], direct)
  e <- bandsens(b, counts, caps = c(11, 50, 200))
  expect_identical(e$cap, c(11, 50, 200))
  expect_output(print(e), "Sensitivity to the open top band")
  expect_output(print(e), "span over the caps tried")
  # a closed set of bands has nothing to be sensitive to, and says so
  expect_error(
    bandsens(prsbands(c("1", "2 to 5")), c(1, 2)),
    "nothing to be sensitive to"
  )
  expect_error(bandsens(b, c(1, 2)), "4 bands")
})

test_that("Gini is the mean absolute difference over twice the mean", {
  # the definition, computed independently
  for (x in list(
    c(1, 2, 3, 4, 5),
    c(1, 1, 1, 8),
    c(3, 7),
    c(0, 0, 0, 5),
    rep(4, 7),
    c(2, 2, 3, 100)
  )) {
    want <- mean(abs(outer(x, x, "-"))) / (2 * mean(x))
    expect_equal(as.numeric(ginicoef(x)), want, tolerance = 1e-12)
  }
  expect_identical(as.numeric(ginicoef(rep(1, 10))), 0)
  expect_identical(as.numeric(ginicoef(rep(7.5, 100))), 0)
  # the MAXIMUM for n units is 1 - 1/n, not one: a Gini near one needs
  # many units as well as an uneven spread
  for (n in c(2L, 5L, 10L, 100L)) {
    expect_identical(as.numeric(ginicoef(c(rep(0, n - 1L), 1))), 1 - 1 / n)
  }
  # scale invariance: doubling every value changes no share
  x <- c(1, 4, 9, 16)
  expect_identical(as.numeric(ginicoef(x)), as.numeric(ginicoef(2 * x)))
  expect_identical(as.numeric(ginicoef(x)), as.numeric(ginicoef(1000 * x)))
  expect_identical(as.numeric(ginicoef(5)), 0)
  # a total of zero has no distribution to be unequal about: refused, not NA
  expect_error(ginicoef(c(0, 0, 0)), "every value is zero")
  expect_error(ginicoef(numeric(0)), "no values")
  expect_identical(
    as.numeric(ginicoef(c(1, 2, 3, NA))),
    as.numeric(ginicoef(c(1, 2, 3)))
  )
  expect_error(ginicoef(c(1, -1)), "non-negative")
  expect_error(ginicoef(c("a", "b")), "must be numeric")
})

test_that("the Lorenz curve is Gini's own geometry", {
  x <- c(1, 1, 2, 6)
  l <- lorenzc(x)
  expect_identical(nrow(l), length(x) + 1L)
  expect_identical(l$population[1L], 0)
  expect_identical(l$value[1L], 0)
  expect_identical(l$population[nrow(l)], 1)
  expect_identical(l$value[nrow(l)], 1)
  # the shares, by hand: sorted 1, 1, 2, 6 with a total of 10
  expect_equal(l$value, c(0, 0.1, 0.2, 0.4, 1))
  expect_equal(l$population, c(0, 0.25, 0.5, 0.75, 1))
  # the curve never rises above the diagonal, and is convex
  expect_true(all(l$value <= l$population + 1e-12))
  expect_true(all(diff(diff(l$value)) >= -1e-12))

  # GINI IS TWICE THE AREA between the diagonal and the curve, which
  # ties the two functions together
  for (x in list(
    c(1, 1, 2, 6),
    c(1, 2, 3, 4, 5),
    c(2, 2, 3, 100),
    c(rep(1, 20), 50)
  )) {
    l <- lorenzc(x)
    area <- sum(
      diff(l$population) *
        (l$value[-1] + l$value[-nrow(l)]) /
        2
    )
    expect_equal(as.numeric(ginicoef(x)), 1 - 2 * area, tolerance = 1e-12)
  }
  e <- lorenzc(rep(3, 5))
  expect_identical(e$value, e$population)
})

test_that("the top share counts whole units", {
  x <- c(rep(1, 90), rep(10, 10))
  t <- topshr(x, c(0.01, 0.05, 0.1, 0.25))
  # the top 10% of 100 units is 10 units, holding 100 of the total 190
  expect_identical(t$units, c(1L, 5L, 10L, 25L))
  expect_identical(t$share[3L], 100 / 190)
  s <- sort(x, decreasing = TRUE)
  for (i in seq_len(nrow(t))) {
    expect_identical(t$share[i], sum(s[seq_len(t$units[i])]) / sum(s))
  }
  # the count ROUNDS UP, so the top 10% of 25 units is three of them
  expect_identical(topshr(seq_len(25), 0.1)$units, 3L)
  expect_identical(topshr(x, 1)$share, 1)
  expect_identical(topshr(x, 1)$units, 100L)
  expect_identical(topshr(x, 0)$units, 0L)
  expect_identical(topshr(x, 0)$share, 0)
  m <- topshr(x, seq(0.05, 1, by = 0.05))
  expect_true(all(diff(m$share) >= -1e-12))
  expect_error(topshr(x, 1.5), "shares in \\[0, 1\\]")
  expect_error(topshr(x, -0.1), "shares in \\[0, 1\\]")
  expect_error(topshr(numeric(0), 0.1), "no values")
})

test_that("the Hurwitz zeta matches its published values", {
  # the Riemann zeta at even integers has a closed form
  expect_equal(hurwzeta(2), pi^2 / 6, tolerance = 1e-13)
  expect_equal(hurwzeta(4), pi^4 / 90, tolerance = 1e-13)
  expect_equal(hurwzeta(6), pi^6 / 945, tolerance = 1e-13)
  # and Apery's constant at three
  expect_equal(hurwzeta(3), 1.2020569031595943, tolerance = 1e-13)
  expect_equal(hurwzeta(1.5), 2.612375348685488, tolerance = 1e-11)
  # shifting the lower limit removes exactly the leading term, which is
  # a functional identity rather than a numerical coincidence
  for (s in c(1.2, 2, 2.5, 4, 9)) {
    for (q in c(1, 2, 3.5, 10)) {
      expect_equal(hurwzeta(s, q) - hurwzeta(s, q + 1), q^-s, tolerance = 1e-12)
    }
  }
  expect_equal(hurwzeta(2, 2), pi^2 / 6 - 1, tolerance = 1e-13)
  expect_equal(hurwzeta(c(2, 4)), c(pi^2 / 6, pi^4 / 90), tolerance = 1e-13)
  expect_true(all(diff(hurwzeta(seq(1.5, 10, by = 0.5))) < 0))
  expect_equal(hurwzeta(60), 1, tolerance = 1e-12)
  # outside the domain of convergence there is no value to return
  expect_true(is.na(hurwzeta(1)))
  expect_true(isTRUE(all.equal(hurwzeta(0.5), -1.4603545088095868)))
  expect_true(is.na(hurwzeta(2, 0)))
  expect_true(is.na(hurwzeta(2, -1)))
})

test_that("the tail index recovers an exponent it was given", {
  # A CONTINUOUS Pareto tail: the closed-form Hill estimator is the
  # maximum-likelihood one here, so it should land on the truth.
  set.seed(1)
  for (a in c(1.5, 2, 3)) {
    x <- (1 - stats::runif(20000))^(-1 / a)
    f <- hilltlidx(x, xmin = 1, discrete = FALSE)
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
    exact <- hilltlidx(z, xmin = 1)
    approx <- hilltlidx(z, xmin = 1, approx = TRUE)
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
  expect_gt(hilltlidx(g, xmin = 1)$ks, 0.2)

  # the standard error shrinks with the tail's size
  k2 <- 1:5000
  p2 <- k2^(-2.5) / sum(k2^(-2.5))
  set.seed(3)
  small <- hilltlidx(sample(k2, 200L, TRUE, p2), xmin = 1)
  set.seed(3)
  big <- hilltlidx(sample(k2, 20000L, TRUE, p2), xmin = 1)
  expect_lt(big$se, small$se)

  # a threshold selects the tail, and is reported back
  t3 <- hilltlidx(c(1, 1, 1, 5, 6, 7, 8, 20), xmin = 5)
  expect_identical(t3$xmin, 5)
  expect_identical(t3$ntl, 5L)
  # a short tail still gets an estimate, marked as not to be leaned on
  short <- hilltlidx(c(3, 4, 5, 9), xmin = 3)
  expect_true(is.finite(short$alpha))
  expect_false(short$reliable)
  expect_identical(short$ntl, 4L)
  # the flag turns over at the sample size the literature gives, and is
  # about the sample size rather than about the fit
  expect_true(hilltlidx(sample(k2, 200L, TRUE, p2), xmin = 1)$reliable)
  # below the minimum there is nothing to estimate from
  expect_true(is.na(hilltlidx(c(3, 4), xmin = 3)$alpha))
  expect_match(hilltlidx(c(3, 4), xmin = 3)$method, "too few")
  expect_error(hilltlidx(numeric(0), xmin = 1), "no positive")
  # and the minimum is settable
  expect_true(is.finite(hilltlidx(c(3, 4), xmin = 3, mintl = 2L)$alpha))
  auto <- hilltlidx(c(rep(1, 100), 2:60))
  expect_true(is.finite(auto$xmin))
  expect_error(hilltlidx(1:10, xmin = 0), "must be positive")
})

test_that("Cramer's V agrees with the chi-square it is built on", {
  tbl <- rbind(c(120, 80), c(40, 160))
  got <- cramerv(tbl, biascor = FALSE)
  ct <- stats::chisq.test(tbl, correct = FALSE)
  expect_identical(got$chisq, as.numeric(ct$statistic))
  expect_identical(got$p_value, as.numeric(ct$p.value))
  expect_identical(got$df, 1L)
  expect_identical(got$n, 400)
  # V is phi for a 2x2 table: the square root of chi-square over n
  expect_identical(got$v, sqrt(as.numeric(ct$statistic) / 400))

  none <- cramerv(rbind(c(100, 100), c(100, 100)))
  expect_identical(none$v, 0)
  expect_identical(none$p_value, 1)
  perfect <- cramerv(rbind(c(100, 0), c(0, 100)), biascor = FALSE)
  expect_identical(perfect$v, 1)
  expect_gte(got$v, 0)
  expect_lte(got$v, 1)

  # Bergsma's correction reduces V, and reduces it most in a sparse
  # table -- where the uncorrected figure reports the table's size
  # rather than its association
  sparse <- rbind(c(3, 1), c(1, 3))
  raw <- cramerv(sparse, biascor = FALSE)$v
  corrected <- cramerv(sparse)$v
  expect_lt(corrected, raw)
  # on plenty of data the two nearly agree
  big <- rbind(c(3000, 1000), c(1000, 3000))
  expect_equal(
    cramerv(big)$v,
    cramerv(big, biascor = FALSE)$v,
    tolerance = 0.01
  )

  # a small expected count makes the chi-square approximation
  # unreliable, so it is counted and the p-value permuted instead
  expect_gt(cramerv(sparse)$cellsbelow, 0L)
  expect_match(cramerv(sparse)$method, "permutation")
  expect_match(cramerv(tbl)$method, "approximation")
  expect_identical(cramerv(tbl)$cellsbelow, 0L)
  expect_gt(cramerv(sparse)$p_value, 0)
  expect_lte(cramerv(sparse)$p_value, 1)

  three <- rbind(c(50, 30, 20), c(20, 50, 30), c(30, 20, 50))
  t3 <- cramerv(three, biascor = FALSE)
  expect_identical(t3$df, 4L)
  expect_identical(
    t3$v,
    sqrt(
      as.numeric(
        stats::chisq.test(three, correct = FALSE)$statistic
      ) /
        (300 * 2)
    )
  )

  # degenerate tables degrade rather than erroring
  expect_true(is.na(cramerv(matrix(1:3, nrow = 1))$v))
  expect_match(cramerv(matrix(1:3, nrow = 1))$method, "too small")
  expect_true(is.na(cramerv(matrix(0, 2, 2))$v))
  expect_match(cramerv(matrix(0, 2, 2))$method, "empty")
  expect_error(cramerv(rbind(c(-1, 2), c(3, 4))), "negative counts")
})

test_that("the trend test is Kendall's tau against the period", {
  # tau from this and from cor.test must agree, since both are S over
  # the number of pairs
  for (y in list(
    c(1, 2, 3, 4, 5),
    c(5, 4, 3, 2, 1),
    c(402, 377, 190, 268, 331),
    c(1, 3, 2, 5, 4, 6)
  )) {
    got <- trndtst(y)
    ref <- suppressWarnings(
      stats::cor.test(seq_along(y), y, method = "kendall")
    )
    expect_equal(got$tau, as.numeric(ref$estimate), tolerance = 1e-9)
  }
  up <- trndtst(1:6)
  expect_identical(up$tau, 1)
  expect_identical(up$S, 15)
  expect_identical(trndtst(6:1)$S, -15)
  expect_identical(trndtst(6:1)$tau, -1)
  # the slope is the resistant one: exactly one per period here
  expect_identical(up$slope, 1)
  expect_identical(trndtst(seq(10, 50, by = 10))$slope, 10)

  # the exact p-value is a count of orderings. At n = 5 only two of the
  # 120 orderings are monotone, so a monotone series has p = 2/120.
  five <- trndtst(1:5)
  expect_identical(five$p_value, 2 / 120)
  expect_match(five$method, "exact over all 120")
  expect_identical(trndtst(1:5, alt = "increasing")$p_value, 1 / 120)
  expect_identical(trndtst(1:5, alt = "decreasing")$p_value, 1)
  # and it agrees with cor.test's own exact p-values
  for (y in list(c(1, 3, 2, 4, 5), c(2, 1, 4, 3, 5), c(3, 1, 2, 5, 4))) {
    ref <- suppressWarnings(
      stats::cor.test(seq_along(y), y, method = "kendall", exact = TRUE)
    )
    expect_equal(trndtst(y)$p_value, as.numeric(ref$p.value), tolerance = 1e-9)
  }
  # above the enumeration limit the approximation takes over, and says so
  long <- trndtst(c(1, 3, 2, 5, 4, 7, 6, 9, 8, 11))
  expect_match(long$method, "normal approximation")
  expect_lt(long$p_value, 0.01)
  expect_match(trndtst(1:5, exact = FALSE)$method, "normal")

  # one aberrant period does not make a trend, which is the point of a
  # rank test and a median slope
  expect_gt(trndtst(c(100, 100, 100, 100, 900))$p_value, 0.05)
  expect_identical(trndtst(c(100, 100, 100, 100, 900))$slope, 0)

  # ties reduce the variance of S, and the correction is applied
  flat <- trndtst(c(5, 5, 5, 5, 5))
  expect_identical(flat$S, 0)
  expect_identical(flat$var_S, 0)
  expect_identical(flat$p_value, 1)

  t <- trndtst(c(402, 377, 190, 268, 331))
  expect_lte(t$slopelo, t$slope)
  expect_gte(t$slopeup, t$slope)

  d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
  expect_identical(trndtst(d, value = "n", prd = "year")$slope, t$slope)
  expect_identical(trndtst(d$n, x = d$year)$slope, t$slope)
  # unevenly spaced periods change the slope, since it is per unit of x
  expect_false(isTRUE(all.equal(
    trndtst(c(1, 2, 3), x = c(1, 2, 10))$slope,
    1
  )))
  expect_error(trndtst(d, value = "nope"), "not found")
  expect_error(trndtst(d, value = "n", prd = "nope"), "not found")
  expect_error(trndtst(data.frame(a = 1)), "`value` is required")
  expect_error(trndtst(c(1, 2)), "at least three periods")
  expect_error(trndtst(1:5, x = 1:3), "same length")
})

test_that("the step test uses the scan's own null, not the best split's", {
  s <- stepchg(c(100, 104, 98, 60, 63, 58))
  expect_identical(s$index, 3L)
  expect_equal(s$breakafter, 3, tolerance = testthat::testthat_tolerance())
  expect_identical(s$before, mean(c(100, 104, 98)))
  expect_identical(s$after, mean(c(60, 63, 58)))
  expect_identical(s$difference, s$after - s$before)
  expect_lt(s$difference, 0)
  expect_match(s$method, "exact over all 720")

  # PURE NOISE must not produce a significant break. Comparing the best
  # split against its own null would: the maximum over four splits is
  # not distributed like one split's statistic.
  ps <- vapply(
    seq_len(30L),
    function(i) {
      set.seed(1000L + i)
      stepchg(stats::rnorm(10), nperm = 499L, seed = i)$p_value
    },
    0
  )
  expect_lt(sum(ps < 0.05), 6L)
  expect_true(all(ps >= 0 & ps <= 1))

  # a permutation p-value can never be exactly zero: the observed
  # arrangement is one of the arrangements and counts in its own null
  expect_gt(stepchg(c(1, 1, 1, 100, 100, 100))$p_value, 0)

  # A PERFECT step has zero variation inside each segment. A studentised
  # statistic is infinite there and would be discarded as inadmissible,
  # so the clearest possible break would be reported as no break at all.
  perfect <- stepchg(c(1, 1, 1, 9, 9, 9), minseg = 3L)
  expect_identical(perfect$index, 3L)
  expect_identical(perfect$before, 1)
  expect_identical(perfect$after, 9)

  # An exact permutation test on six points has a FLOOR. The only
  # orderings that separate three low values from three high ones are
  # the 3! * 3! arrangements within each side, twice for the two
  # directions, so p cannot fall below 72 / 720 however clear the step
  # is: six points are six points. (The observed ordering is one of the
  # 720; it was counted a second time, (1 + 72) / (1 + 720); CRAN stress
  # test of 0.5.14.)
  clear <- stepchg(c(1, 2, 1, 100, 101, 99))
  expect_equal(clear$p_value, (2 * 36) / 720, tolerance = 1e-9)
  expect_identical(clear$index, 3L)
  # With more periods the floor drops, by the same combinatorial
  # argument: eight points split four and four give 2 * (4!)^2 / 8!,
  # about 0.029. The sampled p-value should sit near that floor and
  # below the six-point one, which is the whole gain from two more
  # years of data.
  floor6 <- (1 + 2 * factorial(3)^2) / (1 + 720)
  floor8 <- 2 * factorial(4)^2 / factorial(8)
  eight <- stepchg(c(1, 2, 1, 2, 100, 101, 99, 100), nperm = 4999L, seed = 5L)
  expect_lt(eight$p_value, floor6)
  # 4999 samples of a probability near 0.029 carry a relative standard
  # error of about 8%, so the tolerance is on that scale rather than on
  # the arithmetic's
  expect_equal(eight$p_value, floor8, tolerance = 0.25)
  expect_gte(eight$p_value, floor8 * 0.9)
  expect_identical(eight$index, 4L)

  expect_error(stepchg(c(1, 2, 3), minseg = 2L), "at least 4 periods")

  # the periods label the break without entering the arithmetic
  lab <- stepchg(c(100, 104, 98, 60, 63, 58), x = 2018:2023)
  expect_equal(lab$breakafter, 2020, tolerance = testthat::testthat_tolerance())
  expect_identical(lab$index, 3L)
  expect_identical(lab$difference, s$difference)

  # the p-value is reproducible, and does not disturb the caller's RNG
  set.seed(99)
  y <- stats::rnorm(14)
  a <- stepchg(y, nperm = 199L, seed = 7L)$p_value
  b <- stepchg(y, nperm = 199L, seed = 7L)$p_value
  expect_identical(a, b)
  set.seed(99)
  expect_identical(stats::rnorm(14), y)
  set.seed(123)
  keep <- stats::runif(1)
  set.seed(123)
  invisible(stepchg(y, nperm = 99L, seed = 3L))
  expect_identical(stats::runif(1), keep)
})

test_that("the count trend is glm's Poisson fit", {
  set.seed(3)
  y <- stats::rpois(10L, lambda = 200 * 0.85^(0:9))
  got <- cnttrnd(y)
  xc <- seq_along(y) - mean(seq_along(y))
  ref <- stats::glm(y ~ xc, family = stats::poisson())
  # the rate ratio and its standard error must be glm's, because the
  # model is the same model
  expect_equal(got$logslope, as.numeric(stats::coef(ref)[2L]), tolerance = 1e-8)
  expect_equal(
    got$rateratio,
    exp(as.numeric(stats::coef(ref)[2L])),
    tolerance = 1e-8
  )
  expect_equal(got$se, summary(ref)$coefficients[2L, 2L], tolerance = 1e-6)
  expect_equal(unname(got$fitted), unname(stats::fitted(ref)), tolerance = 1e-7)
  expect_lt(got$rateratio, 1)
  expect_lt(got$upper, 1)
  expect_lt(got$p_value, 0.001)
  expect_lt(got$lower, got$rateratio)
  expect_gt(got$upper, got$rateratio)
  expect_false(got$overdispersed)

  # with an OFFSET the trend is in the rate, not in the count: a count
  # that rises while its denominator rises faster is a falling rate
  up <- c(20, 25, 30)
  off <- c(1000, 1500, 2500)
  r <- cnttrnd(up, offset = off)
  expect_lt(r$rateratio, 1)
  ro <- stats::glm(
    up ~ I(seq_along(up) - mean(seq_along(up))),
    family = stats::poisson(),
    offset = log(off)
  )
  expect_equal(r$logslope, as.numeric(stats::coef(ro)[2L]), tolerance = 1e-7)
  # and without it the same counts are a rising trend
  expect_gt(cnttrnd(up)$rateratio, 1)

  # overdispersion widens the interval rather than being ignored, since
  # a Poisson interval assumes a dispersion of one
  set.seed(4)
  od <- stats::rnbinom(20L, mu = 100, size = 1.2)
  o <- cnttrnd(od)
  expect_true(o$overdispersed)
  expect_gt(o$dispersion, 1.5)
  expect_match(o$method, "quasi-Poisson")
  po <- stats::glm(
    od ~ I(seq_along(od) - mean(seq_along(od))),
    family = stats::poisson()
  )
  expect_gt(o$se, summary(po)$coefficients[2L, 2L])
  # and the point estimate is unchanged by the dispersion, which scales
  # only the standard error
  expect_equal(o$logslope, as.numeric(stats::coef(po)[2L]), tolerance = 1e-7)

  flat <- cnttrnd(rep(100L, 8L))
  expect_equal(flat$rateratio, 1, tolerance = 1e-6)
  expect_gt(flat$p_value, 0.9)

  expect_error(cnttrnd(c(1.5, 2, 3)), "whole numbers")
  expect_error(cnttrnd(c(-1, 2, 3)), "whole numbers")
  expect_error(cnttrnd(c(1, 2)), "at least three")
  expect_error(cnttrnd(c(1, 2, 3), offset = c(1, 2)), "same length")
  expect_error(cnttrnd(c(1, 2, 3), offset = c(1, 0, 2)), "positive")
  expect_error(cnttrnd(c(1, 2, 3), x = 1:2), "same length")
})
