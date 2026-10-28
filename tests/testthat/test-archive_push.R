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

# The rows of a tsvrf() result whose token is for these bytes, signed.
push_ts_rows <- function(ok = TRUE) {
  data.frame(
    check = c(
      "token_parses", "token_structure", "message_imprint", "signature",
      "attribute_digest"
    ),
    ok = ok,
    stringsAsFactors = FALSE
  )
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
           checks = push_ts_rows())
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

# A capture whose manifest names `files` (written by hand, as an attacker
# could), with a good file "a.zip" first.
push_hostile <- function(dir, files) {
  push_capture(dir)
  m <- fromjs(file.path(dir, "manifest.json"), simplifyVector = FALSE)
  one <- m$files[[1L]]
  for (k in seq_along(files)) {
    one$file <- files[[k]]
    one$url <- sprintf("https://s.org/h%d", k)
    m$files[[length(m$files) + 1L]] <- one
  }
  writeLines(tojs(m), file.path(dir, "manifest.json"))
  invisible(dir)
}

test_that(
  "a manifest file name outside the capture folder is never read or sent",
  {
    top <- withr::local_tempdir()
    dir <- file.path(top, "cap")
    dir.create(dir)
    dir.create(file.path(top, "outside"))
    secret <- file.path(top, "outside", "secret.txt")
    writeBin(charToRaw("AAA"), secret)
    file.symlink(secret, file.path(dir, "link.zip"))
    dir.create(file.path(dir, "sub"))
    bad <- c(
      "../outside/secret.txt", secret, "..", ".", "sub", "a\\b.zip",
      "sub/../../outside/secret.txt", "link.zip", "~/x", "a\u009bb"
    )
    push_hostile(dir, bad)
    rec <- new.env()
    rec$puts <- character()
    rec$paths <- character()
    local_mocked_bindings(
      .bl_ia_put = function(url, path, content_type, headers, timeout) {
        rec$puts <- c(rec$puts, url)
        rec$paths <- c(rec$paths, path)
        list(status = 200L, body = raw(), error = "")
      },
      .bl_arc_base = function() "https://archive.rmorie.com",
      .bl_arc_key = function(base) "key",
      .bl_arc_upload = function(path, url, ...) {
        rec$paths <- c(rec$paths, path)
        list(capture_id = "c1", capture = "https://archive.rmorie.com/c/c1")
      }
    )
    why <- "Tables cited in chapter 3 of the thesis"
    r <- arcpush(dir, item = "test-item-2026", ak = "AK1", sk = "SK1",
                 upload = "rmorie", reason = why, tsa = NULL)
    expect_identical(r$status[1:2], c("archived", "archived"))
    expect_true(all(grepl(
      "not a plain relative path inside the capture folder", r$status[-1:-2],
      fixed = TRUE
    )))
    # nothing outside the folder was read, and every key is in the one item
    expect_false(any(grepl("outside|secret|link", rec$paths)))
    expect_true(all(startsWith(
      rec$puts, "https://s3.us.archive.org/test-item-2026/"
    )))
    expect_false(any(grepl("/\\.\\./|/outside/", rec$puts)))
  }
)

test_that("a file name is percent-encoded in its S3 key and mirror", {
  dir <- withr::local_tempdir()
  push_capture(dir)
  file.rename(file.path(dir, "a.zip"), file.path(dir, "a b#?.zip"))
  m <- fromjs(file.path(dir, "manifest.json"), simplifyVector = FALSE)
  m$files[[1L]]$file <- "a b#?.zip"
  writeLines(tojs(m), file.path(dir, "manifest.json"))
  rec <- new.env()
  rec$puts <- character()
  local_mocked_bindings(
    .bl_ia_put = function(url, path, content_type, headers, timeout) {
      rec$puts <- c(rec$puts, url)
      list(status = 200L, body = raw(), error = "")
    }
  )
  r <- arcpush(dir, item = "test-item-2026", ak = "AK1", sk = "SK1",
               tsa = NULL)
  expect_true(
    "https://s3.us.archive.org/test-item-2026/a%20b%23%3F.zip" %in% rec$puts
  )
  expect_identical(
    r$mirror[1L], "https://archive.org/download/test-item-2026/a%20b%23%3F.zip"
  )
  expect_error(.bl_ia_key_path("../x"), "not a file name inside")
})

test_that("a junk timestamp reply is neither kept nor sent nor reused", {
  dir <- withr::local_tempdir()
  push_capture(dir)
  rec <- new.env()
  rec$puts <- character()
  local_mocked_bindings(
    .bl_tsa_post = function(url, body, timeout) {
      list(status = 200L, body = charToRaw("<html>portal</html>"), error = "")
    },
    .bl_ia_put = function(url, path, content_type, headers, timeout) {
      rec$puts <- c(rec$puts, url)
      list(status = 200L, body = raw(), error = "")
    }
  )
  expect_warning(
    r <- arcpush(dir, item = "test-item-2026", ak = "AK1", sk = "SK1"),
    "not a valid timestamp of the manifest .*not kept"
  )
  expect_false(file.exists(file.path(dir, "manifest.tsr")))
  expect_null(attr(r, "timestamp"))
  expect_false(any(grepl("manifest.tsr", rec$puts, fixed = TRUE)))
  # a junk manifest.tsr an earlier version kept is set aside, not sent
  writeBin(charToRaw("junk"), file.path(dir, "manifest.tsr"))
  unlink(file.path(dir, "push.json"))
  rec$puts <- character()
  expect_warning(
    expect_warning(
      r <- arcpush(dir, item = "test-item-2026", ak = "AK1", sk = "SK1"),
      "the kept manifest.tsr is not a valid timestamp"
    ),
    "authority's reply is not a valid timestamp"
  )
  expect_false(file.exists(file.path(dir, "manifest.tsr")))
  expect_true(file.exists(file.path(dir, "manifest.tsr.rejected")))
  expect_false(any(grepl("manifest.tsr", rec$puts, fixed = TRUE)))
})

test_that("the timestamp reply is checked against the request's nonce", {
  dir <- withr::local_tempdir()
  push_capture(dir)
  seen <- new.env()
  local_mocked_bindings(
    .bl_tsa_post = function(url, body, timeout) {
      list(status = 200L, body = charToRaw("tsr"), error = "")
    },
    tsvrf = function(token, data, cert = NULL, trust = NULL, crls = list(),
                     attm = NULL, nonce = NULL) {
      seen$nonce <- nonce
      ck <- rbind(
        push_ts_rows(),
        data.frame(check = "nonce", ok = FALSE, stringsAsFactors = FALSE)
      )
      list(ok = FALSE, time = Sys.time(), checks = ck)
    },
    wbsave = function(urls, ...) stop("offline", call. = FALSE)
  )
  expect_warning(arcpush(dir, upload = "wayback"), "failed: nonce")
  expect_true(is.raw(seen$nonce))
  expect_length(seen$nonce, 8L)
  expect_false(file.exists(file.path(dir, "manifest.tsr")))
})

test_that("a junk token is not printed as imprint and signature verified", {
  m <- charToRaw("manifest")
  ts <- tsvrf(charToRaw("junk"), m)
  expect_match(.bl_cap_ts_text(ts), "NOT verified", fixed = TRUE)
  ts <- tsvrf(as.raw(c(0x30, 0x03, 0x02, 0x01, 0x05)), m)
  expect_match(.bl_cap_ts_text(ts), "NOT verified", fixed = TRUE)
  ok <- list(time = Sys.time(), ok = FALSE, checks = push_ts_rows())
  expect_match(.bl_cap_ts_text(ok), "imprint and signature verified")
  ok$checks$ok[3L] <- FALSE
  expect_match(.bl_cap_ts_text(ok), "NOT verified", fixed = TRUE)
})

test_that("one private address does not stop the Wayback for the others", {
  dir <- withr::local_tempdir()
  urls <- c(
    "https://s.org/a.zip", "http://10.0.0.7/b.csv",
    "https://intranet.s.org/c.csv"
  )
  local_mocked_bindings(
    blfetch = .push_stub(stats::setNames(
      list(charToRaw("A"), charToRaw("B"), charToRaw("C")), urls
    ))
  )
  arccap(urls, dir, tsa = NULL)
  asked <- new.env()
  asked$urls <- list()
  local_mocked_bindings(
    wbsave = function(urls, ...) {
      asked$urls[[length(asked$urls) + 1L]] <- urls
      # as wbsave() refuses a name that resolves to your own network
      if (any(grepl("intranet", urls, fixed = TRUE))) {
        stop("wbsave: not a public address, so it is not sent to ",
             "archive.org: ", grep("intranet", urls, fixed = TRUE,
                                   value = TRUE)[1L],
             call. = FALSE)
      }
      structure(
        data.frame(url = urls, status = "saved",
                   timestamp = "20261028120000", stringsAsFactors = FALSE),
        class = c("rmbl_wayback_save", "data.frame")
      )
    }
  )
  r <- arcpush(dir, upload = "wayback", tsa = NULL)
  expect_identical(r$wayback[1L], "saved 20261028120000")
  expect_match(r$wayback[2L], "^not asked: not a public address")
  expect_match(r$wayback[3L], "^not asked: wbsave: not a public address")
  expect_false(any(grepl("10.0.0.7", unlist(asked$urls), fixed = TRUE)))
})

test_that("a bad `visibility` is refused in words", {
  dir <- withr::local_tempdir()
  for (v in list(NA, 1, c("a", "b"), "secret", character(), NA_character_)) {
    expect_error(
      arcpush(dir, upload = "wayback", visibility = v),
      "`visibility` must be one of"
    )
    expect_error(
      arccap("https://s.org/a", dir, visibility = v),
      "`visibility` must be one of"
    )
  }
})

test_that("a key or a URL part holding %XX is encoded whole", {
  # utils::URLencode() left a string holding "%41" as it was
  expect_identical(.bl_ia_key_path("x%41?y=1#z.txt"), "x%2541%3Fy%3D1%23z.txt")
  expect_identical(.bl_ia_key_path("%2E%2E/other-item/x"),
                   "%252E%252E/other-item/x")
  expect_identical(.rmbl_pct(c("a b", "50%", "%7e&")),
                   c("a%20b", "50%25", "%257e%26"))
  # the Wayback form: a URL holding %20 keeps its & inside the url field
  w <- list(within = "0", capall = FALSE)
  f <- .bl_wb_form(w, "https://s.org/a%20b?x=1&y=2")
  expect_identical(
    f, "url=https%3A%2F%2Fs.org%2Fa%2520b%3Fx%3D1%26y%3D2&skip_first_archive=1"
  )
})

test_that("`visibility` is matched whole, not abbreviated", {
  dir <- withr::local_tempdir()
  for (v in c("pub", "priv", "p", "Public")) {
    expect_error(arcpush(dir, upload = "wayback", visibility = v),
                 "`visibility` must be one of", info = v)
    expect_error(arccap("https://s.org/a", dir, visibility = v),
                 "`visibility` must be one of", info = v)
  }
})
