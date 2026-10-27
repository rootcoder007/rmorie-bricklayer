# SPDX-License-Identifier: AGPL-3.0-or-later
# RFC 3161 timestamp tokens: what tsvrf() and tsinfo() make of bytes that are
# not a token, and the pieces they read a token with.

test_that("bytes that are not a token are a failed check, not an error", {
  r <- tsvrf(as.raw(c(1, 2, 3)), charToRaw("data"))
  expect_s3_class(r, "bricklayer_timestamp")
  expect_false(r$ok)
  expect_identical(r$checks$check[1L], "token_parses")
  expect_true(is.na(r$time))
  expect_output(print(r))
})

test_that("a token or data that is neither bytes nor a file is refused", {
  expect_error(tsvrf(1, "x"), "raw vector or the path to a file")
  expect_error(tsvrf(tempdir(), as.raw(1)), "is a directory")
  expect_error(tsinfo(as.raw(c(1, 2, 3))))
})

test_that("GeneralizedTime is read in UTC, fractions too", {
  t <- .rmbl_ts_gentime("20240102030405Z")
  expect_identical(
    format(t, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    "2024-01-02 03:04:05"
  )
  t2 <- .rmbl_ts_gentime("20240102030405.25Z")
  expect_equal(as.numeric(t2) - as.numeric(t), 0.25, tolerance = 1e-9)
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

test_that("a timestamp check prints as a box", {
  r <- tsvrf(as.raw(c(1, 2, 3)), charToRaw("data"))
  b <- o1_box(r)
  o1_expect_box(
    b,
    r,
    "Timestamp token: NOT verified",
    c("NOT VERIFIED", "token_parses", "<unknown>")
  )
  r2 <- r
  r2$checks <- data.frame(
    check = "certificate_trust",
    ok = FALSE,
    detail = "",
    stringsAsFactors = FALSE
  )
  expect_true(any(grepl("no anchor was given", format(r2), fixed = TRUE)))
})
