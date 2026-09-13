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
  expect_equal(admissions(25, implied), 1750)
})

test_that("person-days come out of periodic headcounts, as on p.21", {
  # p.21: counts on 255 days summing to 34,935 over a 365-day year.
  counts <- rep(34935 / 255, 255)
  expect_equal(adp_from_counts(counts), 50005)
  expect_equal(round(adp_from_counts(counts)), 50005)
  # the counts need not be equal, only their mean matters
  set.seed(1)
  jittered <- 34935 / 255 + c(-10, 10, rep(0, 253))
  expect_equal(adp_from_counts(jittered), 50005)
})

test_that("the identity adp = n * alos / t holds", {
  # This is algebra rather than data, so it is asserted once and then
  # relied on: days = people x stay, so dividing by t either way agrees.
  days <- 126121; people <- 9608
  expect_equal(adp(days), admissions(adp(days), alos(days, people)) *
                          alos(days, people) / 365)
  expect_equal(admissions(adp(days), alos(days, people)), people)
})

test_that("stock and flow can carry opposite signs", {
  # The reason these functions exist. Fewer people, held longer: the
  # flow rate falls while the stock rate rises, and a report quoting
  # either alone states the wrong direction for the other.
  sf <- stock_flow(days = c(115674, 126121), people = c(12647, 9608),
                   period = c("2023", "2025"),
                   exposure = c(15495050, 16256538))
  expect_s3_class(sf, "rmbl_stock_flow")
  expect_identical(nrow(sf), 2L)
  # people down, stay up, days up
  expect_lt(sf$people_change[2], 0)
  expect_gt(sf$alos_change[2], 0)
  expect_gt(sf$days_change[2], 0)
  # and the two rates disagree on the sign
  expect_lt(sf$flow_rate_change[2], 0)
  expect_gt(sf$stock_rate_change[2], 0)
  # the decomposition is exact: days = people x stay
  p <- sf$people_change[2] / 100
  l <- sf$alos_change[2] / 100
  expect_equal((1 + p) * (1 + l) - 1, sf$days_change[2] / 100)
  # adp is days per day; the stock rate is adp against the exposure
  expect_equal(sf$adp[2], 126121 / 365)
  expect_equal(sf$stock_rate[2], 1e5 * (126121 / 365) / 16256538)
  expect_equal(sf$flow_rate[2], 1e5 * 9608 / 16256538)
})

test_that("stock_flow works without an exposure", {
  sf <- stock_flow(days = c(100, 200), people = c(10, 10))
  expect_false("stock_rate" %in% names(sf))
  expect_equal(sf$alos, c(10, 20))
  expect_equal(sf$adp, c(100, 200) / 365)
  expect_equal(sf$days_change[2], 100)
})

test_that("the printed form says when the signs disagree", {
  sf <- stock_flow(days = c(115674, 126121), people = c(12647, 9608),
                   period = c("2023", "2025"),
                   exposure = c(15495050, 16256538))
  expect_output(print(sf), "opposite signs")
  expect_output(print(sf), "stock_rate")
  # and stays quiet when they agree
  agree <- stock_flow(days = c(100, 200), people = c(10, 20),
                      exposure = c(1000, 1000))
  expect_failure(expect_output(print(agree), "opposite signs"))
})

test_that("the arguments are validated", {
  expect_error(adp(13500, t = 0), "positive")
  expect_error(adp(13500, t = -1), "positive")
  expect_error(adp(numeric(0)), "must not be empty")
  expect_error(adp(c(1, NA)), "must not contain NA")
  expect_error(adp(-1), "non-negative")
  expect_error(alos(100, 0), "positive")
  expect_error(admissions(25, 0), "positive")
  expect_error(stock_flow(days = c(1, 2), people = 1), "same length")
  expect_error(stock_flow(days = c(1, 2), people = c(1, 2),
                          exposure = c(1, 2, 3)),
               "length 1 or the same length")
})

test_that("a single exposure is recycled across periods", {
  sf <- stock_flow(days = c(100, 200), people = c(10, 20),
                   exposure = 1000, per = 1000)
  expect_equal(sf$exposure, c(1000, 1000))
  expect_equal(sf$flow_rate, c(10, 20))
})
