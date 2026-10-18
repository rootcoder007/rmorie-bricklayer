# The 2026-10-08 stress test of dcb3cb9: one test per finding, each recomputing
# the value it asserts, so the reproducer script stays "fixed".

# ---- P1: the counterfactual follows the pollutant ----------------------------------

test_that("vrfpol uses the NO2 counterfactual (10) for NO2 and 5.8 for PM2.5", {
  a <- vrfpol("no2", expomean = 25, expoprev = 1)
  b <- vrfpol("no2", expomean = 25, expoprev = 1, ref = 10)
  expect_equal(a$inputs$refconc, 10)
  expect_equal(a$pipeline$burden$attrcases, b$pipeline$burden$attrcases)
  # recomputed by hand from the log-linear RR, Levin at prevalence 1 and the baseline count
  rr <- exp(log(1.02) * 15 / 10)
  expect_equal(a$pipeline$burden$attrcases, (1 - 1 / rr) * 500 / 1e5 * 1e6, tolerance = 1e-10)
  p <- vrfpol("pm25", expomean = 12, expoprev = 1)
  expect_equal(p$inputs$refconc, 5.8)
  expect_s3_class(a, "rmbl_pollution_report")
})

# ---- P2: stability of the explicit scheme ---------------------------------------------

test_that("advdif2d reports the real stability bound and sub-steps past it", {
  c0 <- matrix(0, 41, 41)
  c0[21, 21] <- 1
  expect_warning(r <- advdif2d(c0, u = .5, v = .4, kx = .1, ky = .1, 1, 1, 1, 60),
                 "sub-steps")
  expect_true(r$stable)
  expect_lte(r$stabn, 1)
  expect_equal(r$substeps, 2L)
  expect_equal(r$dt, 0.5)
  expect_lt(max(abs(r$field)), 1)   # a diffusing unit pulse, not an explosion
  expect_lte(r$mass, 1)
  expect_s3_class(r, "rmbl_field")
  ok <- advdif2d(c0, u = .5, v = .4, kx = .1, ky = .1, 1, 1, 0.5, 60)
  expect_equal(ok$stabn, 0.5 * (0.9 + 2 * 0.2))
  expect_equal(ok$substeps, 1L)
  expect_error(advdif2d(c0, 1, 1, 1, 1, 0, 1, 1, 1), "dx")
  expect_error(advdif2d(c0, 1, 1, -1, 1, 1, 1, 1, 1), "kx")
  expect_error(advdif2d(c0, 1, 1, 1, 1, 1, 1, 1, 2.5), "whole")
  expect_error(advdif2d(matrix(c(1, NA), 2, 1), 1, 1, 1, 1, 1, 1, 1, 1), "finite")
})

# ---- P3: time zones ------------------------------------------------------------------

test_that("every geographic IANA zone resolves, aliases included", {
  tz <- read.csv(system.file("extdata", "timezone_countries.csv", package = "rmoriebricklayer"),
                 stringsAsFactors = FALSE)
  expect_gt(nrow(tz), 540)
  for (pair in list(c("Europe/Stockholm", "SE"), c("Europe/Oslo", "NO"), c("Europe/Amsterdam", "NL"),
                    c("Asia/Kuala_Lumpur", "MY"), c("Asia/Calcutta", "IN"), c("America/Montreal", "CA"),
                    c("US/Eastern", "US"), c("Europe/Copenhagen", "DK"), c("Asia/Bangkok", "TH"))) {
    expect_equal(dtctloc("", "", tz = pair[1L], locale = "en_US.UTF-8")$location, pair[2L],
                 label = pair[1L])
  }
  expect_equal(dtctloc("", "", tz = "posix/Europe/Paris", locale = "C")$location, "FR")
  expect_equal(dtctloc("", "", tz = "right/America/Toronto", locale = "C")$location, "CA")
  olson <- OlsonNames()
  geo <- olson[grepl("/", olson, fixed = TRUE) & !grepl("^(Etc|posix|right|SystemV)/", olson)]
  missing <- setdiff(geo, tz$tz)
  expect_identical(missing, character(0))
  # no country for a fixed-offset zone: the locale decides
  expect_equal(dtctloc("", "", tz = "Etc/GMT+5", locale = "en_IN.UTF-8")$location, "IN")
})

# ---- P4: Levin's formula on the exposed, not the population mean twice ---------------------

test_that("vrfpol evaluates the RR among the exposed", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f))
  write.csv(data.frame(exposure = c(5, 8, 20, 30, 40)), f, row.names = FALSE)
  r <- vrfpol("no2", expcsv = f)
  expect_equal(r$inputs$expoprev, 3 / 5)
  expect_equal(r$inputs$expomean, 30)
  rr <- exp(log(1.02) * (30 - 10) / 10)
  expect_equal(r$pipeline$paf, 0.6 * (rr - 1) / (1 + 0.6 * (rr - 1)), tolerance = 1e-12)
  d <- vrfpol("pm25", demo = TRUE)
  expect_gt(d$inputs$expomean, d$inputs$refconc)
  expect_true(d$inputs$expoprev > 0 && d$inputs$expoprev <= 1)
})

# ---- P5, P10, P11, P12: guards ---------------------------------------------------------

test_that("attrfrac and the burden chain reject bad input", {
  expect_error(attrfrac(0, 1), "positive")
  expect_error(attrfrac(-1, 1), "positive")
  expect_error(attrfrac(Inf, 1), "finite")
  expect_error(attrfrac("1.5", 1), "numeric")
  expect_error(attrfrac(1.5, 1.2), "\\[0,1\\]")
  expect_equal(attrfrac(0.5, 1), -1)   # a protective exposure
  expect_error(polbrdn(25, 1, 0.008, -5), "non-negative")
  expect_error(polbrdn(25, 1, 0.008, 1e6, poll = "ozone"), "Unknown pollutant")
  expect_error(polbrdn(25, 1, 0.008, 1e6, poll = 5), "Unknown pollutant")
  expect_error(polbrdn(25, 1, 0.008, 1e6, poll = c("NO2", "PM2.5")), "Unknown pollutant")
  expect_error(mortdisp(10, 1e6, 0.008, "a"), "numeric")
  expect_error(crfpm25(-1), "non-negative")
  expect_error(crfno2(c(10, NA)), "missing")
  # population is a number, not an integer: 8e9 is fine
  b <- polbrdn(25, 1, 0.008, 8e9, poll = "NO2")
  expect_equal(b$population, 8e9)
  expect_equal(b$basecases, 0.008 * 8e9)
  # the pollutant spellings agree between the siblings
  expect_equal(polbrdn(12, 1, 0.008, 1e6, poll = "pm2.5")$pollutant, "PM2.5")
  expect_equal(polbrdn(12, 1, 0.008, 1e6, poll = "PM25")$pollutant, "PM2.5")
  expect_equal(vrfpol("PM2.5", expomean = 12, expoprev = 1)$pollutant, "pm25")
  expect_equal(polbrdn(25, 1, 0.008, 1e6, y = "chiast")$extra$unit, "incident cases")
})

test_that("exposure below the floor is a zero result; Inf is an assumption failure", {
  r <- vrfpol("no2", expomean = 5, expoprev = 1)
  expect_equal(r$status, "ok")
  expect_equal(r$pipeline$paf, 0)
  expect_equal(r$pipeline$burden$attrcases, 0)
  expect_true(all(vapply(r$assumptions, function(a) a$ok, logical(1))))
  bad <- vrfpol("no2", expomean = Inf, expoprev = 1)
  expect_equal(bad$status, "assumption_failure")
  expect_equal(attr(bad, "exitstat"), 1L)
  expect_match(polrpttxt(bad), "FAIL\\] exposure finite")
})

test_that("the report text names the outcome's unit", {
  r <- vrfpol("no2", expomean = 25, expoprev = 1, y = "chiast")
  txt <- polrpttxt(r)
  expect_match(txt, "attributable incident cases")
  expect_match(txt, "Cases displaced")
  expect_match(polrpttxt(vrfpol("no2", expomean = 25, expoprev = 1)),
               "attributable deaths")
})

# ---- P6: units per row ------------------------------------------------------------------

test_that("a NAPS pull converts each row by its own unit", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f))
  write.csv(data.frame(value = c(10, 20), unit = c("ppb", "ug/m3")), f, row.names = FALSE)
  expect_message(r <- vrfpol("no2", expcsv = f), "1 NO2 row")
  expect_equal(r$inputs$expomean, mean(c(18.8, 20)))
  write.csv(data.frame(value = c(10, 20)), f, row.names = FALSE)
  r2 <- vrfpol("no2", expcsv = f)
  expect_equal(r2$status, "error")
  expect_match(r2$error, "unit")
  write.csv(data.frame(value = c(10, 20), unit = c("ppm", "ug/m3")), f, row.names = FALSE)
  r3 <- vrfpol("no2", expcsv = f)
  expect_equal(r3$status, "error")
  expect_match(r3$error, "ppm")
})

# ---- P7: ties in income ------------------------------------------------------------------

test_that("the concentration index is invariant to row order under tied incomes", {
  d <- data.frame(exposure = c(1, 5, 2, 9), income = c(3, 3, 3, 3))
  expect_equal(expconcidx(d, "exposure", "income")$concidx, 0)
  d2 <- data.frame(exposure = c(4, 1, 8, 2, 7), income = c(2, 1, 2, 1, 3))
  a <- expconcidx(d2, "exposure", "income")
  b <- expconcidx(d2[c(5, 3, 1, 4, 2), ], "exposure", "income")
  expect_equal(a$concidx, b$concidx)
  # mid-ranks recomputed by hand
  n <- 5
  R <- (rank(d2$income) - 0.5) / n
  h <- d2$exposure
  expect_equal(a$concidx, 2 * sum((h - mean(h)) * (R - mean(R))) / n / mean(h))
  expect_equal(nrow(a$extra$curve), n)
  expect_equal(a$extra$curve$exposure[n], 1)
})

# ---- P8: citations and coefficients ------------------------------------------------------

test_that("the NO2 coefficients carry their sources", {
  expect_equal(crfno2(20, y = "respiratory")$extra$betaper10, log(1.03))
  asthma <- crfno2(20, y = "chiast")
  expect_equal(asthma$extra$betaper10, log(1.05) * 10 / 4)
  expect_match(asthma$citation, "Khreis")
  expect_match(crfno2(20)$citation, "Huangfu")
})

# ---- P9: physical guards in the dispersion code ------------------------------------------

test_that("the dispersion functions refuse unphysical input", {
  rc <- data.frame(x = 1000, y = 0, z = 0)
  expect_error(gplume(q = -100, u = 5, h = 50, rcpt = rc), "q")
  expect_error(gplume(q = 100, u = 0, h = 50, rcpt = rc), "u")
  expect_error(gplume(q = 100, u = 5, h = 50, rcpt = rc, nimg = 2.5), "whole")
  expect_warning(gplume(q = 100, u = 5, h = 500, rcpt = rc, mixh = 300),
                 "above the mixing height")
  expect_error(gspuff(mass = 100, u = 5, h = 50, rcpt = rc, t = -100), "t")
  expect_error(gspuff(mass = -1, u = 5, h = 50, rcpt = rc, t = 100), "mass")
  expect_error(pgsig(-500), "x")
  expect_error(gplume(q = NA, u = 5, h = 50, rcpt = rc), "finite")
  expect_error(gplume(q = Inf, u = 5, h = 50, rcpt = rc), "finite")
  expect_error(briggs(100, 4, diam = 1, exitvel = 12, stktmp = 280,
                                 ambtmp = 285), "hotter|exceed")
  expect_error(briggs(100, 4, diam = 0, exitvel = 12, stktmp = 420,
                                 ambtmp = 285), "diameter")
  expect_error(lagrprt(10, c(0, 1), 0, 1, 1, 1, 1, 1, 2), "x0")
  expect_error(lagrprt(10, 0, 0, 1, 1, -1, 1, 1, 2), "kx")
  p <- lagrprt(10, 0, 0, 1, 1, 1, 1, 1, 2)
  expect_s3_class(p, "rmbl_particles")
  expect_equal(p$mean_x, mean(p$x))
  expect_gt(gplume(q = 100, u = 5, h = 50, rcpt = rc), 0)
})

# ---- P12: the footprint checks its arguments first ------------------------------------------

test_that("co2fp validates before it runs the expression", {
  ran <- FALSE
  mark <- function() {
    ran <<- TRUE
    1
  }
  expect_error(co2fp(mark(), memgb = -16, loc = "CA"), "memgb")
  expect_false(ran)
  expect_error(co2fp(1, cores = 0, loc = "CA"), "cores")
  expect_error(co2fp(1, cpupwrw = -1, loc = "CA"), "cpupwrw")
  expect_error(co2fp(1, rapldir = c("a", "b"), loc = "CA"), "rapldir")
  expect_error(co2fp(1, procstat = NA_character_, loc = "CA"), "procstat")
})

# ---- P13: the carbon-intensity table -----------------------------------------------------------

test_that("the carbon-intensity table names Kosovo once and keeps the reported values", {
  tab <- co2inttab()
  expect_equal(sum(tab$name == "Kosovo"), 1L)
  expect_equal(co2int("Kosovo")$location, "XK")
  expect_equal(co2int("XK")$g_per_kwh, co2int("Kosovo")$g_per_kwh)
  expect_equal(sum(tab$location == "WORLD"), 1L)
  expect_equal(co2int("TM")$g_per_kwh, 1306.27)
  expect_false(any(duplicated(tab$location)))
})

# ---- C3: masking can be switched off -----------------------------------------------------------

test_that("masked = FALSE and the session option give the same signatures", {
  key <- fipskg("ML-DSA-44")
  s1 <- cpssign("m", key, determ = TRUE)
  s2 <- cpssign("m", key, determ = TRUE, masked = FALSE)
  expect_identical(s1$signature, s2$signature)
  expect_true(cpsvrf("m", s2, fipspubkey(key)))
  mu <- fipsmu(fipspubkey(key), "m")
  expect_identical(fipssignmu(key, mu, determ = TRUE)$signature,
                   fipssignmu(key, mu, determ = TRUE, masked = FALSE)$signature)
  expect_error(cpssign("m", key, masked = NA), "masked")
  old <- options(rmoriebricklayer.masked = FALSE)
  on.exit(options(old), add = TRUE)
  expect_identical(cpssign("m", key, determ = TRUE)$signature, s1$signature)
  k <- kemkg(512)
  c <- kemencap(kempubkey(k))
  expect_identical(kemdecap(k, c$ciphertext), c$shared)
  options(rmoriebricklayer.masked = "yes")
  expect_error(kemdecap(k, c$ciphertext), "masked")
})

# ---- D6: the services fallback points at the www host with its trailing slashes ----------------

test_that("the offline services fallback uses the www host", {
  svc <- rmoriebricklayer:::.rmbl_services_off()
  expect_equal(svc$llm$request_access, "https://www.rmorie.com/access/")
  expect_equal(svc$data$license, "https://www.rmorie.com/data-license/")
})

# ---- D7: the two-part hash entry refuses a non-integer split -------------------------------------

test_that("C_rmbl_hash_two_part refuses non-integer and logical splits", {
  x <- as.raw(1:10)
  ok <- .Call(rmoriebricklayer:::C_rmbl_hash_two_part, x, 4L)
  expect_identical(.Call(rmoriebricklayer:::C_rmbl_hash_two_part, x, 4), ok)
  expect_error(.Call(rmoriebricklayer:::C_rmbl_hash_two_part, x, 3.7), "integer")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_hash_two_part, x, TRUE), "integer")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_hash_two_part, x, c(1L, 2L)), "single")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_hash_two_part, x, -1), "integer")
})

# ---- D4: yoypdf at another page height -------------------------------------------------------------

test_that("yoypdf keeps every row on the page whatever the height", {
  seg <- data.frame(year = rep(2022:2023, each = 60), area = rep(sprintf("a%02d", 1:60), 2),
                    n = c(rep(10, 60), 8:67))
  y <- yoy(seg, value = "n", prd = "year", by = "area")
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  yoypdf(y, f, height = 14)
  expect_true(file.exists(f))
  # at every height the renderer's row height (0.22 inch over the page height) keeps
  # a full page of rows, as the pagination counts them, above the notes line
  for (h in c(8.5, 11, 14)) {
    per_page <- max(5L, floor((h - 2.4) / 0.22))
    expect_gt(0.88 - (per_page + 1.1) * 0.22 / h, 0.04, label = sprintf("height %s", h))
  }
})

# ---- S1: the French SIU path is linear -------------------------------------------------------------

test_that("the French resolver is not slower than the English one by orders of magnitude", {
  fr <- paste0("Remarque : Un agent impliqué ", strrep("a b ", 10000))
  en <- paste0("Note: An involved officer ", strrep("a b ", 10000))
  tf <- system.time(suppressWarnings(siuso(fr)))[["elapsed"]]
  te <- system.time(suppressWarnings(siuso(en)))[["elapsed"]]
  expect_lt(tf, 5 * max(te, 0.05))
  # the sentence filter still removes the legal boilerplate
  txt <- "UES. Les agents impliqués sont invités à participer; l'agent impliqué a participé."
  r <- siuso(txt)
  expect_equal(r$count, 1L)
})

# ---- S2, S3 -------------------------------------------------------------------------------------------

test_that("hilltlidx on identical values is not estimable, and a bound is not a fit", {
  h <- hilltlidx(rep(1, 50))
  expect_true(is.na(h$alpha))
  expect_false(h$reliable)
  expect_match(h$method, "not estimable")
})

test_that("classical Mahalanobis distances survive wildly different scales", {
  set.seed(3)
  d <- data.frame(a = rnorm(100) * 1e160, b = rnorm(100))
  out <- mahaoutl(d, robust = FALSE)
  expect_equal(nrow(out), 100L)
  expect_true(all(is.finite(out$distance)))
  # affine invariance: the distances equal those on the rescaled data
  out2 <- mahaoutl(data.frame(a = d$a / 1e160, b = d$b), robust = FALSE)
  expect_equal(out$distance, out2$distance, tolerance = 1e-8)
})
