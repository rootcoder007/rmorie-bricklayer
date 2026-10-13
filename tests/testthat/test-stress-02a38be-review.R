# Review of 02a38be (PR #56, 0.5.12): one test per finding, the reviewer's reproducers as the gate.

# ---- C1, C2: hurwitz_zeta below s = 1 -----------------------------------------------------------

test_that("C1: hurwitz_zeta is accurate for s <= -5 (exact Bernoulli values, exact zeros)", {
  # -B_{n+1}/(n+1) for the Riemann zeta at negative integers
  expect_equal(hurwitz_zeta(-7) / (1 / 240), 1, tolerance = 1e-13)
  expect_equal(hurwitz_zeta(-11) / (691 / 32760), 1, tolerance = 1e-13)
  expect_equal(hurwitz_zeta(-15) / (3617 / 8160), 1, tolerance = 1e-13)
  # the trivial zeros stay exact, and zeta(-200, 2) = zeta(-200) - 1 = -1
  expect_identical(hurwitz_zeta(-60), 0)
  expect_identical(hurwitz_zeta(-200, 2), -1)
  # 20-digit references from mpmath (zeta(s, q), mp.dps = 50)
  ref <- rbind(c(-9.5, 1, -0.0066721722964666407568), c(-5.5, 1, -0.002671458019899224599),
               c(-6, 0.3, -0.0035246000000000000833), c(-7.25, 0.5, -0.0040118264434775960983),
               c(-12.5, 3.7, -247390.33662012577855), c(-20, 0.1, 49.498996835970336185),
               c(-9.5, 57.3, -250558246982887252.3), c(-30.5, 0.9, 209205876.6885998616))
  for (i in seq_len(nrow(ref))) {
    expect_equal(hurwitz_zeta(ref[i, 1], ref[i, 2]) / ref[i, 3], 1, tolerance = 1e-12,
                 info = sprintf("s = %g, q = %g", ref[i, 1], ref[i, 2]))
  }
})

test_that("C1: -5 < s < 1 is accurate too (the Euler-Maclaurin shift lost 1e-6 near s = -5)", {
  # mpmath zeta(s, q) at mp.dps = 40
  ref <- rbind(c(-4.9, 0.25, 0.0006823623986372121152137509), c(-4.5, 1, -0.003091669247215833844824257),
               c(-4.5, 0.25, 0.003074170159878321454996867), c(-3.5, 1, 0.004441011335479431958534658),
               c(-2.5, 0.25, -0.008038096082003843471484853), c(-1, 1, -1 / 12), c(0.5, 1, -1.460354508809586812889499),
               c(0.25, 1.7, -1.536611235751201615426241))
  for (i in seq_len(nrow(ref))) {
    expect_equal(hurwitz_zeta(ref[i, 1], ref[i, 2]) / ref[i, 3], 1, tolerance = 1e-12,
                 info = sprintf("s = %g, q = %g", ref[i, 1], ref[i, 2]))
  }
  # zeta(-n, q) = -B_{n+1}(q) / (n + 1) exactly, small q included: zeta(-4, 1e-8) = q / 30 to first order
  expect_equal(hurwitz_zeta(-4, 1e-8) / 3.3333333333333333e-10, 1, tolerance = 1e-12)
  expect_identical(hurwitz_zeta(0, 0.3), 0.5 - 0.3)
})

test_that("C2: a tiny q keeps its term (q + (n - 1), not (q + n) - 1)", {
  expect_equal(hurwitz_zeta(0.5, 1e-20) / 9999999998.5396454912, 1, tolerance = 1e-12)
  expect_equal(hurwitz_zeta(0.5, 1e-12) / 999998.53964549118911, 1, tolerance = 1e-12)
})

# ---- C3: compressed exposure files are checked to be complete -------------------------------------

c3_rows <- function(n = 20000) {
  set.seed(2)
  c("exposure,income", sprintf("%.3f,%d", runif(n, 12, 60), sample(1e5, n, TRUE)))
}
c3_write <- function(fun, x, ext) { f <- tempfile(fileext = ext); con <- fun(f, "w"); writeLines(x, con); close(con); f }
c3_cut <- function(f, frac, ext) {
  b <- readBin(f, "raw", file.size(f)); t <- tempfile(fileext = ext); writeBin(b[seq_len(floor(length(b) * frac))], t); t
}
c3_join <- function(..., ext = ".csv.gz") {
  t <- tempfile(fileext = ext)
  writeBin(do.call(c, lapply(list(...), function(f) if (is.raw(f)) f else readBin(f, "raw", file.size(f)))), t)
  t
}

test_that("C3: a truncated, damaged or padded gzip is refused, a whole one (several members too) is read", {
  rows <- c3_rows()
  gz <- c3_write(gzfile, rows, ".csv.gz")
  expect_identical(verify_pollution("pm25", exposure_csv = gz)$status, "ok")
  for (frac in c(0.1, 0.5, 0.9, 0.99)) {
    v <- verify_pollution("pm25", exposure_csv = c3_cut(gz, frac, ".csv.gz"))
    expect_identical(v$status, "error")
    expect_match(v$error, "is truncated")
  }
  b <- readBin(gz, "raw", file.size(gz)); b[length(b) - 6L] <- xor(b[length(b) - 6L], as.raw(1))
  flip <- tempfile(fileext = ".csv.gz"); writeBin(b, flip)
  expect_match(verify_pollution("pm25", exposure_csv = flip)$error, "CRC-32")
  expect_match(verify_pollution("pm25", exposure_csv = c3_join(gz, charToRaw("tail")))$error, "bytes after the end")
  expect_identical(verify_pollution("pm25", exposure_csv = c3_join(gz, as.raw(rep(0, 512))))$status, "ok")
  # two members (gzip -c a b > c, data.table::fwrite): read whole, and refused when cut
  two <- c3_join(c3_write(gzfile, rows[1:10001], ".gz"), c3_write(gzfile, rows[10002:20001], ".gz"))
  d <- rmoriebricklayer:::.pollution_read_csv(two)
  expect_identical(nrow(d), 20000L)
  expect_match(verify_pollution("pm25", exposure_csv = c3_cut(two, 0.97, ".csv.gz"))$error, "is truncated")
  expect_error(rmoriebricklayer:::.rmbl_decompress_checked(c3_join(charToRaw("not gzip"))), NA)
})

test_that("C3: a truncated bzip2 or xz file is refused, a whole one is read", {
  rows <- c3_rows()
  bz <- c3_write(bzfile, rows, ".csv.bz2")
  xz <- c3_write(xzfile, rows, ".csv.xz")
  expect_identical(verify_pollution("pm25", exposure_csv = bz)$status, "ok")
  expect_identical(verify_pollution("pm25", exposure_csv = xz)$status, "ok")
  for (frac in c(0.25, 0.99)) {
    expect_match(verify_pollution("pm25", exposure_csv = c3_cut(bz, frac, ".csv.bz2"))$error, "end-of-stream marker")
    expect_match(verify_pollution("pm25", exposure_csv = c3_cut(xz, frac, ".csv.xz"))$error, "truncated or damaged")
  }
  short <- tempfile(); writeBin(charToRaw("BZh9"), short)
  expect_false(rmoriebricklayer:::.rmbl_bzip2_complete(short))
})

test_that("C3: the decompressed size is capped while it is read", {
  bomb <- tempfile(fileext = ".csv.gz")
  con <- gzfile(bomb, "wb"); z <- charToRaw(paste(rep("1,2\n", 1e5), collapse = "")); for (i in 1:20) writeBin(z, con); close(con)
  for (fun in list(gzfile, bzfile)) {
    f <- tempfile(); con <- fun(f, "wb"); for (i in 1:20) writeBin(z, con); close(con)
    withr::with_options(list(rmoriebricklayer.max_csv_bytes = 1e5), {
      expect_error(rmoriebricklayer:::.rmbl_decompress_checked(f), "more than the size limit")
    })
  }
  withr::with_options(list(rmoriebricklayer.max_csv_bytes = -1),
                      expect_error(rmoriebricklayer:::.rmbl_decompress_checked(bomb), "non-negative number"))
  expect_error(.Call(rmoriebricklayer:::C_rmbl_gunzip_checked, "x", 10), "raw vector")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_gunzip_checked, as.raw(1:3), NA_real_), "non-negative number")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_gunzip_checked, raw(0), 10), "not gzip data")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_gunzip_checked, as.raw(c(0x1f, 0x8b, 1, 2, 3)), 10), "not valid gzip|truncated")
})

# ---- C4: the rate check holds whatever unit the rate came in ----------------------------------

test_that("C4: a rate below one per 100k needs rare_outcome = TRUE, whatever baseline_rate_per is", {
  args <- list("pm25", exposure_mean = 25, exposure_prevalence = 1)
  trap <- do.call(verify_pollution, c(args, baseline_rate = 0.008, baseline_rate_per = 1e5))
  expect_identical(trap$status, "assumption_failure")
  expect_match(pollution_report_text(trap), "baseline_rate_per = 1")
  # the person-year reading gives the right burden
  ok <- do.call(verify_pollution, c(args, baseline_rate = 0.008, baseline_rate_per = 1))
  expect_identical(ok$status, "ok")
  expect_gt(ok$pipeline$burden$attributable_cases, 1000)
  rare <- do.call(verify_pollution, c(args, baseline_rate = 0.5, baseline_rate_per = 1e5, rare_outcome = TRUE))
  expect_identical(rare$status, "ok")
  # an absurd unit is refused even when the outcome is declared rare
  absurd <- do.call(verify_pollution, c(args, baseline_rate = 0.008, baseline_rate_per = 1e300, rare_outcome = TRUE))
  expect_identical(absurd$status, "assumption_failure")
  expect_match(pollution_report_text(absurd), "100 billion")
  expect_identical(do.call(verify_pollution, c(args, rare_outcome = NA))$status, "error")
})

# ---- C5: the NAPS value + unit path refuses censored text too -----------------------------------

test_that("C5: \"<2\" in a NAPS value column is refused, as it is in an exposure column", {
  f <- tempfile(fileext = ".csv")
  writeLines(c("value,unit", "20,ug/m3", "<2,ug/m3", "<2,ug/m3", "<2,ug/m3", "40,ug/m3"), f)
  v <- verify_pollution("pm25", exposure_csv = f)
  expect_identical(v$status, "error")
  expect_match(v$error, "3 exposure value\\(s\\) are text")
  writeLines(c("value,unit", "20,ug/m3", ",ug/m3", "40,ug/m3"), f)
  expect_identical(verify_pollution("pm25", exposure_csv = f)$status, "ok")
})

# ---- C6 and the command-line arguments ------------------------------------------------------------

test_that("C6: --force belongs to config reset only, and stray arguments are refused", {
  withr::local_envvar(R_USER_CONFIG_DIR = tempfile("cfg-"))
  quiet <- function(...) invisible(NULL)
  code <- function(...) rmoriebricklayer:::bricklayer_cli(c(...), out = quiet)
  expect_identical(code("config", "set", "own.key", "--force"), 2L)
  expect_false(file.exists(rmoriebricklayer:::.bl_config_path()))
  for (a in list(c("config", "unset", "route", "--force"), c("config", "show", "--force"),
                 c("config", "get", "route", "--force"), c("config", "show", "extra"), c("config", "help", "x"),
                 c("config", "get", "route", "extra"), c("config", "unset", "route", "extra"),
                 c("functions", "--", "a", "b"), c("help", "ask", "extra"), c("describe", "--", "x"))) {
    expect_identical(do.call(code, as.list(a)), 2L, info = paste(a, collapse = " "))
  }
  expect_identical(code("config", "reset", "--force"), 0L)
  expect_identical(code("help", "ask"), 0L)
})

# ---- C7: the legacy record path ---------------------------------------------------------------

test_that("C7: a FIFO or a directory at the legacy record path is refused at once", {
  skip_on_os("windows")
  d <- tempfile("legacy-"); dir.create(d)
  p <- file.path(d, "xmss_used_indices.txt")
  j <- file.path(d, "xmss_index.json")
  expect_identical(rmoriebricklayer:::.rmbl_xmss_legacy_json(p), integer(0))
  dir.create(j)
  expect_error(rmoriebricklayer:::.rmbl_xmss_legacy_json(p), "is a directory, not a regular file")
  unlink(j, recursive = TRUE)
  skip_if(!nzchar(Sys.which("mkfifo")))
  system2("mkfifo", j)
  t0 <- proc.time()[["elapsed"]]
  expect_error(rmoriebricklayer:::.rmbl_xmss_legacy_json(p), "device or other special file")
  expect_lt(proc.time()[["elapsed"]] - t0, 2)
})

# ---- C8, C9: the manifest cache -----------------------------------------------------------------

c89_cache <- function(table = NULL, manifest = NULL, age_days = 0) {
  d <- tempfile("dcache-"); dir.create(d)
  withr::local_options(list(rmoriebricklayer.data_cache = d), .local_envir = parent.frame())
  if (!is.null(table)) { con <- gzfile(file.path(d, "db__t.csv.gz"), "wb"); writeBin(table, con); close(con) }
  if (!is.null(manifest)) {
    writeLines(manifest, file.path(d, "manifest.json"))
    Sys.setFileTime(file.path(d, "manifest.json"), Sys.time() - age_days * 86400)
  }
  d
}
c89_manifest <- function(sha = NULL) {
  if (is.null(sha)) '{"datasets":[{"key":"db/t"}]}' else sprintf('{"datasets":[{"key":"db/t","sha256":"%s"}]}', sha)
}

test_that("C8: parallel refreshes each use their own temporary file", {
  skip_on_os("windows")
  skip_on_cran()
  d <- c89_cache(manifest = c89_manifest(), age_days = 3)
  local_mocked_bindings(.bl_data_get = function(path, dest, ...) {
    writeLines(c89_manifest(strrep("a", 64)), dest); Sys.sleep(0.05); invisible(dest)
  })
  res <- parallel::mclapply(1:12, function(i) tryCatch({
    for (k in 1:3) bricklayer_data_manifest(refresh = TRUE)
    "ok"
  }, error = function(e) conditionMessage(e)),
  # R CMD check --as-cran caps child processes at 2 (_R_CHECK_LIMIT_CORES_)
  mc.cores = if (nzchar(Sys.getenv("_R_CHECK_LIMIT_CORES_"))) 2L else 12L)
  expect_identical(unique(unlist(res)), "ok")
  expect_length(list.files(d, pattern = "[.]part$"), 0L)
})

test_that("C9: a reply that is not a manifest leaves the cached copy, and a cached table is kept", {
  good <- charToRaw("x,y\n1,2\n")
  d <- c89_cache(good, c89_manifest(), age_days = 3)
  for (reply in c("{}", '{"error":"unauthorised"}', '{"datasets":{"key":"db/t"}}', '{"datasets":[1, 2]}')) {
    local_mocked_bindings(.bl_data_get = function(path, dest, ...) writeLines(reply, dest))
    expect_error(bricklayer_data_manifest(refresh = TRUE), "not a manifest", info = reply)
    expect_identical(readLines(file.path(d, "manifest.json")), c89_manifest(), info = reply)
  }
  # offline, the stale copy lists the table without a digest: it loads, as it does online
  local_mocked_bindings(.bl_data_get = function(...) stop("could not resolve host"))
  expect_identical(nrow(bricklayer_data_load("db/t")), 1L)
  # no manifest anywhere: refused, and the cached table is kept for the next run
  unlink(file.path(d, "manifest.json"))
  expect_error(bricklayer_data_load("db/t"), "kept unused")
  expect_true(file.exists(file.path(d, "db__t.csv.gz")))
})

# ---- LOW ---------------------------------------------------------------------------------------

test_that("LOW: releasing descriptor 0, 1 or 2 is refused (it would close the console)", {
  for (fd in 0:2) expect_error(.Call(rmoriebricklayer:::C_rmbl_flock_release, fd), "not a lock")
  expect_null(.Call(rmoriebricklayer:::C_rmbl_flock_release, -1L))
})

test_that("LOW: the checked writer leaves the exact bytes and no temporary file", {
  d <- tempfile("w-"); dir.create(d)
  p <- file.path(d, "rec"); tmp <- file.path(d, "rec.tmp")
  expect_null(.Call(rmoriebricklayer:::C_rmbl_write_file_checked, tmp, p, charToRaw("abc\n")))
  expect_identical(readBin(p, "raw", 100), charToRaw("abc\n"))
  expect_false(file.exists(tmp))
})

test_that("LOW: a lock file this user cannot write is named as such, not as a read-only directory", {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["user"]], "root"))
  d <- tempfile("lk-"); dir.create(d)
  withr::local_options(list(rmoriebricklayer.xmss_index_file = file.path(d, "rec.txt")))
  writeLines("", file.path(d, "rec.txt.flock")); Sys.chmod(file.path(d, "rec.txt.flock"), "0400")
  expect_error(rmoriebricklayer:::.rmbl_xmss_with_lock(file.path(d, "rec.txt"), function() NULL),
               "owned by another user")
})

# ---- C10: Ctrl-C at a prompt --------------------------------------------------------------

test_that("C10: the trap's marker is an interrupt even when the shell's exit status is lost (dash)", {
  skip_on_os("windows")
  skip_if_not(nzchar(Sys.which("sh")))
  local_mocked_bindings(.bl_interactive = function() FALSE, .bl_stdin_tty = function() TRUE)
  # what system2(stdout = TRUE) returns from dash: the trap's output, and no status attribute
  local_mocked_bindings(system2 = function(...) "\001RMBL-INTERRUPTED\001", .package = "base")
  got <- tryCatch(rmoriebricklayer:::.bl_readline("key: ", secret = FALSE), interrupt = function(i) "interrupt")
  expect_identical(got, "interrupt")
  got <- tryCatch(rmoriebricklayer:::.bl_readline("key: ", secret = TRUE), interrupt = function(i) "interrupt")
  expect_identical(got, "interrupt")
})

test_that("C10: Ctrl-C at a real terminal prompt exits 130 (not mocked)", {
  skip_on_cran()
  skip_on_os(c("windows", "mac"))
  skip_if_not(nzchar(Sys.which("script")) && nzchar(Sys.which("sh")))
  launcher <- system.file("bin", "rmbl", package = "rmoriebricklayer")
  skip_if_not(nzchar(launcher))
  h <- withr::local_tempdir()
  for (args in c("login --token", "config set own.key")) {
    cmd <- sprintf("(sleep 5; printf '\\003') | script -qec %s /dev/null > /dev/null 2>&1",
                   shQuote(paste("sh", shQuote(launcher), args)))
    st <- withr::with_envvar(c(HOME = h, R_USER_CONFIG_DIR = h, R_LIBS = paste(.libPaths(), collapse = ":")),
                             system(cmd))
    expect_identical(as.integer(st), 130L, info = args)
  }
})

test_that("LOW: UTF-32 with a mark is read, and its decoding error never quotes the file", {
  rows <- c("exposure,income", "30,10", "40,20")
  txt <- paste0(paste(rows, collapse = "\n"), "\n")
  for (enc in c("UTF-32LE", "UTF-32BE")) {
    f <- tempfile(fileext = ".csv")
    bom <- if (enc == "UTF-32LE") as.raw(c(0xff, 0xfe, 0, 0)) else as.raw(c(0, 0, 0xfe, 0xff))
    writeBin(c(bom, iconv(txt, "UTF-8", enc, toRaw = TRUE)[[1]]), f)
    d <- rmoriebricklayer:::.pollution_read_csv(f)
    expect_identical(d$exposure, c(30L, 40L), info = enc)
  }
  bad <- tempfile(fileext = ".csv"); writeBin(c(as.raw(c(0xff, 0xfe, 0, 0)), as.raw(c(0x41, 0, 0))), bad)
  e <- tryCatch(rmoriebricklayer:::.pollution_read_csv(bad), error = conditionMessage)
  expect_lt(nchar(e), 200)
})

test_that("LOW: a row with the wrong number of fields, or a column name twice, is refused", {
  f <- tempfile(fileext = ".csv")
  writeLines(c("exposure,income", "30,10", "40,20,99", "50,30"), f)
  expect_error(rmoriebricklayer:::.pollution_read_csv(f), "line 3 has 3 fields where the header has 2")
  writeLines(c("site,exposure,exposure", "a,30,99", "b,40,98"), f)
  expect_error(rmoriebricklayer:::.pollution_read_csv(f), "'exposure' more than once")
  writeLines(c("exposure,note", "30,\"a, quoted, note\"", "40,plain"), f)
  expect_identical(nrow(rmoriebricklayer:::.pollution_read_csv(f)), 2L)
})

test_that("LOW: a next_index past 2^31 - 1 is the damaged-key error, not a raw NA", {
  k <- pqc_keygen(height = 2)
  for (bad in list(1e10, 2^31)) {
    k2 <- k; k2$next_index <- bad
    expect_error(capsule_sign("m", k2), "not a whole number >= 0 \\(below 2\\^31\\)")
  }
})

test_that("L3: a key saved for another hosted address is said once, and the summary says so", {
  d <- withr::local_tempdir()
  withr::local_envvar(XDG_CONFIG_HOME = d, MORIE_HOSTED_KEY = "", MORIE_HOSTED_BASE_URL = "https://llm.example.org/v1")
  dir.create(file.path(d, "morie"))
  writeLines('{"hosted_key": "sk-test", "hosted_base_url": "https://old.example.org/v1"}', file.path(d, "morie", "credentials.json"))
  rm(list = ls(rmoriebricklayer:::.bl_said_once), envir = rmoriebricklayer:::.bl_said_once)
  expect_message(expect_null(rmoriebricklayer:::.bl_hosted_key()), "issued for https://old.example.org/v1")
  expect_silent(expect_null(rmoriebricklayer:::.bl_hosted_key()))
  expect_match(rmoriebricklayer:::.bl_no_route_message(), "stored key was issued for https://old.example.org/v1")
  expect_false(grepl("no key stored", rmoriebricklayer:::.bl_no_route_message()))
})

test_that("M2: validation needs a schema, a misspelt field is fatal, and expected_dtypes is checked", {
  df <- data.frame(a = 1:3, b = c("x", "y", "z"))
  expect_error(apply_schema_validation(df, NULL), "no schema to validate against")
  expect_error(apply_schema_validation(df, list()), "no schema to validate against")
  expect_error(apply_schema_validation(df, list(scheme = infer_schema(df))), "no `schema` element \\(it has scheme\\)")
  expect_error(apply_schema_validation(df, list(schema = list(expected_colums = "a"))), "did you mean 'expected_columns'")
  expect_error(apply_schema_validation(df, list(schema = list(structural_invariants = list(min_data_row = 1)))),
               "did you mean 'min_data_rows'")
  expect_warning(apply_schema_validation(df, list(schema = list(notes = "about this table"))), "not one validate_schema\\(\\) uses")
  # a dataset's own invariant (the OTIS file's) is allowed
  expect_true(apply_schema_validation(df, list(schema = list(structural_invariants = list(total_placements_sum = 5)))))
  # expected_dtypes is read; a factor and a character column are one family
  expect_warning(apply_schema_validation(df, list(schema = list(expected_dtypes = list(a = "character")))), "is integer, expected character")
  expect_true(apply_schema_validation(df, list(schema = list(expected_dtypes = list(b = "factor", a = "integer")))))
})

test_that("LOW: default-ignorable characters are removed from the data list", {
  hidden <- "a­b͏cᅟdㅤe᠎f﻿g￹h\U000e0041i"
  tabs <- rmoriebricklayer:::.bl_data_tables_df("db/t", hidden, 1L, "src")
  out <- paste(rmoriebricklayer:::.bl_format_data_tables(tabs, width = 200), collapse = "\n")
  expect_match(out, "abcdefghi", fixed = TRUE)
})

test_that("B3: a temporary record file left by a writer that died is removed at the next write", {
  d <- withr::local_tempdir()
  p <- file.path(d, "rec.txt")
  stale <- file.path(d, "xmss-dead123.tmp"); writeLines("partial", stale)
  rmoriebricklayer:::.rmbl_xmss_with_lock(p, function() rmoriebricklayer:::.rmbl_xmss_record_write(p, c(`k:aa` = 3L)))
  expect_false(file.exists(stale))
  expect_true(file.exists(p))
})

test_that("B5: a credentials file with a NUL, in Latin-1, or of megabytes is refused plainly", {
  d <- withr::local_tempdir()
  f <- file.path(d, "c.json")
  writeBin(c(charToRaw('{"a": "b"}'), as.raw(0), charToRaw('{"c": 1}')), f)
  expect_error(rmoriebricklayer:::.bl_read_text(f), "NUL byte")
  writeBin(c(charToRaw('{"name": "caf'), as.raw(0xe9), charToRaw('"}')), f)
  expect_error(rmoriebricklayer:::.bl_read_text(f), "not UTF-8 text")
  writeBin(charToRaw(paste0('{"x": "', strrep("y", 1100000), '"}')), f)
  expect_error(rmoriebricklayer:::.bl_read_text(f), "too large to be a credentials file")
  writeLines('{"hosted_key": "k"}', f)
  expect_identical(rmoriebricklayer:::.bl_read_text(f), '{"hosted_key": "k"}\n')
})

test_that("LOW: numbers must be numbers, steps and grids are capped, and plot() needs a report", {
  expect_match(verify_pollution("pm25", exposure_mean = as.raw(25), exposure_prevalence = 1)$error, "exposure_mean must be a single number, not raw")
  expect_match(verify_pollution("pm25", exposure_mean = 25, exposure_prevalence = 1, population = as.raw(9))$error, "population must be a single number")
  expect_error(lagrangian_particles(10, 0, 0, 1, 0, 1, 1, 1, n_steps = 1e300, max_work = Inf), "at most 2\\^31 - 1")
  expect_error(advection_diffusion_2d(matrix(0, 3, 3), 0, 0, 0.1, 0.1, 1, 1, 0.1, n_steps = 1e300, max_work = Inf), "at most 2\\^31 - 1")
  expect_error(lagrangian_particles(10, 0, 0, 1, 0, 1, 1, 1, n_steps = 1, grid = c(0, 1, 0, 1, 1e6, 1e6)), "above max_work")
  pdf(NULL); on.exit(grDevices::dev.off(), add = TRUE)
  for (bad in list("x", list(), structure(list(status = "ok"), class = "rmbl_pollution_report"))) {
    expect_error(rmoriebricklayer:::plot.rmbl_pollution_report(bad), "must be a report from verify_pollution")
  }
  # the NA bar's label never takes a real level's name
  lab <- NULL
  local_mocked_bindings(.bl_label_fit = function(labels) { lab <<- labels; list(labels = labels, mar = 4) })
  rmoriebricklayer:::.bl_hbars(c(1, 2, 3, 4), c("(missing)", "(NA)", NA, "a"), "n", "t", rep("grey", 4))
  expect_identical(anyDuplicated(lab), 0L)
  expect_true("(NA 2)" %in% lab)
})
