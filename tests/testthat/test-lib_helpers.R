# SPDX-License-Identifier: AGPL-3.0-or-later

# The file digest, the ASCII fallbacks for text and the URL gate.

test_that("sha256file() hashes a file and refuses what is not one", {
  f <- withr::local_tempfile()
  writeBin(charToRaw("abc"), f)
  expect_identical(
    sha256file(f),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  e <- withr::local_tempfile()
  file.create(e)
  expect_identical(
    sha256file(e),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  )
  expect_error(sha256file(tempdir()), "is not a file")
  expect_error(sha256file(file.path(tempdir(), "no-such-file")), "not a file")
  expect_error(sha256file(c("a", "b")), "sha256file: `path` is not a file")
  expect_error(sha256file(NA_character_), "is not a file")
  expect_error(sha256file(1), "sha256file: `path` is not a file")
})

test_that("toascii() folds accents and drops what has no ASCII form", {
  expect_identical(toascii("Angéla"), "Angela")
  expect_identical(toascii(c("a", NA)), c("a", ""))
  expect_true(all(validUTF8(toascii("ßæ"))))
  # the base-R fallback, without stringi, gives the same answers on Latin
  expect_identical(
    .to_ascii_fallback(c("École", "Straße", "Œuvre")),
    c("Ecole", "Strasse", "OEuvre")
  )
  tab <- .to_ascii_table()
  expect_identical(nchar(tab$from), nchar(tab$to))
})

test_that("asciifb() keeps valid text and folds only broken bytes", {
  expect_identical(asciifb("Angéla"), "Angéla")
  expect_identical(asciifb("Angéla", force = TRUE), "Angela")
  bad <- rawToChar(as.raw(c(0x61, 0xff, 0x62)))
  expect_identical(asciifb(c("ok", bad)), c("ok", "ab"))
})

test_that("wrtxtfb() writes the text as UTF-8 lines", {
  f <- withr::local_tempfile(fileext = ".txt")
  expect_identical(wrtxtfb(c("one", "Angéla"), f), f)
  expect_identical(
    readBin(f, "raw", 100),
    charToRaw(enc2utf8("one\nAngéla\n"))
  )
})

test_that("the URL gate admits https and refuses local or plain addresses", {
  expect_identical(
    .rmbl_check_public_url("https://example.org/a"),
    "https://example.org/a"
  )
  expect_error(.rmbl_check_public_url(""), "url is empty")
  expect_error(.rmbl_check_public_url("example.org"), "has no URL scheme")
  expect_error(
    .rmbl_check_public_url("http://example.org/", allow_http = FALSE),
    "must be an https:// URL, not http://"
  )
  expect_error(
    .rmbl_check_public_url("https://127.0.0.1/", what = "src"),
    "src points at a local or private address"
  )
  expect_identical(
    .rmbl_check_public_url("file:///tmp/x", allow_file = TRUE),
    "file:///tmp/x"
  )
})

test_that("the base-R URL check stands in for the C validator", {
  why <- function(u) .rmbl_url_why_base(u, FALSE, FALSE)
  expect_identical(why("https://example.org/x"), "")
  expect_identical(why("ftp://example.org/"), "scheme ftp is not allowed")
  expect_identical(why("http://example.org/"), "plain http is not allowed")
  expect_identical(
    .rmbl_url_why_base("http://localhost:8080/", FALSE, TRUE),
    ""
  )
  expect_identical(why("https://10.1.2.3/"), "a local or private address")
  expect_identical(why("https://192.168.0.1/"), "a local or private address")
  expect_identical(why("https://8.8.8.8/"), "")
  expect_identical(why("https://2130706433/"), "a local or private address")
  expect_identical(why("https://[::1]/"), "a local or private address")
  expect_identical(why("https://intranet/"), "a single-label host")
  expect_identical(why("https://printer.local/"), "a local name")
  expect_true(.rmbl_private_v4("172.20.0.1"))
  expect_false(.rmbl_private_v4("172.32.0.1"))
  expect_identical(.rmbl_host_why("example.org", FALSE), "")
})

test_that("the streamed SHA-256 refuses a directory by name", {
  d <- withr::local_tempdir()
  expect_error(.rmbl_sha256_stream(d), "is a directory, not a file")
})
