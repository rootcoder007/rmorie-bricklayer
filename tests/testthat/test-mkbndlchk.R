# SPDX-License-Identifier: AGPL-3.0-or-later
# mkbndlchk(): a bundle run as a recipient would, and its manifest read.

# A small bundle whose runner is `run` (lines of R), zipped as mkbndl()
# zips; `config` is the text of its config.json, or NULL for none.
fake_bundle <- function(d, run, config = NULL, top = "fake_v1") {
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
  zip <- file.path(d, paste0(top, ".zip"))
  .bndl_zip(src, top, zip)
  zip
}

# A runner that prints a line, records its arguments and writes a manifest
# with these statuses, in this input mode.
man_run <- function(status, mode = "csv") {
  meta <- if (is.null(mode)) "" else sprintf('"input_mode": "%s"', mode)
  res <- paste(
    sprintf('"c%d": {"status": "%s"}', seq_along(status), status),
    collapse = ", "
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

expect3 <- '{"expected": {"total_checks": 3, "pass_csv": 2, "pass_real": 3}}'

test_that("a bundle that runs and gives the expected counts is verified", {
  d <- withr::local_tempdir()
  zip <- fake_bundle(d, man_run(c("PASS", "PASS", "INFO")), expect3)
  w <- file.path(d, "w1")
  a <- mkbndlchk(zip, dir = w, keep = TRUE)
  expect_s3_class(a, "rmbl_bundle_audit")
  expect_true(a$ok)
  expect_identical(a$mode, "csv")
  expect_identical(
    a$counts, c(total = 3L, pass = 2L, differ = 0L, info = 1L)
  )
  expect_true(all(a$checks$ok))
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
  expect_true(b$ok)
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
  expect_true(a$ok)
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
  expect_true(r$ok)
  expect_match(r$checks$detail[4L], "pass_real expects 3/3", fixed = TRUE)
  # a manifest that records no input mode is a run on the real data
  n <- mkbndlchk(fake_bundle(d, man_run(rep("PASS", 3L), mode = NULL),
                             expect3, top = "nomode_v1"))
  expect_identical(n$mode, "real")
  expect_true(n$ok)
})

test_that("a bundle with no expected counts is not compared", {
  d <- withr::local_tempdir()
  a <- mkbndlchk(fake_bundle(d, man_run("PASS"), top = "nocfg_v1"))
  expect_true(a$ok)
  expect_identical(
    a$checks$detail[4L], "not compared: config.json expects none"
  )
  b <- mkbndlchk(fake_bundle(d, man_run("PASS"), '{"project": {}}',
                             top = "noexp_v1"))
  expect_true(b$ok)
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
  expect_true(mkbndlchk(zip)$ok)
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
  m <- .bndlchk_modes(fake_bundle(d, man_run("PASS")))
  expect_identical(unname(m[["fake_v1/start_here.sh"]]), 33261)
  expect_identical(unname(m[["fake_v1/setup_and_run.R"]]), 33188)
  # a directory claimed beyond the file's end is not read (readBin() would
  # allocate the 4 GB claimed)
  z <- fake_bundle(d, man_run("PASS"), top = "hostile_v1")
  b <- readBin(z, "raw", file.size(z))
  at <- grepRaw(as.raw(c(0x50, 0x4b, 0x05, 0x06)), b, all = TRUE)
  b[at[length(at)] + 12:15] <- as.raw(0xff)
  writeBin(b, z)
  expect_length(.bndlchk_modes(z), 0L)
  # a file with no end-of-central-directory record has no modes
  junk <- file.path(d, "junk.zip")
  writeBin(as.raw(1:200), junk)
  expect_length(.bndlchk_modes(junk), 0L)
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
  expect_true(a$ok)
  expect_identical(a$mode, "synthetic")
  expect_gt(a$counts[["total"]], 0L)
})
