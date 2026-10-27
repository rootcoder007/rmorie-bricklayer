# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("loadprov reads a provenance file and refuses a directory", {
  p <- tempfile(fileext = ".json")
  writeLines('{"dataset": {"name": "x"}, "schema": {}}', p)
  prov <- loadprov(p)
  expect_identical(prov$dataset$name, "x")
  expect_null(loadprov(tempfile()))
  expect_error(loadprov(tempdir()), "is a directory")
})

test_that("the resolvers return NULL without the fields they need", {
  expect_null(rslvckan(NULL))
  expect_null(rslvckan(list()))
  expect_null(rslvckan(list(
    dataset = list(ckan_api_endpoint = ""),
    resource = list(name_match_pattern = "x")
  )))
  expect_error(rslvckan("x"), "must be a provenance list")
  expect_null(rslvsoc(NULL))
  expect_null(rslvsoc(list(dataset = list(socrata_domain = "a.org"))))
  expect_error(rslvsoc(1), "must be a provenance list")
  expect_null(rslvarc(NULL))
  expect_null(rslvarc(list(dataset = list())))
})

test_that("rslvckan picks the first resource whose name matches", {
  local_mocked_bindings(
    .rmbl_check_public_url = function(url, what, ...) url,
    .rmbl_read_json = function(url, ...) {
      list(
        success = TRUE,
        result = list(
          resources = list(
            list(name = "Data dictionary", url = "https://a.org/dict.pdf"),
            list(name = "Annual data 2024", url = "https://a.org/data.csv"),
            list(name = "Annual data 2023", url = "https://a.org/old.csv")
          )
        )
      )
    }
  )
  prov <- list(
    dataset = list(ckan_api_endpoint = "https://a.org/api/3/action/x"),
    resource = list(name_match_pattern = "annual data")
  )
  expect_identical(rslvckan(prov), "https://a.org/data.csv")
  prov$resource$name_match_pattern <- "nothing like it"
  expect_null(rslvckan(prov))
})

test_that("rslvckan is NULL when the API does not answer success", {
  local_mocked_bindings(
    .rmbl_check_public_url = function(url, what, ...) url,
    .rmbl_read_json = function(url, ...) list(success = FALSE)
  )
  prov <- list(
    dataset = list(ckan_api_endpoint = "https://a.org/api/3/action/x"),
    resource = list(name_match_pattern = "x")
  )
  expect_null(rslvckan(prov))
})

test_that("rslvsoc and rslvarc build the export URLs", {
  local_mocked_bindings(
    .rmbl_check_public_url = function(url, what, ...) url,
    .rmbl_read_json = function(url, ...) list(id = "abcd-1234", name = "L")
  )
  expect_identical(
    rslvsoc(list(
      dataset = list(socrata_domain = "data.a.org", socrata_id = "abcd-1234")
    )),
    "https://data.a.org/api/views/abcd-1234/rows.csv?accessType=DOWNLOAD"
  )
  expect_identical(
    rslvarc(list(
      dataset = list(arcgis_layer_url = "https://a.org/FeatureServer/0/")
    )),
    "https://a.org/FeatureServer/0/query?where=1%3D1&outFields=*&f=geojson"
  )
})

test_that("wbsnpurl reads the closest snapshot and upgrades it to https", {
  local_mocked_bindings(
    .rmbl_check_public_url = function(url, what, ...) url,
    .rmbl_read_json = function(url, ...) {
      list(
        archived_snapshots = list(
          closest = list(
            available = TRUE,
            url = "http://web.archive.org/web/2024/https://a.org/x.csv"
          )
        )
      )
    }
  )
  expect_identical(
    wbsnpurl("https://a.org/x.csv", ts = "2024"),
    "https://web.archive.org/web/2024/https://a.org/x.csv"
  )
  local_mocked_bindings(
    .rmbl_read_json = function(url, ...) {
      list(archived_snapshots = list(closest = list(available = FALSE)))
    }
  )
  expect_null(wbsnpurl("https://a.org/x.csv"))
})

test_that("vrfsha256 compares a file with its pinned digest", {
  p <- tempfile()
  writeLines("abc", p)
  d <- sha256file(p)
  ok <- vrfsha256(p, list(toupper(d)))
  expect_true(ok$match)
  expect_identical(ok$expected, d)
  expect_false(vrfsha256(p, strrep("0", 64))$match)
  expect_error(vrfsha256(p, c("a", "b")), "single SHA-256 hex string")
})

test_that("valsch reads an absent, an empty and a bad schema", {
  d <- data.frame(a = 1:3)
  expect_identical(valsch(d, NULL), list())
  expect_identical(valsch(d, list(dataset = list())), list())
  empty <- valsch(d, list(schema = list()))
  expect_named(empty, "schema_empty")
  expect_identical(empty$schema_empty$severity, "warning")
  expect_error(valsch(1, NULL), "must be a data frame")
  expect_error(valsch(d, "x"), "must be a provenance list")
  expect_error(valsch(d, list(schema = "x")), "must be a list")
  expect_error(
    schval(d, list(dataset = list())),
    "nothing would be validated"
  )
  expect_error(schval(d, list(schema = list())), "the schema is empty")
})

test_that("wbsnpurl checks ts and url before any request", {
  u <- "https://a.org/x.csv"
  for (ts in list(
    "2020&url=evil.org",
    NA,
    TRUE,
    c("1", "2"),
    "123456789012345"
  )) {
    expect_error(wbsnpurl(u, ts = ts), "wbsnpurl: `ts` must be NULL")
  }
  expect_error(wbsnpurl("x"), "url")
  expect_error(vrfsha256(tempfile(), function() 1), "vrfsha256: `expsha` must")
})

# ---- loadprov() prints as a box; what it reads and writes is unchanged -------

test_that("loadprov() carries a class and reads whether the data is pinned", {
  f <- tempfile(fileext = ".json")
  writeLines('{"name": "n", "resource": {"filename": "d.csv"}}', f)
  p <- loadprov(f)
  expect_s3_class(p, c("rmbl_provenance", "list"))
  expect_identical(tojs(p, pretty = TRUE), tojs(unclass(p), pretty = TRUE))
  expect_box2(p, "Provenance record", c("resource$filename", "Not pinned yet"))
  writeLines(sprintf(
    '{"name": "n", "resource": {"filename": "d.csv", "sha256": "%s"}}',
    strrep("ab", 32)
  ), f)
  expect_box2(loadprov(f), "Provenance record", "Pinned: the data file")
})

test_that("a provenance record past 60 fields says how many are left out", {
  p <- structure(
    stats::setNames(as.list(seq_len(70)), paste0("f", seq_len(70))),
    class = c("rmbl_provenance", "list")
  )
  expect_match(box_text(p),
    "... and 10 more fields: unclass(x) has them all.", fixed = TRUE)
})
