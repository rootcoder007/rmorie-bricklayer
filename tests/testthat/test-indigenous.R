# First Nations, Metis and Inuit methods: each against an exact reference

test_that(
  paste0(
    "sctidy() keeps the quality flags and ",
    "never keeps a suppressed value"
  ),
  {
    d <- data.frame(
      GEO = "Canada",
      VALUE = c("45.8", "12", "", "3", "7"),
      STATUS = c("", "E", "x", "F", ".."),
      stringsAsFactors = FALSE
    )
    t <- sctidy(d)
    expect_s3_class(t, "rmbl_statcan")
    expect_identical(as.character(t$quality), c("ok", "E", "x", "F", ".."))
    expect_identical(t$VALUE, c(45.8, 12, NA, NA, NA))
    expect_error(
      sctidy(data.frame(a = 1)),
      "no VALUE column, nor census columns"
    )
    expect_error(sctidy(1), "must be a data frame or a table key")
  }
)

test_that("sctidy() makes a census table's wide layout long", {
  w <- data.frame(
    REF_DATE = 2021,
    GEO = "Canada",
    `Age (20)` = c("Total - Age", "0 to 14 years"),
    Coordinate = c("1.1", "1.2"),
    `Indigenous identity (9):First Nations (North American Indian)[4]` = c(
      1048405,
      300000
    ),
    Symbol = c("", "x"),
    `Indigenous identity (9):Inuk (Inuit)[6]` = c(70540, 22000),
    Symbol2 = c("E", ""),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  # StatCan repeats the Symbol column after every value column
  names(w)[names(w) == "Symbol2"] <- "Symbol"
  t <- sctidy(w)
  expect_identical(
    t[["Indigenous identity (9)"]],
    rep(c("First Nations (North American Indian)", "Inuk (Inuit)"), each = 2)
  )
  expect_identical(t$VALUE, c(1048405, NA, 70540, 22000))
  expect_identical(as.character(t$quality), c("ok", "x", "E", "ok"))
  expect_identical(t[["Age (20)"]], rep(c("Total - Age", "0 to 14 years"), 2))
  e <- scests(t)
  expect_identical(nrow(e), 4L)
  expect_false("Coordinate" %in% names(e))
  # one label, two members: told apart by the member number in the coordinate
  du <- data.frame(
    REF_DATE = 2021,
    GEO = "Canada",
    DGUID = "2021A000011124",
    `Household type (16)` = c("Without children", "Without children", "Total"),
    Coordinate = c("1.3", "1.7", "1.1"),
    `Tenure (8):Owner[2]` = c(5, 6, 11),
    Symbol = "",
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  tu <- sctidy(du)
  expect_identical(
    tu[["Household type (16)"]],
    c("Without children [3]", "Without children [7]", "Total")
  )
  expect_identical(nrow(scests(tu)), 3L)
  bad <- data.frame(`A (2):x[1]` = 1, `B (2):y[1]` = 2, check.names = FALSE)
  expect_error(sctidy(bad), "more than one dimension")
})

test_that(
  paste0(
    "indgap() works the ratio and ",
    "difference from the published intervals"
  ),
  {
    d <- data.frame(
      g = c(
        "First Nations",
        "Metis",
        "Total Indigenous",
        "Inuit",
        "Non-Indigenous"
      ),
      est = c(45.8, 52.8, 49, 47.8, 61.5),
      lo = c(43.9, 50.6, 47.5, 43.1, 61),
      hi = c(47.7, 55, 50.5, 52.5, 62),
      q = c("", "", "", "E", ""),
      stringsAsFactors = FALSE
    )
    r <- indgap(d, "g", "est", "lo", "hi", qual = "q")
    z <- stats::qnorm(0.975)
    se <- function(l, h) (h - l) / (2 * z)
    fn <- r[r$group == "First Nations", ]
    expect_identical(fn$difference, 45.8 - 61.5)
    expect_identical(
      fn$diflo,
      (45.8 - 61.5) - z * sqrt(se(43.9, 47.7)^2 + se(61, 62)^2)
    )
    sl <- sqrt(
      ((log(47.7) - log(43.9)) / (2 * z))^2 + ((log(62) - log(61)) / (2 * z))^2
    )
    expect_identical(fn$ratioup, exp(log(45.8 / 61.5) + z * sl))
    expect_true(r$usewithcau[r$group == "Inuit"])
    expect_identical(r$poogrp, c(FALSE, FALSE, TRUE, FALSE))
    d$q[2] <- "F"
    expect_true(is.na(indgap(d, "g", "est", "lo", "hi", qual = "q")$ratio[2]))
    expect_error(
      indgap(d, "g", "est", "lo", "hi", ref = "zz"),
      "exactly one row"
    )
    d2 <- d
    d2$lo[1] <- 50
    expect_warning(
      {
        r2 <- indgap(d2, "g", "est", "lo", "hi")
      },
      "does not contain the estimate for: First Nations"
    )
    expect_true(is.na(r2$difference[1]))
    d4 <- d
    d4$lo[5] <- 62.5
    expect_error(
      indgap(d4, "g", "est", "lo", "hi"),
      "reference group's published interval"
    )
    d3 <- d
    d3$q <- c("", "", "", "", "x")
    expect_error(
      indgap(d3, "g", "est", "lo", "hi", qual = "q"),
      "reference estimate is suppressed"
    )
    expect_error(indgap(d, "zz", "est", "lo", "hi"), "column `zz` not found")
    expect_error(
      indgap(d, "g", "est", "lo", "hi", qual = "zz"),
      "column `zz` not found"
    )
    expect_error(
      indgap(1, "g", "est", "lo", "hi"),
      "`data` must be a data frame"
    )
  }
)

test_that(
  paste0(
    "agestd(): one age group gives the exact ",
    "Poisson interval; weights apply"
  ),
  {
    r <- agestd(7, 10000, 1, per = 1)
    expect_identical(r$rate, 7 / 10000)
    expect_equal(r$lower, stats::qgamma(0.025, 7) / 10000, tolerance = 1e-12)
    expect_equal(r$upper, stats::qgamma(0.975, 8) / 10000, tolerance = 1e-12)
    z0 <- agestd(0, 5000, 1, per = 1)
    expect_identical(z0$lower, 0)
    expect_equal(z0$upper, stats::qgamma(0.975, 1) / 5000, tolerance = 1e-12)
    std <- c(3, 2, 1)
    r2 <- agestd(c(1, 4, 9), c(1000, 2000, 1500), std)
    expect_identical(
      r2$rate,
      sum(std / sum(std) * c(1, 4, 9) / c(1000, 2000, 1500)) * 1e5
    )
    expect_lt(r2$lower, r2$rate)
    expect_gt(r2$upper, r2$rate)
    expect_error(agestd(c(1, 2), c(10, 20), c(1, 1, 1)), "has 2 age groups")
    expect_error(
      agestd(c(1, -2), c(10, 20), c(1, 1)),
      "non-negative whole numbers"
    )
    expect_error(agestd(c(1, 2), c(10, 0), c(1, 1)), "`pop` must be positive")
    expect_error(agestd(c(1, 2), c(10, 20), c(0, 0)), "not all zero")
    expect_error(agestd(c(1, 2), c(10, 20, 30), c(1, 1)), "same length")
    expect_error(
      agestd(c(1, 2), c(10, 20), c(1, 1), grp = "a"),
      "one label per row"
    )
  }
)

test_that("rategap(): ratio and difference of two standardised rates", {
  r <- agestd(
    c(5, 9, 2, 3),
    c(1000, 1200, 2000, 2500),
    c(1, 1),
    grp = c("Inuit", "Inuit", "Non-Indigenous", "Non-Indigenous")
  )
  g <- rategap(r, "Inuit", "Non-Indigenous")
  y1 <- r$rate[1] / 1e5
  y0 <- r$rate[2] / 1e5
  expect_identical(g$ratio, y1 / y0)
  v <- attr(r, "var")
  expect_identical(
    g$difup,
    (y1 - y0 + stats::qnorm(0.975) * sqrt(sum(v))) * 1e5
  )
  expect_error(rategap(data.frame(), "a", "b"), "must come from agestd")
  expect_error(rategap(r, "zz", "Inuit"), "is not a group")
  r0 <- agestd(
    c(0, 0, 2, 3),
    c(1000, 1200, 2000, 2500),
    c(1, 1),
    grp = c("a", "a", "b", "b")
  )
  expect_error(rategap(r0, "a", "b"), "both rates above zero")
})

test_that("genexpo() codes 0, 1, 2 and keeps what is not known unknown", {
  expect_identical(
    genexpo(
      c(TRUE, FALSE, TRUE, NA, FALSE, NA, TRUE),
      c(TRUE, FALSE, FALSE, TRUE, NA, NA, NA)
    ),
    c(2L, 0L, 1L, NA, NA, NA, NA)
  )
  expect_identical(
    genexpo(
      c(TRUE, FALSE, TRUE, NA, FALSE, NA, TRUE),
      c(TRUE, FALSE, FALSE, TRUE, NA, NA, NA),
      partial = "lowerbnd"
    ),
    c(2L, 0L, 1L, 1L, NA, NA, 1L)
  )
  expect_error(genexpo(1, TRUE), "`parent` must be TRUE, FALSE or NA")
  expect_error(genexpo(TRUE, c(TRUE, FALSE)), "same length")
})

test_that(
  paste0(
    "exptrnd(): odds ratios by hand, the trend test as prop.trend.test ",
    "gives it"
  ),
  {
    r <- exptrnd(c(60, 95, 70), c(500, 520, 300))
    expect_identical(r$orratio[3], (70 / 230) / (60 / 440))
    se <- sqrt(1 / 70 + 1 / 230 + 1 / 60 + 1 / 440)
    expect_identical(
      r$lower[3],
      exp(log((70 / 230) / (60 / 440)) - stats::qnorm(0.975) * se)
    )
    expect_identical(
      attr(r, "trend")$p.value,
      stats::prop.trend.test(c(60, 95, 70), c(500, 520, 300), 0:2)$p.value
    )
    expect_no_warning({
      r0 <- exptrnd(c(0, 5), c(10, 10))
    })
    expect_identical(r0$orratio[2], (5.5 / 5.5) / (0.5 / 10.5))
    expect_error(exptrnd(c(1, 20), c(10, 10)), "0 <= cases <= n")
    expect_error(exptrnd(1, 10), "two levels at least")
    expect_error(
      exptrnd(c(1, 2), c(10, 10), dose = c(1, 0)),
      "strictly increasing"
    )
  }
)

test_that(
  paste0(
    "trccmpl() and trcprog(): the counts the reports state, the exact rate ",
    "interval"
  ),
  {
    tc <- trccmpl()
    expect_identical(tc$completed, c(8L, 0L, 3L, 2L))
    expect_identical(tail(tc$cumulative, 1), 13L)
    p <- trcprog()
    span <- 2023 - 2015.96
    expect_identical(p$rate, 13 / span)
    expect_equal(
      p$ratelo,
      stats::qgamma(0.025, 13) / span,
      tolerance = testthat::testthat_tolerance()
    )
    expect_identical(p$rateup, stats::qgamma(0.975, 14) / span)
    expect_identical(p$cmplby, 2023 + 81 / (13 / span))
    expect_identical(trcprog(94, 2030)$cmplby, 2031)
    expect_identical(trcprog(0, 2020)$cmplbylate, Inf)
    expect_error(trcprog(c(5, 3), c(2020, 2021)), "cumulative counts")
    expect_error(trcprog(1, c(2020, 2021)), "one count per year")
    expect_error(trcprog(1, 2010), "after `start`")
  }
)

test_that("indtabs() lists the mirrored tables, and searches them", {
  man <- list(
    datasets = list(
      list(
        key = "statcan_indigenous/tbl_13100924",
        rows = 413100,
        meta = list(
          description = "Health indicators ... perceived mental health",
          license = "Statistics Canada Open Licence",
          source = paste0(
            "https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=13100924",
            "01"
          )
        )
      ),
      list(
        key = "census2021_ipp/x2021003_pop",
        rows = 2,
        meta = list(description = "Indigenous Population Profile")
      ),
      list(key = "hib/cpads", rows = 1, meta = list(description = "other"))
    )
  )
  local_mocked_bindings(dmnf = function(refresh = FALSE) man)
  t <- indtabs()
  expect_identical(
    t$key,
    c("statcan_indigenous/tbl_13100924", "census2021_ipp/x2021003_pop")
  )
  expect_identical(nrow(indtabs("mental health")), 1L)
  expect_error(indtabs(1), "`pat` must be a single non-empty string")
})

test_that("qltyrcd() refuses non-character flags and warns of unknown ones", {
  expect_error(qltyrcd("a", suppr = mean), "`suppr` must be data")
  expect_error(
    qltyrcd(c(1, 2)),
    "^qltyrcd: `x` must be a vector of flags \\(character\\)"
  )
  expect_error(qltyrcd(TRUE), "vector of flags \\(character\\)")
  fl <- c("np", "*", "Q", "", NA)
  expect_warning(
    qltyrcd(fl, suppr = "np", caution = "*"),
    "\"Q\" are in neither `suppr` nor `caution`"
  )
  r <- suppressWarnings(qltyrcd(fl, suppr = "np", caution = "*"))
  expect_identical(r, c("x", "E", "ok", "ok", "ok"))
  expect_silent(qltyrcd(factor(c("E", "F", "ok"))))
  expect_identical(qltyrcd(NA), "ok")
})

test_that("agestd() names `grp` when it is a function", {
  expect_error(agestd(1, 10, 1, grp = mean), "`grp` must be data")
})

test_that("indgap() refuses a `pooled` label that is not a group", {
  d <- data.frame(
    g = c("A", "B", "Total", "R"),
    e = c(10, 12, 11, 8),
    lo = c(8, 10, 9, 7),
    hi = c(12, 14, 13, 9),
    stringsAsFactors = FALSE
  )
  expect_error(
    indgap(d, "g", "e", "lo", "hi", ref = "R", pooled = "Totl"),
    "^indgap: `pooled` names \"Totl\", not a group of `data`"
  )
  expect_error(
    indgap(d, "g", "e", "lo", "hi", ref = "R", pooled = mean),
    "`pooled` must be data"
  )
  r <- indgap(d, "g", "e", "lo", "hi", ref = "R", pooled = "Total")
  expect_identical(r$poogrp, c(FALSE, FALSE, TRUE))
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
    expect_true(grepl(h, flat, fixed = TRUE), info = h)
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

test_that("the Indigenous gap, rate and trend results print as boxes", {
  d <- data.frame(
    REF_DATE = "2019/2022",
    GEO = "Canada",
    `Indigenous identity` = c(
      "First Nations",
      "Inuk (Inuit)",
      "Non-Indigenous"
    ),
    VALUE = c("45.8", "", "61.5"),
    STATUS = c("", "x", ""),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  expect_box(
    sctidy(d),
    "Statistics Canada table",
    c("Quality", "ok 2, x 1", "Inuk (Inuit)", "x suppressed")
  )
  h <- indiex("health")
  mh <- h[
    h$period == "2019/2022" &
      h$age == "Total, 18 years and over" &
      h$indicator == "Perceived mental health, very good or excellent",
  ]
  g <- indgap(mh, "group", "estimate", "lower", "upper", qual = "quality")
  expect_box(
    g,
    "Gap against a reference group",
    c("Non-Indigenous", "First Nations", "M\u00e9tis", "Inuit", "ratio CI")
  )
  expect_box(
    agestd(
      events = c(4, 9, 11, 6, 3),
      pop = c(9000, 8000, 6000, 4000, 2000),
      std = c(30000, 25000, 20000, 15000, 10000)
    ),
    "Directly age-standardised rate",
    c("100,000", "Fay and Feuer")
  )
  expect_box(
    exptrnd(cases = c(60, 95, 70), n = c(500, 520, 300)),
    "Odds by level of exposure",
    c("chi-square", "Woolf")
  )
  expect_box(
    exptrnd(cases = c(0, 5), n = c(10, 10)),
    "Odds by level of exposure",
    "Haldane-Anscombe"
  )
  expect_box(
    trcprog(),
    "Calls to Action: progress",
    c("13 of 94", "Calls a year", "Poisson")
  )
  stalled <- trcprog(done = c(0, 0), yearend = c(2019, 2020))
  expect_box(stalled, "Calls to Action", "never at this pace")
  expect_output(print(g[, c("group", "ratio")]), "ratio")
})

test_that("limfrom() and rategap() results print as boxes", {
  l <- limfrom(c(10, 20), se = c(1, 2))
  expect_s3_class(l, c("rmbl_limits", "data.frame"))
  expect_box2(l, "Intervals from published precision", "[8.04, 11.96]")
  expect_box2(l["estimate"], "Intervals from published", "plain table")
  a <- agestd(
    c(5, 10, 8, 20),
    c(1000, 2000, 1200, 2500),
    c(0.4, 0.6),
    grp = c("A", "A", "B", "B")
  )
  g <- rategap(a, "B", "A")
  expect_s3_class(g, c("rmbl_rate_gap", "data.frame"))
  expect_box2(g, "Gap between two standardised rates", c("Reference", "ratio"))
  expect_box2(rbind(g, g), "Gap between two", "Comparisons")
})

test_that("trcprog() takes your own count, and microdata reach indgap()", {
  p <- trcprog(done = c(2, 6, 9, 13), yearend = 2016:2019)
  expect_s3_class(p, "rmbl_trc_progress")
  set.seed(7)
  n <- 600
  resp <- data.frame(
    group = sample(c("First Nations", "Inuit", "Non-Indigenous"), n, TRUE),
    wt = runif(n, 50, 150)
  )
  resp$goodmh <- rbinom(n, 1, ifelse(resp$group == "Non-Indigenous", 0.6, 0.5))
  des <- svydes(resp, w = "wt")
  tab <- as.data.frame(
    svyest(des, resp, "goodmh", by = "group", stat = "proportion", lvls = "1")
  )
  g <- indgap(tab, "group", "estimate", "lower", "upper")
  expect_s3_class(g, "rmbl_indigenous_gap")
  expect_setequal(g$group, c("First Nations", "Inuit"))
})

test_that("refusals name the function", {
  expect_error(limfrom(1), "^limfrom: give one of")
  expect_error(genexpo(TRUE, c(TRUE, FALSE)), "^genexpo: ")
})

# ---- restored box items and result-driven readings ---------------------------

ls_flat <- function(x) gsub("\\s+", " ", paste(format(x), collapse = " "))

test_that("indgap()'s box marks the pooled row and reads the ratios", {
  own <- data.frame(
    group = c("A", "B", "A and B", "Ref"),
    pct = c(31.2, 27.5, 30.8, 18.9),
    lower = c(28, 15, 28.5, 18.4),
    upper = c(34, 40, 33, 19.4),
    stringsAsFactors = FALSE
  )
  g <- indgap(own, "group", "pct", "lower", "upper", ref = "Ref",
    pooled = "A and B")
  txt <- ls_flat(g)
  expect_match(txt, "A and B (pooled)", fixed = TRUE)
  expect_match(txt, "Above the reference (interval above 1): A and A and B",
    fixed = TRUE)
  expect_match(txt, "Not distinguishable from 1 (interval includes it): B",
    fixed = TRUE)
  low <- own
  low$pct <- c(10, 11, 10.5, 18.9)
  low$lower <- low$pct - 1
  low$upper <- low$pct + 1
  g2 <- indgap(low, "group", "pct", "lower", "upper", ref = "Ref")
  txt2 <- ls_flat(g2)
  expect_match(txt2, "Below the reference (interval below 1)", fixed = TRUE)
  expect_false(grepl("Above the reference", txt2, fixed = TRUE))
})

test_that("agestd()'s reading names the highest and lowest group", {
  std <- c(30000, 25000, 20000)
  one <- agestd(c(4, 9, 11), c(9000, 8000, 6000), std)
  expect_match(ls_flat(one), "all: rate", fixed = TRUE)
  two <- agestd(
    c(4, 9, 11, 40, 90, 110),
    rep(c(9000, 8000, 6000), 2),
    std,
    grp = rep(c("low", "high"), each = 3)
  )
  txt <- ls_flat(two)
  expect_match(txt, "Highest rate: high", fixed = TRUE)
  expect_match(txt, "lowest: low", fixed = TRUE)
  expect_match(txt, "do not overlap", fixed = TRUE)
})

test_that("exptrnd()'s reading follows the direction of the odds", {
  up <- ls_flat(exptrnd(cases = c(60, 95, 70), n = c(500, 520, 300)))
  expect_match(up, "The odds rise with exposure", fixed = TRUE)
  expect_match(up, "At the highest level (2)", fixed = TRUE)
  flat <- ls_flat(exptrnd(cases = c(50, 51, 49), n = c(500, 500, 500)))
  expect_match(flat, "finds no steady change", fixed = TRUE)
  down <- ls_flat(exptrnd(cases = c(120, 60, 20), n = c(500, 500, 500)))
  expect_match(down, "The odds fall with exposure", fixed = TRUE)
})

test_that("an indigenous-health table without its columns prints plainly", {
  expect_df_fallback("rmbl_rate_gap", "Gap between two standardised rates")
  for (cls in c("rmbl_statcan", "rmbl_dsr", "rmbl_exposure_trend",
    "rmbl_trc_progress")) {
    expect_plain_df(cls)
  }
})
