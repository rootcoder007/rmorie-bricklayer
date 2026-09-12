# HashML-DSA (FIPS 204 section 5.4), HashSLH-DSA (FIPS 205 section
# 10.2.2) and the ML-DSA external-mu interface.
#
# Anchored on OpenSSL 3.5, out of tree: OpenSSL has no pre-hash mode of
# its own, so the check was to build M' from the standard's own recipe,
# hand it to OpenSSL with message encoding switched off, and confirm the
# bytes agree -- which they do for every parameter set and every
# pre-hash. Its external-mu mode needs no such trick and agrees
# directly. What is asserted here is the part that cannot be wrong by
# accident twice: that a pre-hashed signature is NOT interchangeable
# with a pure one, and that mu is not a bare digest.

PREHASHES <- c("sha256", "sha512", "shake128", "shake256")

test_that("a pre-hashed signature round-trips for each pre-hash", {
  for (scheme in c("ML-DSA-44", "SLH-DSA-SHAKE-128f",
                   "SLH-DSA-SHA2-128f")) {
    key <- fips_keygen(scheme)
    pub <- fips_public_key(key)
    for (ph in PREHASHES) {
      sig <- capsule_sign("a manifest digest", key, prehash = ph)
      expect_identical(sig$prehash, ph, info = paste(scheme, ph))
      expect_true(capsule_verify("a manifest digest", sig, pub),
                  info = paste(scheme, ph))
      # the pre-hash is recorded, so verification needs no extra
      # argument -- but stating the wrong one must fail
      expect_false(capsule_verify("a manifest digest", sig, pub,
                                  prehash = "none"),
                   info = paste(scheme, ph))
      expect_false(capsule_verify("another digest", sig, pub),
                   info = paste(scheme, ph))
    }
  }
})

test_that("the pre-hash identifier is bound, not just its output", {
  key <- fips_keygen("ML-DSA-65")
  # SHA-256 and SHAKE128 both produce 32 bytes. If only the digest were
  # signed, and not the identifier of the function that produced it, a
  # signature made under one would be presentable under the other for
  # any message whose two digests happened to be equal -- and, more
  # simply, the two M' values would differ in nothing but the digest.
  a <- capsule_sign("m", key, prehash = "sha256")
  b <- capsule_sign("m", key, prehash = "shake128")
  expect_false(identical(a$signature, b$signature))
  expect_false(capsule_verify("m", a, key, prehash = "shake128"))
  expect_false(capsule_verify("m", b, key, prehash = "sha256"))
  expect_true(capsule_verify("m", a, key, prehash = "sha256"))
  expect_true(capsule_verify("m", b, key, prehash = "shake128"))

  # and a pure signature over the digest bytes is a different signature
  # from a pre-hashed one over the message, which is what the 0x01
  # domain byte is for
  dig <- .rmbl_hex_to_raw(core_sha256("m"))
  pure <- capsule_sign(dig, key, prehash = "none")
  expect_false(identical(pure$signature, a$signature))
  expect_false(capsule_verify(dig, a, key, prehash = "none"))
  expect_false(capsule_verify("m", pure, key, prehash = "sha256"))
})

test_that("a pre-hashed signature still respects the context", {
  key <- fips_keygen("ML-DSA-44")
  sig <- capsule_sign("m", key, context = "release", prehash = "sha512")
  expect_true(capsule_verify("m", sig, key, context = "release"))
  expect_false(capsule_verify("m", sig, key, context = "staging"))
  expect_false(capsule_verify("m", sig, key))
  # the deterministic variant is deterministic here too
  d1 <- capsule_sign("m", key, context = "release", prehash = "sha512",
                     deterministic = TRUE)
  d2 <- capsule_sign("m", key, context = "release", prehash = "sha512",
                     deterministic = TRUE)
  expect_identical(d1$signature, d2$signature)
})

test_that("an unknown pre-hash is refused", {
  key <- fips_keygen("ML-DSA-44")
  expect_error(capsule_sign("m", key, prehash = "md5"), "arg")
  expect_error(capsule_sign("m", key, prehash = "sha1"), "arg")
  # partial matching is match.arg's, so an unambiguous prefix is fine
  expect_true(capsule_verify("m", capsule_sign("m", key, prehash = "sha2"),
                             key))
})

test_that("external mu signs without the message and agrees with it", {
  key <- fips_keygen("ML-DSA-65")
  pub <- fips_public_key(key)
  mu <- fips_mu(key, "a manifest digest", context = "release")
  expect_true(is.raw(mu))
  expect_length(mu, 64L)
  # computable from the public key alone: the message never has to reach
  # whatever holds the secret
  expect_identical(fips_mu(pub, "a manifest digest", context = "release"),
                   mu)

  sig <- fips_sign_mu(key, mu)
  expect_s3_class(sig, "bricklayer_signature")
  expect_identical(sig$scheme, "ML-DSA-65")
  expect_true(fips_verify_mu(key, mu, sig))
  expect_true(fips_verify_mu(pub, mu, sig))
  # the result is an ordinary signature: verifying from the message works
  expect_true(capsule_verify("a manifest digest", sig, pub,
                             context = "release"))
  expect_false(capsule_verify("a manifest digest", sig, pub))

  # and the ordinary path produces a signature the mu path verifies
  det <- capsule_sign("a manifest digest", key, context = "release",
                      deterministic = TRUE)
  expect_true(fips_verify_mu(pub, mu, det))
  expect_identical(fips_sign_mu(key, mu, deterministic = TRUE)$signature,
                   det$signature)
})

test_that("mu binds the key and the context, so it is not a bare digest", {
  a <- fips_keygen("ML-DSA-44")
  b <- fips_keygen("ML-DSA-44")
  m <- "a manifest digest"
  # different key, same message: different mu, because mu absorbs
  # tr = H(pk)
  expect_false(identical(fips_mu(a, m), fips_mu(b, m)))
  # different context, same key and message
  expect_false(identical(fips_mu(a, m, context = "x"),
                         fips_mu(a, m, context = "y")))
  expect_false(identical(fips_mu(a, m), fips_mu(a, m, context = "x")))
  # different pre-hash
  expect_false(identical(fips_mu(a, m, prehash = "sha256"),
                         fips_mu(a, m, prehash = "shake128")))
  # a signature made over one mu does not verify against another
  sig <- fips_sign_mu(a, fips_mu(a, m))
  expect_false(fips_verify_mu(a, fips_mu(a, "other"), sig))
  expect_false(fips_verify_mu(b, fips_mu(b, m), sig))
})

test_that("the external-mu surface refuses what it cannot do", {
  slh <- fips_keygen("SLH-DSA-SHAKE-128f")
  expect_error(fips_mu(slh, "m"), "ML-DSA interface")
  expect_error(fips_sign_mu(slh, raw(64L)), "ML-DSA interface")
  key <- fips_keygen("ML-DSA-44")
  expect_error(fips_sign_mu(key, raw(63L)), "64 raw bytes")
  expect_error(fips_sign_mu(key, as.character(raw(64L))), "64 raw bytes")
  expect_error(fips_mu(list(), "m"), "fips_keygen")
  # a public-only key cannot sign
  expect_error(fips_sign_mu(fips_public_key(key), raw(64L)), "secret half")
  # and mu of the wrong length is not verified rather than an error
  sig <- fips_sign_mu(key, fips_mu(key, "m"))
  expect_false(fips_verify_mu(key, raw(63L), sig))
  expect_false(fips_verify_mu(key, raw(64L), sig))
  # a signature from another scheme is refused on the scheme, not the
  # bytes
  other <- fips_sign_mu(fips_keygen("ML-DSA-65"),
                        fips_mu(fips_keygen("ML-DSA-65"), "m"))
  expect_false(fips_verify_mu(key, fips_mu(key, "m"), other))
  expect_error(fips_verify_mu(key, raw(64L), list()), "fips_sign_mu")
})
