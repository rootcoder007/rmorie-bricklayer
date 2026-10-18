# archive_capture(): capture from here, timestamp the manifest, upload to an archive.org item

test_that("the RFC 3161 request is the DER a time-stamping authority expects", {
  d <- as.raw(0:31)
  q <- .bl_tsq(d, as.raw(1:8))
  hdr <- as.raw(c(0x30, 0x43, 0x02, 0x01, 0x01, 0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01,
                  0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20))
  expect_identical(q, c(hdr, d, as.raw(c(0x02, 0x08)), as.raw(1:8), as.raw(c(0x01, 0x01, 0xff))))
  expect_identical(.bl_der(0x04, raw(200))[1:3], as.raw(c(0x04, 0x81, 200)))
  expect_identical(.bl_der(0x04, raw(300))[1:4], as.raw(c(0x04, 0x82, 0x01, 0x2c)))
  expect_identical(.bl_hex_raw("00ff10"), as.raw(c(0, 255, 16)))
})

test_that("capture names are safe and unique", {
  expect_identical(.bl_capture_name("https://x.org/n1/tbl/csv/41100063-eng.zip"), "41100063-eng.zip")
  a <- .bl_capture_name("https://x.org/t1/tbl1/en/tv.action?pid=1")
  b <- .bl_capture_name("https://x.org/t1/tbl1/en/tv.action?pid=2")
  expect_false(identical(a, b))
  expect_match(a, "^tv_[0-9a-f]{10}\\.action$")
  expect_identical(.bl_capture_name("https://x.org/"), "index")
})

.cap_stub <- function(serve) {
  force(serve)
  function(url, dest, wayback = "", timeout = 120L) {
    b <- serve[[url]]
    if (is.null(b)) stop("bricklayer_fetch: could not reach", call. = FALSE)
    writeBin(b, dest)
    invisible("live")
  }
}

test_that("archive_capture() captures, timestamps and uploads, keys only in the header", {
  dir <- withr::local_tempdir()
  puts <- list()
  local_mocked_bindings(
    bricklayer_fetch = .cap_stub(list("https://s.org/a.zip" = charToRaw("AAA"),
                                      "https://s.org/t.action?pid=1" = charToRaw("<html>"))),
    .bl_tsa_post = function(url, body, timeout) list(status = 200L, body = charToRaw("tsr"), error = ""),
    timestamp_verify = function(token, data, ...) {
      list(ok = FALSE, time = as.POSIXct("2026-10-18", tz = "UTC"),
           checks = data.frame(check = c("message_imprint", "signature"), ok = TRUE))
    },
    .bl_ia_put = function(url, path, content_type, headers, timeout) {
      puts[[length(puts) + 1L]] <<- list(url = url, headers = headers, size = file.size(path))
      list(status = 200L, body = raw(), error = "")
    })
  r <- archive_capture(c("https://s.org/a.zip", "https://s.org/t.action?pid=1", "https://s.org/gone"), dir,
                       item = "test-item-2026", metadata = list(title = "T"), access_key = "AK1",
                       secret_key = "SK1")
  expect_identical(r$status, c("uploaded", "uploaded", "failed: bricklayer_fetch: could not reach"))
  expect_identical(r$sha256[1], sha256_file(file.path(dir, "a.zip")))
  expect_identical(r$mirror[1], "https://archive.org/download/test-item-2026/a.zip")
  expect_true(file.exists(file.path(dir, "manifest.tsr")))
  man <- bricklayer_json_from_json(paste(readLines(file.path(dir, "manifest.json")), collapse = "\n"))
  expect_identical(NROW(man$files), 2L)
  # the manifest goes first and creates the item with its metadata; keys only in the header
  expect_match(puts[[1]]$url, "/test-item-2026/manifest.json$")
  expect_true("x-amz-auto-make-bucket:1" %in% puts[[1]]$headers)
  expect_true("x-archive-meta-title:T" %in% puts[[1]]$headers)
  expect_false("x-amz-auto-make-bucket:1" %in% puts[[3]]$headers)
  expect_identical(length(puts), 4L)
  expect_false(any(grepl("SK1", readLines(file.path(dir, "manifest.json")))))
  expect_output(print(r), "imprint and signature verified")
})

test_that("archive_capture() takes the refused URLs of a wayback_save() result", {
  w <- structure(data.frame(url = c("https://s.org/a.zip", "https://s.org/ok", "https://s.org/busy"),
                            status = c("failed", "saved", "failed"),
                            message = c("The target server cannot find https://s.org/a.zip", NA,
                                        "error:too-many-requests"), stringsAsFactors = FALSE),
                 class = c("rmbl_wayback_save", "data.frame"))
  local_mocked_bindings(bricklayer_fetch = .cap_stub(list("https://s.org/a.zip" = charToRaw("A"))))
  r <- archive_capture(w, withr::local_tempdir(), tsa = NULL)
  expect_identical(r$url, "https://s.org/a.zip")
  expect_identical(r$status, "captured")
})

test_that("archive_capture() refuses bad arguments before any request", {
  expect_error(archive_capture(character(), tempdir()), "must be URLs")
  expect_error(archive_capture("https://s.org/a", tempdir(), item = "a b"), "`item` must be")
  expect_error(archive_capture("https://s.org/a", tempdir(), metadata = list(1)), "named list")
  withr::local_envvar(IA_S3_ACCESS_KEY = "", IA_S3_SECRET_KEY = "", IA_S3_ACCESS_KEY_FILE = "",
                      IA_S3_SECRET_KEY_FILE = "")
  expect_error(archive_capture("https://s.org/a", tempdir(), item = "valid-item"), "keys are needed")
})
