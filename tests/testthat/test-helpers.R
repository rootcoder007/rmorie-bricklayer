# Tests for Unicode-safe text helpers (to_ascii, ascii_fallback, write_text_fallback).
# Source file kept pure ASCII (CRAN policy): the accented A is a \u escape.

ang <- "\u00c1ngela"  # R parses \u00c1 as accented A; source stays ASCII

test_that("to_ascii transliterates accents to plain ASCII", {
  res <- to_ascii(ang)
  expect_false(grepl("[^ -~]", res))      # pure 7-bit ASCII
  expect_equal(res, "Angela")
  expect_equal(to_ascii(paste("Prof.", ang, "Zorro Medina")),
               "Prof. Angela Zorro Medina")
})

test_that("ascii_fallback preserves valid UTF-8 by default", {
  expect_equal(ascii_fallback(ang), ang)  # accent kept
  expect_equal(ascii_fallback("plain text"), "plain text")
})

test_that("ascii_fallback(force = TRUE) transliterates to ASCII", {
  res <- ascii_fallback(ang, force = TRUE)
  expect_equal(res, "Angela")
  expect_false(grepl("[^ -~]", res))
})

test_that("write_text_fallback writes a readable file for accented input", {
  tmp <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp), add = TRUE)
  write_text_fallback(c("Supervisor:", ang), tmp)
  expect_true(file.exists(tmp))
  expect_gt(file.info(tmp)$size, 0)
})
