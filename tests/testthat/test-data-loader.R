# SPDX-License-Identifier: AGPL-3.0-or-later
# Provenance loading, CKAN resolution guards, Wayback URL handling,
# downloads (file:// only — no network), sha256, schema validation.

test_that("load_provenance returns NULL for a missing path and roundtrips JSON", {
  expect_null(load_provenance(file.path(tempdir(), "nope-does-not-exist.json")))
  p <- tempfile(fileext = ".json")
  jsonlite::write_json(
    list(dataset = list(id = "otis-b01"), resource = list(sha256 = "abc")),
    p,
    auto_unbox = TRUE
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
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) {
      list(archived_snapshots = list(closest = list(
        available = TRUE, url = "http://web.archive.org/web/2024/https://x.csv"
      )))
    }
  )
  out <- wayback_snapshot_url("https://example.org/x.csv")
  expect_match(out, "^https://web\\.archive\\.org/")

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(archived_snapshots = list())
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
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) {
      list(success = TRUE, result = list(resources = list(
        list(name = "Readme", url = "https://example.org/readme.txt"),
        list(name = "Data 2014", url = "https://example.org/2014.csv")
      )))
    }
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
  skip_if_cannot_mock()
  seen_url <- NULL
  testthat::local_mocked_bindings(
    .rmbl_read_json = function(url, ...) {
      seen_url <<- url
      list(result = list(results = list(list(resources = list(
        list(name = "Data 2014", format = "XLSX", url = "https://example.org/s.xlsx"),
        list(name = "Data 2014", format = "CSV", url = "https://example.org/s.csv")
      )))))
    }
  )
  prov <- list(
    dataset = list(ckan_api_endpoint = "https://portal/api/3/action/package_show?id=x"),
    resource = list(
      name_match_pattern = "2014", search_query = "library stats",
      format = "CSV"
    )
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
  skip_if_cannot_mock()
  seen <- NULL
  testthat::local_mocked_bindings(
    .rmbl_read_json = function(url, ...) {
      seen <<- url
      list(archived_snapshots = list(closest = list(
        available = TRUE,
        url = "http://web.archive.org/web/20240101/https://x.csv"
      )))
    }
  )
  out <- wayback_snapshot_url("https://example.org/x.csv",
    timestamp = "20240101000000"
  )
  expect_match(seen, "&timestamp=20240101000000", fixed = TRUE)
  expect_match(out, "^https://")
})

test_that("friendly_download prints diagnostics and retries from a wayback snapshot", {
  skip_if_cannot_mock()
  snap <- tempfile(fileext = ".csv")
  writeLines("a,b\n1,2", snap)
  calls <- 0L
  testthat::local_mocked_bindings(
    .bl_fetch_file = function(url, dest) {
      calls <<- calls + 1L
      if (calls == 1L) stop("HTTP error 429: too many requests")
      file.copy(sub("^file://", "", url), dest, overwrite = TRUE)
      invisible(dest)
    }
  )
  dst <- tempfile(fileext = ".csv")
  out <- capture.output(
    type = "message",
    ok <- friendly_download("https://example.org/x.csv", dst,
      attempt_wayback = paste0("file://", snap)
    )
  )
  expect_true(ok)
  expect_true(file.exists(dst))
  expect_true(any(grepl("Rate-limited", out)))
  expect_true(any(grepl("Wayback", out)))
})

test_that("friendly_download covers the failure diagnostics and total failure", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .bl_fetch_file = function(...) {
      stop(paste(
        "SSL certificate handshake failed; connection timed out;",
        "could not resolve host; HTTP 403 forbidden"
      ))
    }
  )
  # auto-resolution consults wayback_snapshot_url; make it find nothing
  testthat::local_mocked_bindings(wayback_snapshot_url = function(...) NULL)
  out <- capture.output(
    type = "message",
    ok <- friendly_download("https://example.org/x.csv", tempfile())
  )
  expect_false(ok)
  expect_true(any(grepl("SSL/TLS", out)))
  expect_true(any(grepl("DNS", out)))
  expect_true(any(grepl("timed out", out)))
  expect_true(any(grepl("403", out)))
})

test_that("friendly_download reports a failed wayback retry", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .bl_fetch_file = function(...) stop("could not resolve host")
  )
  out <- capture.output(
    type = "message",
    ok <- friendly_download("https://example.org/x.csv", tempfile(),
      attempt_wayback = "file:///nonexistent/nope.csv"
    )
  )
  expect_false(ok)
  expect_true(any(grepl("also failed", out)))
})

test_that("resolve_via_socrata returns the canonical CSV export URL", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(id = "ijzp-q8t2")
  )
  prov <- list(dataset = list(
    socrata_domain = "data.example.org",
    socrata_id = "ijzp-q8t2"
  ))
  expect_identical(
    resolve_via_socrata(prov),
    "https://data.example.org/api/views/ijzp-q8t2/rows.csv?accessType=DOWNLOAD"
  )

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) stop("network down")
  )
  expect_null(resolve_via_socrata(prov))
})

test_that("resolve_via_arcgis returns a paged GeoJSON query URL, trimming slashes", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(name = "Layer0")
  )
  prov <- list(dataset = list(
    arcgis_layer_url = "https://svc.example.org/FeatureServer/0///"
  ))
  expect_identical(
    resolve_via_arcgis(prov),
    "https://svc.example.org/FeatureServer/0/query?where=1%3D1&outFields=*&f=geojson"
  )

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(error = list(code = 400))
  )
  expect_null(resolve_via_arcgis(prov))
})

test_that("the CKAN resolvers return NULL for an empty endpoint, a failed call and no match", {
  skip_if_cannot_mock()
  prov <- list(dataset = list(ckan_api_endpoint = ""), resource = list(name_match_pattern = "x"))
  expect_null(resolve_via_ckan(prov))
  prov$dataset$ckan_api_endpoint <- "https://portal/api/3/action/package_show?id=x"
  testthat::with_mocked_bindings(
    .rmbl_read_json = function(...) list(success = FALSE),
    expect_null(resolve_via_ckan(prov))
  )
  expect_null(resolve_via_ckan_search(list(dataset = prov$dataset, resource = list(name_match_pattern = ""))))
  testthat::with_mocked_bindings(
    .rmbl_read_json = function(...) NULL,
    expect_null(resolve_via_ckan_search(list(dataset = prov$dataset, resource = list(search_query = "libraries"))))
  )
  testthat::with_mocked_bindings(
    .rmbl_read_json = function(...) {
      list(result = list(results = list(list(resources = list(list(name = "other", format = "CSV", url = "u"))))))
    },
    expect_null(resolve_via_ckan_search(list(
      dataset = prov$dataset, resource = list(search_query = "libraries", name_match_pattern = "stats")
    )))
  )
})

test_that("numeric range checks skip non-numeric and all-missing columns", {
  prov <- list(schema = list(numeric_ranges = list(a = c(min = 0, max = 1), b = c(min = 0, max = 1))))
  df <- data.frame(a = c("x", "y"), b = c(NA_real_, NA_real_), stringsAsFactors = FALSE)
  expect_length(validate_schema(df, prov), 0)
})

test_that("a snapshot lookup that returns nothing usable is no snapshot", {
  answer <- function(url) list(archived_snapshots = list(closest = list(available = TRUE, url = url)))
  testthat::local_mocked_bindings(.rmbl_read_json = function(api) answer(list()))
  expect_null(wayback_snapshot_url("https://example.invalid/x.csv"))
  testthat::local_mocked_bindings(.rmbl_read_json = function(api) answer("http://web.archive.org/x"))
  expect_equal(wayback_snapshot_url("https://example.invalid/x.csv"), "https://web.archive.org/x")
})


test_that("friendly_download names a refused connection as one, not as a DNS failure", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .bl_fetch_file = function(...) stop("URL 'https://www.r-project.org/': status was 'Could not connect to server'")
  )
  out <- capture.output(type = "message",
    ok <- suppressWarnings(friendly_download("https://www.r-project.org/", tempfile(), attempt_wayback = "")))
  expect_false(ok)
  expect_true(any(grepl("Could not connect to the server", out)))
  expect_false(any(grepl("DNS lookup failed", out)))
})
