# Pollution -> health: every formula recomputed in the test body against the
# coefficient the documentation cites.

test_that("PM2.5: 1 at and below the counterfactual, log-linear all-cause, Burnett IER per cause", {
  expect_equal(crfpm25(5.8)$rr, 1)
  expect_equal(crfpm25(2)$rr, 1)
  r <- crfpm25(12)
  expect_equal(r$rr, exp(log(1.08) * (12 - 5.8) / 10))  # RR 1.08 per 10 ug/m3 (Chen & Hoek 2020)
  expect_equal(r$logrr, log(r$rr))
  expect_equal(r$expconc, 12)
  expect_equal(r$extra$betaper10, log(1.08))
  expect_null(r$extra$rrperunit)
  expect_true(crfpm25(30)$rr > r$rr)
  expect_equal(r$citation, "Chen & Hoek (2020) Environ Int 143:105974; WHO (2021) Global AQ Guidelines")
  expect_s3_class(r, "rmbl_crf")
  ihd <- crfpm25(12, y = "ihd")
  expect_equal(ihd$rr, 1 + 1.91 * (1 - exp(-0.14 * (12 - 5.8)^0.49)))
  expect_equal(ihd$citation, "Burnett et al. (2014) EHP 122(4):397-403")
  expect_equal(ihd$extra$form, "IER")
  stroke <- crfpm25(20, y = "stroke")
  expect_equal(stroke$rr, 1 + 1.46 * (1 - exp(-0.13 * (20 - 5.8)^0.61)))
  v <- crfpm25(c(5, 12, 20))
  expect_equal(v$rr, mean(v$extra$rrperunit))
  expect_equal(v$expconc, mean(c(5, 12, 20)))
  expect_length(v$extra$rrperunit, 3L)
  expect_error(crfpm25(10, y = "nope"), "Unknown outcome")
  expect_error(crfpm25("twelve"), "exposure")
  expect_error(crfpm25(numeric(0)), "exposure")
})

test_that("NO2 log-linear: doubling the increment doubles log-RR, outcome table, beta override", {
  expect_equal(crfno2(10)$rr, 1)
  a <- crfno2(20)
  b <- crfno2(30)
  expect_equal(a$logrr, log(1.02))  # RR 1.02 per 10 ug/m3 (Huangfu & Atkinson 2020)
  expect_equal(b$logrr, 2 * a$logrr)
  expect_equal(crfno2(20, betaper10 = 0.1)$logrr, 0.1)
  expect_equal(crfno2(20, y = "respiratory")$logrr, log(1.03))   # Huangfu & Atkinson 2020
  expect_equal(crfno2(20, y = "chiast")$logrr, log(1.05) * 10 / 4)   # Khreis 2017, per 4 -> per 10
  expect_equal(crfno2(20, y = "anything", betaper10 = 0.05)$logrr, 0.05)
  expect_error(crfno2(20, y = "nope"), "Unknown outcome")
  expect_error(crfno2(20, betaper10 = c(1, 2)), "betaper10")
})

test_that("attrfrac: Levin's formula and its boundaries", {
  expect_equal(attrfrac(1.5, 0), 0)
  expect_equal(attrfrac(1, 0.7), 0)
  expect_equal(attrfrac(2, 1), 1 - 1 / 2)
  expect_equal(attrfrac(1.5, 0.4), 0.4 * 0.5 / (1 + 0.4 * 0.5))
  expect_true(attrfrac(1.5, 0.6) > attrfrac(1.5, 0.3))
  expect_error(attrfrac(0, 1), "positive")   # RR = 0 is not a relative risk
  expect_error(attrfrac(1.5, 1.2), "must be in")
  expect_error(attrfrac(c(1, 2), 0.5), "single")
})

test_that("mortdisp: BenMAP form, linear in N, small-beta limit", {
  expect_equal(mortdisp(0, 1e6, 0.008, 0.0039), 0)
  one <- mortdisp(10, 1e6, 0.008, 0.0039)
  expect_equal(one, 0.008 * 1e6 * (1 - exp(-0.039)))
  expect_equal(mortdisp(10, 2e6, 0.008, 0.0039), 2 * one)
  expect_equal(mortdisp(1, 1e6, 0.008, 1e-5), 0.008 * 1e6 * 1e-5, tolerance = 1e-5)
  expect_error(mortdisp(1, -1, 0.008, 0.001), "non-negative")
  expect_error(mortdisp(1, 1, -0.008, 0.001), "non-negative")
})

test_that("polbrdn chains CRF -> PAF -> cases for both pollutants", {
  b <- polbrdn(25, 1, 0.008, 1e6, poll = "NO2")
  rr <- exp(log(1.02) * 1.5)  # RR 1.02 per 10 ug/m3 above the 10 ug/m3 reference
  expect_equal(b$extra$rr, rr)
  expect_equal(b$paf, (rr - 1) / rr)
  expect_equal(b$basecases, 8000)
  expect_equal(b$attrcases, b$paf * 8000)
  expect_equal(b$refconc, 10)
  expect_s3_class(b, "rmbl_burden")
  expect_match(b$citation, "Rothman")
  p <- polbrdn(12, 0.9, 0.005, 5e5, poll = "PM2.5")
  expect_equal(p$extra$rr, crfpm25(12)$rr)
  expect_equal(p$refconc, 5.8)
  expect_equal(polbrdn(12, 1, 0.005, 5e5, poll = "PM2.5", refconc = 8)$extra$rr,
               crfpm25(12, refconc = 8)$rr)
  expect_equal(polbrdn(4, 1, 0.008, 1e6, poll = "PM2.5")$attrcases, 0)
  expect_error(polbrdn(4, 1, 0.008, 1e6, poll = "O3"), "Unknown pollutant")
})

test_that("plrcf recovers a linear exposure effect and matches its own recipe exactly", {
  set.seed(7)
  n <- 160
  d <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
  d$exposure <- 20 + 2 * d$x1 + rnorm(n)
  d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(n)
  r <- plrcf(d, "asthma", "exposure", c("x1", "x2"), kfol = 4L, seed = 3L)
  ols <- unname(stats::coef(stats::lm(asthma ~ exposure + x1 + x2, d))["exposure"])
  expect_lt(abs(r$ate - ols), 0.05)
  expect_lt(abs(r$ate - 0.3), 0.1)
  expect_equal(r$n, n)
  expect_equal(r$kfol, 4L)
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
  expect_error(plrcf(d, "asthma", "exposure", "nope"), "missing columns")
  expect_error(plrcf(d, "asthma", "exposure", "x1", kfol = 1), "at least 2")
  expect_error(plrcf(d[1:6, ], "asthma", "exposure", "x1", kfol = 5), "complete rows")
  # a treatment that is a function of the covariates has nothing left to identify
  d2 <- d
  d2$exposure <- d2$x1
  expect_error(plrcf(d2, "asthma", "exposure", "x1"), "no variation")
  # a collinear covariate is handled (its coefficient is dropped, not NA-propagated)
  d3 <- d
  d3$x3 <- d3$x1
  expect_true(is.finite(plrcf(d3, "asthma", "exposure", c("x1", "x2", "x3"))$ate))
})

test_that("exprspplr wraps the estimator with a percentile bootstrap and accepts another", {
  set.seed(7)
  n <- 150
  d <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
  d$exposure <- 20 + 2 * d$x1 + rnorm(n)
  d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(n)
  r <- exprspplr(d, y = "asthma", expo = "exposure",
                             confs = c("x1", "x2"), nboot = 15L)
  expect_equal(r$nboot, 15L)
  expect_true(r$cilobs < r$ate && r$ate < r$ciupbs)
  ols <- unname(stats::coef(stats::lm(asthma ~ exposure + x1 + x2, d))["exposure"])
  expect_lt(abs(r$ate - ols), 0.05)
  expect_match(r$method, "bootstrap")
  # the same seed gives the same interval
  r2 <- exprspplr(d, "asthma", "exposure", c("x1", "x2"), nboot = 15L)
  expect_equal(r$cilobs, r2$cilobs)
  # a user estimator with the same interface is used for the base fit and the resamples
  constant <- function(data, outcome, treatment, covariates) list(ate = 0.25, se = 0.01)
  c1 <- exprspplr(d, "asthma", "exposure", c("x1", "x2"), nboot = 12L, estr = constant)
  expect_equal(c1$ate, 0.25)
  expect_equal(c1$seboot, 0)
  expect_match(c1$method, "^exposure-response")
  # too few successful fits is an error, not a silent interval
  flaky <- function(data, outcome, treatment, covariates) stop("no")
  expect_error(exprspplr(d, "asthma", "exposure", c("x1", "x2"), nboot = 12L,
                                     estr = function(data, outcome, treatment, covariates) {
                                       same <- nrow(data) == n && identical(rownames(data), rownames(d))
                                       if (same) list(ate = 1, se = 1) else flaky()
                                     }), "successful bootstrap fits")
})

test_that("expconcidx: zero, pro-poor, pro-rich; population covariance", {
  flat <- data.frame(exposure = rep(10, 20), income = 1:20)
  expect_equal(expconcidx(flat, "exposure", "income")$concidx, 0)
  poor <- data.frame(exposure = 30:11, income = 1:20)
  e <- expconcidx(poor, "exposure", "income")
  expect_true(e$concidx < 0)
  R <- (seq_len(20) - 0.5) / 20
  h <- 30:11
  expect_equal(e$concidx, 2 * (sum((h - mean(h)) * (R - mean(R))) / 20) / mean(h))
  expect_match(e$interpretation, "Pro-poor")
  expect_equal(e$extra$n, 20L)
  expect_s3_class(e, "rmbl_equity")
  rich <- data.frame(exposure = 11:30, income = 1:20)
  expect_match(expconcidx(rich, "exposure", "income")$interpretation, "Pro-rich")
  expect_match(expconcidx(flat, "exposure", "income")$interpretation, "evenly")
  expect_error(expconcidx(poor[1, ], "exposure", "income"), "at least 2")
  expect_error(expconcidx(data.frame(exposure = c(0, 0), income = 1:2), "exposure", "income"), "zero")
  expect_error(expconcidx(poor, "exposure", "wealth"), "missing columns")
  # missing rows are dropped before ranking
  withna <- rbind(poor, data.frame(exposure = NA, income = 21))
  expect_equal(expconcidx(withna, "exposure", "income")$concidx, e$concidx)
})

test_that("polbrdarea sorts worst first, keeps the names, rejects bad tables", {
  t <- data.frame(fsa = c("M5V", "M6H"), exposure = c(18, 28), population = c(60000, 40000), brate = 0.008)
  r <- polbrdarea(t)
  expect_equal(r$fsa, c("M6H", "M5V"))
  expect_equal(r$attrcases[1], polbrdn(28, 1, 0.008, 40000)$attrcases)
  expect_equal(r$rr[2], crfno2(18)$rr)
  expect_equal(names(r), c("fsa", "exposure", "population", "brate", "rr", "paf",
                           "attrcases", "basecases"))
  t2 <- data.frame(tract = c("a", "b"), pm = c(9, 14), pop = c(1000, 1000), rate = 0.01)
  r2 <- polbrdarea(t2, areacol = "tract", expcol = "pm", popcol = "pop",
                                 basratecol = "rate", poll = "PM2.5")
  expect_equal(r2$tract, c("b", "a"))
  expect_error(polbrdarea(t[, 1:2]), "missing columns")
  expect_error(polbrdarea(t[0, ]), "no rows")
})

test_that("vrfpol: ok, one reference, avoided deaths over the exposed share, failures, CSVs, demo", {
  ok <- vrfpol("no2", expomean = 25, expoprev = 0.9)
  expect_equal(ok$status, "ok")
  expect_equal(attr(ok, "exitstat"), 0L)
  expect_equal(ok$pipeline$crf$rr, exp(log(1.02) * (25 - 10) / 10))   # the NO2 counterfactual, 10
  expect_equal(ok$pipeline$paf, attrfrac(ok$pipeline$crf$rr, 0.9))
  expect_equal(ok$pipeline$displaced$deadisp, 500 / 1e5 * 1e6 * 0.9 * (1 - 1 / ok$pipeline$crf$rr))
  expect_null(ok$pipeline$equity)
  # the burden uses the same reference concentration as the RR above it
  r <- vrfpol("no2", expomean = 20, expoprev = 0.5, ref = 5.8,
                        brate = 500, pop = 1e6)
  rr <- exp(log(1.02) * (20 - 5.8) / 10)
  paf <- 0.5 * (rr - 1) / (0.5 * (rr - 1) + 1)
  expect_equal(r$pipeline$burden$refconc, 5.8)
  expect_equal(r$pipeline$burden$attrcases, paf * 500 / 1e5 * 1e6, tolerance = 1e-9)
  expect_equal(r$pipeline$displaced$deadisp, 500 / 1e5 * 1e6 * 0.5 * (1 - 1 / rr), tolerance = 1e-9)
  # exposure at or below the counterfactual floor is a zero result, not a failed assumption
  low <- vrfpol("pm25", expomean = 2, expoprev = 0.5)
  expect_equal(low$status, "ok")
  expect_equal(attr(low, "exitstat"), 0L)
  expect_equal(low$pipeline$paf, 0)
  expect_equal(low$pipeline$burden$attrcases, 0)
  bad <- vrfpol("pm25", expomean = NA, expoprev = 0.5)
  expect_equal(bad$status, "assumption_failure")
  expect_equal(attr(bad, "exitstat"), 1L)
  expect_true(bad$pipeline$skipped)
  expect_equal(vrfpol("o3", expomean = 20, expoprev = 0.5)$status, "assumption_failure")
  d <- tempfile()
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  f <- file.path(d, "e.csv")
  utils::write.csv(data.frame(exposure = c(20, 30, 25), income = c(1, 3, 2)), f, row.names = FALSE)
  c <- vrfpol("no2", expcsv = f, reg = "Toronto", years = "2023")
  expect_equal(c$status, "ok")
  expect_false(is.null(c$pipeline$equity))
  expect_equal(c$inputs$expomean, 25)
  expect_equal(c$dsou, f)
  utils::write.csv(data.frame(x = 1), f, row.names = FALSE)
  expect_equal(attr(vrfpol("no2", expcsv = f), "exitstat"), 2L)
  expect_match(vrfpol("no2", expcsv = f)$error, "missing 'exposure'")
  expect_equal(attr(vrfpol("no2", expcsv = file.path(d, "none.csv")), "exitstat"), 2L)
  writeLines(character(0), f)
  expect_match(vrfpol("no2", expcsv = f)$error, "is empty")
  writeLines("exposure", f)
  expect_match(vrfpol("no2", expcsv = f)$error, "is empty")
  # a NAPS pull: NO2 in ppb is converted at 1.88; another unit is refused
  utils::write.csv(data.frame(station_id = 1, value = c(5, 10), unit = "ppb"), f, row.names = FALSE)
  expect_message(naps <- vrfpol("no2", expcsv = f, ref = 10), "x 1.88")
  # 5 and 10 ppb are 9.4 and 18.8 ug/m3; only the second is above the floor of 10
  expect_equal(naps$inputs$expomean, 10 * 1.88)
  expect_equal(naps$inputs$expoprev, 0.5)
  writeLines(c("station_id,value,unit", "1,0.5,ppm"), f)
  expect_equal(vrfpol("no2", expcsv = f)$status, "error")
  utils::write.csv(data.frame(value = c(12, 14), unit = "ug/m3"), f, row.names = FALSE)
  expect_equal(vrfpol("pm25", expcsv = f)$inputs$expomean, 13)
  demo <- vrfpol("pm25", demo = TRUE)
  expect_equal(demo$status, "ok")
  expect_equal(demo$dsou, "demo (synthetic)")
  expect_false(is.null(demo$pipeline$equity))
  demo2 <- vrfpol("no2", demo = TRUE)
  expect_equal(demo2$inputs$expomean, vrfpol("no2", demo = TRUE)$inputs$expomean)
  # the demo seed does not disturb the caller's RNG stream
  set.seed(11)
  a <- stats::runif(1)
  set.seed(11)
  invisible(vrfpol("no2", demo = TRUE))
  expect_equal(stats::runif(1), a)
})

test_that("polrpttxt renders ok, failure and error reports", {
  demo <- vrfpol("pm25", demo = TRUE, reg = "demo region", years = "2024")
  txt <- polrpttxt(demo)
  expect_match(txt, "verify-pollution -- PM25 -> allcause", fixed = TRUE)
  expect_match(txt, "region: demo region", fixed = TRUE)
  expect_match(txt, "years:  2024", fixed = TRUE)
  expect_match(txt, "attributable deaths:   [0-9.]+")
  expect_match(txt, "concentration index: -?[0-9.]+")
  expect_match(txt, "STATUS: ok")
  low <- polrpttxt(vrfpol("pm25", expomean = 2, expoprev = 0.5))
  expect_match(low, "\\[PASS\\] exposure finite and non-negative -- mean 2 is at or below the counterfactual floor")
  expect_match(low, "attributable deaths:   0.0", fixed = TRUE)
  bad <- polrpttxt(vrfpol("pm25", expomean = Inf, expoprev = 0.5))
  expect_match(bad, "\\[FAIL\\] exposure finite and non-negative")
  expect_match(bad, "STATUS: assumption_failure")
  err <- polrpttxt(vrfpol("no2", expcsv = tempfile()))
  expect_match(err, "^ERROR: exposure CSV not found")
  plain <- polrpttxt(vrfpol("no2", expomean = 25, expoprev = 1))
  expect_false(grepl("Equity analysis", plain))
})
