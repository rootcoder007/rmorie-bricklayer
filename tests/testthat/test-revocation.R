# SPDX-License-Identifier: AGPL-3.0-or-later
# Revocation lookups: the input checks and the offline paths.

test_that("rvkfetch() checks its input and makes no request without a URL", {
  expect_error(rvkfetch(list()), "non-empty list of parsed certificates")
  expect_error(rvkfetch(list(list(der = "x"))), "parsed certificates")
  expect_error(rvkfetch(list(list(der = as.raw(1:3))), tmout = 0), "positive")
  r <- rvkfetch(list(list(der = as.raw(1:3))))
  expect_type(r, "list")
})

test_that("a signature algorithm names its digest", {
  expect_identical(.rmbl_ocsp_digest("ecdsa-with-SHA384"), "sha384")
  expect_identical(.rmbl_ocsp_digest("SHA256withRSA"), "sha256")
  expect_identical(.rmbl_ocsp_digest("SHA512withECDSA"), "sha512")
  expect_identical(.rmbl_ocsp_digest("md5WithRSA"), NA_character_)
})
