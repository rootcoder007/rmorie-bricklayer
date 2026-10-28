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

test_that("an OCSP answer must be about this certificate, and current", {
  f <- x509_fx()
  leaf <- certprs(f$ocsp_good)
  ca <- certprs(f$ocsp_ca)
  revoked <- certprs(f$ocsp_revoked)
  path <- list(leaf, ca)
  at <- as.POSIXct("2026-10-10", tz = "UTC")
  # a signed "good" for another certificate of the same CA says nothing
  # about a revoked one
  r <- .rmbl_ocsp_parse(f$ocsp_resp_good, revoked, list(revoked, ca), at)
  expect_false(r$ok)
  expect_identical(r$detail, "the answer is about another certificate")
  r <- .rmbl_ocsp_parse(f$ocsp_resp_revoked, leaf, path, at)
  expect_identical(r$detail, "the answer is about another certificate")
  # nor with no issuer in the path to name it by
  r <- .rmbl_ocsp_parse(f$ocsp_resp_good, leaf, list(leaf), at)
  expect_false(r$ok)
  expect_match(r$detail, "no certificate in the path issued it")
  # an answer past its nextUpdate, or dated after the time checked
  late <- as.POSIXct("2026-12-01", tz = "UTC")
  r <- .rmbl_ocsp_parse(f$ocsp_resp_good, leaf, path, late)
  expect_false(r$ok)
  expect_identical(r$detail,
                   "the answer is stale: it held until 2026-11-05 05:23 UTC")
  early <- as.POSIXct("2026-09-01", tz = "UTC")
  r <- .rmbl_ocsp_parse(f$ocsp_resp_good, leaf, path, early)
  expect_identical(
    r$detail, "the answer is dated 2026-10-06 05:23 UTC, after the time checked"
  )
  expect_true(.rmbl_ocsp_parse(f$ocsp_resp_good, leaf, path, at)$ok)
})

test_that("only the issuer or a responder it delegated to signs for it", {
  f <- x509_fx()
  leaf <- certprs(f$ocsp_good)
  ca <- certprs(f$ocsp_ca)
  at <- as.POSIXct("2026-10-10", tz = "UTC")
  b <- .rmbl_ocsp_basic(.Call(C_rmbl_der_parse, f$ocsp_resp_good_delegated))
  # the responder's certificate travels in the answer: the CA signed it
  expect_true(.rmbl_ocsp_verify_sig(b$basic, list(ca), b$src, at)$ok)
  # an embedded certificate another CA issued is nobody's delegate here
  other <- certprs(f$ocsp_ecca)
  expect_false(.rmbl_ocsp_verify_sig(b$basic, list(other), b$src, at)$ok)
  # without id-kp-OCSPSigning, or outside its validity, it is not one either
  real <- certprs
  testthat::with_mocked_bindings(
    certprs = function(x) {
      p <- real(x)
      p$extended_key_usage <- character(0)
      p
    },
    expect_false(.rmbl_ocsp_verify_sig(b$basic, list(ca), b$src, at)$ok)
  )
  expect_false(.rmbl_ocsp_verify_sig(
    b$basic, list(ca), b$src, as.POSIXct("2040-01-01", tz = "UTC")
  )$ok)
  expect_true(.rmbl_ocsp_parse(f$ocsp_resp_good_delegated, leaf,
                               list(leaf, ca), at)$ok)
})

test_that("responseBytes are read where RFC 6960 puts them", {
  f <- x509_fx()
  leaf <- certprs(f$ocsp_good)
  ca <- certprs(f$ocsp_ca)
  at <- as.POSIXct("2026-10-10", tz = "UTC")
  d <- .Call(C_rmbl_der_parse, f$ocsp_resp_good)
  inner <- .rmbl_ocsp_basic(d)$src
  # the same BasicOCSPResponse under another response type, or loose in the
  # answer, is not read
  typed <- .rmbl_der_seq(
    .rmbl_der_tlv(0x0a, as.raw(0)),
    .rmbl_der_tlv(0xa0, .rmbl_der_seq(.rmbl_der_oid_bytes("1.2.3.4"),
                                      .rmbl_der_tlv(0x04, inner)))
  )
  expect_identical(.rmbl_ocsp_parse(typed, leaf, list(leaf, ca), at)$detail,
                   "no BasicOCSPResponse in the answer")
  loose <- .rmbl_der_seq(.rmbl_der_tlv(0x0a, as.raw(0)),
                         .rmbl_der_tlv(0x04, inner))
  expect_identical(.rmbl_ocsp_parse(loose, leaf, list(leaf, ca), at)$detail,
                   "the answer carries no response bytes")
})

test_that("a CRL counts only when its CA signed it and it is current", {
  f <- x509_fx()
  ca <- certprs(f$nc_ca)
  leaf <- certprs(f$nc_leaf_good)
  at <- ca$not_before + 86400
  path <- list(leaf, ca)
  ok <- .rmbl_crl_check(path, list(f$nc_crl), at)
  # the root issued itself, so its CRL covers both
  expect_identical(ok$check, c("revocation [1]", "revocation [2]"))
  expect_identical(ok$ok, c(FALSE, TRUE))
  expect_match(ok$detail[1], "is on a CRL")
  # the same CRL with its signature altered: refused, not pooled
  bad <- f$nc_crl
  bad[length(bad)] <- xor(bad[length(bad)], as.raw(1))
  r <- .rmbl_crl_check(path, list(bad), at)
  expect_identical(r$check, "crl [1]")
  expect_false(r$ok)
  expect_identical(r$detail,
                   "its signature does not verify under the CA that issued it")
  # an empty CRL from another CA says nothing about this path: before, it
  # passed every certificate
  other <- .rmbl_crl_check(path, list(f$ocsp_crl_der), at)
  expect_false(any(other$ok))
  expect_match(other$detail, "no CA in the path issued this CRL")
  # a CRL whose nextUpdate has passed
  late <- .rmbl_crl_check(path, list(f$nc_crl), at + 365 * 86400)
  expect_false(late$ok)
  expect_match(late$detail, "^it is stale: it held until ")
  # and through certchnvrf(): a forged CRL fails the check
  r <- certchnvrf(f$nc_leaf_good, trust = ca, attm = at, crls = list(bad))
  expect_false(r$ok)
  expect_true(any(r$checks$check == "crl [1]"))
})
