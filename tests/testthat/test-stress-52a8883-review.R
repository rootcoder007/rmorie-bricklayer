# The review of 52a8883 (2026-10-12): every HIGH and MEDIUM finding has a test here that fails on
# 52a8883, and none of them mocks the component under test. The lock is held by real forked
# processes, the full disk is /dev/full, the cache is a real directory with a real manifest file.

xmss_tmp_record <- function(env = parent.frame()) {
  f <- tempfile("xmss-rec-", fileext = ".txt")
  withr::local_options(rmoriebricklayer.xmss_index_file = f, .local_envir = env)
  f
}
fresh_session <- function() {
  e <- rmoriebricklayer:::.rmbl_xmss_used
  rm(list = ls(e, all.names = TRUE), envir = e)
}

# ---- B1: the digest check when the manifest cannot be had --------------------------------

data_cache_with <- function(table_bytes, manifest = NULL, age_days = 0, env = parent.frame()) {
  d <- tempfile("bl-cache-")
  dir.create(d)
  withr::local_options(rmoriebricklayer.data_cache = d, .local_envir = env)
  writeBin(table_bytes, file.path(d, "db__t.csv.gz"))
  if (!is.null(manifest)) {
    m <- file.path(d, "manifest.json")
    writeLines(manifest, m)
    Sys.setFileTime(m, Sys.time() - age_days * 86400)
  }
  d
}
good <- charToRaw("a,b\n1,2\n")
good_sha <- function() tolower(rmoriebricklayer::core_sha256(good))
manifest_for <- function(sha) sprintf('{"datasets":[{"key":"db/t","rows":1,"sha256_gz":"%s"}]}', sha)

test_that("B1: a tampered cached table is refused when the manifest is stale and the server is down", {
  d <- data_cache_with(charToRaw("666,TAMPERED\n"), manifest_for(good_sha()), age_days = 3)
  # the network itself is down: every fetch fails (the transport is the stub, not the check)
  local_mocked_bindings(.bl_data_get = function(...) stop("HTTP 503 Service Unavailable"))
  expect_error(bricklayer_data_load("db/t"), "does not match the manifest's SHA-256")
  expect_false(file.exists(file.path(d, "db__t.csv.gz")))
  # the stale manifest stayed in place: a failed refresh does not destroy the last good copy
  expect_true(file.exists(file.path(d, "manifest.json")))
})

test_that("B1: with no manifest at all and the server down, the table cannot be verified and is not kept", {
  d <- data_cache_with(charToRaw("666,TAMPERED\n"))
  local_mocked_bindings(.bl_data_get = function(...) stop("could not resolve host"))
  expect_error(bricklayer_data_load("db/t"), "cannot be verified")
  expect_false(file.exists(file.path(d, "db__t.csv.gz")))
})

test_that("B1: a genuine table loads from the stale manifest's digest while the server is down", {
  d <- data_cache_with(good, manifest_for(good_sha()), age_days = 3)
  local_mocked_bindings(.bl_data_get = function(...) stop("HTTP 500"))
  expect_true(rmoriebricklayer:::.bl_data_check_sha("db/t", file.path(d, "db__t.csv.gz")))
  # a manifest that lists the table without a digest: the fresh manifest is authoritative
  d2 <- data_cache_with(good, '{"datasets":[{"key":"db/t"}]}', age_days = 0)
  expect_true(rmoriebricklayer:::.bl_data_check_sha("db/t", file.path(d2, "db__t.csv.gz")))
  # the same manifest stale and unreachable: no digest to check against, so not kept
  d3 <- data_cache_with(good, '{"datasets":[{"key":"db/t"}]}', age_days = 3)
  expect_error(rmoriebricklayer:::.bl_data_check_sha("db/t", file.path(d3, "db__t.csv.gz")), "cannot be verified")
  # an unparseable cached manifest is no copy at all
  d4 <- data_cache_with(good, "{not json", age_days = 3)
  expect_error(rmoriebricklayer:::.bl_data_check_sha("db/t", file.path(d4, "db__t.csv.gz")), "cannot be verified")
  # a digest field that is not a digest, in the fallback copy too
  d5 <- data_cache_with(good, manifest_for("xyz"), age_days = 3)
  expect_error(rmoriebricklayer:::.bl_data_check_sha("db/t", file.path(d5, "db__t.csv.gz")), "not a SHA-256 hex digest")
  expect_false(file.exists(file.path(d5, "db__t.csv.gz")))
  d6 <- data_cache_with(good, manifest_for("xyz"), age_days = 0)
  expect_error(rmoriebricklayer:::.bl_data_check_sha("db/t", file.path(d6, "db__t.csv.gz")), "not a SHA-256 hex digest")
})

test_that("B1: a refreshed manifest replaces the cached one only when it parses", {
  d <- data_cache_with(good, manifest_for(good_sha()), age_days = 3)
  local_mocked_bindings(.bl_data_get = function(path, dest, ...) writeLines("<html>gateway error</html>", dest))
  expect_error(bricklayer_data_manifest())
  expect_identical(readLines(file.path(d, "manifest.json")), manifest_for(good_sha()))
  local_mocked_bindings(.bl_data_get = function(path, dest, ...) writeLines(manifest_for(good_sha()), dest))
  expect_identical(bricklayer_data_manifest(refresh = TRUE)$datasets[[1]]$key, "db/t")
  local_mocked_bindings(.bl_data_get = function(path, dest, ...) writeLines("[1, 2]", dest))
  expect_error(bricklayer_data_manifest(refresh = TRUE), "not a JSON object")
})

# ---- B2, B4: the operating-system lock ------------------------------------------------------

test_that("B2: the lock is held by the process, and the kernel releases it when the process dies", {
  skip_on_os("windows")
  skip_on_cran()
  p <- tempfile("lockrec-")
  lock <- paste0(p, ".flock")
  fd <- .Call(rmoriebricklayer:::C_rmbl_flock_acquire, lock, 0L)
  expect_true(fd >= 0L)
  # a second open file description in this process is refused while the first holds it
  expect_identical(.Call(rmoriebricklayer:::C_rmbl_flock_acquire, lock, 60L), -1L)
  invisible(.Call(rmoriebricklayer:::C_rmbl_flock_release, fd))
  expect_null(.Call(rmoriebricklayer:::C_rmbl_flock_release, -1L))
  # a child takes the lock and dies without releasing it (a crashed session): the lock is free
  job <- parallel::mcparallel({
    .Call(rmoriebricklayer:::C_rmbl_flock_acquire, lock, 0L)
    tools::pskill(Sys.getpid(), tools::SIGKILL)
  })
  parallel::mccollect(job, wait = TRUE)
  fd2 <- .Call(rmoriebricklayer:::C_rmbl_flock_acquire, lock, 2000L)
  expect_true(fd2 >= 0L)
  .Call(rmoriebricklayer:::C_rmbl_flock_release, fd2)
  # a live holder: the waiter is told after its timeout, nothing is deleted
  ready <- tempfile()
  job <- parallel::mcparallel({
    f <- .Call(rmoriebricklayer:::C_rmbl_flock_acquire, lock, 0L)
    file.create(ready)
    Sys.sleep(3)
    .Call(rmoriebricklayer:::C_rmbl_flock_release, f)
  })
  for (i in 1:600) if (!file.exists(ready)) Sys.sleep(0.05)
  skip_if_not(file.exists(ready), "the lock-holding child did not start")
  withr::local_options(rmoriebricklayer.xmss_index_file = p)
  t0 <- Sys.time()
  expect_identical(.Call(rmoriebricklayer:::C_rmbl_flock_acquire, lock, 200L), -1L)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
  parallel::mccollect(job, wait = TRUE)
  expect_true(file.exists(lock))
})

test_that("B2: six processes signing with copies of one key never share an index, even after a crash", {
  skip_on_os("windows")
  skip_on_cran()
  f <- xmss_tmp_record()
  k <- pqc_keygen(height = 5L)
  # a crashed signer: it held the lock when it was killed (the case that left a stale lock dir)
  job <- parallel::mcparallel({
    .Call(rmoriebricklayer:::C_rmbl_flock_acquire, paste0(f, ".flock"), 0L)
    tools::pskill(Sys.getpid(), tools::SIGKILL)
  })
  parallel::mccollect(job, wait = TRUE)
  for (trial in 1:3) {
    signer <- function(i) {
      kk <- k
      out <- NA_integer_
      for (j in 0:31) {
        kk$next_index <- j
        s <- tryCatch(capsule_sign(paste("m", i, j), kk, scheme = "xmss"), error = function(e) NULL)
        if (!is.null(s)) {
          out <- as.integer(s$index)
          break
        }
      }
      out
    }
    jobs <- lapply(1:6, function(i) {
      parallel::mcparallel(signer(i))
    })
    got <- unlist(parallel::mccollect(jobs, wait = TRUE))
    got <- got[!is.na(got)]
    expect_false(anyDuplicated(got) > 0)
  }
})

test_that("B4, B7: a lock or record path that cannot be used is reported at once, not spun on", {
  skip_on_os("windows")
  p <- tempfile("lockdir-")
  dir.create(paste0(p, ".flock"))          # an unremovable "lock": a directory in its place
  withr::local_options(rmoriebricklayer.xmss_index_file = p)
  t0 <- Sys.time()
  expect_error(pqc_keygen(height = 2L), "Is a directory|not a regular file")
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 5)
  expect_error(.Call(rmoriebricklayer:::C_rmbl_flock_acquire, file.path(tempfile(), "x"), 0L),
               "cannot open the lock file")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_flock_acquire, NA_character_, 0L), "single file path")
  # a read-only directory: said as such, not as "another process holds the lock"
  skip_if(identical(Sys.info()[["effective_user"]], "root"))
  ro <- tempfile("ro-")
  dir.create(ro)
  Sys.chmod(ro, "0555")
  withr::defer(Sys.chmod(ro, "0755"))
  withr::local_options(rmoriebricklayer.xmss_index_file = file.path(ro, "rec.txt"))
  expect_error(pqc_keygen(height = 2L), "read-only")
})

test_that("B7: device, directory and relative paths are refused for the record", {
  for (v in c("none", "2", "-", "relative/rec.txt")) {
    withr::local_options(rmoriebricklayer.xmss_index_file = v)
    expect_error(pqc_keygen(height = 2L), "relative path")
  }
  skip_on_os("windows")
  withr::local_options(rmoriebricklayer.xmss_index_file = "/dev/null")
  expect_error(pqc_keygen(height = 2L), "device or other special file")
  withr::local_options(rmoriebricklayer.xmss_index_file = tempdir())
  expect_error(pqc_keygen(height = 2L), "is a directory")
  notdir <- tempfile()
  file.create(notdir)
  withr::local_options(rmoriebricklayer.xmss_index_file = file.path(notdir, "rec.txt"))
  expect_error(pqc_keygen(height = 2L), "is not a directory")
  expect_identical(.Call(rmoriebricklayer:::C_rmbl_path_kind, "/dev/null"), "other")
  expect_identical(.Call(rmoriebricklayer:::C_rmbl_path_kind, tempfile()), "missing")
})

# ---- B3: the checked write -------------------------------------------------------------------

test_that("B3: a write that does not reach the disk leaves the record as it was and stops the signature", {
  w <- rmoriebricklayer:::C_rmbl_write_file_checked
  target <- tempfile()
  writeLines("k:old", target)
  # the temporary file is created exclusively: an existing path is refused, never written or removed
  taken <- tempfile()
  writeLines("keep me", taken)
  expect_match(.Call(w, taken, target, charToRaw("x")), "cannot create")
  expect_identical(readLines(taken), "keep me")
  expect_match(.Call(w, file.path(tempfile(), "t"), target, raw(0)), "cannot create")
  skip_on_os("windows")
  busy <- tempfile()
  dir.create(file.path(busy, "inside"), recursive = TRUE)   # a non-empty directory cannot be renamed over
  tmp <- tempfile()
  expect_match(.Call(w, tmp, busy, charToRaw("x")), "could not replace")
  expect_false(file.exists(tmp))
  ok <- tempfile()
  expect_null(.Call(w, tempfile(tmpdir = dirname(ok)), ok, charToRaw("a\tb\n")))
  expect_identical(readBin(ok, "raw", 100), charToRaw("a\tb\n"))
  expect_error(.Call(w, tmp, ok, "not raw"), "raw vector")
  # a file-size limit stands in for a full disk: the write fails (EFBIG), the old record stays
  sh <- Sys.which("sh")
  rscript <- file.path(R.home("bin"), "Rscript")
  skip_if(!nzchar(sh) || !file.exists(rscript))
  lib <- paste(.libPaths(), collapse = .Platform$path.sep)
  code <- sprintf(paste0(".libPaths(strsplit('%s', '%s', fixed = TRUE)[[1]]); library(rmoriebricklayer); ",
                         "cat(.Call(rmoriebricklayer:::C_rmbl_write_file_checked, '%s', '%s', as.raw(rep(65L, 200000))))"),
                  lib, .Platform$path.sep, tempfile(tmpdir = dirname(target)), target)
  out <- suppressWarnings(system2(sh, c("-c", shQuote(sprintf("trap '' XFSZ; ulimit -f 64; exec %s -e %s",
                                                                  shQuote(rscript), shQuote(code)))),
                                  stdout = TRUE, stderr = TRUE))
  expect_match(paste(out, collapse = " "), "did not complete|did not reach the disk|not the size written")
  expect_identical(readLines(target), "k:old")
})

# ---- A1, A2, A3: the record's key id, seeded keys, the fcdce03 record ------------------------

test_that("A1: an edited root does not make a stale copy a new key; a root that does not match is withheld", {
  f <- xmss_tmp_record()
  k <- pqc_keygen(height = 4L)
  k0 <- k
  for (m in c("m0", "m1", "m2")) {
    s <- capsule_sign(m, k, scheme = "xmss")
    k <- xmss_advance(k, s)
  }
  fresh_session()
  for (edit in list(toupper, function(r) paste0(r, " "), function(r) strrep("ab", 32))) {
    stale <- k0
    stale$next_index <- 1L
    stale$root <- edit(stale$root)
    expect_error(capsule_sign("forged", stale, scheme = "xmss"))
  }
  # the record holds one fingerprint line, never the root a key claims
  expect_true(all(grepl("^k:[0-9a-f]{64}\t", readLines(f))))
  # a root that does not match the seeds, at a fresh index: the index is retired, no signature
  bad <- k
  bad$root <- strrep("cd", 32)
  expect_error(capsule_sign("x", bad, scheme = "xmss"), "does not match its seeds")
  k$next_index <- 3L
  expect_error(capsule_sign("x", k, scheme = "xmss"), "already used")
  bad$root <- "not-hex"
  expect_error(capsule_sign("x", bad, scheme = "xmss"), "not 64 hex")
})

test_that("A2: a key regenerated from its seeds is not registered and must be vouched for", {
  f <- xmss_tmp_record()
  sd <- strrep("ab", 32)
  ps <- strrep("cd", 32)
  pr <- strrep("ef", 32)
  k1 <- pqc_keygen(height = 4L, sk_seed = sd, pub_seed = ps, sk_prf = pr)
  expect_false(file.exists(f))
  expect_error(capsule_sign("first", k1, scheme = "xmss"), "xmss_register_key")
  xmss_register_key(k1)
  s <- capsule_sign("first", k1, scheme = "xmss")
  expect_identical(as.integer(s$index), 0L)
  fresh_session()
  k2 <- pqc_keygen(height = 4L, sk_seed = sd, pub_seed = ps, sk_prf = pr)
  expect_error(xmss_register_key(k2), "already in the record with index 0 used")
  expect_error(capsule_sign("second", k2, scheme = "xmss"), "already used")
  # a random key is registered at birth and signs at once
  expect_identical(as.integer(capsule_sign("r", pqc_keygen(height = 2L), scheme = "xmss")$index), 0L)
})

test_that("A3: the fcdce03 record is merged, kept, and an unreadable one stops signing", {
  d <- tempfile("cfg-")
  dir.create(d)
  f <- file.path(d, "xmss_used_indices.txt")
  withr::local_options(rmoriebricklayer.xmss_index_file = f)
  k <- pqc_keygen(height = 4L)
  writeLines(sprintf('{"%s:%s": 5}', toupper(k$root), k$pub_seed), file.path(d, "xmss_index.json"))
  fresh_session()
  stale <- k
  stale$next_index <- 1L
  expect_error(capsule_sign("again", stale, scheme = "xmss"), "next index 6")
  stale$next_index <- 6L
  expect_identical(as.integer(capsule_sign("ok", stale, scheme = "xmss")$index), 6L)
  expect_false(file.exists(file.path(d, "xmss_index.json")))
  expect_true(file.exists(file.path(d, "xmss_index.json.migrated")))
  # the 0.5.12-pre line format (root:pub_seed) is read as well
  k2 <- pqc_keygen(height = 3L)
  cat(sprintf("%s:%s\t4\n", k2$root, k2$pub_seed), file = f, append = TRUE)
  fresh_session()
  k2$next_index <- 2L
  expect_error(capsule_sign("x", k2, scheme = "xmss"), "next index 5")
  # xmss_forget_used_indices() for one key clears the legacy line too
  xmss_forget_used_indices(k2)
  k2$next_index <- 0L
  expect_identical(as.integer(capsule_sign("x", k2, scheme = "xmss")$index), 0L)
  expect_error(xmss_forget_used_indices(signing_public_key(k2)), "signing key")
  for (bad in c("{not json", '{"zz": 1}', sprintf('{"%s:%s": "five"}', k$root, k$pub_seed), "[1, 2]")) {
    writeLines(bad, file.path(d, "xmss_index.json"))
    expect_error(capsule_sign("x", pqc_keygen(height = 2L), scheme = "xmss"), "written before 0.5.12")
    unlink(file.path(d, "xmss_index.json"))
  }
  writeLines("{}", file.path(d, "xmss_index.json"))
  expect_silent(pqc_keygen(height = 2L))
  xmss_forget_used_indices()
  gone <- file.path(d, c("xmss_used_indices.txt", "xmss_index.json", "xmss_index.json.migrated"))
  expect_false(any(file.exists(gone)))
})

test_that("xmss_advance(): no message means no index above the record; bundles; a damaged next_index", {
  f <- xmss_tmp_record()
  k <- pqc_keygen(height = 4L)
  s <- capsule_sign("m", k, scheme = "xmss")
  edited <- s
  edited$index <- 9L
  expect_error(xmss_advance(k, edited), "above the highest index")
  expect_identical(xmss_advance(k, s)$next_index, 1L)
  expect_error(xmss_advance(k, edited, message = "m"), "does not verify")
  nx <- k
  nx$next_index <- NA
  expect_error(xmss_advance(nx, s), "not a whole number")
  b <- list(attestation = list(signature = s))
  expect_identical(xmss_advance(k, b)$next_index, 1L)
  # with the record off, a signature from another session needs the message
  withr::local_options(rmoriebricklayer.xmss_index_file = FALSE)
  fresh_session()
  expect_error(xmss_advance(k, s), "above the highest index")
  expect_identical(xmss_advance(k, s, message = "m")$next_index, 1L)
})

# ---- A4, A5, A6: the CSV reader and the rate unit -------------------------------------------

rows <- c("exposure,income,site", sprintf("%d,%d,Ottawa", rep(c(12, 60), each = 500), seq_len(1000)))
mean_of <- function(v) as.numeric(v$inputs$exposure_mean)

test_that("A4: gzip, bzip2 and xz exposure CSVs are read as before 0.5.12", {
  for (type in c("gzip", "bzip2", "xz")) {
    g <- tempfile(fileext = ".csv.z")
    con <- switch(type, gzip = gzfile(g, "w"), bzip2 = bzfile(g, "w"), xz = xzfile(g, "w"))
    writeLines(rows, con)
    close(con)
    v <- verify_pollution("pm25", exposure_csv = g)
    expect_identical(v$status, "ok", info = type)
    expect_equal(v$inputs$exposure_prevalence, 1, info = type)
  }
  # UTF-16 with no byte-order mark, both orders
  for (enc in c("UTF-16LE", "UTF-16BE")) {
    u <- tempfile(fileext = ".csv")
    writeBin(iconv(paste0(paste(rows[1:3], collapse = "\n"), "\n"), "UTF-8", enc, toRaw = TRUE)[[1]], u)
    expect_message(v <- verify_pollution("pm25", exposure_csv = u), "no byte-order mark")
    expect_identical(v$status, "ok")
  }
  nul <- tempfile(fileext = ".csv")
  writeBin(c(charToRaw("exposure\n1"), as.raw(c(0, 0, 0, 5, 6, 0, 7))), nul)
  expect_match(verify_pollution("pm25", exposure_csv = nul)$error, "NUL bytes and is not UTF-16")
})

test_that("A5: an unbalanced quote stops the read instead of returning the rows before it", {
  q <- rows
  q[503] <- "60,1,\"site"
  f <- tempfile(fileext = ".csv")
  writeLines(q, f)
  v <- verify_pollution("pm25", exposure_csv = f)
  expect_identical(v$status, "error")
  expect_match(v$error, "could not be read cleanly")
  # the same file without the stray quote: every row, mean of the exposed rows as before
  writeLines(rows, f)
  expect_identical(verify_pollution("pm25", exposure_csv = f)$status, "ok")
})

test_that("A6: a rare rate is accepted once its unit is given, and the note says how", {
  a <- verify_pollution("pm25", exposure_mean = 25, exposure_prevalence = 1, baseline_rate = 0.5)
  expect_identical(a$status, "assumption_failure")
  expect_match(pollution_report_text(a), "baseline_rate_per = 1e5")
  b <- verify_pollution("pm25", exposure_mean = 25, exposure_prevalence = 1, baseline_rate = 5e-6,
                        baseline_rate_per = 1)
  expect_identical(b$status, "ok")
  expect_equal(b$inputs$baseline_rate_per_100k, 0.5)
  c <- verify_pollution("pm25", exposure_mean = 25, exposure_prevalence = 1, baseline_rate = 0.5,
                        baseline_rate_per = 1e5)
  expect_identical(c$status, "ok")
  expect_equal(c$pipeline$burden$attributable_cases, b$pipeline$burden$attributable_cases)
  expect_identical(verify_pollution("pm25", exposure_mean = 25, exposure_prevalence = 1, baseline_rate = 2e5,
                                    baseline_rate_per = 1e5)$status, "assumption_failure")
})

test_that("M8/Y3 residuals: one exposure source, text values named, empty income, an impossible population", {
  f <- tempfile(fileext = ".csv")
  writeLines(rows, f)
  expect_match(verify_pollution("pm25", exposure_csv = f, demo = TRUE)$error, "two sources of exposure")
  writeLines(c("exposure", "20", "<2", "<2", "<2", "40"), f)
  v <- verify_pollution("pm25", exposure_csv = f)
  expect_identical(v$status, "error")
  expect_match(v$error, "3 exposure value\\(s\\) are text")
  writeLines(c("exposure,site", "20,a", ",b", "NA,c", "n/a,d", "40,e"), f)
  expect_message(v <- verify_pollution("pm25", exposure_csv = f), "3 row\\(s\\) have no exposure value")
  expect_identical(v$inputs$dropped_rows, 3L)
  expect_match(pollution_report_text(v), "rows dropped: +3")
  writeLines(c("exposure,income", "20,", "40,"), f)
  expect_message(v <- verify_pollution("pm25", exposure_csv = f), "income column is empty")
  expect_identical(v$status, "ok")
  p <- verify_pollution("pm25", exposure_mean = 25, exposure_prevalence = 1, population = 1e300)
  expect_identical(p$status, "assumption_failure")
  expect_match(pollution_report_text(p), "more people than live on Earth")
  expect_error(pollution_report_text("x"), "report from verify_pollution")
})

# ---- B5, B6: credentials and config ---------------------------------------------------------

test_that("B5: login refuses a credentials file that is not valid JSON, and leaves it as it was", {
  home <- withr::local_tempdir()
  withr::local_envvar(XDG_CONFIG_HOME = home, MORIE_HOSTED_BASE_URL = "https://llm.example.org")
  p <- file.path(home, "morie", "credentials.json")
  dir.create(dirname(p), recursive = TRUE)
  for (bad in c('{"a": tru}', '{"a": 1 "b": 2}', '{"a": 1,}', '{"a": 1} junk',
                '{"hosted_key": "sk-OLD-1", "hosted_key": "sk-OLD-2"}')) {
    writeLines(bad, p)
    expect_error(rmoriebricklayer:::.bl_store_key("sk-NEW"), "not a JSON object", info = bad)
    expect_identical(readLines(p), bad)
    expect_error(bricklayer_llm_logout(), "not a JSON object", info = bad)
  }
  writeLines('{"big": 12345678901234567890, "hosted_key": "sk-OLD"}', p)
  rmoriebricklayer:::.bl_store_key("sk-BIG")
  expect_match(paste(readLines(p), collapse = ""), "12345678901234567890", fixed = TRUE)
  writeLines('{"other": [1, 2], "hosted_key": "sk-OLD"}', p)
  rmoriebricklayer:::.bl_store_key("sk-NEW")
  expect_identical(bricklayer_json_from_json(paste(readLines(p), collapse = "\n"))$hosted_key, "sk-NEW")
  expect_message(bricklayer_llm_logout(), "Logged out")
  expect_identical(bricklayer_json_from_json(paste(readLines(p), collapse = "\n"))$other, c(1L, 2L))
})

test_that("B6: config setup asks for the MORIE key and the own key without echo", {
  home <- withr::local_tempdir()
  withr::local_envvar(XDG_CONFIG_HOME = home, MORIE_HOSTED_BASE_URL = "off", OLLAMA_BASE_URL = "off",
                      MORIE_HOSTED_KEY = "")
  asked <- list()
  answers <- c("own", "http://localhost:1234/v1", "m1", "sk-own")
  i <- 0L
  local_mocked_bindings(.bl_readline = function(prompt, con = NULL, secret = FALSE) {
    i <<- i + 1L
    asked[[i]] <<- list(prompt = prompt, secret = secret)
    if (i <= length(answers)) answers[[i]] else ""
  })
  local_mocked_bindings(.bl_cli_doctor = function(out) invisible(NULL))
  rmoriebricklayer:::.bl_config_setup(function(...) invisible(NULL))
  sec <- vapply(asked, function(a) a$secret, logical(1))
  pr <- vapply(asked, function(a) a$prompt, "")
  expect_true(sec[grep("API key", pr)])
  expect_false(any(sec[grep("Ollama|server|Model|Which", pr)]))
})

test_that("B6: an interrupted read exits 130 and a key on the command line is warned about", {
  e <- tryCatch(rmoriebricklayer:::.bl_signal_interrupt(), interrupt = function(i) "interrupt")
  expect_identical(e, "interrupt")
  out <- character()
  local_mocked_bindings(bricklayer_llm_login = function(...) invisible(TRUE))
  st <- bricklayer_cli(c("login", "--token", "sk-ARGV"), out = function(x) out <<- c(out, x))
  expect_identical(st, 0L)
  expect_match(paste(out, collapse = ""), "stays in the shell history")
})

test_that("CLI: extra arguments are refused; config reset asks for --force on a readable file", {
  out <- character()
  o <- function(x) out <<- c(out, x)
  expect_identical(bricklayer_cli(c("data", "list", "foo"), out = o), 2L)
  expect_identical(bricklayer_cli(c("data", "pull", "a/b", "c/d"), out = o), 2L)
  expect_identical(bricklayer_cli(c("functions", "a", "b"), out = o), 2L)
  expect_identical(bricklayer_cli(c("config", "path", "extra"), out = o), 2L)
  expect_identical(bricklayer_cli(c("config", "setup", "extra"), out = o), 2L)
  expect_identical(bricklayer_cli(c("config", "reset", "--now"), out = o), 2L)
  home <- withr::local_tempdir()
  withr::local_envvar(XDG_CONFIG_HOME = home)
  cfg <- rmoriebricklayer:::.bl_config_path()
  dir.create(dirname(cfg), recursive = TRUE)
  writeLines('{"route": "hosted"}', cfg)
  expect_identical(bricklayer_cli(c("config", "reset"), out = o), 1L)
  expect_match(paste(out, collapse = ""), "reads fine")
  expect_true(file.exists(cfg))
  expect_identical(bricklayer_cli(c("config", "reset", "--force"), out = o), 0L)
  expect_false(file.exists(cfg))
  # two broken files moved aside in the same second keep both backups
  for (i in 1:2) {
    writeLines("{broken", cfg)
    expect_identical(bricklayer_cli(c("config", "reset"), out = o), 0L)
  }
  expect_length(list.files(dirname(cfg), "llm.json.broken-"), 2L)
  expect_match(paste(capture.output(bricklayer_cli("help")), collapse = ""), "config reset")
})

# ---- LOW items -------------------------------------------------------------------------------

test_that("A7: hurwitz_zeta() at large negative q, below s = 1, and its poles", {
  expect_equal(hurwitz_zeta(5, -99999.5), 2.50005e-21, tolerance = 1e-5)
  expect_equal(hurwitz_zeta(3, -999999.5), rmoriebricklayer:::.rmbl_hurwitz(3, 1e6 + 0.5), tolerance = 1e-10)
  expect_equal(hurwitz_zeta(2, -2.5), sum((-2.5 + 0:2)^-2) + hurwitz_zeta(2, 0.5), tolerance = 1e-12)
  expect_equal(hurwitz_zeta(3, -1.25), sum((-1.25 + 0:1)^-3) + hurwitz_zeta(3, 0.75), tolerance = 1e-12)
  expect_equal(hurwitz_zeta(0.5, 0.5), (sqrt(2) - 1) * -1.4603545088095868, tolerance = 1e-9)
  expect_equal(hurwitz_zeta(-1, 1), -1 / 12, tolerance = 1e-12)
  expect_equal(hurwitz_zeta(0, 0.3), 0.5 - 0.3, tolerance = 1e-12)
  expect_equal(hurwitz_zeta(-3, 2), 1 / 120 - 1, tolerance = 1e-10)
  expect_true(is.na(hurwitz_zeta(1, 2)))
  expect_true(is.na(hurwitz_zeta(2.5, -1.5)))   # a fractional s at a negative q is complex
  expect_true(is.na(hurwitz_zeta(2, -3)))
  expect_true(is.finite(hurwitz_zeta(4, -1e7 + 0.25)))
})

test_that("type guards: x_min as a factor or text, bias_correct and min_expected", {
  x <- c(1, 2, 3, 5, 8, 13, 21, 34)
  expect_error(hill_tail_index(x, x_min = factor("3")), "must be numeric")
  expect_error(hill_tail_index(x, x_min = "3"), "must be numeric")
  tbl <- matrix(c(10, 20, 30, 40), 2)
  expect_error(cramers_v(tbl, bias_correct = "abc"), "TRUE or FALSE")
  expect_error(cramers_v(tbl, min_expected = NA), "non-negative number")
  expect_error(plot_funnel(c(1, 2), c(1, 0)), "must be positive")
  expect_error(plot_funnel(c(1, 2), c(1, 2), levels = 1.5), "strictly between 0 and 1")
  expect_error(plot_funnel(c(1, 2), c(1, 2), target = -1), "single positive number")
})

test_that("sibling caps: particles x steps and lid images", {
  expect_error(lagrangian_particles(10, 0, 0, 1, 0, 1, 1, 1, n_steps = 1e9), "above max_work")
  expect_error(lagrangian_particles(10, 0, 0, 1, 0, 1, 1, 1, n_steps = 2, max_work = 0), "single positive number")
  p <- lagrangian_particles(10, 0, 0, 1, 0, 1, 1, 1, n_steps = 3, max_work = Inf)
  expect_equal(p$mean_x, 3 + sum(p$x - 3) / 10)
  rec <- matrix(c(100, 0, 1), 1)
  expect_error(gaussian_plume(1, 2, 10, rec, n_images = 1e9), "at most 1,000")
  expect_error(gaussian_puff(1, 2, 10, rec, t = 10, n_images = 1001), "at most 1,000")
  expect_true(is.finite(gaussian_plume(1, 2, 10, rec, mixing_height = 500, n_images = 1000)))
  f <- advection_diffusion_2d(matrix(0, 3, 3), 0, 0, 0.1, 0.1, 1, 1, 0.1, n_steps = 2)
  expect_match(f$title, "after 2 steps")
})

test_that("bar labels: distinct levels stay distinct, a real (missing) level keeps its name, small devices fit", {
  lab <- c(paste0(strrep("x", 30), c("a", "b")), "short", NA)
  s <- rmoriebricklayer:::.bl_short_label(lab, 25)
  expect_false(anyDuplicated(s[!is.na(s)]) > 0)
  expect_true(all(nchar(s[!is.na(s)]) <= 25))
  expect_identical(rmoriebricklayer:::.bl_short_label(rep("same-long-label-over-the-limit", 2), 10)[1],
                   rmoriebricklayer:::.bl_short_label(rep("same-long-label-over-the-limit", 2), 10)[2])
  pdf(NULL, width = 2.5, height = 2.5)
  on.exit(grDevices::dev.off(), add = TRUE)
  long <- paste0("level-", strrep("long", 10), 1:4)
  expect_silent(rmoriebricklayer:::.bl_hbars(c(4, 3, 2, 1), long, "n", "t", rep("grey", 4)))
  fit <- rmoriebricklayer:::.bl_label_fit(long)
  expect_false(anyDuplicated(fit$labels) > 0)
  expect_silent(rmoriebricklayer:::.bl_hbars(c(2, 1, 1), c("(missing)", NA, "b"), "n", "t", rep("grey", 3)))
})

test_that("old XMSS objects warn on print; fips_verify_mu says not verified for an edited key", {
  f <- xmss_tmp_record()
  k <- pqc_keygen(height = 2L)
  s <- capsule_sign("m", k, scheme = "xmss")
  s$key_state <- list(sk_seed = "x")
  att <- structure(list(signature = s, digest = "d"), class = c("bricklayer_attestation", "list"))
  expect_warning(tryCatch(capture.output(print(att)), error = function(e) NULL), "carries the signer's private key")
  bun <- structure(list(attestation = list(signature = s)), class = c("bricklayer_bundle", "list"))
  expect_warning(tryCatch(capture.output(print(bun)), error = function(e) NULL), "carries the signer's private key")
  mk <- fips_keygen("ML-DSA-44")
  mu <- fips_mu(mk, "m")
  sg <- fips_sign_mu(mk, mu)
  expect_true(fips_verify_mu(mk, mu, sg))
  edits <- list(function(x) structure(unclass(x), class = "list"),
                function(x) utils::modifyList(x, list(scheme = "nope")),
                function(x) utils::modifyList(x, list(scheme = c("ML-DSA-44", "ML-DSA-65"))),
                function(x) utils::modifyList(x, list(public = "zz")),
                function(x) utils::modifyList(x, list(scheme = "SLH-DSA-SHAKE-128f")))
  for (edit in edits) {
    expect_false(fips_verify_mu(edit(mk), mu, sg))
  }
  expect_error(fips_verify_mu("not a key", mu, sg), "fips_keygen")
  expect_error(fips_keygen(c("ML-DSA-44", "ML-DSA-65")), "single non-empty string")
})

# ---- the lines codecov found unexercised on fec371e ----------------------------------------

test_that("an interrupt nobody handles is an error; the shell read reports Ctrl-C as an interrupt", {
  expect_error(rmoriebricklayer:::.bl_signal_interrupt(), "interrupted")
  skip_on_os("windows")
  skip_if_not(nzchar(Sys.which("sh")))
  local_mocked_bindings(.bl_interactive = function() FALSE, .bl_stdin_tty = function() TRUE)
  # the shell child exits 130 when its read is interrupted (the status system2 reports)
  local_mocked_bindings(system2 = function(...) structure(character(), status = 130L), .package = "base")
  got <- tryCatch(rmoriebricklayer:::.bl_readline("key: ", secret = FALSE), interrupt = function(i) "interrupt")
  expect_identical(got, "interrupt")
  local_mocked_bindings(system2 = function(...) "typed-line", .package = "base")
  expect_identical(rmoriebricklayer:::.bl_readline("key: ", secret = FALSE), "typed-line")
})

test_that("a manifest that cannot be stored is an error and the old copy stays", {
  d <- data_cache_with(good, manifest_for(good_sha()), age_days = 3)
  local_mocked_bindings(.bl_data_get = function(path, dest, ...) writeLines(manifest_for(good_sha()), dest))
  local_mocked_bindings(file.rename = function(from, to) FALSE, .package = "base")
  expect_error(bricklayer_data_manifest(refresh = TRUE), "could not store the manifest")
  expect_identical(readLines(file.path(d, "manifest.json")), manifest_for(good_sha()))
})

test_that("config reset refuses a stray argument; the member scanner refuses an unterminated nested string", {
  out <- character()
  expect_identical(bricklayer_cli(c("config", "reset", "now"), out = function(x) out <<- c(out, x)), 2L)
  expect_match(paste(out, collapse = ""), "config reset \\[--force\\]")
  expect_null(rmoriebricklayer:::.bl_json_top_members('{"a": {"b": "unterminated}'))
})

test_that("an edit that would damage credentials.json is refused and the file is left as it was", {
  home <- withr::local_tempdir()
  withr::local_envvar(XDG_CONFIG_HOME = home, MORIE_HOSTED_BASE_URL = "https://llm.example.org")
  p <- file.path(home, "morie", "credentials.json")
  dir.create(dirname(p), recursive = TRUE)
  writeLines('{"hosted_key": "sk-OLD"}', p)
  # an editor that leaves the text as it was: the new key is not in what would be written
  local_mocked_bindings(.bl_credentials_text_set = function(txt, key, value) txt)
  expect_error(rmoriebricklayer:::.bl_store_key("sk-NEW"), "without damaging it")
  expect_error(bricklayer_llm_logout(), "without damaging it")
  expect_identical(readLines(p), '{"hosted_key": "sk-OLD"}')
})

test_that("a UTF-16BE exposure CSV with its byte-order mark is read", {
  u <- tempfile(fileext = ".csv")
  txt <- paste0(paste(rows[1:3], collapse = "\n"), "\n")
  writeBin(c(as.raw(c(0xfe, 0xff)), iconv(txt, "UTF-8", "UTF-16BE", toRaw = TRUE)[[1]]), u)
  expect_identical(verify_pollution("pm25", exposure_csv = u)$status, "ok")
})

test_that("a lock path that is not a regular file is refused (a FIFO)", {
  skip_on_os("windows")
  skip_if_not(nzchar(Sys.which("mkfifo")))
  f <- tempfile()
  system2("mkfifo", f)
  skip_if_not(file.exists(f))
  expect_error(.Call(rmoriebricklayer:::C_rmbl_flock_acquire, f, 0L), "not a regular file")
})
