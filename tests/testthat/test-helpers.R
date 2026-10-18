# Tests for Unicode-safe text helpers (toascii, asciifb, wrtxtfb).
# Source file kept pure ASCII (CRAN policy): the accented A is a \u escape.

ang <- "\u00c1ngela"  # R parses \u00c1 as accented A; source stays ASCII

test_that("toascii transliterates accents to plain ASCII", {
  res <- toascii(ang)
  expect_false(grepl("[^ -~]", res))      # pure 7-bit ASCII
  expect_equal(res, "Angela")
  expect_equal(toascii(paste("Prof.", ang, "Zorro Medina")),
               "Prof. Angela Zorro Medina")
})

test_that("asciifb preserves valid UTF-8 by default", {
  expect_equal(asciifb(ang), ang)  # accent kept
  expect_equal(asciifb("plain text"), "plain text")
})

test_that("asciifb(force = TRUE) transliterates to ASCII", {
  res <- asciifb(ang, force = TRUE)
  expect_equal(res, "Angela")
  expect_false(grepl("[^ -~]", res))
})

test_that("wrtxtfb writes a readable file for accented input", {
  tmp <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp), add = TRUE)
  wrtxtfb(c("Supervisor:", ang), tmp)
  expect_true(file.exists(tmp))
  expect_gt(file.info(tmp)$size, 0)
})

test_that("agentbndl validates its request and reports a missing binary", {
  Sys.setenv(XDG_CONFIG_HOME = tempfile("xdg-"))
  on.exit(Sys.unsetenv("XDG_CONFIG_HOME"), add = TRUE)
  expect_error(agentbndl(""), "single non-empty string")
  expect_error(agentbndl(c("a", "b")), "single non-empty string")

  expect_match(agentbndl("scaffold demo bundle"), "No language-model route")
})

test_that(".to_ascii_fallback (no-stringi path) transliterates deterministically", {
  # The iconv("ASCII//TRANSLIT") it replaces gave "?" under a C locale;
  # the table-driven fallback must not depend on stringi or the locale.
  expect_equal(rmoriebricklayer:::.to_ascii_fallback(ang), "Angela")
  expect_equal(
    rmoriebricklayer:::.to_ascii_fallback("J\u00fcrgen Stra\u00dfe"),
    "Jurgen Strasse"
  )
  expect_equal(
    rmoriebricklayer:::.to_ascii_fallback("\u0141ukasz \u017bak"),
    "Lukasz Zak"
  )
  out <- rmoriebricklayer:::.to_ascii_fallback("\u0152uvre \u00c6on")
  expect_equal(out, "OEuvre AEon")
  expect_false(any(grepl("[^ -~]", out)))
})
