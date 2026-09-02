# SPDX-License-Identifier: AGPL-3.0-or-later
# Capsule-level integrity: verify_capsule, capture_environment,
# cite_capsule, and the Socrata/ArcGIS resolvers.

make_test_capsule <- function() {
  dir <- file.path(tempdir(), paste0("capsule-", as.integer(stats::runif(1, 1, 1e8))))
  dir.create(dir, showWarnings = FALSE)
  df <- data.frame(id = 1:6, year = rep(2024:2025, 3), value = 1:6 / 2)
  utils::write.csv(df, file.path(dir, "data.csv"), row.names = FALSE)
  prov <- list(
    captured_at_utc = "2026-06-23T04:41:40Z",
    dataset = list(
      package_slug = "test-capsule",
      publisher = "Test Publisher",
      licence_short = "OGL-Ontario"
    ),
    resource = list(
      name = "Test Detailed Dataset",
      filename = "data.csv",
      direct_url = "https://example.org/data.csv",
      sha256 = sha256_file(file.path(dir, "data.csv")),
      size_bytes = file.size(file.path(dir, "data.csv")),
      row_count_data_rows = 6
    ),
    schema = list(
      expected_columns = c("id", "year", "value"),
      structural_invariants = list(min_data_rows = 3)
    )
  )
  jsonlite::write_json(prov, file.path(dir, "data_provenance.json"),
                       auto_unbox = TRUE, digits = NA)
  m <- make_manifest(list(study = "test"), environment = FALSE)
  capture.output({
    m <- record(m, "mean_value", observed = mean(df$value), expected = 1.75)
  })
  write_manifest_json(m, file.path(dir, "manifest.json"))
  dir
}

test_that("verify_capsule passes an intact capsule end to end", {
  dir <- make_test_capsule()
  out <- verify_capsule(dir, manifest_file = "manifest.json")
  expect_true(out$ok)
  expect_true(all(c("provenance_readable", "data_present", "data_sha256",
                    "data_size_bytes", "data_readable", "data_row_count",
                    "schema_valid", "manifest_consistent")
                  %in% out$checks$check))
  expect_true(all(out$checks$ok))
})

test_that("verify_capsule catches tampered data and stale manifests", {
  dir <- make_test_capsule()
  cat("7,2026,9.9\n", file = file.path(dir, "data.csv"), append = TRUE)
  out <- verify_capsule(dir, manifest_file = "manifest.json")
  expect_false(out$ok)
  ck <- out$checks
  expect_false(ck$ok[ck$check == "data_sha256"])
  expect_false(ck$ok[ck$check == "data_row_count"])

  # Stale manifest: stored status contradicts its own numbers.
  testthat::skip_if_not_installed("jsonlite")
  m2 <- jsonlite::fromJSON(file.path(dir, "manifest.json"),
                           simplifyVector = FALSE)
  m2$results$mean_value$status <- "DIFFER"
  jsonlite::write_json(m2, file.path(dir, "manifest.json"),
                       auto_unbox = TRUE)
  out2 <- verify_capsule(dir, manifest_file = "manifest.json")
  ck2 <- out2$checks
  expect_false(ck2$ok[ck2$check == "manifest_consistent"])
})

test_that("verify_capsule flags a missing data file and schema violations", {
  dir <- make_test_capsule()
  file.remove(file.path(dir, "data.csv"))
  out <- verify_capsule(dir)
  expect_false(out$ok)
  expect_false(out$checks$ok[out$checks$check == "data_present"])

  dir2 <- make_test_capsule()
  df <- utils::read.csv(file.path(dir2, "data.csv"))
  df$value <- NULL
  utils::write.csv(df, file.path(dir2, "data.csv"), row.names = FALSE)
  out2 <- verify_capsule(dir2)
  ck2 <- out2$checks
  expect_false(ck2$ok[ck2$check == "schema_valid"])
  expect_match(ck2$detail[ck2$check == "schema_valid"], "value")
})

test_that("capture_environment records the running session", {
  env <- capture_environment(c("stats", "testthat"))
  expect_identical(env$r_version, as.character(getRversion()))
  expect_true(nzchar(env$platform))
  expect_match(env$captured_utc, "^\\d{4}-\\d{2}-\\d{2}T")
  expect_identical(names(env$packages), c("stats", "testthat"))
  expect_identical(env$packages[["testthat"]],
                   as.character(utils::packageVersion("testthat")))
})

test_that("make_manifest attaches the environment by default and skips on FALSE", {
  m <- make_manifest(list(study = "env"))
  expect_identical(m$environment$r_version, as.character(getRversion()))
  m0 <- make_manifest(list(study = "no-env"), environment = FALSE)
  expect_null(m0$environment)
})

test_that("cite_capsule builds text and BibTeX from real provenance fields", {
  dir <- make_test_capsule()
  prov <- load_provenance(file.path(dir, "data_provenance.json"))
  cite <- cite_capsule(prov)
  expect_match(cite$text, "Test Publisher \\(2026\\)")
  expect_match(cite$text, "Test Detailed Dataset")
  expect_match(cite$text, "Retrieved 2026-06-23")
  expect_match(cite$text, "OGL-Ontario")
  expect_match(cite$bibtex, "^@misc\\{testcapsule2026,")
  expect_match(cite$bibtex, "url = \\{https://example.org/data.csv\\}")
  expect_null(cite_capsule(NULL))

  prov$dataset$doi <- "10.9999/example"
  expect_match(cite_capsule(prov)$text, "doi.org/10.9999/example")
  expect_match(cite_capsule(prov)$bibtex, "doi = \\{10.9999/example\\}")
})

test_that("resolve_via_socrata guards missing fields and builds the export URL", {
  expect_null(resolve_via_socrata(NULL))
  expect_null(resolve_via_socrata(list(dataset = list())))

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(id = "ijzp-q8t2")
  )
  url <- resolve_via_socrata(list(dataset = list(
    socrata_domain = "data.cityofchicago.org", socrata_id = "ijzp-q8t2"
  )))
  expect_identical(
    url,
    "https://data.cityofchicago.org/api/views/ijzp-q8t2/rows.csv?accessType=DOWNLOAD"
  )

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) stop("404")
  )
  expect_null(resolve_via_socrata(list(dataset = list(
    socrata_domain = "x.org", socrata_id = "dead-beef"
  ))))
})

test_that("resolve_via_arcgis guards missing fields and builds the query URL", {
  expect_null(resolve_via_arcgis(NULL))
  expect_null(resolve_via_arcgis(list(dataset = list())))

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(name = "Assault_Open_Data")
  )
  layer <- "https://services.arcgis.com/X/arcgis/rest/services/Assault_Open_Data/FeatureServer/0"
  expect_identical(
    resolve_via_arcgis(list(dataset = list(arcgis_layer_url = paste0(layer, "/")))),
    paste0(layer, "/query?where=1%3D1&outFields=*&f=geojson")
  )

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(error = list(code = 400))
  )
  expect_null(resolve_via_arcgis(list(dataset = list(arcgis_layer_url = layer))))
})

test_that("verify_capsule checks a pinned analysis-script hash", {
  dir <- make_test_capsule()
  writeLines("x <- 1", file.path(dir, "analysis.R"))
  m <- jsonlite::fromJSON(file.path(dir, "manifest.json"),
                          simplifyVector = FALSE)
  m$meta$script_sha256 <- sha256_file(file.path(dir, "analysis.R"))
  write_manifest_json(m, file.path(dir, "manifest.json"))
  out <- verify_capsule(dir, manifest_file = "manifest.json",
                        script_file = "analysis.R")
  expect_true("script_sha256" %in% out$checks$check)
  expect_true(out$checks$ok[out$checks$check == "script_sha256"])
})

test_that("cite_capsule falls back to the current year without captured_at_utc", {
  prov <- list(dataset = list(publisher = "P"), resource = list(name = "N"))
  cit <- cite_capsule(prov)
  expect_match(cit$bibtex, format(Sys.Date(), "%Y"), fixed = TRUE)
})
