# Pollution -> health: every formula recomputed in the test body against the
# coefficient the documentation cites.

test_that(
  paste0(
    "PM2.5: 1 at and below the counterfactual, log-linear all-cause, ",
    "Burnett IER per cause"
  ),
  {
    expect_identical(crfpm25(5.8)$rr, 1)
    expect_identical(crfpm25(2)$rr, 1)
    r <- crfpm25(12)
    # RR 1.08 per 10 ug/m3 (Chen & Hoek 2020)
    expect_identical(r$rr, exp(log(1.08) * (12 - 5.8) / 10))
    expect_equal(r$logrr, log(r$rr), tolerance = testthat::testthat_tolerance())
    expect_identical(r$expconc, 12)
    expect_identical(r$extra$betaper10, log(1.08))
    expect_null(r$extra$rrperunit)
    expect_gt(crfpm25(30)$rr, r$rr)
    expect_identical(
      r$citation,
      paste0(
        "Chen & Hoek (2020) Environ Int 143:105974; WHO (2021) Global AQ ",
        "Guidelines"
      )
    )
    expect_s3_class(r, "rmbl_crf")
    ihd <- crfpm25(12, y = "ihd")
    expect_identical(ihd$rr, 1 + 1.91 * (1 - exp(-0.14 * (12 - 5.8)^0.49)))
    expect_identical(ihd$citation, "Burnett et al. (2014) EHP 122(4):397-403")
    expect_identical(ihd$extra$form, "IER")
    stroke <- crfpm25(20, y = "stroke")
    expect_identical(stroke$rr, 1 + 1.46 * (1 - exp(-0.13 * (20 - 5.8)^0.61)))
    v <- crfpm25(c(5, 12, 20))
    expect_identical(v$rr, mean(v$extra$rrperunit))
    expect_identical(v$expconc, mean(c(5, 12, 20)))
    expect_length(v$extra$rrperunit, 3L)
    expect_error(crfpm25(10, y = "nope"), "Unknown outcome")
    expect_error(crfpm25("twelve"), "exposure")
    expect_error(crfpm25(numeric(0)), "exposure")
  }
)

test_that(
  paste0(
    "NO2 log-linear: doubling the increment doubles log-RR, outcome table, ",
    "beta override"
  ),
  {
    expect_identical(crfno2(10)$rr, 1)
    a <- crfno2(20)
    b <- crfno2(30)
    # RR 1.02 per 10 ug/m3 (Huangfu & Atkinson 2020)
    expect_identical(a$logrr, log(1.02))
    expect_identical(b$logrr, 2 * a$logrr)
    expect_equal(crfno2(20, betaper10 = 0.1)$logrr, 0.1)
    # Huangfu & Atkinson 2020
    expect_identical(crfno2(20, y = "respiratory")$logrr, log(1.03))
    # Khreis 2017, per 4 -> per 10
    expect_equal(
      crfno2(20, y = "chiast")$logrr,
      log(1.05) * 10 / 4,
      tolerance = testthat::testthat_tolerance()
    )
    expect_equal(crfno2(20, y = "anything", betaper10 = 0.05)$logrr, 0.05)
    expect_error(crfno2(20, y = "nope"), "Unknown outcome")
    expect_error(crfno2(20, betaper10 = c(1, 2)), "betaper10")
  }
)

test_that("attrfrac: Levin's formula and its boundaries", {
  expect_identical(as.numeric(attrfrac(1.5, 0)), 0)
  expect_identical(as.numeric(attrfrac(1, 0.7)), 0)
  expect_identical(as.numeric(attrfrac(2, 1)), 1 - 1 / 2)
  expect_identical(
    as.numeric(attrfrac(1.5, 0.4)),
    0.4 * 0.5 / (1 + 0.4 * 0.5)
  )
  expect_gt(attrfrac(1.5, 0.6), attrfrac(1.5, 0.3))
  expect_error(attrfrac(0, 1), "positive") # RR = 0 is not a relative risk
  expect_error(attrfrac(1.5, 1.2), "must be in")
  expect_error(attrfrac(c(1, 2), 0.5), "single")
})

test_that("mortdisp: BenMAP form, linear in N, small-beta limit", {
  expect_identical(mortdisp(0, 1e6, 0.008, 0.0039), 0)
  one <- mortdisp(10, 1e6, 0.008, 0.0039)
  expect_identical(one, 0.008 * 1e6 * (1 - exp(-0.039)))
  expect_identical(mortdisp(10, 2e6, 0.008, 0.0039), 2 * one)
  expect_equal(
    mortdisp(1, 1e6, 0.008, 1e-5),
    0.008 * 1e6 * 1e-5,
    tolerance = 1e-5
  )
  expect_error(mortdisp(1, -1, 0.008, 0.001), "non-negative")
  expect_error(mortdisp(1, 1, -0.008, 0.001), "non-negative")
})

test_that("polbrdn chains CRF -> PAF -> cases for both pollutants", {
  b <- polbrdn(25, 1, 0.008, 1e6, poll = "NO2")
  rr <- exp(log(1.02) * 1.5) # RR 1.02 per 10 ug/m3 above the 10 ug/m3 reference
  expect_identical(b$extra$rr, rr)
  expect_identical(b$paf, (rr - 1) / rr)
  expect_identical(b$basecases, 8000)
  expect_identical(b$attrcases, b$paf * 8000)
  expect_identical(b$refconc, 10)
  expect_s3_class(b, "rmbl_burden")
  expect_match(b$citation, "Rothman")
  p <- polbrdn(12, 0.9, 0.005, 5e5, poll = "PM2.5")
  expect_identical(p$extra$rr, crfpm25(12)$rr)
  expect_equal(p$refconc, 5.8)
  expect_identical(
    polbrdn(12, 1, 0.005, 5e5, poll = "PM2.5", refconc = 8)$extra$rr,
    crfpm25(12, refconc = 8)$rr
  )
  expect_identical(polbrdn(4, 1, 0.008, 1e6, poll = "PM2.5")$attrcases, 0)
  expect_error(polbrdn(4, 1, 0.008, 1e6, poll = "O3"), "Unknown pollutant")
})

test_that(
  paste0(
    "plrcf recovers a linear exposure effect and matches its own recipe ",
    "exactly"
  ),
  {
    set.seed(7)
    n <- 160
    d <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
    d$exposure <- 20 + 2 * d$x1 + rnorm(n)
    d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(n)
    r <- plrcf(d, "asthma", "exposure", c("x1", "x2"), kfol = 4L, seed = 3L)
    ols <- unname(stats::coef(stats::lm(asthma ~ exposure + x1 + x2, d))[
      "exposure"
    ])
    expect_lt(abs(r$ate - ols), 0.05)
    expect_lt(abs(r$ate - 0.3), 0.1)
    expect_equal(r$n, n, tolerance = testthat::testthat_tolerance())
    expect_identical(r$kfol, 4L)
    # the recipe, step by step, with the same fold draw
    folds <- .rmbl_with_seed(3L, sample(rep_len(1:4, n)))
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
    expect_equal(
      r$se,
      sqrt(sum(V^2 * (U - theta * V)^2)) / sum(V^2),
      tolerance = 1e-12
    )
    expect_error(plrcf(d, "asthma", "exposure", "nope"), "missing columns")
    expect_error(plrcf(d, "asthma", "exposure", "x1", kfol = 1), "at least 2")
    expect_error(
      plrcf(d[1:6, ], "asthma", "exposure", "x1", kfol = 5),
      "complete rows"
    )
    # a treatment that is a function of the covariates has nothing left to
    # identify
    d2 <- d
    d2$exposure <- d2$x1
    expect_error(plrcf(d2, "asthma", "exposure", "x1"), "no variation")
    # a collinear covariate is handled (its coefficient is dropped, not
    # NA-propagated)
    d3 <- d
    d3$x3 <- d3$x1
    expect_true(is.finite(
      plrcf(d3, "asthma", "exposure", c("x1", "x2", "x3"))$ate
    ))
  }
)

test_that(
  paste0(
    "exprspplr wraps the estimator with a percentile bootstrap and accepts ",
    "another"
  ),
  {
    set.seed(7)
    n <- 150
    d <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
    d$exposure <- 20 + 2 * d$x1 + rnorm(n)
    d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(n)
    r <- exprspplr(
      d,
      y = "asthma",
      expo = "exposure",
      confs = c("x1", "x2"),
      nboot = 15L
    )
    expect_identical(r$nboot, 15L)
    expect_lt(r$cilobs, r$ate)
    expect_lt(r$ate, r$ciupbs)
    ols <- unname(stats::coef(stats::lm(asthma ~ exposure + x1 + x2, d))[
      "exposure"
    ])
    expect_lt(abs(r$ate - ols), 0.05)
    expect_match(r$method, "bootstrap")
    # the same seed gives the same interval
    r2 <- exprspplr(d, "asthma", "exposure", c("x1", "x2"), nboot = 15L)
    expect_identical(r$cilobs, r2$cilobs)
    # a user estimator with the same interface is used for the base fit and the
    # resamples
    constant <- function(data, outcome, treatment, covariates) {
      list(ate = 0.25, se = 0.01)
    }
    c1 <- exprspplr(
      d,
      "asthma",
      "exposure",
      c("x1", "x2"),
      nboot = 12L,
      estr = constant
    )
    expect_equal(c1$ate, 0.25)
    expect_identical(c1$seboot, 0)
    expect_match(c1$method, "^exposure-response")
    # too few successful fits is an error, not a silent interval
    flaky <- function(data, outcome, treatment, covariates) stop("no")
    expect_error(
      exprspplr(
        d,
        "asthma",
        "exposure",
        c("x1", "x2"),
        nboot = 12L,
        estr = function(data, outcome, treatment, covariates) {
          same <- nrow(data) == n && identical(rownames(data), rownames(d))
          if (same) list(ate = 1, se = 1) else flaky()
        }
      ),
      "successful bootstrap fits"
    )
  }
)

test_that("expconcidx: zero, pro-poor, pro-rich; population covariance", {
  flat <- data.frame(exposure = rep(10, 20), income = 1:20)
  expect_identical(expconcidx(flat, "exposure", "income")$concidx, 0)
  poor <- data.frame(exposure = 30:11, income = 1:20)
  e <- expconcidx(poor, "exposure", "income")
  expect_lt(e$concidx, 0)
  R <- (seq_len(20) - 0.5) / 20
  h <- 30:11
  expect_identical(
    e$concidx,
    2 * (sum((h - mean(h)) * (R - mean(R))) / 20) / mean(h)
  )
  expect_match(e$interpretation, "Pro-poor")
  expect_identical(e$extra$n, 20L)
  expect_s3_class(e, "rmbl_equity")
  rich <- data.frame(exposure = 11:30, income = 1:20)
  expect_match(
    expconcidx(rich, "exposure", "income")$interpretation,
    "Pro-rich"
  )
  expect_match(expconcidx(flat, "exposure", "income")$interpretation, "evenly")
  expect_error(expconcidx(poor[1, ], "exposure", "income"), "at least 2")
  expect_error(
    expconcidx(
      data.frame(exposure = c(0, 0), income = 1:2),
      "exposure",
      "income"
    ),
    "zero"
  )
  expect_error(expconcidx(poor, "exposure", "wealth"), "missing columns")
  # missing rows are dropped before ranking
  withna <- rbind(poor, data.frame(exposure = NA, income = 21))
  expect_identical(expconcidx(withna, "exposure", "income")$concidx, e$concidx)
})

test_that("polbrdarea sorts worst first, keeps the names, rejects bad tables", {
  t <- data.frame(
    fsa = c("M5V", "M6H"),
    exposure = c(18, 28),
    population = c(60000, 40000),
    brate = 0.008,
    stringsAsFactors = FALSE
  )
  r <- polbrdarea(t)
  expect_identical(r$fsa, c("M6H", "M5V"))
  expect_identical(r$attrcases[1], polbrdn(28, 1, 0.008, 40000)$attrcases)
  expect_identical(r$rr[2], crfno2(18)$rr)
  expect_named(
    r,
    c(
      "fsa",
      "exposure",
      "population",
      "brate",
      "rr",
      "paf",
      "attrcases",
      "basecases"
    )
  )
  t2 <- data.frame(
    tract = c("a", "b"),
    pm = c(9, 14),
    pop = c(1000, 1000),
    rate = 0.01,
    stringsAsFactors = FALSE
  )
  r2 <- polbrdarea(
    t2,
    areacol = "tract",
    expcol = "pm",
    popcol = "pop",
    basratecol = "rate",
    poll = "PM2.5"
  )
  expect_identical(r2$tract, c("b", "a"))
  expect_error(polbrdarea(t[, 1:2]), "missing columns")
  expect_error(polbrdarea(t[0, ]), "no rows")
})

test_that(
  paste0(
    "vrfpol: ok, one reference, avoided deaths over the exposed share, ",
    "failures, CSVs, demo"
  ),
  {
    ok <- vrfpol("no2", expomean = 25, expoprev = 0.9)
    expect_identical(ok$status, "ok")
    expect_identical(attr(ok, "exitstat"), 0L)
    # the NO2 counterfactual, 10
    expect_identical(ok$pipeline$crf$rr, exp(log(1.02) * (25 - 10) / 10))
    expect_identical(
      as.numeric(ok$pipeline$paf),
      as.numeric(attrfrac(ok$pipeline$crf$rr, 0.9))
    )
    expect_identical(
      ok$pipeline$displaced$deadisp,
      500 / 1e5 * 1e6 * 0.9 * (1 - 1 / ok$pipeline$crf$rr)
    )
    expect_null(ok$pipeline$equity)
    # the burden uses the same reference concentration as the RR above it
    r <- vrfpol(
      "no2",
      expomean = 20,
      expoprev = 0.5,
      ref = 5.8,
      brate = 500,
      pop = 1e6
    )
    rr <- exp(log(1.02) * (20 - 5.8) / 10)
    paf <- 0.5 * (rr - 1) / (0.5 * (rr - 1) + 1)
    expect_equal(r$pipeline$burden$refconc, 5.8)
    expect_equal(
      r$pipeline$burden$attrcases,
      paf * 500 / 1e5 * 1e6,
      tolerance = 1e-9
    )
    expect_equal(
      r$pipeline$displaced$deadisp,
      500 / 1e5 * 1e6 * 0.5 * (1 - 1 / rr),
      tolerance = 1e-9
    )
    # exposure at or below the counterfactual floor is a zero result, not a
    # failed assumption
    low <- vrfpol("pm25", expomean = 2, expoprev = 0.5)
    expect_identical(low$status, "ok")
    expect_identical(attr(low, "exitstat"), 0L)
    expect_identical(low$pipeline$paf, 0)
    expect_identical(low$pipeline$burden$attrcases, 0)
    bad <- vrfpol("pm25", expomean = NA, expoprev = 0.5)
    expect_identical(bad$status, "assumption_failure")
    expect_identical(attr(bad, "exitstat"), 1L)
    expect_true(bad$pipeline$skipped)
    expect_identical(
      vrfpol("o3", expomean = 20, expoprev = 0.5)$status,
      "assumption_failure"
    )
    d <- tempfile()
    dir.create(d)
    on.exit(unlink(d, recursive = TRUE), add = TRUE)
    f <- file.path(d, "e.csv")
    utils::write.csv(
      data.frame(exposure = c(20, 30, 25), income = c(1, 3, 2)),
      f,
      row.names = FALSE
    )
    c <- vrfpol("no2", expcsv = f, reg = "Toronto", years = "2023")
    expect_identical(c$status, "ok")
    expect_false(is.null(c$pipeline$equity))
    expect_identical(c$inputs$expomean, 25)
    expect_identical(c$dsou, f)
    utils::write.csv(data.frame(x = 1), f, row.names = FALSE)
    expect_identical(attr(vrfpol("no2", expcsv = f), "exitstat"), 2L)
    expect_match(vrfpol("no2", expcsv = f)$error, "missing 'exposure'")
    expect_identical(
      attr(vrfpol("no2", expcsv = file.path(d, "none.csv")), "exitstat"),
      2L
    )
    writeLines(character(0), f)
    expect_match(vrfpol("no2", expcsv = f)$error, "is empty")
    writeLines("exposure", f)
    expect_match(vrfpol("no2", expcsv = f)$error, "is empty")
    # a NAPS pull: NO2 in ppb is converted at 1.88; another unit is refused
    utils::write.csv(
      data.frame(
        station_id = 1,
        value = c(5, 10),
        unit = "ppb",
        stringsAsFactors = FALSE
      ),
      f,
      row.names = FALSE
    )
    expect_message(
      {
        naps <- vrfpol("no2", expcsv = f, ref = 10)
      },
      "x 1.88"
    )
    # 5 and 10 ppb are 9.4 and 18.8 ug/m3; only the second is above the floor of
    # 10
    expect_identical(naps$inputs$expomean, 10 * 1.88)
    expect_equal(naps$inputs$expoprev, 0.5)
    writeLines(c("station_id,value,unit", "1,0.5,ppm"), f)
    expect_identical(vrfpol("no2", expcsv = f)$status, "error")
    utils::write.csv(
      data.frame(value = c(12, 14), unit = "ug/m3", stringsAsFactors = FALSE),
      f,
      row.names = FALSE
    )
    expect_identical(vrfpol("pm25", expcsv = f)$inputs$expomean, 13)
    demo <- vrfpol("pm25", demo = TRUE)
    expect_identical(demo$status, "ok")
    expect_identical(demo$dsou, "demo (synthetic)")
    expect_false(is.null(demo$pipeline$equity))
    demo2 <- vrfpol("no2", demo = TRUE)
    expect_identical(
      demo2$inputs$expomean,
      vrfpol("no2", demo = TRUE)$inputs$expomean
    )
    # the demo seed does not disturb the caller's RNG stream
    set.seed(11)
    a <- stats::runif(1)
    set.seed(11)
    invisible(vrfpol("no2", demo = TRUE))
    expect_identical(stats::runif(1), a)
  }
)

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
  expect_match(
    low,
    paste0(
      "\\[PASS\\] exposure finite and non-negative -- mean 2 is at or below ",
      "the counterfactual floor"
    )
  )
  expect_match(low, "attributable deaths:   0.0", fixed = TRUE)
  bad <- polrpttxt(vrfpol("pm25", expomean = Inf, expoprev = 0.5))
  expect_match(bad, "\\[FAIL\\] exposure finite and non-negative")
  expect_match(bad, "STATUS: assumption_failure")
  err <- polrpttxt(vrfpol("no2", expcsv = tempfile()))
  expect_match(err, "^ERROR: exposure CSV not found")
  plain <- polrpttxt(vrfpol("no2", expomean = 25, expoprev = 1))
  expect_false(grepl("Equity analysis", plain, fixed = TRUE))
})

test_that("pollution errors name the user's arguments", {
  expect_error(crfpm25(10, y = mean), "`y` must be data")
  expect_error(crfno2(10, y = mean), "`y` must be data")
  expect_error(polbrdn(30, 1, 0.008, 1e6, poll = mean), "`poll` must be data")
  expect_error(mortdisp(5, -1, 0.01, 0.001), "`pop` must be non-negative")
  expect_error(
    polbrdn(30, 1, 0.008, -1),
    "^polbrdn: `pop` must be non-negative"
  )
  expect_error(
    mortdisp(5, 1e6, 0.01, 0.001, rare = NA),
    "`rare` must be TRUE or FALSE"
  )
  expect_error(
    mortdisp(5, 1e6, 0.01, 0.001, hirate = "no"),
    "`hirate` must be TRUE or FALSE"
  )
})

test_that("polbrdarea() refuses a bad row in its own words", {
  t <- data.frame(
    fsa = c("A", "B"),
    exposure = c(10, -1),
    population = c(1000, 2000),
    brate = c(0.008, 0.008),
    stringsAsFactors = FALSE
  )
  expect_error(polbrdarea(t), "^polbrdarea: `expcol` must be non-negative")
  t$exposure <- c(10, 12)
  t$population <- c(1000, -5)
  expect_error(polbrdarea(t), "^polbrdarea: `popcol` must be non-negative")
  t$population <- c(1000, 2000)
  t$brate <- c(0.008, 800)
  expect_error(polbrdarea(t), "^polbrdarea: `basratecol` ")
  t$brate <- c(0.008, 0.008)
  expect_identical(nrow(polbrdarea(t)), 2L)
})

test_that("expconcidx() refuses an income with one value", {
  d <- data.frame(exposure = c(10, 20, 30), income = c(5, 5, 5))
  expect_error(
    expconcidx(d, "exposure", "income"),
    "^expconcidx: `income` must take at least two values"
  )
  d$income <- c(1, 1, 2)
  expect_true(is.finite(expconcidx(d, "exposure", "income")$concidx))
})

test_that("the pollution CSV reader refuses a directory by name", {
  d <- withr::local_tempdir()
  expect_error(.pollution_csv_bytes(d), "is a directory, not a file")
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

test_that("the pollution results print as boxes with their sources", {
  expect_box(
    crfpm25(12),
    "Concentration-response: PM2.5",
    c("Relative risk", "95% [", "Chen & Hoek", "4.9% higher")
  )
  expect_match(.pol_rr_reading(0.9, 3, 5)[1L], "lower")
  expect_match(.pol_rr_reading(NA_real_, 3, 5), "not defined")
  b <- polbrdn(25, 1, 0.008, 1e6, poll = "NO2")
  expect_box(
    b,
    "Burden of NO2",
    c("Attributable fraction", "deaths a year", "if the curve is causal")
  )
  e <- expconcidx(
    data.frame(exposure = c(30, 25, 20, 15, 10), income = 1:5),
    "exposure",
    "income"
  )
  expect_box(e, "Concentration index", c("-0.2000", "Wagstaff"))
  ok <- vrfpol("no2", demo = TRUE)
  out <- expect_box(
    ok,
    "Pollution report: NO2",
    c("Status", "Attributable fraction", "Assumption log", "PASS")
  )
  bad <- vrfpol("no2", expomean = 20, expoprev = 1, brate = 0.008, pop = 1e6)
  expect_box(
    bad,
    "Pollution report",
    c("assumption_failure", "FAIL", "skipped")
  )
  err <- .pollution_fail("no exposure")
  expect_box(err, "Pollution report: error", "no exposure")
  set.seed(1)
  d <- data.frame(x1 = stats::rnorm(120), x2 = stats::rnorm(120))
  d$exposure <- 20 + 2 * d$x1 + stats::rnorm(120)
  d$asthma <- 5 + 0.3 * d$exposure + d$x2 + stats::rnorm(120)
  r <- plrcf(d, "asthma", "exposure", c("x1", "x2"), kfol = 3L)
  expect_s3_class(r, c("rmbl_plr", "list"), exact = TRUE)
  expect_named(r, c("ate", "se", "n", "kfol", "method"))
  expect_box(r, "Partially linear exposure effect", c("Folds", "95% CI"))
  rb <- exprspplr(d, "asthma", "exposure", c("x1", "x2"), nboot = 12L)
  expect_s3_class(rb, c("rmbl_plr_boot", "list"), exact = TRUE)
  expect_box(rb, "percentile bootstrap", c("Resamples", "bootstrap sd"))
})

test_that("polbrdarea() results print as a box", {
  b <- polbrdarea(data.frame(
    fsa = c("A", "B"),
    exposure = c(20, 30),
    population = c(1e4, 2e4),
    brate = c(0.008, 0.009),
    stringsAsFactors = FALSE
  ))
  expect_s3_class(b, c("rmbl_burden_area", "data.frame"))
  expect_box2(
    b,
    "Pollution burden by area",
    c("Share attributable", "basecases")
  )
  expect_box2(b["fsa"], "Pollution burden by area", "plain table")
})

# ---- attrfrac() prints as a box and stays a number ---------------------------

test_that("attrfrac() returns a boxed measure that reads its sign", {
  paf <- attrfrac(1.08, 1, rrlo = 1.06, rrup = 1.09)
  expect_s3_class(paf, c("rmbl_attrfrac", "rmbl_measure", "numeric"))
  expect_equal(attr(paf, "ci")[["lower"]], 0.06 / 1.06, tolerance = 1e-12)
  expect_false(inherits(paf + 0, "rmbl_measure"))
  expect_box2(paf, "Population attributable fraction",
    c("7.41%", "Its interval stays above 0"))
  prot <- paste(format(attrfrac(0.8, 0.5)), collapse = " ")
  expect_match(prot, "The exposure is protective", fixed = TRUE)
  expect_match(.rmbl_paf_reading(0.01, c(lower = -0.01, upper = 0.03))[2L],
    "includes 0", fixed = TRUE)
})

test_that("an attributable fraction without its record formats plainly", {
  expect_plain_measure("rmbl_attrfrac", 0.25)
})

test_that("a log RR without its interval; an unknown check reads n/a", {
  # a record read back from JSON loses an NA interval (null): the log RR is
  # shown alone
  r <- crfno2(30, betaper10 = log(1.04))
  r$extra$betaper10ci <- NULL
  txt <- box_text(r)
  lr <- regmatches(txt, regexpr("Log RR per 10 ug/m3 [^ ]+ [^ ]+", txt))
  expect_match(lr, paste0("^Log RR per 10 ug/m3 ",
    .rmbl_fmt_num(log(1.04))), fixed = FALSE)
  expect_false(grepl("95%", lr, fixed = TRUE))
  a <- .pol_assumption_lines(list(
    list(ok = TRUE, assumption = "x", note = "fine"),
    list(ok = NA, assumption = "y", note = "not run")
  ))
  expect_identical(a, c("PASS x -- fine", "n/a  y -- not run"))
})
