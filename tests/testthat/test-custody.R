# Stock and flow measures.
#
# The anchors here are Lakner's own worked examples from A Manual of
# Statistical Sampling Methods for Corrections Planners (1976). They are
# published numbers computed by someone else, so they can disagree with
# this code -- which is the property a test needs and which a test
# comparing these functions to each other would not have.

test_that("the average daily population is Lakner's worked example", {
  # p.15: 3,000 inmates served 13,500 detention days in a year.
  expect_equal(adp(13500), 13500 / 365)
  expect_equal(round(adp(13500), 8), 36.98630137)
  expect_equal(round(adp(13500)), 37)
  # summing per-person days gives the same answer as the total
  expect_equal(adp(c(5000, 8500)), adp(13500))
})

test_that("the average length of stay is Lakner's worked example", {
  # p.17: 2,700 inmates admitted and released served 12,150 days.
  expect_equal(alos(12150, 2700), 4.5)
  # the manual's own text rounds 12,150/2,700 to 4.5 days
  expect_equal(round(alos(12150, 2700), 1), 4.5)
})

test_that("admissions invert the identity, as on p.20", {
  # p.20: t = 365, average daily population 25, 1,750 admissions imply a
  # stay of 5.2 days.
  implied <- 25 * 365 / 1750
  expect_equal(round(implied, 7), 5.2142857)
  expect_equal(round(implied, 1), 5.2)
  # and inverting gets the admissions back
  expect_equal(admits(25, implied), 1750)
})

test_that("person-days come out of periodic headcounts, as on p.21", {
  # p.21: counts on 255 days summing to 34,935 over a 365-day year.
  counts <- rep(34935 / 255, 255)
  expect_equal(adpcnts(counts), 50005)
  expect_equal(round(adpcnts(counts)), 50005)
  # the counts need not be equal, only their mean matters
  set.seed(1)
  jittered <- 34935 / 255 + c(-10, 10, rep(0, 253))
  expect_equal(adpcnts(jittered), 50005)
})

test_that("the identity adp = n * alos / t holds", {
  # This is algebra rather than data, so it is asserted once and then
  # relied on: days = people x stay, so dividing by t either way agrees.
  days <- 126121
  people <- 9608
  expect_equal(
    adp(days),
    admits(adp(days), alos(days, people)) *
      alos(days, people) /
      365
  )
  expect_equal(admits(adp(days), alos(days, people)), people)
})

test_that("stock and flow can carry opposite signs", {
  # The reason these functions exist. Fewer people, held longer: the
  # flow rate falls while the stock rate rises, and a report quoting
  # either alone states the wrong direction for the other.
  sf <- stkflow(
    days = c(115674, 126121),
    people = c(12647, 9608),
    prd = c("2023", "2025"),
    expo = c(15495050, 16256538)
  )
  expect_s3_class(sf, "rmbl_stock_flow")
  expect_identical(nrow(sf), 2L)
  # people down, stay up, days up
  expect_lt(sf$peochg[2], 0)
  expect_gt(sf$aloschg[2], 0)
  expect_gt(sf$dayschg[2], 0)
  # and the two rates disagree on the sign
  expect_lt(sf$flowratechg[2], 0)
  expect_gt(sf$stkratechg[2], 0)
  # the decomposition is exact: days = people x stay
  p <- sf$peochg[2] / 100
  l <- sf$aloschg[2] / 100
  expect_equal((1 + p) * (1 + l) - 1, sf$dayschg[2] / 100)
  # adp is days per day; the stock rate is adp against the exposure
  expect_equal(sf$adp[2], 126121 / 365)
  expect_equal(sf$stkrate[2], 1e5 * (126121 / 365) / 16256538)
  expect_equal(sf$flowrate[2], 1e5 * 9608 / 16256538)
})

test_that("stkflow works without an exposure", {
  sf <- stkflow(days = c(100, 200), people = c(10, 10))
  expect_false("stkrate" %in% names(sf))
  expect_equal(sf$alos, c(10, 20))
  expect_equal(sf$adp, c(100, 200) / 365)
  expect_equal(sf$dayschg[2], 100)
})

test_that("the printed form says when the signs disagree", {
  sf <- stkflow(
    days = c(115674, 126121),
    people = c(12647, 9608),
    prd = c("2023", "2025"),
    expo = c(15495050, 16256538)
  )
  expect_output(print(sf), "opposite signs")
  expect_output(print(sf), "stkrate")
  # and stays quiet when they agree
  agree <- stkflow(
    days = c(100, 200),
    people = c(10, 20),
    expo = c(1000, 1000)
  )
  expect_failure(expect_output(print(agree), "opposite signs"))
})

test_that("the arguments are validated", {
  expect_error(adp(13500, t = 0), "positive")
  expect_error(adp(13500, t = -1), "positive")
  expect_error(adp(numeric(0)), "must not be empty")
  expect_error(adp(c(1, NA)), "must not contain NA")
  expect_error(adp(-1), "non-negative")
  expect_error(alos(100, 0), "positive")
  expect_error(admits(25, 0), "positive")
  expect_error(stkflow(days = c(1, 2), people = 1), "same length")
  expect_error(
    stkflow(
      days = c(1, 2),
      people = c(1, 2),
      expo = c(1, 2, 3)
    ),
    "length 1 or the same length"
  )
})

test_that("a single exposure is recycled across periods", {
  sf <- stkflow(
    days = c(100, 200),
    people = c(10, 20),
    expo = 1000,
    per = 1000
  )
  expect_equal(sf$exposure, c(1000, 1000))
  expect_equal(sf$flowrate, c(10, 20))
})

test_that("perdays counts both ends, and leap years look after themselves", {
  # A period from the 1st to the 31st is thirty-one days of exposure.
  expect_equal(perdays("2024-01-01", "2024-01-31"), 31)
  expect_equal(perdays("2024-01-01", "2024-01-01"), 1)
  # nobody has to know which years are leap years
  expect_equal(perdays("2024-01-01", "2024-12-31"), 366)
  expect_equal(perdays("2023-01-01", "2023-12-31"), 365)
  expect_equal(perdays("2025-04-01", "2026-03-31"), 365)
  # and it feeds straight into adp()
  expect_equal(
    adp(13500, perdays("2023-01-01", "2023-12-31")),
    adp(13500, 365)
  )
  expect_error(perdays("2024-12-31", "2024-01-01"), "must not precede")
  expect_error(
    perdays(c("2024-01-01", "2024-01-02"), "2024-12-31"),
    "a single date"
  )
})

test_that("staysmry describes the distribution, not just its mean", {
  # Most stays short, a few long: the mean sits well above the median,
  # which is the reason both are reported.
  stays <- c(rep(1, 40), rep(3, 30), rep(10, 20), 60, 90, 120)
  ss <- staysmry(stays)
  expect_identical(ss$n, length(stays))
  expect_equal(ss$totaldays, sum(stays))
  expect_equal(ss$mean, mean(stays))
  expect_equal(ss$median, stats::median(stays))
  expect_equal(ss$max, 120)
  expect_gt(ss$mean, ss$median)
  # the mean agrees with alos() on the same data
  expect_equal(ss$mean, alos(sum(stays), length(stays)))
  # the interval is the ordinary t interval on a mean
  se <- stats::sd(stays) / sqrt(length(stays))
  tq <- stats::qt(0.975, df = length(stays) - 1L)
  expect_equal(ss$se, se)
  expect_equal(ss$lower, mean(stays) - tq * se)
  expect_equal(ss$upper, mean(stays) + tq * se)
  # a wider level gives a wider interval
  w <- staysmry(stays, conflvl = 0.99)
  expect_lt(w$lower, ss$lower)
  expect_gt(w$upper, ss$upper)
})

test_that("staysmry copes with a single person and refuses nonsense", {
  one <- staysmry(7)
  expect_identical(one$n, 1L)
  expect_equal(one$mean, 7)
  # no spread and no interval from one observation, said with NA rather
  # than with a fabricated zero
  expect_true(is.na(one$sd))
  expect_true(is.na(one$lower))
  expect_true(is.na(one$upper))
  expect_error(staysmry(c(1, -1)), "non-negative")
  expect_error(staysmry(numeric(0)), "must not be empty")
  # the shared message since 0.5.13
  expect_error(
    staysmry(c(1, 2), conflvl = 1),
    paste0("strictly between 0 ", "and 1")
  )
})

test_that("stkflow measures against the previous period when asked", {
  sf1 <- stkflow(
    days = c(100, 200, 400),
    people = c(10, 10, 10),
    prd = c("a", "b", "c")
  )
  sf2 <- stkflow(
    days = c(100, 200, 400),
    people = c(10, 10, 10),
    prd = c("a", "b", "c"),
    base = "previous"
  )
  # against the first: b is +100%, c is +300%
  expect_equal(sf1$dayschg, c(0, 100, 300))
  # against the previous: each doubling is +100%, and the first has none
  expect_true(is.na(sf2$dayschg[1]))
  expect_equal(sf2$dayschg[-1], c(100, 100))
  expect_identical(attr(sf2, "stkflow")$baseline, "previous")
  expect_error(
    stkflow(days = 1:2, people = c(1, 1), base = "middle"),
    "must be one of"
  )
})

test_that("the measures hold together on a period that is not a year", {
  # A thirty-day month, which is the case a hardcoded 365 would break.
  t30 <- perdays("2025-04-01", "2025-04-30")
  expect_equal(t30, 30)
  sf <- stkflow(
    days = c(2400, 2750),
    people = c(300, 250),
    prd = c("Apr", "May"),
    t = t30
  )
  expect_equal(sf$adp, c(2400, 2750) / 30)
  expect_equal(sf$alos, c(8, 11))
  # people down, stay up, days up: the decomposition still multiplies out
  p <- sf$peochg[2] / 100
  l <- sf$aloschg[2] / 100
  expect_equal((1 + p) * (1 + l) - 1, sf$dayschg[2] / 100)
})

test_that("perdays refuses a missing date", {
  expect_error(perdays(NA_character_, "2020-01-02"), "must be dates")
})
