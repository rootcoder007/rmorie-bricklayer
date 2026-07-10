# SPDX-License-Identifier: AGPL-3.0-or-later
# Provenance loading, CKAN resolution guards, Wayback URL handling,
# downloads (file:// only — no network), sha256, schema validation.

test_that("load_provenance returns NULL for a missing path and roundtrips JSON", {
  expect_null(load_provenance(file.path(tempdir(), "nope-does-not-exist.json")))
  p <- tempfile(fileext = ".json")
  jsonlite::write_json(
    list(dataset = list(id = "otis-b01"), resource = list(sha256 = "abc")),
    p, auto_unbox = TRUE
  )
  prov <- load_provenance(p)
  expect_identical(prov$dataset$id, "otis-b01")
  expect_identical(prov$resource$sha256, "abc")
})

test_that("resolve_via_ckan returns NULL on absent provenance or endpoint", {
  expect_null(resolve_via_ckan(NULL))
  expect_null(resolve_via_ckan(list(dataset = list(), resource = list())))
  expect_null(resolve_via_ckan_search(NULL))
})

test_that("wayback_snapshot_url upgrades snapshots to https and rejects unavailable", {
  testthat::local_mocked_bindings(
    fromJSON = function(...) list(archived_snapshots = list(closest = list(
      available = TRUE, url = "http://web.archive.org/web/2024/https://x.csv"
    ))),
    .package = "jsonlite"
  )
  out <- wayback_snapshot_url("https://example.org/x.csv")
  expect_match(out, "^https://web\\.archive\\.org/")

  testthat::local_mocked_bindings(
    fromJSON = function(...) list(archived_snapshots = list()),
    .package = "jsonlite"
  )
  expect_null(wayback_snapshot_url("https://example.org/x.csv"))
})

test_that("download_data and friendly_download work over file:// without network", {
  src <- tempfile(fileext = ".csv")
  writeLines("a,b\n1,2", src)
  url <- paste0("file://", src)

  dst <- tempfile(fileext = ".csv")
  download_data(url, dst, quiet = TRUE)
  expect_identical(readLines(dst), readLines(src))

  dst2 <- tempfile(fileext = ".csv")
  expect_true(suppressWarnings(friendly_download(url, dst2, attempt_wayback = "")))
  expect_true(file.exists(dst2))

  # Failure path: nonexistent source, Wayback fallback disabled.
  bad <- paste0("file://", tempfile(fileext = ".missing"))
  res <- NULL
  capture.output(
    res <- suppressWarnings(friendly_download(bad, tempfile(), attempt_wayback = ""))
  )
  expect_false(res)
})

test_that("sha256_file matches digest and verify_sha256 classifies match/mismatch", {
  f <- tempfile()
  writeLines("brick", f)
  h <- sha256_file(f)
  expect_identical(h, digest::digest(file = f, algo = "sha256"))
  expect_true(verify_sha256(f, h)$match)
  bad <- verify_sha256(f, paste(rep("0", 64), collapse = ""))
  expect_false(bad$match)
  expect_identical(bad$actual, h)
})

test_that("validate_schema flags missing columns as fatal and short rows as warning", {
  prov <- list(schema = list(
    expected_columns = c("id", "year", "value"),
    structural_invariants = list(min_data_rows = 5)
  ))
  df_bad <- data.frame(id = 1:2, year = 2024:2025)
  issues <- validate_schema(df_bad, prov)
  expect_identical(issues$missing_columns$severity, "fatal")
  expect_match(issues$missing_columns$message, "value")
  expect_identical(issues$row_count_low$severity, "warning")

  df_ok <- data.frame(id = 1:6, year = 2020:2025, value = rnorm(6))
  expect_length(validate_schema(df_ok, prov), 0)
  expect_length(validate_schema(df_ok, NULL), 0)
})

test_that("apply_schema_validation stops on fatal, warns on warning, TRUE when clean", {
  prov <- list(schema = list(
    expected_columns = c("id"),
    structural_invariants = list(min_data_rows = 3)
  ))
  expect_error(
    apply_schema_validation(data.frame(x = 1), prov),
    "Missing required columns"
  )
  expect_warning(
    apply_schema_validation(data.frame(id = 1:2), prov),
    "below expected minimum"
  )
  expect_true(apply_schema_validation(data.frame(id = 1:5), prov))
})
