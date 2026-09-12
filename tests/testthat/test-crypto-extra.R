# BLAKE2b, PBKDF2, OS entropy and object digests.
#
# Anchors outside the package: the RFC 7693 BLAKE2b-512 vectors and the
# published PBKDF2-HMAC-SHA256 vectors. The entropy source is anchored
# on the properties a CSPRNG must have -- independence between calls, and
# not consuming R's own stream.

test_that("BLAKE2b matches the RFC 7693 vectors", {
  expect_equal(core_blake2b("abc", length = 64), paste0(
    "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d1",
    "7d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923"))
  expect_equal(core_blake2b("", length = 64), paste0(
    "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419",
    "d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce"))

  # any digest length, which SHA-2 cannot offer
  expect_equal(nchar(core_blake2b("abc")), 64L)
  expect_equal(nchar(core_blake2b("abc", length = 64)), 128L)
  expect_equal(nchar(core_blake2b("abc", length = 1)), 2L)
  expect_equal(nchar(core_blake2b("abc", length = 20)), 40L)
  # a shorter digest is NOT a prefix of a longer one: the length enters
  # the parameter block, which is what stops a length-extension trick
  expect_false(identical(core_blake2b("abc", length = 32),
                         substring(core_blake2b("abc", length = 64), 1, 64)))

  # keyed BLAKE2b is a MAC in its own right
  expect_false(identical(core_blake2b("m", key = "k"), core_blake2b("m")))
  expect_false(identical(core_blake2b("m", key = "k1"),
                         core_blake2b("m", key = "k2")))
  expect_identical(core_blake2b("m", key = "k"), core_blake2b("m", key = "k"))
  # a raw key and a 64-byte key both work
  expect_match(core_blake2b("m", key = as.raw(rep(1, 64))), "^[0-9a-f]{64}$")

  # vectorised over character input; raw input hashes the same bytes
  expect_length(core_blake2b(c("a", "b", "c")), 3L)
  expect_identical(core_blake2b("abc"), core_blake2b(charToRaw("abc")))
  expect_match(core_blake2b("abc"), "^[0-9a-f]{64}$")
  # sensitive to a one-character change
  expect_false(identical(core_blake2b("abc"), core_blake2b("abd")))

  expect_error(core_blake2b("m", length = 0), "between 1 and 64")
  expect_error(core_blake2b("m", length = 65), "between 1 and 64")
  expect_error(core_blake2b("m", key = as.raw(rep(1, 65))), "at most 64")
})

test_that("PBKDF2-HMAC-SHA256 matches the published vectors", {
  expect_equal(derive_key("password", "salt", iterations = 1),
    "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
  expect_equal(derive_key("password", "salt", iterations = 2),
    "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43")
  expect_equal(derive_key("password", "salt", iterations = 4096),
    "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a")
  # a 40-byte key spans two blocks, which exercises the block counter
  expect_equal(derive_key("passwordPASSWORDpassword",
                          "saltSALTsaltSALTsaltSALTsaltSALTsalt",
                          iterations = 4096, length = 40), paste0(
    "348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1",
    "c635518c7dac47e9"))

  # deterministic, so a verifier can repeat it
  expect_identical(derive_key("pw", "s", 1000), derive_key("pw", "s", 1000))
  # every input changes the key
  expect_false(identical(derive_key("pw", "s1", 100),
                         derive_key("pw", "s2", 100)))
  expect_false(identical(derive_key("pw1", "s", 100),
                         derive_key("pw2", "s", 100)))
  expect_false(identical(derive_key("pw", "s", 100),
                         derive_key("pw", "s", 101)))
  # a longer key extends a shorter one, since the blocks are independent
  expect_equal(substring(derive_key("pw", "s", 10, length = 64), 1, 64),
               derive_key("pw", "s", 10, length = 32))
  expect_equal(nchar(derive_key("pw", "s", 10, length = 16)), 32L)
  # raw passphrases and salts are accepted
  expect_match(derive_key(charToRaw("pw"), charToRaw("s"), 10),
               "^[0-9a-f]{64}$")

  # it composes with HMAC signing, which is the point of it existing
  key <- derive_key("correct horse battery staple", "unique-salt",
                    iterations = 1000)
  sig <- capsule_sign("manifest", key, scheme = "hmac")
  expect_true(capsule_verify("manifest", sig, key))
  expect_false(capsule_verify("manifest", sig,
                              derive_key("wrong passphrase", "unique-salt",
                                         iterations = 1000)))
  # the salt is part of the key, so the same passphrase under another
  # salt does not verify
  expect_false(capsule_verify("manifest", sig,
    derive_key("correct horse battery staple", "other-salt", 1000)))

  expect_error(derive_key("pw", "s", iterations = 0), "at least 1")
  expect_error(derive_key("pw", "s", length = 0), "between 1 and 1024")
  expect_error(derive_key(c("a", "b"), "s"), "length-1")
})

test_that("random_bytes reads the OS source, not R's generator", {
  b <- random_bytes(32)
  expect_true(is.raw(b))
  expect_length(b, 32L)
  # independent between calls, which a seeded generator would not be
  expect_false(identical(random_bytes(32), random_bytes(32)))
  # and NOT reproducible under set.seed, which is the whole point
  set.seed(1)
  x <- random_bytes(16)
  set.seed(1)
  expect_false(identical(random_bytes(16), x))
  # R's own stream is left untouched, so a seeded analysis is unaffected
  set.seed(99)
  want <- stats::runif(3)
  set.seed(99)
  invisible(random_bytes(64))
  expect_equal(stats::runif(3), want)

  # the bytes are spread over the whole octet range
  big <- as.integer(random_bytes(8000))
  expect_gt(length(unique(big)), 200L)
  expect_true(all(big >= 0 & big <= 255))
  # a chi-square check that no byte value is grossly favoured
  counts <- tabulate(big + 1L, nbins = 256L)
  chi <- sum((counts - 8000 / 256)^2 / (8000 / 256))
  expect_lt(chi, stats::qchisq(0.9999, df = 255))

  expect_length(random_bytes(1), 1L)
  expect_error(random_bytes(0), "between 1 and")
  expect_error(random_bytes(2e6), "between 1 and")
  # a generated key really is unpredictable, because its seeds come from
  # here
  expect_false(identical(pqc_keygen(2)$root, pqc_keygen(2)$root))
})

test_that("digest_object fingerprints arbitrary objects stably", {
  expect_match(digest_object(list(a = 1L)), "^[0-9a-f]{64}$")
  # stable across calls
  expect_identical(digest_object(1:10), digest_object(1:10))
  expect_identical(digest_object(mtcars), digest_object(mtcars))
  # sensitive to any change
  expect_false(identical(digest_object(1:10), digest_object(1:11)))
  expect_false(identical(digest_object(list(a = 1)),
                         digest_object(list(a = 2))))
  expect_false(identical(digest_object(list(a = 1)),
                         digest_object(list(b = 1))))
  # attributes are part of the object, so part of the digest
  expect_false(identical(digest_object(matrix(1:6, nrow = 2)),
                         digest_object(1:6)))
  expect_false(identical(digest_object(factor(c("a", "b"))),
                         digest_object(c("a", "b"))))
  # integer and double are different objects even when they print alike
  expect_false(identical(digest_object(1L), digest_object(1)))

  # every algorithm is available, with the right width
  expect_equal(nchar(digest_object(mtcars, algo = "sha256")), 64L)
  expect_equal(nchar(digest_object(mtcars, algo = "sha512")), 128L)
  expect_equal(nchar(digest_object(mtcars, algo = "blake2b")), 64L)
  expect_type(digest_object(mtcars, algo = "crc32"), "double")
  # a keyed fingerprint only a key holder can reproduce
  expect_false(identical(digest_object(mtcars, algo = "blake2b",
                                       key = "k1"),
                         digest_object(mtcars, algo = "blake2b",
                                       key = "k2")))
  # functions and environments-free objects work too
  expect_match(digest_object(function(x) x + 1), "^[0-9a-f]{64}$")
  expect_match(digest_object(NULL), "^[0-9a-f]{64}$")
  expect_error(digest_object(1, algo = "md5"))
})
