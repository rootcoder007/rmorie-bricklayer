test_that("Base32 matches the RFC 4648 test vectors", {
  inp <- c("", "f", "fo", "foo", "foob", "fooba", "foobar")
  out <- c("", "MY======", "MZXQ====", "MZXW6===", "MZXW6YQ=", "MZXW6YTB", "MZXW6YTBOI======")
  for (i in seq_along(inp)) expect_identical(.bl_base32(charToRaw(inp[i])), out[i])
})

test_that("SURT keys lower-case, drop www and default ports, sort the query and reverse the host", {
  expect_identical(.bl_surt("https://www.Example.com:443/A/b?z=1&a=2#frag"), "com,example)/a/b?a=2&z=1")
  expect_identical(.bl_surt("https://data.ontario.ca/dataset/x.csv"), "ca,ontario,data)/dataset/x.csv")
  expect_identical(.bl_surt("http://www2.statcan.gc.ca:8080"), "ca,gc,statcan:8080)/")
  expect_identical(.bl_surt("http://user:pw@host.org:80/p"), "org,host)/p")
  # not a URL: kept as it is, lower-cased, as a sort key
  expect_identical(.bl_surt("Not A URL"), "not a url")
})

test_that("record ids are version 4 UUIDs", {
  id <- .bl_uuid()
  expect_match(id, "^<urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}>$")
  expect_false(identical(id, .bl_uuid()))
})

test_that("a capture is written as WARC/1.1 and its CDXJ line points at the response record", {
  d <- withr::local_tempdir()
  payload <- file.path(d, "x.csv")
  writeBin(charToRaw("a,b\n1,2\n"), payload)
  ts <- as.POSIXct("2026-10-21 14:30:05", tz = "UTC")
  warc <- file.path(d, "20261021143005-1a2b3c4d.warc")
  line <- .bl_warc_write(warc, "https://data.ontario.ca/dataset/x.csv", payload, ts, "20261021143005-1a2b3c4d",
                         mime = "text/csv", meta = c(reason = "tables cited in a methods paper"))
  parts <- regmatches(line, regexec("^(\\S+) (\\S+) (.*)$", line))[[1L]]
  expect_identical(parts[2:3], c("ca,ontario,data)/dataset/x.csv", "20261021143005"))
  rec <- fromjs(parts[4L])
  expect_identical(rec$sha256, "492d5ea496056f1a6a6592241032fab764c321596317930b4fa0e1e8bc3b7470")
  expect_identical(rec$digest, "sha256:JEWV5JEWAVXRU2TFSISBAMX2W5SMGIKZMMLZGC2PUDQ6RPB3ORYA====")
  expect_identical(rec$filename, basename(warc))
  # the bytes at offset/length are exactly the response record, and its block is the 70 bytes of
  # the design's example: status line, two headers, blank line, the 8-byte payload
  all <- readBin(warc, "raw", file.size(warc))
  resp <- rawToChar(all[as.integer(rec$offset) + seq_len(as.integer(rec$length))])
  expect_match(resp, "^WARC/1\\.1\r\nWARC-Type: response\r\n")
  expect_match(resp, "\r\nContent-Length: 70\r\n\r\nHTTP/1.1 200 OK\r\n", fixed = FALSE)
  expect_match(resp, "Content-Type: text/csv\r\nContent-Length: 8\r\n\r\na,b\n1,2\n\r\n\r\n$")
  expect_match(resp, "WARC-Payload-Digest: sha256:JEWV5JEWAVXRU2TFSISBAMX2W5SMGIKZMMLZGC2PUDQ6RPB3ORYA====",
               fixed = TRUE)
  txt <- rawToChar(all)
  expect_match(txt, "^WARC/1\\.1\r\nWARC-Type: warcinfo\r\n")
  expect_match(txt, "WARC-Type: metadata\r\n", fixed = TRUE)
  expect_match(txt, "reason: tables cited in a methods paper\r\n", fixed = TRUE)
  expect_match(txt, "file-sha256: 492d5ea4", fixed = TRUE)
  # chunked transfer is never recorded: the body is stored de-chunked with its real length
  line2 <- .bl_warc_write(file.path(d, "b.warc"), "https://h.org/p", payload, ts, "b",
                          headers = c("Transfer-Encoding" = "chunked", "Content-Type" = "text/csv"))
  b <- rawToChar(readBin(file.path(d, "b.warc"), "raw", 1e5))
  expect_false(grepl("Transfer-Encoding: chunked", b, fixed = TRUE))
  expect_match(b, "Content-Type: text/csv\r\nContent-Length: 8\r\n\r\n", fixed = TRUE)
})

test_that("the CDXJ index stays sorted by key and time and keeps one copy of a line", {
  d <- withr::local_tempdir()
  idx <- file.path(d, "index.cdxj")
  .bl_cdxj_add(idx, c("org,b)/ 20260102000000 {}", "org,a)/ 20260101000000 {}"))
  .bl_cdxj_add(idx, c("org,a)/ 20250101000000 {}", "org,b)/ 20260102000000 {}"))
  expect_identical(readLines(idx), c("org,a)/ 20250101000000 {}", "org,a)/ 20260101000000 {}",
                                     "org,b)/ 20260102000000 {}"))
})
