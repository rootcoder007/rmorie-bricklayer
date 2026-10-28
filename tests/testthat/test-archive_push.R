# SPDX-License-Identifier: AGPL-3.0-or-later
# arcpush(): a capture kept on this computer, sent on to the archives later.

# A stand-in for blfetch() that serves these bytes.
.push_stub <- function(serve) {
  force(serve)
  function(url, dest, wb = "", tmout = 120L) {
    b <- serve[[url]]
    if (is.null(b)) {
      stop("blfetch: could not reach", call. = FALSE)
    }
    writeBin(b, dest)
    invisible("live")
  }
}

# A capture of two files, kept here only, as arccap() makes it offline.
push_capture <- function(dir) {
  local_mocked_bindings(
    blfetch = .push_stub(list(
      "https://s.org/a.zip" = charToRaw("AAA"),
      "https://s.org/b.csv" = charToRaw("x,y")
    ))
  )
  arccap(c("https://s.org/a.zip", "https://s.org/b.csv"), dir, tsa = NULL)
}

test_that("a capture kept here goes to an archive.org item later", {
  dir <- withr::local_tempdir()
  cap <- push_capture(dir)
  expect_identical(cap$status, c("captured", "captured"))
  rec <- new.env()
  rec$puts <- list()
  rec$code <- 503L
  local_mocked_bindings(
    .bl_ia_put = function(url, path, content_type, headers, timeout) {
      rec$puts[[length(rec$puts) + 1L]] <- list(url = url, path = path)
      list(status = rec$code, body = raw(), error = "")
    }
  )
  # archive.org is down: nothing is lost, and the reason is recorded
  r <- arcpush(dir, item = "test-item-2026", ak = "AK1", sk = "SK1",
               tsa = NULL)
  expect_match(r$status, "^failed: archive.org refused manifest.json")
  expect_true(file.exists(file.path(dir, "push.json")))
  # back up: the same bytes go, the manifest first
  rec$code <- 200L
  rec$puts <- list()
  r <- arcpush(dir, item = "test-item-2026", ak = "AK1", sk = "SK1",
               tsa = NULL)
  expect_identical(r$status, c("uploaded", "uploaded"))
  expect_identical(
    r$mirror[1L], "https://archive.org/download/test-item-2026/a.zip"
  )
  expect_match(rec$puts[[1L]]$url, "/test-item-2026/manifest.json$")
  expect_identical(rec$puts[[2L]]$path, file.path(dir, "a.zip"))
  expect_length(rec$puts, 3L)
  expect_identical(r$sha256, cap$sha256)
  # nothing is sent twice
  rec$puts <- list()
  r <- arcpush(dir, item = "test-item-2026", ak = "AK1", sk = "SK1",
               tsa = NULL)
  expect_length(rec$puts, 0L)
  expect_identical(r$status, c("uploaded", "uploaded"))
  expect_output(print(r), "Archive capture")
})

test_that("a file that changed or went missing is not sent", {
  dir <- withr::local_tempdir()
  push_capture(dir)
  writeBin(charToRaw("BBB"), file.path(dir, "a.zip"))
  unlink(file.path(dir, "b.csv"))
  n <- new.env()
  n$sent <- 0L
  local_mocked_bindings(
    .bl_ia_put = function(url, path, content_type, headers, timeout) {
      n$sent <- n$sent + 1L
      list(status = 200L, body = raw(), error = "")
    }
  )
  r <- arcpush(dir, item = "test-item-2026", ak = "AK1", sk = "SK1",
               tsa = NULL)
  expect_identical(
    r$status,
    c(
      "failed: the file no longer matches its SHA-256 in the manifest",
      "failed: the file is missing"
    )
  )
  expect_identical(n$sent, 0L)
})

test_that("archive.rmorie.com takes the capture when it is back", {
  dir <- withr::local_tempdir()
  push_capture(dir)
  n <- new.env()
  n$calls <- 0L
  up <- FALSE
  local_mocked_bindings(
    .bl_arc_base = function() "https://archive.rmorie.com",
    .bl_arc_key = function(base) "key",
    .bl_arc_upload = function(path, url, ...) {
      n$calls <- n$calls + 1L
      if (!up) {
        stop("archive.rmorie.com answered 503", call. = FALSE)
      }
      list(capture_id = basename(path),
           capture = paste0("https://archive.rmorie.com/c/", basename(path)))
    }
  )
  why <- "Tables cited in chapter 3 of the thesis"
  r <- arcpush(dir, upload = "rmorie", reason = why, tsa = NULL)
  expect_match(r$status, "answered 503 \\(the file is kept locally\\)")
  up <- TRUE
  r <- arcpush(dir, upload = "rmorie", reason = why, tsa = NULL)
  expect_identical(r$status, c("archived", "archived"))
  expect_identical(r$capture_id, c("a.zip", "b.csv"))
  expect_identical(n$calls, 4L)
  # a later run keeps what was archived and sends nothing
  r <- arcpush(dir, upload = "rmorie", reason = why, tsa = NULL)
  expect_identical(n$calls, 4L)
  expect_identical(r$archive[1L], "https://archive.rmorie.com/c/a.zip")
})

test_that("the Wayback Machine is asked again until it answers", {
  dir <- withr::local_tempdir()
  push_capture(dir)
  n <- new.env()
  n$asked <- 0L
  down <- TRUE
  local_mocked_bindings(
    wbsave = function(urls, ...) {
      n$asked <- n$asked + 1L
      if (down) {
        stop("web.archive.org did not answer", call. = FALSE)
      }
      structure(
        data.frame(url = urls, status = "saved",
                   timestamp = "20261028120000", stringsAsFactors = FALSE),
        class = c("rmbl_wayback_save", "data.frame")
      )
    }
  )
  r <- arcpush(dir, upload = "wayback", tsa = NULL)
  expect_match(r$wayback, "^not asked: web.archive.org did not answer")
  down <- FALSE
  r <- arcpush(dir, upload = "wayback", tsa = NULL)
  expect_identical(r$wayback, rep("saved 20261028120000", 2L))
  r <- arcpush(dir, upload = "wayback", tsa = NULL)
  expect_identical(n$asked, 2L)
  # the files themselves stay captured: the Wayback Machine takes no uploads
  expect_identical(r$status, c("captured", "captured"))
})

test_that("a manifest without a timestamp is stamped when it is sent", {
  dir <- withr::local_tempdir()
  push_capture(dir)
  n <- new.env()
  n$checked <- 0L
  local_mocked_bindings(
    .bl_tsa_post = function(url, body, timeout) {
      list(status = 200L, body = charToRaw("tsr"), error = "")
    },
    tsvrf = function(token, data, ...) {
      n$checked <- n$checked + 1L
      list(ok = TRUE, time = as.POSIXct("2026-10-28", tz = "UTC"),
           checks = data.frame(check = "signature", ok = TRUE))
    },
    wbsave = function(urls, ...) stop("offline", call. = FALSE)
  )
  r <- arcpush(dir, upload = "wayback")
  expect_true(file.exists(file.path(dir, "manifest.tsr")))
  expect_true(attr(r, "timestamp")$ok)
  # the timestamp kept is checked, not replaced
  r <- arcpush(dir, upload = "wayback")
  expect_identical(n$checked, 2L)
  expect_true(attr(r, "timestamp")$ok)
})

test_that("arcpush refuses what it cannot send", {
  dir <- withr::local_tempdir()
  expect_error(arcpush(dir, upload = "wayback"), "manifest.json is missing")
  writeLines('{"files": []}', file.path(dir, "manifest.json"))
  expect_error(arcpush(dir, upload = "wayback"), "lists no files")
  expect_error(arcpush(dir), "give `item`, `upload` or both")
  expect_error(arcpush(dir, upload = "rmorie"), "`reason` is needed")
  expect_error(arcpush(dir, upload = "elsewhere"), "`upload` must be")
  expect_error(arcpush(dir, item = "x"), "`item` must be")
})

test_that("rmbl archive push sends a capture kept here", {
  dir <- withr::local_tempdir()
  push_capture(dir)
  run <- function(...) {
    rec <- new.env()
    rec$buf <- character()
    st <- blcli(c(...), out = function(s) rec$buf <- c(rec$buf, s))
    list(status = st, text = paste(rec$buf, collapse = ""))
  }
  up <- FALSE
  local_mocked_bindings(
    .bl_arc_base = function() "https://archive.rmorie.com",
    .bl_arc_key = function(base) "key",
    .bl_arc_upload = function(path, url, ...) {
      if (!up) stop("archive.rmorie.com answered 503", call. = FALSE)
      list(capture_id = "c1", capture = "https://archive.rmorie.com/c/c1")
    },
    wbsave = function(urls, ...) stop("offline", call. = FALSE)
  )
  why <- "Tables cited in chapter 3 of the thesis"
  expect_identical(run("archive", "push", dir)$status, 2L)
  expect_identical(
    run("archive", "push", dir, "--reason", why, "--also", "x")$status, 2L
  )
  r <- run("archive", "push", dir, "--reason", why, "--also", "wayback")
  expect_identical(r$status, 1L)
  expect_match(r$text, "Archive capture", fixed = TRUE)
  up <- TRUE
  r <- run("archive", "push", dir, "--reason", why, "--private")
  expect_identical(r$status, 0L)
})
