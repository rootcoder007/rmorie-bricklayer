# Tests written for the rOpenSci statistical standards; each block names the
# standards it meets.

#' @srrstats {G5.6b} plndid() recovers polex()'s built-in effect of -3 to within
#'   0.5 under six seeds.
test_that("plndid() recovers the built-in effect under several seeds", {
  for (s in c(1, 2, 3, 4, 5, 20240101)) {
    est <- plndid(polex(s), "district", "month", "crmrate", "reformed")$estimate
    expect_lt(abs(est + 3), 0.5)
  }
})

#' @srrstats {G5.9} Noise susceptibility is tested for ginicoef(), trndtst() and
#'   svyest() (G5.9a) and cbootmean() (G5.9b).
#' @srrstats {G5.9a} Relative noise of .Machine$double.eps leaves ginicoef(),
#'   the trndtst() slope and p-value, and the svyest() estimate and SE unchanged
#'   to 1e-10.
test_that("trivial noise does not move the estimates", {
  eps <- .Machine$double.eps
  set.seed(3)
  g <- stats::rexp(200)
  expect_equal(
    ginicoef(g * (1 + eps * stats::runif(200, -1, 1))),
    ginicoef(g),
    tolerance = 1e-10
  )
  y <- c(402, 377, 190, 268, 331, 420, 455)
  a <- trndtst(y)
  b <- trndtst(y * (1 + eps * rep_len(c(1, -1), 7)))
  expect_equal(b$slope, a$slope, tolerance = 1e-10)
  expect_equal(b$p_value, a$p_value, tolerance = 1e-10)
  d <- data.frame(
    s = rep(c("a", "b"), each = 10),
    w = rep(c(2, 3), each = 10),
    y = (1:20) / 3,
    stringsAsFactors = FALSE
  )
  des <- svydes(d, w = "w", strata = "s")
  d2 <- d
  d2$y <- d$y * (1 + eps * rep_len(c(1, -1), 20))
  e1 <- svyest(des, d, "y")
  e2 <- svyest(des, d2, "y")
  expect_equal(e2$estimate, e1$estimate, tolerance = 1e-10)
  expect_equal(e2$se, e1$se, tolerance = 1e-10)
})

#' @srrstats {G5.9b} cbootmean() under five seeds gives replicate means within
#'   0.01 of the sample mean and SEs within 5% of the formula SE.
test_that("bootstrap results agree across seeds within tolerance", {
  set.seed(7)
  x <- stats::rnorm(60, mean = 5)
  se <- stats::sd(x) / sqrt(length(x))
  for (s in 11:15) {
    b <- cbootmean(x, B = 3000, seed = s)
    expect_equal(mean(b), mean(x), tolerance = 0.01 / mean(x))
    expect_equal(stats::sd(b), se, tolerance = 0.05)
  }
})

#' @srrstats {EA6.0d} The yoy(), rtcalc(), cpsdrft()$columns and profcols()
#'   frames are checked column by column for their class.
test_that("the main result frames have the documented column classes", {
  y <- yoy(data.frame(year = 2019:2023, n = c(10, 12, 9, 15, 20)), "n", "year")
  expect_identical(
    vapply(y, function(z) class(z)[1L], ""),
    c(
      year = "integer",
      value = "numeric",
      previous = "numeric",
      change = "numeric",
      pctchg = "numeric",
      flag = "character",
      pctlo = "numeric",
      pctup = "numeric",
      verdict = "character"
    )
  )
  r <- rtcalc(
    data.frame(
      g = c("a", "b"),
      k = c(5, 9),
      pop = c(1000, 2000),
      stringsAsFactors = FALSE
    ),
    "k",
    "pop",
    by = "g"
  )
  expect_identical(
    vapply(r, function(z) class(z)[1L], ""),
    c(
      g = "character",
      count = "numeric",
      population = "numeric",
      rate = "numeric",
      lower = "numeric",
      upper = "numeric",
      flag = "character"
    )
  )
  set.seed(1)
  a <- data.frame(u = stats::rnorm(50), v = stats::runif(50))
  cd <- cpsdrft(a, transform(a, u = u + 1))
  expect_identical(
    vapply(cd$columns, function(z) class(z)[1L], ""),
    c(
      column = "character",
      type = "character",
      statistic = "numeric",
      p_value = "numeric",
      psi = "numeric",
      jsdiv = "numeric",
      unseen_share = "numeric",
      drifted = "logical",
      note = "character"
    )
  )
  pc <- profcols(a)
  cls <- vapply(pc, function(z) class(z)[1L], "")
  expect_identical(
    unname(cls[c("column", "type", "hist", "top")]),
    rep("character", 4L)
  )
  expect_identical(
    unname(cls[c(
      "n",
      "n_missing",
      "n_distinct",
      "nzero",
      "nneg",
      "ninf",
      "n_outliers"
    )]),
    rep("integer", 7L)
  )
  expect_true(all(
    cls[c(
      "pct_missing",
      "mean",
      "sd",
      "median",
      "mad",
      "min",
      "max",
      "skewness",
      "q25",
      "q50",
      "q75"
    )] ==
      "numeric"
  ))
})

#' @srrstats {TS3.0} trcprog()'s interval for the completion year widens as the
#'   target moves further away (total 94, 150, 300).
test_that("the completion-year interval widens with the horizon", {
  w <- vapply(
    c(94, 150, 300),
    function(tot) {
      p <- trcprog(total = tot)
      p$cmplbylate - p$cmplbyearly
    },
    0
  )
  expect_true(all(diff(w) > 0))
})

test_that("stepchg() and trndtst() refuse periods out of order or repeated", {
  expect_error(
    stepchg(c(1, 2, 3, 4, 5, 6), x = c(1, 3, 2, 4, 5, 6)),
    "strictly increasing"
  )
  expect_error(
    stepchg(c(1, 2, 3, 4, 5, 6), x = c(1, 2, 2, 4, 5, 6)),
    "strictly increasing"
  )
  expect_identical(
    stepchg(c(100, 104, 98, 60, 63, 58), x = 2018:2023)$breakafter,
    2020L
  )
  expect_error(trndtst(c(1, 2, 3, 4), x = c(1, 2, 2, 3)), "duplicated periods")
})

test_that("stepchg() gives the means of a huge series in its own units", {
  y <- c(1, 1.1, 0.9, 3, 3.2, 2.9)
  big <- stepchg(y * 1e200)
  small <- stepchg(y)
  expect_equal(big$before, small$before * 1e200, tolerance = 1e-12)
  expect_equal(big$after, small$after * 1e200, tolerance = 1e-12)
  expect_equal(big$difference, small$difference * 1e200, tolerance = 1e-12)
  expect_identical(big$index, small$index)
})

test_that("chwkfit() warns when the branching ratio sits on its bound", {
  set.seed(1)
  tm <- sort(100 + cumsum(stats::rexp(150, 20)))
  expect_warning(
    {
      f <- chwkfit(tm, 1000)
    },
    "upper bound 0.99"
  )
  expect_identical(f$atbound, "eta")
})

test_that("yoy() compares ordered-factor periods by level order", {
  d <- data.frame(
    q = factor(c("Q1", "Q2", "Q4"), levels = paste0("Q", 1:4), ordered = TRUE),
    n = c(10, 12, 15)
  )
  r <- yoy(d, "n", "q")
  expect_identical(as.character(r$q), paste0("Q", 1:4))
  expect_s3_class(r$q, "ordered")
  expect_identical(r$previous, c(NA, 10, 12, NA))
  expect_identical(r$flag[3L], "no data")
  r <- yoy(d, "n", "q", complete = FALSE)
  expect_identical(r$previous, c(NA, 10, NA))
  # unordered: no order, so no comparison
  d$q <- factor(as.character(d$q))
  expect_warning(un <- yoy(d, "n", "q"), "of no form yoy\\(\\) reads")
  expect_true(all(is.na(un$previous)))
  expect_error(yoy(list(1)), "a numeric or integer vector, or a ts, not list")
})

test_that("fylbl() refuses a fractional year, as documented", {
  expect_error(fylbl(2023.7), "whole years")
  expect_identical(fylbl(2023), "2022/23")
})

# ---- time-series plots (TS5.1, TS5.2, TS5.3, TS5.5) --------------------------

with_pdf <- function(expr) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  force(expr)
}

#' @srrstats {TS5.1} Periods sit on their own number or Date scale; text periods
#'   at labelled positions.
#' @srrstats {TS5.3} The period axis is titled with the unit the period implies.
test_that("the period axis keeps the period's own scale and names its unit", {
  pa <- .bl_period_axis
  a <- pa(c(2019, 2020, 2022))
  expect_identical(a$at, c(2019, 2020, 2022))
  expect_identical(a$xlab, "Period")
  expect_equal(a$xlim, c(2018.5, 2022.5))
  # stkflow() stores its periods as text: whole numbers and ISO dates are read
  # back
  expect_identical(pa(c("2021", "2023"))$at, c(2021, 2023))
  d <- pa(c("2020-01-01", "2020-03-01"))
  expect_identical(d$xlab, "Date")
  expect_identical(d$at, as.numeric(as.Date(c("2020-01-01", "2020-03-01"))))
  expect_identical(pa(as.Date("2020-01-01") + 0:1)$xlab, "Date")
  expect_identical(
    pa(as.POSIXct(c("2020-01-01 10:00", "2020-01-01 11:00"), tz = "UTC"))$xlab,
    "Time"
  )
  f <- pa(c("2021/22", "2022/23", "2022/23"))
  expect_identical(f$xlab, "Fiscal year")
  expect_identical(f$at, c(1L, 2L, 2L))
  expect_identical(f$tlab, c("2021/22", "2022/23"))
  q <- pa(factor(c("Q1", "Q2")))
  expect_identical(q$xlab, "Period")
  expect_identical(q$step, 1L)
  # labels relabel the ticks of a numeric period (yoylbl()'s fiscal years)
  l <- pa(c(2022, 2023), c("2021/22", "2022/23"))
  expect_identical(l$at, c(2022, 2023))
  expect_identical(l$xlab, "Fiscal year")
  expect_identical(pa(NA_character_)$xlim, c(-0.5, 1.5))
  # a tick per period when there are few; pretty ticks along a long numeric or
  # date series
  with_pdf({
    graphics::plot(c(1, 20), c(0, 1))
    expect_equal(.bl_period_ticks(pa(1:3)), 1:3, tolerance = 1e-8)
    expect_length(.bl_period_ticks(pa(1:20)), 20L)
    expect_length(
      .bl_period_ticks(pa(as.character(1:20 + 100))),
      20L
    )
    graphics::plot(as.numeric(as.Date("2020-01-01") + c(0, 600)), c(0, 1))
    expect_length(
      .bl_period_ticks(pa(seq(
        as.Date("2020-01-01"),
        by = "month",
        length.out = 20
      ))),
      20L
    )
  })
})

#' @srrstats {TS5.2} yoy and rate-change plots put the period across: points sit
#'   at the period's own x.
test_that("change plots draw the period across, groups side by side", {
  y <- yoy(
    data.frame(year = 2019:2023, n = c(400, 420, 390, 460, 450)),
    value = "n",
    prd = "year"
  )
  d <- with_pdf(plot(y))
  expect_equal(d$at, 2019:2023, tolerance = 1e-8)
  expect_equal(d$pctchg, y$pctchg, tolerance = 1e-8)
  seg <- data.frame(
    year = rep(2021:2023, 2),
    g = rep(c("a", "b"), each = 3),
    n = c(500, 600, 700, 900, 800, 1000),
    stringsAsFactors = FALSE
  )
  dg <- with_pdf(plot(yoy(seg, value = "n", prd = "year", by = "g")))
  # two groups in one period: a to the left of the period, b to the right
  expect_equal(
    dg$at,
    c(2021, 2022, 2023, 2021, 2022, 2023) + rep(c(-0.175, 0.175), each = 3),
    tolerance = 1e-8
  )
  rt <- data.frame(
    division = rep(c("n", "e", "w"), 2),
    year = rep(2022:2023, each = 3),
    stops = c(120, 90, 60, 150, 85, 70),
    residents = rep(c(1e4, 8e3, 5e3), 2),
    stringsAsFactors = FALSE
  )
  rc <- ratechg(
    rt,
    count = "stops",
    pop = "residents",
    prd = "year",
    by = "division"
  )
  drc <- with_pdf(plot(rc, xlab = "Year"))
  expect_equal(drc$pctchg, rc$pctchg, tolerance = 1e-8)
  expect_length(unique(drc$at), nrow(rc))
  rc0 <- ratechg(rt, count = "stops", pop = "residents", prd = "year")
  expect_equal(with_pdf(plot(rc0))$at, as.numeric(rc0$year), tolerance = 1e-8)
  # one value everywhere, or none at all, still gives the panel a height
  ti <- .bl_time_interval
  ax <- .bl_period_axis(1:2)
  expect_equal(
    with_pdf(ti(ax, c(2, 2), c(2, 2), c(2, 2), "m", "y", "x", "black")),
    1:2,
    tolerance = 1e-8
  )
  expect_equal(
    with_pdf(ti(
      ax,
      c(NA, NA),
      c(NA, NA),
      c(NA, NA),
      "m",
      "y",
      "x",
      "black",
      note = c("a: b", "")
    )),
    1:2,
    tolerance = 1e-8
  )
  # six groups recycle the five symbols
  many <- data.frame(
    year = rep(2021:2022, 6),
    g = rep(letters[1:6], each = 2),
    n = rep(c(100, 120), 6)
  )
  expect_equal(
    nrow(with_pdf(plot(yoy(many, value = "n", prd = "year", by = "g")))),
    12L,
    tolerance = 1e-8
  )
})

#' @srrstats {TS5.3} A formal `xlab` reaches every plot over time; through `...`
#'   it was matched twice.
test_that("xlab is an argument of the plots over time", {
  sf <- stkflow(
    days = c(13500, 14600, 15100),
    people = c(300, 320, 310),
    prd = 2021:2023
  )
  out <- with_pdf(plot(sf, xlab = "Year"))
  expect_identical(attr(out, "at"), c(2021, 2022, 2023))
  y <- yoy(
    data.frame(year = 2019:2021, n = c(40, 44, 41)),
    value = "n",
    prd = "year"
  )
  expect_equal(with_pdf(plot(y, xlab = "Year"))$at, 2019:2021, tolerance = 1e-8)
  expect_equal(
    with_pdf(plot(y, what = "value", xlab = "Year"))$at,
    2019:2021,
    tolerance = 1e-8
  )
  fy <- yoylbl(y, fylbl)
  expect_equal(
    with_pdf(plot(fy, what = "value"))$at,
    2019:2021,
    tolerance = 1e-8
  )
  ct <- cnttrnd(c(5, 7, 6, 9, 12, 11), x = 2018:2023)
  expect_equal(with_pdf(plot(ct, xlab = "Year"))$x, 2018:2023, tolerance = 1e-8)
  es <- evstudy(
    polex(),
    "district",
    "month",
    "crmrate",
    "refmonth",
    leads = 2,
    lags = 2
  )
  expect_equal(
    with_pdf(plot(es, xlab = "Months since the reform"))$evtm,
    es$evtm,
    tolerance = 1e-8
  )
  dt <- yoy(
    data.frame(
      d = as.Date(c("2020-01-01", "2021-01-01", "2022-01-01")),
      n = c(40, 44, 41)
    ),
    value = "n",
    prd = "d",
    complete = FALSE
  )
  expect_equal(
    with_pdf(plot(dt, what = "value"))$at,
    as.numeric(dt$d),
    tolerance = 1e-8
  )
})

#' @srrstats {TS5.5} gaps = "break" breaks the line at a missing value; "join"
#'   draws over it.
test_that("missing values break lines by default and can be joined", {
  bl <- .bl_line
  with_pdf({
    graphics::plot(1:4, c(0, 5, 0, 5))
    br <- bl(1:4, c(1, NA, 3, 4), "black", gaps = "break")
    expect_identical(br$y, c(1, NA, 3, 4))
    jn <- bl(1:4, c(1, NA, 3, 4), "black", gaps = "join")
    expect_identical(jn$x, c(1, 3, 4))
    expect_identical(
      bl(c(1, NA, 3), c(1, 2, Inf), "black", gaps = "break")$y,
      c(1, NA)
    )
    expect_null(bl(1:2, c(NA, NA), "black", gaps = "break"))
  })
  # a year with no data, inserted by yoy(complete = TRUE)
  y <- yoy(
    data.frame(year = c(2019, 2020, 2022, 2023), n = c(40, 44, 41, 50)),
    value = "n",
    prd = "year"
  )
  expect_identical(y$flag[y$year == 2021], "no data")
  v <- with_pdf(plot(y, what = "value"))
  expect_equal(v$at, 2019:2023, tolerance = 1e-8)
  expect_true(is.na(v$value[3L]))
  expect_equal(
    with_pdf(plot(y, what = "value", gaps = "join"))$value,
    v$value,
    tolerance = 1e-8
  )
  expect_error(
    with_pdf(plot(y, what = "value", gaps = "skip")),
    "must be one of"
  )
  es <- evstudy(
    polex(),
    "district",
    "month",
    "crmrate",
    "refmonth",
    leads = 2,
    lags = 2
  )
  es$estimate[1L] <- NA
  expect_true(is.na(with_pdf(plot(es, style = "stata"))$estimate[1L]))
  expect_true(is.na(with_pdf(plot(es, style = "stata", gaps = "join"))$estimate[
    1L
  ]))
})

test_that("vrfcps() reports an unparseable provenance record as a failed row", {
  dir <- tempfile("cps-")
  dir.create(dir)
  utils::write.csv(
    data.frame(a = 1:3),
    file.path(dir, "d.csv"),
    row.names = FALSE
  )
  writeLines("{bad", file.path(dir, "data_provenance.json"))
  r <- vrfcps(dir)
  expect_false(r$ok)
  row <- r$checks[r$checks$check == "provenance_readable", ]
  expect_false(row$ok)
  expect_match(row$detail, "data_provenance.json: ")
  expect_true("data_present" %in% r$checks$check)
})
