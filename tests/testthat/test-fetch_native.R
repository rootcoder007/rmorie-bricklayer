# SPDX-License-Identifier: AGPL-3.0-or-later
# The compiled libcurl fetch core. Failure paths run fully OFFLINE
# (127.0.0.1:9 — the discard port, nothing listens). Success paths need
# HTTP by design (the core enforces HTTP semantics: a 200, not a scheme
# curl merely tolerates), so they run only where the network exists —
# the coverage workflow has it; CRAN-style offline checks skip them.

skip_if_no_internet <- function() {
  # live traffic only when asked for: a test run is not a reason to reach
  # cloud.r-project.org or archive.org (review of 29a55d8, L4); the CI check job
  # sets it
  if (!identical(Sys.getenv("RMBL_LIVE_TESTS"), "1")) {
    testthat::skip("set RMBL_LIVE_TESTS=1 for the live fetch checks")
  }
  ok <- !inherits(
    try(
      suppressWarnings(
        readLines("https://cloud.r-project.org/", n = 1L, warn = FALSE)
      ),
      silent = TRUE
    ),
    "try-error"
  )
  if (!ok) testthat::skip("no internet")
}

test_that("blfetch validates inputs before any network access", {
  expect_error(blfetch("", tempfile()))
  expect_error(blfetch(1L, tempfile()))
  expect_error(blfetch("https://x", ""))
  expect_error(blfetch(c("a", "b"), tempfile()))
})

test_that("blfetch errors when live and fallback both fail", {
  skip_if_not(
    identical(Sys.getenv("RMBL_LIVE_TESTS"), "1"),
    "the fallback looks archive.org up: RMBL_LIVE_TESTS=1"
  )
  expect_error(
    blfetch(
      "https://invalid.invalid/a",
      tempfile(),
      wb = "https://invalid.invalid/b",
      tmout = 3
    ),
    "Wayback fallback failed"
  )
  # No wayback pinned: same terminal error, shorter path.
  expect_error(
    blfetch("https://invalid.invalid/only", tempfile(), tmout = 3),
    "Wayback fallback failed"
  )
})

test_that("wbsnpnat validates input and degrades to NULL", {
  expect_error(wbsnpnat(""))
  expect_error(wbsnpnat(1))
  # the transport does not honour a proxy, so this reaches archive.org: live
  # runs only (H8)
  skip_if_not(
    identical(Sys.getenv("RMBL_LIVE_TESTS"), "1"),
    "set RMBL_LIVE_TESTS=1 for the live lookup"
  )
  old <- c(
    http_proxy = Sys.getenv("http_proxy"),
    https_proxy = Sys.getenv("https_proxy")
  )
  Sys.setenv(
    http_proxy = "http://127.0.0.1:9",
    https_proxy = "http://127.0.0.1:9"
  )
  on.exit(
    Sys.setenv(
      http_proxy = old[["http_proxy"]],
      https_proxy = old[["https_proxy"]]
    ),
    add = TRUE
  )
  expect_null(wbsnpnat("https://example.org/", tmout = 3))
})

test_that("siufetch validates drid and dest", {
  expect_error(siufetch(0, tempfile()))
  expect_error(siufetch(-1, tempfile()))
  expect_error(siufetch("x", tempfile()))
  expect_error(siufetch(c(1, 2), tempfile()))
  expect_error(siufetch(648, ""))
})

# ---- live-network success paths (skipped offline) ------------------------

test_that("blfetch downloads over live HTTP", {
  skip_if_no_internet()
  dst <- tempfile(fileext = ".html")
  status <- blfetch("https://cloud.r-project.org/", dst, tmout = 60)
  expect_identical(status, "live")
  expect_gt(file.size(dst), 500)
})

test_that("blfetch falls back to a pinned wayback URL", {
  skip_if_no_internet()
  dst <- tempfile(fileext = ".html")
  status <- blfetch(
    "https://invalid.invalid/never-there",
    dst,
    wb = "https://cloud.r-project.org/",
    tmout = 60
  )
  expect_identical(status, "wayback")
  expect_gt(file.size(dst), 500)
})

test_that("wbsnpnat resolves a real snapshot", {
  skip_if_no_internet()
  u <- wbsnpnat("https://www.r-project.org/", tmout = 30)
  # NULL is legal (archive.org throttling with 429, or down) but it is not a
  # pass: say so; a hit must be a web.archive.org URL
  skip_if(
    is.null(u),
    "archive.org gave no snapshot just now (rate limit or outage)"
  )
  expect_match(u, "web\\.archive\\.org")
})

test_that("siufetch builds the SIU report URL and forwards options", {
  seen <- new.env()
  testthat::local_mocked_bindings(
    blfetch = function(url, dest, wb = "", tmout = 120L) {
      seen$url <- url
      seen$dest <- dest
      seen$wayback <- wb
      seen$timeout <- tmout
      invisible(dest)
    }
  )
  d <- tempfile(fileext = ".html")
  siufetch(648, d)
  expect_identical(
    seen$url,
    "https://www.siu.on.ca/en/directors_report_details.php?drid=648"
  )
  expect_identical(seen$dest, d)
  expect_identical(seen$wayback, "")
  expect_identical(seen$timeout, 120L)
  siufetch("12", d, lang = "fr", wb = "20240101", tmout = 30L)
  expect_identical(
    seen$url,
    "https://www.siu.on.ca/fr/directors_report_details.php?drid=12"
  )
  expect_identical(seen$wayback, "20240101")
  expect_identical(seen$timeout, 30L)
  expect_error(siufetch(1, d, lang = "de"))
})

test_that("blfetch reports the HTTP status of a server that answered", {
  skip_if_no_internet()
  # a 404 is an answer, not an unreachable server
  msg <- tryCatch(
    blfetch(
      "https://cloud.r-project.org/nosuch-bricklayer-r8.csv",
      tempfile(),
      wb = "http://127.0.0.1:9/b",
      tmout = 60
    ),
    error = conditionMessage
  )
  if (grepl("could not reach", msg, fixed = TRUE)) {
    skip("cloud.r-project.org did not answer from this runner")
  }
  expect_match(msg, "answered HTTP 404")
})
