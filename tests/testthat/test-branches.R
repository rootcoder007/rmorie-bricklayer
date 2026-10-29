# The branches the main suites do not reach: type restoration through an
# aggregation, period grids that are not grids, degenerate estimator
# inputs, and the argument guards on every writer.
#
# These are the paths a real extract reaches and a tidy example does not
# -- a factor region column, a POSIXct period, a single observation, a
# tail with no spread.

test_that("an aggregation restores each key column's own type", {
  # split() stringifies its keys, so every key type has to be put back;
  # a period silently turned into a string sorts lexically and the whole
  # comparison misaligns
  mk <- function(period, by = NULL) {
    d <- data.frame(n = c(1, 2, 3, 4, 5, 6))
    d$p <- period
    if (!is.null(by)) {
      d$g <- by
    }
    d
  }
  # two rows per period, so the aggregation path is taken
  int <- yoy(
    mk(rep(c(2019L, 2020L, 2021L), each = 2L)),
    value = "n",
    prd = "p",
    minbase = 0
  )
  expect_type(as.data.frame(int)$p, "integer")
  expect_identical(as.data.frame(int)$value, c(3, 7, 11))

  dbl <- yoy(
    mk(rep(c(1.5, 2.5, 3.5), each = 2L)),
    value = "n",
    prd = "p",
    minbase = 0
  )
  expect_type(as.data.frame(dbl)$p, "double")

  dte <- yoy(
    mk(rep(as.Date(c("2019-01-01", "2020-01-01", "2021-01-01")), each = 2L)),
    value = "n",
    prd = "p",
    minbase = 0
  )
  expect_s3_class(as.data.frame(dte)$p, "Date")

  # a POSIXct period keeps its class and its time zone
  tm <- rep(
    as.POSIXct(c("2019-01-01", "2020-01-01", "2021-01-01"), tz = "UTC"),
    each = 2L
  )
  pos <- yoy(mk(tm), value = "n", prd = "p", minbase = 0)
  expect_s3_class(as.data.frame(pos)$p, "POSIXct")

  # a FACTOR grouping column, which is what read.csv used to give and
  # what a factor-coded region still is
  fac <- yoy(
    mk(rep(2019:2021, each = 2L), by = factor(rep(c("a", "b"), 3L))),
    value = "n",
    prd = "p",
    by = "g",
    minbase = 0
  )
  expect_s3_class(as.data.frame(fac)$g, "factor")
  expect_identical(levels(as.data.frame(fac)$g), c("a", "b"))

  # a logical grouping column
  lg <- yoy(
    mk(rep(2019:2021, each = 2L), by = rep(c(TRUE, FALSE), 3L)),
    value = "n",
    prd = "p",
    by = "g",
    minbase = 0
  )
  expect_type(as.data.frame(lg)$g, "logical")

  # and a character one, which needs no restoring but must survive
  ch <- yoy(
    mk(rep(2019:2021, each = 2L), by = rep(c("x", "y"), 3L)),
    value = "n",
    prd = "p",
    by = "g",
    minbase = 0
  )
  expect_type(as.data.frame(ch)$g, "character")
})

test_that("a gap inside groups is completed within each group", {
  # the grouped completion path: 2021 missing for both regions
  d <- data.frame(
    year = rep(c(2019, 2020, 2022), each = 2L),
    region = rep(c("N", "S"), 3L),
    n = c(100, 200, 110, 210, 130, 230),
    stringsAsFactors = FALSE
  )
  got <- as.data.frame(yoy(
    d,
    value = "n",
    prd = "year",
    by = "region",
    minbase = 0
  ))
  # both regions gain a 2021 row with no value
  expect_identical(nrow(got), 8L)
  expect_identical(sum(got$year == 2021), 2L)
  expect_true(all(is.na(got$value[got$year == 2021])))
  # and 2022 has no comparison period in either region
  expect_true(all(is.na(got$previous[got$year == 2022])))
  expect_identical(sort(unique(got$region)), c("N", "S"))
})

test_that("a period column that is not a grid is left alone", {
  # Integer periods with gaps ARE a grid -- the step is the greatest
  # common divisor of the differences -- so 1, 2, 5, 11 completes to
  # 1..11 with the absent years present and empty. That is the intended
  # behaviour: the gaps are what stop a comparison from spanning them.
  irr <- as.data.frame(yoy(
    data.frame(
      p = c(1, 2, 5, 11),
      n = c(10, 20, 30, 40)
    ),
    value = "n",
    prd = "p",
    minbase = 0
  ))
  expect_identical(nrow(irr), 11L)
  expect_identical(irr$p, as.double(1:11))
  expect_identical(sum(!is.na(irr$value)), 4L)
  # A predecessor is found wherever the period one step back carries a
  # value: period 2 follows 1, and periods 3 and 6 follow the observed
  # 2 and 5 -- so an empty period does not hide the year before it, it
  # only stops the year AFTER it from reaching across.
  expect_identical(irr$previous[irr$p == 2], 10)
  expect_identical(irr$previous[irr$p == 3], 20)
  expect_identical(irr$previous[irr$p == 6], 30)
  expect_identical(sum(!is.na(irr$previous)), 3L)
  # and the periods following a gap have none
  expect_true(is.na(irr$previous[irr$p == 5]))
  expect_true(is.na(irr$previous[irr$p == 11]))

  # A period NOT on the constructed grid must still survive. With a
  # non-integer step the grid need not contain every observed value --
  # 1, 1.5 and 4.2 give a step of 0.5 and a grid that stops short of
  # 4.2 -- and an inner join would silently drop the row.
  odd <- as.data.frame(yoy(
    data.frame(
      p = c(1, 1.5, 4.2),
      n = c(10, 20, 30)
    ),
    value = "n",
    prd = "p",
    minbase = 0
  ))
  expect_true(4.2 %in% odd$p)
  expect_identical(odd$value[odd$p == 4.2], 30)
  expect_identical(sum(!is.na(odd$value)), 3L)

  # a single period has no step either
  one <- as.data.frame(yoy(data.frame(p = 2019, n = 5), value = "n", prd = "p"))
  expect_identical(nrow(one), 1L)
  expect_true(is.na(one$previous))

  # A character period has no arithmetic, so "one period earlier" means
  # nothing. It must report that rather than raising: taking diff() of
  # it failed with "non-numeric argument to binary operator" and killed
  # the whole call.
  expect_warning(
    {
      chr <- as.data.frame(yoy(
        data.frame(
          p = c("Q1", "Q2", "Q3"),
          n = c(10, 20, 30),
          stringsAsFactors = FALSE
        ),
        value = "n",
        prd = "p",
        minbase = 0
      ))
    },
    "prdord"
  )
  expect_identical(nrow(chr), 3L)
  expect_identical(chr$value, c(10, 20, 30))
  expect_true(all(is.na(chr$previous)))
  expect_true(all(chr$flag == "no comparison period"))
  # a factor period is the same case
  expect_warning(fct <- as.data.frame(yoy(
    data.frame(
      p = factor(c("Q1", "Q2")),
      n = c(10, 20)
    ),
    value = "n",
    prd = "p",
    minbase = 0
  )), "of no form yoy\\(\\) reads")
  expect_identical(nrow(fct), 2L)
  expect_true(all(is.na(fct$previous)))

  # a period range so wide that completing it would fabricate a vast
  # table is left alone rather than expanded
  huge <- as.data.frame(yoy(
    data.frame(
      p = c(1, 2, 1e9),
      n = c(10, 20, 30)
    ),
    value = "n",
    prd = "p",
    minbase = 0
  ))
  expect_identical(nrow(huge), 3L)

  # a column name must be a name or a string, not an expression
  expect_error(
    yoy(data.frame(a = 1:3, b = 1:3), value = 1 + 1, prd = "a"),
    "must be a column name"
  )
})

test_that("the value-digit count handles both extremes", {
  # no finite values to inspect
  na <- yoy(
    data.frame(p = 2019:2021, n = rep(NA_real_, 3L)),
    value = "n",
    prd = "p",
    units = "continuous"
  )
  expect_output(print(na, color = FALSE), "2019")

  # more decimals than are worth printing are capped
  fine <- yoy(
    data.frame(
      p = 2019:2021,
      n = c(1.1234567891, 2.2, 3.3)
    ),
    value = "n",
    prd = "p",
    units = "continuous"
  )
  out <- paste(utils::capture.output(print(fine, color = FALSE)), collapse = "")
  expect_match(out, "1.123457", fixed = TRUE)

  # an integer-valued continuous measure prints without decimals
  whole <- yoy(
    data.frame(p = 2019:2021, n = c(1, 2, 3)),
    value = "n",
    prd = "p",
    units = "continuous"
  )
  expect_match(
    paste(utils::capture.output(print(whole, color = FALSE)), collapse = ""),
    " 1 ",
    fixed = TRUE
  )
})

test_that("the writers refuse anything that is not a change table", {
  for (f in list(yoycsv, yoytsv, yoyjs, yoymd)) {
    expect_error(f(list(a = 1), NULL), "rmbl_yoy")
    expect_error(f(data.frame(a = 1), NULL), "rmbl_yoy")
  }
})

test_that("the settings line reports the units and the direction", {
  # a percentage-units table says so, and names no interval it does not
  # have
  pct <- yoy(
    data.frame(p = 2019:2021, s = c(4.1, 4.6, 5.2)),
    value = "s",
    prd = "p",
    units = "percent",
    dir = "lower"
  )
  line <- yoycsv(pct, NULL)
  expect_match(line, "change is in percentage points")
  expect_match(line, "direction: lower is better")
  expect_false(grepl("exact rate ratio", line, fixed = TRUE))
  # and a count table names the interval and the base gate instead
  cnt <- yoy(
    data.frame(p = 2019:2021, n = c(100, 120, 140)),
    value = "n",
    prd = "p"
  )
  cl <- yoycsv(cnt, NULL)
  expect_match(cl, "exact rate ratio")
  expect_false(grepl("bases below", cl, fixed = TRUE))
  noted <- yoy(
    data.frame(p = 2019:2021, n = c(100, 120, 140)),
    value = "n",
    prd = "p",
    minbase = 20
  )
  expect_match(yoycsv(noted, NULL), "bases below 20 noted")
  expect_false(grepl("direction:", cl, fixed = TRUE))
  # the Markdown footer carries the same line, so the caveat cannot
  # drift between formats
  expect_match(yoymd(pct, NULL), "percentage points")
  # and a grouped table names its grouping
  g <- yoy(
    data.frame(
      p = rep(2019:2020, each = 2L),
      k = rep(c("a", "b"), 2L),
      n = c(1, 2, 3, 4),
      stringsAsFactors = FALSE
    ),
    value = "n",
    prd = "p",
    by = "k",
    minbase = 0
  )
  expect_match(yoycsv(g, NULL), "by: k")
})

test_that("the tail index reports when there is nothing to estimate", {
  # every tail value AT the threshold: the log ratios are all zero, so
  # the likelihood has no slope and there is no exponent to report
  flat <- hilltlidx(rep(5, 20L), xmin = 5, discrete = FALSE)
  expect_true(is.na(flat$alpha))
  expect_match(flat$method, "not estimable")
  expect_false(flat$reliable)
  # The approximate discrete branch used to return a number here, because
  # its continuity correction divides by xmin - 0.5 rather than by xmin,
  # so the log ratios were not zero. Since 0.5.10 a tail of identical
  # values is "not estimable" on every branch: there is no slope to fit.
  fa <- hilltlidx(rep(5, 20L), xmin = 5, approx = TRUE)
  expect_true(is.na(fa$alpha))
  expect_match(fa$method, "not estimable")
  expect_false(fa$reliable)
  # and with a threshold at or below a half there is no correction left
  # to make, so it reports the same nothing
  fb <- hilltlidx(rep(0.4, 20L), xmin = 0.4, approx = TRUE)
  expect_true(is.na(fb$alpha))
  expect_match(fb$method, "not estimable")
  # a value of zero cannot be logged, so it is not in the tail at all
  expect_identical(hilltlidx(c(0, 0, 3, 4, 5, 9), xmin = 3)$ntl, 4L)
  # an infinite value is not data
  expect_identical(hilltlidx(c(Inf, 3, 4, 5, 9), xmin = 3)$ntl, 4L)
})

test_that("the discrete distance degrades on degenerate input", {
  # no observations at all
  expect_true(is.na(.rmbl_ks_discrete(numeric(0), function(q) q)))
  # a fitted function that returns nothing usable
  expect_true(is.na(.rmbl_ks_discrete(
    c(1, 2, 3),
    function(q) {
      rep(
        NA_real_,
        length(q)
      )
    }
  )))
  # and it is a distance, so it lies in the unit interval
  d <- .rmbl_ks_discrete(
    c(1, 1, 2, 3),
    function(q) stats::pbinom(q, 3, 0.4)
  )
  expect_gte(d, 0)
  expect_lte(d, 1)
})

test_that("the zeta likelihood refuses an exponent it cannot normalise", {
  # zeta(s, q) only converges for s > 1, so the search interval's lower
  # end has to be excluded rather than evaluated
  expect_true(is.na(hurwzeta(1)))
  # the objective returns Inf there, which is what keeps optimize inside
  # the domain; a tail that is nearly flat pushes it to that boundary
  k <- 1:50
  p <- k^(-1.05) / sum(k^(-1.05))
  set.seed(21)
  heavy <- sample(k, 2000L, replace = TRUE, prob = p)
  fit <- hilltlidx(heavy, xmin = 1)
  expect_true(is.finite(fit$alpha))
  expect_gt(fit$alpha, 1)
})

test_that("the count trend survives a design it cannot solve", {
  # every period the same: the design matrix is singular, so there is no
  # slope to report and the fit stops rather than dividing by zero
  flat <- cnttrnd(c(5L, 7L, 9L), x = rep(1, 3L))
  expect_true(is.na(flat$se) || !is.finite(flat$se))
  expect_true(is.finite(flat$rateratio))
  # and a series of zeros has no rate to fit a trend to: refused, not
  # reported as a ratio of one with an infinite upper bound
  expect_error(cnttrnd(rep(0L, 5L)), "every count is zero")
})
