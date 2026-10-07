# Pollution -> health: every formula recomputed in the test body against the
# coefficient the documentation cites.

test_that("PM2.5: 1 at and below the counterfactual, log-linear all-cause, Burnett IER per cause", {
  expect_equal(crf_pm25(5.8)$rr, 1)
  expect_equal(crf_pm25(2)$rr, 1)
  r <- crf_pm25(12)
  expect_equal(r$rr, exp(log(1.08) * (12 - 5.8) / 10))  # RR 1.08 per 10 ug/m3 (Chen & Hoek 2020)
  expect_equal(r$log_rr, log(r$rr))
  expect_equal(r$exposure_conc, 12)
  expect_equal(r$extra$beta_per_10, log(1.08))
  expect_null(r$extra$rr_per_unit)
  expect_true(crf_pm25(30)$rr > r$rr)
  expect_equal(r$citation, "Chen & Hoek (2020) Environ Int 143:105974; WHO (2021) Global AQ Guidelines")
  expect_s3_class(r, "rmbl_crf")
  ihd <- crf_pm25(12, outcome = "ihd")
  expect_equal(ihd$rr, 1 + 1.91 * (1 - exp(-0.14 * (12 - 5.8)^0.49)))
  expect_equal(ihd$citation, "Burnett et al. (2014) EHP 122(4):397-403")
  expect_equal(ihd$extra$form, "IER")
  stroke <- crf_pm25(20, outcome = "stroke")
  expect_equal(stroke$rr, 1 + 1.46 * (1 - exp(-0.13 * (20 - 5.8)^0.61)))
  v <- crf_pm25(c(5, 12, 20))
  expect_equal(v$rr, mean(v$extra$rr_per_unit))
  expect_equal(v$exposure_conc, mean(c(5, 12, 20)))
  expect_length(v$extra$rr_per_unit, 3L)
  expect_error(crf_pm25(10, outcome = "nope"), "Unknown outcome")
  expect_error(crf_pm25("twelve"), "exposure")
  expect_error(crf_pm25(numeric(0)), "exposure")
})

test_that("NO2 log-linear: doubling the increment doubles log-RR, outcome table, beta override", {
  expect_equal(crf_no2(10)$rr, 1)
  a <- crf_no2(20)
  b <- crf_no2(30)
  expect_equal(a$log_rr, log(1.02))  # RR 1.02 per 10 ug/m3 (Huangfu & Atkinson 2020)
  expect_equal(b$log_rr, 2 * a$log_rr)
  expect_equal(crf_no2(20, beta_per_10 = 0.1)$log_rr, 0.1)
  expect_equal(crf_no2(20, outcome = "respiratory")$log_rr, 0.029)
  expect_equal(crf_no2(20, outcome = "childhood_asthma")$log_rr, 0.039)
  expect_equal(crf_no2(20, outcome = "anything", beta_per_10 = 0.05)$log_rr, 0.05)
  expect_error(crf_no2(20, outcome = "nope"), "Unknown outcome")
  expect_error(crf_no2(20, beta_per_10 = c(1, 2)), "beta_per_10")
})

test_that("attributable_fraction: Levin's formula and its boundaries", {
  expect_equal(attributable_fraction(1.5, 0), 0)
  expect_equal(attributable_fraction(1, 0.7), 0)
  expect_equal(attributable_fraction(2, 1), 1 - 1 / 2)
  expect_equal(attributable_fraction(1.5, 0.4), 0.4 * 0.5 / (1 + 0.4 * 0.5))
  expect_true(attributable_fraction(1.5, 0.6) > attributable_fraction(1.5, 0.3))
  expect_equal(attributable_fraction(0, 1), 0)   # den = 1 + 1 * (0 - 1) = 0 -> 0 by definition
  expect_error(attributable_fraction(1.5, 1.2), "must be in")
  expect_error(attributable_fraction(c(1, 2), 0.5), "single")
})

test_that("mortality_displaced: BenMAP form, linear in N, small-beta limit", {
  expect_equal(mortality_displaced(0, 1e6, 0.008, 0.0039), 0)
  one <- mortality_displaced(10, 1e6, 0.008, 0.0039)
  expect_equal(one, 0.008 * 1e6 * (1 - exp(-0.039)))
  expect_equal(mortality_displaced(10, 2e6, 0.008, 0.0039), 2 * one)
  expect_equal(mortality_displaced(1, 1e6, 0.008, 1e-5), 0.008 * 1e6 * 1e-5, tolerance = 1e-5)
  expect_error(mortality_displaced(1, -1, 0.008, 0.001), "non-negative")
  expect_error(mortality_displaced(1, 1, -0.008, 0.001), "non-negative")
})

test_that("pollution_burden chains CRF -> PAF -> cases for both pollutants", {
  b <- pollution_burden(25, 1, 0.008, 1e6, pollutant = "NO2")
  rr <- exp(log(1.02) * 1.5)  # RR 1.02 per 10 ug/m3 above the 10 ug/m3 reference
  expect_equal(b$extra$rr, rr)
  expect_equal(b$paf, (rr - 1) / rr)
  expect_equal(b$baseline_cases, 8000)
  expect_equal(b$attributable_cases, b$paf * 8000)
  expect_equal(b$reference_conc, 10)
  expect_s3_class(b, "rmbl_burden")
  expect_match(b$citation, "Rothman")
  p <- pollution_burden(12, 0.9, 0.005, 5e5, pollutant = "PM2.5")
  expect_equal(p$extra$rr, crf_pm25(12)$rr)
  expect_equal(p$reference_conc, 5.8)
  expect_equal(pollution_burden(12, 1, 0.005, 5e5, pollutant = "PM2.5", reference_conc = 8)$extra$rr,
               crf_pm25(12, reference_conc = 8)$rr)
  expect_equal(pollution_burden(4, 1, 0.008, 1e6, pollutant = "PM2.5")$attributable_cases, 0)
  expect_error(pollution_burden(4, 1, 0.008, 1e6, pollutant = "O3"), "Unknown pollutant")
})

test_that("plr_crossfit recovers a linear exposure effect and matches its own recipe exactly", {
  set.seed(7)
  n <- 160
  d <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
  d$exposure <- 20 + 2 * d$x1 + rnorm(n)
  d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(n)
  r <- plr_crossfit(d, "asthma", "exposure", c("x1", "x2"), k_folds = 4L, seed = 3L)
  ols <- unname(stats::coef(stats::lm(asthma ~ exposure + x1 + x2, d))["exposure"])
  expect_lt(abs(r$ate - ols), 0.05)
  expect_lt(abs(r$ate - 0.3), 0.1)
  expect_equal(r$n, n)
  expect_equal(r$k_folds, 4L)
  # the recipe, step by step, with the same fold draw
  folds <- rmoriebricklayer:::.rmbl_with_seed(3L, sample(rep_len(1:4, n)))
  X <- cbind(1, d$x1, d$x2)
  U <- V <- numeric(n)
  for (k in 1:4) {
    te <- folds == k
    gy <- stats::lm.fit(X[!te, ], d$asthma[!te])$coefficients
    gd <- stats::lm.fit(X[!te, ], d$exposure[!te])$coefficients
    U[te] <- d$asthma[te] - drop(X[te, , drop = FALSE] %*% gy)
    V[te] <- d$exposure[te] - drop(X[te, , drop = FALSE] %*% gd)
  }
  theta <- sum(V * U) / sum(V^2)
  expect_equal(r$ate, theta, tolerance = 1e-12)
  expect_equal(r$se, sqrt(sum(V^2 * (U - theta * V)^2)) / sum(V^2), tolerance = 1e-12)
  expect_error(plr_crossfit(d, "asthma", "exposure", "nope"), "missing columns")
  expect_error(plr_crossfit(d, "asthma", "exposure", "x1", k_folds = 1), "at least 2")
  expect_error(plr_crossfit(d[1:6, ], "asthma", "exposure", "x1", k_folds = 5), "complete rows")
  # a treatment that is a function of the covariates has nothing left to identify
  d2 <- d
  d2$exposure <- d2$x1
  expect_error(plr_crossfit(d2, "asthma", "exposure", "x1"), "no variation")
  # a collinear covariate is handled (its coefficient is dropped, not NA-propagated)
  d3 <- d
  d3$x3 <- d3$x1
  expect_true(is.finite(plr_crossfit(d3, "asthma", "exposure", c("x1", "x2", "x3"))$ate))
})

test_that("exposure_response_plr wraps the estimator with a percentile bootstrap and accepts another", {
  set.seed(7)
  n <- 150
  d <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
  d$exposure <- 20 + 2 * d$x1 + rnorm(n)
  d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(n)
  r <- exposure_response_plr(d, outcome = "asthma", exposure = "exposure",
                             confounders = c("x1", "x2"), n_bootstrap = 15L)
  expect_equal(r$n_bootstrap, 15L)
  expect_true(r$ci_lower_bs < r$ate && r$ate < r$ci_upper_bs)
  ols <- unname(stats::coef(stats::lm(asthma ~ exposure + x1 + x2, d))["exposure"])
  expect_lt(abs(r$ate - ols), 0.05)
  expect_match(r$method, "bootstrap")
  # the same seed gives the same interval
  r2 <- exposure_response_plr(d, "asthma", "exposure", c("x1", "x2"), n_bootstrap = 15L)
  expect_equal(r$ci_lower_bs, r2$ci_lower_bs)
  # a user estimator with the same interface is used for the base fit and the resamples
  constant <- function(data, outcome, treatment, covariates) list(ate = 0.25, se = 0.01)
  c1 <- exposure_response_plr(d, "asthma", "exposure", c("x1", "x2"), n_bootstrap = 12L, estimator = constant)
  expect_equal(c1$ate, 0.25)
  expect_equal(c1$se_bootstrap, 0)
  expect_match(c1$method, "^exposure-response")
  # too few successful fits is an error, not a silent interval
  flaky <- function(data, outcome, treatment, covariates) stop("no")
  expect_error(exposure_response_plr(d, "asthma", "exposure", c("x1", "x2"), n_bootstrap = 12L,
                                     estimator = function(data, outcome, treatment, covariates) {
                                       same <- nrow(data) == n && identical(rownames(data), rownames(d))
                                       if (same) list(ate = 1, se = 1) else flaky()
                                     }), "successful bootstrap fits")
})

test_that("exposure_concentration_index: zero, pro-poor, pro-rich; population covariance", {
  flat <- data.frame(exposure = rep(10, 20), income = 1:20)
  expect_equal(exposure_concentration_index(flat, "exposure", "income")$concentration_index, 0)
  poor <- data.frame(exposure = 30:11, income = 1:20)
  e <- exposure_concentration_index(poor, "exposure", "income")
  expect_true(e$concentration_index < 0)
  R <- (seq_len(20) - 0.5) / 20
  h <- 30:11
  expect_equal(e$concentration_index, 2 * (sum((h - mean(h)) * (R - mean(R))) / 20) / mean(h))
  expect_match(e$interpretation, "Pro-poor")
  expect_equal(e$extra$n, 20L)
  expect_s3_class(e, "rmbl_equity")
  rich <- data.frame(exposure = 11:30, income = 1:20)
  expect_match(exposure_concentration_index(rich, "exposure", "income")$interpretation, "Pro-rich")
  expect_match(exposure_concentration_index(flat, "exposure", "income")$interpretation, "evenly")
  expect_error(exposure_concentration_index(poor[1, ], "exposure", "income"), "at least 2")
  expect_error(exposure_concentration_index(data.frame(exposure = c(0, 0), income = 1:2), "exposure", "income"), "zero")
  expect_error(exposure_concentration_index(poor, "exposure", "wealth"), "missing columns")
  # missing rows are dropped before ranking
  withna <- rbind(poor, data.frame(exposure = NA, income = 21))
  expect_equal(exposure_concentration_index(withna, "exposure", "income")$concentration_index, e$concentration_index)
})

test_that("pollution_burden_by_area sorts worst first, keeps the names, rejects bad tables", {
  t <- data.frame(fsa = c("M5V", "M6H"), exposure = c(18, 28), population = c(60000, 40000), baseline_rate = 0.008)
  r <- pollution_burden_by_area(t)
  expect_equal(r$fsa, c("M6H", "M5V"))
  expect_equal(r$attributable_cases[1], pollution_burden(28, 1, 0.008, 40000)$attributable_cases)
  expect_equal(r$rr[2], crf_no2(18)$rr)
  expect_equal(names(r), c("fsa", "exposure", "population", "baseline_rate", "rr", "paf",
                           "attributable_cases", "baseline_cases"))
  t2 <- data.frame(tract = c("a", "b"), pm = c(9, 14), pop = c(1000, 1000), rate = 0.01)
  r2 <- pollution_burden_by_area(t2, area_col = "tract", exposure_col = "pm", population_col = "pop",
                                 baseline_rate_col = "rate", pollutant = "PM2.5")
  expect_equal(r2$tract, c("b", "a"))
  expect_error(pollution_burden_by_area(t[, 1:2]), "missing columns")
  expect_error(pollution_burden_by_area(t[0, ]), "no rows")
})

test_that("verify_pollution: ok, one reference, avoided deaths over the exposed share, failures, CSVs, demo", {
  ok <- verify_pollution("no2", exposure_mean = 25, exposure_prevalence = 0.9)
  expect_equal(ok$status, "ok")
  expect_equal(attr(ok, "exit_status"), 0L)
  expect_equal(ok$pipeline$crf$rr, exp(log(1.02) * (25 - 5.8) / 10))
  expect_equal(ok$pipeline$paf, attributable_fraction(ok$pipeline$crf$rr, 0.9))
  expect_equal(ok$pipeline$displaced$deaths_displaced, 500 / 1e5 * 1e6 * 0.9 * (1 - 1 / ok$pipeline$crf$rr))
  expect_null(ok$pipeline$equity)
  # the burden uses the same reference concentration as the RR above it
  r <- verify_pollution("no2", exposure_mean = 20, exposure_prevalence = 0.5, reference = 5.8,
                        baseline_rate = 500, population = 1e6)
  rr <- exp(log(1.02) * (20 - 5.8) / 10)
  paf <- 0.5 * (rr - 1) / (0.5 * (rr - 1) + 1)
  expect_equal(r$pipeline$burden$reference_conc, 5.8)
  expect_equal(r$pipeline$burden$attributable_cases, paf * 500 / 1e5 * 1e6, tolerance = 1e-9)
  expect_equal(r$pipeline$displaced$deaths_displaced, 500 / 1e5 * 1e6 * 0.5 * (1 - 1 / rr), tolerance = 1e-9)
  bad <- verify_pollution("pm25", exposure_mean = 2, exposure_prevalence = 0.5)
  expect_equal(bad$status, "assumption_failure")
  expect_equal(attr(bad, "exit_status"), 1L)
  expect_true(bad$pipeline$skipped)
  expect_equal(verify_pollution("o3", exposure_mean = 20, exposure_prevalence = 0.5)$status, "assumption_failure")
  d <- tempfile()
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  f <- file.path(d, "e.csv")
  utils::write.csv(data.frame(exposure = c(20, 30, 25), income = c(1, 3, 2)), f, row.names = FALSE)
  c <- verify_pollution("no2", exposure_csv = f, region = "Toronto", years = "2023")
  expect_equal(c$status, "ok")
  expect_false(is.null(c$pipeline$equity))
  expect_equal(c$inputs$exposure_mean, 25)
  expect_equal(c$data_source, f)
  utils::write.csv(data.frame(x = 1), f, row.names = FALSE)
  expect_equal(attr(verify_pollution("no2", exposure_csv = f), "exit_status"), 2L)
  expect_match(verify_pollution("no2", exposure_csv = f)$error, "missing 'exposure'")
  expect_equal(attr(verify_pollution("no2", exposure_csv = file.path(d, "none.csv")), "exit_status"), 2L)
  writeLines(character(0), f)
  expect_match(verify_pollution("no2", exposure_csv = f)$error, "is empty")
  writeLines("exposure", f)
  expect_match(verify_pollution("no2", exposure_csv = f)$error, "is empty")
  # a NAPS pull: NO2 in ppb is converted at 1.88; another unit is refused
  utils::write.csv(data.frame(station_id = 1, value = c(5, 10), unit = "ppb"), f, row.names = FALSE)
  expect_message(naps <- verify_pollution("no2", exposure_csv = f, reference = 10), "x 1.88")
  expect_equal(naps$inputs$exposure_mean, 7.5 * 1.88)
  writeLines(c("station_id,value,unit", "1,0.5,ppm"), f)
  expect_equal(verify_pollution("no2", exposure_csv = f)$status, "error")
  utils::write.csv(data.frame(value = c(12, 14), unit = "ug/m3"), f, row.names = FALSE)
  expect_equal(verify_pollution("pm25", exposure_csv = f)$inputs$exposure_mean, 13)
  demo <- verify_pollution("pm25", demo = TRUE)
  expect_equal(demo$status, "ok")
  expect_equal(demo$data_source, "demo (synthetic)")
  expect_false(is.null(demo$pipeline$equity))
  demo2 <- verify_pollution("no2", demo = TRUE)
  expect_equal(demo2$inputs$exposure_mean, verify_pollution("no2", demo = TRUE)$inputs$exposure_mean)
  # the demo seed does not disturb the caller's RNG stream
  set.seed(11)
  a <- stats::runif(1)
  set.seed(11)
  invisible(verify_pollution("no2", demo = TRUE))
  expect_equal(stats::runif(1), a)
})

test_that("pollution_report_text renders ok, failure and error reports", {
  demo <- verify_pollution("pm25", demo = TRUE, region = "demo region", years = "2024")
  txt <- pollution_report_text(demo)
  expect_match(txt, "verify-pollution -- PM25 -> all_cause_mortality", fixed = TRUE)
  expect_match(txt, "region: demo region", fixed = TRUE)
  expect_match(txt, "years:  2024", fixed = TRUE)
  expect_match(txt, "attributable deaths:   [0-9.]+")
  expect_match(txt, "concentration index: -?[0-9.]+")
  expect_match(txt, "STATUS: ok")
  bad <- pollution_report_text(verify_pollution("pm25", exposure_mean = 2, exposure_prevalence = 0.5))
  expect_match(bad, "\\[FAIL\\] exposure > reference")
  expect_match(bad, "STATUS: assumption_failure")
  err <- pollution_report_text(verify_pollution("no2", exposure_csv = tempfile()))
  expect_match(err, "^ERROR: exposure CSV not found")
  plain <- pollution_report_text(verify_pollution("no2", exposure_mean = 25, exposure_prevalence = 1))
  expect_false(grepl("Equity analysis", plain))
})
