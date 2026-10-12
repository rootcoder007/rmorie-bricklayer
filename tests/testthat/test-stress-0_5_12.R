# SPDX-License-Identifier: AGPL-3.0-or-later
# The 0.5.11 stress round (commit a5a4d10, report of 2026-10-12): every finding pinned.

loc_of <- function(z) detect_location("", "", tz = z, locale = "C")$location

test_that("N1: time-zone aliases map to their own country, generic zones to none", {
  expect_equal(loc_of("Iceland"), "IS")
  expect_equal(loc_of("Atlantic/Reykjavik"), "IS")
  expect_equal(loc_of("Atlantic/Jan_Mayen"), "NO")
  expect_equal(loc_of("America/Coral_Harbour"), "CA")
  expect_equal(loc_of("Africa/Asmera"), "ER")
  expect_equal(loc_of("Africa/Timbuktu"), "ML")
  expect_equal(loc_of("Pacific/Truk"), "FM")
  expect_equal(loc_of("Pacific/Yap"), "FM")
  expect_equal(loc_of("Pacific/Ponape"), "FM")
  expect_equal(loc_of("Asia/Calcutta"), "IN")
  expect_equal(loc_of("US/Eastern"), "US")
  expect_equal(loc_of("Canada/Eastern"), "CA")
  expect_equal(loc_of("Europe/Stockholm"), "SE")
  tz <- rmoriebricklayer:::.rmbl_tz_table()
  expect_false(any(c("CET", "EET", "MET", "WET", "EST", "HST", "MST", "EST5EDT", "PST8PDT") %in% tz$tz))
  for (g in c("CET", "EST", "WET")) expect_equal(loc_of(g), "WORLD")
  olson <- OlsonNames()
  geo <- olson[grepl("/", olson, fixed = TRUE) & !grepl("^(Etc|posix|right|SystemV)/", olson)]
  expect_identical(setdiff(geo, tz$tz), character(0))
  # every alias in the table names a country the carbon table knows, or a territory code
  expect_true(all(nchar(tz$location) == 2L))
})

test_that("N2: a run whose work (cells x steps x sub-steps) is out of reach is refused, as is an overflowed count", {
  c0 <- matrix(0, 11, 11)
  c0[6, 6] <- 1
  expect_error(advection_diffusion_2d(c0, u = 1e10, v = 0, kx = .1, ky = .1, 1, 1, 1, 2), "sub-steps")
  t0 <- proc.time()[["elapsed"]]
  expect_error(advection_diffusion_2d(c0, u = .5, v = .4, kx = .1, ky = .1, 1, 1, 1e5, 1), "sub-steps")
  expect_lt(proc.time()[["elapsed"]] - t0, 5)
  # a mild excursion is still sub-stepped and conserves mass
  r <- suppressWarnings(advection_diffusion_2d(c0, u = 1.5, v = 0, kx = 0, ky = 0, 1, 1, 1, 1))
  expect_equal(r$substeps, 2L)
  expect_equal(r$mass, 1, tolerance = 1e-12)
})

test_that("N3: no data is an error report, a below-reference exposure a valid zero, the contract enforced", {
  none <- verify_pollution("no2")
  expect_equal(none$status, "error")
  expect_equal(attr(none, "exit_status"), 2L)
  expect_match(none$error, "no exposure data")
  low <- verify_pollution("pm25", exposure_mean = 3, exposure_prevalence = 0.5)
  expect_equal(low$status, "ok")
  expect_equal(low$pipeline$paf, 0)
  expect_equal(low$pipeline$burden$attributable_cases, 0)
  bad <- verify_pollution("pm25", exposure_mean = -3, exposure_prevalence = 0.5)
  expect_equal(bad$status, "assumption_failure")
  expect_equal(attr(bad, "exit_status"), 1L)
  for (args in list(list(demo = NA), list(demo = "yes"), list(exposure_mean = c(20, 30), exposure_prevalence = 0.5),
                    list(outcome = "bogus", exposure_mean = 20, exposure_prevalence = 0.5),
                    list(reference = c(1, 2), exposure_mean = 20, exposure_prevalence = 0.5),
                    list(exposure_csv = tempdir()), list(exposure_csv = c("a", "b")),
                    list(population = TRUE, exposure_mean = 20, exposure_prevalence = 0.5))) {
    r <- do.call(verify_pollution, c(list("no2"), args))
    expect_equal(r$status, "error", info = paste(names(args), collapse = ","))
    expect_equal(attr(r, "exit_status"), 2L)
  }
  expect_match(verify_pollution("no2", outcome = "bogus", exposure_mean = 20, exposure_prevalence = 0.5)$error,
               "Unknown outcome")
  expect_match(verify_pollution("no2", exposure_csv = tempdir())$error, "directory")
  ok <- verify_pollution("no2", exposure_mean = 20, exposure_prevalence = 0.5, population = 1e6)
  expect_match(pollution_report_text(ok), "population:         1,000,000", fixed = TRUE)
})

test_that("N4: a rule list handed to apply_schema_validation() is run, not ignored", {
  expect_error(apply_schema_validation(data.frame(a = 1), list(rule_col_count(6, severity = "fatal"))), "6")
  expect_true(apply_schema_validation(data.frame(a = 1, b = 2), list(rule_col_count(2, severity = "fatal"))))
  expect_warning(apply_schema_validation(data.frame(a = 1), rule_col_count(6, severity = "warning")))
})

test_that("N5: a stripped boilerplate sentence ends its line, so the roster entry after it counts", {
  fr1 <- paste0("UES\nAgents impliqués\nLe nom d'un agent impliqué n'est pas divulgué. ",
                "AI N'a pas consenti à une entrevue\nAgents témoins\n")
  fr2 <- paste0("UES\nAgents impliqués\nLe nom d'un agent impliqué n'est pas divulgué. ",
                "AI no 3 A participé\nAI no 1\nAgents témoins\n")
  expect_equal(as.numeric(bricklayer_siu_resolve_so(fr1)$count), 1)
  expect_equal(as.numeric(bricklayer_siu_resolve_so(fr2)$count), 3)
  # the English roster is untouched by the change
  en <- "SIU\nSubject Officials\nSO #1 Interviewed\nSO #2 Declined\nWitness Officials\n"
  expect_equal(as.numeric(bricklayer_siu_resolve_so(en)$count), 2)
})

test_that("N6: the concentration index refuses coded incomes and negative exposures; numeric area columns", {
  d <- data.frame(e = c(10, 20, 30), inc = factor(c("high", "low", "mid")))
  expect_error(exposure_concentration_index(d, "e", "inc"), "must be numeric")
  d$inc <- c("high", "low", "mid")
  expect_error(exposure_concentration_index(d, "e", "inc"), "must be numeric")
  expect_error(exposure_concentration_index(data.frame(e = c(-1, 2, 3), i = 1:3), "e", "i"), "non-negative")
  r <- exposure_concentration_index(data.frame(e = c(30, 25, 20, 15, 10), i = 1:5), "e", "i")
  h <- c(30, 25, 20, 15, 10)
  R <- (rank(1:5) - 0.5) / 5
  expect_equal(r$concentration_index, 2 * sum((h - mean(h)) * (R - mean(R))) / 5 / mean(h), tolerance = 1e-12)
  expect_null(r$n_quintiles)
  a <- data.frame(fsa = c("a", "b"), exposure = c(10, 20), population = factor(c("100", "200")),
                  baseline_rate = c(500, 500))
  expect_error(pollution_burden_by_area(a), "must be numeric")
})

test_that("L1/L4: an empty local Ollama is skipped with a message in the automatic order; a bad route name errors", {
  withr::local_envvar(MORIE_LLM_ROUTE = "", MORIE_LLM_BASE_URL = "", OLLAMA_HOST = "", OLLAMA_MODEL = "",
                      MORIE_HOSTED_KEY = "")
  testthat::local_mocked_bindings(
    .bl_own_base = function() NULL,
    .bl_ollama_base = function() "http://localhost:11434",
    .bl_ollama_tags = function(base, timeout = 2) character(0),
    .bl_hosted_base = function() "https://llm.rmorie.com",
    .bl_hosted_key = function() "k",
    .bl_hosted_model = function() "m",
    .bl_config_value = function(env) NULL,
    .package = "rmoriebricklayer"
  )
  expect_message(rt <- rmoriebricklayer:::.bl_llm_route(NULL), "no model pulled.*hosted MORIE tier")
  expect_equal(rt$name, "hosted MORIE tier")
  expect_message(rt2 <- rmoriebricklayer:::.bl_llm_route("auto"), "no model pulled")
  expect_equal(rt2$name, "hosted MORIE tier")
  # insisting on Ollama keeps the prompt local: the empty server is taken, no message
  expect_silent(rt3 <- rmoriebricklayer:::.bl_llm_route("ollama"))
  expect_equal(rt3$name, "local Ollama")
  withr::local_envvar(MORIE_LLM_ROUTE = "ollma")
  expect_error(rmoriebricklayer:::.bl_llm_route(NULL), "must be auto, own, ollama or hosted")
})

test_that("L2: a malformed llm.json is an error and never written over", {
  dir <- withr::local_tempdir()
  cfg <- file.path(dir, "llm.json")
  writeLines('{"route": "ollama",}', cfg)
  testthat::local_mocked_bindings(.bl_config_path = function() cfg, .package = "rmoriebricklayer")
  # the review of 0.5.12: an unreadable settings file is an error every time, not a warning
  # once per change that then let the saved route be dropped
  expect_error(rmoriebricklayer:::.bl_read_config(), "not a JSON object")
  expect_error(bricklayer_llm_config(route = "hosted"), "not a JSON object")
  expect_identical(readLines(cfg), '{"route": "ollama",}')
})

test_that("L3: a saved key is sent only to the address it was saved with", {
  withr::local_envvar(MORIE_LLM_API_KEY = "", MORIE_LLM_BASE_URL = "", OLLAMA_API_KEY = "", OLLAMA_HOST = "",
                      OLLAMA_BASE_URL = "")
  saved <- c(MORIE_LLM_BASE_URL = "http://10.0.0.5:1234/v1", MORIE_LLM_API_KEY = "own-secret",
             OLLAMA_HOST = "http://10.0.0.6:11434", OLLAMA_API_KEY = "ollama-secret")
  testthat::local_mocked_bindings(.bl_config_value = function(env) unname(saved[env]), .package = "rmoriebricklayer")
  kf <- rmoriebricklayer:::.bl_key_for
  expect_equal(kf("MORIE_LLM_API_KEY", "MORIE_LLM_BASE_URL"), "own-secret")
  own <- function() kf("MORIE_LLM_API_KEY", "MORIE_LLM_BASE_URL")
  withr::with_envvar(c(MORIE_LLM_BASE_URL = "http://10.0.0.5:1234/v1/"), expect_equal(own(), "own-secret"))
  withr::with_envvar(c(MORIE_LLM_BASE_URL = "http://10.0.0.9:18002"), expect_null(own()))
  withr::with_envvar(c(MORIE_LLM_BASE_URL = "http://10.0.0.9:18002", MORIE_LLM_API_KEY = "one-off"),
                     expect_equal(kf("MORIE_LLM_API_KEY", "MORIE_LLM_BASE_URL"), "one-off"))
  withr::with_envvar(c(OLLAMA_HOST = "http://10.0.0.7:11434"), expect_null(kf("OLLAMA_API_KEY", "OLLAMA_HOST")))
  withr::with_envvar(c(OLLAMA_BASE_URL = "http://10.0.0.6:11434"), expect_equal(kf("OLLAMA_API_KEY",
                                                                                   "OLLAMA_HOST"), "ollama-secret"))
})

test_that("L5: addresses are checked when saved as they are when used", {
  withr::local_envvar(OLLAMA_HOST = "", OLLAMA_BASE_URL = "", MORIE_LLM_BASE_URL = "")
  dir <- withr::local_tempdir()
  cfg <- file.path(dir, "llm.json")
  testthat::local_mocked_bindings(.bl_config_path = function() cfg, .package = "rmoriebricklayer")
  expect_error(bricklayer_llm_config(own.url = "http://169.254.169.254"), "own.url")
  expect_error(bricklayer_llm_config(ollama.url = "ftp://10.0.0.6:11434"), "http")
  expect_false(file.exists(cfg))
  bricklayer_llm_config(ollama.url = "http://localhost:11434")
  expect_true(file.exists(cfg))
})

test_that("L6-L8: plot state survives an error; funnel labels, empty tables and unsorted fields are refused clearly", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  broken <- structure(list(status = "ok", pipeline = list(crf = "bad"), pollutant = "no2", outcome = "x"),
                      class = "rmbl_pollution_report")
  try(plot(broken), silent = TRUE)
  expect_false(rmoriebricklayer:::.bl_state$active)
  expect_error(plot_funnel(c(5, 6, 7), c(5, 5, 5), area = "x"), "one label per point")
  expect_silent(plot(frequency_table(character(0))))
  expect_error(plume_field(1, 5, 50, c(3, 1, 2), c(1, 2)), "strictly increasing")
})

test_that("L10: dispersion, zeta, footprint and displaced-mortality inputs are checked", {
  expect_error(advection_diffusion_2d(c(1, 0, 0), 0, 0, 0, 0, 1, 1, 1, 1), "numeric matrix")
  expect_error(advection_diffusion_2d(matrix(-1, 3, 3), 0, 0, 0, 0, 1, 1, 1, 1), "non-negative")
  expect_error(advection_diffusion_2d(matrix(0, 3, 3), 0, 0, 0, 0, 1, 1, 1, 1, source = matrix(NA, 3, 3)), "finite")
  expect_error(hurwitz_zeta(2, q = c(1, 2)), "single finite")
  expect_true(is.na(hurwitz_zeta(2, 0)))
  expect_equal(hurwitz_zeta(2, q = 1), pi^2 / 6, tolerance = 1e-9)
  expect_error(compute_footprint(1 + 1, cores = 2.5), "whole number")
  expect_error(mortality_displaced(10, 1e6, 800, 0.01), "per person-year")
  expect_equal(mortality_displaced(10, 1e6, 0.008, 0.01), 0.008 * 1e6 * (1 - exp(-0.1)))
})

test_that("L12: control characters in the data manifest never reach the terminal", {
  tab <- data.frame(key = c("ok", "x\033[31m"), name = c("plain", "red\033[31mname\r"), rows = c(1, NA),
                                                         stringsAsFactors = FALSE)
  out <- rmoriebricklayer:::.bl_format_data_tables(tab, width = 80)
  expect_false(grepl("\033", out, fixed = TRUE))
  expect_false(grepl("\r", out, fixed = TRUE))
  expect_match(out, "redname", fixed = TRUE)
})

test_that("P5/P9/P12/P13: logical risks, Celsius, recycled references, fractional folds, coded outcomes, grids", {
  expect_error(attributable_fraction(TRUE, 0.5), "not logical")
  expect_error(briggs_plume_rise(500, 5, 2, 10, 150, 20), "kelvin")
  expect_gt(briggs_plume_rise(500, 5, 2, 10, 423, 293)$rise[1], 0)
  expect_error(crf_pm25(c(10, 20, 30), reference_conc = c(5, 6)), "single finite")
  expect_error(crf_pm25(10, reference_conc = NA), "single finite")
  expect_error(crf_pm25(10, reference_conc = TRUE), "not logical")
  expect_error(crf_no2(10, reference_conc = c(5, 6)), "single finite")
  set.seed(1)
  d <- data.frame(y = rnorm(40), d = rnorm(40), x = rnorm(40))
  expect_error(plr_crossfit(d, "y", "d", "x", k_folds = 2.7), "whole number")
  d$y <- factor(sample(c("a", "b"), 40, TRUE))
  expect_error(plr_crossfit(d, "y", "d", "x"), "must be numeric")
  expect_error(lagrangian_particles(50, 0, 0, 1, 0, .1, .1, 1, 5, grid = c(10, -10, -10, 10, 5, 5)), "x_min < x_max")
  expect_error(lagrangian_particles(50, 0, 0, 1, 0, .1, .1, 1, 5, grid = c(-10, 10, -10, 10, 5.5, 5)), "whole")
  expect_warning(r <- detect_location(env_location = "Narnia", codecarbon_location = "", tz = "Europe/Paris",
                                      locale = "C"),
                 "RMBL_LOCATION='Narnia' is not")
  expect_equal(r$location, "FR")
})

test_that("P14: one world row, from Ember", {
  ci <- carbon_intensity_table()
  expect_false("GLOBAL" %in% ci$location)
  expect_equal(sum(ci$location == "WORLD"), 1L)
  expect_true(all(ci$year >= 2009 & ci$year <= 2025))
})

test_that("tamper: a verifier answers FALSE to edited or malformed signature fields", {
  k <- pqc_keygen()
  s <- capsule_sign("m", k)
  expect_true(capsule_verify("m", s, k))
  s2 <- s
  s2$signature <- c(s2$signature, "zz")
  expect_false(capsule_verify("m", s2, k))
  s2 <- s
  s2$auth <- character(0)
  expect_false(capsule_verify("m", s2, k))
  s2 <- s
  s2$root <- paste0(rev(strsplit(s2$root, "")[[1]]), collapse = "")
  expect_false(capsule_verify("m", s2, k))
  s2 <- s
  s2$height <- s2$height + 1L
  expect_false(capsule_verify("m", s2, k))
  s2 <- s
  s2$wire <- sub("^.", "f", s2$wire)
  expect_false(capsule_verify("m", s2, k))
  s2 <- s
  s2$index <- NA
  expect_false(capsule_verify("m", s2, k))
  ok <- fips_keygen("ML-DSA-65")
  fs <- capsule_sign("m", ok)
  expect_true(capsule_verify("m", fs, ok))
  fs2 <- fs
  fs2$prehash <- "bogus"
  expect_false(capsule_verify("m", fs2, ok))
  fs2 <- fs
  fs2$signature <- c(fs2$signature, "zz")
  expect_false(capsule_verify("m", fs2, ok))
})

test_that("P5: the relative risk's confidence limits propagate through the attributable fraction", {
  p <- 0.4
  levin <- function(r) p * (r - 1) / (1 + p * (r - 1))
  paf <- attributable_fraction(1.5, p, rr_lower = 1.2, rr_upper = 1.9)
  expect_equal(as.numeric(paf), levin(1.5))
  expect_equal(attr(paf, "ci"), c(lower = levin(1.2), upper = levin(1.9)))
  expect_null(attr(attributable_fraction(1.5, p), "ci"))
  expect_error(attributable_fraction(1.5, p, rr_lower = 1.2), "go together")
  expect_error(attributable_fraction(1.5, p, rr_lower = 1.6, rr_upper = 1.9), "between")
  # the PM2.5 all-cause curve carries Chen and Hoek's 1.06 to 1.09 per 10 ug/m3
  crf <- crf_pm25(15.8)
  expect_equal(crf$rr, 1.08)
  expect_equal(crf$rr_lower, 1.06)
  expect_equal(crf$rr_upper, 1.09)
  n <- crf_no2(20)
  expect_equal(c(n$rr_lower, n$rr_upper), c(1.01, 1.04))
  expect_true(is.na(crf_pm25(20, outcome = "ihd")$rr_lower))
  r <- verify_pollution("pm25", exposure_mean = 15.8, exposure_prevalence = 0.5)
  expect_equal(r$pipeline$paf, 0.5 * 0.08 / (1 + 0.5 * 0.08))
  expect_equal(unname(r$pipeline$paf_ci), c(0.5 * 0.06 / (1 + 0.5 * 0.06), 0.5 * 0.09 / (1 + 0.5 * 0.09)))
  expect_match(pollution_report_text(r), "95% CI", fixed = TRUE)
})

test_that("D4: the rows a PDF page holds leave room for the title block, the page label and the notes", {
  rows <- rmoriebricklayer:::.yoy_rows_per_page
  for (h in c(5, 8.5, 11, 17, 24)) {
    n <- rows(h, 0L)
    # the rows drawn from 0.88 down by 0.22 inch each end above the page label at 0.06
    expect_lte(0.88 - 1.1 * 0.22 / h - (n - 1) * 0.22 / h, 0.88)
    expect_gte(0.88 - 1.1 * 0.22 / h - n * 0.22 / h, 0.06 - 1e-9)
    expect_gt(rows(h, 0L), rows(h, 3L))
  }
  expect_equal(rows(24, 0L), 88L)
  expect_equal(rows(8.5, 0L), 30L)
  expect_equal(rows(1, 0L), 5L)
})

test_that("PBKDF2-HMAC-SHA256 matches the RFC 7914 vectors (ACVP's PBKDF set is SHA2-224 only)", {
  expect_identical(derive_key("passwd", "salt", 1L, 64L),
                   paste0("55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc",
                          "49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783"))
  expect_identical(derive_key("Password", "NaCl", 80000L, 64L),
                   paste0("4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56",
                          "a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d"))
})

test_that("a secret typed at a terminal is read with echo off and the echo restored", {
  skip_on_os("windows")
  calls <- character()
  testthat::local_mocked_bindings(.bl_interactive = function() TRUE)
  testthat::local_mocked_bindings(
    isatty = function(con) TRUE,
    readline = function(prompt = "") " sk-hidden ",
    system2 = function(command, args = character(), ...) {
      calls <<- c(calls, paste(command, args))
      invisible(0L)
    },
    .package = "base"
  )
  msg <- utils::capture.output(got <- .bl_readline("key> ", secret = TRUE), type = "message")
  expect_equal(got, "sk-hidden")
  if (nzchar(Sys.which("stty"))) {
    expect_equal(calls, c("stty -echo", "stty echo"))
    expect_true(any(msg == ""))
  }
})

test_that("ask refuses a repeated --model or --route instead of folding one into the prompt", {
  withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir(), MORIE_HOSTED_KEY = NA, RMBL_PROG = "rmbl")
  txt <- character()
  st <- bricklayer_cli(c("ask", "--model", "a", "--model", "b", "hi"), out = function(s) txt <<- c(txt, s))
  expect_equal(st, 2L)
  expect_match(paste(txt, collapse = ""), "--model may be given once", fixed = TRUE)
  txt <- character()
  st <- bricklayer_cli(c("ask", "--route", "own", "--route", "hosted", "hi"), out = function(s) txt <<- c(txt, s))
  expect_equal(st, 2L)
  expect_match(paste(txt, collapse = ""), "--route may be given once", fixed = TRUE)
})

test_that("verify_pollution wants one outcome name, not a vector or a number", {
  for (bad in list(c("a", "b"), 3, NA_character_)) {
    r <- verify_pollution("no2", outcome = bad, exposure_mean = 20, exposure_prevalence = 0.5)
    expect_equal(attr(r, "exit_status"), 2L)
    expect_match(r$error, "outcome must be a single outcome name", fixed = TRUE)
  }
})

test_that("the PAF confidence text is empty without limits and quotes them otherwise", {
  expect_equal(rmoriebricklayer:::.pollution_paf_ci_text(NULL), "")
  expect_equal(rmoriebricklayer:::.pollution_paf_ci_text(c(lower = 0.1234, upper = 0.2)),
               "  (95% CI 0.1234 to 0.2000, from the risk's limits)")
})
