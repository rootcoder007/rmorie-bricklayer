# The policy-evaluation figures: each draws and returns what it drew

.pp <- function() polex()

test_that("event studies draw in both styles, alone and in a grid", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- .pp()
  es <- evstudy(
    p,
    "district",
    "month",
    "crmrate",
    "refmonth",
    leads = 3,
    lags = 4
  )
  expect_identical(
    nrow(plot(es, style = "stata", shadepost = TRUE, refline = 0)),
    nrow(es)
  )
  s <- stgatt(p, "district", "month", "crmrate", "refmonth", reps = 0)
  expect_identical(nrow(plot(s, style = "stata")), nrow(s$dynamic))
  g <- plotevgrid(list(Crime = es, Staggered = s), main = "Two outcomes")
  expect_identical(unique(g$panel), c("Crime", "Staggered"))
  expect_error(plotevgrid(list(es)), "named list")
  expect_error(plot(es, style = "zz"), "style")
})

test_that(
  paste0(
    "the Bacon scatter, the permutation ",
    "distributions and leave-one-out draw"
  ),
  {
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    p <- .pp()
    b <- bacondcmp(p, "district", "month", "crmrate", "reformed")
    expect_identical(nrow(plot(b)), nrow(b))
    r <- perminf(
      p,
      "district",
      "month",
      c("crmrate", "arrrate"),
      "refmonth",
      cl = "region"
    )
    expect_identical(nrow(plot(r)), 2L)
    expect_identical(nrow(plot(r, type = "histogram")), 2L)
    l <- loounit(
      p,
      "district",
      "month",
      "crmrate",
      "reformed",
      units = c("D01", "D02", "D03")
    )
    expect_identical(l$dropped, c("D01", "D02", "D03"))
    q <- p[p$district != "D02", ]
    expect_identical(
      l$estimate[2],
      plndid(q, "district", "month", "crmrate", "reformed")$estimate
    )
    expect_identical(nrow(plot(l)), 3L)
    expect_error(
      loounit(p, "district", "month", "crmrate", "reformed", units = "D99"),
      "units of"
    )
  }
)

test_that("cohtrnd(): moving average, scaled to 1 before adoption", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- .pp()
  ct <- cohtrnd(
    p,
    "district",
    "month",
    "crmrate",
    "refmonth",
    win = c(-6, 6),
    ma = 3
  )
  expect_true(all(ct$value[ct$evtm == -1] == 1))
  m <- tapply(
    p$crmrate[(!is.na(p$refmonth) & p$refmonth == 13)],
    p$month[(!is.na(p$refmonth) & p$refmonth == 13)],
    mean
  )
  ma <- stats::filter(m, rep(1 / 3, 3), sides = 1)
  expect_identical(
    ct$value[ct$cohort == 13 & ct$evtm == 2],
    as.numeric(ma[15] / ma[12])
  )
  raw <- cohtrnd(
    p,
    "district",
    "month",
    "crmrate",
    "refmonth",
    ma = 1,
    norm = FALSE
  )
  expect_identical(
    raw$value[raw$cohort == 19 & raw$evtm == 0],
    mean(p$crmrate[(!is.na(p$refmonth) & p$refmonth == 19) & p$month == 19])
  )
  expect_identical(nrow(plot(ct)), nrow(ct))
  expect_error(
    cohtrnd(p, "district", "month", "crmrate", "refmonth", win = c(0, 3)),
    "`win`"
  )
})

test_that("cohtrnd() checks `norm` (C1)", {
  expect_error(
    cohtrnd(.pp(), "district", "month", "crmrate", "refmonth", norm = "yes"),
    "cohtrnd: `norm` must be TRUE or FALSE"
  )
})

# ---- boxed printouts ---------------------------------------------------------

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

test_that("leave-one-out and cohort trends print as boxes", {
  p <- polex()
  lo <- loounit(p, "district", "month", "crmrate", "reformed",
    units = c("D01", "D02"))
  .o2_check(lo, "Leave one unit out", c("Full-sample estimate", "change"))
  ct <- cohtrnd(p, "district", "month", "crmrate", "refmonth")
  .o2_check(ct, "Outcome trends by adoption cohort",
    c("cohort 13", "relative to period -1"))
})

# the help pages' own panel: eight towns, 2015 to 2024, four adopting
.own_panel <- function() {
  own <- data.frame(
    town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
    year = rep(2015:2024, times = 8),
    stringsAsFactors = FALSE
  )
  i <- match(own$town, unique(own$town))
  own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
  own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
  own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
  own$county <- rep(c("North", "South"), 4)[i]
  own$income <- 50 + own$year - 2015 + cos(seq_len(80))
  own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
    0.2 * own$income + sin(seq_len(80))
  own
}

test_that("loounit() passes weights to each fit", {
  own <- .own_panel()
  a <- loounit(own, "town", "year", "rate", "bylaw")
  expect_identical(loounit(own, "town", "year", "rate", "bylaw", w = NULL), a)
  b <- loounit(own, "town", "year", "rate", "bylaw", w = "pop")
  expect_identical(b$dropped, c("A", "B", "C", "D"))
  ref <- plndid(own[own$town != "B", ], "town", "year", "rate", "bylaw",
                w = "pop")
  expect_equal(b$estimate[2L], ref$estimate[1L], tolerance = 1e-12)
  expect_equal(
    attr(b, "full"),
    plndid(own, "town", "year", "rate", "bylaw", w = "pop")$estimate[1L],
    tolerance = 1e-12
  )
  expect_error(loounit(own, "town", "year", "rate", "bylaw", units = "Z"),
               "loounit: `units` must be units of `data`")
})

test_that("the help pages' own panel draws", {
  own <- .own_panel()
  ct <- cohtrnd(own, "town", "year", "rate", "first", win = c(-3, 3), ma = 1)
  expect_s3_class(ct, "rmbl_cohort_trends")
  pdf(NULL)
  on.exit(grDevices::dev.off())
  g <- plotevgrid(list(
    Rate = evstudy(own, "town", "year", "rate", "first", leads = 3, lags = 3),
    Income = evstudy(own, "town", "year", "income", "first", leads = 3,
                     lags = 3)
  ))
  expect_s3_class(g, "data.frame")
})

test_that("a subset of a leave-one-out or cohort table prints plainly", {
  expect_df_fallback("rmbl_loo", "Leave one unit out")
  expect_df_fallback("rmbl_cohort_trends", "Outcome trends by adoption cohort")
})
