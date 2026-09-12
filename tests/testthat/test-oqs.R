# The standardised post-quantum schemes, via liboqs.
#
# These tests skip entirely where the build did not find liboqs, which
# is the normal case on CRAN. Where it did, the scheme is liboqs's own
# implementation -- bricklayer contributes no lattice arithmetic -- so
# what is tested here is the BINDING: that the key sizes are the ones
# FIPS 204 specifies, that a genuine signature verifies, and that every
# way of tampering fails.

skip_if_no_oqs <- function() {
  testthat::skip_if_not("ML-DSA-65" %in% pqc_backends(),
                        "this build has no liboqs")
}

test_that("the backend list reports what the build actually enabled", {
  b <- pqc_backends()
  expect_type(b, "character")
  # the dependency-free scheme is always present and always first
  expect_equal(b[1], "xmss-sha256")
  # any further entries are standardised scheme names
  if (length(b) > 1L) {
    expect_true(all(grepl("^(ML-DSA|SPHINCS|SLH-DSA|Falcon)", b[-1])))
  }
  # asking for a scheme this build lacks is an error naming what is
  # available, not a silent fallback to something weaker
  expect_error(oqs_keygen("NO-SUCH-SCHEME-42"), "not available in this build")
  expect_error(oqs_keygen("NO-SUCH-SCHEME-42"), "pqc_backends")
  expect_error(oqs_keygen(""), "non-empty string")
})

test_that("ML-DSA keys have the sizes FIPS 204 specifies", {
  skip_if_no_oqs()
  key <- oqs_keygen("ML-DSA-65")
  expect_s3_class(key, "bricklayer_oqs_key")
  expect_equal(key$scheme, "ML-DSA-65")
  # FIPS 204 ML-DSA-65: 1952-byte public key, 4032-byte private key
  expect_equal(nchar(key$public) / 2, 1952)
  expect_equal(nchar(key$secret) / 2, 4032)
  expect_match(key$public, "^[0-9a-f]+$")
  # each call draws a fresh key
  expect_false(identical(oqs_keygen("ML-DSA-65")$public, key$public))

  # the public half carries no secret
  pub <- oqs_public_key(key)
  expect_s3_class(pub, "bricklayer_oqs_public_key")
  expect_null(pub$secret)
  expect_equal(pub$public, key$public)
  expect_equal(pub$scheme, key$scheme)
  expect_error(oqs_public_key(list()), "oqs_keygen")

  # the other levels, where enabled
  for (alg in c("ML-DSA-44", "ML-DSA-87")) {
    if (alg %in% pqc_backends()) {
      k <- oqs_keygen(alg)
      expect_equal(k$scheme, alg)
      expect_gt(nchar(k$public), 0L)
    }
  }
})

test_that("an ML-DSA signature verifies and resists tampering", {
  skip_if_no_oqs()
  key <- oqs_keygen("ML-DSA-65")
  pub <- oqs_public_key(key)
  msg <- "capsule manifest sha256:deadbeef"

  sig <- capsule_sign(msg, key)
  expect_s3_class(sig, "bricklayer_signature")
  expect_equal(sig$scheme, "ML-DSA-65")
  # ML-DSA-65's signature is 3309 bytes
  expect_equal(nchar(sig$signature) / 2, 3309)
  # no authentication path and no leaf index: the scheme is stateless
  expect_null(sig$auth)
  expect_null(sig$index)

  expect_true(capsule_verify(msg, sig, pub))
  # verifying from the full key works too
  expect_true(capsule_verify(msg, sig, key))

  # every way of being wrong fails
  expect_false(capsule_verify("capsule manifest sha256:deadbeeg", sig, pub))
  expect_false(capsule_verify("", sig, pub))
  expect_false(capsule_verify(msg, sig, oqs_public_key(oqs_keygen("ML-DSA-65"))))
  flip <- sig
  flip$signature <- paste0(
    if (substring(sig$signature, 1L, 1L) == "a") "b" else "a",
    substring(sig$signature, 2L))
  expect_false(capsule_verify(msg, flip, pub))
  # a truncated or non-hex signature is not verified, and does not error
  trunc <- sig
  trunc$signature <- substring(sig$signature, 1L, 64L)
  expect_false(capsule_verify(msg, trunc, pub))
  bad <- sig
  bad$signature <- paste0("zz", substring(sig$signature, 3L))
  expect_false(capsule_verify(msg, bad, pub))
  # a malformed public key likewise
  badpub <- pub
  badpub$public <- "abcd"
  expect_false(capsule_verify(msg, sig, badpub))

  # STATELESS: the same key signs again, with no index to carry forward
  sig2 <- capsule_sign("a second manifest", key)
  expect_true(capsule_verify("a second manifest", sig2, pub))
  expect_true(capsule_verify(msg, sig, pub))
  expect_null(sig2$key_state)
  # and signatures do not transfer between messages
  expect_false(capsule_verify(msg, sig2, pub))

  # raw messages work
  r <- capsule_sign(charToRaw("abc"), key)
  expect_true(capsule_verify(charToRaw("abc"), r, pub))
  expect_error(capsule_sign(c("a", "b"), key), "length-1")
})

test_that("a signature is not verified against another scheme's key", {
  skip_if_no_oqs()
  oqs <- oqs_keygen("ML-DSA-65")
  xm <- pqc_keygen(height = 2)
  msg <- "one manifest"

  osig <- capsule_sign(msg, oqs)
  xsig <- capsule_sign(msg, xm)
  # the schemes are recorded and checked, so a cross-scheme presentation
  # is rejected rather than misinterpreted
  expect_false(capsule_verify(msg, xsig, oqs_public_key(oqs)))
  expect_false(capsule_verify(msg, osig, signing_public_key(xm)))
  # the correct key still verifies, so the guard is not rejecting
  # everything
  expect_true(capsule_verify(msg, osig, oqs_public_key(oqs)))
  expect_true(capsule_verify(msg, xsig, signing_public_key(xm)))
  # and an ML-DSA signature under a different ML-DSA level fails too
  if ("ML-DSA-87" %in% pqc_backends()) {
    k87 <- oqs_keygen("ML-DSA-87")
    expect_false(capsule_verify(msg, osig, oqs_public_key(k87)))
  }
})

test_that("the standardised keys print without exposing the secret", {
  skip_if_no_oqs()
  key <- oqs_keygen("ML-DSA-65")
  txt <- paste(format(key), collapse = "\n")
  expect_match(txt, "liboqs", fixed = TRUE)
  expect_match(txt, "ML-DSA-65", fixed = TRUE)
  expect_match(txt, "withheld")
  expect_match(txt, "stateless")
  # the secret key must not appear anywhere in the rendering
  expect_false(grepl(substring(key$secret, 1L, 64L), txt, fixed = TRUE))
  # nor is the whole public key dumped
  expect_true(nchar(txt) < 1000L)
  expect_output(print(key), "Signing key")

  ptxt <- paste(format(oqs_public_key(key)), collapse = "\n")
  expect_match(ptxt, "Public verification key")
  expect_false(grepl(substring(key$secret, 1L, 64L), ptxt, fixed = TRUE))
  expect_output(print(oqs_public_key(key)), "Public verification")

  # the signature prints abbreviated, with no path or index
  s <- capsule_sign("m", key)
  stxt <- paste(format(s), collapse = "\n")
  expect_match(stxt, "3309 bytes")
  expect_match(stxt, "stateless")
  expect_true(nchar(stxt) < 500L)
  expect_output(print(s), "Capsule signature")
})

test_that("a manifest chain seal can be signed with a standardised key", {
  skip_if_no_oqs()
  ch <- chain_new()
  for (i in 1:4) ch <- chain_append(ch, paste("manifest", i))
  key <- oqs_keygen("ML-DSA-65")
  pub <- oqs_public_key(key)

  sig <- capsule_sign(chain_seal(ch), key)
  expect_true(capsule_verify(chain_seal(ch), sig, pub))
  # a truncated chain seals differently, so the signature no longer holds
  trunc <- ch
  trunc$entries[[4]] <- NULL
  expect_false(capsule_verify(chain_seal(trunc), sig, pub))
  # and the same key signs the Merkle root of the data, no index needed
  root <- merkle_root(c("a", "b", "c"))
  rsig <- capsule_sign(root, key)
  expect_true(capsule_verify(root, rsig, pub))
  expect_false(capsule_verify(merkle_root(c("a", "b", "d")), rsig, pub))
})
