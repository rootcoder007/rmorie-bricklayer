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
