# Period-over-period change.
#
# Anchors outside the module: stats::poisson.test, whose confidence
# interval for the ratio of two counts is the same conditional-binomial
# construction, so it pins the interval exactly rather than
# approximately; the percent change and CAGR written out by hand; and
# base R's own readers, which must be able to read back what the
# delimited writers produce.

test_that("the percent change is the arithmetic, not the row order", {
  d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
  y <- yoy(d, value = "n", prd = "year")
  got <- as.data.frame(y)
  expect_s3_class(y, "rmbl_yoy")
  expect_identical(got$year, 2019:2023)
  expect_identical(got$previous, c(NA, 402, 377, 190, 268))
  expect_identical(got$change, c(NA, -25, -187, 78, 63))
  expect_equal(
    got$pctchg,
    100 * (c(NA, 377, 190, 268, 331) / c(NA, 402, 377, 190, 268) - 1),
    tolerance = testthat::testthat_tolerance()
  )
  # the first period has nothing to compare with, and says so rather
  # than reporting a change of zero
  expect_true(is.na(got$pctchg[1L]))
  expect_identical(got$flag[1L], "no comparison period")
  # a bare column name works as well as a string
  expect_identical(
    as.data.frame(yoy(d, value = n, prd = year))$change,
    got$change
  )
  expect_error(yoy(d, value = "nope", prd = "year"), "not found")
  expect_error(yoy(d, value = "n", prd = "nope"), "not found")
  expect_error(yoy(d, value = "n", prd = "year", lag = 0), "positive")
  expect_error(
    yoy(d, value = "n", prd = "year", conflvl = 1),
    "strictly between 0 and 1"
  ) # the shared message since 0.5.13
})

test_that("a missing period is a gap, not a shifted comparison", {
  # This is the defect the whole design turns on: with 2021 absent,
  # matching on position would compare 2022 with 2020 and print a
  # confident number for a three-year change labelled as one year.
  d <- data.frame(year = c(2019, 2020, 2022, 2023), n = c(100, 120, 140, 150))
  got <- as.data.frame(yoy(d, value = "n", prd = "year"))
  expect_equal(got$year, 2019:2023, tolerance = testthat::testthat_tolerance())
  # 2021 is present as a row with no value
  expect_true(is.na(got$value[got$year == 2021]))
  # 2022 has no previous period, because 2021 is missing
  expect_true(is.na(got$previous[got$year == 2022]))
  expect_identical(got$flag[got$year == 2022], "no comparison period")
  # and 2023 compares with 2022, which is present
  expect_identical(got$previous[got$year == 2023], 140)
  expect_identical(got$change[got$year == 2023], 10)
  # turning completion off leaves the observed rows alone, and the
  # comparison is STILL matched on the period rather than the row
  raw <- as.data.frame(yoy(d, value = "n", prd = "year", complete = FALSE))
  expect_identical(nrow(raw), 4L)
  expect_true(is.na(raw$previous[raw$year == 2022]))
})

test_that("the count interval is exactly poisson.test's", {
  # poisson.test's interval for the ratio of two counts is the same
  # conditional-binomial (Clopper-Pearson) construction, so this is an
  # identity and not a tolerance
  for (pair in list(
    c(50, 40),
    c(3, 10),
    c(0, 7),
    c(12, 0),
    c(331, 268),
    c(1, 1),
    c(2, 2),
    c(1000, 990)
  )) {
    a <- pair[1L]
    b <- pair[2L]
    ci <- .yoy_ratio_ci(a, b, 0.95)
    ref <- stats::poisson.test(c(a, b), c(1, 1))$conf.int
    expect_equal(1 + ci$lower / 100, ref[1L], tolerance = 1e-9)
    if (is.finite(ref[2L])) {
      expect_equal(1 + ci$upper / 100, ref[2L], tolerance = 1e-9)
    } else {
      expect_true(is.infinite(ci$upper))
    }
  }
  # a different level gives a different, wider interval
  wide <- .yoy_ratio_ci(50, 40, 0.99)
  narrow <- .yoy_ratio_ci(50, 40, 0.95)
  expect_lt(wide$lower, narrow$lower)
  expect_gt(wide$upper, narrow$upper)
  expect_equal(
    1 + wide$lower / 100,
    stats::poisson.test(c(50, 40), c(1, 1), conf.level = 0.99)$conf.int[1L],
    tolerance = 1e-9
  )
  # a count of zero in both periods has no ratio at all
  z <- .yoy_ratio_ci(0, 0, 0.95)
  expect_true(is.na(z$lower))
  expect_true(is.na(z$upper))
  # the interval brackets the point estimate it belongs to
  d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
  got <- as.data.frame(yoy(d, value = "n", prd = "year"))
  ok <- !is.na(got$pctchg)
  expect_true(all(got$pctlo[ok] <= got$pctchg[ok]))
  expect_true(all(got$pctup[ok] >= got$pctchg[ok]))
})

test_that("a percent off a small base is computed, with its exact interval", {
  # two placements becoming twenty is a 900% rise; the exact interval
  # carries how little a base of two supports, so nothing is withheld
  d <- data.frame(year = 2019:2021, n = c(2, 20, 25))
  got <- as.data.frame(yoy(d, value = "n", prd = "year"))
  expect_identical(got$pctchg[got$year == 2020], 900)
  expect_true(is.na(got$flag[got$year == 2020]))
  # the interval is the exact one: conditional on 22 events, 20 fall in the
  # later period
  ci <- stats::binom.test(20, 22)$conf.int
  expect_identical(got$pctlo[got$year == 2020], 100 * (ci[1] / (1 - ci[1]) - 1))
  expect_identical(got$pctup[got$year == 2020], 100 * (ci[2] / (1 - ci[2]) - 1))
  # wide, as a base of two must be, and it contains the estimate
  expect_lt(got$pctlo[got$year == 2020], 900)
  expect_gt(got$pctup[got$year == 2020], 900)
  expect_identical(got$change[got$year == 2020], 18)
  expect_identical(got$verdict[got$year == 2020], "up")
  # a minute change off a small base is reported too
  m <- as.data.frame(yoy(
    data.frame(y = 1:2, n = c(15, 14)),
    value = "n",
    prd = "y"
  ))
  expect_identical(m$pctchg[2L], -100 / 15)
  # a note appears only when asked for, and still nothing is withheld
  noted <- as.data.frame(yoy(d, value = "n", prd = "year", minbase = 20))
  expect_identical(noted$pctchg[noted$year == 2020], 900)
  expect_identical(noted$flag[noted$year == 2020], "small base (below 20)")
  expect_true(is.na(noted$flag[noted$year == 2021]))
  # a previous period of zero has no percent change to report, whatever
  # the gate
  z <- as.data.frame(yoy(
    data.frame(y = 1:2, n = c(0, 5)),
    value = "n",
    prd = "y",
    minbase = 0
  ))
  expect_true(is.na(z$pctchg[2L]))
  expect_identical(z$flag[2L], "previous period is zero")
})

test_that("a percentage changes by points, not by percent", {
  # a rate moving from 4% to 5% is one percentage point, not 25%: the
  # two are different quantities and reporting the second as "the
  # change" is the standard error
  d <- data.frame(year = 2019:2021, share = c(4.0, 5.0, 5.5))
  got <- as.data.frame(yoy(d, value = "share", prd = "year", units = "percent"))
  expect_true("ppchg" %in% names(got))
  expect_false("pctchg" %in% names(got))
  expect_equal(got$ppchg, c(NA, 1.0, 0.5))
  # no count interval either, since these are not counts
  expect_false("pctlo" %in% names(got))
  # a measured quantity keeps its decimals rather than printing as a
  # count
  out <- utils::capture.output(print(
    yoy(d, value = "share", prd = "year", units = "percent"),
    color = FALSE
  ))
  expect_true(any(grepl("4.0", out, fixed = TRUE)))
  expect_true(any(grepl("pp", out, fixed = TRUE)))
})

test_that("count units refuse a measured quantity", {
  # the exact interval is only meaningful for counts, so a fractional
  # value is refused rather than silently rounded into one
  d <- data.frame(year = 2019:2021, x = c(1.5, 2.5, 3.5))
  expect_error(yoy(d, value = "x", prd = "year"), "whole numbers")
  expect_error(
    yoy(data.frame(y = 1:2, n = c(-1, 2)), value = "n", prd = "y"),
    "whole numbers"
  )
  # and continuous units accept it, without claiming an interval
  got <- as.data.frame(yoy(d, value = "x", prd = "year", units = "continuous"))
  expect_equal(
    got$pctchg,
    c(NA, 100 * (2.5 / 1.5 - 1), 100 * (3.5 / 2.5 - 1)),
    tolerance = testthat::testthat_tolerance()
  )
  expect_false("pctlo" %in% names(got))
  expect_error(
    yoy(
      data.frame(y = 1:2, s = c("a", "b"), stringsAsFactors = FALSE),
      value = "s",
      prd = "y"
    ),
    "must be numeric"
  )
})

test_that("groups are compared within themselves", {
  seg <- data.frame(
    year = rep(2019:2021, each = 2),
    gender = rep(c("Female", "Male"), 3),
    n = c(31, 402, 28, 377, 12, 190),
    stringsAsFactors = FALSE
  )
  got <- as.data.frame(yoy(
    seg,
    value = "n",
    prd = "year",
    by = "gender",
    minbase = 0
  ))
  f <- got[got$gender == "Female", ]
  m <- got[got$gender == "Male", ]
  # Female 2020 compares with Female 2019, not with Male 2019
  expect_identical(f$previous, c(NA, 31, 28))
  expect_identical(m$previous, c(NA, 402, 377))
  expect_identical(f$change, c(NA, -3, -16))
  expect_error(
    yoy(seg, value = "n", prd = "year", by = "nope"),
    "`by` column not found"
  )
  # two grouping columns
  seg$region <- rep(c("N", "S"), 3)
  two <- as.data.frame(yoy(
    seg,
    value = "n",
    prd = "year",
    by = c("gender", "region"),
    minbase = 0
  ))
  expect_true(all(c("gender", "region") %in% names(two)))
  expect_identical(nrow(two), 6L)
})

test_that("repeated rows inside a period are aggregated first", {
  # OTIS ships one row per placement, so a year holds many rows and the
  # measure has to be totalled before it can be compared
  d <- data.frame(
    year = c(rep(2019, 3), rep(2020, 2)),
    n = c(10, 20, 30, 25, 35)
  )
  got <- as.data.frame(yoy(d, value = "n", prd = "year"))
  expect_identical(got$value, c(60, 60))
  expect_identical(got$change, c(NA, 0))
  # another aggregation is available where a total is the wrong summary
  avg <- as.data.frame(yoy(
    d,
    value = "n",
    prd = "year",
    fun = mean,
    units = "continuous"
  ))
  expect_identical(avg$value, c(20, 30))
  expect_identical(avg$pctchg, c(NA, 50))
  # the period column keeps its own type through the aggregation
  dd <- data.frame(
    when = as.Date(c("2019-01-01", "2019-01-01", "2020-01-01")),
    n = c(1, 2, 6)
  )
  a <- as.data.frame(yoy(dd, value = "n", prd = "when", minbase = 0))
  expect_s3_class(a$when, "Date")
  expect_identical(a$value, c(3, 6))
})

test_that("a seasonal series compares with the same season", {
  # the lag for a monthly series is twelve, not one: comparing with the
  # previous OBSERVATION would put January against December
  x <- stats::ts(c(10:21, 20:31), start = c(2021, 1), frequency = 12)
  got <- as.data.frame(yoy(x, minbase = 0))
  expect_identical(nrow(got), 24L)
  # the first twelve have no counterpart a year earlier
  expect_true(all(is.na(got$previous[1:12])))
  # and the thirteenth compares with the first, which is the same month
  expect_identical(got$previous[13L], 10)
  expect_identical(got$value[13L], 20)
  expect_identical(got$change[13L], 10)
  # a quarterly series takes four
  q <- stats::ts(c(1:4, 5:8), start = c(2021, 1), frequency = 4)
  gq <- as.data.frame(yoy(q, minbase = 0))
  expect_true(all(is.na(gq$previous[1:4])))
  expect_identical(gq$previous[5L], 1)
  # an explicit lag overrides the frequency
  g1 <- as.data.frame(yoy(q, lag = 1L, minbase = 0))
  expect_identical(g1$previous[2L], 1)
  # a plain vector indexes by position when no periods are given
  v <- as.data.frame(yoy(c(100, 110, 121), minbase = 0))
  expect_identical(v$pctchg, c(NA, 10, 10))
  # and an integer vector goes the same way
  expect_identical(
    as.data.frame(yoy(c(100L, 150L), minbase = 0))$change,
    c(NA, 50)
  )
})

test_that("a longer lag compares with a longer-ago period", {
  d <- data.frame(year = 2015:2023, n = seq(100, 180, by = 10))
  l3 <- as.data.frame(yoy(d, value = "n", prd = "year", lag = 3L))
  expect_true(all(is.na(l3$previous[1:3])))
  expect_identical(l3$previous[4L], 100)
  expect_identical(l3$change[4L], 30)
  # and the footer says which lag produced the column
  out <- utils::capture.output(print(
    yoy(d, value = "n", prd = "year", lag = 3L),
    color = FALSE
  ))
  expect_true(any(grepl("lag 3 periods", out, fixed = TRUE)))
})

test_that("direction decides what counts as an improvement", {
  d <- data.frame(year = 2019:2020, n = c(100, 150))
  up <- as.data.frame(yoy(d, value = "n", prd = "year"))
  expect_identical(up$verdict[2L], "up")
  better <- as.data.frame(yoy(d, value = "n", prd = "year", dir = "higher"))
  expect_identical(better$verdict[2L], "better")
  worse <- as.data.frame(yoy(d, value = "n", prd = "year", dir = "lower"))
  expect_identical(worse$verdict[2L], "worse")
  # the arithmetic is untouched by the choice
  expect_identical(up$pctchg, worse$pctchg)
  # and an unchanged period is unchanged under every direction
  flat <- data.frame(year = 2019:2020, n = c(100, 100))
  for (dir in c("neutral", "higher", "lower")) {
    g <- as.data.frame(yoy(flat, value = "n", prd = "year", dir = dir))
    expect_identical(g$verdict[2L], "unchanged")
  }
})

test_that("the span summary is the compound rate", {
  d <- data.frame(year = 2019:2023, n = c(100, 110, 120, 130, 160))
  s <- yoysmry(yoy(d, value = "n", prd = "year"))
  expect_identical(s$first, 100)
  expect_identical(s$last, 160)
  expect_equal(s$totalpct, 60, tolerance = testthat::testthat_tolerance())
  # four steps from 100 to 160, so the compound rate per period is the
  # fourth root of the total growth
  expect_identical(s$cagrpct, 100 * ((160 / 100)^(1 / 4) - 1))
  # and compounding it back over the span returns the total
  expect_identical(100 * ((1 + s$cagrpct / 100)^4 - 1), s$totalpct)
  expect_identical(s$periods, 5L)
  expect_identical(s$up, 4L)
  expect_identical(s$down, 0L)
  # a compound rate out of zero does not exist
  z <- yoysmry(yoy(
    data.frame(y = 1:3, n = c(0, 5, 10)),
    value = "n",
    prd = "y",
    minbase = 0
  ))
  expect_true(is.na(z$cagrpct))
  expect_true(is.na(z$totalpct))
  # one row per group
  seg <- data.frame(
    year = rep(2019:2021, each = 2),
    g = rep(c("a", "b"), 3),
    n = c(10, 100, 20, 90, 30, 80),
    stringsAsFactors = FALSE
  )
  sg <- yoysmry(yoy(seg, value = "n", prd = "year", by = "g", minbase = 0))
  expect_identical(nrow(sg), 2L)
  expect_true("g" %in% names(sg))
  expect_identical(sg$totalpct[sg$g == "a"], 200)
  expect_equal(
    sg$totalpct[sg$g == "b"],
    -20,
    tolerance = testthat::testthat_tolerance()
  )
})

test_that("printing says what the percentages mean", {
  d <- data.frame(year = 2019:2021, n = c(2, 200, 250))
  out <- utils::capture.output(print(
    yoy(d, value = "n", prd = "year", dir = "lower"),
    color = FALSE
  ))
  txt <- paste(out, collapse = "\n")
  # the settings a reader needs in order to know what the column is
  expect_match(txt, "units: count")
  expect_match(txt, "exact rate-ratio interval")
  expect_false(grepl("withheld", txt, fixed = TRUE))
  expect_match(txt, "lower is better")
  # a small base prints its percent: 2 to 200 is +9900%
  expect_match(txt, "9900")
  # and the reason a particular percent is absent, on its own row
  z <- utils::capture.output(print(
    yoy(data.frame(year = 1:2, n = c(0, 4)), value = "n", prd = "year"),
    color = FALSE
  ))
  expect_match(paste(z, collapse = "\n"), "note: previous period is zero")
  # colour is off when asked, and the table is still readable
  expect_false(grepl("\033", txt, fixed = TRUE))
  # colour is emitted when asked for
  col <- utils::capture.output(print(
    yoy(d, value = "n", prd = "year"),
    color = TRUE
  ))
  expect_true(any(grepl("\033[38;2;", col, fixed = TRUE)))
  # the mono palette prints no colour even when colour is on
  mono <- utils::capture.output(print(
    yoy(d, value = "n", prd = "year"),
    color = TRUE,
    palette = "mono"
  ))
  expect_false(any(grepl("\033", mono, fixed = TRUE)))
  expect_error(
    print(yoy(d, value = "n", prd = "year"), palette = "neon"),
    "must be one of"
  )
  # row capping
  big <- data.frame(year = 2000:2050, n = seq(100, 600, by = 10))
  capped <- utils::capture.output(print(
    yoy(big, value = "n", prd = "year"),
    color = FALSE,
    n = 5L
  ))
  expect_true(any(grepl("more rows", capped, fixed = TRUE)))
  expect_true("diverging" %in% yoypals())
})

test_that("the delimited writers round-trip through base R's readers", {
  d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
  y <- yoy(d, value = "n", prd = "year")
  ref <- as.data.frame(y)

  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  yoycsv(y, f)
  back <- utils::read.csv(f, comment.char = "#")
  expect_identical(as.numeric(back$value), ref$value)
  expect_equal(
    back$pctchg,
    ref$pctchg,
    tolerance = testthat::testthat_tolerance()
  )
  # the flag travels with the numbers: a CSV that dropped it would hand
  # on the one figure the table declined to stand behind
  expect_identical(back$flag[1L], "no comparison period")
  # and the settings lead the file as comments
  head5 <- readLines(f, n = 2L)
  expect_match(head5[1L], "^#")
  expect_match(head5[1L], "units: count")
  expect_match(head5[1L], "exact rate ratio")

  g <- tempfile(fileext = ".tsv")
  on.exit(unlink(g), add = TRUE)
  yoytsv(y, g)
  bt <- utils::read.delim(g, comment.char = "#")
  expect_identical(as.numeric(bt$value), ref$value)
  # no metadata when it is not wanted
  yoycsv(y, f, meta = FALSE)
  expect_false(startsWith(readLines(f, n = 1L), "#"))
  # rounding is available for a figure meant to be read
  yoycsv(y, f, digits = 1L, meta = FALSE)
  expect_identical(utils::read.csv(f)$pctchg, round(ref$pctchg, 1L))
  # NA spelling is settable
  yoycsv(y, f, na = "NA", meta = FALSE)
  expect_true(any(grepl(",NA,", readLines(f), fixed = TRUE)))
  # text, rather than a file, when no path is given
  expect_type(yoycsv(y, NULL), "character")
  expect_match(yoycsv(y, NULL), "year,value")
})

test_that("a separator inside a field cannot break the columns", {
  # group labels come from open data, so they contain whatever the
  # publisher put in them
  d <- data.frame(
    year = rep(2019:2020, each = 2),
    region = rep(c("North, Central", "Say \"hi\""), 2),
    n = c(100, 200, 120, 180),
    stringsAsFactors = FALSE
  )
  y <- yoy(d, value = "n", prd = "year", by = "region")
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  yoycsv(y, f)
  back <- utils::read.csv(f, comment.char = "#")
  # the row count and the labels survive the comma and the quotes
  expect_identical(nrow(back), 4L)
  expect_true("North, Central" %in% back$region)
  expect_true("Say \"hi\"" %in% back$region)

  # a tab inside a field would shift every column after it in a TSV, so
  # it is replaced rather than written
  d2 <- data.frame(
    year = rep(2019:2020, each = 1),
    region = c("A\tB", "A\tB"),
    n = c(100, 120),
    stringsAsFactors = FALSE
  )
  g <- tempfile(fileext = ".tsv")
  on.exit(unlink(g), add = TRUE)
  yoytsv(yoy(d2, value = "n", prd = "year", by = "region"), g)
  bt <- utils::read.delim(g, comment.char = "#")
  expect_identical(nrow(bt), 2L)
  expect_identical(bt$region[1L], "A B")
})

test_that("the JSON keeps the settings as fields", {
  skip_if_not_installed("jsonlite")
  d <- data.frame(year = 2019:2021, n = c(100, 120, 140))
  y <- yoy(d, value = "n", prd = "year", dir = "lower")
  txt <- yoyjs(y, NULL)
  obj <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
  expect_identical(obj$settings$value, "n")
  expect_identical(obj$settings$units, "count")
  expect_identical(obj$settings$direction, "lower")
  expect_identical(obj$settings$lag, 1L)
  # an absent grouping is an absent key, not an empty object
  expect_null(obj$settings$by)
  expect_length(obj$rows, 3L)
  expect_equal(
    obj$rows[[2L]]$change,
    20,
    tolerance = testthat::testthat_tolerance()
  )
  expect_length(obj$summary, 1L)
  # a grouped table names its grouping
  g <- yoy(
    data.frame(
      year = rep(2019:2020, each = 2),
      k = rep(c("a", "b"), 2),
      n = c(1, 2, 3, 4),
      stringsAsFactors = FALSE
    ),
    value = "n",
    prd = "year",
    by = "k",
    minbase = 0
  )
  og <- jsonlite::fromJSON(yoyjs(g, NULL), simplifyVector = FALSE)
  expect_identical(unlist(og$settings$by), "k")
  # and it is written with this package's own codec
  f <- tempfile(fileext = ".json")
  on.exit(unlink(f), add = TRUE)
  yoyjs(y, f)
  expect_equal(
    fromjs(paste(readLines(f), collapse = "\n"))$rows$change,
    c(NA, 20, 20),
    tolerance = testthat::testthat_tolerance()
  )
})

test_that("the Markdown table lines up and escapes its cells", {
  d <- data.frame(year = 2019:2021, n = c(100, 120, 140))
  md <- yoymd(yoy(d, value = "n", prd = "year"), NULL)
  lines <- strsplit(md, "\n", fixed = TRUE)[[1L]]
  tbl <- lines[startsWith(lines, "|")]
  expect_gte(length(tbl), 5L)
  # every row has the same number of cells, which is what makes it a
  # table rather than five paragraphs
  counts <- vapply(
    tbl,
    function(l) {
      length(strsplit(l, "|", fixed = TRUE)[[1L]])
    },
    0L
  )
  expect_length(unique(counts), 1L)
  # the rule is exactly as wide as its header, so the source reads as a
  # table before it is rendered
  expect_identical(nchar(tbl[1L]), nchar(tbl[2L]))
  # right-aligned numeric columns are marked as such
  expect_match(tbl[2L], "-:")
  # a pipe inside a label is escaped instead of ending the cell
  p <- yoymd(
    yoy(
      data.frame(
        year = rep(2019:2020, each = 1),
        k = c("a|b", "a|b"),
        n = c(10, 20),
        stringsAsFactors = FALSE
      ),
      value = "n",
      prd = "year",
      by = "k",
      minbase = 0
    ),
    NULL
  )
  expect_match(p, "a\\\\|b")
  # unaligned output is still a valid table
  u <- yoymd(yoy(d, value = "n", prd = "year"), NULL, align = FALSE)
  expect_match(u, "| year |", fixed = TRUE)
})

test_that("the HTML is self-contained and escapes its content", {
  d <- data.frame(
    year = rep(2019:2020, each = 1),
    region = c("<script>alert(1)</script>", "x"),
    n = c(100, 120),
    stringsAsFactors = FALSE
  )
  y <- yoy(d, value = "n", prd = "year", by = "region", minbase = 0)
  f <- tempfile(fileext = ".html")
  on.exit(unlink(f), add = TRUE)
  yoyhtml(y, f, title = "A & B <report>", notes = "Note <here>")
  txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
  # a group label comes from open data, so markup in it must not survive
  # as markup
  expect_false(grepl("<script>", txt, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;", txt, fixed = TRUE))
  expect_true(grepl("A &amp; B &lt;report&gt;", txt, fixed = TRUE))
  expect_true(grepl("Note &lt;here&gt;", txt, fixed = TRUE))
  # nothing is fetched at render time, so the page looks the same later
  # as it did when the capsule was sealed
  expect_false(grepl("http://", txt, fixed = TRUE))
  expect_false(grepl("https://", txt, fixed = TRUE))
  expect_false(grepl("<link", txt, fixed = TRUE))
  expect_false(grepl("<script", txt, fixed = TRUE))
  # the palette is defined as tokens, with a dark variant
  expect_true(grepl("prefers-color-scheme", txt, fixed = TRUE))
  expect_true(grepl("--bad:", txt, fixed = TRUE))
  # the settings reach the page
  expect_true(grepl("units: count", txt, fixed = TRUE))
  # the summary cards
  expect_true(grepl("Across the span", txt, fixed = TRUE))
  # bars can be turned off
  yoyhtml(y, f, bars = FALSE)
  expect_false(grepl(
    "class=\"bar",
    paste(readLines(f, warn = FALSE), collapse = ""),
    fixed = TRUE
  ))
  expect_error(yoyhtml(list(), f), "rmbl_yoy")
})

test_that("the PDF is a PDF, and pages rather than truncates", {
  d <- data.frame(year = 2000:2060, n = seq(100, 700, by = 10))
  y <- yoy(d, value = "n", prd = "year")
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f), add = TRUE)
  expect_silent(yoypdf(y, f, title = "Long table"))
  # the file really is a PDF
  expect_identical(rawToChar(readBin(f, "raw", 5L)), "%PDF-")
  expect_gt(file.size(f), 1000)
  # 61 rows do not fit on one page, so there is more than one. The file
  # is binary, so count the marker over the BYTES rather than decoding
  # it as text in the session's encoding.
  bytes <- readBin(f, "raw", file.size(f))
  marker <- charToRaw("/Type /Page")
  hits <- 0L
  for (i in seq_len(length(bytes) - length(marker))) {
    if (
      identical(bytes[i:(i + length(marker) - 1L)], marker) &&
        !identical(bytes[i + length(marker)], charToRaw("s"))
    ) {
      hits <- hits + 1L
    }
  }
  expect_gt(hits, 1L)
  # a short table needs only one page, and draws without the glyph
  # substitution warnings the device's base fonts would otherwise emit
  short <- yoy(
    data.frame(year = 2019:2021, n = c(100, 120, 140)),
    value = "n",
    prd = "year"
  )
  expect_silent(yoypdf(short, f))
  expect_error(yoypdf(list(), f), "rmbl_yoy")
})

test_that("the format follows the file name", {
  d <- data.frame(year = 2019:2021, n = c(100, 120, 140))
  y <- yoy(d, value = "n", prd = "year")
  for (ext in c(
    "csv",
    "tsv",
    "tab",
    "json",
    "md",
    "markdown",
    "html",
    "htm",
    "pdf"
  )) {
    f <- tempfile(fileext = paste0(".", ext))
    yoywr(y, f)
    expect_true(file.exists(f))
    expect_gt(file.size(f), 50)
    unlink(f)
  }
  # an upper-case extension is the same extension
  f <- tempfile(fileext = ".CSV")
  yoywr(y, f)
  expect_match(paste(readLines(f), collapse = ""), "year,value")
  unlink(f)
  # an unrecognised name asks rather than guessing
  expect_error(yoywr(y, tempfile(fileext = ".xyz")), "cannot tell the format")
  # and an explicit format overrides the name
  f <- tempfile(fileext = ".xyz")
  yoywr(y, f, format = "csv")
  expect_match(paste(readLines(f), collapse = ""), "year,value")
  unlink(f)
  expect_error(yoywr(y, tempfile(), format = "xml"), "unknown format")
  expect_error(yoywr(list(), tempfile(fileext = ".csv")), "rmbl_yoy")
})

test_that("degenerate input degrades rather than erroring", {
  # one period has nothing to compare with
  one <- as.data.frame(yoy(
    data.frame(y = 2019, n = 100),
    value = "n",
    prd = "y"
  ))
  expect_identical(nrow(one), 1L)
  expect_true(is.na(one$previous))
  expect_identical(one$flag, "no comparison period")
  expect_identical(
    nrow(yoysmry(yoy(data.frame(y = 2019, n = 100), value = "n", prd = "y"))),
    1L
  )
  # an all-missing value column
  na <- yoy(
    data.frame(y = 2019:2021, n = c(NA_real_, NA, NA)),
    value = "n",
    prd = "y"
  )
  expect_identical(nrow(as.data.frame(na)), 3L)
  expect_true(all(is.na(as.data.frame(na)$pctchg)))
  s <- yoysmry(na)
  expect_identical(s$periods, 0L)
  expect_true(is.na(s$cagrpct))
  # an empty table prints without erroring
  empty <- yoy(
    data.frame(y = numeric(0), n = numeric(0)),
    value = "n",
    prd = "y"
  )
  expect_identical(nrow(as.data.frame(empty)), 0L)
  expect_output(print(empty), "no periods")
  # and writes an empty file with only its header
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  yoycsv(empty, f, meta = FALSE)
  expect_length(readLines(f), 1L)
  # an irregular period column has no grid, so nothing is compared and
  # nothing is invented
  irr <- as.data.frame(yoy(
    data.frame(y = c(1, 2, 5, 11), n = c(1, 2, 3, 4)),
    value = "n",
    prd = "y",
    minbase = 0
  ))
  expect_true(all(c("previous", "change") %in% names(irr)))
})

test_that("a label changes the printing and nothing else", {
  seg <- data.frame(EndFiscalYear = 2019:2023, n = c(402, 377, 190, 268, 331))
  y <- yoy(seg, value = n, prd = EndFiscalYear)
  # 2023 keys the fiscal year 2022/23, so printing it as "2023" names a
  # calendar year the row is not about
  expect_identical(
    fylbl(2019:2023),
    c("2018/19", "2019/20", "2020/21", "2021/22", "2022/23")
  )
  expect_identical(fylbl(2023, short = FALSE), "2022/2023")
  expect_identical(fylbl(2023, sep = "-"), "2022-23")
  expect_true(is.na(fylbl("not a year")))
  expect_identical(fylbl(2000), "1999/00")

  lab <- yoylbl(y, fylbl)
  # the arithmetic already ran on the period's value, so a label cannot
  # move a number
  expect_identical(as.data.frame(lab)$pctchg, as.data.frame(y)$pctchg)
  expect_identical(as.data.frame(lab)$previous, as.data.frame(y)$previous)
  expect_identical(as.data.frame(lab)$EndFiscalYear, 2019:2023)

  # and it reaches every renderer, not just the one it was tested on
  out <- paste(
    utils::capture.output(print(lab, color = FALSE)),
    collapse = "\n"
  )
  expect_match(out, "2022/23", fixed = TRUE)
  expect_match(yoymd(lab, NULL), "2022/23", fixed = TRUE)
  expect_match(yoycsv(lab, NULL), "2022/23", fixed = TRUE)
  h <- tempfile(fileext = ".html")
  on.exit(unlink(h), add = TRUE)
  yoyhtml(lab, h)
  expect_match(
    paste(readLines(h, warn = FALSE), collapse = ""),
    "2022/23",
    fixed = TRUE
  )
  pf <- tempfile(fileext = ".pdf")
  on.exit(unlink(pf), add = TRUE)
  expect_silent(yoypdf(lab, pf))

  # a plain function
  f <- yoylbl(y, function(p) paste0("FY", substr(p, 3L, 4L)))
  expect_match(yoycsv(f, NULL), "FY19", fixed = TRUE)
  # a named mapping relabels only what it names
  n <- as.data.frame(yoylbl(y, c("2020" = "2019/20 (COVID)")))
  expect_identical(n$perlbl[n$EndFiscalYear == 2020], "2019/20 (COVID)")
  expect_identical(n$perlbl[n$EndFiscalYear == 2021], "2021")
  # an unnamed vector must cover every period
  expect_identical(
    as.data.frame(
      yoylbl(y, c("a", "b", "c", "d", "e"))
    )$perlbl,
    c("a", "b", "c", "d", "e")
  )
  expect_error(yoylbl(y, c("a", "b")), "distinct periods")
  expect_error(yoylbl(list(), fylbl), "rmbl_yoy")
  # labels repeat correctly across groups, which share their periods
  g <- yoy(
    data.frame(
      y = rep(2019:2020, each = 2),
      k = rep(c("a", "b"), 2),
      n = c(100, 200, 120, 180),
      stringsAsFactors = FALSE
    ),
    value = "n",
    prd = "y",
    by = "k"
  )
  gl <- as.data.frame(yoylbl(g, fylbl))
  expect_identical(gl$perlbl, fylbl(gl$y))
})

test_that(
  paste0(
    "the period helpers restore every key class and refuse a grid with no ",
    "step"
  ),
  {
    expect_identical(
      .yoy_restore(c("b", "a"), factor(c("a", "b"))),
      factor(c("b", "a"), levels = c("a", "b"))
    )
    expect_identical(.yoy_restore(c("TRUE", "FALSE"), TRUE), c(TRUE, FALSE))
    expect_identical(.yoy_restore("x", "x"), "x")
    expect_true(is.na(.yoy_gcd(numeric(0))))
    expect_null(.yoy_period_grid(c(1, Inf)))
    expect_null(.yoy_period_grid(as.Date(c(0, Inf), origin = "1970-01-01")))
    expect_identical(
      .yoy_previous(c(1, Inf), c(1, 2), 1L),
      c(NA_real_, NA_real_)
    )
  }
)

test_that(
  paste0(
    "several rows of one period: counts add ",
    "up, percentages are averaged"
  ),
  {
    d <- data.frame(
      year = c(2019, 2019, 2020, 2020),
      share = c(53, 57.9, 60, 62)
    )
    p <- yoy(d, value = "share", prd = "year", units = "percent")
    expect_identical(p$value[p$year == 2019], mean(c(53, 57.9)))
    n <- data.frame(year = c(2019, 2019, 2020, 2020), cases = c(53, 58, 60, 62))
    k <- yoy(n, value = "cases", prd = "year", units = "count")
    expect_identical(k$value[k$year == 2019], 53 + 58)
    m <- yoy(d, value = "share", prd = "year", units = "percent", fun = max)
    expect_equal(m$value[m$year == 2019], 57.9)
  }
)

test_that("the printed footer names a minbase only when one was set", {
  d <- data.frame(year = 2019:2021, n = c(2, 20, 25))
  plain <- paste(
    utils::capture.output(print(
      yoy(d, value = "n", prd = "year"),
      color = FALSE
    )),
    collapse = "\n"
  )
  expect_false(grepl("bases below", plain, fixed = TRUE))
  noted <- paste(
    utils::capture.output(print(
      yoy(d, value = "n", prd = "year", minbase = 20),
      color = FALSE
    )),
    collapse = "\n"
  )
  expect_match(noted, "bases below 20 noted", fixed = TRUE)
  expect_match(noted, "note: small base (below 20)", fixed = TRUE)
})

test_that("a grouped table prints its group columns first", {
  d <- data.frame(
    year = rep(2020:2022, 2),
    g = rep(c("a", "b"), each = 3),
    n = c(10, 12, 15, 30, 28, 33),
    stringsAsFactors = FALSE
  )
  out <- utils::capture.output(print(
    yoy(d, value = "n", prd = "year", by = "g"),
    color = FALSE
  ))
  # the header row of the table, inside the box
  hdr <- grep("change %", out, fixed = TRUE, value = TRUE)[1]
  expect_gt(regexpr("\\bg\\b", hdr), 0L)
  expect_lt(regexpr("\\bg\\b", hdr), regexpr("year", hdr, fixed = TRUE))
  expect_true(any(grepl("^\\S?\\s*b\\s", out)))
})

test_that("text periods of every form are read in calendar order (C18)", {
  rd <- function(p, ...) {
    d <- data.frame(p = p, n = seq_along(p) * 10, stringsAsFactors = FALSE)
    as.data.frame(yoy(d, "n", "p", ...))
  }
  # each form: two consecutive periods and one after a gap
  forms <- list(
    year = c("1987", "1988", "1990"),
    fy2 = c("2019/20", "2020/21", "2022/23"),
    fy4 = c("2019-2020", "2020-2021", "2022-2023"),
    fyd = c("2019-20", "2020-21", "2022-23"),
    fyp = c("FY 2019-20", "FY 2020-21", "FY 2022-23"),
    fy1 = c("FY2020", "FY2021", "FY2023"),
    qa = c("2021 Q3", "2021 Q4", "2022 Q2"),
    qb = c("2021Q3", "2021Q4", "2022Q2"),
    qc = c("2021-Q3", "2021-Q4", "2022-Q2"),
    qd = c("Q3 2021", "Q4 2021", "Q2 2022"),
    ma = c("2021-11", "2021-12", "2022-02"),
    mb = c("2021/11", "2021/12", "2022/02"),
    mc = c("Nov 2021", "December 2021", "Feb 2022"),
    md = c("2021 Nov", "2021 Dec", "2022 Feb"),
    dt = c("2021-03-01", "2021-04-01", "2021-06-01")
  )
  for (nm in names(forms)) {
    p <- forms[[nm]]
    # given out of order: the reader sorts them, not the alphabet
    y <- expect_silent(rd(rev(p)))
    got <- y[!is.na(y$value), ]
    expect_identical(got$p, p, info = nm)
    expect_identical(got$previous, c(NA, 30, NA), info = nm)
    # the gap is a row of its own, spelled like the others
    expect_identical(nrow(y), 4L, info = nm)
    expect_identical(y$flag[3L], "no data", info = nm)
  }
  expect_identical(rd(forms$fy2)$p[3L], "2021/22")
  expect_identical(rd(forms$qd)$p[3L], "Q1 2022")
  expect_identical(rd(forms$mc)$p[3L], "Jan 2022")
  expect_identical(rd(forms$fyp)$p[3L], "FY 2021-22")
  # complete = FALSE: no row for the gap, and still no comparison across it
  nc <- rd(forms$qa, complete = FALSE)
  expect_identical(nc$previous, c(NA, 10, NA))
  # years before 1900 and after 2030 alike
  expect_identical(rd(c("1899", "2031", "2030"))$previous[132:133], c(NA, 30))
})

test_that("labels yoy() cannot order warn once and name them (C18)", {
  d <- data.frame(
    p = c("Q1", "Q2", "Q3"),
    n = 1:3 * 10,
    stringsAsFactors = FALSE
  )
  expect_warning(
    yoy(d, "n", "p"),
    "\"Q1\", \"Q2\", \"Q3\" are of no form yoy\\(\\) reads.*`prdord`"
  )
  y <- suppressWarnings(yoy(d, "n", "p"))
  expect_identical(y$flag, rep("no comparison period", 3L))
  mixed <- data.frame(
    p = c("2020", "2021", "2022 Q1"),
    n = 1:3,
    stringsAsFactors = FALSE
  )
  w <- testthat::capture_warnings(yoy(mixed, "n", "p"))
  expect_length(w, 1L)
  expect_match(w, "\"2022 Q1\" are not years like the others")
  # "2010-11" is a fiscal year and November 2010 alike
  amb <- data.frame(
    p = c("2010-11", "2011-12"),
    n = 1:2,
    stringsAsFactors = FALSE
  )
  expect_warning(yoy(amb, "n", "p"), "fiscal years or as months alike")
  # a second year that does not follow the first is no fiscal year
  expect_warning(
    yoy(
      data.frame(
        p = c("2019/21", "2020/22"),
        n = 1:2,
        stringsAsFactors = FALSE
      ),
      "n",
      "p"
    ),
    "no form"
  )
})

test_that("prdord orders labels the reader does not know (C18)", {
  d <- data.frame(
    s = c("fall", "spring", "summer"),
    n = c(30, 10, 20),
    stringsAsFactors = FALSE
  )
  ord <- c("spring", "summer", "fall", "winter")
  y <- as.data.frame(yoy(d, "n", "s", prdord = ord))
  expect_identical(y$s, c("spring", "summer", "fall"))
  expect_identical(y$previous, c(NA, 10, 20))
  # a label prdord lists that the data lacks is a gap
  g <- as.data.frame(yoy(d[-3, ], "n", "s", prdord = ord))
  expect_identical(g$flag[2L], "no data")
  expect_true(is.na(g$previous[3L]))
  # numeric method and the 0.5.x argument names pass it through
  v <- yoy(c(5, 6), prd = c("b", "a"), prdord = c("a", "b"))
  expect_identical(v$previous, c(NA, 6))
  o <- yoy(d, "n", period = "s", prdord = ord)
  expect_true(any(vapply(o, identical, NA, c(NA, 10, 20))))
  # a factor too
  f <- yoy(transform(d, s = factor(s)), "n", "s", prdord = ord)
  expect_identical(f$previous, c(NA, 10, 20))
  expect_error(
    yoy(d, "n", "s", prdord = c("spring", "summer")),
    "yoy: `prdord` must list every period label; it lacks \"fall\""
  )
  expect_error(
    yoy(d, "n", "s", prdord = c("spring", "spring")),
    "`prdord` must be the period labels in order"
  )
  expect_error(
    yoy(data.frame(y = 1:2, n = 1:2), "n", "y", prdord = c("1", "2")),
    "`prdord` orders text periods, but the `prd` column is integer"
  )
})

test_that("an ordered factor stays ordered when its rows are combined", {
  d <- data.frame(
    p = factor(c("lo", "lo", "hi"), levels = c("lo", "hi"), ordered = TRUE),
    n = c(1, 2, 6)
  )
  y <- yoy(d, "n", "p")
  expect_s3_class(y$p, "ordered")
  expect_identical(y$previous, c(NA, 3))
})

test_that("the period readers handle numbers, factors and month labels", {
  expect_identical(.yoy_prd_read(1:3), list(p = 1:3))
  na <- c(NA_character_, NA_character_)
  expect_identical(.yoy_prd_read(na), list(p = na))
  expect_null(.yoy_prd_rank(factor(c("b", "a"))))
  expect_identical(.yoy_prd_sort(c("b", NA, "a", "b")), c("a", "b"))
  expect_identical(.yoy_prd_sort(c(3, 1, 2)), c(1, 2, 3))
  expect_identical(.yoy_lab_month("JAN 2020", 12 * 2021 + 1), "FEB 2021")
})

test_that("the first period is said once, not once per group or on the plot", {
  d <- data.frame(
    year = rep(2021:2024, 5),
    g = rep(letters[1:5], each = 4),
    n = c(10, 12, 15, 11, 20, 0, 25, 30, 5, 0, 7, 9, 8, 9, 10, 12, 3, 4, 5, 6)
  )
  y <- yoy(d, value = "n", prd = "year", by = "g")
  out <- format(y)
  expect_false(any(grepl("note: no comparison period", out, fixed = TRUE)))
  fn <- grep("first period of each group", out, fixed = TRUE)
  expect_length(fn, 1L)
  expect_match(out[fn], "has nothing to compare with")
  # the zero bases keep their own note, one per row
  expect_length(grep("previous period is zero", out, fixed = TRUE), 2L)
  y1 <- yoy(c(10, 12, 15))
  expect_true(any(grepl("Note: the first period has nothing", format(y1),
                        fixed = TRUE)))
  y2 <- yoy(c(10, 12, 15, 11), lag = 2)
  expect_true(any(grepl("the first 2 periods have nothing", format(y2),
                        fixed = TRUE)))
  # the plot draws no first-period label and each other reason once
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  rec <- new.env()
  rec$calls <- character()
  local_mocked_bindings(
    text = function(x, y, labels, ...) rec$calls <- c(rec$calls, labels),
    .package = "graphics"
  )
  plot(y)
  expect_false(any(grepl("first period", rec$calls, fixed = TRUE)))
  expect_identical(
    sum(grepl("previous period is zero", rec$calls, fixed = TRUE)), 1L
  )
  # the HTML table says it once too, under the table
  f <- withr::local_tempfile(fileext = ".html")
  yoyhtml(y, f)
  h <- paste(readLines(f, encoding = "UTF-8"), collapse = "\n")
  expect_false(grepl("note: no comparison period", h, fixed = TRUE))
  expect_identical(
    lengths(regmatches(h, gregexpr("first period of each group", h,
                                   fixed = TRUE))),
    1L
  )
})

