# SPDX-License-Identifier: AGPL-3.0-or-later
# Capsule-level integrity: vrfcps, capenv,
# citecps, and the Socrata/ArcGIS resolvers.

test_that("vrfcps passes an intact capsule end to end", {
  dir <- make_test_capsule()
  out <- vrfcps(dir, mnffile = "manifest.json")
  expect_true(out$ok)
  expect_true(all(
    c(
      "provenance_readable",
      "data_present",
      "data_sha256",
      "data_size_bytes",
      "data_readable",
      "data_row_count",
      "schema_valid",
      "manifest_consistent"
    ) %in%
      out$checks$check
  ))
  expect_true(all(out$checks$ok))
})

test_that("vrfcps catches tampered data and stale manifests", {
  dir <- make_test_capsule()
  cat("7,2026,9.9\n", file = file.path(dir, "data.csv"), append = TRUE)
  out <- vrfcps(dir, mnffile = "manifest.json")
  expect_false(out$ok)
  ck <- out$checks
  expect_false(ck$ok[ck$check == "data_sha256"])
  expect_false(ck$ok[ck$check == "data_row_count"])

  # Stale manifest: stored status contradicts its own numbers.
  testthat::skip_if_not_installed("jsonlite")
  m2 <- jsonlite::fromJSON(
    file.path(dir, "manifest.json"),
    simplifyVector = FALSE
  )
  m2$results$mean_value$status <- "DIFFER"
  jsonlite::write_json(m2, file.path(dir, "manifest.json"), auto_unbox = TRUE)
  out2 <- vrfcps(dir, mnffile = "manifest.json")
  ck2 <- out2$checks
  expect_false(ck2$ok[ck2$check == "manifest_consistent"])
})

test_that("vrfcps flags a missing data file and schema violations", {
  dir <- make_test_capsule()
  file.remove(file.path(dir, "data.csv"))
  out <- vrfcps(dir)
  expect_false(out$ok)
  expect_false(out$checks$ok[out$checks$check == "data_present"])

  dir2 <- make_test_capsule()
  df <- utils::read.csv(file.path(dir2, "data.csv"))
  df$value <- NULL
  utils::write.csv(df, file.path(dir2, "data.csv"), row.names = FALSE)
  out2 <- vrfcps(dir2)
  ck2 <- out2$checks
  expect_false(ck2$ok[ck2$check == "schema_valid"])
  expect_match(ck2$detail[ck2$check == "schema_valid"], "value")
})

test_that("capenv records the running session", {
  env <- capenv(c("stats", "testthat"))
  expect_identical(env$r_version, as.character(getRversion()))
  expect_true(nzchar(env$platform))
  expect_match(env$captured_utc, "^\\d{4}-\\d{2}-\\d{2}T")
  expect_named(env$packages, c("stats", "testthat"))
  expect_identical(
    env$packages[["testthat"]],
    as.character(utils::packageVersion("testthat"))
  )
})

test_that("mkmnf attaches the environment by default and skips on FALSE", {
  m <- mkmnf(list(study = "env"))
  expect_identical(m$environment$r_version, as.character(getRversion()))
  m0 <- mkmnf(list(study = "no-env"), env = FALSE)
  expect_null(m0$environment)
})

test_that("citecps builds text and BibTeX from real provenance fields", {
  dir <- make_test_capsule()
  prov <- loadprov(file.path(dir, "data_provenance.json"))
  cite <- citecps(prov)
  expect_match(cite$text, "Test Publisher \\(2026\\)")
  expect_match(cite$text, "Test Detailed Dataset")
  expect_match(cite$text, "Retrieved 2026-06-23")
  expect_match(cite$text, "OGL-Ontario")
  expect_match(cite$bibtex, "^@misc\\{testcapsule2026,")
  expect_match(cite$bibtex, "url = \\{https://example.org/data.csv\\}")
  expect_null(citecps(NULL))

  prov$dataset$doi <- "10.9999/example"
  expect_match(citecps(prov)$text, "doi.org/10.9999/example")
  expect_match(citecps(prov)$bibtex, "doi = \\{10.9999/example\\}")
})

test_that("rslvsoc guards missing fields and builds the export URL", {
  expect_null(rslvsoc(NULL))
  expect_null(rslvsoc(list(dataset = list())))

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(id = "ijzp-q8t2")
  )
  url <- rslvsoc(list(
    dataset = list(
      socrata_domain = "data.cityofchicago.org",
      socrata_id = "ijzp-q8t2"
    )
  ))
  expect_identical(
    url,
    paste0(
      "https://data.cityofchicago.org/api/views/ijzp-q8t2/rows.csv?accessTy",
      "pe=DOWNLOAD"
    )
  )

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) stop("404")
  )
  expect_null(rslvsoc(list(
    dataset = list(
      socrata_domain = "x.org",
      socrata_id = "dead-beef"
    )
  )))
})

test_that("rslvarc guards missing fields and builds the query URL", {
  expect_null(rslvarc(NULL))
  expect_null(rslvarc(list(dataset = list())))

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(name = "Assault_Open_Data")
  )
  layer <- paste0(
    "https://services.arcgis.com/X/arcgis/rest/services/Assault_Open_Data/F",
    "eatureServer/0"
  )
  expect_identical(
    rslvarc(list(dataset = list(arcgis_layer_url = paste0(layer, "/")))),
    file.path(layer, "query?where=1%3D1&outFields=*&f=geojson")
  )

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(error = list(code = 400))
  )
  expect_null(rslvarc(list(dataset = list(arcgis_layer_url = layer))))
})

test_that("vrfcps checks a pinned analysis-script hash", {
  dir <- make_test_capsule()
  writeLines("x <- 1", file.path(dir, "analysis.R"))
  m <- jsonlite::fromJSON(
    file.path(dir, "manifest.json"),
    simplifyVector = FALSE
  )
  m$meta$script_sha256 <- sha256file(file.path(dir, "analysis.R"))
  wrmnfjs(m, file.path(dir, "manifest.json"))
  out <- vrfcps(dir, mnffile = "manifest.json", scrfile = "analysis.R")
  expect_true("script_sha256" %in% out$checks$check)
  expect_true(out$checks$ok[out$checks$check == "script_sha256"])
})

test_that("citecps falls back to the current year without captured_at_utc", {
  prov <- list(dataset = list(publisher = "P"), resource = list(name = "N"))
  cit <- citecps(prov)
  expect_match(cit$bibtex, format(Sys.Date(), "%Y"), fixed = TRUE)
})
