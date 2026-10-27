# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("csha256 matches the FIPS 180-4 standard vectors", {
  # Canonical test vectors -- if these break, the C SHA-256 is wrong.
  expect_identical(
    csha256(""),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  )
  expect_identical(
    csha256("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  expect_identical(
    csha256("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
  )
})

test_that("csha256 hashes raw the same as the equivalent string", {
  expect_identical(csha256(charToRaw("abc")), csha256("abc"))
})

test_that("csha256 is vectorised over character and cross-checks digest", {
  expect_identical(csha256(c("abc", "")), c(csha256("abc"), csha256("")))
  skip_if_not_installed("digest")
  expect_identical(
    csha256("provenance"),
    digest::digest("provenance", algo = "sha256", serialize = FALSE)
  )
})

test_that("core stats match base R", {
  x <- c(2, 4, 4, 4, 5, 5, 7, 9)
  y <- (seq_along(x))^2
  expect_identical(cmn(x), mean(x))
  expect_identical(cvari(x), var(x))
  expect_identical(ccorr(x, y), cor(x, y))
  expect_equal(
    cnormpdf(c(-1, 0, 1, 2.5), mean = 0.3, sd = 1.7),
    dnorm(c(-1, 0, 1, 2.5), mean = 0.3, sd = 1.7),
    tolerance = testthat::testthat_tolerance()
  )
})

test_that("core stats handle degenerate input the way R's contract implies", {
  expect_true(is.nan(cvari(1))) # sample variance needs n >= 2
  expect_true(is.nan(ccorr(c(1, 1, 1), c(2, 3, 4)))) # zero variance
  # sd must be > 0: refused, not a silent NaN
  expect_error(cnormpdf(0, sd = 0), "positive")
})

test_that("csha256 handles multi-block input (FIPS 180-4 two-block vector)", {
  expect_identical(
    csha256(paste0(
      "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn",
      "hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
    )),
    "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1"
  )
})

test_that("ccorr rejects length-mismatched input", {
  expect_error(ccorr(1:3, 1:4), "same length")
})
