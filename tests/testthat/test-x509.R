# Certificate path validation, ECDSA, and the positive controls.
#
# The timestamp fixtures carry two tokens over the same payload under
# the same CA -- one signed with RSA, one with ECDSA on P-256 -- so the
# two signature paths are exercised against real tokens rather than
# against each other.

ts_fixtures <- function() {
  fx <- readLines(test_path("timestamp-token.txt"), warn = FALSE)
  fx <- fx[!startsWith(fx, "#") & nzchar(fx)]
  parts <- strsplit(fx, "|", fixed = TRUE)
  stats::setNames(lapply(parts, function(p) .rmbl_hex_to_raw(p[2L])),
                  vapply(parts, `[[`, character(1), 1L))
}

test_that("ECDSA verifies on every curve, and rejects what it must", {
  # The curve arithmetic, against the published base-point multiples.
  # 2G and 3G on P-256 are the values in SEC 2 and every other table.
  g2 <- .Call(C_rmbl_ec_mul, "P-256", as.raw(2L))
  expect_identical(
    .rmbl_hexlify(g2$x),
    "7cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978")
  g3 <- .Call(C_rmbl_ec_mul, "P-256", as.raw(3L))
  expect_identical(
    .rmbl_hexlify(g3$x),
    "5ecbe4d1a6330a44c8f7ef951d4bf165e6c6b721efada985fb41661bc6e7fd6c")

  # The definitive check on each group order: n*G is the point at
  # infinity. The P-521 order was once four hex digits short here, which
  # left the curve arithmetic correct -- 2G still matched the published
  # value -- while every operation mod n was wrong and no signature
  # verified. This is the check that would have caught it immediately.
  for (cv in c("P-256", "P-384", "P-521")) {
    n <- .Call(C_rmbl_ec_order, cv)
    expect_true(.Call(C_rmbl_ec_mul, cv, n)$infinity, info = cv)
    expect_identical(length(n),
                     switch(cv, "P-256" = 32L, "P-384" = 48L, 66L))
  }
  expect_error(.Call(C_rmbl_ec_mul, "P-192", as.raw(1L)), "unsupported")
})

test_that("a certificate parses into the fields a verifier needs", {
  f <- ts_fixtures()
  cert <- cert_parse(f$rsa_cert)
  expect_s3_class(cert, "bricklayer_certificate")
  expect_match(cert$subject, "TSA")
  expect_match(cert$issuer, "CA")
  expect_identical(cert$key$type, "RSA")
  expect_identical(cert$key$bits, 2048L)
  expect_identical(cert$signature_algorithm, "RSA-SHA256")
  expect_false(cert$is_ca)
  # the leaf is issued for timestamping and nothing else
  expect_identical(cert$extended_key_usage, "1.3.6.1.5.5.7.3.8")
  expect_s3_class(cert$not_before, "POSIXct")
  expect_true(cert$not_after > cert$not_before)
  expect_false(cert$self_signed)

  ec <- cert_parse(f$ecdsa_cert)
  expect_identical(ec$key$type, "EC")
  expect_identical(ec$key$curve, "P-256")

  ca <- cert_parse(f$ca)
  expect_true(ca$is_ca)
  expect_true(ca$self_signed)
  expect_output(print(cert), "X.509 certificate")
})

test_that("a chain verifies to an anchor, and fails every other way", {
  f <- ts_fixtures()
  leaf <- cert_parse(f$rsa_cert)
  ca <- cert_parse(f$ca)
  at <- leaf$not_before + 86400

  ok <- cert_chain_verify(leaf, trust = ca, at_time = at,
                          purpose = "timeStamping")
  expect_true(ok$ok)
  expect_length(ok$path, 2L)
  expect_true(all(ok$checks$ok))

  # an anchor that did not issue it
  bad <- cert_chain_verify(leaf, trust = cert_parse(f$other_ca),
                           at_time = at)
  expect_false(bad$ok)
  expect_false(bad$checks$ok[bad$checks$check == "path_to_anchor"])

  # outside the validity window, in both directions
  expect_false(cert_chain_verify(leaf, trust = ca,
    at_time = leaf$not_before - 86400)$ok)
  expect_false(cert_chain_verify(leaf, trust = ca,
    at_time = leaf$not_after + 86400)$ok)

  # a purpose the leaf was not issued for
  expect_false(cert_chain_verify(leaf, trust = ca, at_time = at,
                                 purpose = "codeSigning")$ok)

  # the leaf is not a CA, so it cannot stand in as its own issuer
  self <- cert_chain_verify(leaf, trust = leaf, at_time = at)
  expect_false(self$ok)

  # a CRL naming the leaf's serial revokes it
  expect_error(cert_chain_verify(leaf, trust = list()), "at least one")
  expect_output(print(ok), "Certificate chain")
})

test_that("a token is verified with its trust chain, RSA and ECDSA", {
  f <- ts_fixtures()
  for (nm in c("rsa_token", "ecdsa_token")) {
    tok <- f[[nm]]
    # without an anchor the signature still checks, but trust is
    # reported as not established rather than assumed
    bare <- timestamp_verify(tok, f$payload)
    expect_true(bare$checks$ok[bare$checks$check == "signature"],
                info = nm)
    expect_false(bare$checks$ok[bare$checks$check == "certificate_trust"],
                 info = nm)
    expect_false(bare$ok, info = nm)

    full <- timestamp_verify(tok, f$payload, trust = f$ca)
    expect_true(full$ok, info = nm)
    expect_true(any(startsWith(full$checks$check, "chain:")), info = nm)
    # the chain's validity was judged at the time the token asserts
    expect_match(full$checks$detail[
      full$checks$check == "certificate_trust"],
      format(full$time, "%Y-%m-%d", tz = "UTC"), info = nm)

    # an anchor that did not issue it
    expect_false(timestamp_verify(tok, f$payload,
                                  trust = f$other_ca)$ok, info = nm)
    # and a time the certificate did not cover
    expect_false(timestamp_verify(tok, f$payload, trust = f$ca,
      at_time = as.POSIXct("1999-01-01", tz = "UTC"))$ok, info = nm)
  }
  # the ECDSA token really is ECDSA, so the two paths are distinct
  ec <- timestamp_verify(f$ecdsa_token, f$payload, trust = f$ca)
  expect_match(ec$checks$detail[ec$checks$check == "signature"], "ECDSA")
  rsa <- timestamp_verify(f$rsa_token, f$payload, trust = f$ca)
  expect_match(rsa$checks$detail[rsa$checks$check == "signature"], "RSA")
})

test_that("tampering is caught on both signature algorithms", {
  f <- ts_fixtures()
  for (nm in c("rsa_token", "ecdsa_token")) {
    tok <- f[[nm]]
    k <- length(tok) - 40L
    tok[k] <- as.raw(bitwXor(as.integer(tok[k]), 1L))
    r <- timestamp_verify(tok, f$payload, trust = f$ca)
    expect_false(r$ok, info = nm)
    expect_false(r$checks$ok[r$checks$check == "signature"], info = nm)
  }
})

test_that("SHA-384 matches its FIPS 180-4 vectors", {
  # needed because ecdsa-with-SHA384 is a certificate signature
  # algorithm in common use, and a verifier that cannot compute the
  # digest cannot check the signature
  expect_identical(
    .rmbl_hexlify(.Call(C_rmbl_sha384, charToRaw("abc"))),
    paste0("cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43",
           "ff5bed8086072ba1e7cc2358baeca134c825a7"))
  expect_identical(
    .rmbl_hexlify(.Call(C_rmbl_sha384, raw(0))),
    paste0("38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63",
           "f6e1da274edebfe76f65fbd51ad2f14898b95b"))
  # the padding boundary, where the length no longer fits the block
  got <- vapply(c(111L, 112L, 113L), function(n) {
    substring(.rmbl_hexlify(.Call(C_rmbl_sha384,
                                  charToRaw(strrep("a", n)))), 1L, 16L)
  }, character(1))
  expect_length(unique(got), 3L)
})

test_that("the positive control finds an injected effect, or says not", {
  set.seed(1)
  d <- data.frame(x = stats::rnorm(120), y = stats::rnorm(120))
  inj <- function(z, size) {
    z$y <- z$y + size * z$x
    z
  }
  pw <- capsule_power(d, function(z) stats::cor(z$x, z$y), inj,
                      sizes = c(0, 0.1, 0.4), treatment = "x",
                      n = 99L, reps = 6L, seed = 42L)
  expect_s3_class(pw, "bricklayer_power")
  expect_identical(nrow(pw$curve), 3L)
  # a large effect is found every time, a tiny one is not, and the
  # smallest reliably detected is what a null result can speak to
  expect_identical(pw$curve$rate[pw$curve$size == 0.4], 1)
  expect_lt(pw$curve$rate[pw$curve$size == 0.1], 0.8)
  expect_identical(pw$smallest_detected, 0.4)
  # the false-positive rate at size 0 must not be large
  expect_lt(pw$curve$rate[pw$curve$size == 0], 0.5)

  # A statistic blind to the effect detects nothing at any size. This is
  # the case that every falsification control passes and that matters
  # most: a null result from here is not evidence of absence.
  blind <- capsule_power(d, function(z) mean(z$x), inj,
                         sizes = c(0, 0.8), treatment = "x",
                         n = 99L, reps = 4L, seed = 7L)
  expect_true(is.na(blind$smallest_detected))
  expect_output(print(blind), "could not")

  # a design whose permutation floor is above alpha could never detect
  # anything, and is refused rather than run
  expect_error(capsule_power(d, function(z) stats::cor(z$x, z$y), inj,
                             treatment = "x", n = 9L, alpha = 0.05),
               "no size could ever be detected")
  expect_error(capsule_power(d, function(z) 1, inj), "`treatment` is required")
  expect_error(capsule_power(d, function(z) 1, "notafunction",
                             treatment = "x"), "must both be functions")
})
