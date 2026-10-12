# SPDX-License-Identifier: AGPL-3.0-or-later
# The review of PR #56 (head 6e80794, report of 2026-10-12): every finding pinned, siblings
# enumerated.

cf_env2 <- function(env = parent.frame()) {
  withr::local_envvar(c(MORIE_LLM_BASE_URL = NA, MORIE_LLM_API_KEY = NA, MORIE_LLM_MODEL = NA,
                        MORIE_LLM_ROUTE = NA, OLLAMA_HOST = NA, OLLAMA_BASE_URL = NA,
                        OLLAMA_MODEL = NA, OLLAMA_API_KEY = NA,
                        MORIE_HOSTED_BASE_URL = NA, MORIE_HOSTED_KEY = NA, MORIE_HOSTED_MODEL = NA,
                        XDG_CONFIG_HOME = withr::local_tempdir(.local_envir = env)),
                      .local_envir = env)
}

test_that("X1: an attestation carries no private key, and the signature inside it still verifies", {
  k <- pqc_keygen()
  at <- capsule_attest(list(name = "real manifest"), k)
  expect_null(at$signature$key_state)
  flat <- unlist(at)
  expect_false(any(grepl("sk_seed|sk_prf|key_state", names(flat))))
  expect_false(any(grepl(k$sk_seed, flat, fixed = TRUE)))
  expect_false(any(grepl(k[["sk_prf"]], flat, fixed = TRUE)))
  chk <- capsule_check_attestation(at, list(name = "real manifest"))
  expect_match(paste(format(chk), collapse = "\n"), "Attestation check: OK")
  # the forgery of the report: there is no state to advance, so a second attestation from the
  # shared object is impossible
  expect_error(capsule_attest(list(name = "forged"), at$signature$key_state))
})

test_that("tamper: XMSS fields edited into non-whole numbers or removed are not verified, without an error", {
  k <- pqc_keygen()
  s <- capsule_sign("m", k, scheme = "xmss")
  pub <- signing_public_key(k)
  expect_true(capsule_verify("m", s, pub))
  for (bad in list(0.5, "0", -1L, NA_integer_, c(0L, 0L))) {
    t <- s
    t$index <- bad
    expect_false(capsule_verify("m", t, pub))
  }
  for (bad in list(4.5, "4", c(4L, 4L))) {
    t <- s
    t$height <- bad
    expect_false(capsule_verify("m", t, pub))
  }
  for (f in c("root", "height", "wire", "randomizer", "auth", "signature")) {
    t <- s
    t[[f]] <- NULL
    expect_false(capsule_verify("m", t, pub), info = f)
  }
  t <- s
  t$signature <- c(t$signature, "zz")
  expect_false(capsule_verify("m", t, pub))
})

test_that("M5: fips_verify_mu answers FALSE to a length-2 signature field (the shared hex helper)", {
  k <- fips_keygen("ML-DSA-65")
  mu <- as.raw(sample(0:255, 64, TRUE))
  s <- fips_sign_mu(k, mu)
  expect_true(fips_verify_mu(k, mu, s))
  s2 <- s
  s2$signature <- c(s2$signature, "zz")
  expect_false(fips_verify_mu(k, mu, s2))
  s3 <- s
  s3$signature <- character(0)
  expect_false(fips_verify_mu(k, mu, s3))
  expect_null(rmoriebricklayer:::.rmbl_hex_or_null(c("00", "11")))
  expect_null(rmoriebricklayer:::.rmbl_hex_or_null(NULL))
})

test_that("M1: boilerplate inserted at any sentence boundary of a French roster line never changes the count", {
  H <- "UES\nAgents impliqués\n"
  bp <- "Le nom d'un agent impliqué est confidentiel."
  lines <- c("AI no 1 A participé à une entrevue. AI no 3 était présent",
             "AI no 2 N'a pas consenti à une entrevue.",
             "AI no 4 A participé à une entrevue; AI no 5 a refusé. AI no 2 absent")
  for (ln in lines) {
    base <- as.numeric(bricklayer_siu_resolve_so(paste0(H, ln, "\nAgents témoins\n"))$count)
    expect_false(is.na(base))
    # the sentence is stripped whole, so it is inserted where a sentence can start: the line
    # start, the line end and after every terminator
    cuts <- c(0L, gregexpr("[.;]", ln)[[1L]], nchar(ln))
    cuts <- unique(cuts[cuts >= 0L])
    for (pos in cuts) {
      with_bp <- paste0(substr(ln, 1L, pos), " ", bp, " ", substr(ln, pos + 1L, nchar(ln)))
      got <- as.numeric(bricklayer_siu_resolve_so(paste0(H, with_bp, "\nAgents témoins\n"))$count)
      expect_identical(got, base, info = with_bp)
    }
  }
  # the two 0.5.11 cases stay pinned: a stripped sentence at the start of a line leaves the
  # entry after it counted
  fr2 <- paste0(H, "Le nom d'un agent impliqué n'est pas divulgué. AI no 3 A participé\nAI no 1\nAgents témoins\n")
  expect_equal(as.numeric(bricklayer_siu_resolve_so(fr2)$count), 3)
})

test_that("M2: a list mixing rules with anything else is refused, as is a data frame", {
  df <- data.frame(a = 1)
  expect_error(apply_schema_validation(df, list(rule_col_count(6, severity = "fatal"), 1)), "mixes rules")
  expect_error(apply_schema_validation(df, list(list(rule_col_count(6, severity = "fatal")))),
               "mixes rules|named provenance")
  expect_error(apply_schema_validation(df, df), "not a data frame")
  expect_error(apply_schema_validation(df, list(rule_col_count(6, severity = "fatal"))), "6")
  expect_true(apply_schema_validation(df, list(rule_col_count(1, severity = "fatal"))))
})

test_that("M3: a zero exposure the caller passed is a valid run with zero cases; nothing passed is no data", {
  st <- function(r) r$status
  r <- verify_pollution("pm25", exposure_mean = 0, exposure_prevalence = 1)
  expect_identical(st(r), "ok")
  expect_equal(r$pipeline$paf, 0)
  expect_equal(r$pipeline$burden$attributable_cases, 0)
  r2 <- verify_pollution("pm25", exposure_mean = 25, exposure_prevalence = 0)
  expect_identical(st(r2), "ok")
  expect_equal(r2$pipeline$paf, 0)
  expect_identical(st(verify_pollution("pm25")), "error")
  expect_identical(attr(verify_pollution("pm25"), "exit_status"), 2L)
})

test_that("M4: a per-100,000 baseline rate is refused by pollution_burden(), by_area() and mortality_displaced()", {
  expect_error(pollution_burden(25, 1, 800, 1e6, "PM2.5"), "per 100,000")
  expect_error(pollution_burden(25, 1, 800, 1e6, "NO2"), "per 100,000")
  tab <- data.frame(fsa = c("a", "b"), exposure = c(20, 30), population = c(40000, 60000),
                    baseline_rate = 800)
  expect_error(pollution_burden_by_area(tab), "per 100,000")
  expect_error(mortality_displaced(10, 1e6, 800, 0.01), "per 100,000")
  b <- pollution_burden(25, 1, 0.008, 1e6, "PM2.5")
  expect_lt(b$attributable_cases, 1e6)
  # verify_pollution() takes the per-100k form and converts; 800 per 100k on a million people
  r <- verify_pollution("pm25", exposure_mean = 25, exposure_prevalence = 1, baseline_rate = 800)
  expect_identical(r$status, "ok")
  expect_lt(r$pipeline$burden$attributable_cases, 8000)
})

test_that("M6: a logical or factor beta is refused by crf_no2 (and every pollution scalar)", {
  expect_error(crf_no2(20, beta_per_10 = TRUE), "not logical")
  expect_error(crf_no2(20, beta_per_10 = factor(0.02)), "not a factor")
  expect_error(pollution_burden(factor(25), 1, 0.008, 1e6), "not a factor")
  expect_error(exposure_response_plr(data.frame(y = 1:9, x = 1:9, z = 1:9), "y", "x", "z", n_bootstrap = 10.5),
               "whole number")
})

test_that("M7: the sub-step cap is on the work, cells x steps x sub-steps, with no off-by-one", {
  small <- matrix(1, 5, 5)
  # 5 x 5 cells needing about 10,001 sub-steps: a tenth of a second of work, so it runs
  r <- suppressWarnings(advection_diffusion_2d(small, u = 1e4 + 1, v = 0, kx = 0, ky = 0, dx = 1, dy = 1, dt = 1,
                                               n_steps = 1))
  expect_s3_class(r, "rmbl_field")
  expect_equal(r$substeps, 10001L)
  r2 <- suppressWarnings(advection_diffusion_2d(small, u = 1e4, v = 0, kx = 0, ky = 0, dx = 1, dy = 1,
                                                dt = 1, n_steps = 1))
  expect_equal(r2$substeps, 10000L)
  # 201 x 201 cells at 9,999 sub-steps for 100 steps would take hours: refused, naming the work
  big <- matrix(1, 201, 201)
  expect_error(advection_diffusion_2d(big, u = 9999, v = 0, kx = 0, ky = 0, dx = 1, dy = 1, dt = 1, n_steps = 100),
               "cells x steps x sub-steps")
})

test_that("M8: every input the pipeline refuses is a report, not a raw error", {
  csv <- function(df) {
    f <- withr::local_tempfile(fileext = ".csv", .local_envir = parent.frame())
    utils::write.csv(df, f, row.names = FALSE)
    f
  }
  st <- function(...) {
    r <- verify_pollution("no2", ...)
    list(status = r$status, exit = attr(r, "exit_status"), r = r)
  }
  r <- st(exposure_csv = csv(data.frame(exposure = c(20, 30, 40), income = c("low", "mid", "high"))))
  expect_identical(r$status, "error")
  expect_match(r$r$error, "income")
  r <- st(exposure_csv = csv(data.frame(exposure = c(0, 0, 0), income = c(1, 2, 3))))
  expect_identical(r$status, "ok")
  expect_null(r$r$pipeline$equity)
  r <- st(exposure_csv = csv(data.frame(exposure = c(20, -5, 40), income = c(1, 2, 3))))
  expect_true(r$status %in% c("ok", "error", "assumption_failure"))
  r <- st(exposure_csv = csv(data.frame(exposure = 20, income = 1)))
  expect_identical(r$status, "ok")
  r <- st(exposure_mean = 25, exposure_prevalence = 1, baseline_rate = 2e5)
  expect_identical(r$status, "assumption_failure")
  r <- st(exposure_mean = factor(25), exposure_prevalence = 1)
  expect_identical(r$status, "error")
  expect_match(r$r$error, "single number")
  r <- st(exposure_mean = 25, exposure_prevalence = 1, population = 1e6)
  txt <- pollution_report_text(r$r)
  expect_false(grepl("1e+06", txt, fixed = TRUE))
  expect_true(grepl("population=1,000,000", txt, fixed = TRUE))
})

test_that("L1: a configured Ollama that does not answer is skipped out loud before the hosted tier", {
  cf_env2()
  withr::local_envvar(c(OLLAMA_HOST = "http://127.0.0.1:18099", MORIE_HOSTED_KEY = "sk-h",
                        MORIE_HOSTED_BASE_URL = "https://llm.example.org"))
  testthat::local_mocked_bindings(.bl_ollama_tags = function(base, timeout = 2) NULL,
                                  .package = "rmoriebricklayer")
  expect_message(hit <- rmoriebricklayer:::.bl_llm_route(), "not answering")
  expect_identical(hit$name, "hosted MORIE tier")
  # the default address, never configured, is not announced
  withr::local_envvar(c(OLLAMA_HOST = NA))
  expect_silent(rmoriebricklayer:::.bl_llm_route())
})

test_that("L2: a non-object llm.json and a malformed credentials.json are errors, and nothing writes over them", {
  cf_env2()
  cfg <- rmoriebricklayer:::.bl_config_path()
  dir.create(dirname(cfg), recursive = TRUE, showWarnings = FALSE)
  for (bad in c("[]", "\"x\"", "5", "{not json")) {
    writeLines(bad, cfg)
    expect_error(rmoriebricklayer:::.bl_read_config(), "not a JSON object")
    expect_error(bricklayer_llm_config(route = "hosted"), "not valid JSON|not a JSON object")
    expect_identical(readLines(cfg, warn = FALSE), bad)
  }
  unlink(cfg)
  cred <- rmoriebricklayer:::.bl_credentials_path()
  writeLines("{not json", cred)
  expect_error(rmoriebricklayer:::.bl_read_credentials(), "shared with morie")
  expect_error(rmoriebricklayer:::.bl_store_key("sk-new"), "not a JSON object")
  expect_identical(readLines(cred, warn = FALSE), "{not json")
  writeLines("[1, 2]", cred)
  expect_error(rmoriebricklayer:::.bl_store_key("sk-new"), "not a JSON object")
})

test_that("L3: the hosted key is tied to the address it was saved for; a new own.url drops the saved own.key", {
  cf_env2()
  withr::local_envvar(c(MORIE_HOSTED_BASE_URL = "https://llm.example.org"))
  rmoriebricklayer:::.bl_store_key("sk-saved")
  expect_identical(rmoriebricklayer:::.bl_hosted_key(), "sk-saved")
  withr::local_envvar(c(MORIE_HOSTED_BASE_URL = "https://other.example.org"))
  expect_null(rmoriebricklayer:::.bl_hosted_key())
  withr::local_envvar(c(MORIE_HOSTED_KEY = "sk-env"))
  expect_identical(rmoriebricklayer:::.bl_hosted_key(), "sk-env")
  withr::local_envvar(c(MORIE_HOSTED_KEY = NA, MORIE_HOSTED_BASE_URL = NA))
  bricklayer_llm_config(own.url = "http://localhost:1234/v1", own.key = "k-one")
  expect_identical(rmoriebricklayer:::.bl_config_value("MORIE_LLM_API_KEY"), "k-one")
  expect_message(bricklayer_llm_config(own.url = "http://localhost:4321/v1"), "own.key was dropped")
  expect_null(rmoriebricklayer:::.bl_config_value("MORIE_LLM_API_KEY"))
  bricklayer_llm_config(ollama.url = "http://localhost:11434", ollama.key = "k-two")
  expect_message(bricklayer_llm_config(ollama.url = "http://192.168.1.20:11434"), "ollama.key was dropped")
})

test_that("L5: ollama.url refuses a metadata or link-local address when it is saved", {
  cf_env2()
  pat <- "169.254|link-local|metadata|not allowed|refus"
  expect_error(bricklayer_llm_config(ollama.url = "http://169.254.169.254"), pat)
  expect_error(bricklayer_llm_config(ollama.url = "169.254.169.254:11434"), pat)
  expect_silent(bricklayer_llm_config(ollama.url = "http://localhost:11434"))
})

test_that("L12: accents survive the control-character filter in a C locale", {
  withr::local_locale(c(LC_CTYPE = "C"))
  nm <- paste0("Donn\u00e9es \u2014 Montr\u00e9al", "\033[31m")
  tab <- rmoriebricklayer:::.bl_data_tables_df("db/t", nm, 3L, "x")
  txt <- rmoriebricklayer:::.bl_format_data_tables(tab, width = 100)
  # the accents are kept (a C locale may print them as <U+00E9>, but never drops them)
  expect_false(grepl("Donnes", txt, fixed = TRUE))
  expect_false(grepl("Montral", txt, fixed = TRUE))
  expect_true(grepl("Donn", txt, fixed = TRUE))
  expect_false(grepl("\033", txt, fixed = TRUE))
})

test_that("D1: a cached table whose SHA-256 is not the manifest's is deleted and refused", {
  dir <- withr::local_tempdir()
  f <- file.path(dir, "t.csv.gz")
  con <- gzfile(f, "wb")
  writeLines("a,b\n1,2", con)
  close(con)
  good <- core_sha256(readBin(f, "raw", file.size(f)))
  testthat::local_mocked_bindings(
    bricklayer_data_manifest = function(refresh = FALSE) list(datasets = list(list(key = "db/t", sha256 = good))),
    .package = "rmoriebricklayer")
  expect_true(rmoriebricklayer:::.bl_data_check_sha("db/t", f))
  con <- gzfile(f, "wb")
  writeLines("a,b\n1,3", con)
  close(con)
  expect_error(rmoriebricklayer:::.bl_data_check_sha("db/t", f), "does not match the manifest")
  expect_false(file.exists(f))
  # a manifest without a digest for the table is not a failure
  testthat::local_mocked_bindings(
    bricklayer_data_manifest = function(refresh = FALSE) list(datasets = list(list(key = "db/t"))),
    .package = "rmoriebricklayer")
  con <- gzfile(f, "wb")
  writeLines("a,b\n1,2", con)
  close(con)
  expect_true(rmoriebricklayer:::.bl_data_check_sha("db/t", f))
})

test_that("N1b: a territory the carbon table lacks uses its country's grid or the world, never the locale", {
  loc <- function(z, locale = "en_US.UTF-8") detect_location("", "", tz = z, locale = locale)
  expect_identical(loc("Europe/Monaco")$location, "FR")
  expect_match(loc("Europe/Monaco")$method, "territory MC")
  expect_identical(loc("Europe/Vaduz")$location, "CH")
  expect_identical(loc("Europe/Andorra")$location, "ES")
  expect_identical(loc("Europe/Jersey")$location, "GB")
  expect_identical(loc("Europe/Guernsey")$location, "GB")
  expect_identical(loc("Antarctica/McMurdo")$location, "WORLD")
  expect_match(loc("Antarctica/McMurdo")$method, "world average")
  # every geographic zone resolves to a row of the carbon table or to WORLD by this path
  tz <- rmoriebricklayer:::.rmbl_tz_table()
  ct <- carbon_intensity_table()
  for (z in tz$tz[!tz$location %in% ct$location]) {
    r <- loc(z)
    expect_false(grepl("locale", r$method), info = z)
    expect_true(r$location %in% ct$location, info = z)
  }
})

test_that("argument leftovers: particles, usage, flags, sources and receptor heights", {
  expect_error(lagrangian_particles(n = 2.7, x0 = 0, y0 = 0, u = 1, v = 0, kx = 1, ky = 1, dt = 1, n_steps = 2),
               "whole number")
  expect_error(compute_footprint(usage = c("process", "machine")), "one value")
  expect_error(gaussian_plume(q = 1, u = TRUE, h = 10, receptors = cbind(100, 0, 0)), "not logical")
  expect_error(advection_diffusion_2d(matrix(1, 4, 4), 0, 0, 1, 1, 1, 1, 0.1, 1, source = matrix(-1, 4, 4)),
               "non-negative")
  expect_warning(gaussian_plume(q = 1, u = 2, h = 10, receptors = cbind(100, 0, -1)), "below ground")
  expect_warning(gaussian_plume(q = 1, u = 2, h = 10, receptors = cbind(100, 0, 900), mixing_height = 500),
                 "above the mixing height")
})

test_that("plots: a hand-made Lorenz frame is sorted and checked; an all-NA axis gives a finite margin", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  d <- data.frame(population = c(0.5, 1, 0.25), value = c(0.3, 1, 0.1))
  got <- plot_lorenz(d)
  expect_true(all(diff(got$population) >= 0))
  expect_true(all(diff(got$value) >= 0))
  expect_error(plot_lorenz(data.frame(population = c(0.25, 0.5, 1), value = c(0.3, 0.1, 1))),
               "non-decreasing")
  expect_true(is.finite(rmoriebricklayer:::.bl_left_margin(c(NA_real_, NA_real_))))
  expect_true(is.finite(rmoriebricklayer:::.bl_left_margin(labels = c(NA, NA))))
})

test_that("D4: thirty notes on a five-inch page all land on the page, on pages of their own", {
  d <- data.frame(year = 2015:2024, n = c(402, 377, 190, 268, 331, 300, 310, 290, 305, 320))
  y <- yoy(d, value = "n", period = "year")
  f <- withr::local_tempfile(fileext = ".pdf")
  notes <- sprintf("note %d of thirty, a footnote that explains one row of the table", 1:30)
  yoy_pdf(y, f, notes = notes, height = 5)
  # count the page objects from the bytes: readLines() of a PDF stops early on some platforms
  bytes <- readBin(f, "raw", file.size(f))
  bytes[bytes == as.raw(0L)] <- as.raw(32L)
  txt <- rawToChar(bytes)
  pages <- length(gregexpr("/Type /Page[^s]", txt, useBytes = TRUE)[[1L]])
  expect_gte(pages, 2L)
  # the table rows do not shrink to make room: thirty notes on a 5-inch page would leave
  # room for fewer rows than the table has, so they took pages of their own and the table
  # kept the rows of a note-free page, which hold all ten
  expect_lt(rmoriebricklayer:::.yoy_rows_per_page(5, 30L), nrow(d))
  expect_gte(rmoriebricklayer:::.yoy_rows_per_page(5, 0L), nrow(d))
  expect_gt(rmoriebricklayer:::.yoy_rows_per_page(5, 0L), rmoriebricklayer:::.yoy_rows_per_page(5, 30L))
})

test_that("CLI: a prompt after a bare -- may start with --, and the launcher is executable", {
  cf_env2()
  seen <- NULL
  testthat::local_mocked_bindings(
    bricklayer_llm_ask = function(prompt, model = NULL, route = NULL, ...) {
      seen <<- prompt
      "reply"
    },
    .package = "rmoriebricklayer")
  buf <- character()
  st <- bricklayer_cli(c("ask", "--", "--weird", "prompt"), out = function(s) buf <<- c(buf, s))
  expect_identical(st, 0L)
  expect_identical(seen, "--weird prompt")
  st <- bricklayer_cli(c("ask", "--route", "hosted", "--", "--model"), out = function(s) buf <<- c(buf, s))
  expect_identical(seen, "--model")
  launcher <- system.file("bin", "rmbl", package = "rmoriebricklayer")
  skip_if(!nzchar(launcher))
  skip_on_os("windows")  # no execute bit there
  expect_true(file.access(launcher, 1L) == 0L)
})

test_that("the help never suggests a key on the command line", {
  expect_false(grepl("--token KEY", rmoriebricklayer:::.bl_access_hint(), fixed = TRUE))
  out <- character()
  bricklayer_cli("help", out = function(s) out <<- c(out, s))
  expect_false(any(grepl("login --token KEY", out, fixed = TRUE)))
  out <- character()
  bricklayer_cli(c("login", "--help"), out = function(s) out <<- c(out, s))
  expect_false(any(grepl("login --token KEY", out, fixed = TRUE)))
})

test_that("patch coverage: the territory fallback, an overflowed stability number, a non-object settings file", {
  known <- function(k) if (identical(k, "FR")) "FR" else NA_character_
  expect_identical(rmoriebricklayer:::.rmbl_territory_location("MC", known), "FR")
  expect_identical(rmoriebricklayer:::.rmbl_territory_location("AQ", known), "WORLD")
  expect_identical(rmoriebricklayer:::.rmbl_territory_location("MC", known, proxies = c(MC = "ZZ")), "WORLD")
  expect_identical(rmoriebricklayer:::.rmbl_territory_location("MC", known, proxies = c(XX = "FR")), "WORLD")
  expect_error(advection_diffusion_2d(matrix(1, 4, 4), u = 1e308, v = 0, kx = 0, ky = 0, dx = 1e-308, dy = 1,
                                      dt = 1e308, n_steps = 1), "not finite")
  cf_env2()
  cfg <- rmoriebricklayer:::.bl_config_path()
  dir.create(dirname(cfg), recursive = TRUE, showWarnings = FALSE)
  writeLines("{\"route\": \"hosted\"}", cfg)
  expect_identical(rmoriebricklayer:::.bl_config_object(cfg)$route, "hosted")
  writeLines("{", cfg)
  expect_null(rmoriebricklayer:::.bl_config_object(cfg))
  # the writer's own guard, for callers that write without reading first
  writeLines("[]", cfg)
  expect_error(rmoriebricklayer:::.bl_write_config(list(route = "hosted")), "not valid JSON")
  expect_identical(readLines(cfg, warn = FALSE), "[]")
  unlink(cfg)
  rmoriebricklayer:::.bl_write_config(list(route = "hosted"))
  expect_identical(rmoriebricklayer:::.bl_read_config()$route, "hosted")
  cred <- rmoriebricklayer:::.bl_credentials_path()
  writeLines("{\"hosted_key\": \"k\"}", cred)
  expect_identical(rmoriebricklayer:::.bl_credentials_object(cred)$hosted_key, "k")
  writeLines("{", cred)
  expect_null(rmoriebricklayer:::.bl_credentials_object(cred))
})
