# SPDX-License-Identifier: AGPL-3.0-or-later
# Manifest lifecycle: build, record (PASS/DIFFER/INFO + tolerance),
# JSON serialisation, and the plain-text summary writer.

test_that("record classifies PASS/DIFFER by tolerance and INFO for synthetic", {
  m <- mkmnf(list(study = "otis-mrp"))
  expect_identical(m$meta$study, "otis-mrp")
  expect_length(m$results, 0)

  capture.output({
    m <- recrd(m, "ate_matches", obs = 1.00004, expd = 1, tol = 1e-4)
    m <- recrd(m, "n_rows", obs = 100, expd = 250, tol = 1e-4)
    m <- recrd(m, "synthetic_mean", obs = 5, expd = 99, syn = TRUE)
    m <- recrd(m, "label_check", obs = "b01", expd = "b01")
  })
  expect_identical(m$results$ate_matches$status, "PASS")
  expect_identical(m$results$n_rows$status, "DIFFER")
  expect_identical(m$results$synthetic_mean$status, "INFO")
  expect_match(m$results$synthetic_mean$note, "synthetic")
  # Non-numeric comparison carries no diff -> INFO.
  expect_identical(m$results$label_check$status, "INFO")
  expect_identical(m$results$n_rows$diff, 150)
})

test_that("wrmnfjs roundtrips through jsonlite", {
  m <- mkmnf(list(study = "roundtrip"))
  capture.output(
    m <- recrd(m, "check_one", obs = 2, expd = 2, tol = 0.1)
  )
  p <- tempfile(fileext = ".json")
  expect_identical(wrmnfjs(m, p), p)
  back <- jsonlite::fromJSON(p, simplifyVector = FALSE)
  expect_identical(back$meta$study, "roundtrip")
  expect_identical(back$results$check_one$status, "PASS")
})

test_that("wrsmrytxt writes a summary containing the recorded counts", {
  m <- mkmnf(list(study = "summary"))
  capture.output({
    m <- recrd(m, "a", obs = 1, expd = 1)
    m <- recrd(m, "b", obs = 1, expd = 3)
  })
  out_dir <- file.path(tempdir(), "brick-summary-test")
  dir.create(out_dir, showWarnings = FALSE)
  capture.output(
    wrsmrytxt(m, out_dir, paths = list(capsule = out_dir))
  )
  files <- list.files(out_dir, pattern = "\\.txt$", full.names = TRUE)
  expect_gte(length(files), 1)
  txt <- paste(readLines(files[1], warn = FALSE), collapse = "\n")
  expect_match(txt, "PASS")
  expect_match(txt, "DIFFER")
})

test_that("wrsmrytxt includes what-was-done, contact and licence blocks", {
  m <- mkmnf(list(project = "demo"), env = FALSE)
  capture.output(m <- recrd(m, "chk", obs = 1, expd = 1))
  out_dir <- file.path(tempdir(), "summary-full-blocks")
  dir.create(out_dir, showWarnings = FALSE)
  s <- wrsmrytxt(m, out_dir, paths = list(results = out_dir),
                         whatwasdone = "* did the thing",
                         contact = "maintainer@example.org",
                         lic = "AGPL-3.0-or-later")
  txt <- readLines(s)
  expect_true(any(grepl("WHAT WAS DONE", txt)))
  expect_true(any(grepl("did the thing", txt, fixed = TRUE)))
  expect_true(any(grepl("Contact: maintainer@example.org", txt, fixed = TRUE)))
  expect_true(any(grepl("Licence: AGPL-3.0-or-later", txt, fixed = TRUE)))
})

test_that("wrsmrytxt labels a synthetic run as a pipeline check", {
  m <- mkmnf(list(study = "synthetic-run", synthetic = TRUE))
  capture.output(m <- recrd(m, "a", obs = 1, expd = 1))
  out_dir <- file.path(tempdir(), "brick-summary-synth")
  dir.create(out_dir, showWarnings = FALSE)
  capture.output(wrsmrytxt(m, out_dir, paths = list(capsule = out_dir)))
  files <- list.files(out_dir, pattern = "\\.txt$", full.names = TRUE)
  txt <- paste(readLines(files[1], warn = FALSE), collapse = "\n")
  expect_match(txt, "SYNTHETIC")
})
