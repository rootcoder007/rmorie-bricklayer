# The 2026-10-08 stress test of dcb3cb9: one test per finding, each recomputing
# the value it asserts, so the reproducer script stays "fixed".

# ---- P1: the counterfactual follows the pollutant ----------------------------------

test_that("verify_pollution uses the NO2 counterfactual (10) for NO2 and 5.8 for PM2.5", {
  a <- verify_pollution("no2", exposure_mean = 25, exposure_prevalence = 1)
  b <- verify_pollution("no2", exposure_mean = 25, exposure_prevalence = 1, reference = 10)
  expect_equal(a$inputs$reference_conc, 10)
  expect_equal(a$pipeline$burden$attributable_cases, b$pipeline$burden$attributable_cases)
  # recomputed by hand from the log-linear RR, Levin at prevalence 1 and the baseline count
  rr <- exp(log(1.02) * 15 / 10)
  expect_equal(a$pipeline$burden$attributable_cases, (1 - 1 / rr) * 500 / 1e5 * 1e6, tolerance = 1e-10)
  p <- verify_pollution("pm25", exposure_mean = 12, exposure_prevalence = 1)
  expect_equal(p$inputs$reference_conc, 5.8)
  expect_s3_class(a, "rmbl_pollution_report")
})

# ---- P2: stability of the explicit scheme ---------------------------------------------

test_that("advection_diffusion_2d reports the real stability bound and sub-steps past it", {
  c0 <- matrix(0, 41, 41)
  c0[21, 21] <- 1
  expect_warning(r <- advection_diffusion_2d(c0, u = .5, v = .4, kx = .1, ky = .1, 1, 1, 1, 60),
                 "sub-steps")
  expect_true(r$stable)
  expect_lte(r$stability_number, 1)
  expect_equal(r$substeps, 2L)
  expect_equal(r$dt, 0.5)
  expect_lt(max(abs(r$field)), 1)   # a diffusing unit pulse, not an explosion
  expect_lte(r$mass, 1)
  expect_s3_class(r, "rmbl_field")
  ok <- advection_diffusion_2d(c0, u = .5, v = .4, kx = .1, ky = .1, 1, 1, 0.5, 60)
  expect_equal(ok$stability_number, 0.5 * (0.9 + 2 * 0.2))
  expect_equal(ok$substeps, 1L)
  expect_error(advection_diffusion_2d(c0, 1, 1, 1, 1, 0, 1, 1, 1), "dx")
  expect_error(advection_diffusion_2d(c0, 1, 1, -1, 1, 1, 1, 1, 1), "kx")
  expect_error(advection_diffusion_2d(c0, 1, 1, 1, 1, 1, 1, 1, 2.5), "whole")
  expect_error(advection_diffusion_2d(matrix(c(1, NA), 2, 1), 1, 1, 1, 1, 1, 1, 1, 1), "finite")
})

# ---- P3: time zones ------------------------------------------------------------------

test_that("every geographic IANA zone resolves, aliases included", {
  tz <- read.csv(system.file("extdata", "timezone_countries.csv", package = "rmoriebricklayer"),
                 stringsAsFactors = FALSE)
  expect_gt(nrow(tz), 540)
  for (pair in list(c("Europe/Stockholm", "SE"), c("Europe/Oslo", "NO"), c("Europe/Amsterdam", "NL"),
                    c("Asia/Kuala_Lumpur", "MY"), c("Asia/Calcutta", "IN"), c("America/Montreal", "CA"),
                    c("US/Eastern", "US"), c("Europe/Copenhagen", "DK"), c("Asia/Bangkok", "TH"))) {
    expect_equal(detect_location("", "", tz = pair[1L], locale = "en_US.UTF-8")$location, pair[2L],
                 label = pair[1L])
  }
  expect_equal(detect_location("", "", tz = "posix/Europe/Paris", locale = "C")$location, "FR")
  expect_equal(detect_location("", "", tz = "right/America/Toronto", locale = "C")$location, "CA")
  olson <- OlsonNames()
  geo <- olson[grepl("/", olson, fixed = TRUE) & !grepl("^(Etc|posix|right|SystemV)/", olson)]
  missing <- setdiff(geo, tz$tz)
  expect_identical(missing, character(0))
  # no country for a fixed-offset zone: the locale decides
  expect_equal(detect_location("", "", tz = "Etc/GMT+5", locale = "en_IN.UTF-8")$location, "IN")
})

# ---- P4: Levin's formula on the exposed, not the population mean twice ---------------------

test_that("verify_pollution evaluates the RR among the exposed", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f))
  write.csv(data.frame(exposure = c(5, 8, 20, 30, 40)), f, row.names = FALSE)
  r <- verify_pollution("no2", exposure_csv = f)
  expect_equal(r$inputs$exposure_prevalence, 3 / 5)
  expect_equal(r$inputs$exposure_mean, 30)
  rr <- exp(log(1.02) * (30 - 10) / 10)
  expect_equal(r$pipeline$paf, 0.6 * (rr - 1) / (1 + 0.6 * (rr - 1)), tolerance = 1e-12)
  d <- verify_pollution("pm25", demo = TRUE)
  expect_gt(d$inputs$exposure_mean, d$inputs$reference_conc)
  expect_true(d$inputs$exposure_prevalence > 0 && d$inputs$exposure_prevalence <= 1)
})

# ---- P5, P10, P11, P12: guards ---------------------------------------------------------

test_that("attributable_fraction and the burden chain reject bad input", {
  expect_error(attributable_fraction(0, 1), "positive")
  expect_error(attributable_fraction(-1, 1), "positive")
  expect_error(attributable_fraction(Inf, 1), "finite")
  expect_error(attributable_fraction("1.5", 1), "numeric")
  expect_error(attributable_fraction(1.5, 1.2), "\\[0,1\\]")
  expect_equal(attributable_fraction(0.5, 1), -1)   # a protective exposure
  expect_error(pollution_burden(25, 1, 0.008, -5), "non-negative")
  expect_error(pollution_burden(25, 1, 0.008, 1e6, pollutant = "ozone"), "Unknown pollutant")
  expect_error(pollution_burden(25, 1, 0.008, 1e6, pollutant = 5), "Unknown pollutant")
  expect_error(pollution_burden(25, 1, 0.008, 1e6, pollutant = c("NO2", "PM2.5")), "Unknown pollutant")
  expect_error(mortality_displaced(10, 1e6, 0.008, "a"), "numeric")
  expect_error(crf_pm25(-1), "non-negative")
  expect_error(crf_no2(c(10, NA)), "missing")
  # population is a number, not an integer: 8e9 is fine
  b <- pollution_burden(25, 1, 0.008, 8e9, pollutant = "NO2")
  expect_equal(b$population, 8e9)
  expect_equal(b$baseline_cases, 0.008 * 8e9)
  # the pollutant spellings agree between the siblings
  expect_equal(pollution_burden(12, 1, 0.008, 1e6, pollutant = "pm2.5")$pollutant, "PM2.5")
  expect_equal(pollution_burden(12, 1, 0.008, 1e6, pollutant = "PM25")$pollutant, "PM2.5")
  expect_equal(verify_pollution("PM2.5", exposure_mean = 12, exposure_prevalence = 1)$pollutant, "pm25")
  expect_equal(pollution_burden(25, 1, 0.008, 1e6, outcome = "childhood_asthma")$extra$unit, "incident cases")
})

test_that("exposure below the floor is a zero result; Inf is an assumption failure", {
  r <- verify_pollution("no2", exposure_mean = 5, exposure_prevalence = 1)
  expect_equal(r$status, "ok")
  expect_equal(r$pipeline$paf, 0)
  expect_equal(r$pipeline$burden$attributable_cases, 0)
  expect_true(all(vapply(r$assumptions, function(a) a$ok, logical(1))))
  bad <- verify_pollution("no2", exposure_mean = Inf, exposure_prevalence = 1)
  expect_equal(bad$status, "assumption_failure")
  expect_equal(attr(bad, "exit_status"), 1L)
  expect_match(pollution_report_text(bad), "FAIL\\] exposure finite")
})

test_that("the report text names the outcome's unit", {
  r <- verify_pollution("no2", exposure_mean = 25, exposure_prevalence = 1, outcome = "childhood_asthma")
  txt <- pollution_report_text(r)
  expect_match(txt, "attributable incident cases")
  expect_match(txt, "Cases displaced")
  expect_match(pollution_report_text(verify_pollution("no2", exposure_mean = 25, exposure_prevalence = 1)),
               "attributable deaths")
})

# ---- P6: units per row ------------------------------------------------------------------

test_that("a NAPS pull converts each row by its own unit", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f))
  write.csv(data.frame(value = c(10, 20), unit = c("ppb", "ug/m3")), f, row.names = FALSE)
  expect_message(r <- verify_pollution("no2", exposure_csv = f), "1 NO2 row")
  expect_equal(r$inputs$exposure_mean, mean(c(18.8, 20)))
  write.csv(data.frame(value = c(10, 20)), f, row.names = FALSE)
  r2 <- verify_pollution("no2", exposure_csv = f)
  expect_equal(r2$status, "error")
  expect_match(r2$error, "unit")
  write.csv(data.frame(value = c(10, 20), unit = c("ppm", "ug/m3")), f, row.names = FALSE)
  r3 <- verify_pollution("no2", exposure_csv = f)
  expect_equal(r3$status, "error")
  expect_match(r3$error, "ppm")
})

# ---- P7: ties in income ------------------------------------------------------------------

test_that("the concentration index is invariant to row order under tied incomes", {
  d <- data.frame(exposure = c(1, 5, 2, 9), income = c(3, 3, 3, 3))
  expect_equal(exposure_concentration_index(d, "exposure", "income")$concentration_index, 0)
  d2 <- data.frame(exposure = c(4, 1, 8, 2, 7), income = c(2, 1, 2, 1, 3))
  a <- exposure_concentration_index(d2, "exposure", "income")
  b <- exposure_concentration_index(d2[c(5, 3, 1, 4, 2), ], "exposure", "income")
  expect_equal(a$concentration_index, b$concentration_index)
  # mid-ranks recomputed by hand
  n <- 5
  R <- (rank(d2$income) - 0.5) / n
  h <- d2$exposure
  expect_equal(a$concentration_index, 2 * sum((h - mean(h)) * (R - mean(R))) / n / mean(h))
  expect_equal(nrow(a$extra$curve), n)
  expect_equal(a$extra$curve$exposure[n], 1)
})

# ---- P8: citations and coefficients ------------------------------------------------------

test_that("the NO2 coefficients carry their sources", {
  expect_equal(crf_no2(20, outcome = "respiratory")$extra$beta_per_10, log(1.03))
  asthma <- crf_no2(20, outcome = "childhood_asthma")
  expect_equal(asthma$extra$beta_per_10, log(1.05) * 10 / 4)
  expect_match(asthma$citation, "Khreis")
  expect_match(crf_no2(20)$citation, "Huangfu")
})

# ---- P9: physical guards in the dispersion code ------------------------------------------

test_that("the dispersion functions refuse unphysical input", {
  rc <- data.frame(x = 1000, y = 0, z = 0)
  expect_error(gaussian_plume(q = -100, u = 5, h = 50, receptors = rc), "q")
  expect_error(gaussian_plume(q = 100, u = 0, h = 50, receptors = rc), "u")
  expect_error(gaussian_plume(q = 100, u = 5, h = 50, receptors = rc, n_images = 2.5), "whole")
  expect_warning(gaussian_plume(q = 100, u = 5, h = 500, receptors = rc, mixing_height = 300),
                 "above the mixing height")
  expect_error(gaussian_puff(mass = 100, u = 5, h = 50, receptors = rc, t = -100), "t")
  expect_error(gaussian_puff(mass = -1, u = 5, h = 50, receptors = rc, t = 100), "mass")
  expect_error(pg_sigmas(-500), "x")
  expect_error(gaussian_plume(q = NA, u = 5, h = 50, receptors = rc), "finite")
  expect_error(gaussian_plume(q = Inf, u = 5, h = 50, receptors = rc), "finite")
  expect_error(briggs_plume_rise(100, 4, diameter = 1, exit_velocity = 12, stack_temp = 280,
                                 ambient_temp = 285), "hotter|exceed")
  expect_error(briggs_plume_rise(100, 4, diameter = 0, exit_velocity = 12, stack_temp = 420,
                                 ambient_temp = 285), "diameter")
  expect_error(lagrangian_particles(10, c(0, 1), 0, 1, 1, 1, 1, 1, 2), "x0")
  expect_error(lagrangian_particles(10, 0, 0, 1, 1, -1, 1, 1, 2), "kx")
  p <- lagrangian_particles(10, 0, 0, 1, 1, 1, 1, 1, 2)
  expect_s3_class(p, "rmbl_particles")
  expect_equal(p$mean_x, mean(p$x))
  expect_gt(gaussian_plume(q = 100, u = 5, h = 50, receptors = rc), 0)
})

# ---- P12: the footprint checks its arguments first ------------------------------------------

test_that("compute_footprint validates before it runs the expression", {
  ran <- FALSE
  mark <- function() {
    ran <<- TRUE
    1
  }
  expect_error(compute_footprint(mark(), memory_gb = -16, location = "CA"), "memory_gb")
  expect_false(ran)
  expect_error(compute_footprint(1, cores = 0, location = "CA"), "cores")
  expect_error(compute_footprint(1, cpu_power_w = -1, location = "CA"), "cpu_power_w")
  expect_error(compute_footprint(1, rapl_dir = c("a", "b"), location = "CA"), "rapl_dir")
  expect_error(compute_footprint(1, proc_stat = NA_character_, location = "CA"), "proc_stat")
})

# ---- P13: the carbon-intensity table -----------------------------------------------------------

test_that("the carbon-intensity table names Kosovo once and keeps the reported values", {
  tab <- carbon_intensity_table()
  expect_equal(sum(tab$name == "Kosovo"), 1L)
  expect_equal(carbon_intensity("Kosovo")$location, "XK")
  expect_equal(carbon_intensity("XK")$g_per_kwh, carbon_intensity("Kosovo")$g_per_kwh)
  expect_equal(sum(tab$location == "WORLD"), 1L)
  expect_equal(carbon_intensity("TM")$g_per_kwh, 1306.27)
  expect_false(any(duplicated(tab$location)))
})

# ---- C3: masking can be switched off -----------------------------------------------------------

test_that("masked = FALSE and the session option give the same signatures", {
  key <- fips_keygen("ML-DSA-44")
  s1 <- capsule_sign("m", key, deterministic = TRUE)
  s2 <- capsule_sign("m", key, deterministic = TRUE, masked = FALSE)
  expect_identical(s1$signature, s2$signature)
  expect_true(capsule_verify("m", s2, fips_public_key(key)))
  mu <- fips_mu(fips_public_key(key), "m")
  expect_identical(fips_sign_mu(key, mu, deterministic = TRUE)$signature,
                   fips_sign_mu(key, mu, deterministic = TRUE, masked = FALSE)$signature)
  expect_error(capsule_sign("m", key, masked = NA), "masked")
  old <- options(rmoriebricklayer.masked = FALSE)
  on.exit(options(old), add = TRUE)
  expect_identical(capsule_sign("m", key, deterministic = TRUE)$signature, s1$signature)
  k <- kem_keygen(512)
  c <- kem_encapsulate(kem_public_key(k))
  expect_identical(kem_decapsulate(k, c$ciphertext), c$shared)
  options(rmoriebricklayer.masked = "yes")
  expect_error(kem_decapsulate(k, c$ciphertext), "masked")
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

# ---- D4: yoy_pdf at another page height -------------------------------------------------------------

test_that("yoy_pdf keeps every row on the page whatever the height", {
  seg <- data.frame(year = rep(2022:2023, each = 60), area = rep(sprintf("a%02d", 1:60), 2),
                    n = c(rep(10, 60), 8:67))
  y <- yoy(seg, value = "n", period = "year", by = "area")
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  yoy_pdf(y, f, height = 14)
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
  tf <- system.time(suppressWarnings(bricklayer_siu_resolve_so(fr)))[["elapsed"]]
  te <- system.time(suppressWarnings(bricklayer_siu_resolve_so(en)))[["elapsed"]]
  expect_lt(tf, 5 * max(te, 0.05))
  # the sentence filter still removes the legal boilerplate
  txt <- "UES. Les agents impliqués sont invités à participer; l'agent impliqué a participé."
  r <- bricklayer_siu_resolve_so(txt)
  expect_equal(r$count, 1L)
})

# ---- S2, S3 -------------------------------------------------------------------------------------------

test_that("hill_tail_index on identical values is not estimable, and a bound is not a fit", {
  h <- hill_tail_index(rep(1, 50))
  expect_true(is.na(h$alpha))
  expect_false(h$reliable)
  expect_match(h$method, "not estimable")
})

test_that("classical Mahalanobis distances survive wildly different scales", {
  set.seed(3)
  d <- data.frame(a = rnorm(100) * 1e160, b = rnorm(100))
  out <- mahalanobis_outliers(d, robust = FALSE)
  expect_equal(nrow(out), 100L)
  expect_true(all(is.finite(out$distance)))
  # affine invariance: the distances equal those on the rescaled data
  out2 <- mahalanobis_outliers(data.frame(a = d$a / 1e160, b = d$b), robust = FALSE)
  expect_equal(out$distance, out2$distance, tolerance = 1e-8)
})
