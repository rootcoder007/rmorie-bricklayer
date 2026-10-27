# SPDX-License-Identifier: AGPL-3.0-or-later
# Provenance loading, CKAN resolution guards, Wayback URL handling,
# downloads (file:// only — no network), sha256, schema validation.

test_that("loadprov returns NULL for a missing path and roundtrips JSON", {
  expect_null(loadprov(file.path(tempdir(), "nope-does-not-exist.json")))
  p <- tempfile(fileext = ".json")
  jsonlite::write_json(
    list(dataset = list(id = "otis-b01"), resource = list(sha256 = "abc")),
    p,
    auto_unbox = TRUE
  )
  prov <- loadprov(p)
  expect_identical(prov$dataset$id, "otis-b01")
  expect_identical(prov$resource$sha256, "abc")
})

test_that("rslvckan returns NULL on absent provenance or endpoint", {
  expect_null(rslvckan(NULL))
  expect_null(rslvckan(list(dataset = list(), resource = list())))
  expect_null(rslvckns(NULL))
})

test_that("wbsnpurl upgrades snapshots to https and rejects unavailable", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) {
      list(
        archived_snapshots = list(
          closest = list(
            available = TRUE,
            url = "http://web.archive.org/web/2024/https://x.csv"
          )
        )
      )
    }
  )
  out <- wbsnpurl("https://example.org/x.csv")
  expect_match(out, "^https://web\\.archive\\.org/")

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(archived_snapshots = list())
  )
  expect_null(wbsnpurl("https://example.org/x.csv"))
})

test_that("dldata and fdl work over file:// without network", {
  src <- tempfile(fileext = ".csv")
  writeLines("a,b\n1,2", src)
  url <- paste0("file://", src)

  dst <- tempfile(fileext = ".csv")
  dldata(url, dst, quiet = TRUE, allowfile = TRUE)
  expect_identical(readLines(dst), readLines(src))

  dst2 <- tempfile(fileext = ".csv")
  expect_true(suppressWarnings(fdl(url, dst2, attwb = "", allowfile = TRUE)))
  expect_true(file.exists(dst2))

  # Failure path: nonexistent source, Wayback fallback disabled.
  bad <- paste0("file://", tempfile(fileext = ".missing"))
  res <- NULL
  capture.output(
    {
      res <- suppressWarnings(fdl(
        bad,
        tempfile(),
        attwb = "",
        allowfile = TRUE
      ))
    }
  )
  expect_false(res)
})

test_that("sha256file matches digest and vrfsha256 classifies match/mismatch", {
  f <- tempfile()
  writeLines("brick", f)
  h <- sha256file(f)
  expect_identical(h, digest::digest(file = f, algo = "sha256"))
  expect_true(vrfsha256(f, h)$match)
  bad <- vrfsha256(f, strrep("0", 64))
  expect_false(bad$match)
  expect_identical(bad$actual, h)
})

test_that("valsch flags missing columns as fatal and short rows as warning", {
  prov <- list(
    schema = list(
      expected_columns = c("id", "year", "value"),
      structural_invariants = list(min_data_rows = 5)
    )
  )
  df_bad <- data.frame(id = 1:2, year = 2024:2025)
  issues <- valsch(df_bad, prov)
  expect_identical(issues$missing_columns$severity, "fatal")
  expect_match(issues$missing_columns$message, "value")
  expect_identical(issues$row_count_low$severity, "warning")

  df_ok <- data.frame(id = 1:6, year = 2020:2025, value = rnorm(6))
  expect_length(valsch(df_ok, prov), 0)
  expect_length(valsch(df_ok, NULL), 0)
})

test_that("schval stops on fatal, warns on warning, TRUE when clean", {
  prov <- list(
    schema = list(
      expected_columns = "id",
      structural_invariants = list(min_data_rows = 3)
    )
  )
  expect_error(
    schval(data.frame(x = 1), prov),
    "Missing required columns"
  )
  expect_warning(
    schval(data.frame(id = 1:2), prov),
    "below expected minimum"
  )
  expect_true(schval(data.frame(id = 1:5), prov))
})

test_that("rslvckan returns the first name-matched resource URL", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) {
      list(
        success = TRUE,
        result = list(
          resources = list(
            list(name = "Readme", url = "https://example.org/readme.txt"),
            list(name = "Data 2014", url = "https://example.org/2014.csv")
          )
        )
      )
    }
  )
  prov <- list(
    dataset = list(
      ckan_api_endpoint = paste0(
        "https://portal.example.org/api/3/ac",
        "tion/package_show?id=x"
      )
    ),
    resource = list(name_match_pattern = "2014")
  )
  expect_identical(rslvckan(prov), "https://example.org/2014.csv")

  prov$resource$name_match_pattern <- "2099"
  expect_null(rslvckan(prov))
})

test_that("rslvckns matches resources and derives the query", {
  skip_if_cannot_mock()
  st <- new.env(parent = emptyenv())
  st$seen_url <- NULL
  testthat::local_mocked_bindings(
    .rmbl_read_json = function(url, ...) {
      st$seen_url <- url
      list(
        result = list(
          results = list(list(
            resources = list(
              list(
                name = "Data 2014",
                format = "XLSX",
                url = "https://example.org/s.xlsx"
              ),
              list(
                name = "Data 2014",
                format = "CSV",
                url = "https://example.org/s.csv"
              )
            )
          ))
        )
      )
    }
  )
  prov <- list(
    dataset = list(
      ckan_api_endpoint = paste0(
        "https://portal.example.org/api/3/ac",
        "tion/package_show?id=x"
      )
    ),
    resource = list(
      name_match_pattern = "2014",
      search_query = "library stats",
      format = "CSV"
    )
  )
  expect_identical(rslvckns(prov), "https://example.org/s.csv")
  expect_match(st$seen_url, "package_search\\?q=library%20stats")

  # query derived from the name pattern when search_query is absent
  prov$resource$search_query <- NULL
  expect_identical(rslvckns(prov), "https://example.org/s.csv")
  expect_match(st$seen_url, "q=2014")

  # no portal base URL derivable -> NULL
  expect_null(rslvckns(list(resource = list(name_match_pattern = "x"))))
})

test_that("wbsnpurl honours an explicit timestamp", {
  skip_if_cannot_mock()
  st <- new.env(parent = emptyenv())
  st$seen <- NULL
  testthat::local_mocked_bindings(
    .rmbl_read_json = function(url, ...) {
      st$seen <- url
      list(
        archived_snapshots = list(
          closest = list(
            available = TRUE,
            url = "http://web.archive.org/web/20240101/https://x.csv"
          )
        )
      )
    }
  )
  out <- wbsnpurl("https://example.org/x.csv", ts = "20240101000000")
  expect_match(st$seen, "&timestamp=20240101000000", fixed = TRUE)
  expect_match(out, "^https://")
})

test_that("fdl prints diagnostics and retries from a wayback snapshot", {
  skip_if_cannot_mock()
  snap <- tempfile(fileext = ".csv")
  writeLines("a,b\n1,2", snap)
  st <- new.env(parent = emptyenv())
  st$calls <- 0L
  testthat::local_mocked_bindings(
    .bl_fetch_file = function(url, dest, ...) {
      st$calls <- st$calls + 1L
      if (st$calls == 1L) {
        stop("HTTP error 429: too many requests")
      }
      file.copy(sub("^file://", "", url), dest, overwrite = TRUE)
      invisible(dest)
    }
  )
  dst <- tempfile(fileext = ".csv")
  out <- capture.output(type = "message", {
    ok <- fdl(
      "https://example.org/x.csv",
      dst,
      attwb = paste0("file://", snap),
      allowfile = TRUE
    )
  })
  expect_true(ok)
  expect_true(file.exists(dst))
  expect_true(any(grepl("Rate-limited", out, fixed = TRUE)))
  expect_true(any(grepl("Wayback", out, fixed = TRUE)))
})

test_that("fdl covers the failure diagnostics and total failure", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .bl_fetch_file = function(...) {
      stop(
        "SSL certificate handshake failed; connection timed out; ",
        "could not resolve host; HTTP 403 forbidden"
      )
    }
  )
  # auto-resolution consults wbsnpurl; make it find nothing
  testthat::local_mocked_bindings(wbsnpurl = function(...) NULL)
  out <- capture.output(type = "message", {
    ok <- fdl("https://example.org/x.csv", tempfile())
  })
  expect_false(ok)
  expect_true(any(grepl("SSL/TLS", out, fixed = TRUE)))
  expect_true(any(grepl("DNS", out, fixed = TRUE)))
  expect_true(any(grepl("timed out", out, fixed = TRUE)))
  expect_true(any(grepl("403", out, fixed = TRUE)))
})

test_that("fdl reports a failed wayback retry", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .bl_fetch_file = function(...) stop("could not resolve host")
  )
  out <- capture.output(type = "message", {
    ok <- fdl(
      "https://example.org/x.csv",
      tempfile(),
      attwb = "file:///nonexistent/nope.csv",
      allowfile = TRUE
    )
  })
  expect_false(ok)
  expect_true(any(grepl("also failed", out, fixed = TRUE)))
})

test_that("rslvsoc returns the canonical CSV export URL", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(id = "ijzp-q8t2")
  )
  prov <- list(
    dataset = list(
      socrata_domain = "data.example.org",
      socrata_id = "ijzp-q8t2"
    )
  )
  expect_identical(
    rslvsoc(prov),
    "https://data.example.org/api/views/ijzp-q8t2/rows.csv?accessType=DOWNLOAD"
  )

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) stop("network down")
  )
  expect_null(rslvsoc(prov))
})

test_that("rslvarc returns a paged GeoJSON query URL, trimming slashes", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(name = "Layer0")
  )
  prov <- list(
    dataset = list(
      arcgis_layer_url = "https://svc.example.org/FeatureServer/0///"
    )
  )
  expect_identical(
    rslvarc(prov),
    paste0(
      "https://svc.example.org/FeatureServer/0/query?where=1%3D1&outFields=",
      "*&f=geojson"
    )
  )

  testthat::local_mocked_bindings(
    .rmbl_read_json = function(...) list(error = list(code = 400))
  )
  expect_null(rslvarc(prov))
})

test_that(
  paste0(
    "the CKAN resolvers return NULL for an empty endpoint, a failed call ",
    "and no match"
  ),
  {
    skip_if_cannot_mock()
    prov <- list(
      dataset = list(ckan_api_endpoint = ""),
      resource = list(name_match_pattern = "x")
    )
    expect_null(rslvckan(prov))
    prov$dataset$ckan_api_endpoint <- paste0(
      "https://portal.example.org/api/3/ac",
      "tion/package_show?id=x"
    )
    testthat::with_mocked_bindings(
      .rmbl_read_json = function(...) list(success = FALSE),
      expect_null(rslvckan(prov))
    )
    expect_null(rslvckns(list(
      dataset = prov$dataset,
      resource = list(name_match_pattern = "")
    )))
    testthat::with_mocked_bindings(
      .rmbl_read_json = function(...) NULL,
      expect_null(rslvckns(list(
        dataset = prov$dataset,
        resource = list(search_query = "libraries")
      )))
    )
    testthat::with_mocked_bindings(
      .rmbl_read_json = function(...) {
        list(
          result = list(
            results = list(list(
              resources = list(list(name = "other", format = "CSV", url = "u"))
            ))
          )
        )
      },
      expect_null(rslvckns(list(
        dataset = prov$dataset,
        resource = list(
          search_query = "libraries",
          name_match_pattern = "stats"
        )
      )))
    )
  }
)

test_that("numeric range checks skip non-numeric and all-missing columns", {
  prov <- list(
    schema = list(
      numeric_ranges = list(a = c(min = 0, max = 1), b = c(min = 0, max = 1))
    )
  )
  df <- data.frame(
    a = c("x", "y"),
    b = c(NA_real_, NA_real_),
    stringsAsFactors = FALSE
  )
  expect_length(valsch(df, prov), 0)
})

test_that("a snapshot lookup that returns nothing usable is no snapshot", {
  answer <- function(url) {
    list(archived_snapshots = list(closest = list(available = TRUE, url = url)))
  }
  testthat::local_mocked_bindings(.rmbl_read_json = function(api, ...) {
    answer(list())
  })
  expect_null(wbsnpurl("https://example.invalid/x.csv"))
  testthat::local_mocked_bindings(.rmbl_read_json = function(api, ...) {
    answer("http://web.archive.org/x")
  })
  expect_identical(
    wbsnpurl("https://example.invalid/x.csv"),
    "https://web.archive.org/x"
  )
})


test_that("fdl names a refused connection as one, not as a DNS failure", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .bl_fetch_file = function(...) {
      stop(
        "URL 'https://www.r-project.org/': status was 'Could not ",
        "connect to server'"
      )
    }
  )
  out <- capture.output(type = "message", {
    ok <- suppressWarnings(fdl(
      "https://www.r-project.org/",
      tempfile(),
      attwb = ""
    ))
  })
  expect_false(ok)
  expect_true(any(grepl("Could not connect to the server", out, fixed = TRUE)))
  expect_false(any(grepl("DNS lookup failed", out, fixed = TRUE)))
})

test_that("fdl with the Wayback fallback off says so, and claims no lookup", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(
    .bl_fetch_file = function(...) stop("HTTP 404"),
    wbsnpurl = function(...) stop("must not be called")
  )
  for (off in list(FALSE, "")) {
    out <- capture.output(type = "message", {
      ok <- fdl("https://example.org/x.csv", tempfile(), attwb = off)
    })
    expect_false(ok)
    expect_true(any(grepl("switched off", out, fixed = TRUE)))
    expect_false(any(grepl("no snapshot", out, fixed = TRUE)))
  }
  # the default looks one up, and says when there is none
  testthat::local_mocked_bindings(wbsnpurl = function(...) NULL)
  out <- capture.output(type = "message", {
    ok <- fdl("https://example.org/x.csv", tempfile())
  })
  expect_false(ok)
  expect_true(any(grepl("no snapshot", out, fixed = TRUE)))
})
