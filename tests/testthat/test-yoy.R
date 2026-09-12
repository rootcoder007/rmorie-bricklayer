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
  y <- yoy(d, value = "n", period = "year")
  got <- as.data.frame(y)
  expect_s3_class(y, "rmbl_yoy")
  expect_equal(got$year, 2019:2023)
  expect_equal(got$previous, c(NA, 402, 377, 190, 268))
  expect_equal(got$change, c(NA, -25, -187, 78, 63))
  expect_equal(got$pct_change,
               100 * (c(NA, 377, 190, 268, 331) / c(NA, 402, 377, 190, 268) - 1))
  # the first period has nothing to compare with, and says so rather
  # than reporting a change of zero
  expect_true(is.na(got$pct_change[1L]))
  expect_identical(got$flag[1L], "no comparison period")
  # a bare column name works as well as a string
  expect_equal(as.data.frame(yoy(d, value = n, period = year))$change,
               got$change)
  expect_error(yoy(d, value = "nope", period = "year"), "not found")
  expect_error(yoy(d, value = "n", period = "nope"), "not found")
  expect_error(yoy(d, value = "n", period = "year", lag = 0), "positive")
  expect_error(yoy(d, value = "n", period = "year", conf_level = 1),
               "strictly inside")
})

test_that("a missing period is a gap, not a shifted comparison", {
  # This is the defect the whole design turns on: with 2021 absent,
  # matching on position would compare 2022 with 2020 and print a
  # confident number for a three-year change labelled as one year.
  d <- data.frame(year = c(2019, 2020, 2022, 2023), n = c(100, 120, 140, 150))
  got <- as.data.frame(yoy(d, value = "n", period = "year"))
  expect_equal(got$year, 2019:2023)
  # 2021 is present as a row with no value
  expect_true(is.na(got$value[got$year == 2021]))
  # 2022 has no previous period, because 2021 is missing
  expect_true(is.na(got$previous[got$year == 2022]))
  expect_identical(got$flag[got$year == 2022], "no comparison period")
  # and 2023 compares with 2022, which is present
  expect_equal(got$previous[got$year == 2023], 140)
  expect_equal(got$change[got$year == 2023], 10)
  # turning completion off leaves the observed rows alone, and the
  # comparison is STILL matched on the period rather than the row
  raw <- as.data.frame(yoy(d, value = "n", period = "year",
                           complete = FALSE))
  expect_equal(nrow(raw), 4L)
  expect_true(is.na(raw$previous[raw$year == 2022]))
})

test_that("the count interval is exactly poisson.test's", {
  # poisson.test's interval for the ratio of two counts is the same
  # conditional-binomial (Clopper-Pearson) construction, so this is an
  # identity and not a tolerance
  for (pair in list(c(50, 40), c(3, 10), c(0, 7), c(12, 0), c(331, 268),
                    c(1, 1), c(2, 2), c(1000, 990))) {
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
  expect_equal(1 + wide$lower / 100,
               stats::poisson.test(c(50, 40), c(1, 1),
                                   conf.level = 0.99)$conf.int[1L],
               tolerance = 1e-9)
  # a count of zero in both periods has no ratio at all
  z <- .yoy_ratio_ci(0, 0, 0.95)
  expect_true(is.na(z$lower) && is.na(z$upper))
  # the interval brackets the point estimate it belongs to
  d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
  got <- as.data.frame(yoy(d, value = "n", period = "year"))
  ok <- !is.na(got$pct_change)
  expect_true(all(got$pct_lower[ok] <= got$pct_change[ok]))
  expect_true(all(got$pct_upper[ok] >= got$pct_change[ok]))
})

test_that("a percent off a small base is withheld, not printed", {
  # two placements becoming twenty is a 900% rise and also nothing at
  # all; the number describes the denominator's smallness
  d <- data.frame(year = 2019:2021, n = c(2, 20, 25))
  got <- as.data.frame(yoy(d, value = "n", period = "year"))
  expect_true(is.na(got$pct_change[got$year == 2020]))
  expect_match(got$flag[got$year == 2020], "base below 20")
  # and the interval is withheld with it, since it would be as wide as
  # the percent is unstable
  expect_true(is.na(got$pct_lower[got$year == 2020]))
  # the change itself is NOT withheld: 18 more is a fact
  expect_equal(got$change[got$year == 2020], 18)
  # nor is the direction, which is the one thing not in question
  expect_identical(got$verdict[got$year == 2020], "up")
  # a base above the gate reports normally
  expect_false(is.na(got$pct_change[got$year == 2021]))
  # the gate can be lowered or removed
  loose <- as.data.frame(yoy(d, value = "n", period = "year",
                             min_base = 0))
  expect_equal(loose$pct_change[loose$year == 2020], 900)
  expect_true(is.na(loose$flag[loose$year == 2020]))
  # a previous period of zero has no percent change to report, whatever
  # the gate
  z <- as.data.frame(yoy(data.frame(y = 1:2, n = c(0, 5)),
                         value = "n", period = "y", min_base = 0))
  expect_true(is.na(z$pct_change[2L]))
  expect_identical(z$flag[2L], "previous period is zero")
})

test_that("a percentage changes by points, not by percent", {
  # a rate moving from 4% to 5% is one percentage point, not 25%: the
  # two are different quantities and reporting the second as "the
  # change" is the standard error
  d <- data.frame(year = 2019:2021, share = c(4.0, 5.0, 5.5))
  got <- as.data.frame(yoy(d, value = "share", period = "year",
                           units = "percent"))
  expect_true("pp_change" %in% names(got))
  expect_false("pct_change" %in% names(got))
  expect_equal(got$pp_change, c(NA, 1.0, 0.5))
  # no count interval either, since these are not counts
  expect_false("pct_lower" %in% names(got))
  # a measured quantity keeps its decimals rather than printing as a
  # count
  out <- utils::capture.output(print(yoy(d, value = "share",
                                         period = "year",
                                         units = "percent"),
                                     color = FALSE))
  expect_true(any(grepl("4.0", out, fixed = TRUE)))
  expect_true(any(grepl("pp", out, fixed = TRUE)))
})

test_that("count units refuse a measured quantity", {
  # the exact interval is only meaningful for counts, so a fractional
  # value is refused rather than silently rounded into one
  d <- data.frame(year = 2019:2021, x = c(1.5, 2.5, 3.5))
  expect_error(yoy(d, value = "x", period = "year"), "whole numbers")
  expect_error(yoy(data.frame(y = 1:2, n = c(-1, 2)), value = "n",
                   period = "y"), "whole numbers")
  # and continuous units accept it, without claiming an interval
  got <- as.data.frame(yoy(d, value = "x", period = "year",
                           units = "continuous"))
  expect_equal(got$pct_change, c(NA, 100 * (2.5 / 1.5 - 1),
                                 100 * (3.5 / 2.5 - 1)))
  expect_false("pct_lower" %in% names(got))
  expect_error(yoy(data.frame(y = 1:2, s = c("a", "b")), value = "s",
                   period = "y"), "must be numeric")
})

test_that("groups are compared within themselves", {
  seg <- data.frame(
    year = rep(2019:2021, each = 2),
    gender = rep(c("Female", "Male"), 3),
    n = c(31, 402, 28, 377, 12, 190))
  got <- as.data.frame(yoy(seg, value = "n", period = "year",
                           by = "gender", min_base = 0))
  f <- got[got$gender == "Female", ]
  m <- got[got$gender == "Male", ]
  # Female 2020 compares with Female 2019, not with Male 2019
  expect_equal(f$previous, c(NA, 31, 28))
  expect_equal(m$previous, c(NA, 402, 377))
  expect_equal(f$change, c(NA, -3, -16))
  expect_error(yoy(seg, value = "n", period = "year", by = "nope"),
               "`by` column not found")
  # two grouping columns
  seg$region <- rep(c("N", "S"), 3)
  two <- as.data.frame(yoy(seg, value = "n", period = "year",
                           by = c("gender", "region"), min_base = 0))
  expect_true(all(c("gender", "region") %in% names(two)))
  expect_equal(nrow(two), 6L)
})

test_that("repeated rows inside a period are aggregated first", {
  # OTIS ships one row per placement, so a year holds many rows and the
  # measure has to be totalled before it can be compared
  d <- data.frame(year = c(rep(2019, 3), rep(2020, 2)),
                  n = c(10, 20, 30, 25, 35))
  got <- as.data.frame(yoy(d, value = "n", period = "year"))
  expect_equal(got$value, c(60, 60))
  expect_equal(got$change, c(NA, 0))
  # another aggregation is available where a total is the wrong summary
  avg <- as.data.frame(yoy(d, value = "n", period = "year", fun = mean,
                           units = "continuous"))
  expect_equal(avg$value, c(20, 30))
  expect_equal(avg$pct_change, c(NA, 50))
  # the period column keeps its own type through the aggregation
  dd <- data.frame(when = as.Date(c("2019-01-01", "2019-01-01",
                                    "2020-01-01")),
                   n = c(1, 2, 6))
  a <- as.data.frame(yoy(dd, value = "n", period = "when", min_base = 0))
  expect_s3_class(a$when, "Date")
  expect_equal(a$value, c(3, 6))
})

test_that("a seasonal series compares with the same season", {
  # the lag for a monthly series is twelve, not one: comparing with the
  # previous OBSERVATION would put January against December
  x <- stats::ts(c(10:21, 20:31), start = c(2021, 1), frequency = 12)
  got <- as.data.frame(yoy(x, min_base = 0))
  expect_equal(nrow(got), 24L)
  # the first twelve have no counterpart a year earlier
  expect_true(all(is.na(got$previous[1:12])))
  # and the thirteenth compares with the first, which is the same month
  expect_equal(got$previous[13L], 10)
  expect_equal(got$value[13L], 20)
  expect_equal(got$change[13L], 10)
  # a quarterly series takes four
  q <- stats::ts(c(1:4, 5:8), start = c(2021, 1), frequency = 4)
  gq <- as.data.frame(yoy(q, min_base = 0))
  expect_true(all(is.na(gq$previous[1:4])))
  expect_equal(gq$previous[5L], 1)
  # an explicit lag overrides the frequency
  g1 <- as.data.frame(yoy(q, lag = 1L, min_base = 0))
  expect_equal(g1$previous[2L], 1)
  # a plain vector indexes by position when no periods are given
  v <- as.data.frame(yoy(c(100, 110, 121), min_base = 0))
  expect_equal(v$pct_change, c(NA, 10, 10))
  # and an integer vector goes the same way
  expect_equal(as.data.frame(yoy(c(100L, 150L), min_base = 0))$change,
               c(NA, 50))
})

test_that("a longer lag compares with a longer-ago period", {
  d <- data.frame(year = 2015:2023, n = seq(100, 180, by = 10))
  l3 <- as.data.frame(yoy(d, value = "n", period = "year", lag = 3L))
  expect_true(all(is.na(l3$previous[1:3])))
  expect_equal(l3$previous[4L], 100)
  expect_equal(l3$change[4L], 30)
  # and the footer says which lag produced the column
  out <- utils::capture.output(print(yoy(d, value = "n", period = "year",
                                         lag = 3L), color = FALSE))
  expect_true(any(grepl("lag 3 periods", out, fixed = TRUE)))
})

test_that("direction decides what counts as an improvement", {
  d <- data.frame(year = 2019:2020, n = c(100, 150))
  up <- as.data.frame(yoy(d, value = "n", period = "year"))
  expect_identical(up$verdict[2L], "up")
  better <- as.data.frame(yoy(d, value = "n", period = "year",
                              direction = "higher_is_better"))
  expect_identical(better$verdict[2L], "better")
  worse <- as.data.frame(yoy(d, value = "n", period = "year",
                             direction = "lower_is_better"))
  expect_identical(worse$verdict[2L], "worse")
  # the arithmetic is untouched by the choice
  expect_equal(up$pct_change, worse$pct_change)
  # and an unchanged period is unchanged under every direction
  flat <- data.frame(year = 2019:2020, n = c(100, 100))
  for (dir in c("neutral", "higher_is_better", "lower_is_better")) {
    g <- as.data.frame(yoy(flat, value = "n", period = "year",
                           direction = dir))
    expect_identical(g$verdict[2L], "unchanged")
  }
})

test_that("the span summary is the compound rate", {
  d <- data.frame(year = 2019:2023, n = c(100, 110, 120, 130, 160))
  s <- yoy_summary(yoy(d, value = "n", period = "year"))
  expect_equal(s$first, 100)
  expect_equal(s$last, 160)
  expect_equal(s$total_pct, 60)
  # four steps from 100 to 160, so the compound rate per period is the
  # fourth root of the total growth
  expect_equal(s$cagr_pct, 100 * ((160 / 100)^(1 / 4) - 1))
  # and compounding it back over the span returns the total
  expect_equal(100 * ((1 + s$cagr_pct / 100)^4 - 1), s$total_pct)
  expect_equal(s$periods, 5L)
  expect_equal(s$up, 4L)
  expect_equal(s$down, 0L)
  # a compound rate out of zero does not exist
  z <- yoy_summary(yoy(data.frame(y = 1:3, n = c(0, 5, 10)),
                       value = "n", period = "y", min_base = 0))
  expect_true(is.na(z$cagr_pct))
  expect_true(is.na(z$total_pct))
  # one row per group
  seg <- data.frame(year = rep(2019:2021, each = 2),
                    g = rep(c("a", "b"), 3), n = c(10, 100, 20, 90, 30, 80))
  sg <- yoy_summary(yoy(seg, value = "n", period = "year", by = "g",
                        min_base = 0))
  expect_equal(nrow(sg), 2L)
  expect_true("g" %in% names(sg))
  expect_equal(sg$total_pct[sg$g == "a"], 200)
  expect_equal(sg$total_pct[sg$g == "b"], -20)
})

test_that("printing says what the percentages mean", {
  d <- data.frame(year = 2019:2021, n = c(2, 200, 250))
  out <- utils::capture.output(print(yoy(d, value = "n", period = "year",
                                         direction = "lower_is_better"),
                                     color = FALSE))
  txt <- paste(out, collapse = "\n")
  # the settings a reader needs in order to know what the column is
  expect_match(txt, "units: count")
  expect_match(txt, "exact rate-ratio interval")
  expect_match(txt, "percent withheld below a base of 20")
  expect_match(txt, "lower is better")
  # and the reason a particular percent is absent, on its own row
  expect_match(txt, "percent withheld: base below 20")
  # colour is off when asked, and the table is still readable
  expect_false(grepl("\033", txt, fixed = TRUE))
  # colour is emitted when asked for
  col <- utils::capture.output(print(yoy(d, value = "n", period = "year"),
                                     color = TRUE))
  expect_true(any(grepl("\033[38;2;", col, fixed = TRUE)))
  # the mono palette prints no colour even when colour is on
  mono <- utils::capture.output(print(yoy(d, value = "n", period = "year"),
                                      color = TRUE, palette = "mono"))
  expect_false(any(grepl("\033", mono, fixed = TRUE)))
  expect_error(print(yoy(d, value = "n", period = "year"),
                     palette = "neon"), "'arg' should be one of")
  # row capping
  big <- data.frame(year = 2000:2050, n = seq(100, 600, by = 10))
  capped <- utils::capture.output(print(yoy(big, value = "n",
                                            period = "year"),
                                        color = FALSE, n = 5L))
  expect_true(any(grepl("more rows", capped, fixed = TRUE)))
  expect_true("diverging" %in% yoy_palettes())
})

test_that("the delimited writers round-trip through base R's readers", {
  d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
  y <- yoy(d, value = "n", period = "year")
  ref <- as.data.frame(y)

  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  yoy_csv(y, f)
  back <- utils::read.csv(f, comment.char = "#")
  expect_equal(as.numeric(back$value), ref$value)
  expect_equal(back$pct_change, ref$pct_change)
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
  yoy_tsv(y, g)
  bt <- utils::read.delim(g, comment.char = "#")
  expect_equal(as.numeric(bt$value), ref$value)
  # no metadata when it is not wanted
  yoy_csv(y, f, metadata = FALSE)
  expect_false(startsWith(readLines(f, n = 1L), "#"))
  # rounding is available for a figure meant to be read
  yoy_csv(y, f, digits = 1L, metadata = FALSE)
  expect_equal(utils::read.csv(f)$pct_change, round(ref$pct_change, 1L))
  # NA spelling is settable
  yoy_csv(y, f, na = "NA", metadata = FALSE)
  expect_true(any(grepl(",NA,", readLines(f), fixed = TRUE)))
  # text, rather than a file, when no path is given
  expect_type(yoy_csv(y, NULL), "character")
  expect_match(yoy_csv(y, NULL), "year,value")
})

test_that("a separator inside a field cannot break the columns", {
  # group labels come from open data, so they contain whatever the
  # publisher put in them
  d <- data.frame(year = rep(2019:2020, each = 2),
                  region = rep(c("North, Central", "Say \"hi\""), 2),
                  n = c(100, 200, 120, 180))
  y <- yoy(d, value = "n", period = "year", by = "region")
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  yoy_csv(y, f)
  back <- utils::read.csv(f, comment.char = "#")
  # the row count and the labels survive the comma and the quotes
  expect_equal(nrow(back), 4L)
  expect_true("North, Central" %in% back$region)
  expect_true("Say \"hi\"" %in% back$region)

  # a tab inside a field would shift every column after it in a TSV, so
  # it is replaced rather than written
  d2 <- data.frame(year = rep(2019:2020, each = 1),
                   region = c("A\tB", "A\tB"), n = c(100, 120))
  g <- tempfile(fileext = ".tsv")
  on.exit(unlink(g), add = TRUE)
  yoy_tsv(yoy(d2, value = "n", period = "year", by = "region"), g)
  bt <- utils::read.delim(g, comment.char = "#")
  expect_equal(nrow(bt), 2L)
  expect_identical(bt$region[1L], "A B")
})

test_that("the JSON keeps the settings as fields", {
  skip_if_not_installed("jsonlite")
  d <- data.frame(year = 2019:2021, n = c(100, 120, 140))
  y <- yoy(d, value = "n", period = "year",
           direction = "lower_is_better")
  txt <- yoy_json(y, NULL)
  obj <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
  expect_identical(obj$settings$value, "n")
  expect_identical(obj$settings$units, "count")
  expect_identical(obj$settings$direction, "lower_is_better")
  expect_equal(obj$settings$lag, 1L)
  # an absent grouping is an absent key, not an empty object
  expect_null(obj$settings$by)
  expect_length(obj$rows, 3L)
  expect_equal(obj$rows[[2L]]$change, 20)
  expect_length(obj$summary, 1L)
  # a grouped table names its grouping
  g <- yoy(data.frame(year = rep(2019:2020, each = 2),
                      k = rep(c("a", "b"), 2), n = c(1, 2, 3, 4)),
           value = "n", period = "year", by = "k", min_base = 0)
  og <- jsonlite::fromJSON(yoy_json(g, NULL), simplifyVector = FALSE)
  expect_identical(unlist(og$settings$by), "k")
  # and it is written with this package's own codec
  f <- tempfile(fileext = ".json")
  on.exit(unlink(f), add = TRUE)
  yoy_json(y, f)
  expect_equal(bricklayer_json_from_json(paste(readLines(f),
                                               collapse = "\n"))$rows$change,
               c(NA, 20, 20))
})

test_that("the Markdown table lines up and escapes its cells", {
  d <- data.frame(year = 2019:2021, n = c(100, 120, 140))
  md <- yoy_markdown(yoy(d, value = "n", period = "year"), NULL)
  lines <- strsplit(md, "\n", fixed = TRUE)[[1L]]
  tbl <- lines[startsWith(lines, "|")]
  expect_gte(length(tbl), 5L)
  # every row has the same number of cells, which is what makes it a
  # table rather than five paragraphs
  counts <- vapply(tbl, function(l) {
    length(strsplit(l, "|", fixed = TRUE)[[1L]])
  }, 0L)
  expect_equal(length(unique(counts)), 1L)
  # the rule is exactly as wide as its header, so the source reads as a
  # table before it is rendered
  expect_equal(nchar(tbl[1L]), nchar(tbl[2L]))
  # right-aligned numeric columns are marked as such
  expect_match(tbl[2L], "-:")
  # a pipe inside a label is escaped instead of ending the cell
  p <- yoy_markdown(
    yoy(data.frame(year = rep(2019:2020, each = 1),
                   k = c("a|b", "a|b"), n = c(10, 20)),
        value = "n", period = "year", by = "k", min_base = 0), NULL)
  expect_match(p, "a\\\\|b")
  # unaligned output is still a valid table
  u <- yoy_markdown(yoy(d, value = "n", period = "year"), NULL,
                    align = FALSE)
  expect_match(u, "| year |", fixed = TRUE)
})

test_that("the HTML is self-contained and escapes its content", {
  d <- data.frame(year = rep(2019:2020, each = 1),
                  region = c("<script>alert(1)</script>", "x"),
                  n = c(100, 120))
  y <- yoy(d, value = "n", period = "year", by = "region", min_base = 0)
  f <- tempfile(fileext = ".html")
  on.exit(unlink(f), add = TRUE)
  yoy_html(y, f, title = "A & B <report>", notes = "Note <here>")
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
  yoy_html(y, f, bars = FALSE)
  expect_false(grepl("class=\"bar", paste(readLines(f, warn = FALSE),
                                          collapse = ""), fixed = TRUE))
  expect_error(yoy_html(list(), f), "rmbl_yoy")
})

test_that("the PDF is a PDF, and pages rather than truncates", {
  d <- data.frame(year = 2000:2060, n = seq(100, 700, by = 10))
  y <- yoy(d, value = "n", period = "year")
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f), add = TRUE)
  expect_silent(yoy_pdf(y, f, title = "Long table"))
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
    if (identical(bytes[i:(i + length(marker) - 1L)], marker) &&
          !identical(bytes[i + length(marker)], charToRaw("s"))) {
      hits <- hits + 1L
    }
  }
  expect_gt(hits, 1L)
  # a short table needs only one page, and draws without the glyph
  # substitution warnings the device's base fonts would otherwise emit
  short <- yoy(data.frame(year = 2019:2021, n = c(100, 120, 140)),
               value = "n", period = "year")
  expect_silent(yoy_pdf(short, f))
  expect_error(yoy_pdf(list(), f), "rmbl_yoy")
})

test_that("the format follows the file name", {
  d <- data.frame(year = 2019:2021, n = c(100, 120, 140))
  y <- yoy(d, value = "n", period = "year")
  for (ext in c("csv", "tsv", "tab", "json", "md", "markdown", "html",
                "htm", "pdf")) {
    f <- tempfile(fileext = paste0(".", ext))
    yoy_write(y, f)
    expect_true(file.exists(f))
    expect_gt(file.size(f), 50)
    unlink(f)
  }
  # an upper-case extension is the same extension
  f <- tempfile(fileext = ".CSV")
  yoy_write(y, f)
  expect_match(paste(readLines(f), collapse = ""), "year,value")
  unlink(f)
  # an unrecognised name asks rather than guessing
  expect_error(yoy_write(y, tempfile(fileext = ".xyz")),
               "cannot tell the format")
  # and an explicit format overrides the name
  f <- tempfile(fileext = ".xyz")
  yoy_write(y, f, format = "csv")
  expect_match(paste(readLines(f), collapse = ""), "year,value")
  unlink(f)
  expect_error(yoy_write(y, tempfile(), format = "xml"), "unknown format")
  expect_error(yoy_write(list(), tempfile(fileext = ".csv")), "rmbl_yoy")
})

test_that("degenerate input degrades rather than erroring", {
  # one period has nothing to compare with
  one <- as.data.frame(yoy(data.frame(y = 2019, n = 100), value = "n",
                           period = "y"))
  expect_equal(nrow(one), 1L)
  expect_true(is.na(one$previous))
  expect_identical(one$flag, "no comparison period")
  expect_equal(nrow(yoy_summary(yoy(data.frame(y = 2019, n = 100),
                                    value = "n", period = "y"))), 1L)
  # an all-missing value column
  na <- yoy(data.frame(y = 2019:2021, n = c(NA_real_, NA, NA)),
            value = "n", period = "y")
  expect_equal(nrow(as.data.frame(na)), 3L)
  expect_true(all(is.na(as.data.frame(na)$pct_change)))
  s <- yoy_summary(na)
  expect_equal(s$periods, 0L)
  expect_true(is.na(s$cagr_pct))
  # an empty table prints without erroring
  empty <- yoy(data.frame(y = numeric(0), n = numeric(0)), value = "n",
               period = "y")
  expect_equal(nrow(as.data.frame(empty)), 0L)
  expect_output(print(empty), "no periods")
  # and writes an empty file with only its header
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  yoy_csv(empty, f, metadata = FALSE)
  expect_equal(length(readLines(f)), 1L)
  # an irregular period column has no grid, so nothing is compared and
  # nothing is invented
  irr <- as.data.frame(yoy(data.frame(y = c(1, 2, 5, 11), n = c(1, 2, 3, 4)),
                           value = "n", period = "y", min_base = 0))
  expect_true(all(c("previous", "change") %in% names(irr)))
})

test_that("a label changes the printing and nothing else", {
  seg <- data.frame(EndFiscalYear = 2019:2023,
                    n = c(402, 377, 190, 268, 331))
  y <- yoy(seg, value = n, period = EndFiscalYear)
  # 2023 keys the fiscal year 2022/23, so printing it as "2023" names a
  # calendar year the row is not about
  expect_equal(fiscal_year_label(2019:2023),
               c("2018/19", "2019/20", "2020/21", "2021/22", "2022/23"))
  expect_equal(fiscal_year_label(2023, short = FALSE), "2022/2023")
  expect_equal(fiscal_year_label(2023, sep = "-"), "2022-23")
  expect_true(is.na(fiscal_year_label("not a year")))
  expect_equal(fiscal_year_label(2000), "1999/00")

  lab <- yoy_label(y, fiscal_year_label)
  # the arithmetic already ran on the period's value, so a label cannot
  # move a number
  expect_equal(as.data.frame(lab)$pct_change, as.data.frame(y)$pct_change)
  expect_equal(as.data.frame(lab)$previous, as.data.frame(y)$previous)
  expect_equal(as.data.frame(lab)$EndFiscalYear, 2019:2023)

  # and it reaches every renderer, not just the one it was tested on
  out <- paste(utils::capture.output(print(lab, color = FALSE)),
               collapse = "\n")
  expect_match(out, "2022/23", fixed = TRUE)
  expect_match(yoy_markdown(lab, NULL), "2022/23", fixed = TRUE)
  expect_match(yoy_csv(lab, NULL), "2022/23", fixed = TRUE)
  h <- tempfile(fileext = ".html")
  on.exit(unlink(h), add = TRUE)
  yoy_html(lab, h)
  expect_match(paste(readLines(h, warn = FALSE), collapse = ""),
               "2022/23", fixed = TRUE)
  pf <- tempfile(fileext = ".pdf")
  on.exit(unlink(pf), add = TRUE)
  expect_silent(yoy_pdf(lab, pf))

  # a plain function
  f <- yoy_label(y, function(p) paste0("FY", substr(p, 3L, 4L)))
  expect_match(yoy_csv(f, NULL), "FY19", fixed = TRUE)
  # a named mapping relabels only what it names
  n <- as.data.frame(yoy_label(y, c("2020" = "2019/20 (COVID)")))
  expect_identical(n$period_label[n$EndFiscalYear == 2020],
                   "2019/20 (COVID)")
  expect_identical(n$period_label[n$EndFiscalYear == 2021], "2021")
  # an unnamed vector must cover every period
  expect_equal(as.data.frame(
    yoy_label(y, c("a", "b", "c", "d", "e")))$period_label,
    c("a", "b", "c", "d", "e"))
  expect_error(yoy_label(y, c("a", "b")), "distinct periods")
  expect_error(yoy_label(list(), fiscal_year_label), "rmbl_yoy")
  # labels repeat correctly across groups, which share their periods
  g <- yoy(data.frame(y = rep(2019:2020, each = 2),
                      k = rep(c("a", "b"), 2), n = c(100, 200, 120, 180)),
           value = "n", period = "y", by = "k")
  gl <- as.data.frame(yoy_label(g, fiscal_year_label))
  expect_equal(gl$period_label, fiscal_year_label(gl$y))
})
