# The standardised post-quantum schemes at the R level: the key objects,
# the signature objects, and every way a verification must fail.
#
# Conformance against an independent implementation lives in
# test-fips-sig.R. What is checked here is the surface around it -- that
# a malformed key or signature is a FALSE rather than an error, that the
# scheme is recorded and enforced, and that a secret never reaches a
# printed representation. These tests used to skip wherever liboqs was
# absent, which on CRAN was always; the schemes are implemented in the
# package now, so nothing here is conditional.

test_that("a key names its scheme and does not repeat itself", {
  key <- fips_keygen("ML-DSA-65")
  expect_s3_class(key, "bricklayer_fips_key")
  expect_s3_class(key, "bricklayer_oqs_key")
  expect_identical(key$scheme, "ML-DSA-65")
  expect_identical(nchar(key$public) %/% 2L, 1952L)
  expect_identical(nchar(key$secret) %/% 2L, 4032L)
  # a fresh key is a different key: keygen draws from the CSPRNG
  expect_false(identical(fips_keygen("ML-DSA-65")$public, key$public))

  pub <- fips_public_key(key)
  expect_s3_class(pub, "bricklayer_fips_public_key")
  expect_s3_class(pub, "bricklayer_oqs_public_key")
  expect_identical(pub$public, key$public)
  expect_null(pub$secret)
  expect_error(fips_public_key(list()), "fips_keygen")

  expect_error(fips_keygen("NO-SUCH-SCHEME-42"), "unknown scheme")
  expect_error(fips_keygen("NO-SUCH-SCHEME-42"), "pqc_backends|standardised")
  expect_error(fips_keygen(""), "non-empty string")

  for (alg in c("ML-DSA-44", "ML-DSA-87")) {
    k <- fips_keygen(alg)
    expect_identical(k$scheme, alg)
    expect_identical(nchar(k$public) %/% 2L,
                     fips_sizes(alg)[["public_key"]])
  }
})

test_that("an ML-DSA signature verifies and resists tampering", {
  key <- fips_keygen("ML-DSA-65")
  pub <- fips_public_key(key)
  msg <- "capsule manifest sha256:deadbeef"

  sig <- capsule_sign(msg, key)
  expect_s3_class(sig, "bricklayer_signature")
  expect_identical(sig$scheme, "ML-DSA-65")
  expect_identical(nchar(sig$signature) %/% 2L, 3309L)
  # no authentication path and no leaf index: the scheme is stateless
  expect_null(sig$auth)
  expect_null(sig$index)

  expect_true(capsule_verify(msg, sig, pub))
  expect_true(capsule_verify(msg, sig, key))

  # every way of being wrong fails
  expect_false(capsule_verify("capsule manifest sha256:deadbeeg", sig, pub))
  expect_false(capsule_verify("", sig, pub))
  expect_false(capsule_verify(msg, sig, fips_public_key(
    fips_keygen("ML-DSA-65"))))
  flip <- sig
  flip$signature <- paste0(
    if (substring(sig$signature, 1L, 1L) == "a") "b" else "a",
    substring(sig$signature, 2L))
  expect_false(capsule_verify(msg, flip, pub))
  # a truncated, odd-length or non-hex signature is not verified, and
  # does not error
  trunc <- sig
  trunc$signature <- substring(sig$signature, 1L, 64L)
  expect_false(capsule_verify(msg, trunc, pub))
  odd <- sig
  odd$signature <- substring(sig$signature, 2L)
  expect_false(capsule_verify(msg, odd, pub))
  bad <- sig
  bad$signature <- paste0("zz", substring(sig$signature, 3L))
  expect_false(capsule_verify(msg, bad, pub))
  # a malformed public key likewise
  badpub <- pub
  badpub$public <- "abcd"
  expect_false(capsule_verify(msg, sig, badpub))
  badpub$public <- paste0("zz", substring(pub$public, 3L))
  expect_false(capsule_verify(msg, sig, badpub))

  # STATELESS: the same key signs again, with no index to carry forward
  sig2 <- capsule_sign("a second manifest", key)
  expect_true(capsule_verify("a second manifest", sig2, pub))
  expect_true(capsule_verify(msg, sig, pub))
  expect_null(sig2$key_state)
  expect_false(capsule_verify(msg, sig2, pub))

  # raw messages work
  r <- capsule_sign(charToRaw("abc"), key)
  expect_true(capsule_verify(charToRaw("abc"), r, pub))
  expect_true(capsule_verify("abc", r, pub))
  expect_error(capsule_sign(c("a", "b"), key), "length-1")
})

test_that("an SLH-DSA signature verifies and resists tampering", {
  # the f parameter set, because signing an s set takes seconds
  key <- fips_keygen("SLH-DSA-SHAKE-128f")
  pub <- fips_public_key(key)
  msg <- "capsule manifest sha256:deadbeef"
  sig <- capsule_sign(msg, key)
  expect_identical(nchar(sig$signature) %/% 2L, 17088L)
  expect_true(capsule_verify(msg, sig, pub))
  expect_false(capsule_verify(paste0(msg, "!"), sig, pub))
  expect_false(capsule_verify(msg, sig, fips_public_key(
    fips_keygen("SLH-DSA-SHAKE-128f"))))
  # a hash-based scheme has no index either: this one is stateless
  expect_null(sig$index)
  expect_true(capsule_verify(msg, capsule_sign(msg, key), pub))
})

test_that("a signature is not verified against another scheme's key", {
  std <- fips_keygen("ML-DSA-65")
  xm <- pqc_keygen(height = 2)
  msg <- "one manifest"

  osig <- capsule_sign(msg, std)
  xsig <- capsule_sign(msg, xm)
  # the schemes are recorded and checked, so a cross-scheme presentation
  # is rejected rather than misinterpreted
  expect_false(capsule_verify(msg, xsig, fips_public_key(std)))
  expect_false(capsule_verify(msg, osig, signing_public_key(xm)))
  # the correct key still verifies, so the guard is not rejecting
  # everything
  expect_true(capsule_verify(msg, osig, fips_public_key(std)))
  expect_true(capsule_verify(msg, xsig, signing_public_key(xm)))
  # and an ML-DSA signature under a different ML-DSA level fails too
  k87 <- fips_keygen("ML-DSA-87")
  expect_false(capsule_verify(msg, osig, fips_public_key(k87)))
  # as does an SLH-DSA signature under an ML-DSA key
  ssig <- capsule_sign(msg, fips_keygen("SLH-DSA-SHAKE-128f"))
  expect_false(capsule_verify(msg, ssig, fips_public_key(std)))
})

test_that("the standardised keys print without exposing the secret", {
  key <- fips_keygen("ML-DSA-65")
  txt <- paste(format(key), collapse = "\n")
  expect_match(txt, "FIPS 204", fixed = TRUE)
  expect_match(txt, "ML-DSA-65", fixed = TRUE)
  expect_match(txt, "withheld")
  expect_match(txt, "stateless")
  # The secret must not appear. Tested on its TAIL: an ML-DSA secret key
  # opens with rho, the same bytes the public key opens with, so its
  # leading characters are not secret and asserting on them would pass
  # whatever the rendering did.
  expect_false(grepl(substring(key$secret, nchar(key$secret) - 63L), txt,
                     fixed = TRUE))
  # nor is the whole public key dumped
  expect_true(nchar(txt) < 1000L)
  expect_output(print(key), "Signing key")

  ptxt <- paste(format(fips_public_key(key)), collapse = "\n")
  expect_match(ptxt, "Public verification key")
  expect_false(grepl(substring(key$secret, nchar(key$secret) - 63L), ptxt,
                     fixed = TRUE))
  expect_output(print(fips_public_key(key)), "Public verification")

  # the signature prints abbreviated, with no path or index
  s <- capsule_sign("m", key)
  stxt <- paste(format(s), collapse = "\n")
  expect_match(stxt, "3309 bytes")
  expect_match(stxt, "stateless")
  expect_true(nchar(stxt) < 500L)
  expect_output(print(s), "Capsule signature")
})

test_that("a manifest chain seal can be signed with a standardised key", {
  ch <- chain_new()
  for (i in 1:4) ch <- chain_append(ch, paste("manifest", i))
  key <- fips_keygen("ML-DSA-65")
  pub <- fips_public_key(key)

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
