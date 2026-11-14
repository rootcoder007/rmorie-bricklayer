# SPDX-License-Identifier: AGPL-3.0-or-later

# Compressed JSON: a real gzip member (RFC 1952), base64 around it, and the
# checks the decoder makes before it inflates anything.

test_that("jsgzenc() writes a gzip member that jsgzdec() reads back", {
  x <- list(a = 1L, b = "two", c = list(d = TRUE))
  g <- jsgzenc(x)
  expect_type(g, "character")
  expect_identical(jsgzdec(g), fromjs(tojs(x)))
  r <- jsgzenc(x, raw = TRUE)
  expect_type(r, "raw")
  # the gzip magic, deflate, and MTIME zero so the bytes never depend on the
  # clock
  expect_identical(r[1:4], as.raw(c(0x1f, 0x8b, 0x08, 0x00)))
  expect_identical(r[5:8], as.raw(c(0, 0, 0, 0)))
  expect_identical(jsgzenc(x, raw = TRUE), r)
  # raw input is read as the member itself, flag or no flag
  expect_identical(jsgzdec(r), jsgzdec(g))
  expect_identical(jsgzdec(r, raw = TRUE), jsgzdec(g))
  # base R reads it as gzip too
  expect_identical(
    rawToChar(memDecompress(r, type = "gzip")),
    as.character(tojs(x))
  )
})

test_that("the gzip trailer carries the CRC-32 and length of the input", {
  bytes <- charToRaw(strrep("abc", 50))
  m <- .rmbl_gzip_member(bytes)
  n <- length(m)
  le <- function(b) sum(as.numeric(as.integer(b)) * 256^(0:3))
  expect_identical(le(m[(n - 3L):n]), 150)
  expect_identical(le(m[(n - 7L):(n - 4L)]), as.numeric(ccrc32(bytes)))
})

test_that("jsgzdec() refuses what is not one small gzip member", {
  expect_error(
    jsgzdec(as.raw(1:5)),
    "does not hold a gzip member: expected at least 18 bytes"
  )
  expect_error(jsgzdec(as.raw(rep(0, 20))), "starting 1f 8b, got 20 byte")
  expect_error(jsgzdec("abc", raw = TRUE), "must be a raw vector")
  # a trailer that declares a length its data does not have is damage (it
  # was called an oversized member from the trailer alone)
  r <- jsgzenc(list(a = 1), raw = TRUE)
  n <- length(r)
  r[(n - 3L):n] <- as.raw(c(0, 0, 0, 0x10))
  expect_error(jsgzdec(r), "jsgzdec: `txt` has a length trailer that does")
  # a member that does hold more than 64 MiB is refused at the limit
  big <- .rmbl_gzip_member(raw(65 * 1024^2))
  expect_error(jsgzdec(big), "refusing to inflate more than 64 MiB")
  # a truncated member, and bytes after the member
  ok <- jsgzenc(list(a = 1:50), raw = TRUE)
  expect_error(jsgzdec(ok[1:20]), "jsgzdec: `txt` is truncated")
  expect_error(jsgzdec(c(ok, charToRaw("JUNK"))), "bytes after the end")
})

test_that("jsgzenc and jsgzdec check raw and take one string", {
  expect_error(jsgzenc(1, raw = "yes"), "jsgzenc: `raw` must be TRUE or FALSE")
  expect_error(jsgzdec("x", raw = NA), "jsgzdec: `raw` must be TRUE or FALSE")
  g <- jsgzenc(list(a = 1))
  expect_error(jsgzdec(c(g, g)), "jsgzdec: `txt` must be a single string")
  expect_identical(jsgzdec(g), list(a = 1L))
})
