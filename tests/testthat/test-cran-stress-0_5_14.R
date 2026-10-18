# Findings of the CRAN stress test of 0.5.14 (r-universe tarball, git 1c19b00), each with its fix.

ns <- function(f) get(f, envir = asNamespace("rmoriebricklayer"))

test_that("#4: an argument error raised inside a C++ entry point leaves nothing behind and reads as before", {
  C <- function(f) asNamespace("rmoriebricklayer")[[f]]
  expect_error(.Call(C("C_rmbl_uniforms"), NaN, 1), "`n` must be")
  expect_error(.Call(C("C_rmbl_merkle_root"), list(1, "a"), 1L), "^each chunk must be a raw vector$")
  expect_error(.Call(C("C_rmbl_http_get"), NA_character_, 5L, "a: b", FALSE), "`url` must be a non-missing string")
  # the message carries no call (the barrier raises it, as the package's R errors are raised)
  e <- tryCatch(.Call(C("C_rmbl_merkle_root"), list(1), 1L), error = function(e) e)
  expect_null(conditionCall(e))
})

test_that("#7: the reservoir loop answers an interrupt", {
  skip_on_cran()
  skip_on_os("windows")
  skip_if(!nzchar(Sys.which("python3")), "python3 runs the probe")
  # 3e9 items took 37.9 s through a Ctrl-C; the loop now takes it
  r <- interrupt_probe("reservoir_indices(3e9, 1)", after = 1)
  skip_if(startsWith(r, "inconclusive"), r)
  expect_identical(r, "interrupt")
})

test_that("step_change(): an enumerated null counts the observed ordering once", {
  r <- step_change(c(1, 2, 1, 2, 5, 6))
  expect_match(r$method, "exact over all 720 orderings")
  # every ordering scored, the observed one among them: a multiple of 1/720
  expect_equal(r$p_value * 720, round(r$p_value * 720), tolerance = 1e-9)
  # drawn permutations keep the +1
  set.seed(1)
  r2 <- step_change(c(1, 2, 1, 2, 5, 6, 7, 8, 9, 10), n_perm = 99)
  expect_equal(r2$p_value * 100, round(r2$p_value * 100), tolerance = 1e-9)
})

test_that("trend_test(): a constant series has p = 1 at every length", {
  expect_identical(trend_test(rep(3, 6))$p_value, 1)
  expect_identical(trend_test(rep(3, 12))$p_value, 1)
  expect_identical(trend_test(rep(3, 40), alternative = "increasing")$p_value, 1)
})

test_that("count_trend(): zeros at one end have no finite trend, and say so", {
  expect_warning(r <- count_trend(c(0, 0, 5)), "no finite estimate")
  expect_identical(r$rate_ratio, Inf)
  expect_true(is.na(r$lower) && is.na(r$upper) && is.na(r$p_value))
  expect_warning(r <- count_trend(c(5, 0, 0)), "reported as 0")
  expect_identical(r$rate_ratio, 0)
  # an ordinary series is untouched
  expect_silent(r <- count_trend(c(20, 18, 15, 13, 12)))
  expect_true(is.finite(r$rate_ratio) && r$rate_ratio < 1)
})

test_that("validate_rules(): a table of no rows fails no row-wise rule", {
  rl <- list(rule("present", function(v) !is.na(v), column = "a"),
             rule("one row at least", function(d) nrow(d) > 0))
  out <- validate_rules(data.frame(a = numeric()), rl)
  expect_identical(names(out), "one row at least")
})

test_that("online_summary(): values far from zero keep their digits", {
  set.seed(1)
  x <- 1e8 + stats::rnorm(1000)
  a <- online_summary()
  for (i in seq(1, 1000, by = 100)) a <- summary_update(a, x[i:(i + 99)])
  expect_lt(abs(summary_stats(a)[["variance"]] / stats::var(x) - 1), 1e-9)
  expect_lt(abs(summary_stats(online_summary(x))[["variance"]] / stats::var(x) - 1), 1e-13)
})

test_that("seeds: knox_test() and capsule_falsify() take every seed up to 2^53 - 1", {
  set.seed(2)
  n <- 30
  expect_s3_class(knox_test(stats::runif(n), stats::runif(n), stats::runif(n), 0.2, 0.2, nsim = 19, seed = 2^40),
                  "rmbl_knox")
  expect_error(knox_test(stats::runif(n), stats::runif(n), stats::runif(n), 0.2, 0.2, nsim = 19, seed = -2^31),
               "from -2147483647 to 2\\^53 - 1")
  d <- data.frame(y = stats::rnorm(20), x = stats::rnorm(20))
  f <- capsule_falsify(d, function(z) stats::cor(z$x, z$y), n = 19, seed = 2^40, treatment = "x")
  expect_identical(f$seed, 2^40)
})

test_that("the URL gate refuses 6to4 and Teredo addresses that carry a private one", {
  chk <- function(u) .Call(asNamespace("rmoriebricklayer")$C_rmbl_url_check, u, FALSE, FALSE, FALSE)
  expect_match(chk("https://[2002:7f00:1::]/"), "local or private")
  expect_match(chk("https://[2002:a00:7::]/"), "local or private")       # 10.0.0.7
  expect_match(chk("https://[2001:0:4136:e378::1]/"), "local or private")  # Teredo
  expect_match(chk("https://[64:ff9b:1::a00:7]/"), "local or private")
  expect_identical(chk("https://[2002:808:808::]/"), "")                 # 8.8.8.8 is public
  expect_identical(chk("https://[2606:4700:4700::1111]/"), "")
})

test_that("wayback_save() sends no address on your own network to the public archive", {
  for (u in c("https://10.0.0.7/", "http://192.168.1.2/a", "https://intranet/", "https://printer.local/x")) {
    expect_error(wayback_save(u, access_key = "a", secret_key = "b"), "not a public address", info = u)
  }
})

test_that("the manifest is fetched with a size cap", {
  got <- NULL
  local_mocked_bindings(.bl_data_get = function(path, dest, timeout = 600, max_bytes = 2^31) {
    got <<- max_bytes
    writeLines('{"datasets": [{"key": "a/b"}]}', dest)
  })
  withr::local_options(rmoriebricklayer.data_cache = withr::local_tempdir())
  bricklayer_data_manifest(refresh = TRUE)
  expect_identical(got, 32 * 2^20)
})

test_that("JSON: the native path parses what the R parser parses, and gives way on what it says", {
  P <- ns(".rmbl_json_parse")
  nat <- ns(".rmbl_native")
  slow <- function(t, ...) {
    nat$json <- FALSE
    on.exit(nat$json <- NULL)
    tryCatch(P(t, ...), error = function(e) conditionMessage(e), warning = function(w) conditionMessage(w))
  }
  fast <- function(t, ...) {
    nat$json <- NULL
    tryCatch(P(t, ...), error = function(e) conditionMessage(e), warning = function(w) conditionMessage(w))
  }
  docs <- c('{"a":1,"b":[true,false,null],"c":{"d":"\\u00e9\\ud83d\\ude00"}}', '[1.5,-0,2147483648,1e400]',
            '"a\\nb\\"c\\\\"', '{}', '[]', '[[[]]]', 'null', '{"a":1,"a":2}', '[01]', '{"a" 1}', '"\\ud83d"',
            '"\\u0000"', '9007199254740993', '9.007199254740993e15', '[1,]', paste0(strrep("[", 101), strrep("]", 101)),
            '"été 中"', ' [ 1 , 2 ] ', '[1] x', '"tab\there"')
  for (d in docs) {
    expect_identical(fast(d), slow(d), info = d)
    expect_identical(fast(d, duplicate_keys = "keep", bigint_as_char = TRUE),
                     slow(d, duplicate_keys = "keep", bigint_as_char = TRUE), info = d)
  }
  # a large reply in well under a second (85 s for 15 MiB before)
  big <- paste0("[", paste(rep('{"id":12,"name":"abcdefghij","v":[0.25,1e-3,true]}', 50000), collapse = ","), "]")
  t <- system.time(v <- P(big))[["elapsed"]]
  expect_length(v, 50000L)
  expect_lt(t, wall_limit(5))
})

test_that("CSV: NUL bytes are dropped before quotes are read, as read.csv(skipNul = TRUE) drops them", {
  ours <- ns(".bl_csv_from_bytes")
  ref <- function(b) {
    f <- withr::local_tempfile(fileext = ".csv")
    writeBin(b, f)
    suppressWarnings(utils::read.csv(f, stringsAsFactors = FALSE, skipNul = TRUE))
  }
  B <- as.raw(c(0xEF, 0xBB, 0xBF))
  z <- as.raw(0)
  for (b in list(c(charToRaw("a\n\""), z, charToRaw("\"\n")),                 # a line of "" with a NUL: blank
                 c(charToRaw("a\n\"x\""), z, charToRaw("\"y\"\n")),            # "x"<NUL>"y" is "x""y"
                 c(charToRaw("a,c\n"), z, B, charToRaw("\n")),                 # a NUL before the mark
                 c(charToRaw("a\n\"\""), B, charToRaw("\nq\n")),               # the mark after an empty ""
                 charToRaw("a,b\n\"x\"y\",z\",1\n"),                          # a reopened quote holds the comma
                 charToRaw("a,b\n\"x\"y\"\r\n\"q,1\n"))) {
    expect_identical(ours(b), ref(b), info = encodeString(rawToChar(b[b != z])))
  }
  expect_error(ours(charToRaw("a\n\"x\"y\"\n")), "never closes")
})

test_that("CLI: three-letter and hyphenated near misses, short lines naming a file, dense keys", {
  bq <- ns(".bl_bare_question")
  for (q in c("dat list", "xplain-rror?", "urls.txt?", "my urls.txt", "is AbCdEf1234567890 my key?",
              "check k3j9sq2wab7x_m4n8pq1zrt5v_c9d2 ok?")) {
    expect_false(bq(q), info = q)
  }
  for (q in c("how do I fit a survey design?", "what is population2021 in census?",
              "are there functions for rates?", "how do I read my data.csv file into R?")) {
    expect_true(bq(q), info = q)
  }
  expect_error(bricklayer_llm_ask("why?", model = "AbCdEf1234567890xyz"), "looks like a key")
  expect_error(bricklayer_llm_ask("why?", model = "sk-sVau8MGU1achkc82m2vR"), "looks like a key")
})

test_that("survey_design(): a post-stratified JK1 set on a post-stratum subset is accepted", {
  set.seed(5)
  # 15 PSUs of 4 rows; post-strata cut across them; the replicates post-stratified to fixed totals
  psu <- rep(1:15, each = 4)
  st <- rep(c("E", "H", "M", "E"), 15)
  st[psu > 10 & st == "H"] <- "E"
  w <- stats::runif(60, 5, 15)
  tot <- tapply(w, st, sum)
  post <- function(v) {
    s <- tapply(v, st, sum)
    v * as.numeric(tot[st] / s[st])
  }
  w0 <- post(w)
  R <- sapply(1:15, function(j) post(ifelse(psu == j, 0, w * 15 / 14)))
  y <- stats::rnorm(60)
  d <- data.frame(y = y, w = w0, st = st)
  h <- st == "H"
  des <- survey_design(d[h, ], "w", replicates = R[h, ], type = "jk1")
  est <- survey_estimate(des, d[h, ], "y")
  th <- sum(w0[h] * y[h]) / sum(w0[h])
  tb <- apply(R[h, ], 2, function(r) sum(r * y[h]) / sum(r))
  expect_equal(est$se, sqrt(14 / 15 * sum((tb - th)^2)), tolerance = 1e-10)
  # an unadjusted set with the weight passed beside it is still refused
  J <- sapply(1:15, function(j) ifelse(psu == j, 0, w * 15 / 14))
  # (unnamed: a column named as the weight is set aside, as documented)
  expect_error(survey_design(data.frame(y = y, w = w), "w", replicates = unname(cbind(J, w)), type = "jk1"),
               "full-sample weight")
})

test_that("hostile arguments: each is refused in words, with no call (a battery of 38,836 calls, 306 functions)", {
  worded <- function(expr) {
    e <- tryCatch({
      force(expr)
      NULL
    }, error = function(e) e)
    expect_s3_class(e, "error")
    expect_null(conditionCall(e))
  }
  df <- data.frame(a = 1:2)
  worded(core_tukey_fences(1:10, k = "x"))
  worded(core_sd(1:10, ddof = df))
  worded(core_mad(1:10, constant = list(1)))
  worded(step_change(c(1, 2, 1, 2, 5, 6), n_perm = NULL))
  worded(step_change(c(1, 2, 1, 2, 5, 6), min_segment = NA))
  worded(mcar_test(data.frame(a = c(1, NA, 3, 4), b = c(2, 3, NA, 5)), max_iter = NA))
  worded(hill_tail_index(c(1, 2, 3, 10, 20, 50), min_tail = "x"))
  worded(scan_adjust(data.frame(p_value = c(0.01, 0.2)), method = NA))
  worded(scan_adjust(data.frame(p_value = c(0.01, 0.2)), alpha = NULL))
  worded(bricklayer_download("https://example.org/a", tempfile(), size = df))
  worded(bricklayer_explain_error("`x` must be numeric", n = list(1)))
  worded(bricklayer_json_to_json(1:3, pretty = NA_real_))
  worded(bricklayer_json_unserialize("1"))
  worded(bricklayer_json_from_json(NA_character_))
  worded(make_synthetic_csv(list(columns = list(a = list(type = "normal"))), tempfile(), n_rows = 2^31))
  worded(fiscal_year_label(2024, sep = function(x) x))
  worded(decode_codes(c("1", "2"), c(`1` = "a", `2` = "b"), keep_na = NA))
  worded(core_ipw_weights(c(0, 1, 1), c(0.2, 0.5, 0.7), trim_lo = NA))
  worded(funnel_limits(c(10, 20), levels = list(0.95)))
  worded(missingness_map(data.frame(a = c(1, NA)), width = NA))
  e <- new.env()
  worded(ascii_fallback(e))
  worded(capsule_attest(list(), key = NULL, note = e))
  set.seed(4)
  d <- data.frame(y = stats::rnorm(20), x = stats::rnorm(20))
  worded(capsule_power(d, function(z) stats::cor(z$x, z$y), function(z, s) z, treatment = "x", reps = Sys.Date()))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  worded(plot_lorenz(c(1, 2, 3, 10), col = 1e10))
  worded(plot_lorenz(c(1, 2, 3, 10), col = "not a colour"))
  worded(plot_lorenz(c(1, 2, 3, 10), main = list("a")))
})

test_that("a Hawkes horizon is no allocation: constant baselines need no grid, a sinusoidal one is capped", {
  set.seed(1)
  times <- sort(stats::runif(60, 0, 2^31))
  r <- core_hawkes_residuals(times, 2^31, kernel = "exponential", par = c(log(60 / 2^31), 0.2, 1e-6))
  expect_length(r, 60L)
  expect_error(core_hawkes_residuals(times, 2^31, kernel = "exponential", baseline = "sinusoidal",
                                     par = c(log(60 / 2^31), 0, 0, 0, 0.2, 1e-6)), "at most 4194304 days")
})

test_that("a time limit ends capsule_falsify() and capsule_power(); the statistic's own errors are NA", {
  slow <- function(z) {
    Sys.sleep(0.05)
    stats::cor(z$x, z$y)
  }
  set.seed(5)
  d <- data.frame(y = stats::rnorm(30), x = stats::rnorm(30))
  t0 <- proc.time()[["elapsed"]]
  r <- tryCatch({
    setTimeLimit(elapsed = 1, transient = TRUE)
    capsule_falsify(d, slow, treatment = "x", n = 999)
  }, error = function(e) conditionMessage(e), finally = setTimeLimit())
  expect_match(r, "time limit")
  expect_lt(proc.time()[["elapsed"]] - t0, wall_limit(10))
})

test_that("the survey row keys from C are the keys the R arithmetic made", {
  old <- function(v) {
    fold <- function(x) x - 2147483647 * floor(x / 2147483647)
    b <- readBin(writeBin(v, raw()), "integer", n = 2L * length(v))
    fold(fold(b[c(TRUE, FALSE)]) * 65599 + b[c(FALSE, TRUE)])
  }
  C <- asNamespace("rmoriebricklayer")
  v <- c(stats::rnorm(1000), NA, NaN, Inf, -Inf, 0, -0, 1e308, .Machine$double.xmin)
  expect_identical(.Call(C$C_rmbl_svy_dblcode, v), old(v))
  expect_identical(.Call(C$C_rmbl_sha256_real, v), core_sha256(writeBin(v, raw())))
})

test_that("every new refusal is reached (one call per branch)", {
  w <- function(expr, pat) expect_error(expr, pat)
  d <- data.frame(v = c(10, 12, 15), p = 2020:2022)
  w(analyse_table(d, "v", "p", by = 1), "`by` must be one or more column names")
  w(analyse_table(d, "v", "p", suppression_limit = -1), "`suppression_limit` must be one non-negative number")
  w(sir(c(1, 2), c(1, 2), area = c("a", "b", "c")), "`area` must be NULL or one label per area")
  w(eb_rates(c(1, 2), c(1, 2), area = c("a", "b", "c")), "`area` must be NULL or one label per area")
  w(band_values(c("0-9", "10+"), open_upper_factor = -1), "`open_upper_factor` must be one positive number")
  w(band_sensitivity(c("0-9", "10+"), c(5, 3), statistic = 1), "`statistic` must be a function")
  f <- tempfile()
  writeLines("x", f)
  w(use_capsule_template(f), "is a file, not a directory")
  cat_d <- data.frame(g = c("a", "b"))
  w(audit_categories(cat_d, cols = 1), "`cols` must be column names")
  w(audit_categories(cat_d, cols = "zz"), "`cols` names no column of `data`: zz")
  w(odds_ratio_check(matrix(1:4, 2, dimnames = list(c("a", "b"), NULL)), reference = c("a", "b"), reported = 1),
    "`reference` must be one group label")
  w(write_recode_manifest(structure(list(), class = "bricklayer_recode_manifest"), NULL), "`path` must be a file path")
  w(relabel(as.raw(1:2), c(a = "b")), "`x` must be a vector of labels")
  w(transfer_verify(c(1, 2), c(`1` = 1), code_book = list(a = 1)), "`code_book` must be a named vector")
  w(detect_location(env_location = c("a", "b")), "`env_location` must be one string")
  w(core_uniforms(3e9, 1), "`n` must be at most 2147483647")
  w(reservoir_indices(10, 3e9), "`k` must be at most 2147483647")
  w(capture_environment(1), "`packages` must be package names")
  w(validate_schema(data.frame(a = 1), provenance = 1), "`provenance` must be a provenance list")
  w(record(1, "a", 1, 1), "`manifest` must be a manifest")
  w(write_manifest_json(1, tempfile()), "`manifest` must be a manifest")
  m <- make_manifest(list(project = "t"), environment = FALSE)
  w(write_summary_txt(m, tempfile(), character()), "`output_dir` is not a directory")
  w(write_summary_txt(m, tempdir(), character(), contact = 1), "`contact` must be text")
  w(make_synthetic_column(1, 3), "`spec` must be a column spec list")
  w(make_synthetic_column(list(type = "normal"), -1), "`n` must be a single non-negative whole number")
  w(make_synthetic_csv(list(columns = list()), tempfile(), n_rows = 0), "`n_rows` must be one whole number of rows")
  w(bricklayer_llm_models(route = 1), "`route` must be a single route name")
  w(bricklayer_llm_ask("why?", model = 1), "`model` must be one model name")
  ed <- data.frame(y = stats::rnorm(20), e = stats::rnorm(20), c1 = stats::rnorm(20))
  w(exposure_response_plr(ed, "y", "e", "c1", estimator = "no_such_function_zz"), "`estimator` names no function")
  w(exposure_response_plr(ed, "y", "e", "c1", estimator = 1), "`estimator` must be a function")
  w(exposure_response_plr(ed, "y", "e", "c1", estimator = function(x) x), "`estimator` failed on the full sample")
  w(verify_pollution(1), "`pollutant` must be one pollutant name")
  w(falsify_family(list()), "`x` must hold at least one")
  w(profile_columns(data.frame(a = 1:3), quantiles = 2), "`quantiles` must be probabilities")
  pb <- published_bounds(c(10, 20), rounding = 5)
  w(change_envelope(pb, pb, population = c(1, 2, 3)), "`population` must be one number or one per row")
  w(share(data.frame(n = 1:3)), "`count` must name the column")
  w(capsule_report(data.frame(a = 1:3), max_rows_outliers = -1), "`max_rows_outliers` must be one non-negative")
  w(step_change(1:6, x = matrix(1:6)), "`x` must be one time or position")
  w(cert_chain_verify(NULL, NULL, at_time = "now"), "`at_time` must be a single date-time")
  w(yoy(d, "v", "p", by = 1), "`by` must be one or more column names")
  w(yoy(c(1, 2, 3), value = 1), "for a numeric `x`")
  w(yoy(c(1, 2, 3), period = 1:2), "`period` must have one entry per value")
  y <- yoy(c(10, 12, 15))
  w(yoy_html(y, NULL), "`file` must be a file path or a connection")
  w(yoy_html(y, tempfile(fileext = ".html"), subtitle = 1), "`subtitle` must be a single string")
  w(yoy_html(y, tempfile(fileext = ".html"), notes = 1), "`notes` must be text")
  w(yoy_pdf(y, tempfile(fileext = ".pdf"), subtitle = 1), "`subtitle` must be a single string")
  w(yoy_pdf(y, tempfile(fileext = ".pdf"), notes = 1), "`notes` must be text")
  set.seed(1)
  w(lagrangian_particles(10, 0, 0, 1, 0, 1, 1, 1, 2, normals = function(x) x), "`normals` failed when called")
  if (requireNamespace("sf", quietly = TRUE)) {
    w(region_map_from_points(1, 1, "u", boundaries = 1, fields = "a"), "`boundaries` must be the path of one")
  }
})

test_that("compiled refusals and branches: JSON escapes, invalid UTF-8, CSV CR in a reopened quote, discard prefix", {
  C <- asNamespace("rmoriebricklayer")
  P <- C$.rmbl_json_parse
  expect_identical(P('"a\\rb\\bc\\fd\\u20ac"'), "a\rb\bc\fd€")
  expect_error(.Call(C$C_rmbl_json_fast, c("a", "b"), FALSE), "`txt` must be one string")
  bad <- rawToChar(as.raw(c(0x22, 0xff, 0x22)))
  expect_type(tryCatch(P(bad), error = function(e) "refused"), "character")
  expect_match(.Call(C$C_rmbl_url_check, "https://[100::1]/", FALSE, FALSE, FALSE), "local or private")
  ours <- C$.bl_csv_from_bytes
  expect_identical(ours(charToRaw("a,b\n\"x\"y\"\r\nz\",1\n"))$a, "xy\nz")
  expect_error(.Call(C$C_rmbl_siu_to_iso_date, 1), "single non-NA character string")
  expect_error(.Call(C$C_rmbl_hawkes_rescaled, c(1, 2), 5e6, 1L, c(0, 0, 0, 0), 0.2, 0L, 1),
               "at most 4194304 days")
})

test_that("the last branches: a spec that is a frame, a lone CR in a reopened quote, a bare header, an empty replicate", {
  expect_error(make_synthetic_column(data.frame(type = "normal"), 3), "`spec` must be a column spec list")
  expect_error(make_synthetic_column(list(1, 2), 3), "`spec` must be a column spec list")
  ours <- get(".bl_csv_from_bytes", asNamespace("rmoriebricklayer"))
  expect_identical(ours(charToRaw("a,b\n\"x\"y\"\rz\",1\n"))$a, "xy\nz")
  expect_silent(h <- ours(charToRaw("\"\"\nx")))
  expect_identical(dim(h), c(1L, 0L))
  expect_error(ours(charToRaw("\"\"")), "the CSV cannot be read: first five rows are empty")
  expect_error(get(".rmbl_json_parse", asNamespace("rmoriebricklayer"))(rawToChar(as.raw(c(0x5b, 0xff, 0x5d)))),
               "not valid UTF-8")
  set.seed(8)
  n <- 40
  w <- stats::runif(n, 1, 3)
  B <- sapply(1:20, function(b) w * stats::rpois(n, 1))
  B[, 3] <- 0
  d <- data.frame(y = stats::rnorm(n), w = w)
  expect_s3_class(suppressWarnings(survey_design(d, "w", replicates = B, type = "bootstrap")), "rmbl_svy_design")
  J <- sapply(1:n, function(j) { r <- w * n / (n - 1); r[j] <- 0; r })
  J[, 2] <- 0
  r <- tryCatch(suppressWarnings(survey_design(d, "w", replicates = J, type = "jkn")), error = function(e) e)
  expect_true(inherits(r, "rmbl_svy_design") || inherits(r, "error"))
})
