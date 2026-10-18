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
  key <- fipskg("ML-DSA-65")
  expect_s3_class(key, "bricklayer_fips_key")
  expect_s3_class(key, "bricklayer_oqs_key")
  expect_identical(key$scheme, "ML-DSA-65")
  expect_identical(nchar(key$public) %/% 2L, 1952L)
  expect_identical(nchar(key$secret) %/% 2L, 4032L)
  # a fresh key is a different key: keygen draws from the CSPRNG
  expect_false(identical(fipskg("ML-DSA-65")$public, key$public))

  pub <- fipspubkey(key)
  expect_s3_class(pub, "bricklayer_fips_public_key")
  expect_s3_class(pub, "bricklayer_oqs_public_key")
  expect_identical(pub$public, key$public)
  expect_null(pub$secret)
  expect_error(fipspubkey(list()), "fipskg")

  expect_error(fipskg("NO-SUCH-SCHEME-42"), "unknown scheme")
  expect_error(fipskg("NO-SUCH-SCHEME-42"), "pqc_backends|standardised")
  expect_error(fipskg(""), "non-empty string")

  for (alg in c("ML-DSA-44", "ML-DSA-87")) {
    k <- fipskg(alg)
    expect_identical(k$scheme, alg)
    expect_identical(nchar(k$public) %/% 2L,
                     fipssz(alg)[["public_key"]])
  }
})

test_that("an ML-DSA signature verifies and resists tampering", {
  key <- fipskg("ML-DSA-65")
  pub <- fipspubkey(key)
  msg <- "capsule manifest sha256:deadbeef"

  sig <- cpssign(msg, key)
  expect_s3_class(sig, "bricklayer_signature")
  expect_identical(sig$scheme, "ML-DSA-65")
  expect_identical(nchar(sig$signature) %/% 2L, 3309L)
  # no authentication path and no leaf index: the scheme is stateless
  expect_null(sig$auth)
  expect_null(sig$index)

  expect_true(cpsvrf(msg, sig, pub))
  expect_true(cpsvrf(msg, sig, key))

  # every way of being wrong fails
  expect_false(cpsvrf("capsule manifest sha256:deadbeeg", sig, pub))
  expect_false(cpsvrf("", sig, pub))
  expect_false(cpsvrf(msg, sig, fipspubkey(
    fipskg("ML-DSA-65"))))
  flip <- sig
  flip$signature <- paste0(
    if (substring(sig$signature, 1L, 1L) == "a") "b" else "a",
    substring(sig$signature, 2L))
  expect_false(cpsvrf(msg, flip, pub))
  # a truncated, odd-length or non-hex signature is not verified, and
  # does not error
  trunc <- sig
  trunc$signature <- substring(sig$signature, 1L, 64L)
  expect_false(cpsvrf(msg, trunc, pub))
  odd <- sig
  odd$signature <- substring(sig$signature, 2L)
  expect_false(cpsvrf(msg, odd, pub))
  bad <- sig
  bad$signature <- paste0("zz", substring(sig$signature, 3L))
  expect_false(cpsvrf(msg, bad, pub))
  # a malformed public key likewise
  badpub <- pub
  badpub$public <- "abcd"
  expect_false(cpsvrf(msg, sig, badpub))
  badpub$public <- paste0("zz", substring(pub$public, 3L))
  expect_false(cpsvrf(msg, sig, badpub))

  # STATELESS: the same key signs again, with no index to carry forward
  sig2 <- cpssign("a second manifest", key)
  expect_true(cpsvrf("a second manifest", sig2, pub))
  expect_true(cpsvrf(msg, sig, pub))
  expect_null(sig2$key_state)
  expect_false(cpsvrf(msg, sig2, pub))

  # raw messages work
  r <- cpssign(charToRaw("abc"), key)
  expect_true(cpsvrf(charToRaw("abc"), r, pub))
  expect_true(cpsvrf("abc", r, pub))
  expect_error(cpssign(c("a", "b"), key), "length-1")
})

test_that("an SLH-DSA signature verifies and resists tampering", {
  # the f parameter set, because signing an s set takes seconds
  key <- fipskg("SLH-DSA-SHAKE-128f")
  pub <- fipspubkey(key)
  msg <- "capsule manifest sha256:deadbeef"
  sig <- cpssign(msg, key)
  expect_identical(nchar(sig$signature) %/% 2L, 17088L)
  expect_true(cpsvrf(msg, sig, pub))
  expect_false(cpsvrf(paste0(msg, "!"), sig, pub))
  expect_false(cpsvrf(msg, sig, fipspubkey(
    fipskg("SLH-DSA-SHAKE-128f"))))
  # a hash-based scheme has no index either: this one is stateless
  expect_null(sig$index)
  expect_true(cpsvrf(msg, cpssign(msg, key), pub))
})

test_that("a signature is not verified against another scheme's key", {
  std <- fipskg("ML-DSA-65")
  xm <- pqckg(height = 2)
  msg <- "one manifest"

  osig <- cpssign(msg, std)
  xsig <- cpssign(msg, xm)
  # the schemes are recorded and checked, so a cross-scheme presentation
  # is rejected rather than misinterpreted
  expect_false(cpsvrf(msg, xsig, fipspubkey(std)))
  expect_false(cpsvrf(msg, osig, signpubkey(xm)))
  # the correct key still verifies, so the guard is not rejecting
  # everything
  expect_true(cpsvrf(msg, osig, fipspubkey(std)))
  expect_true(cpsvrf(msg, xsig, signpubkey(xm)))
  # and an ML-DSA signature under a different ML-DSA level fails too
  k87 <- fipskg("ML-DSA-87")
  expect_false(cpsvrf(msg, osig, fipspubkey(k87)))
  # as does an SLH-DSA signature under an ML-DSA key
  ssig <- cpssign(msg, fipskg("SLH-DSA-SHAKE-128f"))
  expect_false(cpsvrf(msg, ssig, fipspubkey(std)))
})

test_that("the standardised keys print without exposing the secret", {
  key <- fipskg("ML-DSA-65")
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

  ptxt <- paste(format(fipspubkey(key)), collapse = "\n")
  expect_match(ptxt, "Public verification key")
  expect_false(grepl(substring(key$secret, nchar(key$secret) - 63L), ptxt,
                     fixed = TRUE))
  expect_output(print(fipspubkey(key)), "Public verification")

  # the signature prints abbreviated, with no path or index
  s <- cpssign("m", key)
  stxt <- paste(format(s), collapse = "\n")
  expect_match(stxt, "3309 bytes")
  expect_match(stxt, "stateless")
  expect_true(nchar(stxt) < 500L)
  expect_output(print(s), "Capsule signature")
})

test_that("a manifest chain seal can be signed with a standardised key", {
  ch <- chnnew()
  for (i in 1:4) ch <- chnapp(ch, paste("manifest", i))
  key <- fipskg("ML-DSA-65")
  pub <- fipspubkey(key)

  sig <- cpssign(chnseal(ch), key)
  expect_true(cpsvrf(chnseal(ch), sig, pub))
  # a truncated chain seals differently, so the signature no longer holds
  trunc <- ch
  trunc$entries[[4]] <- NULL
  expect_false(cpsvrf(chnseal(trunc), sig, pub))
  # and the same key signs the Merkle root of the data, no index needed
  root <- mrkroot(c("a", "b", "c"))
  rsig <- cpssign(root, key)
  expect_true(cpsvrf(root, rsig, pub))
  expect_false(cpsvrf(mrkroot(c("a", "b", "d")), rsig, pub))
})
