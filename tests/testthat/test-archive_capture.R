# arccap(): capture from here, timestamp the manifest, upload to an archive.org
# item

test_that("the RFC 3161 request is the DER a time-stamping authority expects", {
  d <- as.raw(0:31)
  q <- .bl_tsq(d, as.raw(1:8))
  hdr <- as.raw(c(
    0x30,
    0x43,
    0x02,
    0x01,
    0x01,
    0x30,
    0x31,
    0x30,
    0x0d,
    0x06,
    0x09,
    0x60,
    0x86,
    0x48,
    0x01,
    0x65,
    0x03,
    0x04,
    0x02,
    0x01,
    0x05,
    0x00,
    0x04,
    0x20
  ))
  expect_identical(
    q,
    c(hdr, d, as.raw(c(0x02, 0x08)), as.raw(1:8), as.raw(c(0x01, 0x01, 0xff)))
  )
  expect_identical(.bl_der(0x04, raw(200))[1:3], as.raw(c(0x04, 0x81, 200)))
  expect_identical(
    .bl_der(0x04, raw(300))[1:4],
    as.raw(c(0x04, 0x82, 0x01, 0x2c))
  )
  expect_identical(.bl_hex_raw("00ff10"), as.raw(c(0, 255, 16)))
})

test_that("capture names are safe and unique", {
  expect_identical(
    .bl_capture_name("https://x.org/n1/tbl/csv/41100063-eng.zip"),
    "41100063-eng.zip"
  )
  a <- .bl_capture_name("https://x.org/t1/tbl1/en/tv.action?pid=1")
  b <- .bl_capture_name("https://x.org/t1/tbl1/en/tv.action?pid=2")
  expect_false(identical(a, b))
  expect_match(a, "^tv_[0-9a-f]{10}\\.action$")
  expect_identical(.bl_capture_name("https://x.org/"), "index")
})

.cap_stub <- function(serve) {
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

test_that(
  paste0(
    "arccap() captures, timestamps and ",
    "uploads, keys only in the header"
  ),
  {
    dir <- withr::local_tempdir()
    rec <- new.env()
    rec$puts <- list()
    local_mocked_bindings(
      blfetch = .cap_stub(list(
        "https://s.org/a.zip" = charToRaw("AAA"),
        "https://s.org/t.action?pid=1" = charToRaw("<html>")
      )),
      .bl_tsa_post = function(url, body, timeout) {
        list(status = 200L, body = charToRaw("tsr"), error = "")
      },
      tsvrf = function(token, data, ...) {
        list(
          ok = FALSE,
          time = as.POSIXct("2026-10-18", tz = "UTC"),
          checks = data.frame(
            check = c(
              "token_structure", "message_imprint", "signature",
              "attribute_digest", "certificate_trust"
            ),
            ok = c(TRUE, TRUE, TRUE, TRUE, FALSE),
            stringsAsFactors = FALSE
          )
        )
      },
      .bl_ia_put = function(url, path, content_type, headers, timeout) {
        rec$puts[[length(rec$puts) + 1L]] <- list(
          url = url,
          headers = headers,
          size = file.size(path)
        )
        list(status = 200L, body = raw(), error = "")
      }
    )
    r <- arccap(
      c(
        "https://s.org/a.zip",
        "https://s.org/t.action?pid=1",
        "https://s.org/gone"
      ),
      dir,
      item = "test-item-2026",
      meta = list(title = "T"),
      ak = "AK1",
      sk = "SK1"
    )
    expect_identical(
      r$status,
      c("uploaded", "uploaded", "failed: blfetch: could not reach")
    )
    expect_identical(r$sha256[1], sha256file(file.path(dir, "a.zip")))
    expect_identical(
      r$mirror[1],
      "https://archive.org/download/test-item-2026/a.zip"
    )
    expect_true(file.exists(file.path(dir, "manifest.tsr")))
    man <- fromjs(paste(
      readLines(file.path(dir, "manifest.json")),
      collapse = "\n"
    ))
    expect_identical(NROW(man$files), 2L)
    # the manifest goes first and creates the item with its metadata; keys only
    # in the header
    expect_match(rec$puts[[1]]$url, "/test-item-2026/manifest.json$")
    expect_true("x-amz-auto-make-bucket:1" %in% rec$puts[[1]]$headers)
    expect_true("x-archive-meta-title:T" %in% rec$puts[[1]]$headers)
    expect_false("x-amz-auto-make-bucket:1" %in% rec$puts[[3]]$headers)
    expect_length(rec$puts, 4L)
    expect_false(any(grepl(
      "SK1",
      readLines(file.path(dir, "manifest.json")),
      fixed = TRUE
    )))
    expect_output(print(r), "imprint and signature verified")
  }
)

test_that("arccap() takes the refused URLs of a wbsave() result", {
  w <- structure(
    data.frame(
      url = c("https://s.org/a.zip", "https://s.org/ok", "https://s.org/busy"),
      status = c("failed", "saved", "failed"),
      message = c(
        "The target server cannot find https://s.org/a.zip",
        NA,
        "error:too-many-requests"
      ),
      stringsAsFactors = FALSE
    ),
    class = c("rmbl_wayback_save", "data.frame")
  )
  local_mocked_bindings(
    blfetch = .cap_stub(list("https://s.org/a.zip" = charToRaw("A")))
  )
  r <- arccap(w, withr::local_tempdir(), tsa = NULL)
  expect_identical(r$url, "https://s.org/a.zip")
  expect_identical(r$status, "captured")
})

test_that("arccap() refuses bad arguments before any request", {
  expect_error(arccap(character(), tempdir()), "must be URLs")
  expect_error(
    arccap("https://s.org/a", tempdir(), item = "a b"),
    "`item` must be"
  )
  expect_error(
    arccap("https://s.org/a", tempdir(), meta = list(1)),
    "named list"
  )
  withr::local_envvar(
    IA_S3_ACCESS_KEY = "",
    IA_S3_SECRET_KEY = "",
    IA_S3_ACCESS_KEY_FILE = "",
    IA_S3_SECRET_KEY_FILE = ""
  )
  expect_error(
    arccap("https://s.org/a", tempdir(), item = "valid-item"),
    "keys are needed"
  )
})

# Prints `x` on an ASCII console: the lines and what print() returned.
o1_box <- function(x, ...) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  tmp <- withr::local_tempfile()
  v <- withr::with_output_sink(tmp, withVisible(print(x, ...)))
  list(out = readLines(tmp), v = v)
}

# The box's frame, its title and the facts expected in it.
o1_expect_box <- function(b, x, title, facts = character()) {
  expect_false(b$v$visible)
  expect_identical(b$v$value, x)
  expect_match(b$out[1L], "^\\+-- ")
  expect_true(grepl(title, b$out[1L], fixed = TRUE))
  expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  for (f in facts) {
    expect_true(any(grepl(f, b$out, fixed = TRUE)), info = f)
  }
}

test_that("a capture result prints as a box", {
  x <- data.frame(
    url = c("https://s.org/a", "https://s.org/b"),
    file = c("a", "b"),
    bytes = c(10, NA),
    status = c("captured", "failed: 404"),
    archive = c("https://archive.rmorie.com/c/1", NA),
    stringsAsFactors = FALSE
  )
  class(x) <- c("rmbl_archive_capture", "data.frame")
  attr(x, "item") <- "demo-item"
  b <- o1_box(x)
  o1_expect_box(
    b,
    x,
    "Archive capture",
    c("1 of 2 URLs", "demo-item", "1 saved", "1 failed")
  )
  expect_null(.bl_cap_ts_text(NULL))
})

test_that("a capture table without its status column prints plainly", {
  expect_plain_df("rmbl_archive_capture")
})
