otis <- read.csv(system.file("extdata", "otis_a01_individuals.csv",
                             package = "rmoriebricklayer"))

test_that("published_bounds turns rounding and suppression into intervals", {
  b <- published_bounds(c(120, 35, 0), rounding = 5)
  expect_equal(b$lower, c(117.5, 32.5, 0))
  expect_equal(b$upper, c(122.5, 37.5, 2.5))
  expect_true(all(b$status == "rounded"))
  # random rounding to base 5 moves a cell by up to 4
  r <- published_bounds(15, rounding = 5, rounding_kind = "random")
  expect_equal(c(r$lower, r$upper), c(11, 19))
  # suppressed cells: explicit "<k" or a mark with a limit
  s <- published_bounds(c("120", "x", "<5", "1,250"), rounding = 5,
                        suppression_limit = 5)
  expect_equal(s$status, c("rounded", "suppressed", "suppressed", "rounded"))
  expect_equal(s$upper[2:3], c(4, 4))
  expect_equal(s$value[4], 1250)
  expect_true(is.na(s$value[2]))
  expect_error(published_bounds("x"), "limit")
  expect_error(published_bounds("abc"), "cannot read")
  expect_equal(published_bounds(7)$status, "exact")
})

test_that("change_envelope is the exact image of the input intervals", {
  now <- published_bounds(c(45, 120), rounding = 5)
  prev <- published_bounds(c(40, 100), rounding = 5)
  e <- change_envelope(now, prev)
  expect_equal(e$change_lower, c(42.5 - 42.5, 117.5 - 102.5))
  expect_equal(e$change_upper, c(47.5 - 37.5, 122.5 - 97.5))
  expect_equal(e$pct_lower[1], 100 * (42.5 / 42.5 - 1))
  expect_equal(e$pct_upper[1], 100 * (47.5 / 37.5 - 1))
  # a previous cell that could be zero has no finite percent bound
  z <- change_envelope(published_bounds("<5"), published_bounds("<5"))
  expect_true(is.na(z$pct_upper))
  # the envelope contains the point estimate
  expect_true(all(e$pct_lower <= 100 * (c(45, 120) / c(40, 100) - 1)))
  expect_true(all(e$pct_upper >= 100 * (c(45, 120) / c(40, 100) - 1)))
})

test_that("yoy_bounds widens the sampling interval, never narrows it", {
  y <- yoy(otis, value = "individuals", period = "year",
           by = c("table", "group"))
  yb <- yoy_bounds(y, rounding = 5)
  ok <- !is.na(yb$pct_lower)
  expect_true(all(yb$combined_pct_lower[ok] <= yb$pct_lower[ok]))
  expect_true(all(yb$combined_pct_upper[ok] >= yb$pct_upper[ok]))
  expect_true(all(yb$env_pct_lower[ok] <= yb$pct_change[ok]))
  expect_true(all(yb$env_pct_upper[ok] >= yb$pct_change[ok]))
  expect_s3_class(yb, "rmbl_yoy")
  expect_error(yoy_bounds(otis), "yoy\\(\\)")
})

test_that("exact p-values agree with binom.test and adjust over the scan", {
  y <- yoy(otis, value = "individuals", period = "year",
           by = c("table", "group"))
  yp <- yoy_pvalues(y)
  i <- which(!is.na(yp$previous))[1]
  expect_equal(yp$p_value[i],
               binom.test(yp$value[i], yp$value[i] + yp$previous[i])$p.value)
  s <- scan_adjust(y, alpha = 0.05)
  ok <- !is.na(s$p_value)
  expect_equal(s$p_adjusted[ok], p.adjust(s$p_value[ok], "BH"))
  expect_true(all(s$p_adjusted[ok] >= s$p_value[ok]))
  expect_s3_class(s, "rmbl_yoy")
  expect_equal(attr(s, "scan_adjust")$tests, sum(ok))
  # a plain data frame with p-values is adjusted too; one without is refused
  d <- data.frame(p_value = c(0.01, 0.04, 0.5))
  expect_equal(scan_adjust(d)$p_adjusted, p.adjust(d$p_value, "BH"))
  expect_error(scan_adjust(data.frame(a = 1)), "p_value")
  # continuous units carry no exact test
  yc <- yoy(otis, value = "individuals", period = "year",
            by = c("table", "group"), units = "continuous")
  expect_error(yoy_pvalues(yc), "count units")
})

test_that("rate_change carries the earlier count and exposure, and adjusts", {
  d <- data.frame(year = rep(2022:2024, each = 2), site = rep(c("A", "B"), 3),
                  n = c(30, 60, 45, 58, 50, 90),
                  pop = c(1000, 2000, 1000, 2100, 1100, 2000))
  rc <- rate_change(d, count = "n", population = "pop", period = "year",
                    by = "site")
  expect_true(all(c("previous_count", "previous_population") %in%
                    names(rc)))
  expect_equal(rc$previous_count[rc$site == "A" & rc$year == 2023], 30)
  s <- scan_adjust(rc)
  i <- which(rc$site == "A" & rc$year == 2023)
  expect_equal(s$p_value[i], binom.test(45, 75, p = 1000 / 2000)$p.value)
  expect_s3_class(s, "rmbl_rate_change")
})

test_that("drift_calibrate reports a false-alarm rate on identical data", {
  set.seed(2)
  d <- data.frame(a = rnorm(300), b = sample(letters[1:3], 300, TRUE),
                  c = rpois(300, 4))
  cal <- drift_calibrate(d, n = 8, alpha = 0.01)
  expect_s3_class(cal, "rmbl_drift_calibration")
  expect_equal(nrow(cal$columns), 3)
  far <- cal$columns$false_alarm_rate
  expect_true(all(far >= 0 & far <= 1))
  expect_true(cal$any_flag >= 0 && cal$any_flag <= 1)
  expect_equal(cal$alpha_familywise, 0.01 / 3)
  expect_output(print(cal), "identical re-fetches")
  expect_error(drift_calibrate(d[1:2, ]), "four rows")
})

test_that("analyse_table runs the whole workflow on the shipped table", {
  a <- analyse_table(otis, value = "individuals", period = "year",
                     by = c("table", "group"))
  expect_s3_class(a, "bricklayer_analysis")
  expect_s3_class(a$change, "rmbl_yoy")
  expect_true(all(c("p_value", "p_adjusted", "significant") %in%
                    names(a$change)))
  expect_null(a$rates)
  expect_null(a$drift)
  expect_equal(nrow(a$trend), 5)
  expect_true(all(a$trend$periods == 3))
  # three periods: Mann-Kendall p can never be below 1/3
  expect_true(all(a$trend$trend_p >= 1 / 3 - 1e-12, na.rm = TRUE))
  expect_equal(a$meta$periods, 2023:2025)
  expect_output(print(a), "5 comparison|comparison")
})

test_that("analyse_table with bounds, exposure and a prior capsule", {
  d <- otis
  d$pop <- c(rep(25000, 9), rep(21000, 6))
  prior <- d
  prior$individuals <- round(prior$individuals * 0.9)
  a <- analyse_table(d, value = "individuals", period = "year",
                     by = c("table", "group"), population = "pop",
                     prior = prior, rounding = 5, alpha = 0.05)
  expect_true("combined_pct_lower" %in% names(a$change))
  expect_s3_class(a$rates, "rmbl_rate")
  expect_s3_class(a$rate_change, "rmbl_rate_change")
  expect_true("p_adjusted" %in% names(a$rate_change))
  expect_true(is.data.frame(a$drift$columns))
  expect_true("individuals" %in% a$drift$columns$column)
  expect_output(print(a), "publication bounds")
  expect_output(print(a), "drift vs prior")
  expect_error(analyse_table(d, value = "nope", period = "year"), "not found")
})

test_that("report_analysis writes Markdown and self-contained HTML", {
  a <- analyse_table(otis, value = "individuals", period = "year",
                     by = c("table", "group"), rounding = 5)
  md <- report_analysis(a)
  expect_match(md, "^# Analysis of a published table")
  expect_match(md, "## Change between periods")
  expect_match(md, "combined_pct_lower")
  expect_match(md, "## Trend over the series")
  f <- tempfile(fileext = ".html")
  report_analysis(a, f, title = "OTIS")
  html <- readLines(f, warn = FALSE)
  expect_match(html[1], "<!DOCTYPE html>")
  expect_true(any(grepl("<table>", html)))
  expect_true(any(grepl("<title>OTIS</title>", html)))
  expect_false(any(grepl("http://|https://", html)))
  g <- tempfile(fileext = ".md")
  report_analysis(a, g)
  expect_match(readLines(g, warn = FALSE)[1], "^# ")
  expect_error(report_analysis(otis), "analyse_table")
})

test_that("the capsule template runs as written on the shipped example", {
  d <- use_capsule_template(tempfile("capsule-"), example = TRUE)
  expect_setequal(list.files(d), c("analysis.R", "data_provenance.json",
                                   "README.md"))
  prov <- load_provenance(file.path(d, "data_provenance.json"))
  expect_true(file.exists(prov$source$url))
  expect_error(use_capsule_template(d), "not empty")
  skip_on_cran()
  res <- system2(file.path(R.home("bin"), "Rscript"),
                 c(shQuote(file.path(d, "analysis.R"))),
                 stdout = TRUE, stderr = TRUE)
  expect_true(file.exists(file.path(d, "results", "manifest.json")),
              info = paste(res, collapse = "\n"))
  expect_true(file.exists(file.path(d, "results", "report.html")))
})
