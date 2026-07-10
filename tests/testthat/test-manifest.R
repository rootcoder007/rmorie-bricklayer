# SPDX-License-Identifier: AGPL-3.0-or-later
# Manifest lifecycle: build, record (PASS/DIFFER/INFO + tolerance),
# JSON serialisation, and the plain-text summary writer.

test_that("record classifies PASS/DIFFER by tolerance and INFO for synthetic", {
  m <- make_manifest(list(study = "otis-mrp"))
  expect_identical(m$meta$study, "otis-mrp")
  expect_length(m$results, 0)

  capture.output({
    m <- record(m, "ate_matches", observed = 1.00004, expected = 1, tol = 1e-4)
    m <- record(m, "n_rows", observed = 100, expected = 250, tol = 1e-4)
    m <- record(m, "synthetic_mean", observed = 5, expected = 99, synthetic = TRUE)
    m <- record(m, "label_check", observed = "b01", expected = "b01")
  })
  expect_identical(m$results$ate_matches$status, "PASS")
  expect_identical(m$results$n_rows$status, "DIFFER")
  expect_identical(m$results$synthetic_mean$status, "INFO")
  expect_match(m$results$synthetic_mean$note, "synthetic")
  # Non-numeric comparison carries no diff -> INFO.
  expect_identical(m$results$label_check$status, "INFO")
  expect_identical(m$results$n_rows$diff, 150)
})

test_that("write_manifest_json roundtrips through jsonlite", {
  m <- make_manifest(list(study = "roundtrip"))
  capture.output(
    m <- record(m, "check_one", observed = 2, expected = 2, tol = 0.1)
  )
  p <- tempfile(fileext = ".json")
  expect_identical(write_manifest_json(m, p), p)
  back <- jsonlite::fromJSON(p, simplifyVector = FALSE)
  expect_identical(back$meta$study, "roundtrip")
  expect_identical(back$results$check_one$status, "PASS")
})

test_that("write_summary_txt writes a summary containing the recorded counts", {
  m <- make_manifest(list(study = "summary"))
  capture.output({
    m <- record(m, "a", observed = 1, expected = 1)
    m <- record(m, "b", observed = 1, expected = 3)
  })
  out_dir <- file.path(tempdir(), "brick-summary-test")
  dir.create(out_dir, showWarnings = FALSE)
  capture.output(
    write_summary_txt(m, out_dir, paths = list(capsule = out_dir))
  )
  files <- list.files(out_dir, pattern = "\\.txt$", full.names = TRUE)
  expect_gte(length(files), 1)
  txt <- paste(readLines(files[1], warn = FALSE), collapse = "\n")
  expect_match(txt, "PASS")
  expect_match(txt, "DIFFER")
})

test_that("write_summary_txt includes what-was-done, contact and licence blocks", {
  m <- make_manifest(list(project = "demo"), environment = FALSE)
  capture.output(m <- record(m, "chk", observed = 1, expected = 1))
  out_dir <- file.path(tempdir(), "summary-full-blocks")
  dir.create(out_dir, showWarnings = FALSE)
  s <- write_summary_txt(m, out_dir, paths = list(results = out_dir),
                         what_was_done = "* did the thing",
                         contact = "maintainer@example.org",
                         licence = "AGPL-3.0-or-later")
  txt <- readLines(s)
  expect_true(any(grepl("WHAT WAS DONE", txt)))
  expect_true(any(grepl("did the thing", txt, fixed = TRUE)))
  expect_true(any(grepl("Contact: maintainer@example.org", txt, fixed = TRUE)))
  expect_true(any(grepl("Licence: AGPL-3.0-or-later", txt, fixed = TRUE)))
})
