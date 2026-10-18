# The 0.5.13 performance and progress leftovers: SLH-DSA signing and core_bootstrap_mean() poll for
# a Ctrl-C (and so turn the busy spinner), sha256_file() streams its file, bricklayer_llm_config()
# builds its tables once, and plr_crossfit() fits its nuisances by normal equations. Each output is
# checked against what 0.5.13 returned before the change.

lo_ns <- function(name) get(name, envir = asNamespace("rmoriebricklayer"))

test_that("SLH-DSA signatures are the bytes 0.5.13 produced (the polls change nothing)", {
  # sha256 of the signature of "bricklayer leftovers" under a fixed seed and opt_rand, recorded
  # with 0.5.13 before the interrupt polls were added
  pinned <- c(
    "SLH-DSA-SHA2-128f" = "8caba627168250223b1d858dfc2b5be56b422f7c1dfe8e325220d73bad80e68d",
    "SLH-DSA-SHA2-192f" = "1729f36c4569b2e783b521e57aee207221fe5b496fd880dfbc533f81da3e5586",
    "SLH-DSA-SHAKE-128f" = "1fa3e3dbf842c0bf4d95bdfed45e89116a3df7c118b0bf94d0fa6a4331bf228f",
    "SLH-DSA-SHAKE-128s" = "17af79dfccc26fc7154476ac1424bb3690bfb2c0d5a57ee870d74fc23f64119b"
  )
  for (sc in names(pinned)) {
    sz <- fips_sizes(sc)
    k <- fips_keygen(sc, seed = as.raw((seq_len(sz[["seed"]]) * 7L) %% 256L))
    sig <- lo_ns(".rmbl_fips_sign")(sc, lo_ns(".rmbl_hex_to_raw")(k$secret), charToRaw("bricklayer leftovers"),
                                    raw(0), as.raw(seq_len(sz[["opt_rand"]])))
    expect_identical(core_sha256(sig), pinned[[sc]], info = sc)
    expect_true(lo_ns(".rmbl_fips_verify")(sc, lo_ns(".rmbl_hex_to_raw")(k$public),
                                           charToRaw("bricklayer leftovers"), raw(0), sig), info = sc)
  }
})

test_that("core_bootstrap_mean() gives the 0.5.13 replicates for the same seed", {
  # recorded with 0.5.13, before the kernel polled for an interrupt
  expect_identical(sprintf("%a", core_bootstrap_mean(c(1, 5, 2, 8), 50, seed = 3)[1:6]),
                   c("0x1.4p+1", "0x1.cp+1", "0x1.8p+0", "0x1p+2", "0x1.ap+2", "0x1p+1"))
  set.seed(3)
  x <- stats::rnorm(20000)
  reps <- core_bootstrap_mean(x, 60L, seed = 11)
  # the resamples are the same on every platform (Lemire's draw on mt19937_64); the sums run in
  # long double, which is 80-bit on x86 and plain double on arm64, so the means agree to rounding
  expect_equal(reps[1:2], c(-0x1.564a2aa5fd3d7p-6, -0x1.9dbc36011be11p-7), tolerance = 1e-12)
  # a poll falls every 52 replicates at n = 20000: the replicates on both sides of it follow the
  # same stream as a run too short to poll
  expect_identical(reps[1:40], core_bootstrap_mean(x, 40L, seed = 11))
  expect_true(all(is.nan(core_bootstrap_mean(numeric(0), 3))))
})

test_that("sha256_file() streams: empty, small, exact chunk multiples and one byte past", {
  stream <- lo_ns(".rmbl_sha256_stream")
  d <- withr::local_tempdir()
  whole <- function(f) core_sha256(readBin(f, "raw", n = max(1, file.info(f)$size)))
  f0 <- file.path(d, "empty")
  writeBin(raw(0), f0)
  expect_identical(sha256_file(f0), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
  f1 <- file.path(d, "small")
  writeBin(charToRaw("hello capsule\n"), f1)  # bytes, not text: Windows would write \r\n
  expect_identical(sha256_file(f1), "55d6110230c260319d580bb6274db530b7e751c4f687fc00d0736ec531260a02")
  set.seed(9)
  bytes <- as.raw(sample.int(256L, 4096L * 3L + 1L, replace = TRUE) - 1L)
  for (len in c(64L, 4096L, 8192L, 4096L * 3L, 4096L * 3L + 1L, 63L, 65L, 1L)) {
    f <- file.path(d, sprintf("f%d", len))
    writeBin(bytes[seq_len(len)], f)
    ref <- whole(f)
    expect_identical(sha256_file(f), ref, info = len)
    # chunks of 64 bytes (a block), 4096 (the file a multiple of it) and 100 (not a block size)
    for (ch in c(64L, 4096L, 100L)) expect_identical(stream(f, chunk = ch), ref, info = paste(len, ch))
  }
  # the default 8 MB chunk: a file of exactly one chunk, and one byte more
  fb <- file.path(d, "eight")
  writeBin(as.raw(rep(1:255, length.out = 8388608L)), fb)
  expect_identical(sha256_file(fb), whole(fb))
  con <- file(fb, "ab")
  writeBin(as.raw(7L), con)
  close(con)
  expect_identical(sha256_file(fb), whole(fb))
  # the state between chunks is checked, not trusted
  expect_error(.Call(lo_ns("C_rmbl_sha256_chunk"), as.raw(1:3), NULL, TRUE), "SHA-256 state")
  expect_error(.Call(lo_ns("C_rmbl_sha256_chunk"), NULL, "text", FALSE), "raw vector or NULL")
  bad <- .Call(lo_ns("C_rmbl_sha256_chunk"), NULL, as.raw(1:10), FALSE)
  bad[65L] <- as.raw(200L)   # datalen past a block
  expect_error(.Call(lo_ns("C_rmbl_sha256_chunk"), bad, NULL, TRUE), "SHA-256 state")
  expect_error(sha256_file(d), "is not a file")
})

test_that("sha256_file() shows a byte bar for a file larger than one chunk", {
  stream <- lo_ns(".rmbl_sha256_stream")
  d <- withr::local_tempdir()
  f <- file.path(d, "big.bin")
  writeBin(as.raw(rep(3L, 4000L)), f)
  withr::local_options(morie.progress = TRUE, morie.quiet = FALSE)
  st <- lo_ns(".bl_progress_state")
  old <- st$delay
  st$delay <- 0
  on.exit(st$delay <- old, add = TRUE)
  local_mocked_bindings(.bl_stderr_tty = function() FALSE)
  f2 <- function() stream(f, chunk = 1000L)
  msg <- capture.output(h <- f2(), type = "message")
  expect_identical(h, core_sha256(readBin(f, "raw", 4000L)))
  expect_true(any(grepl("sha256 big.bin: 4000 of 4000 (100%)", msg, fixed = TRUE)))
})

# bricklayer_llm_config() before the caches: the settings table and every value rebuilt from the
# presets and the settings file on each lookup (0.5.13's .bl_config_spec, .bl_config_value,
# .bl_config_effective and .bl_config_source, kept here verbatim but for the namespace lookups)
old_llm_config <- function() {
  spec <- lo_ns(".bl_config_spec_build")()
  value <- function(env) {
    key <- spec$key[match(env, spec$env)]
    if (is.na(key)) return(NULL)
    v <- lo_ns(".bl_read_config")()[[key]]
    if (is.character(v) && length(v) == 1L && nzchar(trimws(v))) trimws(v) else NULL
  }
  env1 <- function(name) {
    v <- trimws(Sys.getenv(name, unset = ""))
    if (nzchar(v)) v else value(name)
  }
  mask <- lo_ns(".bl_mask")
  printable <- lo_ns(".rmbl_printable")
  effective <- function(key) {
    fixed <- switch(key,
      route = {
        r <- env1("MORIE_LLM_ROUTE") %||% "auto"
        if (identical(tolower(r), "hosted")) "auto (the saved route `hosted` is retired and ignored)" else r
      },
      own.url = env1("MORIE_LLM_BASE_URL") %||% "(not set)",
      own.key = mask(env1("MORIE_LLM_API_KEY")),
      own.model = env1("MORIE_LLM_MODEL") %||% "(not set)",
      ollama.url = env1("OLLAMA_HOST") %||% env1("OLLAMA_BASE_URL") %||% "http://localhost:11434",
      ollama.model = env1("OLLAMA_MODEL") %||% "(the first one pulled)",
      ollama.key = mask(env1("OLLAMA_API_KEY")),
      NULL)
    if (!is.null(fixed)) return(printable(fixed))
    id <- sub("[.](key|model)$", "", key)
    if (endsWith(key, ".key")) return(mask(lo_ns(".bl_preset_key")(id)))
    pr <- lo_ns(".bl_preset")(id)
    printable(env1(lo_ns(".bl_preset_model_env")(id)) %||%
                (if (!is.na(pr$default_model)) pr$default_model else "(not chosen)"))
  }
  source <- function(key, env) {
    if (nzchar(trimws(Sys.getenv(env, unset = "")))) return("environment")
    if (!is.null(value(env))) "saved" else "default"
  }
  data.frame(key = spec$key, value = vapply(spec$key, effective, "", USE.NAMES = FALSE),
             source = mapply(source, spec$key, spec$env, USE.NAMES = FALSE), env = spec$env,
             help = spec$help, stringsAsFactors = FALSE)
}

test_that("bricklayer_llm_config() reads the same table as before its caches", {
  provider_vars <- c(unlist(lo_ns(".bl_llm_presets")()[, c("key_env", "alt_env")]),
                     paste0("MORIE_", toupper(lo_ns(".bl_llm_presets")()$id), "_MODEL"))
  provider_vars <- provider_vars[nzchar(provider_vars)]
  withr::local_envvar(c(stats::setNames(rep(NA, length(provider_vars)), provider_vars),
                        MORIE_LLM_BASE_URL = NA, MORIE_LLM_API_KEY = NA, MORIE_LLM_MODEL = NA,
                        MORIE_LLM_ROUTE = NA, OLLAMA_HOST = NA, OLLAMA_BASE_URL = NA, OLLAMA_MODEL = NA,
                        OLLAMA_API_KEY = NA, XDG_CONFIG_HOME = withr::local_tempdir()))
  # nothing saved, nothing in the environment
  expect_identical(bricklayer_llm_config(), old_llm_config())
  # saved settings
  suppressMessages(bricklayer_llm_config(route = "anthropic", anthropic.key = "sk-ant-test",
                                         ollama.url = "http://localhost:11434", ollama.model = "qwen3:8b",
                                         openai.model = "gpt-x", own.url = "http://localhost:1234/v1",
                                         own.key = "k-own"))
  expect_identical(bricklayer_llm_config(), old_llm_config())
  # the environment over the saved values, and an alternative key spelling
  withr::local_envvar(c(MORIE_LLM_MODEL = "env-model", GOOGLE_API_KEY = "g-key", MORIE_LLM_ROUTE = "hosted",
                        MORIE_ANTHROPIC_MODEL = "claude-x"))
  new <- bricklayer_llm_config()
  expect_identical(new, old_llm_config())
  expect_identical(new$value[new$key == "gemini.key"], "set")
  expect_identical(new$source[new$key == "own.model"], "environment")
  # a saved file that cannot be read stops both the same way
  writeLines("[1]", lo_ns(".bl_config_path")())
  expect_error(bricklayer_llm_config(), "not a JSON object")
  expect_error(old_llm_config(), "not a JSON object")
  # and the snapshot of the file is gone once the call has ended, by an error too
  expect_null(lo_ns(".bl_cfg_state")$snap)
})

test_that("bricklayer_llm_config() reads its settings in well under a second", {
  withr::local_envvar(c(XDG_CONFIG_HOME = withr::local_tempdir()))
  bricklayer_llm_config()
  t <- system.time(for (i in 1:5) bricklayer_llm_config())[["elapsed"]] / 5
  expect_lt(t, wall_limit(0.5))
})

# 0.5.13's plr_crossfit(), verbatim but for the namespace lookups and without the progress bar:
# two lm.fit() calls per fold on the raw design
old_plr_crossfit <- function(data, outcome, treatment, covariates, k_folds = 5L, seed = 1L) {
  cols <- c(outcome, treatment, covariates)
  df <- data[stats::complete.cases(data[, cols, drop = FALSE]), cols, drop = FALSE]
  n <- nrow(df)
  folds <- lo_ns(".rmbl_with_seed")(seed, sample(rep_len(seq_len(k_folds), n)))
  y <- as.numeric(df[[outcome]])
  d <- as.numeric(df[[treatment]])
  X <- cbind(1, as.matrix(df[, covariates, drop = FALSE]))
  storage.mode(X) <- "double"
  U <- numeric(n)
  V <- numeric(n)
  for (k in seq_len(k_folds)) {
    test <- folds == k
    Xt <- X[!test, , drop = FALSE]
    gy <- stats::lm.fit(Xt, y[!test])$coefficients
    gd <- stats::lm.fit(Xt, d[!test])$coefficients
    gy[is.na(gy)] <- 0
    gd[is.na(gd)] <- 0
    U[test] <- y[test] - drop(X[test, , drop = FALSE] %*% gy)
    V[test] <- d[test] - drop(X[test, , drop = FALSE] %*% gd)
  }
  denom <- sum(V * V)
  theta <- sum(V * U) / denom
  se <- sqrt(sum(V * V * (U - theta * V)^2)) / denom
  list(ate = theta, se = se, n = n, k_folds = k_folds,
       method = "partially linear regression, DML2 cross-fitting, OLS nuisances")
}

test_that("plr_crossfit() gives the 0.5.13 estimates to 1e-10", {
  set.seed(1)
  n <- 3000
  d <- data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n), x3 = stats::rnorm(n) * 1e5 + 3e6,
                  x4 = stats::runif(n))
  d$x5 <- d$x1 + 1e-3 * stats::rnorm(n)            # nearly collinear with x1
  d$exposure <- 20 + 2 * d$x1 + 1e-5 * d$x3 + stats::rnorm(n)
  d$asthma <- 5 + 0.3 * d$exposure + d$x2 + stats::rnorm(n)
  d$x6 <- 2 * d$x1 - d$x2                          # exactly collinear: lm.fit's pivoting path
  d$x7 <- 4                                        # a constant column
  cases <- list(c("x1", "x2"), c("x1", "x2", "x3", "x4"), c("x1", "x5", "x2"), c("x1", "x2", "x6"),
                c("x1", "x7"), "x3")
  for (cv in cases) {
    for (k in c(2L, 5L)) {
      new <- plr_crossfit(d, "asthma", "exposure", cv, k_folds = k, seed = 4L)
      old <- old_plr_crossfit(d, "asthma", "exposure", cv, k_folds = k, seed = 4L)
      expect_equal(new$ate, old$ate, tolerance = 1e-10, info = paste(cv, collapse = "+"))
      expect_equal(new$se, old$se, tolerance = 1e-10, info = paste(cv, collapse = "+"))
      expect_identical(new[c("n", "k_folds", "method")], old[c("n", "k_folds", "method")])
    }
  }
  # recorded with 0.5.13 at n = 20000 (x3 on a scale of 1e5): 0.3004172919461145
  set.seed(1)
  n <- 20000
  dd <- data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n), x3 = stats::rnorm(n) * 1e5 + 3e6)
  dd$exposure <- 20 + 2 * dd$x1 + stats::rnorm(n)
  dd$asthma <- 5 + 0.3 * dd$exposure + dd$x2 + stats::rnorm(n)
  expect_equal(plr_crossfit(dd, "asthma", "exposure", c("x1", "x2", "x3"))$ate, 0.3004172919461145,
               tolerance = 1e-10)
})
