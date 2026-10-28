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
  for (cs in list(
    c(412, 120000),
    c(77, 41000),
    c(3, 9500),
    c(0, 5000),
    c(1, 100)
  )) {
    got <- rtcalc(cs[1], cs[2], per = "100k")
    want <- stats::poisson.test(cs[1], cs[2])$conf.int * 1e5
    expect_equal(
      c(got$lower, got$upper),
      as.numeric(want),
      info = paste("count", cs[1])
    )
  }
})

test_that("a zero count has a lower limit of zero, not a negative rate", {
  z <- rtcalc(0, 5000, per = "100k")
  expect_identical(z$lower, 0)
  expect_gt(z$upper, 0)
  expect_identical(z$rate, 0)
})

test_that("the share interval is Wilson's, not the normal approximation", {
  for (cs in list(c(412, 492), c(77, 492), c(3, 492), c(0, 100), c(100, 100))) {
    got <- shrs(cs[1], total = cs[2])
    want <- stats::prop.test(cs[1], cs[2], correct = FALSE)$conf.int * 100
    expect_equal(
      c(got$lower, got$upper),
      as.numeric(want),
      info = paste("count", cs[1])
    )
  }
  # the normal approximation would run below zero here; Wilson does not
  expect_gte(shrs(3, total = 492)$lower, 0)
  expect_lte(shrs(100, total = 100)$upper, 100)
})

test_that("the rate-ratio interval is the two-sample poisson.test", {
  d <- data.frame(
    year = c(2022, 2023),
    stops = c(70, 455),
    residents = c(41000, 125000)
  )
  rc <- ratechg(d, stops, residents, year, per = "100k")
  want <- stats::poisson.test(c(455, 70), c(125000, 41000))$conf.int
  expect_equal(
    c(1 + rc$pctlo[2] / 100, 1 + rc$pctup[2] / 100),
    as.numeric(want),
    tolerance = testthat::testthat_tolerance()
  )
})

test_that("equal denominators reduce to yoy()'s interval exactly", {
  # This is the property that says the exposure correction is applied
  # in the right direction: with nothing to correct for, the two
  # constructions must give the same numbers to the last digit.
  e <- data.frame(year = c(2022, 2023), n = c(70, 90), pop = c(50000, 50000))
  rc <- ratechg(e, n, pop, year, per = 1000)
  y <- yoy(e, n, year, units = "count")
  expect_equal(
    rc$pctchg[2],
    y$pctchg[2],
    tolerance = testthat::testthat_tolerance()
  )
  expect_identical(rc$pctlo[2], y$pctlo[2])
  expect_identical(rc$pctup[2], y$pctup[2])
})

test_that("a rate is not a share, and the difference shows", {
  d <- data.frame(
    division = c("North", "South", "East"),
    stops = c(412, 77, 3),
    residents = c(120000, 41000, 9500),
    stringsAsFactors = FALSE
  )
  r <- rtcalc(d, stops, residents, by = "division", per = "100k")
  s <- shrs(d, stops, by = "division")
  # shares over a complete grouping sum to 100; rates do not sum to
  # anything, because their denominators are different populations
  expect_identical(sum(s$share), 100)
  expect_false(isTRUE(all.equal(sum(r$rate), 100)))
  # East has the smallest count and the largest share interval, in
  # relative terms, and the largest rate interval too
  expect_gt(
    (s$upper - s$lower)[s$division == "East"] / s$share[s$division == "East"],
    (s$upper - s$lower)[s$division == "North"] / s$share[s$division == "North"]
  )
})

test_that("the per denominator scales the rate and its interval together", {
  d <- data.frame(n = 412, pop = 120000)
  per_1k <- rtcalc(d, n, pop, per = 1000)
  per_100k <- rtcalc(d, n, pop, per = "100k")
  expect_identical(per_100k$rate, per_1k$rate * 100)
  expect_equal(
    per_100k$lower,
    per_1k$lower * 100,
    tolerance = testthat::testthat_tolerance()
  )
  expect_identical(per_100k$upper, per_1k$upper * 100)
  # every shorthand means what it says
  expect_identical(
    rtcalc(d, n, pop, per = "1k")$rate,
    rtcalc(d, n, pop, per = 1e3)$rate
  )
  expect_identical(
    rtcalc(d, n, pop, per = "10k")$rate,
    rtcalc(d, n, pop, per = 1e4)$rate
  )
  expect_identical(
    rtcalc(d, n, pop, per = "100k")$rate,
    rtcalc(d, n, pop, per = 1e5)$rate
  )
  expect_identical(
    rtcalc(d, n, pop, per = "1m")$rate,
    rtcalc(d, n, pop, per = 1e6)$rate
  )
  expect_identical(
    rtcalc(d, n, pop, per = "per 100k")$rate,
    rtcalc(d, n, pop, per = 1e5)$rate
  )
})

test_that("a denominator mistyped as a word is refused, not guessed", {
  d <- data.frame(n = 412, pop = 120000)
  expect_error(rtcalc(d, n, pop, per = "hundred thousand"), "not recognised")
  expect_error(rtcalc(d, n, pop, per = 0), "positive")
  expect_error(rtcalc(d, n, pop, per = -1000), "positive")
  expect_error(rtcalc(d, n, pop, per = NA), "positive")
})

test_that("the comparison period is matched on the period, not the row", {
  # 2023 against 2020 is not a year-over-year change, and the gap is
  # reported rather than silently bridged
  g <- data.frame(year = c(2020, 2023), n = c(10, 20), pop = c(1000, 1000))
  rc <- ratechg(g, n, pop, year)
  expect_true(all(is.na(rc$pctchg)))
  expect_identical(unique(rc$flag), "no comparison period")
  # with the year present, the comparison is made
  ok <- data.frame(year = c(2022, 2023), n = c(10, 20), pop = c(1000, 1000))
  expect_identical(ratechg(ok, n, pop, year)$pctchg[2], 100)
})

test_that("exposure is required to be exposure", {
  bad <- data.frame(n = 5, pop = 0)
  expect_error(rtcalc(bad, n, pop), "positive")
  expect_error(rtcalc(data.frame(n = -1, pop = 10), n, pop), "non-negative")
  # a Poisson interval on a fractional count is not defined
  expect_error(rtcalc(data.frame(n = 2.5, pop = 10), n, pop), "whole numbers")
  # a count larger than the total is not a share of it
  expect_error(shrs(data.frame(n = 20), n, total = 10), "larger than the total")
})

test_that("grouping aggregates before dividing, not after", {
  # Two rows for one division must give one rate computed from the
  # summed count over the summed population -- the mean of two rates
  # is a different and usually wrong number.
  d <- data.frame(
    division = c("North", "North"),
    n = c(200, 212),
    pop = c(60000, 60000),
    stringsAsFactors = FALSE
  )
  r <- rtcalc(d, n, pop, by = "division", per = "100k")
  expect_identical(nrow(r), 1L)
  expect_identical(r$rate, 1e5 * 412 / 120000)
  expect_identical(r$count, 412)
  expect_identical(r$population, 120000)
})

test_that("mincnt flags a small count without hiding the rate", {
  d <- data.frame(
    division = c("North", "East"),
    n = c(412, 3),
    pop = c(120000, 9500),
    stringsAsFactors = FALSE
  )
  r <- rtcalc(d, n, pop, by = "division", per = "100k", mincnt = 5)
  east <- r[r$division == "East", ]
  expect_match(east$flag, "at or below 5")
  expect_false(is.na(east$rate))
  expect_true(is.na(r$flag[r$division == "North"]))
  # and in a change, the percent off the tiny base is still computed, only noted
  g <- data.frame(year = c(2022, 2023), n = c(2, 40), pop = c(1000, 1000))
  rc <- ratechg(g, n, pop, year, mincnt = 5)
  expect_identical(rc$pctchg[2], 1900)
  expect_lt(rc$pctlo[2], 1900)
  expect_gt(rc$pctup[2], 1900)
  expect_match(rc$flag[2], "earlier count at or below 5")
})

test_that("vectors and data frames agree", {
  d <- data.frame(n = 412, pop = 120000)
  expect_identical(
    rtcalc(d, n, pop, per = "100k")$rate,
    rtcalc(412, 120000, per = "100k")$rate
  )
  expect_identical(shrs(d, n, total = 492)$share, shrs(412, total = 492)$share)
})

test_that("the printed header states the denominator in words", {
  d <- data.frame(n = 412, pop = 120000)
  expect_output(print(rtcalc(d, n, pop, per = "100k")), "per 100,000")
  expect_output(print(rtcalc(d, n, pop, per = 1000)), "per 1,000")
  # 1e+05 in a published table is a defect
  expect_output(print(rtcalc(d, n, pop, per = "100k")), "Poisson")
  expect_failure(expect_output(
    print(rtcalc(d, n, pop, per = "100k")),
    "1e+05",
    fixed = TRUE
  ))
  expect_output(print(shrs(412, total = 492)), "Wilson")
  g <- data.frame(year = c(2022, 2023), n = c(10, 20), pop = c(1000, 1000))
  expect_output(print(ratechg(g, n, pop, year)), "Change in rate")
})

test_that("columns can be named as strings as well as symbols", {
  d <- data.frame(n = 412, pop = 120000)
  expect_identical(
    rtcalc(d, "n", "pop", per = "100k")$rate,
    rtcalc(d, n, pop, per = "100k")$rate
  )
  expect_error(rtcalc(d, n, pop, by = "nope"), "column not found")
})

test_that("periods that are not numbers step back along their own order", {
  # Quarters as labels: the grid is the sorted unique values, so the
  # comparison is the previous label, and the first one has none.
  q <- data.frame(
    quarter = c("2023Q1", "2023Q2", "2023Q3"),
    n = c(10L, 20L, 15L),
    pop = c(1000, 1000, 1000),
    stringsAsFactors = FALSE
  )
  rc <- ratechg(q, n, pop, quarter)
  expect_identical(rc$flag[1], "no comparison period")
  expect_identical(rc$pctchg[2], 100)
  expect_identical(rc$pctchg[3], -25)
  # lag 2 reaches back two labels
  rc2 <- ratechg(q, n, pop, quarter, lag = 2L)
  expect_true(is.na(rc2$pctchg[2]))
  expect_identical(rc2$pctchg[3], 50)
})

test_that("a scalar population is recycled, a mismatched one is refused", {
  r <- rtcalc(c(3, 6, 9), 1000, per = 1000)
  expect_identical(nrow(r), 3L)
  expect_identical(r$rate, c(3, 6, 9))
  expect_error(rtcalc(c(1, 2, 3), c(10, 20)), "same length")
})

test_that("shrs() takes its denominator from a column when asked", {
  d <- data.frame(
    division = c("North", "South"),
    stops = c(30, 70),
    everything = c(500, 500),
    stringsAsFactors = FALSE
  )
  # the column is summed, so the denominator is 1000, not 500
  s <- shrs(d, stops, by = "division", total = "everything")
  expect_identical(unique(s$total), 1000)
  expect_identical(sum(s$share), 10)
  expect_error(shrs(d, stops, total = "nope"), "column not found")
})

test_that("shrs() on a bare vector totals itself by default", {
  s <- shrs(c(1, 2, 7))
  expect_identical(s$share, c(10, 20, 70))
  expect_identical(unique(s$total), 10)
  expect_identical(shrs(c(1, 2, 7), total = 100)$share, c(1, 2, 7))
})

test_that("a confidence level outside (0, 1) is refused everywhere", {
  # the shared .rmbl_conf_level() message since 0.5.13
  d <- data.frame(n = 10, pop = 1000)
  expect_error(rtcalc(d, n, pop, conflvl = 0), "strictly between 0 and 1")
  expect_error(rtcalc(d, n, pop, conflvl = 1), "strictly between 0 and 1")
  expect_error(shrs(10, total = 100, conflvl = 2), "strictly between 0 and 1")
  g <- data.frame(year = c(2022, 2023), n = c(1, 2), pop = c(10, 10))
  expect_error(
    ratechg(g, n, pop, year, conflvl = NA),
    "strictly between 0 and 1"
  )
  expect_error(ratechg(g, n, pop, year, lag = 0), "positive integer")
})

test_that("a wider confidence level gives a wider interval", {
  # the direction of the level is easy to get backwards, and nothing
  # else in these tests would notice
  narrow <- rtcalc(50, 1000, per = 1000, conflvl = 0.80)
  wide <- rtcalc(50, 1000, per = 1000, conflvl = 0.99)
  expect_lt(wide$lower, narrow$lower)
  expect_gt(wide$upper, narrow$upper)
  ns <- shrs(50, total = 1000, conflvl = 0.80)
  ws <- shrs(50, total = 1000, conflvl = 0.99)
  expect_lt(ws$lower, ns$lower)
  expect_gt(ws$upper, ns$upper)
})

test_that("grouped ratechg keeps the groups apart", {
  d <- data.frame(
    year = rep(2022:2023, each = 2),
    division = rep(c("North", "South"), 2),
    n = c(100, 10, 200, 5),
    pop = c(1000, 1000, 1000, 1000),
    stringsAsFactors = FALSE
  )
  rc <- ratechg(d, n, pop, year, by = "division")
  north <- rc[rc$division == "North" & rc$year == 2023, ]
  south <- rc[rc$division == "South" & rc$year == 2023, ]
  expect_identical(north$pctchg, 100)
  expect_identical(south$pctchg, -50)
})

test_that("a zero earlier count is named rather than reported as Inf", {
  g <- data.frame(year = c(2022, 2023), n = c(0, 12), pop = c(1000, 1000))
  rc <- ratechg(g, n, pop, year)
  expect_identical(rc$flag[2], "earlier period is zero")
  expect_false(is.finite(rc$pctchg[2]) && !is.na(rc$pctchg[2]))
})

test_that("rtcalc() refuses a `per` of length other than one", {
  expect_error(rtcalc(5, 1000, per = c(1e5, 1e3)), "`per` must be a single")
  expect_error(
    rtcalc(5, 1000, per = c("100k", "1k")),
    "`per` must be a single"
  )
  expect_error(rtcalc(5, 1000, per = numeric(0)), "`per` must be a single")
  expect_no_error(rtcalc(5, 1000, per = 1e5))
})

test_that("ratechg orders fiscal years in time order, as yoy does", {
  d <- data.frame(
    yr = c("2020/21", "2019/20", "2021/22"),
    n = c(20, 10, 30),
    pop = c(1000, 1000, 1000),
    stringsAsFactors = FALSE
  )
  rc <- ratechg(d, n, pop, yr)
  expect_identical(as.character(rc$yr), c("2019/20", "2020/21", "2021/22"))
  expect_identical(rc$count, c(10, 20, 30))
})

# ---- boxed printouts -------------------------------------------------------

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

test_that("rates, rate changes and shares print as boxes", {
  rd <- data.frame(
    g = c("a", "b", "a", "b"),
    yr = c(1, 1, 2, 2),
    n = c(3, 40, 5, 60),
    pop = c(1000, 2000, 1000, 2000),
    stringsAsFactors = FALSE
  )
  out <- .o2_check(rtcalc(rd, "n", "pop", by = "g", mincnt = 10),
    "Rate per 1,000", c("95% exact Poisson", "[1] count at or below 10"))
  rc <- ratechg(rd, "n", "pop", "yr", by = "g")
  .o2_check(rc, "Change in rate per 1,000",
    c("pct_interval", "[1] no comparison period"))
  .o2_check(scanadj(rc), "Change in rate per 1,000",
    c("Adjustment", "adj_p", "significant"))
  .o2_check(shrs(c(a = 3, b = 7)), "Share", c("95% Wilson", "label"))
})

# ---- result-driven readings ------------------------------------------------

ls_flat <- function(x) gsub("\\s+", " ", paste(format(x), collapse = " "))

test_that("rtcalc()'s reading compares the groups and flags small counts", {
  s <- data.frame(division = c("North", "South", "East"),
    stops = c(412, 77, 3), residents = c(120000, 41000, 9500),
    stringsAsFactors = FALSE)
  r <- ls_flat(rtcalc(s, stops, residents, by = "division", mincnt = 5))
  expect_match(r, "Highest rate: North", fixed = TRUE)
  expect_match(r, "lowest: East", fixed = TRUE)
  expect_match(r, "East rests on 5 or fewer events", fixed = TRUE)
  s$stops <- c(10, 400, 30)
  r2 <- ls_flat(rtcalc(s, stops, residents, by = "division"))
  expect_match(r2, "Highest rate: South", fixed = TRUE)
  expect_false(grepl("fewer events", r2, fixed = TRUE))
})

test_that("ratechg()'s reading separates real changes from chance", {
  d <- data.frame(year = 2021:2022, n = c(400, 800), pop = 1e5)
  up <- ls_flat(ratechg(d, n, pop, year))
  expect_match(up,
    "Rose by more than chance (interval above 0): 2022 (+100.0%)",
    fixed = TRUE)
  d$n <- c(400, 410)
  same <- ls_flat(ratechg(d, n, pop, year))
  expect_match(same, "Not distinguishable from 0", fixed = TRUE)
  d$n <- c(800, 400)
  expect_match(ls_flat(ratechg(d, n, pop, year)), "Fell by more than chance",
    fixed = TRUE)
})

test_that("a subset of a rate change or share prints as a plain table", {
  expect_df_fallback("rmbl_rate_change", "Change in rate")
  expect_df_fallback("rmbl_share", "Share")
})

test_that("plot(ratechg(..., prdord = )) draws the periods in that order", {
  d <- data.frame(p = c("spring", "summer", "autumn", "spring", "autumn"),
                  g = c("a", "a", "a", "b", "b"),
                  n = c(10, 12, 15, 4, 6), pop = 1000)
  ord <- c("spring", "summer", "autumn")
  r <- ratechg(d, "n", "pop", "p", by = "g", prdord = ord)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  pl <- plot(r)
  a <- pl[r$g == "a", ]
  # the x positions follow prdord, not the alphabet (autumn first)
  expect_true(all(diff(a$at) > 0))
  expect_identical(a$label, paste("a:", ord))
})

test_that("ratechg() and anltab() take prdord, and refuse what they lack", {
  d <- data.frame(p = c("spring", "summer", "autumn", "spring", "autumn"),
                  g = c("a", "a", "a", "b", "b"),
                  n = c(10, 12, 15, 4, 6), pop = 1000)
  ord <- c("spring", "summer", "autumn")
  r <- ratechg(d, "n", "pop", "p", by = "g", prdord = ord)
  a <- r[r$g == "a", ]
  expect_identical(as.character(a$p), ord)
  expect_equal(a$prerate[3], 12, tolerance = 1e-12)
  # for b, summer is missing: autumn is not compared with spring as one step
  b <- r[r$g == "b", ]
  expect_true(is.na(b$prerate[b$p == "autumn"]))
  expect_identical(attr(r, "ratechg")$prdord, ord)
  # alphabetical order would have put autumn first
  expect_false(identical(as.character(ratechg(d, "n", "pop", "p",
                                              by = "g")$p[1:3]), ord))
  t <- anltab(d, value = "n", prd = "p", by = "g", pop = "pop",
              prdord = ord)
  expect_identical(t$meta$periods, ord)
  expect_identical(t$meta$prdord, ord)
  # an argument the method does not take is named, not swallowed
  expect_error(ratechg(d, "n", "pop", "p", prdrd = ord),
               "ratechg: unused argument: prdrd")
  expect_error(rtcalc(d, "n", "pop", by = "g", conflevel = 0.9),
               "rtcalc: unused argument: conflevel")
  expect_error(rtcalc(c(1, 2), c(10, 20), 5, 6, 7, 8), "unused argument")
  expect_error(shrs(d, "n", by = "g", denom = 5),
               "shrs: unused argument: denom")
  expect_error(shrs(c(1, 2), denom = 5), "shrs: unused argument: denom")
  expect_error(yoy(d, "n", "p", by = "g", prdrd = ord),
               "yoy: unused argument: prdrd")
})

test_that("a ratechg box prints whole-number periods as labels", {
  d <- data.frame(p = rep(2019:2022, 2), g = rep(c("a", "b"), each = 4),
                  n = c(5, 7, 9, 11, 4, 6, 8, 7), pop = 1000)
  out <- format(ratechg(d, "n", "pop", "p", by = "g"))
  expect_false(any(grepl("2020.000", out, fixed = TRUE)))
  expect_true(any(grepl("\\b2020\\b", out, perl = TRUE)))
  expect_identical(.rmbl_prdtxt(c(2019, NA)), c("2019", NA))
  expect_identical(.rmbl_prdtxt(c(1.5, 2)), c(1.5, 2))
})
