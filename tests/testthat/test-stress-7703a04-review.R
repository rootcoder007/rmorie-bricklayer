# SPDX-License-Identifier: AGPL-3.0-or-later
# The review of 7703a04 (report of 2026-10-12): every finding pinned, with the earlier round's
# weak tests sharpened.

cf_env3 <- function(env = parent.frame()) {
  withr::local_envvar(c(MORIE_LLM_BASE_URL = NA, MORIE_LLM_API_KEY = NA, MORIE_LLM_MODEL = NA,
                        MORIE_LLM_ROUTE = NA, OLLAMA_HOST = NA, OLLAMA_BASE_URL = NA,
                        OLLAMA_MODEL = NA, OLLAMA_API_KEY = NA, MORIE_DATA_URL = NA,
                        MORIE_HOSTED_BASE_URL = NA, MORIE_HOSTED_KEY = NA, MORIE_HOSTED_MODEL = NA,
                        XDG_CONFIG_HOME = withr::local_tempdir(.local_envir = env)),
                      .local_envir = env)
}

has_secret <- function(obj, key) {
  flat <- unlist(obj)
  any(grepl("sk_seed|sk_prf|key_state", names(flat))) ||
    any(grepl(key$sk_seed, flat, fixed = TRUE)) || any(grepl(key[["sk_prf"]], flat, fixed = TRUE))
}

test_that("Y1: no signature, attestation, bundle or serialisation of any scheme carries private-key bytes", {
  k <- pqc_keygen()
  s <- capsule_sign("hello", k, scheme = "xmss")
  expect_null(s$key_state)
  expect_false(has_secret(s, k))
  expect_false(has_secret(capsule_attest(list(name = "m"), xmss_advance(k, s)), k))
  renderings <- c(deparse(s), bricklayer_json_to_json(s), rawToChar(serialize(s, NULL, ascii = TRUE)))
  expect_false(any(grepl(k$sk_seed, renderings, fixed = TRUE)))
  expect_false(any(grepl(k[["sk_prf"]], bricklayer_json_to_json(unclass(s)), fixed = TRUE)))
  # the forgery of the report has nothing to work from
  expect_error(capsule_attest(list(name = "forged"), s$key_state))
  f <- fips_keygen("ML-DSA-65")
  fs <- capsule_sign("hello", f)
  expect_false(any(grepl(f$secret %||% "no-secret-field", unlist(fs), fixed = TRUE)))
  expect_true(capsule_verify("hello", s, signing_public_key(k)))
})

test_that("Y2: xmss_advance() carries the key; one object twice is refused; the index file survives sessions", {
  withr::local_options(rmoriebricklayer.xmss_index_file = withr::local_tempfile(fileext = ".json"))
  xmss_forget_used_indices()
  k <- pqc_keygen(height = 2)
  a1 <- capsule_attest(list(n = 1), k)
  expect_null(a1$signature$key_state)
  expect_error(capsule_attest(list(n = 2), k), "already used")
  k2 <- xmss_advance(k, a1$signature)
  expect_identical(k2$next_index, 1L)
  a2 <- capsule_attest(list(n = 2), k2)
  expect_identical(a2$signature$index, 1L)
  expect_error(xmss_advance(pqc_keygen(height = 2), a1$signature), "not made by this key")
  # a "fresh session": the in-memory registry is cleared, the file is not, and index 0 is refused
  rm(list = ls(rmoriebricklayer:::.rmbl_xmss_used, all.names = TRUE), envir = rmoriebricklayer:::.rmbl_xmss_used)
  expect_error(capsule_sign("again", k), "already used")
  xmss_forget_used_indices()
  expect_false(file.exists(getOption("rmoriebricklayer.xmss_index_file")))
})

test_that("Y3: a mean without a prevalence (or the reverse) is an error report, not zero cases", {
  r <- verify_pollution("pm25", exposure_mean = 25)
  expect_identical(r$status, "error")
  expect_identical(attr(r, "exit_status"), 2L)
  expect_match(r$error, "go together")
  expect_identical(verify_pollution("no2", exposure_prevalence = 1)$status, "error")
  expect_identical(verify_pollution("pm25")$status, "error")
  ok <- verify_pollution("pm25", exposure_mean = 25, exposure_prevalence = 1)
  expect_identical(ok$status, "ok")
  expect_gt(ok$pipeline$burden$attributable_cases, 0)
  expect_identical(verify_pollution("pm25", exposure_mean = 0, exposure_prevalence = 1)$status, "ok")
})

test_that("Y4: a cue sentence ended by a newline keeps the line break", {
  H <- "UES\nAgents impliqu\u00e9s\n"
  fa <- paste0(H, "AI no 1 A particip\u00e9 à une entrevue. Le nom d'un agent impliqu\u00e9 est confidentiel\n",
               "AI no 2 N'a pas consenti à une entrevue\nAgents t\u00e9moins\n")
  fb <- paste0(H, "AI no 1 A particip\u00e9 à une entrevue. Le nom d'un agent impliqu\u00e9 est confidentiel\n",
               "Agents t\u00e9moins\nAI no 7 (narrative)\n")
  expect_equal(as.numeric(bricklayer_siu_resolve_so(fa)$count), 2)
  expect_equal(as.numeric(bricklayer_siu_resolve_so(fb)$count), 1)
  # the property, with the line-end position included
  bp <- "Le nom d'un agent impliqu\u00e9 est confidentiel"
  lines <- c("AI no 1 A particip\u00e9 à une entrevue. AI no 3 \u00e9tait pr\u00e9sent",
             "AI no 2 N'a pas consenti à une entrevue.",
             "AI no 4 A particip\u00e9 à une entrevue; AI no 5 a refus\u00e9. AI no 2 absent")
  for (ln in lines) {
    base <- as.numeric(bricklayer_siu_resolve_so(paste0(H, ln, "\nAI no 1 absent\nAgents t\u00e9moins\n"))$count)
    variants <- c(paste0(bp, ". ", ln), paste0(ln, " ", bp, "."), paste0(ln, "\n", bp), paste0(bp, "\n", ln),
                  paste0(sub("\\. ", paste0(". ", bp, ". "), ln)))
    for (v in variants) {
      got <- as.numeric(bricklayer_siu_resolve_so(paste0(H, v, "\nAI no 1 absent\nAgents t\u00e9moins\n"))$count)
      expect_identical(got, base, info = v)
    }
  }
})

test_that("Y5: a stable run of any size is the caller's to wait for; only sub-stepped runs are capped", {
  c0 <- matrix(0, 301, 301)
  c0[151, 151] <- 1
  r <- advection_diffusion_2d(c0, u = 0.5, v = 0, kx = 0, ky = 0, 1, 1, 1, 2)
  expect_s3_class(r, "rmbl_field")
  expect_equal(r$mass, 1, tolerance = 1e-12)
  err <- tryCatch(advection_diffusion_2d(matrix(1, 201, 201), u = 9999, v = 0, kx = 0, ky = 0, 1, 1, 1, 100),
                  error = function(e) conditionMessage(e))
  expect_match(err, "sub-stepping would make this run")
  expect_false(grepl(", 0", err, fixed = TRUE))
  expect_match(err, "smaller dt lowers")
  expect_error(lagrangian_particles(n = 1e300, x0 = 0, y0 = 0, u = 1, v = 0, kx = 1, ky = 1, dt = 1, n_steps = 1),
               "at most 100 million")
  expect_warning(gaussian_puff(mass = 1, u = 2, h = 10, receptors = cbind(100, 0, -1), t = 10), "below ground")
})

test_that("Y6: a frequency table with a missing level plots", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  ft <- frequency_table(data.frame(g = c("a", "b", NA)), "g")
  expect_silent(d <- plot(ft))
  expect_true(is.data.frame(d))
})

test_that("H1 and the attestation edges: edited HMAC signatures are FALSE; a missing digest and a key object work", {
  s <- capsule_sign("m", "secret", scheme = "hmac")
  expect_true(capsule_verify("m", s, "secret"))
  edits <- list(c(s$signature, s$signature), 5, "zz", substr(s$signature, 1, 10), NA_character_, list(s$signature))
  for (bad in edits) {
    t <- s
    t$signature <- bad
    expect_false(capsule_verify("m", t, "secret"))
  }
  k <- pqc_keygen(height = 2)
  at <- capsule_attest(list(name = "m"), k)
  chk <- capsule_check_attestation(at, list(name = "m"), key_expected = signing_public_key(k))
  expect_true(all(chk$checks$ok))
  at2 <- at
  at2$digest <- NULL
  chk2 <- capsule_check_attestation(at2, list(name = "m"))
  expect_false(all(chk2$checks$ok))
})

test_that("L1, L2, L3, L5 residuals: Ollama by model is announced; wrong types are errors; keys follow addresses", {
  cf_env3()
  withr::local_envvar(c(OLLAMA_MODEL = "qwen3:8b", MORIE_HOSTED_KEY = "sk-h",
                        MORIE_HOSTED_BASE_URL = "https://llm.example.org"))
  testthat::local_mocked_bindings(.bl_ollama_tags = function(base, timeout = 2) NULL, .package = "rmoriebricklayer")
  expect_message(hit <- rmoriebricklayer:::.bl_llm_route(), "not answering")
  expect_identical(hit$name, "hosted MORIE tier")
  withr::local_envvar(c(OLLAMA_MODEL = NA))
  cfg <- rmoriebricklayer:::.bl_config_path()
  dir.create(dirname(cfg), recursive = TRUE, showWarnings = FALSE)
  for (bad in c('{"route": 5}', '{"route": ["ollama", "hosted"]}', '{"route": true}', '{"route": ""}')) {
    writeLines(bad, cfg)
    expect_error(rmoriebricklayer:::.bl_read_config(), "must be a non-empty string")
  }
  unlink(cfg)
  # a credentials file without hosted_base_url (morie writes one) sends the key only to the document's address
  withr::local_envvar(c(MORIE_HOSTED_KEY = NA))
  cred <- rmoriebricklayer:::.bl_credentials_path()
  writeLines('{"hosted_key": "sk-saved", "other": ["x"], "n": null, "big": 9007199254740993}', cred)
  withr::local_envvar(c(MORIE_HOSTED_BASE_URL = "https://other.example.org"))
  expect_message(expect_null(rmoriebricklayer:::.bl_hosted_key()), "not sent to")
  withr::local_envvar(c(MORIE_HOSTED_BASE_URL = NA))
  # login and logout keep the other package's entries as they were
  withr::local_envvar(c(MORIE_HOSTED_BASE_URL = "https://llm.example.org"))
  rmoriebricklayer:::.bl_store_key("sk-new")
  flat <- function() gsub("[[:space:]]", "", paste(readLines(cred, warn = FALSE), collapse = ""))
  expect_match(flat(), '"other":\\["x"\\]')
  expect_match(flat(), '"n":null')
  expect_match(flat(), "9007199254740993")
  bricklayer_llm_logout()
  txt <- flat()
  expect_match(txt, '"other":\\["x"\\]')
  expect_false(grepl("hosted_key", txt, fixed = TRUE))
  # MORIE_DATA_URL does not receive the hosted key unless it is the document's address
  withr::local_envvar(c(MORIE_HOSTED_KEY = "sk-h", MORIE_DATA_URL = "https://elsewhere.example.org"))
  expect_message(expect_null(rmoriebricklayer:::.bl_data_key()), "not sent to it")
  withr::local_envvar(c(MORIE_DATA_URL = NA))
  expect_identical(rmoriebricklayer:::.bl_data_key(), "sk-h")
  # a saved address is one address
  for (bad in c("http://local host:1234/v1", "http://host#@evil", "http://user@host:1234/v1")) {
    expect_error(bricklayer_llm_config(own.url = bad), "plain address")
  }
  expect_error(bricklayer_llm_config(ollama.url = "http://h ost:11434"), "plain address")
})

test_that("L11 and L12: no `--token [KEY]` anywhere in the help; C1 and bidi characters never print", {
  out <- character()
  bricklayer_cli("help", out = function(s) out <<- c(out, s))
  bricklayer_cli(c("login", "--help"), out = function(s) out <<- c(out, s))
  expect_false(any(grepl("--token KEY|--token \\[KEY\\]", out)))
  expect_false(grepl("--token KEY|\\[KEY\\]", rmoriebricklayer:::.bl_access_hint()))
  for (lc in c("C", "en_US.UTF-8")) {
    r <- try(withr::with_locale(c(LC_CTYPE = lc), {
      nm <- paste0("Donn\u00e9es", "\u009b", "[31m", "\u202e", "Montr\u00e9al")
      tab <- rmoriebricklayer:::.bl_data_tables_df("db/t", nm, 3L, "x")
      txt <- rmoriebricklayer:::.bl_format_data_tables(tab, width = 100)
      expect_false(grepl("\u009b", txt, fixed = TRUE))
      expect_false(grepl("\u202e", txt, fixed = TRUE))
      expect_false(grepl("Donnes", txt, fixed = TRUE))
    }), silent = TRUE)
    if (inherits(r, "try-error")) skip(paste("locale", lc, "not available"))
  }
})

test_that("D1 gaps and M2, M4, M6, M8 leftovers", {
  dir <- withr::local_tempdir()
  f <- file.path(dir, "t.csv.gz")
  con <- gzfile(f, "wb")
  writeLines("a,b\n1,2", con)
  close(con)
  good <- core_sha256(readBin(f, "raw", file.size(f)))
  man <- function(sha) function(refresh = FALSE) list(datasets = list(list(key = "db/t", sha256 = sha)))
  testthat::local_mocked_bindings(bricklayer_data_manifest = man(paste0("sha256:", good)),
                                  .package = "rmoriebricklayer")
  expect_true(rmoriebricklayer:::.bl_data_check_sha("db/t", f))
  testthat::local_mocked_bindings(bricklayer_data_manifest = man("not-a-digest"), .package = "rmoriebricklayer")
  expect_error(rmoriebricklayer:::.bl_data_check_sha("db/t", f), "not a SHA-256")
  expect_true(file.exists(f))
  # a rebuilt table: the first manifest is stale, the refreshed one matches
  calls <- 0L
  testthat::local_mocked_bindings(bricklayer_data_manifest = function(refresh = FALSE) {
    calls <<- calls + 1L
    list(datasets = list(list(key = "db/t", sha256 = if (refresh) good else strrep("0", 64))))
  }, .package = "rmoriebricklayer")
  expect_true(rmoriebricklayer:::.bl_data_check_sha("db/t", f))
  expect_gte(calls, 2L)
  expect_warning(apply_schema_validation(data.frame(a = 1), list(scheme = list(expected_columns = "a"))), "no `schema`")
  expect_error(apply_schema_validation(data.frame(a = 1), new.env()), "provenance list")
  r <- verify_pollution("pm25", exposure_mean = 25, exposure_prevalence = 1, baseline_rate = 0.008)
  expect_identical(r$status, "assumption_failure")
  expect_true(any(grepl("per person-year", vapply(r$assumptions, function(a) a$note, ""))))
  expect_error(crf_pm25(TRUE), "not logical")
  expect_error(crf_no2(TRUE), "not logical")
  vp <- function(...) verify_pollution("pm25", exposure_prevalence = 1, ...)$status
  expect_identical(vp(exposure_mean = 1e308), "assumption_failure")
  expect_identical(vp(exposure_mean = 90000), "assumption_failure")
  expect_identical(vp(exposure_mean = as.Date("2020-01-01")), "error")
  bom <- withr::local_tempfile(fileext = ".csv")
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("exposure\n20\n30\n")), bom)
  expect_identical(verify_pollution("pm25", exposure_csv = bom)$status, "ok")
  neg <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("exposure", "20", "-5"), neg)
  r <- verify_pollution("pm25", exposure_csv = neg)
  expect_identical(r$status, "error")
  expect_match(r$error, "negative")
  expect_error(exposure_concentration_index(data.frame(e = c(1, Inf), i = c(1, 2)), "e", "i"), "finite")
  expect_equal(hurwitz_zeta(2, q = -0.5), 8.934802200544679, tolerance = 1e-9)
  expect_true(is.na(hurwitz_zeta(2, q = -1)))
  expect_error(top_share(c(1, 2, 3), fractions = 1.5), "shares in")
  expect_identical(top_share(c(1, 2, 3), fractions = 0)$units, 0L)
  expect_true(apply_schema_validation(data.frame(a = 1), NULL))
  expect_error(hill_tail_index(c(1, 5, 9, 20, 50), x_min = c(1, 2)), "single threshold")
  expect_error(rapl_available(NA), "single directory")
})

test_that("the earlier round's weak tests, sharpened", {
  # D4: the notes went on a page of their own, so the table page keeps every row
  d <- data.frame(year = 2015:2024, n = c(402, 377, 190, 268, 331, 300, 310, 290, 305, 320))
  y <- yoy(d, value = "n", period = "year")
  f <- withr::local_tempfile(fileext = ".pdf")
  yoy_pdf(y, f, notes = sprintf("note %d", 1:30), height = 5)
  bytes <- readBin(f, "raw", file.size(f))
  bytes[bytes == as.raw(0L)] <- as.raw(32L)
  expect_identical(length(gregexpr("/Type /Page[^s]", rawToChar(bytes), useBytes = TRUE)[[1L]]), 2L)
  # plots: the frequency path with an NA level (above) and the margin helper
  expect_true(is.finite(rmoriebricklayer:::.bl_left_margin(labels = c(NA, "a"))))
})

test_that("stress battery on 4b4af29: scheme edits on an HMAC secret, recorded FIPS fields, a missing reference", {
  s <- capsule_sign("m", "secret", scheme = "hmac")
  for (bad in list(NULL, "xmss-sha256", "ML-DSA-44", 5, NA)) {
    t <- s
    t$scheme <- bad
    expect_false(capsule_verify("m", t, "secret"), info = deparse(bad))
  }
  f <- fips_keygen("ML-DSA-44")
  fs <- capsule_sign("m", f)
  expect_true(capsule_verify("m", fs, f))
  for (bad in list(5, c("a", "b"), list(1), NA_character_)) {
    t <- fs
    t$context <- bad
    expect_false(capsule_verify("m", t, f), info = deparse(bad))
    t <- fs
    t$prehash <- bad
    expect_false(capsule_verify("m", t, f), info = deparse(bad))
  }
  for (r in list(NA, NaN)) {
    v <- verify_pollution("no2", exposure_mean = 25, exposure_prevalence = 1, reference = r)
    expect_identical(v$status, "assumption_failure")
  }
})

test_that("Y2b: the XMSS index record persists by default, in the package config directory", {
  withr::local_options(rmoriebricklayer.xmss_index_file = NULL)
  withr::local_envvar(RMBL_XMSS_INDEX_FILE = NA)
  expect_identical(rmoriebricklayer:::.rmbl_xmss_index_file(),
                   path.expand(file.path(tools::R_user_dir("rmoriebricklayer", "config"), "xmss_index.json")))
  withr::local_envvar(RMBL_XMSS_INDEX_FILE = "")
  expect_null(rmoriebricklayer:::.rmbl_xmss_index_file())
  withr::local_options(rmoriebricklayer.xmss_index_file = FALSE)
  expect_null(rmoriebricklayer:::.rmbl_xmss_index_file())
  # the file written by one "session" is read by the next: a reloaded stale key is refused
  f <- withr::local_tempfile(fileext = ".json")
  withr::local_options(rmoriebricklayer.xmss_index_file = f)
  k <- pqc_keygen(height = 2)
  saved <- k
  a <- capsule_attest(list(n = 1), k)
  expect_true(file.exists(f))
  xmss_forget_used_indices()   # removes the file too; recreate the record as another session would
  rmoriebricklayer:::.bl_write_private_json(f, setNames(list(a$signature$index), paste0(k$root, ":", k$pub_seed)))
  expect_error(capsule_attest(list(n = 2), saved), "already used")
  expect_s3_class(capsule_attest(list(n = 2), xmss_advance(saved, a$signature)), "bricklayer_attestation")
  # a file that is not a JSON object is reported, not read around
  xmss_forget_used_indices()
  writeLines("[1, 2]", f)
  expect_error(capsule_sign("m", pqc_keygen(height = 2)), "not a JSON object")
  xmss_forget_used_indices()
})

test_that("a stack at ambient temperature has no buoyancy and no rise, a cooler one is refused", {
  r <- briggs_plume_rise(c(0, 100, 1000), 3, 2, 10, 290, 290)
  expect_identical(r$flux, 0)
  expect_identical(r$rise, c(0, 0, 0))
  expect_error(briggs_plume_rise(100, 3, 2, 10, 280, 290), "hotter")
})

test_that("a line typed at a terminal in a non-interactive session is read by a shell child, so Ctrl-C lands", {
  skip_on_os("windows")
  calls <- character()
  testthat::local_mocked_bindings(.bl_interactive = function() FALSE, .bl_stdin_tty = function() TRUE)
  testthat::local_mocked_bindings(
    system2 = function(command, args = character(), ...) {
      calls <<- c(calls, command)
      if (identical(command, "sh")) " sk-typed " else invisible(0L)
    },
    .package = "base"
  )
  msg <- utils::capture.output(got <- .bl_readline("key> "), type = "message")
  expect_equal(got, "sk-typed")
  expect_true("sh" %in% calls)
  expect_true(any(grepl("key>", msg, fixed = TRUE)))
})

test_that("an XMSS object that still carries key_state (0.5.9 to 7703a04) is verified with a warning", {
  k <- pqc_keygen(height = 2)
  s <- capsule_sign("m", k)
  s$key_state <- list(sk_seed = k$sk_seed, sk_prf = k[["sk_prf"]], next_index = 1L)
  expect_warning(ok <- capsule_verify("m", s, signing_public_key(k)), "carries the signer")
  expect_true(ok)
  a <- capsule_attest(list(n = 1), xmss_advance(k, s))
  a$signature$key_state <- s$key_state
  expect_warning(capsule_check_attestation(a, list(n = 1)), "carries the signer")
})
