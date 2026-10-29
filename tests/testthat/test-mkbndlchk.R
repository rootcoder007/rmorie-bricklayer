# SPDX-License-Identifier: AGPL-3.0-or-later
# mkbndlchk(): a bundle run as a recipient would, and its manifest read.

# A small bundle whose runner is `run` (lines of R), zipped as mkbndl()
# zips; `config` is the text of its config.json, or NULL for none; `extra`
# names more files (path inside the bundle = lines).
fake_bundle <- function(d, run, config = NULL, top = "fake_v1",
                        extra = list()) {
  src <- file.path(d, paste0("src_", top))
  dir.create(file.path(src, top), recursive = TRUE)
  if (!is.null(run)) {
    writeLines(run, file.path(src, top, "setup_and_run.R"))
  } else {
    writeLines("no runner", file.path(src, top, "README.txt"))
  }
  if (!is.null(config)) {
    writeLines(config, file.path(src, top, "config.json"))
  }
  writeLines("#!/bin/sh", file.path(src, top, "start_here.sh"))
  for (f in names(extra)) {
    dir.create(dirname(file.path(src, top, f)), recursive = TRUE,
               showWarnings = FALSE)
    writeLines(extra[[f]], file.path(src, top, f))
  }
  zip <- file.path(d, paste0(top, ".zip"))
  .bndl_zip(src, top, zip)
  zip
}

# A runner that prints a line, records its arguments and writes a manifest
# with these statuses, in this input mode.
man_run <- function(status, mode = "csv") {
  meta <- if (is.null(mode)) "" else sprintf('"input_mode": "%s"', mode)
  res <- toString(
    sprintf('"c%d": {"status": "%s"}', seq_along(status), status)
  )
  c(
    "cat('running the checks\\n')",
    "writeLines(commandArgs(TRUE), 'args.txt')",
    "dir.create('results_1')",
    sprintf(
      paste0(
        "writeLines('{\"meta\": {%s}, ",
        "\"results\": {%s}}', 'results_1/manifest.json')"
      ),
      meta, res
    )
  )
}

# Whether a check ran clean. Where escaped processes cannot be detected
# (a process group on macOS) the isolation row fails closed by design:
# there every other row must be ok and the row must say why.
ran_ok <- function(a) {
  iso <- a$checks$check == "isolation"
  blind <- grepl("cannot detect escaped processes", a$checks$detail[iso],
                 fixed = TRUE)
  if (isTRUE(blind)) all(a$checks$ok[!iso]) else isTRUE(a$ok)
}

expect3 <- '{"expected": {"total_checks": 3, "pass_csv": 2, "pass_real": 3}}'

test_that("a bundle that runs and gives the expected counts is verified", {
  d <- withr::local_tempdir()
  zip <- fake_bundle(d, man_run(c("PASS", "PASS", "INFO")), expect3)
  w <- file.path(d, "w1")
  a <- mkbndlchk(zip, dir = w, keep = TRUE)
  expect_s3_class(a, "rmbl_bundle_audit")
  expect_true(ran_ok(a))
  expect_identical(a$mode, "csv")
  expect_identical(
    a$counts, c(total = 3L, pass = 2L, differ = 0L, info = 1L)
  )
  # the isolation row depends on the machine (a process group on macOS
  # and on Linux without user namespaces): ok there too, a warning, or
  # where escapes cannot be seen (macOS) a refusal that says so
  iso <- a$checks$check == "isolation"
  expect_true(all(a$checks$ok[!iso]))
  expect_true(isTRUE(a$checks$ok[iso]) ||
                identical(a$checks$severity[iso], "warn") ||
                grepl("cannot detect", a$checks$detail[iso], fixed = TRUE))
  expect_true(dir.exists(a$dir))
  expect_identical(readLines(file.path(a$dir, "args.txt")), "--quick")
  expect_match(a$checks$detail[4L], "pass_csv expects 2/3 PASS", fixed = TRUE)
  expect_match(a$checks$detail[5L], "1 launcher(s)", fixed = TRUE)
  out <- capture.output(res <- withVisible(print(a)))
  expect_false(res$visible)
  expect_match(out[1L], "Bundle audit: VERIFIED", fixed = TRUE)
  expect_false(any(grepl("last lines", out, fixed = TRUE)))
  # by default the folder is removed afterwards
  b <- mkbndlchk(zip)
  expect_true(ran_ok(b))
  expect_true(is.na(b$dir))
})

test_that("the data file and synthetic mode reach the run", {
  d <- withr::local_tempdir()
  zip <- fake_bundle(d, man_run(c("INFO", "INFO"), mode = "synthetic"))
  csv <- file.path(d, "my data.csv")
  writeLines("a,b", csv)
  a <- mkbndlchk(zip, data = csv, synthetic = TRUE, keep = TRUE,
                 dir = file.path(d, "w"))
  expect_identical(
    readLines(file.path(a$dir, "args.txt")),
    c("--quick", "--synthetic", "--data", normalizePath(csv, winslash = "/"))
  )
  # synthetic runs mark every check INFO, so they are not compared
  expect_true(ran_ok(a))
  expect_identical(a$checks$detail[4L], "not compared: a synthetic run")
})

test_that("a differing check or other counts than expected fail", {
  d <- withr::local_tempdir()
  a <- mkbndlchk(fake_bundle(d, man_run(c("PASS", "DIFFER", "PASS")),
                             expect3, top = "differ_v1"))
  expect_false(a$ok)
  expect_identical(a$checks$detail[3L], "1 DIFFER")
  out <- capture.output(print(a))
  expect_match(out[1L], "Bundle audit: NOT VERIFIED", fixed = TRUE)
  expect_true(any(grepl("running the checks", out, fixed = TRUE)))
  b <- mkbndlchk(fake_bundle(d, man_run(c("PASS", "PASS")), expect3,
                             top = "fewer_v1"))
  expect_false(b$ok)
  expect_match(b$checks$detail[4L], "the csv run gave 2/2", fixed = TRUE)
  # a run on the .RData compares pass_real
  r <- mkbndlchk(fake_bundle(d, man_run(rep("PASS", 3L), mode = "real"),
                             expect3, top = "real_v1"))
  expect_true(ran_ok(r))
  expect_match(r$checks$detail[4L], "pass_real expects 3/3", fixed = TRUE)
  # a manifest that records no input mode is a run on the real data
  n <- mkbndlchk(fake_bundle(d, man_run(rep("PASS", 3L), mode = NULL),
                             expect3, top = "nomode_v1"))
  expect_identical(n$mode, "real")
  expect_true(ran_ok(n))
})

test_that("a bundle with no expected counts is not compared", {
  d <- withr::local_tempdir()
  a <- mkbndlchk(fake_bundle(d, man_run("PASS"), top = "nocfg_v1"))
  expect_true(ran_ok(a))
  expect_identical(
    a$checks$detail[4L], "not compared: config.json expects none"
  )
  b <- mkbndlchk(fake_bundle(d, man_run("PASS"), '{"project": {}}',
                             top = "noexp_v1"))
  expect_true(ran_ok(b))
})

test_that("a run that stops, or writes no manifest, fails", {
  d <- withr::local_tempdir()
  a <- mkbndlchk(fake_bundle(d, c("cat('broken\\n')", "quit(status = 3)"),
                             top = "stops_v1"))
  expect_false(a$ok)
  expect_identical(a$checks$ok[1:4], rep(FALSE, 4L))
  expect_identical(a$checks$detail[1L], "exit status 3")
  expect_identical(a$checks$detail[3:4], rep("no manifest", 2L))
  expect_true(is.na(a$mode))
  expect_true(all(is.na(a$counts)))
  expect_true("broken" %in% a$log)
  out <- capture.output(print(a))
  expect_match(out[1L], "NOT VERIFIED", fixed = TRUE)
})

test_that("the child R runs without the test harness's startup file", {
  d <- withr::local_tempdir()
  zip <- fake_bundle(d, man_run("PASS"))
  withr::local_envvar(R_TESTS = file.path(d, "no-such-startup.R"))
  expect_true(ran_ok(mkbndlchk(zip)))
  expect_identical(Sys.getenv("R_TESTS"), file.path(d, "no-such-startup.R"))
})

test_that("mkbndlchk refuses what is not a bundle", {
  d <- withr::local_tempdir()
  zip <- fake_bundle(d, man_run("PASS"))
  expect_error(mkbndlchk(file.path(d, "none.zip")), "not an existing .zip")
  expect_error(mkbndlchk(d), "not an existing .zip")
  txt <- file.path(d, "notes.txt")
  writeLines("x", txt)
  expect_error(mkbndlchk(txt), "not an existing .zip")
  expect_error(mkbndlchk(zip, data = file.path(d, "none.csv")),
               "`data` is not an existing file")
  expect_error(mkbndlchk(zip, data = d), "`data` is not an existing file")
  expect_error(mkbndlchk(zip, dir = d), "`dir` already exists")
  expect_error(mkbndlchk(zip, keep = NA), "keep")
  expect_error(
    mkbndlchk(fake_bundle(d, NULL, top = "norun_v1")),
    "has no setup_and_run.R"
  )
})

test_that("launchers the zip does not mark executable are a warning", {
  ok <- .bndlchk_launchers(c("a/start_here.sh" = 33261, "a/x.R" = 33188))
  expect_true(ok$ok)
  expect_identical(ok$severity, "warn")
  bad <- .bndlchk_launchers(c("a/START_HERE.command" = 33188))
  expect_false(bad$ok)
  expect_match(bad$detail, "a/START_HERE.command", fixed = TRUE)
  # a zip mkbndl() wrote marks .sh and .command files 0755
  d <- withr::local_tempdir()
  m <- .bndlchk_cd(fake_bundle(d, man_run("PASS")))$modes
  expect_identical(unname(m[["fake_v1/start_here.sh"]]), 33261)
  expect_identical(unname(m[["fake_v1/setup_and_run.R"]]), 33188)
  # a directory claimed beyond the file's end is not read (readBin() would
  # allocate the 4 GB claimed)
  z <- fake_bundle(d, man_run("PASS"), top = "hostile_v1")
  b <- readBin(z, "raw", file.size(z))
  at <- grepRaw(as.raw(c(0x50, 0x4b, 0x05, 0x06)), b, all = TRUE)
  b[at[length(at)] + 12:15] <- as.raw(0xff)
  writeBin(b, z)
  expect_length(.bndlchk_cd_raw(z)$cd, 0L)
  # a file with no end-of-central-directory record has no modes
  junk <- file.path(d, "junk.zip")
  writeBin(as.raw(1:200), junk)
  expect_length(.bndlchk_cd_raw(junk)$cd, 0L)
})

test_that("rmbl pack --check runs mkbndlchk from a terminal", {
  d <- withr::local_tempdir()
  run <- function(...) {
    rec <- new.env()
    rec$buf <- character()
    st <- blcli(c(...), out = function(s) rec$buf <- c(rec$buf, s))
    list(status = st, text = paste(rec$buf, collapse = ""))
  }
  good <- fake_bundle(d, man_run(c("PASS", "PASS", "INFO")), expect3)
  r <- run("pack", "--check", good)
  expect_identical(r$status, 0L)
  expect_match(r$text, "Bundle audit: VERIFIED", fixed = TRUE)
  expect_match(r$text, "WARNING: pack --check runs the bundle's code",
               fixed = TRUE)
  expect_match(.bl_verb_usage("pack", "rmbl"), "RUNS THE BUNDLE'S CODE",
               fixed = TRUE)
  r <- run("pack", "--check", good, "--synthetic", "--keep")
  expect_identical(r$status, 0L)
  bad <- fake_bundle(d, man_run("DIFFER"), top = "bad_v1")
  r <- run("pack", "--check", bad)
  expect_identical(r$status, 1L)
  expect_match(r$text, "NOT VERIFIED", fixed = TRUE)
})

test_that("a starter project's bundle passes its own check", {
  skip_on_cran()
  d <- withr::local_tempdir()
  p <- mkbndlproj(file.path(d, "starter"), title = "Starter")
  b <- mkbndl(p$dir, dest = d, overwrite = TRUE)
  a <- mkbndlchk(b$path, synthetic = TRUE)
  expect_true(ran_ok(a))
  expect_identical(a$mode, "synthetic")
  expect_gt(a$counts[["total"]], 0L)
})

# A zip of these entries (path inside the zip = file on disk), written as
# mkbndl() writes one, whatever the names: duplicates, "..", long names.
raw_zip <- function(zip, ents) {
  stamp <- .bndl_dos_time(Sys.time())
  body <- raw()
  cdir <- raw()
  for (i in seq_along(ents)) {
    e <- .bndl_zip_entry(ents[[i]], names(ents)[i], stamp)
    cdir <- c(cdir, e$central, .bndl_u32(length(body)), e$name)
    body <- c(body, e$local, e$data)
  }
  n <- length(ents)
  writeBin(c(body, cdir, .bndl_u32(0x06054b50), .bndl_u16(0), .bndl_u16(0),
             .bndl_u16(n), .bndl_u16(n), .bndl_u32(length(cdir)),
             .bndl_u32(length(body)), .bndl_u16(0)), zip)
  zip
}

test_that("a results folder the zip carries is never read as the run's", {
  d <- withr::local_tempdir()
  planted <- list(
    "results_29991231/manifest.json" =
      '{"meta": {"input_mode": "csv"}, "results": {"c1": {"status": "PASS"}}}'
  )
  # the runner writes nothing and says so, but exits 0
  quiet <- c("cat('Step 5/5: NOT completed (no manifest.json written)\\n')",
             "quit(status = 0)")
  a <- mkbndlchk(fake_bundle(d, quiet, top = "fakepass_v1", extra = planted))
  expect_false(a$ok)
  expect_identical(a$checks$check[c(1L, 2L, 6L)],
                   c("run finished", "manifest written",
                     "no results packed in the zip"))
  expect_identical(a$checks$ok[c(1L, 2L, 6L)], rep(FALSE, 3L))
  expect_match(a$checks$detail[1L], "NOT completed", fixed = TRUE)
  expect_match(a$checks$detail[6L], "results_29991231", fixed = TRUE)
  expect_true(all(is.na(a$counts)))
  # a run that writes its own manifest is read, not the planted one, and
  # the planted folder still fails the check
  b <- mkbndlchk(fake_bundle(d, man_run(c("PASS", "DIFFER")),
                             top = "both_v1", extra = planted))
  expect_identical(b$counts[["differ"]], 1L)
  expect_match(b$checks$detail[2L], "results_1", fixed = TRUE)
  expect_false(b$ok)
  # the run's own folder is found among several by the runner's own line
  two <- c(man_run("PASS"), "dir.create('results_2')",
           "writeLines('{}', 'results_2/manifest.json')",
           "cat('  Results folder: ', normalizePath('results_1'), '\\n')")
  t2 <- mkbndlchk(fake_bundle(d, two, top = "two_v1"))
  expect_true(ran_ok(t2))
  expect_match(t2$checks$detail[2L], "results_1/manifest.json", fixed = TRUE)
})

test_that("the run gets no credentials, a fresh HOME and no orphans", {
  skip_on_os("windows")
  d <- withr::local_tempdir()
  withr::local_envvar(
    RMBL_KEY = "fake-rmbl-key", OPENAI_API_KEY = "sk-fake",
    ANTHROPIC_API_KEY = "fake", GITHUB_TOKEN = "ghp_fake",
    IA_S3_ACCESS_KEY = "fake", IA_S3_SECRET_KEY = "fake",
    MY_DB_PASSWORD = "fake"
  )
  run <- c(
    "writeLines(names(Sys.getenv()), 'envnames.txt')",
    "writeLines(Sys.getenv(c('HOME', 'TMPDIR')), 'home.txt')",
    "system('sleep 300 > /dev/null 2>&1 & echo $! > orphan.pid')",
    man_run("PASS")
  )
  a <- mkbndlchk(fake_bundle(d, run, top = "leak_v1"), keep = TRUE,
                 dir = file.path(d, "w"))
  expect_true(ran_ok(a))
  got <- readLines(file.path(a$dir, "envnames.txt"))
  expect_false(any(c("RMBL_KEY", "OPENAI_API_KEY", "ANTHROPIC_API_KEY",
                     "GITHUB_TOKEN", "IA_S3_ACCESS_KEY", "IA_S3_SECRET_KEY",
                     "MY_DB_PASSWORD") %in% got))
  expect_true("PATH" %in% got)
  home <- readLines(file.path(a$dir, "home.txt"))
  expect_false(home[[1L]] == Sys.getenv("HOME"))
  expect_false(dir.exists(home[[1L]]))
  expect_true(startsWith(home[[2L]], home[[1L]]))
  # what the run put in the background was killed with it
  pid <- as.integer(readLines(file.path(a$dir, "orphan.pid")))
  alive <- isTRUE(tools::pskill(pid, 0L))
  if (alive) tools::pskill(pid)
  expect_false(alive)
})

test_that("the run's environment keeps only what R needs", {
  withr::local_envvar(
    PATH = "/usr/bin:/bin", LANG = "C.UTF-8", LC_TIME = "C",
    OPENAI_API_KEY = "sk-fake", https_proxy = "http://u:p@proxy:3128",
    http_proxy = "http://proxy:3128", LC_FAKE_SECRET = "fake",
    LC_IDENTIFICATION = "C"
  )
  e <- .rmbl_envmin("/tmp/h")
  # only the locale's own LC_ variables
  expect_false("LC_FAKE_SECRET" %in% names(e))
  expect_identical(e[["LC_IDENTIFICATION"]], "C")
  expect_identical(e[["HOME"]], "/tmp/h")
  expect_identical(e[["TMPDIR"]], file.path("/tmp/h", "tmp"))
  expect_identical(e[["PATH"]], "/usr/bin:/bin")
  expect_identical(e[["LC_TIME"]], "C")
  expect_identical(e[["http_proxy"]], "http://proxy:3128")
  expect_false(any(c("OPENAI_API_KEY", "https_proxy") %in% names(e)))
  expect_identical(
    e[["R_LIBS"]], paste(.libPaths(), collapse = .Platform$path.sep)
  )
  expect_identical(
    .rmbl_envdrop(c("PATH", "RMBL_KEY", "GH_TOKEN", "my_secret", "IA_X",
                    "LANG", "AWS_PROFILE", "DB_PASSWD")),
    c("RMBL_KEY", "GH_TOKEN", "my_secret", "IA_X", "AWS_PROFILE",
      "DB_PASSWD")
  )
  # the Windows list: connection strings, *_PWD, other LC_ names, and a
  # value that is a URL with a password
  n <- c("DATABASE_URL", "APP_DATABASE_URL", "SLACK_WEBHOOK_URL",
         "SENTRY_DSN", "PG_DSN", "DB_PWD", "SMTP_PASS", "X_SECRET",
         "X_TOKEN", "X_API_KEY", "LC_FAKEVAR", "MIRROR", "LC_ALL",
         "LC_CTYPE", "PWD", "LANG", "HOME")
  v <- c(rep("fake", 11L), "https://u:fake@host/x", "C", "C", "/x", "C",
         "/h")
  expect_identical(.rmbl_envdrop(n, v), n[1:12])
  # a password with no user name, and a service's secret key
  expect_identical(
    .rmbl_envdrop(c("CACHE_URL", "STRIPE_SK", "TASK", "DISK", "HOME"),
                  c("redis://:fake@h:6379/0", "fake", "x", "y", "/h")),
    c("CACHE_URL", "STRIPE_SK")
  )
})

test_that("the default time limit is 30 minutes", {
  got <- new.env()
  stub <- function(rscript, args, home, tmout, log) {
    got$tmout <- tmout
    got$home <- home
    list(status = 0L, mode = "process group")
  }
  local_mocked_bindings(.bndlchk_posix = stub, .bndlchk_win = stub)
  root <- withr::local_tempdir()
  withr::local_options(rmbl.bundle.timeout = NULL)
  expect_identical(.bndlchk_run(root, NULL, FALSE)$status, 0L)
  expect_identical(got$tmout, 1800L)
  expect_false(dir.exists(got$home))
  withr::local_options(rmbl.bundle.timeout = 60)
  .bndlchk_run(root, NULL, FALSE)
  expect_identical(got$tmout, 60L)
})

test_that("zips that cannot be unzipped safely are refused in words", {
  d <- withr::local_tempdir()
  n0 <- length(list.files(tempdir(), "^bndlchk"))
  f <- file.path(d, "f.R")
  writeLines("cat('second runner\\n')", f)
  dup <- raw_zip(file.path(d, "dup.zip"),
                 stats::setNames(c(f, f), rep("b/setup_and_run.R", 2L)))
  expect_error(mkbndlchk(dup), "holds the same entry twice")
  case <- raw_zip(file.path(d, "case.zip"),
                  c("b/setup_and_run.R" = f, "b/SETUP_and_run.R" = f))
  expect_error(mkbndlchk(case), "holds the same entry twice")
  # an empty or "." part names the same file: unzip writes b/setup_and_run.R
  for (nm in c("b//setup_and_run.R", "b/./setup_and_run.R")) {
    z <- raw_zip(file.path(d, "dd.zip"),
                 stats::setNames(c(f, f), c("b/setup_and_run.R", nm)))
    expect_error(mkbndlchk(z), "holds the same entry twice", info = nm)
  }
  up2 <- raw_zip(file.path(d, "up2.zip"), c("b/./../x.R" = f))
  expect_error(mkbndlchk(up2), "leave its folder")
  up <- raw_zip(file.path(d, "up.zip"), c("b/../../x.R" = f))
  expect_error(mkbndlchk(up), "leave its folder")
  ab <- raw_zip(file.path(d, "ab.zip"), c("/tmp/x.R" = f))
  expect_error(mkbndlchk(ab), "leave its folder")
  long <- raw_zip(file.path(d, "long.zip"),
                  stats::setNames(f, file.path("b", strrep("n", 300L))))
  expect_error(mkbndlchk(long), "too long")
  nul <- raw_zip(file.path(d, "nul.zip"), c("b/abQcd.R" = f))
  b <- readBin(nul, "raw", file.size(nul))
  q <- grepRaw(charToRaw("abQcd"), b, all = TRUE)
  b[q + 2L] <- as.raw(0L)
  writeBin(b, nul)
  expect_error(mkbndlchk(nul), "NUL byte")
  expect_length(.bndlchk_cd_walk(.bndlchk_cd_raw(nul)$cd)$modes, 1L)
  # an end record counting 65535 entries is a zip64 archive
  z64 <- raw_zip(file.path(d, "z64.zip"), c("b/setup_and_run.R" = f))
  b <- readBin(z64, "raw", file.size(z64))
  at <- grepRaw(as.raw(c(0x50, 0x4b, 0x05, 0x06)), b)
  b[at + 8:11] <- as.raw(0xff)
  writeBin(b, z64)
  expect_error(mkbndlchk(z64), "more than 65535 entries")
  # a count that disagrees with the directory: damaged
  bad <- raw_zip(file.path(d, "bad.zip"), c("b/setup_and_run.R" = f))
  b <- readBin(bad, "raw", file.size(bad))
  b[grepRaw(as.raw(c(0x50, 0x4b, 0x05, 0x06)), b) + 10L] <- as.raw(7L)
  writeBin(b, bad)
  expect_error(mkbndlchk(bad), "end record counts 7")
  junk <- file.path(d, "junk.zip")
  writeBin(as.raw(1:200), junk)
  expect_error(mkbndlchk(junk), "not a readable zip")
  # nothing was run or unzipped
  expect_length(list.files(tempdir(), "^bndlchk"), n0)
})

test_that("a large central directory is read in linear time", {
  skip_on_cran()
  n <- 30000L
  one <- function(i) {
    nm <- charToRaw(sprintf("b/f%05d.txt", i))
    c(.bndl_u32(0x02014b50), as.raw(rep(0L, 24L)), .bndl_u16(length(nm)),
      as.raw(rep(0L, 8L)), .bndl_u32(33188 * 65536), .bndl_u32(0), nm)
  }
  cd <- unlist(lapply(seq_len(n), one), use.names = FALSE)
  t <- system.time(w <- .bndlchk_cd_walk(cd))[["elapsed"]]
  m <- w$modes
  expect_length(m, n)
  expect_identical(rawToChar(w$names[[n]]), sprintf("b/f%05d.txt", n))
  expect_true(all(m == 33188))
  expect_lt(t, 10)
})

test_that("the Windows way, and no bash or env on the PATH", {
  skip_on_os("windows")
  root <- withr::local_tempdir()
  writeLines(c("writeLines(names(Sys.getenv()), 'n.txt')",
               "writeLines(Sys.getenv('HOME'), 'h.txt')"),
             file.path(root, "setup_and_run.R"))
  withr::local_envvar(RMBL_KEY = "fake", GITHUB_TOKEN = "fake")
  got <- new.env()
  local_mocked_bindings(.rmbl_wjob = function(cmd, log, tmout) {
    got$cmd <- cmd
    got$env <- names(Sys.getenv())
    got$home <- Sys.getenv("HOME")
    got$tmout <- tmout
    0L
  })
  r <- .bndlchk_run(root, NULL, FALSE, win = TRUE)
  expect_identical(r$status, 0L)
  expect_identical(r$isolation, "job object")
  expect_match(got$cmd, "setup_and_run.R\" \"--quick\"", fixed = TRUE)
  expect_false(any(c("RMBL_KEY", "GITHUB_TOKEN") %in% got$env))
  expect_false(got$home == Sys.getenv("HOME"))
  expect_identical(got$tmout, 1800L)
  expect_identical(Sys.getenv("RMBL_KEY"), "fake")

  local_mocked_bindings(Sys.which = function(names) "", .package = "base")
  expect_true(file.exists("/usr/bin/env"))
  expect_true(file.exists("/bin/sh"))
  expect_identical(.bndlchk_run(root, NULL, FALSE, win = FALSE)$status, 0L)
})

test_that("an unzip that fails and a manifest that is not an object", {
  d <- withr::local_tempdir()
  zip <- fake_bundle(d, man_run("PASS"))
  local_mocked_bindings(unzip = function(...) warning("error 1 in extracting"),
                        .package = "utils")
  expect_error(mkbndlchk(zip), "could not be unzipped: error 1")
  root <- withr::local_tempdir()
  dir.create(file.path(root, "results_x"))
  writeLines('"text"', file.path(root, "results_x", "manifest.json"))
  expect_null(.bndlchk_manifest(root))
  writeLines('{"results": {"a": 1, "b": {"status": "PASS"}}}',
             file.path(root, "results_x", "manifest.json"))
  m <- .bndlchk_manifest(root)
  expect_identical(m$counts[["total"]], 2L)
  expect_identical(m$counts[["pass"]], 1L)
})

# PIDs of processes whose first argument is exactly `argv0` (Linux /proc)
procs_named <- function(argv0) {
  pids <- list.files("/proc", pattern = "^[0-9]+$")
  hit <- vapply(pids, function(p) {
    # a process can end between the listing and the read
    a <- tryCatch(readBin(file.path("/proc", p, "cmdline"), "raw", 4096L),
                  error = function(e) raw(), warning = function(w) raw())
    if (!length(a)) return(FALSE)
    z <- which(a == as.raw(0L))
    first <- if (length(z)) a[seq_len(z[1L] - 1L)] else a
    identical(rawToChar(first), argv0)
  }, NA)
  as.integer(pids[hit])
}

test_that("in a PID namespace even a setsid daemon dies with the run", {
  skip_on_os(c("windows", "mac", "solaris"))
  skip_if(is.null(.bndlchk_unshare()), "no unprivileged PID namespace here")
  skip_if(!nzchar(Sys.which("setsid")), "no setsid")
  d <- withr::local_tempdir()
  tok <- file.path(d, paste0("rmbl_sleep_", basename(tempfile(""))))
  file.symlink(Sys.which("sleep"), tok)
  run <- c(sprintf("system('setsid -f %s 300 > /dev/null 2>&1')", tok),
           "Sys.sleep(0.5)", man_run("PASS"))
  a <- mkbndlchk(fake_bundle(d, run, top = "daemon_v1"))
  expect_true(ran_ok(a))
  expect_identical(a$isolation, "pid namespace")
  row <- a$checks[a$checks$check == "isolation", ]
  expect_true(row$ok)
  Sys.sleep(0.3)
  left <- procs_named(tok)
  for (p in left) tools::pskill(p)
  expect_length(left, 0L)
  expect_match(paste(capture.output(print(a)), collapse = "\n"),
               "pid namespace", fixed = TRUE)
})

test_that("without unshare the run falls back to its process group", {
  skip_on_os("windows")
  local_mocked_bindings(.bndlchk_unshare = function(...) NULL)
  d <- withr::local_tempdir()
  a <- mkbndlchk(fake_bundle(d, man_run("PASS"), top = "pg_v1"))
  expect_true(ran_ok(a))
  expect_identical(a$isolation, "process group")
  row <- a$checks[a$checks$check == "isolation", ]
  if (.bndlchk_reaper(TRUE)) {
    .bndlchk_reaper(FALSE)
    # every row ok, the isolation row too: no process outlived the run
    expect_true(all(a$checks$ok))
    expect_match(row$detail, "no process outlived the run", fixed = TRUE)
  } else {
    expect_false(a$ok)
    expect_match(row$detail, "cannot detect escaped processes", fixed = TRUE)
  }
  # where the session cannot be the run's subreaper, the check fails closed
  local_mocked_bindings(.bndlchk_reaper = function(on) FALSE)
  b <- mkbndlchk(fake_bundle(d, man_run("PASS"), top = "blind_v1"))
  expect_false(b$ok)
  row <- b$checks[b$checks$check == "isolation", ]
  expect_identical(row$severity, "error")
  expect_match(row$detail, "process group: cannot detect escaped processes",
               fixed = TRUE)
})

test_that("an escape that clears its environment is still found and killed", {
  skip_on_os(c("windows", "mac", "solaris"))
  skip_if(!nzchar(Sys.which("setsid")), "no setsid")
  skip_if(!.bndlchk_reaper(TRUE), "no child subreaper here")
  .bndlchk_reaper(FALSE)
  local_mocked_bindings(.bndlchk_unshare = function(...) NULL)
  d <- withr::local_tempdir()
  for (how in c("env -u RMBL_CHKRUN", "env -i PATH=/usr/bin:/bin")) {
    tok <- file.path(d, paste0("rmbl_sleep_", basename(tempfile(""))))
    file.symlink(Sys.which("sleep"), tok)
    run <- c(sprintf("system('%s setsid -f %s 300 > /dev/null 2>&1')", how,
                     tok), "Sys.sleep(0.5)", man_run("PASS"))
    a <- mkbndlchk(fake_bundle(d, run, top = basename(tok)))
    expect_false(a$ok, info = how)
    row <- a$checks[a$checks$check == "isolation", ]
    expect_identical(row$severity, "error", info = how)
    expect_match(row$detail, "outlived the run and were killed", fixed = TRUE,
                 info = how)
    Sys.sleep(0.3)
    left <- procs_named(tok)
    for (p in left) tools::pskill(p)
    expect_length(left, 0L)
  }
})

test_that("a process that outlives a process-group run fails the check", {
  skip_on_os(c("windows", "solaris"))
  skip_if(!nzchar(Sys.which("setsid")) && !identical(
    Sys.info()[["sysname"]], "Darwin"
  ), "no setsid")
  local_mocked_bindings(.bndlchk_unshare = function(...) NULL)
  d <- withr::local_tempdir()
  tok <- file.path(d, paste0("rmbl_sleep_", basename(tempfile(""))))
  file.symlink(Sys.which("sleep"), tok)
  # setsid leaves the run's process group; on macOS a perl setsid() does
  daemon <- if (nzchar(Sys.which("setsid"))) {
    sprintf("system('setsid %s 300 > /dev/null 2>&1 < /dev/null &')", tok)
  } else {
    sprintf(paste0("system('perl -e \"use POSIX; fork and exit; ",
                   "POSIX::setsid(); exec q{%s}, 300\" > /dev/null 2>&1')"),
            tok)
  }
  run <- c(daemon, "Sys.sleep(0.5)", man_run("PASS"))
  a <- mkbndlchk(fake_bundle(d, run, top = "escape_v1"))
  expect_false(a$ok)
  row <- a$checks[a$checks$check == "isolation", ]
  expect_false(row$ok)
  expect_identical(row$severity, "error")
  expect_match(row$detail, "outlived the run and were killed", fixed = TRUE)
  # and it was killed
  Sys.sleep(0.3)
  if (dir.exists("/proc")) {
    left <- procs_named(tok)
    for (p in left) tools::pskill(p)
    expect_length(left, 0L)
  }
  # a survivor seen by the scan, without running anything
  expect_identical(.bndlchk_iso("process group", 12L)$severity, "error")
  expect_true(.bndlchk_iso("job object")$ok)
})

test_that("unshare that is missing or refuses gives no namespace", {
  expect_null(.bndlchk_unshare(us = ""))
  f <- unname(Sys.which("false"))
  skip_if(!nzchar(f) || !identical(Sys.info()[["sysname"]], "Linux"))
  expect_null(.bndlchk_unshare(us = f))
})

test_that("a container check: the run's arguments and its clean-up", {
  d <- withr::local_tempdir()
  zip <- fake_bundle(d, man_run("PASS"), top = "ctr_v1")
  got <- new.env()
  got$calls <- list()
  local_mocked_bindings(.bndlchk_which = function(x) {
    if (x == "podman") "/usr/bin/podman" else ""
  })
  local_mocked_bindings(
    system2 = function(command, args = character(), stdout = "",
                       stderr = "", timeout = 0, ...) {
      a <- gsub("^'|'$", "", args)
      got$calls[[length(got$calls) + 1L]] <- list(cmd = command, args = a,
                                                  timeout = timeout)
      if (identical(a[1L], "run")) {
        out <- sub(":/out:z$", "", grep(":/out:z$", a, value = TRUE))
        dir.create(file.path(out, "results_1"))
        writeLines('{"results": {"c1": {"status": "PASS"}}}',
                   file.path(out, "results_1", "manifest.json"))
      }
      if (identical(command, "id")) return("1234")
      0L
    },
    .package = "base"
  )
  csv <- file.path(d, "in.csv")
  writeLines("a,b", csv)
  a <- mkbndlchk(zip, data = csv, container = TRUE, keep = TRUE,
                 dir = file.path(d, "w"))
  expect_true(ran_ok(a))
  expect_identical(a$isolation, "container (podman)")
  expect_true(file.exists(file.path(a$dir, "results_1", "manifest.json")))
  run <- Filter(function(x) identical(x$args[1L], "run"), got$calls)[[1L]]
  r <- run$args
  for (f in c("--rm", "--read-only", "--userns=keep-id", "no-new-privileges",
              "ALL", "1234:1234", "4g", "512", "/out")) {
    expect_true(f %in% r, info = f)
  }
  expect_identical(r[match("--network", r) + 1L], "none")
  expect_true(any(grepl(":/bundle:ro,z$", r)))
  expect_true(any(grepl(":/data:ro,z$", r)))
  expect_true("/data/in.csv" %in% r)
  expect_true(.bndlchk_image() %in% r)
  expect_identical(run$timeout, 1800L)
  rm <- Filter(function(x) identical(x$args[1L], "rm"), got$calls)
  expect_length(rm, 1L)
  expect_identical(rm[[1L]]$args[3L], r[match("--name", r) + 1L])
  # the real data to be downloaded: the network is on
  got$calls <- list()
  b <- mkbndlchk(zip, container = "podman")
  run <- Filter(function(x) identical(x$args[1L], "run"), got$calls)[[1L]]
  expect_false("--network" %in% run$args)
  expect_true(ran_ok(b))
})

test_that("container choices, the image and their refusals", {
  expect_null(.bndlchk_ctrarg(NULL))
  expect_null(.bndlchk_ctrarg(FALSE))
  expect_true(.bndlchk_ctrarg(TRUE))
  expect_identical(.bndlchk_ctrarg("docker"), "docker")
  expect_error(.bndlchk_ctrarg("lxc"), "`container` must be")
  expect_error(.bndlchk_ctrarg(c("podman", "docker")), "`container` must be")
  expect_null(.bndlchk_rt(NULL))
  local_mocked_bindings(.bndlchk_which = function(x) {
    if (x == "docker") "/usr/bin/docker" else ""
  })
  expect_identical(.bndlchk_rt(TRUE),
                   list(path = "/usr/bin/docker", kind = "docker"))
  expect_identical(.bndlchk_rt("podman"), list(path = NULL, kind = "podman"))
  expect_match(.bndlchk_image(), "^docker.io/rocker/r-ver:4.6.1@sha256:")
  withr::local_options(rmbl.bundle.image = "example.org/r:1")
  expect_identical(.bndlchk_image(), "example.org/r:1")
  expect_error(.bndlchk_ctrargs("docker", "n", FALSE, "/a:b", "/o", NULL),
               "without ':'")
  a <- .bndlchk_ctrargs("docker", "n", TRUE, "/a", "/o", NULL)
  expect_false("--userns=keep-id" %in% a)
  expect_false("--network" %in% a)
  expect_match(.bndlchk_uid(), "^[0-9]+:[0-9]+$")
  expect_identical(.bndlchk_uid(unix = FALSE), "1000:1000")
  # no runtime: the check falls back, and says so
  d <- withr::local_tempdir()
  local_mocked_bindings(.bndlchk_which = function(x) "")
  r <- mkbndlchk(fake_bundle(d, man_run("PASS"), top = "nort_v1"),
                 container = TRUE)
  expect_true(ran_ok(r))
  expect_match(r$isolation, "(no podman or docker found for a container)",
               fixed = TRUE)
  run <- function(...) {
    rec <- new.env()
    rec$buf <- character()
    st <- blcli(c(...), out = function(s) rec$buf <- c(rec$buf, s))
    list(status = st, text = paste(rec$buf, collapse = ""))
  }
  zip <- fake_bundle(d, man_run("PASS"), top = "cli_v1")
  r <- run("pack", "--check", zip, "--container=docker")
  expect_identical(r$status, 0L)
  expect_match(r$text, "no docker found", fixed = TRUE)
  expect_identical(run("pack", "--check", zip, "--container=lxc")$status, 2L)
  r <- run("pack", "--check", zip, "--container")
  expect_identical(r$status, 0L)
  expect_match(r$text, "no podman or docker found", fixed = TRUE)
  expect_identical(.bl_cli_packpos(c("p", "--container", "--secrets")), "p")
})

test_that("a container check with podman runs the starter bundle", {
  skip_on_cran()
  skip_on_os("windows")
  pm <- Sys.which("podman")
  skip_if(!nzchar(pm), "no podman")
  have <- suppressWarnings(system2(pm, c("image", "exists", .bndlchk_image()),
                                   stdout = FALSE, stderr = FALSE))
  skip_if(!identical(as.integer(have), 0L), "the pinned image is not here")
  d <- withr::local_tempdir()
  p <- mkbndlproj(file.path(d, "starter"), title = "Starter")
  b <- mkbndl(p$dir, dest = d)
  a <- mkbndlchk(b$path, synthetic = TRUE, container = "podman")
  expect_true(ran_ok(a))
  expect_identical(a$isolation, "container (podman)")
  expect_identical(a$mode, "synthetic")
})

test_that("the job-object entry point exists everywhere, runs on Windows", {
  skip_on_os("windows")
  expect_error(.rmbl_wjob("x", tempfile(), 1), "for Windows only")
})
