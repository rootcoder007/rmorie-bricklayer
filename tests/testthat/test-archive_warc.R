test_that("Base32 matches the RFC 4648 test vectors", {
  inp <- c("", "f", "fo", "foo", "foob", "fooba", "foobar")
  out <- c(
    "",
    "MY======",
    "MZXQ====",
    "MZXW6===",
    "MZXW6YQ=",
    "MZXW6YTB",
    "MZXW6YTBOI======"
  )
  for (i in seq_along(inp)) {
    expect_identical(.bl_base32(charToRaw(inp[i])), out[i])
  }
})

test_that(
  paste0(
    "SURT keys lower-case, drop www and default ports, sort the query and ",
    "reverse the host"
  ),
  {
    expect_identical(
      .bl_surt("https://www.Example.com:443/A/b?z=1&a=2#frag"),
      "com,example)/a/b?a=2&z=1"
    )
    expect_identical(
      .bl_surt("https://data.ontario.ca/dataset/x.csv"),
      "ca,ontario,data)/dataset/x.csv"
    )
    expect_identical(
      .bl_surt("http://www2.statcan.gc.ca:8080"),
      "ca,gc,statcan:8080)/"
    )
    expect_identical(.bl_surt("http://user:pw@host.org:80/p"), "org,host)/p")
    # not a URL: kept as it is, lower-cased, as a sort key
    expect_identical(.bl_surt("Not A URL"), "not a url")
  }
)

test_that("record ids are version 4 UUIDs", {
  id <- .bl_uuid()
  expect_match(
    id,
    paste0(
      "^<urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0",
      "-9a-f]{12}>$"
    )
  )
  expect_false(identical(id, .bl_uuid()))
})

test_that(
  paste0(
    "a capture is written as WARC/1.1 and its CDXJ line points at the ",
    "response record"
  ),
  {
    d <- withr::local_tempdir()
    payload <- file.path(d, "x.csv")
    writeBin(charToRaw("a,b\n1,2\n"), payload)
    ts <- as.POSIXct("2026-10-21 14:30:05", tz = "UTC")
    warc <- file.path(d, "20261021143005-1a2b3c4d.warc")
    line <- .bl_warc_write(
      warc,
      "https://data.ontario.ca/dataset/x.csv",
      payload,
      ts,
      "20261021143005-1a2b3c4d",
      mime = "text/csv",
      meta = c(reason = "tables cited in a methods paper")
    )
    parts <- regmatches(line, regexec("^(\\S+) (\\S+) (.*)$", line))[[1L]]
    expect_identical(
      parts[2:3],
      c("ca,ontario,data)/dataset/x.csv", "20261021143005")
    )
    rec <- fromjs(parts[4L])
    expect_identical(
      rec$sha256,
      "492d5ea496056f1a6a6592241032fab764c321596317930b4fa0e1e8bc3b7470"
    )
    expect_identical(
      rec$digest,
      "sha256:JEWV5JEWAVXRU2TFSISBAMX2W5SMGIKZMMLZGC2PUDQ6RPB3ORYA===="
    )
    expect_identical(rec$filename, basename(warc))
    # the bytes at offset/length are exactly the response record, and its block
    # is the 70 bytes of the design's example: status line, two headers, blank
    # line, the 8-byte payload
    all <- readBin(warc, "raw", file.size(warc))
    resp <- rawToChar(all[
      as.integer(rec$offset) + seq_len(as.integer(rec$length))
    ])
    expect_match(resp, "^WARC/1\\.1\r\nWARC-Type: response\r\n")
    expect_match(
      resp,
      "\r\nContent-Length: 70\r\n\r\nHTTP/1.1 200 OK\r\n",
      fixed = FALSE
    )
    expect_match(
      resp,
      "Content-Type: text/csv\r\nContent-Length: 8\r\n\r\na,b\n1,2\n\r\n\r\n$"
    )
    expect_match(
      resp,
      paste0(
        "WARC-Payload-Digest: ",
        "sha256:JEWV5JEWAVXRU2TFSISBAMX2W5SMGIKZMMLZGC2PUDQ6RPB3ORYA===="
      ),
      fixed = TRUE
    )
    txt <- rawToChar(all)
    expect_match(txt, "^WARC/1\\.1\r\nWARC-Type: warcinfo\r\n")
    expect_match(txt, "WARC-Type: metadata\r\n", fixed = TRUE)
    expect_match(
      txt,
      "reason: tables cited in a methods paper\r\n",
      fixed = TRUE
    )
    expect_match(txt, "file-sha256: 492d5ea4", fixed = TRUE)
    # chunked transfer is never recorded: the body is stored de-chunked with its
    # real length
    line2 <- .bl_warc_write(
      file.path(d, "b.warc"),
      "https://h.org/p",
      payload,
      ts,
      "b",
      headers = c("Transfer-Encoding" = "chunked", "Content-Type" = "text/csv")
    )
    b <- rawToChar(readBin(file.path(d, "b.warc"), "raw", 1e5))
    expect_false(grepl("Transfer-Encoding: chunked", b, fixed = TRUE))
    expect_match(
      b,
      "Content-Type: text/csv\r\nContent-Length: 8\r\n\r\n",
      fixed = TRUE
    )
  }
)

test_that(
  paste0(
    "the CDXJ index stays sorted by key and ",
    "time and keeps one copy of a line"
  ),
  {
    d <- withr::local_tempdir()
    idx <- file.path(d, "index.cdxj")
    .bl_cdxj_add(
      idx,
      c("org,b)/ 20260102000000 {}", "org,a)/ 20260101000000 {}")
    )
    .bl_cdxj_add(
      idx,
      c("org,a)/ 20250101000000 {}", "org,b)/ 20260102000000 {}")
    )
    expect_identical(
      readLines(idx),
      c(
        "org,a)/ 20250101000000 {}",
        "org,a)/ 20260101000000 {}",
        "org,b)/ 20260102000000 {}"
      )
    )
  }
)

test_that("a WARC read back takes only what the file holds", {
  d <- withr::local_tempdir()
  local_mocked_bindings(
    blfetch = function(url, dest, wb = "", tmout = 120L) {
      writeBin(charToRaw("payload"), dest)
      invisible("live")
    }
  )
  arccap("https://s.org/a.csv", d, tsa = NULL)
  out <- file.path(d, "back.csv")
  .bl_warc_get(d, "https://s.org/a.csv", out)
  expect_identical(readLines(out, warn = FALSE), "payload")
  idx <- file.path(d, "indexes", "index.cdxj")
  good <- readLines(idx)
  # an index claiming a record of terabytes is refused before any read
  writeLines(sub('"length": ?"?[0-9]+"?', '"length": 3000000000000', good),
             idx)
  expect_error(.bl_warc_get(d, "https://s.org/a.csv", out),
               "does not match")
  # and one naming a file outside archive/
  writeLines(sub('"filename": ?"[^"]+"', '"filename": "../manifest.json"',
                 good), idx)
  expect_error(.bl_warc_get(d, "https://s.org/a.csv", out),
               "outside archive/")
  writeLines(sub('"filename": ?"[^"]+"', '"filename": ""', good), idx)
  expect_error(.bl_warc_get(d, "https://s.org/a.csv", out),
               "outside archive/")
})

test_that("media types from file names", {
  expect_identical(.bl_mime("x.CSV"), "text/csv")
  expect_identical(
    .bl_mime("a/b/c.parquet"),
    "application/vnd.apache.parquet"
  )
  expect_identical(.bl_mime("noext"), "application/octet-stream")
  expect_identical(.bl_mime("x.weird"), "application/octet-stream")
})

test_that(
  paste0(
    "a capture folder's WARC files are read back exactly, and damage is ",
    "caught"
  ),
  {
    dir <- withr::local_tempdir()
    body <- charToRaw("x,y\n3,4\n")
    local_mocked_bindings(
      blfetch = function(url, dest, wb = "", tmout = 120L) {
        writeBin(body, dest)
        invisible("live")
      }
    )
    arccap("https://s.org/w.csv", dir, tsa = NULL)
    g <- withr::local_tempfile()
    .bl_warc_get(dir, "https://s.org/w.csv", g, csha256(body))
    expect_identical(readBin(g, "raw", 100), body)
    expect_error(
      .bl_warc_get(withr::local_tempdir(), "https://s.org/w.csv", g),
      "has no index"
    )
    expect_error(
      .bl_warc_get(dir, "https://s.org/other.csv", g),
      "no capture of"
    )
    w <- list.files(file.path(dir, "archive"), full.names = TRUE)
    raw <- readBin(w, "raw", file.size(w))
    i <- grepRaw("3,4", raw)
    raw[i] <- charToRaw("9")
    writeBin(raw, w)
    expect_error(
      .bl_warc_get(dir, "https://s.org/w.csv", g),
      "does not match its index"
    )
    writeBin(charToRaw("WARC/1.1\r\nno blank line"), w)
    idx <- file.path(dir, "indexes", "index.cdxj")
    l <- readLines(idx)
    writeLines(
      sub(
        '"offset":"[0-9]+"',
        '"offset":"0"',
        sub('"length":"[0-9]+"', '"length":"23"', l)
      ),
      idx
    )
    expect_error(
      .bl_warc_get(dir, "https://s.org/w.csv", g),
      "damaged WARC record"
    )
  }
)

test_that("the reason given to arccap() is written into each WARC file", {
  d <- withr::local_tempdir()
  local_mocked_bindings(
    blfetch = function(url, dest, wb = "", tmout = 120L) {
      writeBin(charToRaw("x,y\n1,2\n"), dest)
      invisible("live")
    }
  )
  cap <- arccap(
    "https://s.org/r.csv",
    d,
    tsa = NULL,
    reason = "Cited in chapter 3\nof the thesis"
  )
  w <- readBin(cap$warc, "raw", file.size(cap$warc))
  expect_length(grepRaw("reason: Cited in chapter 3 of the thesis", w), 1L)
})
