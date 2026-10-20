testthat::skip_on_cran()  # battery: runs in CI and locally; CRAN runs the correctness core
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

PREHASHES <- c("sha224", "sha256", "sha384", "sha512", "sha512_224", "sha512_256",
               "sha3_224", "sha3_256", "sha3_384", "sha3_512", "shake128", "shake256")

test_that("a pre-hashed signature round-trips for each pre-hash", {
  for (scheme in c(
    "ML-DSA-44", "SLH-DSA-SHAKE-128f",
    "SLH-DSA-SHA2-128f"
  )) {
    key <- fipskg(scheme)
    pub <- fipspubkey(key)
    for (ph in PREHASHES) {
      sig <- cpssign("a manifest digest", key, prehash = ph)
      expect_identical(sig$prehash, ph, info = paste(scheme, ph))
      expect_true(cpsvrf("a manifest digest", sig, pub),
        info = paste(scheme, ph)
      )
      # the pre-hash is recorded, so verification needs no extra
      # argument -- but stating the wrong one must fail
      expect_false(
        cpsvrf("a manifest digest", sig, pub,
          prehash = "none"
        ),
        info = paste(scheme, ph)
      )
      expect_false(cpsvrf("another digest", sig, pub),
        info = paste(scheme, ph)
      )
    }
  }
})

test_that("the pre-hash identifier is bound, not just its output", {
  key <- fipskg("ML-DSA-65")
  # SHA-256 and SHAKE128 both produce 32 bytes. If only the digest were
  # signed, and not the identifier of the function that produced it, a
  # signature made under one would be presentable under the other for
  # any message whose two digests happened to be equal -- and, more
  # simply, the two M' values would differ in nothing but the digest.
  a <- cpssign("m", key, prehash = "sha256")
  b <- cpssign("m", key, prehash = "shake128")
  expect_false(identical(a$signature, b$signature))
  expect_false(cpsvrf("m", a, key, prehash = "shake128"))
  expect_false(cpsvrf("m", b, key, prehash = "sha256"))
  expect_true(cpsvrf("m", a, key, prehash = "sha256"))
  expect_true(cpsvrf("m", b, key, prehash = "shake128"))

  # and a pure signature over the digest bytes is a different signature
  # from a pre-hashed one over the message, which is what the 0x01
  # domain byte is for
  dig <- .rmbl_hex_to_raw(csha256("m"))
  pure <- cpssign(dig, key, prehash = "none")
  expect_false(identical(pure$signature, a$signature))
  expect_false(cpsvrf(dig, a, key, prehash = "none"))
  expect_false(cpsvrf("m", pure, key, prehash = "sha256"))
})

test_that("a pre-hashed signature still respects the context", {
  key <- fipskg("ML-DSA-44")
  sig <- cpssign("m", key, ctx = "release", prehash = "sha512")
  expect_true(cpsvrf("m", sig, key, ctx = "release"))
  expect_false(cpsvrf("m", sig, key, ctx = "staging"))
  expect_false(cpsvrf("m", sig, key))
  # the deterministic variant is deterministic here too
  d1 <- cpssign("m", key,
    ctx = "release", prehash = "sha512",
    determ = TRUE
  )
  d2 <- cpssign("m", key,
    ctx = "release", prehash = "sha512",
    determ = TRUE
  )
  expect_identical(d1$signature, d2$signature)
})

test_that("an unknown pre-hash is refused", {
  key <- fipskg("ML-DSA-44")
  expect_error(cpssign("m", key, prehash = "md5"), "must be one of")
  expect_error(cpssign("m", key, prehash = "sha1"), "must be one of")
  # partial matching is match.arg's, so an unambiguous prefix is fine
  expect_true(cpsvrf(
    "m", cpssign("m", key, prehash = "shake2"),
    key
  ))
})

test_that("external mu signs without the message and agrees with it", {
  key <- fipskg("ML-DSA-65")
  pub <- fipspubkey(key)
  mu <- fipsmu(key, "a manifest digest", ctx = "release")
  expect_true(is.raw(mu))
  expect_length(mu, 64L)
  # computable from the public key alone: the message never has to reach
  # whatever holds the secret
  expect_identical(
    fipsmu(pub, "a manifest digest", ctx = "release"),
    mu
  )

  sig <- fipssignmu(key, mu)
  expect_s3_class(sig, "bricklayer_signature")
  expect_identical(sig$scheme, "ML-DSA-65")
  expect_true(fipsvrfmu(key, mu, sig))
  expect_true(fipsvrfmu(pub, mu, sig))
  # the result is an ordinary signature: verifying from the message works
  expect_true(cpsvrf("a manifest digest", sig, pub,
    ctx = "release"
  ))
  expect_false(cpsvrf("a manifest digest", sig, pub))

  # and the ordinary path produces a signature the mu path verifies
  det <- cpssign("a manifest digest", key,
    ctx = "release",
    determ = TRUE
  )
  expect_true(fipsvrfmu(pub, mu, det))
  expect_identical(
    fipssignmu(key, mu, determ = TRUE)$signature,
    det$signature
  )
})

test_that("mu binds the key and the context, so it is not a bare digest", {
  a <- fipskg("ML-DSA-44")
  b <- fipskg("ML-DSA-44")
  m <- "a manifest digest"
  # different key, same message: different mu, because mu absorbs
  # tr is the hash of pk
  expect_false(identical(fipsmu(a, m), fipsmu(b, m)))
  # different context, same key and message
  expect_false(identical(
    fipsmu(a, m, ctx = "x"),
    fipsmu(a, m, ctx = "y")
  ))
  expect_false(identical(fipsmu(a, m), fipsmu(a, m, ctx = "x")))
  # different pre-hash
  expect_false(identical(
    fipsmu(a, m, prehash = "sha256"),
    fipsmu(a, m, prehash = "shake128")
  ))
  # a signature made over one mu does not verify against another
  sig <- fipssignmu(a, fipsmu(a, m))
  expect_false(fipsvrfmu(a, fipsmu(a, "other"), sig))
  expect_false(fipsvrfmu(b, fipsmu(b, m), sig))
})

test_that("the external-mu surface refuses what it cannot do", {
  slh <- fipskg("SLH-DSA-SHAKE-128f")
  expect_error(fipsmu(slh, "m"), "ML-DSA interface")
  expect_error(fipssignmu(slh, raw(64L)), "ML-DSA interface")
  key <- fipskg("ML-DSA-44")
  expect_error(fipssignmu(key, raw(63L)), "64 raw bytes")
  expect_error(fipssignmu(key, as.character(raw(64L))), "64 raw bytes")
  expect_error(fipsmu(list(), "m"), "fipskg")
  # a public-only key cannot sign
  expect_error(fipssignmu(fipspubkey(key), raw(64L)), "secret half")
  # and mu of the wrong length is not verified rather than an error
  sig <- fipssignmu(key, fipsmu(key, "m"))
  expect_false(fipsvrfmu(key, raw(63L), sig))
  expect_false(fipsvrfmu(key, raw(64L), sig))
  # a signature from another scheme is refused on the scheme, not the
  # bytes
  other <- fipssignmu(
    fipskg("ML-DSA-65"),
    fipsmu(fipskg("ML-DSA-65"), "m")
  )
  expect_false(fipsvrfmu(key, fipsmu(key, "m"), other))
  expect_error(fipsvrfmu(key, raw(64L), list()), "fipssignmu")
})
