# First Nations, Metis and Inuit methods: each against an exact reference

test_that("statcan_tidy() keeps the quality flags and never keeps a suppressed value", {
  d <- data.frame(GEO = "Canada", VALUE = c("45.8", "12", "", "3", "7"), STATUS = c("", "E", "x", "F", ".."))
  t <- statcan_tidy(d)
  expect_s3_class(t, "rmbl_statcan")
  expect_identical(as.character(t$quality), c("ok", "E", "x", "F", ".."))
  expect_identical(t$VALUE, c(45.8, 12, NA, NA, NA))
  expect_error(statcan_tidy(data.frame(a = 1)), "no VALUE column, nor census columns")
  expect_error(statcan_tidy(1), "must be a data frame or a table key")
})

test_that("statcan_tidy() makes a census table's wide layout long", {
  w <- data.frame(REF_DATE = 2021, GEO = "Canada", `Age (20)` = c("Total - Age", "0 to 14 years"),
                  Coordinate = c("1.1", "1.2"),
                  `Indigenous identity (9):First Nations (North American Indian)[4]` = c(1048405, 300000),
                  Symbol = c("", "x"), `Indigenous identity (9):Inuk (Inuit)[6]` = c(70540, 22000),
                  Symbol = c("E", ""), check.names = FALSE)
  t <- statcan_tidy(w)
  expect_identical(t[["Indigenous identity (9)"]],
                   rep(c("First Nations (North American Indian)", "Inuk (Inuit)"), each = 2))
  expect_identical(t$VALUE, c(1048405, NA, 70540, 22000))
  expect_identical(as.character(t$quality), c("ok", "x", "E", "ok"))
  expect_identical(t[["Age (20)"]], rep(c("Total - Age", "0 to 14 years"), 2))
  e <- statcan_estimates(t)
  expect_identical(nrow(e), 4L)
  expect_false("Coordinate" %in% names(e))
  bad <- data.frame(`A (2):x[1]` = 1, `B (2):y[1]` = 2, check.names = FALSE)
  expect_error(statcan_tidy(bad), "more than one dimension")
})

test_that("indigenous_gap() works the ratio and difference from the published intervals", {
  d <- data.frame(g = c("First Nations", "Metis", "Total Indigenous", "Inuit", "Non-Indigenous"),
                  est = c(45.8, 52.8, 49, 47.8, 61.5), lo = c(43.9, 50.6, 47.5, 43.1, 61),
                  hi = c(47.7, 55, 50.5, 52.5, 62), q = c("", "", "", "E", ""))
  r <- indigenous_gap(d, "g", "est", "lo", "hi", quality = "q")
  z <- stats::qnorm(0.975)
  se <- function(l, h) (h - l) / (2 * z)
  fn <- r[r$group == "First Nations", ]
  expect_equal(fn$difference, 45.8 - 61.5)
  expect_equal(fn$difference_lower, (45.8 - 61.5) - z * sqrt(se(43.9, 47.7)^2 + se(61, 62)^2))
  sl <- sqrt(((log(47.7) - log(43.9)) / (2 * z))^2 + ((log(62) - log(61)) / (2 * z))^2)
  expect_equal(fn$ratio_upper, exp(log(45.8 / 61.5) + z * sl))
  expect_true(r$use_with_caution[r$group == "Inuit"])
  expect_identical(r$pan_indigenous, c(FALSE, FALSE, TRUE, FALSE))
  d$q[2] <- "F"
  expect_true(is.na(indigenous_gap(d, "g", "est", "lo", "hi", quality = "q")$ratio[2]))
  expect_error(indigenous_gap(d, "g", "est", "lo", "hi", reference = "zz"), "exactly one row")
  d2 <- d
  d2$lo[1] <- 50
  expect_warning(r2 <- indigenous_gap(d2, "g", "est", "lo", "hi"), "does not contain the estimate for: First Nations")
  expect_true(is.na(r2$difference[1]))
  d4 <- d
  d4$lo[5] <- 62.5
  expect_error(indigenous_gap(d4, "g", "est", "lo", "hi"), "reference group's published interval")
  d3 <- d
  d3$q <- c("", "", "", "", "x")
  expect_error(indigenous_gap(d3, "g", "est", "lo", "hi", quality = "q"), "reference estimate is suppressed")
  expect_error(indigenous_gap(d, "zz", "est", "lo", "hi"), "column `zz` not found")
  expect_error(indigenous_gap(d, "g", "est", "lo", "hi", quality = "zz"), "column `zz` not found")
  expect_error(indigenous_gap(1, "g", "est", "lo", "hi"), "`data` must be a data frame")
})

test_that("age_standardise(): one age group gives the exact Poisson interval; weights apply", {
  r <- age_standardise(7, 10000, 1, per = 1)
  expect_equal(r$rate, 7 / 10000)
  expect_equal(r$lower, stats::qgamma(0.025, 7) / 10000, tolerance = 1e-12)
  expect_equal(r$upper, stats::qgamma(0.975, 8) / 10000, tolerance = 1e-12)
  z0 <- age_standardise(0, 5000, 1, per = 1)
  expect_identical(z0$lower, 0)
  expect_equal(z0$upper, stats::qgamma(0.975, 1) / 5000, tolerance = 1e-12)
  std <- c(3, 2, 1)
  r2 <- age_standardise(c(1, 4, 9), c(1000, 2000, 1500), std)
  expect_equal(r2$rate, sum(std / sum(std) * c(1, 4, 9) / c(1000, 2000, 1500)) * 1e5)
  expect_lt(r2$lower, r2$rate)
  expect_gt(r2$upper, r2$rate)
  expect_error(age_standardise(c(1, 2), c(10, 20), c(1, 1, 1)), "has 2 age groups")
  expect_error(age_standardise(c(1, -2), c(10, 20), c(1, 1)), "non-negative whole numbers")
  expect_error(age_standardise(c(1, 2), c(10, 0), c(1, 1)), "`population` must be positive")
  expect_error(age_standardise(c(1, 2), c(10, 20), c(0, 0)), "not all zero")
  expect_error(age_standardise(c(1, 2), c(10, 20, 30), c(1, 1)), "same length")
  expect_error(age_standardise(c(1, 2), c(10, 20), c(1, 1), group = "a"), "one label per row")
})

test_that("rate_gap(): ratio and difference of two standardised rates", {
  r <- age_standardise(c(5, 9, 2, 3), c(1000, 1200, 2000, 2500), c(1, 1),
                       group = c("Inuit", "Inuit", "Non-Indigenous", "Non-Indigenous"))
  g <- rate_gap(r, "Inuit", "Non-Indigenous")
  y1 <- r$rate[1] / 1e5
  y0 <- r$rate[2] / 1e5
  expect_equal(g$ratio, y1 / y0)
  v <- attr(r, "var")
  expect_equal(g$difference_upper, (y1 - y0 + stats::qnorm(0.975) * sqrt(sum(v))) * 1e5)
  expect_error(rate_gap(data.frame(), "a", "b"), "must come from age_standardise")
  expect_error(rate_gap(r, "zz", "Inuit"), "is not a group")
  r0 <- age_standardise(c(0, 0, 2, 3), c(1000, 1200, 2000, 2500), c(1, 1),
                        group = c("a", "a", "b", "b"))
  expect_error(rate_gap(r0, "a", "b"), "both rates above zero")
})

test_that("generations_exposed() codes 0, 1, 2 and keeps what is not known unknown", {
  expect_identical(generations_exposed(c(TRUE, FALSE, TRUE, NA, FALSE, NA, TRUE),
                                       c(TRUE, FALSE, FALSE, TRUE, NA, NA, NA)),
                   c(2L, 0L, 1L, 1L, NA, NA, 1L))
  expect_error(generations_exposed(1, TRUE), "`parent` must be TRUE, FALSE or NA")
  expect_error(generations_exposed(TRUE, c(TRUE, FALSE)), "same length")
})

test_that("exposure_trend(): odds ratios by hand, the trend test as prop.trend.test gives it", {
  r <- exposure_trend(c(60, 95, 70), c(500, 520, 300))
  expect_equal(r$odds_ratio[3], (70 / 230) / (60 / 440))
  se <- sqrt(1 / 70 + 1 / 230 + 1 / 60 + 1 / 440)
  expect_equal(r$lower[3], exp(log((70 / 230) / (60 / 440)) - stats::qnorm(0.975) * se))
  expect_equal(attr(r, "trend")$p.value, stats::prop.trend.test(c(60, 95, 70), c(500, 520, 300), 0:2)$p.value)
  expect_no_warning(r0 <- exposure_trend(c(0, 5), c(10, 10)))
  expect_equal(r0$odds_ratio[2], (5.5 / 5.5) / (0.5 / 10.5))
  expect_error(exposure_trend(c(1, 20), c(10, 10)), "0 <= cases <= n")
  expect_error(exposure_trend(1, 10), "two levels at least")
  expect_error(exposure_trend(c(1, 2), c(10, 10), dose = c(1, 0)), "strictly increasing")
})

test_that("trc_completions() and trc_progress(): the counts the reports state, the exact rate interval", {
  tc <- trc_completions()
  expect_identical(tc$completed, c(8L, 0L, 3L, 2L))
  expect_identical(tail(tc$cumulative, 1), 13L)
  p <- trc_progress()
  span <- 2023 - 2015.96
  expect_equal(p$rate, 13 / span)
  expect_equal(p$rate_lower, stats::qgamma(0.025, 13) / span)
  expect_equal(p$rate_upper, stats::qgamma(0.975, 14) / span)
  expect_equal(p$complete_by, 2023 + 81 / (13 / span))
  expect_identical(trc_progress(94, 2030)$complete_by, 2031)
  expect_identical(trc_progress(0, 2020)$complete_by_late, Inf)
  expect_error(trc_progress(c(5, 3), c(2020, 2021)), "cumulative counts")
  expect_error(trc_progress(1, c(2020, 2021)), "one count per year")
  expect_error(trc_progress(1, 2010), "after `start`")
})

test_that("indigenous_tables() lists the mirrored tables, and searches them", {
  man <- list(datasets = list(
    list(key = "statcan_indigenous/tbl_13100924", rows = 413100,
         meta = list(description = "Health indicators ... perceived mental health",
                     license = "Statistics Canada Open Licence",
                     source = "https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1310092401")),
    list(key = "census2021_ipp/x2021003_pop", rows = 2, meta = list(description = "Indigenous Population Profile")),
    list(key = "hib/cpads", rows = 1, meta = list(description = "other"))))
  local_mocked_bindings(bricklayer_data_manifest = function(refresh = FALSE) man)
  t <- indigenous_tables()
  expect_identical(t$key, c("statcan_indigenous/tbl_13100924", "census2021_ipp/x2021003_pop"))
  expect_identical(nrow(indigenous_tables("mental health")), 1L)
  expect_error(indigenous_tables(1), "`pattern` must be a single non-empty string")
})
