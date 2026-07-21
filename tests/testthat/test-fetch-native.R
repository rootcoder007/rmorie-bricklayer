# SPDX-License-Identifier: AGPL-3.0-or-later
# The compiled libcurl fetch core. Failure paths run fully OFFLINE
# (127.0.0.1:9 — the discard port, nothing listens). Success paths need
# HTTP by design (the core enforces HTTP semantics: a 200, not a scheme
# curl merely tolerates), so they run only where the network exists —
# the coverage workflow has it; CRAN-style offline checks skip them.

skip_if_no_internet <- function() {
  ok <- !inherits(try(suppressWarnings(
    readLines("https://cloud.r-project.org/", n = 1L, warn = FALSE)),
    silent = TRUE), "try-error")
  if (!ok) testthat::skip("no internet")
}

test_that("bricklayer_fetch validates inputs before any network access", {
  expect_error(bricklayer_fetch("", tempfile()))
  expect_error(bricklayer_fetch(1L, tempfile()))
  expect_error(bricklayer_fetch("https://x", ""))
  expect_error(bricklayer_fetch(c("a", "b"), tempfile()))
})

test_that("bricklayer_fetch errors when live and fallback both fail", {
  expect_error(
    bricklayer_fetch("http://127.0.0.1:9/a", tempfile(),
                     wayback = "http://127.0.0.1:9/b", timeout = 3),
    "Wayback fallback failed"
  )
  # No wayback pinned: same terminal error, shorter path.
  expect_error(
    bricklayer_fetch("http://127.0.0.1:9/only", tempfile(), timeout = 3),
    "Wayback fallback failed"
  )
})

test_that("wayback_snapshot_url_native validates input and degrades to NULL", {
  expect_error(wayback_snapshot_url_native(""))
  expect_error(wayback_snapshot_url_native(1))
  old <- c(http_proxy = Sys.getenv("http_proxy"),
           https_proxy = Sys.getenv("https_proxy"))
  Sys.setenv(http_proxy = "http://127.0.0.1:9",
             https_proxy = "http://127.0.0.1:9")
  on.exit(Sys.setenv(http_proxy = old[["http_proxy"]],
                     https_proxy = old[["https_proxy"]]), add = TRUE)
  expect_null(wayback_snapshot_url_native("https://example.org/", timeout = 3))
})

test_that("bricklayer_fetch_siu validates drid and dest", {
  expect_error(bricklayer_fetch_siu(0, tempfile()))
  expect_error(bricklayer_fetch_siu(-1, tempfile()))
  expect_error(bricklayer_fetch_siu("x", tempfile()))
  expect_error(bricklayer_fetch_siu(c(1, 2), tempfile()))
  expect_error(bricklayer_fetch_siu(648, ""))
})

# ---- live-network success paths (skipped offline) ------------------------

test_that("bricklayer_fetch downloads over live HTTP", {
  skip_if_no_internet()
  dst <- tempfile(fileext = ".html")
  status <- bricklayer_fetch("https://cloud.r-project.org/", dst, timeout = 60)
  expect_identical(status, "live")
  expect_gt(file.size(dst), 500)
})

test_that("bricklayer_fetch falls back to a pinned wayback URL", {
  skip_if_no_internet()
  dst <- tempfile(fileext = ".html")
  status <- bricklayer_fetch(
    "http://127.0.0.1:9/never-there", dst,
    wayback = "https://cloud.r-project.org/", timeout = 60)
  expect_identical(status, "wayback")
  expect_gt(file.size(dst), 500)
})

test_that("wayback_snapshot_url_native resolves a real snapshot", {
  skip_if_no_internet()
  u <- wayback_snapshot_url_native("https://www.r-project.org/", timeout = 30)
  # NULL is legal (service hiccup) but a hit must be a web.archive.org URL.
  if (!is.null(u)) expect_match(u, "web\\.archive\\.org")
})
