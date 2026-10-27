# Stock and flow measures.
#
# The anchors here are Lakner's own worked examples from A Manual of
# Statistical Sampling Methods for Corrections Planners (1976). They are
# published numbers computed by someone else, so they can disagree with
# this code -- which is the property a test needs and which a test
# comparing these functions to each other would not have.

test_that("the average daily population is Lakner's worked example", {
  # p.15: 3,000 inmates served 13,500 detention days in a year.
  expect_identical(as.numeric(adp(13500)), 13500 / 365)
  expect_equal(round(adp(13500), 8), 36.98630137)
  expect_identical(round(adp(13500)), 37)
  # summing per-person days gives the same answer as the total
  expect_identical(adp(c(5000, 8500)), adp(13500))
})

test_that("the average length of stay is Lakner's worked example", {
  # p.17: 2,700 inmates admitted and released served 12,150 days.
  expect_equal(as.numeric(alos(12150, 2700)), 4.5)
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
  expect_identical(as.numeric(admits(25, implied)), 1750)
})

test_that("person-days come out of periodic headcounts, as on p.21", {
  # p.21: counts on 255 days summing to 34,935 over a 365-day year.
  counts <- rep(34935 / 255, 255)
  expect_identical(as.numeric(adpcnts(counts)), 50005)
  expect_identical(round(adpcnts(counts)), 50005)
  # the counts need not be equal, only their mean matters
  set.seed(1)
  jittered <- 34935 / 255 + c(-10, 10, rep(0, 253))
  expect_identical(as.numeric(adpcnts(jittered)), 50005)
})

test_that("the identity adp = n * alos / t holds", {
  # This is algebra rather than data, so it is asserted once and then
  # relied on: days = people x stay, so dividing by t either way agrees.
  days <- 126121
  people <- 9608
  expect_identical(
    as.numeric(adp(days)),
    admits(adp(days), alos(days, people)) *
      alos(days, people) /
      365
  )
  expect_identical(
    as.numeric(admits(adp(days), alos(days, people))),
    people
  )
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
  expect_equal(
    (1 + p) * (1 + l) - 1,
    sf$dayschg[2] / 100,
    tolerance = testthat::testthat_tolerance()
  )
  # adp is days per day; the stock rate is adp against the exposure
  expect_identical(sf$adp[2], 126121 / 365)
  expect_identical(sf$stkrate[2], 1e5 * (126121 / 365) / 16256538)
  expect_identical(sf$flowrate[2], 1e5 * 9608 / 16256538)
})

test_that("stkflow works without an exposure", {
  sf <- stkflow(days = c(100, 200), people = c(10, 10))
  expect_false("stkrate" %in% names(sf))
  expect_identical(sf$alos, c(10, 20))
  expect_identical(sf$adp, c(100, 200) / 365)
  expect_identical(sf$dayschg[2], 100)
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
  expect_identical(sf$exposure, c(1000, 1000))
  expect_identical(sf$flowrate, c(10, 20))
})

test_that("perdays counts both ends, and leap years look after themselves", {
  # A period from the 1st to the 31st is thirty-one days of exposure.
  expect_identical(as.numeric(perdays("2024-01-01", "2024-01-31")), 31)
  expect_identical(as.numeric(perdays("2024-01-01", "2024-01-01")), 1)
  # nobody has to know which years are leap years
  expect_identical(as.numeric(perdays("2024-01-01", "2024-12-31")), 366)
  expect_identical(as.numeric(perdays("2023-01-01", "2023-12-31")), 365)
  expect_identical(as.numeric(perdays("2025-04-01", "2026-03-31")), 365)
  # and it feeds straight into adp()
  expect_identical(
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
  expect_identical(ss$totaldays, sum(stays))
  expect_identical(ss$mean, mean(stays))
  expect_identical(ss$median, stats::median(stays))
  expect_identical(ss$max, 120)
  expect_gt(ss$mean, ss$median)
  # the mean agrees with alos() on the same data
  expect_equal(ss$mean, as.numeric(alos(sum(stays), length(stays))),
    tolerance = 1e-12)
  # the interval is the ordinary t interval on a mean
  se <- stats::sd(stays) / sqrt(length(stays))
  tq <- stats::qt(0.975, df = length(stays) - 1L)
  expect_identical(ss$se, se)
  expect_identical(ss$lower, mean(stays) - tq * se)
  expect_identical(ss$upper, mean(stays) + tq * se)
  # a wider level gives a wider interval
  w <- staysmry(stays, conflvl = 0.99)
  expect_lt(w$lower, ss$lower)
  expect_gt(w$upper, ss$upper)
})

test_that("staysmry copes with a single person and refuses nonsense", {
  one <- staysmry(7)
  expect_identical(one$n, 1L)
  expect_identical(one$mean, 7)
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
  expect_identical(sf1$dayschg, c(0, 100, 300))
  # against the previous: each doubling is +100%, and the first has none
  expect_true(is.na(sf2$dayschg[1]))
  expect_identical(sf2$dayschg[-1], c(100, 100))
  expect_identical(attr(sf2, "stkflow")$baseline, "previous")
  expect_error(
    stkflow(days = 1:2, people = c(1, 1), base = "middle"),
    "must be one of"
  )
})

test_that("the measures hold together on a period that is not a year", {
  # A thirty-day month, which is the case a hardcoded 365 would break.
  t30 <- perdays("2025-04-01", "2025-04-30")
  expect_identical(as.numeric(t30), 30)
  sf <- stkflow(
    days = c(2400, 2750),
    people = c(300, 250),
    prd = c("Apr", "May"),
    t = t30
  )
  expect_identical(sf$adp, c(2400, 2750) / 30)
  expect_identical(sf$alos, c(8, 11))
  # people down, stay up, days up: the decomposition still multiplies out
  p <- sf$peochg[2] / 100
  l <- sf$aloschg[2] / 100
  expect_equal(
    (1 + p) * (1 + l) - 1,
    sf$dayschg[2] / 100,
    tolerance = testthat::testthat_tolerance()
  )
})

test_that("perdays refuses a missing date", {
  expect_error(perdays(NA_character_, "2020-01-02"), "must be dates")
})

# ---- printed boxes -----------------------------------------------------------

# format() gives the plain lines of one titled block; print() draws them as a
# box that fits an 80-column console, ASCII where the console takes no Unicode,
# and returns the object invisibly.
expect_box <- function(x, title, has = character()) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  withr::local_options(rmoriebricklayer.width = 80, rmoriebricklayer.numcol = 1)
  txt <- format(x)
  expect_type(txt, "character")
  expect_true(grepl(title, txt[1L], fixed = TRUE), info = txt[1L])
  flat <- paste(txt, collapse = "\n")
  for (h in has) {
    expect_true(grepl(.rmbl_txt(h), flat, fixed = TRUE), info = h)
  }
  out <- utils::capture.output(print(x))
  expect_output(expect_invisible(print(x)), "+-- ", fixed = TRUE)
  expect_identical(withr::with_output_sink(nullfile(), print(x)), x)
  expect_match(out[1L], "^\\+-- ")
  expect_match(out[length(out)], "^\\+-+\\+$")
  expect_true(all(nchar(out) == nchar(out[1L])))
  expect_true(all(nchar(out) <= 79L))
  invisible(out)
}

test_that("a stock and flow table prints as a box with Lakner's caveats", {
  sf <- stkflow(
    days = c(115674, 126121),
    people = c(12647, 9608),
    prd = c("2023", "2025"),
    expo = c(15495050, 16256538)
  )
  expect_box(
    sf,
    "Stock and flow over 2 periods",
    c(
      "2023 to 2025",
      "365 days",
      "100,000 residents",
      "people -24.0%",
      "opposite signs",
      "Lakner (1976)",
      "biased downward"
    )
  )
  one <- stkflow(days = 100, people = 10)
  expect_box(one, "Stock and flow over 1 periods", "One period")
  # a subset that lost its record prints as a plain table
  expect_output(print(sf[, c("period", "adp")]), "adp")
  expect_false(any(grepl("^\\+--", utils::capture.output(print(sf[, 1:2])))))
})

test_that("staysmry() keeps its data frame and prints as a box", {
  stays <- c(rep(1, 40), rep(3, 30), rep(10, 20), 60, 90, 120)
  ss <- staysmry(stays)
  expect_s3_class(ss, c("rmbl_stay_summary", "data.frame"), exact = TRUE)
  expect_identical(nrow(ss), 1L)
  expect_identical(attr(ss, "conflvl"), 0.95)
  expect_box(
    ss,
    "Length of stay",
    c("People", "93", "Median stay", "3 days", "95% t interval", "Lakner")
  )
  expect_match(paste(format(ss), collapse = " "), "times the median")
  one <- staysmry(7)
  txt <- expect_box(one, "Length of stay", "agree")
  expect_false(any(grepl("t interval", txt, fixed = TRUE)))
  expect_box(staysmry(stays, conflvl = 0.9), "Length of stay", "90% t interval")
  expect_output(print(ss[, c("mean", "median")]), "median")
})

test_that("the shared block helpers fit, clip and label", {
  withr::local_options(rmoriebricklayer.width = 60)
  wide <- as.data.frame(
    stats::setNames(as.list(seq_len(12) * 1000.5), paste0("column", 1:12))
  )
  wide <- cbind(key = "a", wide)
  lines <- .an_fit_table(wide)
  expect_true(all(nchar(lines) <= .an_width()))
  expect_gt(sum(grepl("^  key", lines)), 1L)
  expect_identical(.an_width(), 55L)
  expect_identical(.an_ci(c(NA, 1), c(NA, 2)), c("", "[1, 2]"))
  expect_identical(.an_year(Inf), "never at this pace")
  expect_identical(.an_year(2066.9), "2066")
  expect_identical(.an_values(c("a", "b", "a")), "a; b")
  expect_identical(.an_values(letters[1:6]), "6, from a to f")
  expect_null(.an_values(NULL))
  expect_identical(.an_count(c(1234567, 2)), c("1,234,567", "        2"))
  expect_identical(.an_clip("abcdefghij", 6L), "abc...")
  expect_identical(.an_lvl(0.9), "90%")
  expect_null(.an_lvl(NULL))
  expect_identical(.an_ci_name(NULL), "interval")
  expect_identical(.an_counts(c("ok", "x", "ok")), "ok 2, x 1")
  expect_match(.an_census_year("2021A000011124"), "^2021 Census")
  expect_null(.an_census_year(NA))
  expect_identical(
    .an_nonresp(data.frame(tnrsf = 3, tnrlf = c(4, 5))),
    "short form 3%; long form 4% to 5%"
  )
  expect_null(.an_nonresp(data.frame(tnrsf = NA, tnrlf = NA)))
  expect_null(.an_caution(c(FALSE, NA)))
  expect_match(.an_caution(c(FALSE, TRUE)), "use with caution")
  expect_identical(.an_star(c("a", "b"), c(TRUE, NA)), c("a *", "b"))
  h <- .an_head(data.frame(a = 1:15), 12L)
  expect_identical(nrow(h$df), 12L)
  expect_match(h$more, "3 more rows")
  expect_null(.an_head(data.frame(a = 1:3))$more)
  kd <- data.frame(k = c("x", "y", "x"), v = 1:3, stringsAsFactors = FALSE)
  expect_named(.an_by(kd, "k", identity), c("x", "y"))
  blk <- .an_block("T", list(a = 1), list(cap = data.frame(z = 1)), "r", "n")
  expect_identical(blk[1L], .rmbl_rule("T"))
  expect_true("  cap" %in% blk)
  expect_identical(blk[length(blk)], .rmbl_rule())
})

test_that("the single measures carry a class and keep their values", {
  ms <- list(
    adp = adp(13500),
    alos = alos(12150, 2700),
    admits = admits(25, 25 * 365 / 1750),
    adpcnts = adpcnts(rep(34935 / 255, 255)),
    perdays = perdays("2024-01-01", "2024-12-31")
  )
  plain <- c(13500 / 365, 12150 / 2700, 1750, 50005, 366)
  for (i in seq_along(ms)) {
    x <- ms[[i]]
    cls <- c(paste0("rmbl_", names(ms)[i]), "rmbl_measure", "numeric")
    expect_s3_class(x, cls, exact = TRUE)
    expect_type(x, "double")
    expect_length(x, 1L)
    expect_null(names(x))
    expect_type(attr(x, "lakner"), "list")
    expect_identical(as.numeric(x), plain[i])
    expect_identical(as.double(x), plain[i])
  }
  expect_identical(attr(ms$adp, "lakner"), list(days = 13500, t = 365))
  expect_identical(attr(ms$alos, "lakner"), list(days = 12150, n = 2700))
  expect_identical(
    attr(ms$perdays, "lakner"),
    list(from = as.Date("2024-01-01"), to = as.Date("2024-12-31"))
  )
})

test_that("arithmetic on a measure gives plain numbers", {
  a <- adp(13500)
  v <- 13500 / 365
  expect_identical(a * 2, v * 2)
  expect_identical(2 * a, 2 * v)
  expect_identical(-a, -v)
  expect_identical(a + alos(12150, 2700), v + 4.5)
  expect_gt(a, 30)
  expect_identical(round(a), 37)
  expect_equal(round(a, 2), 36.99)
  expect_identical(sqrt(a), sqrt(v))
  expect_identical(sum(a), v)
  expect_identical(sum(a, a), 2 * v)
  expect_identical(max(a, 40), 40)
  expect_identical(mean(a), v)
  expect_identical(a[1], v)
  expect_identical(c(a, a), c(v, v))
  expect_identical(c(perdays("2023-01-01", "2023-12-31"), 1), c(365, 1))
  d <- data.frame(adp = a)
  expect_identical(d$adp, v)
  for (x in list(a * 2, round(a), sum(a), mean(a), a[1], c(a, a))) {
    expect_false(inherits(x, "rmbl_measure"))
    expect_null(attributes(x))
  }
})

test_that("measures feed the other measures as before", {
  t366 <- perdays("2024-01-01", "2024-12-31")
  expect_identical(as.numeric(adp(13500, t = t366)), 13500 / 366)
  expect_identical(attr(adp(13500, t = t366), "lakner")$t, 366)
  pd <- adpcnts(c(120, 130, 125, 128), t = 31)
  expect_identical(as.numeric(adp(pd, t = 31)), mean(c(120, 130, 125, 128)))
  expect_identical(attr(adp(pd, t = 31), "lakner")$days, 125.75 * 31)
  a <- adp(126121)
  l <- alos(126121, 9608)
  expect_identical(as.numeric(admits(a, l)), 9608)
  expect_identical(
    as.numeric(admits(a, l, t = perdays("2025-01-01", "2025-12-31"))),
    as.numeric(admits(a, l, t = 365))
  )
  sf <- stkflow(days = c(2400, 2750), people = c(300, 250), t = t366)
  expect_identical(sf$adp, c(2400, 2750) / 366)
})

test_that("each measure prints as a box with its inputs and formula", {
  expect_box(
    adp(13500),
    "Average daily population",
    c("36.99", "13,500", "365 days", "adp = days / t", "steady state")
  )
  expect_box(
    alos(12150, 2700),
    "Average length of stay",
    c("4.5 days per person", "2,700", "alos = days / n", "biased downward")
  )
  expect_box(
    admits(25, 25 * 365 / 1750),
    "Admissions implied by stock and stay",
    c("1,750", "adp x t / alos", "steady state", "not rounded")
  )
  expect_box(
    adpcnts(rep(34935 / 255, 255)),
    "Person-days from headcounts",
    c("50,005", "255 days counted", "mean(counts) x t", "Lakner (1976, p.21)")
  )
  expect_box(
    perdays("2024-01-01", "2024-12-31"),
    "Period length",
    c("366 days", "2024-01-01", "2024-12-31", "to - from + 1")
  )
})

test_that("a measure prints invisibly, ASCII where asked", {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  withr::local_options(rmoriebricklayer.width = 80)
  a <- adp(13500)
  expect_invisible(print(a))
  res <- withr::with_output_sink(nullfile(), print(a))
  out <- utils::capture.output(print(a))
  expect_identical(res, a)
  expect_match(out[1L], "^\\+-- Average daily population")
  expect_match(out[length(out)], "^\\+-+\\+$")
  expect_identical(format(a)[1L], .rmbl_rule("Average daily population"))
})

test_that("a measure with several values shows a small table", {
  x <- .rmbl_measure(c(a = 1.5, b = 2.5), "adp", list(days = 4, t = 2))
  txt <- format(x)
  expect_true(any(grepl("^  value +adp", txt)))
  expect_true(any(grepl("One value per row", txt, fixed = TRUE)))
  expect_identical(as.numeric(x), c(1.5, 2.5))
  expect_identical(x[2], c(b = 2.5))
  # without its record a measure formats as the plain number
  bare <- structure(2, class = c("rmbl_adp", "rmbl_measure", "numeric"))
  expect_identical(format(bare), "2")
})

test_that("a custody measure without its record formats as its number", {
  for (cls in c("rmbl_alos", "rmbl_admits", "rmbl_adpcnts", "rmbl_perdays")) {
    expect_plain_measure(cls)
  }
})

test_that("a stock and flow table of mixed period lengths lists them", {
  f <- .sf_facts(
    data.frame(period = c("a", "b"), stringsAsFactors = FALSE),
    list(t = c(30, 31), baseline = "previous", per = 1e5),
    FALSE
  )
  expect_identical(f$`Period length`, toString(.rmbl_fmt_num(c(30, 31))))
  expect_identical(f$`Changes against`, "the previous period")
  expect_null(.an_counts(NULL))
  expect_null(.an_counts(character()))
})
