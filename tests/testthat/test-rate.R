# Rates, shares and rate change.
#
# Every interval here is checked against something that could disagree
# with it: stats::poisson.test for the rate and the rate ratio,
# stats::prop.test(correct = FALSE) for the Wilson share, and yoy()
# itself for the case where the two denominators are equal and the two
# constructions must coincide. A test that only compared these
# functions to themselves would pass on any sound-looking arithmetic,
# which is exactly how a wrong interval survives.

test_that("the rate interval is stats::poisson.test's, exactly", {
  for (cs in list(c(412, 120000), c(77, 41000), c(3, 9500),
                  c(0, 5000), c(1, 100))) {
    got <- rate(cs[1], cs[2], per = "100k")
    want <- stats::poisson.test(cs[1], cs[2])$conf.int * 1e5
    expect_equal(c(got$lower, got$upper), as.numeric(want),
                 info = paste("count", cs[1]))
  }
})

test_that("a zero count has a lower limit of zero, not a negative rate", {
  z <- rate(0, 5000, per = "100k")
  expect_identical(z$lower, 0)
  expect_gt(z$upper, 0)
  expect_identical(z$rate, 0)
})

test_that("the share interval is Wilson's, not the normal approximation", {
  for (cs in list(c(412, 492), c(77, 492), c(3, 492), c(0, 100),
                  c(100, 100))) {
    got <- share(cs[1], total = cs[2])
    want <- stats::prop.test(cs[1], cs[2], correct = FALSE)$conf.int * 100
    expect_equal(c(got$lower, got$upper), as.numeric(want),
                 info = paste("count", cs[1]))
  }
  # the normal approximation would run below zero here; Wilson does not
  expect_gte(share(3, total = 492)$lower, 0)
  expect_lte(share(100, total = 100)$upper, 100)
})

test_that("the rate-ratio interval is the two-sample poisson.test", {
  d <- data.frame(year = c(2022, 2023), stops = c(70, 455),
                  residents = c(41000, 125000))
  rc <- rate_change(d, stops, residents, year, per = "100k")
  want <- stats::poisson.test(c(455, 70), c(125000, 41000))$conf.int
  expect_equal(c(1 + rc$pct_lower[2] / 100, 1 + rc$pct_upper[2] / 100),
               as.numeric(want))
})

test_that("equal denominators reduce to yoy()'s interval exactly", {
  # This is the property that says the exposure correction is applied
  # in the right direction: with nothing to correct for, the two
  # constructions must give the same numbers to the last digit.
  e <- data.frame(year = c(2022, 2023), n = c(70, 90),
                  pop = c(50000, 50000))
  rc <- rate_change(e, n, pop, year, per = 1000)
  y <- yoy(e, n, year, units = "count")
  expect_equal(rc$pct_change[2], y$pct_change[2])
  expect_equal(rc$pct_lower[2], y$pct_lower[2])
  expect_equal(rc$pct_upper[2], y$pct_upper[2])
})

test_that("a rate is not a share, and the difference shows", {
  d <- data.frame(division = c("North", "South", "East"),
                  stops = c(412, 77, 3),
                  residents = c(120000, 41000, 9500))
  r <- rate(d, stops, residents, by = "division", per = "100k")
  s <- share(d, stops, by = "division")
  # shares over a complete grouping sum to 100; rates do not sum to
  # anything, because their denominators are different populations
  expect_equal(sum(s$share), 100)
  expect_false(isTRUE(all.equal(sum(r$rate), 100)))
  # East has the smallest count and the largest share interval, in
  # relative terms, and the largest rate interval too
  expect_gt((s$upper - s$lower)[s$division == "East"] / s$share[s$division == "East"],
            (s$upper - s$lower)[s$division == "North"] / s$share[s$division == "North"])
})

test_that("the per denominator scales the rate and its interval together", {
  d <- data.frame(n = 412, pop = 120000)
  per_1k <- rate(d, n, pop, per = 1000)
  per_100k <- rate(d, n, pop, per = "100k")
  expect_equal(per_100k$rate, per_1k$rate * 100)
  expect_equal(per_100k$lower, per_1k$lower * 100)
  expect_equal(per_100k$upper, per_1k$upper * 100)
  # every shorthand means what it says
  expect_identical(rate(d, n, pop, per = "1k")$rate,
                   rate(d, n, pop, per = 1e3)$rate)
  expect_identical(rate(d, n, pop, per = "10k")$rate,
                   rate(d, n, pop, per = 1e4)$rate)
  expect_identical(rate(d, n, pop, per = "100k")$rate,
                   rate(d, n, pop, per = 1e5)$rate)
  expect_identical(rate(d, n, pop, per = "1m")$rate,
                   rate(d, n, pop, per = 1e6)$rate)
  expect_identical(rate(d, n, pop, per = "per 100k")$rate,
                   rate(d, n, pop, per = 1e5)$rate)
})

test_that("a denominator mistyped as a word is refused, not guessed", {
  d <- data.frame(n = 412, pop = 120000)
  expect_error(rate(d, n, pop, per = "hundred thousand"), "not recognised")
  expect_error(rate(d, n, pop, per = 0), "positive")
  expect_error(rate(d, n, pop, per = -1000), "positive")
  expect_error(rate(d, n, pop, per = NA), "positive")
})

test_that("the comparison period is matched on the period, not the row", {
  # 2023 against 2020 is not a year-over-year change, and the gap is
  # reported rather than silently bridged
  g <- data.frame(year = c(2020, 2023), n = c(10, 20), pop = c(1000, 1000))
  rc <- rate_change(g, n, pop, year)
  expect_true(all(is.na(rc$pct_change)))
  expect_identical(unique(rc$flag), "no comparison period")
  # with the year present, the comparison is made
  ok <- data.frame(year = c(2022, 2023), n = c(10, 20), pop = c(1000, 1000))
  expect_equal(rate_change(ok, n, pop, year)$pct_change[2], 100)
})

test_that("exposure is required to be exposure", {
  bad <- data.frame(n = 5, pop = 0)
  expect_error(rate(bad, n, pop), "positive")
  expect_error(rate(data.frame(n = -1, pop = 10), n, pop), "non-negative")
  # a Poisson interval on a fractional count is not defined
  expect_error(rate(data.frame(n = 2.5, pop = 10), n, pop), "whole numbers")
  # a count larger than the total is not a share of it
  expect_error(share(data.frame(n = 20), n, total = 10), "larger than the total")
})

test_that("grouping aggregates before dividing, not after", {
  # Two rows for one division must give one rate computed from the
  # summed count over the summed population -- the mean of two rates
  # is a different and usually wrong number.
  d <- data.frame(division = c("North", "North"), n = c(200, 212),
                  pop = c(60000, 60000))
  r <- rate(d, n, pop, by = "division", per = "100k")
  expect_identical(nrow(r), 1L)
  expect_equal(r$rate, 1e5 * 412 / 120000)
  expect_equal(r$count, 412)
  expect_equal(r$population, 120000)
})

test_that("min_count flags a small count without hiding the rate", {
  d <- data.frame(division = c("North", "East"), n = c(412, 3),
                  pop = c(120000, 9500))
  r <- rate(d, n, pop, by = "division", per = "100k", min_count = 5)
  east <- r[r$division == "East", ]
  expect_match(east$flag, "at or below 5")
  expect_false(is.na(east$rate))
  expect_true(is.na(r$flag[r$division == "North"]))
  # and in a change, the withheld percent is the one off the tiny base
  g <- data.frame(year = c(2022, 2023), n = c(2, 40), pop = c(1000, 1000))
  rc <- rate_change(g, n, pop, year, min_count = 5)
  expect_true(is.na(rc$pct_change[2]))
  expect_match(rc$flag[2], "earlier count at or below 5")
})

test_that("vectors and data frames agree", {
  d <- data.frame(n = 412, pop = 120000)
  expect_equal(rate(d, n, pop, per = "100k")$rate,
               rate(412, 120000, per = "100k")$rate)
  expect_equal(share(d, n, total = 492)$share, share(412, total = 492)$share)
})

test_that("the printed header states the denominator in words", {
  d <- data.frame(n = 412, pop = 120000)
  expect_output(print(rate(d, n, pop, per = "100k")), "per 100,000")
  expect_output(print(rate(d, n, pop, per = 1000)), "per 1,000")
  # 1e+05 in a published table is a defect
  expect_output(print(rate(d, n, pop, per = "100k")), "Poisson")
  expect_failure(expect_output(print(rate(d, n, pop, per = "100k")), "1e+05",
                              fixed = TRUE))
  expect_output(print(share(412, total = 492)), "Wilson")
  g <- data.frame(year = c(2022, 2023), n = c(10, 20), pop = c(1000, 1000))
  expect_output(print(rate_change(g, n, pop, year)), "Change in rate")
})

test_that("columns can be named as strings as well as symbols", {
  d <- data.frame(n = 412, pop = 120000)
  expect_equal(rate(d, "n", "pop", per = "100k")$rate,
               rate(d, n, pop, per = "100k")$rate)
  expect_error(rate(d, n, pop, by = "nope"), "column not found")
})

test_that("periods that are not numbers step back along their own order", {
  # Quarters as labels: the grid is the sorted unique values, so the
  # comparison is the previous label, and the first one has none.
  q <- data.frame(quarter = c("2023Q1", "2023Q2", "2023Q3"),
                  n = c(10L, 20L, 15L),
                  pop = c(1000, 1000, 1000),
                  stringsAsFactors = FALSE)
  rc <- rate_change(q, n, pop, quarter)
  expect_identical(rc$flag[1], "no comparison period")
  expect_equal(rc$pct_change[2], 100)
  expect_equal(rc$pct_change[3], -25)
  # lag 2 reaches back two labels
  rc2 <- rate_change(q, n, pop, quarter, lag = 2L)
  expect_true(is.na(rc2$pct_change[2]))
  expect_equal(rc2$pct_change[3], 50)
})

test_that("a scalar population is recycled, a mismatched one is refused", {
  r <- rate(c(3, 6, 9), 1000, per = 1000)
  expect_identical(nrow(r), 3L)
  expect_equal(r$rate, c(3, 6, 9))
  expect_error(rate(c(1, 2, 3), c(10, 20)), "same length")
})

test_that("share() takes its denominator from a column when asked", {
  d <- data.frame(division = c("North", "South"),
                  stops = c(30, 70),
                  everything = c(500, 500))
  # the column is summed, so the denominator is 1000, not 500
  s <- share(d, stops, by = "division", total = "everything")
  expect_equal(unique(s$total), 1000)
  expect_equal(sum(s$share), 10)
  expect_error(share(d, stops, total = "nope"), "column not found")
})

test_that("share() on a bare vector totals itself by default", {
  s <- share(c(1, 2, 7))
  expect_equal(s$share, c(10, 20, 70))
  expect_equal(unique(s$total), 10)
  expect_equal(share(c(1, 2, 7), total = 100)$share, c(1, 2, 7))
})

test_that("a confidence level outside (0, 1) is refused everywhere", {
  d <- data.frame(n = 10, pop = 1000)
  expect_error(rate(d, n, pop, conf_level = 0), "strictly inside")
  expect_error(rate(d, n, pop, conf_level = 1), "strictly inside")
  expect_error(share(10, total = 100, conf_level = 2), "strictly inside")
  g <- data.frame(year = c(2022, 2023), n = c(1, 2), pop = c(10, 10))
  expect_error(rate_change(g, n, pop, year, conf_level = NA),
               "strictly inside")
  expect_error(rate_change(g, n, pop, year, lag = 0), "positive integer")
})

test_that("a wider confidence level gives a wider interval", {
  # the direction of the level is easy to get backwards, and nothing
  # else in these tests would notice
  narrow <- rate(50, 1000, per = 1000, conf_level = 0.80)
  wide <- rate(50, 1000, per = 1000, conf_level = 0.99)
  expect_lt(wide$lower, narrow$lower)
  expect_gt(wide$upper, narrow$upper)
  ns <- share(50, total = 1000, conf_level = 0.80)
  ws <- share(50, total = 1000, conf_level = 0.99)
  expect_lt(ws$lower, ns$lower)
  expect_gt(ws$upper, ns$upper)
})

test_that("grouped rate_change keeps the groups apart", {
  d <- data.frame(
    year = rep(2022:2023, each = 2),
    division = rep(c("North", "South"), 2),
    n = c(100, 10, 200, 5),
    pop = c(1000, 1000, 1000, 1000))
  rc <- rate_change(d, n, pop, year, by = "division")
  north <- rc[rc$division == "North" & rc$year == 2023, ]
  south <- rc[rc$division == "South" & rc$year == 2023, ]
  expect_equal(north$pct_change, 100)
  expect_equal(south$pct_change, -50)
})

test_that("a zero earlier count is named rather than reported as Inf", {
  g <- data.frame(year = c(2022, 2023), n = c(0, 12), pop = c(1000, 1000))
  rc <- rate_change(g, n, pop, year)
  expect_identical(rc$flag[2], "earlier period is zero")
  expect_false(is.finite(rc$pct_change[2]) && !is.na(rc$pct_change[2]))
})
