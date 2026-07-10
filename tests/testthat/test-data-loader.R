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

test_that("resolve_via_ckan returns the first name-matched resource URL", {
  testthat::local_mocked_bindings(
    fromJSON = function(...) list(success = TRUE, result = list(resources = list(
      list(name = "Readme", url = "https://example.org/readme.txt"),
      list(name = "Data 2014", url = "https://example.org/2014.csv")
    ))),
    .package = "jsonlite"
  )
  prov <- list(
    dataset  = list(ckan_api_endpoint = "https://portal/api/3/action/package_show?id=x"),
    resource = list(name_match_pattern = "2014")
  )
  expect_identical(resolve_via_ckan(prov), "https://example.org/2014.csv")

  prov$resource$name_match_pattern <- "2099"
  expect_null(resolve_via_ckan(prov))
})

test_that("resolve_via_ckan_search matches resources and derives the query", {
  seen_url <- NULL
  testthat::local_mocked_bindings(
    fromJSON = function(url, ...) {
      seen_url <<- url
      list(result = list(results = list(list(resources = list(
        list(name = "Data 2014", format = "XLSX", url = "https://example.org/s.xlsx"),
        list(name = "Data 2014", format = "CSV",  url = "https://example.org/s.csv")
      )))))
    },
    .package = "jsonlite"
  )
  prov <- list(
    dataset  = list(ckan_api_endpoint = "https://portal/api/3/action/package_show?id=x"),
    resource = list(name_match_pattern = "2014", search_query = "library stats",
                    format = "CSV")
  )
  expect_identical(resolve_via_ckan_search(prov), "https://example.org/s.csv")
  expect_match(seen_url, "package_search\\?q=library%20stats")

  # query derived from the name pattern when search_query is absent
  prov$resource$search_query <- NULL
  expect_identical(resolve_via_ckan_search(prov), "https://example.org/s.csv")
  expect_match(seen_url, "q=2014")

  # no portal base URL derivable -> NULL
  expect_null(resolve_via_ckan_search(list(resource = list(name_match_pattern = "x"))))
})

test_that("wayback_snapshot_url honours an explicit timestamp", {
  seen <- NULL
  testthat::local_mocked_bindings(
    fromJSON = function(url, ...) {
      seen <<- url
      list(archived_snapshots = list(closest = list(
        available = TRUE,
        url = "http://web.archive.org/web/20240101/https://x.csv")))
    },
    .package = "jsonlite"
  )
  out <- wayback_snapshot_url("https://example.org/x.csv",
                              timestamp = "20240101000000")
  expect_match(seen, "&timestamp=20240101000000", fixed = TRUE)
  expect_match(out, "^https://")
})

test_that("friendly_download prints diagnostics and retries from a wayback snapshot", {
  snap <- tempfile(fileext = ".csv")
  writeLines("a,b\n1,2", snap)
  calls <- 0L
  testthat::local_mocked_bindings(
    download.file = function(url, destfile, ...) {
      calls <<- calls + 1L
      if (calls == 1L) stop("HTTP error 429: too many requests")
      file.copy(sub("^file://", "", url), destfile, overwrite = TRUE)
      0L
    },
    .package = "utils"
  )
  dst <- tempfile(fileext = ".csv")
  out <- capture.output(
    ok <- friendly_download("https://example.org/x.csv", dst,
                            attempt_wayback = paste0("file://", snap))
  )
  expect_true(ok)
  expect_true(file.exists(dst))
  expect_true(any(grepl("Rate-limited", out)))
  expect_true(any(grepl("Wayback", out)))
})

test_that("friendly_download covers the failure diagnostics and total failure", {
  testthat::local_mocked_bindings(
    download.file = function(...) stop(paste(
      "SSL certificate handshake failed; connection timed out;",
      "could not resolve host; HTTP 403 forbidden")),
    .package = "utils"
  )
  # auto-resolution consults wayback_snapshot_url; make it find nothing
  testthat::local_mocked_bindings(wayback_snapshot_url = function(...) NULL)
  out <- capture.output(
    ok <- friendly_download("https://example.org/x.csv", tempfile())
  )
  expect_false(ok)
  expect_true(any(grepl("SSL/TLS", out)))
  expect_true(any(grepl("DNS", out)))
  expect_true(any(grepl("timed out", out)))
  expect_true(any(grepl("403", out)))
})

test_that("friendly_download reports a failed wayback retry", {
  testthat::local_mocked_bindings(
    download.file = function(...) stop("could not resolve host"),
    .package = "utils"
  )
  out <- capture.output(
    ok <- friendly_download("https://example.org/x.csv", tempfile(),
                            attempt_wayback = "file:///nonexistent/nope.csv")
  )
  expect_false(ok)
  expect_true(any(grepl("also failed", out)))
})

test_that("resolve_via_socrata returns the canonical CSV export URL", {
  testthat::local_mocked_bindings(
    fromJSON = function(...) list(id = "ijzp-q8t2"), .package = "jsonlite")
  prov <- list(dataset = list(socrata_domain = "data.example.org",
                              socrata_id     = "ijzp-q8t2"))
  expect_identical(
    resolve_via_socrata(prov),
    "https://data.example.org/api/views/ijzp-q8t2/rows.csv?accessType=DOWNLOAD")

  testthat::local_mocked_bindings(
    fromJSON = function(...) stop("network down"), .package = "jsonlite")
  expect_null(resolve_via_socrata(prov))
})

test_that("resolve_via_arcgis returns a paged GeoJSON query URL, trimming slashes", {
  testthat::local_mocked_bindings(
    fromJSON = function(...) list(name = "Layer0"), .package = "jsonlite")
  prov <- list(dataset = list(
    arcgis_layer_url = "https://svc.example.org/FeatureServer/0///"))
  expect_identical(
    resolve_via_arcgis(prov),
    "https://svc.example.org/FeatureServer/0/query?where=1%3D1&outFields=*&f=geojson")

  testthat::local_mocked_bindings(
    fromJSON = function(...) list(error = list(code = 400)), .package = "jsonlite")
  expect_null(resolve_via_arcgis(prov))
})

