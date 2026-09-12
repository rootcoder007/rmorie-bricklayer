# ML-DSA (FIPS 204) and SLH-DSA (FIPS 205), implemented in this package.
#
# The anchor that matters is fips-openssl-vectors.txt: public keys and
# signatures produced by OpenSSL 3.5, which shares no code with this
# package. A signature scheme that verifies only its own output passes
# every property test there is -- tampering is still rejected, the wrong
# key still fails -- while being interoperable with nothing. That is not
# hypothetical: this implementation matched the pq-crystals and
# sphincsplus reference code byte for byte while disagreeing with the
# standards in two places (FIPS 204 and 205 both prepend a context
# domain separator the reference omits, and FIPS 205 reads the FORS
# indices most significant bit first where SPHINCS+ read them least
# significant bit first). Only a cross-implementation check found them.

fips_vectors <- function(file) {
  lines <- readLines(test_path(file), warn = FALSE)
  lines <- lines[!startsWith(lines, "#") & nzchar(lines)]
  parts <- strsplit(lines, "|", fixed = TRUE)
  stats::setNames(parts, vapply(parts, `[[`, character(1), 1L))
}

# The sizes FIPS 204 table 1 and FIPS 205 table 2 fix. Hard-coded
# rather than read back from the package, so a change to a packed field
# width fails here instead of being blessed.
FIPS_SIZES <- list(
  "ML-DSA-44"          = c(1312L, 2560L, 2420L, 32L, 32L),
  "ML-DSA-65"          = c(1952L, 4032L, 3309L, 32L, 32L),
  "ML-DSA-87"          = c(2592L, 4896L, 4627L, 32L, 32L),
  "SLH-DSA-SHA2-128s"  = c(32L, 64L, 7856L, 48L, 16L),
  "SLH-DSA-SHA2-128f"  = c(32L, 64L, 17088L, 48L, 16L),
  "SLH-DSA-SHA2-192s"  = c(48L, 96L, 16224L, 72L, 24L),
  "SLH-DSA-SHA2-192f"  = c(48L, 96L, 35664L, 72L, 24L),
  "SLH-DSA-SHA2-256s"  = c(64L, 128L, 29792L, 96L, 32L),
  "SLH-DSA-SHA2-256f"  = c(64L, 128L, 49856L, 96L, 32L),
  "SLH-DSA-SHAKE-128s" = c(32L, 64L, 7856L, 48L, 16L),
  "SLH-DSA-SHAKE-128f" = c(32L, 64L, 17088L, 48L, 16L),
  "SLH-DSA-SHAKE-192s" = c(48L, 96L, 16224L, 72L, 24L),
  "SLH-DSA-SHAKE-192f" = c(48L, 96L, 35664L, 72L, 24L),
  "SLH-DSA-SHAKE-256s" = c(64L, 128L, 29792L, 96L, 32L),
  "SLH-DSA-SHAKE-256f" = c(64L, 128L, 49856L, 96L, 32L)
)

# Signing an SLH-DSA `s` parameter set takes seconds: the small
# signature is bought with a tall hypertree. The `f` sets and every
# ML-DSA set are fast enough to sign unconditionally.
SLOW_TO_SIGN <- c("SLH-DSA-SHAKE-192s", "SLH-DSA-SHAKE-256s",
                  "SLH-DSA-SHA2-192s", "SLH-DSA-SHA2-256s")

test_that("every standardised scheme is present in every build", {
  b <- pqc_backends()
  expect_true("xmss-sha256" %in% b)
  expect_setequal(setdiff(b, "xmss-sha256"), names(FIPS_SIZES))
  # the list is fixed, not probed: there is no build in which a scheme
  # is missing, which was the whole point of dropping liboqs
  expect_identical(b, pqc_backends())
})

test_that("the byte lengths are the ones the standards fix", {
  for (s in names(FIPS_SIZES)) {
    sz <- fips_sizes(s)
    expect_identical(
      unname(sz[c("public_key", "secret_key", "signature", "seed",
                  "opt_rand")]),
      FIPS_SIZES[[s]],
      info = s)
  }
  # an SLH-DSA key is two n-byte halves and its seed three
  expect_identical(fips_sizes("SLH-DSA-SHAKE-192s")[["public_key"]],
                   2L * fips_sizes("SLH-DSA-SHAKE-192s")[["opt_rand"]])
  expect_identical(fips_sizes("SLH-DSA-SHAKE-192s")[["seed"]],
                   3L * fips_sizes("SLH-DSA-SHAKE-192s")[["opt_rand"]])
  # dropping the lattice assumption costs size: three times over at the
  # smallest setting, ten times at the largest
  expect_gt(fips_sizes("SLH-DSA-SHAKE-128s")[["signature"]],
            3 * fips_sizes("ML-DSA-44")[["signature"]])
  expect_gt(fips_sizes("SLH-DSA-SHAKE-256f")[["signature"]],
            10 * fips_sizes("ML-DSA-87")[["signature"]])
  expect_error(fips_sizes("ML-DSA-99"), "unknown scheme")
  expect_error(fips_sizes("xmss-sha256"), "unknown scheme")
  expect_error(fips_sizes(character(0)), "non-empty")
})

test_that("this package reproduces OpenSSL's signatures byte for byte", {
  vec <- fips_vectors("fips-openssl-vectors.txt")
  expect_setequal(names(vec), names(FIPS_SIZES))
  msg <- as.raw(1:32)
  for (s in names(vec)) {
    pk_hex <- vec[[s]][2L]
    sk_hex <- vec[[s]][3L]
    want <- vec[[s]][4L]
    sz <- fips_sizes(s)
    # OpenSSL's key material is the length this package expects, which
    # is already a claim about the encodings
    expect_identical(nchar(pk_hex) %/% 2L, sz[["public_key"]], info = s)
    expect_identical(nchar(sk_hex) %/% 2L, sz[["secret_key"]], info = s)
    key <- fips_key(s, pk_hex, sk_hex)
    if (s %in% SLOW_TO_SIGN) next
    sig <- capsule_sign(msg, key, context = "release",
                        deterministic = TRUE)
    # BYTE equality with an implementation sharing no code with this
    # one. Verifying their signature would be weaker: an implementation
    # can verify what it produces and interoperate with nothing.
    #
    # The digest is over the signature BYTES. core_sha256() on the hex
    # string would hash the spelling instead, which is self-consistent
    # and compares against nothing external.
    expect_identical(core_sha256(.rmbl_hex_to_raw(sig$signature)), want,
                     info = s)
    # and those same bytes verify, from the public key alone
    pub <- fips_key(s, pk_hex)
    expect_true(capsule_verify(msg, sig, pub, context = "release"),
                info = s)
    # the context is bound into the signature, so the same bytes must
    # NOT verify under a different context or none at all
    expect_false(capsule_verify(msg, sig, pub, context = "staging"),
                 info = s)
    expect_false(capsule_verify(msg, sig, pub), info = s)
    expect_false(capsule_verify(as.raw(c(1:32, 0)), sig, pub,
                                context = "release"), info = s)
    # one flipped bit anywhere is a rejection
    flipped <- sig
    n <- nchar(sig$signature)
    mid <- 2L * (n %/% 4L) + 1L
    old <- strtoi(substring(sig$signature, mid, mid + 1L), 16L)
    substring(flipped$signature, mid, mid + 1L) <-
      sprintf("%02x", bitwXor(old, 1L))
    expect_false(capsule_verify(msg, flipped, pub, context = "release"),
                 info = s)
  }
})

test_that("key material round-trips through fips_key", {
  key <- fips_keygen("ML-DSA-44")
  again <- fips_key("ML-DSA-44", key$public, key$secret)
  expect_identical(again$secret, key$secret)
  expect_identical(again$public, key$public)
  expect_s3_class(again, "bricklayer_fips_key")
  # raw and hex are the same material
  expect_identical(
    fips_key("ML-DSA-44", .rmbl_hex_to_raw(key$public),
             .rmbl_hex_to_raw(key$secret))$secret,
    key$secret)
  # a public-only key verifies and cannot sign
  pub <- fips_key("ML-DSA-44", key$public)
  expect_s3_class(pub, "bricklayer_fips_public_key")
  expect_null(pub$secret)
  sig <- capsule_sign("m", again)
  expect_true(capsule_verify("m", sig, pub))
  # material of the wrong length, or for the wrong scheme, is refused
  expect_error(fips_key("ML-DSA-65", key$public, key$secret),
               "must be 1952 bytes")
  expect_error(fips_key("ML-DSA-44", substring(key$public, 3L)),
               "must be 1312 bytes")
  expect_error(fips_key("ML-DSA-44", paste0("zz", substring(key$public, 3L))),
               "must be 1312 bytes")
  expect_error(fips_key("NO-SUCH-42", key$public), "unknown scheme")
})

test_that("a fixed seed reproduces the recorded key and signature", {
  vec <- fips_vectors("fips-self-vectors.txt")
  expect_setequal(names(vec), names(FIPS_SIZES))
  for (s in names(vec)) {
    sz <- fips_sizes(s)
    seed <- as.raw(seq_len(sz[["seed"]]) %% 256L)
    key <- fips_keygen(s, seed = seed)
    expect_identical(key$public, vec[[s]][2L], info = s)
    expect_identical(key$scheme, s)
    # the same seed twice is the same key: keygen reads nothing else
    expect_identical(fips_keygen(s, seed = seed)$public, key$public)
    if (s %in% SLOW_TO_SIGN) next
    sig <- capsule_sign("a manifest digest", key, context = "release",
                        deterministic = TRUE)
    expect_identical(core_sha256(sig$signature), vec[[s]][3L], info = s)
    expect_identical(nchar(sig$signature) %/% 2L,
                     as.integer(vec[[s]][4L]), info = s)
    # and the deterministic variant is deterministic
    expect_identical(
      capsule_sign("a manifest digest", key, context = "release",
                   deterministic = TRUE)$signature,
      sig$signature, info = s)
  }
})

test_that("a fresh key round-trips, and the hedged variant varies", {
  for (s in setdiff(names(FIPS_SIZES), SLOW_TO_SIGN)) {
    key <- fips_keygen(s)
    pub <- fips_public_key(key)
    expect_identical(pub$public, key$public)
    expect_identical(pub$scheme, s)
    expect_null(pub$secret)
    sig <- capsule_sign("payload", key)
    expect_true(capsule_verify("payload", sig, pub), info = s)
    expect_true(capsule_verify("payload", sig, key), info = s)
    expect_false(capsule_verify("payloae", sig, pub), info = s)
    # hedged signing draws fresh randomness, so two signatures over one
    # message differ while both verify
    sig2 <- capsule_sign("payload", key)
    expect_false(identical(sig$signature, sig2$signature), info = s)
    expect_true(capsule_verify("payload", sig2, pub), info = s)
    # raw and character messages are the same message
    expect_true(capsule_verify(charToRaw("payload"), sig, pub), info = s)
  }
})

test_that("a key does not verify another scheme's signature", {
  a <- fips_keygen("ML-DSA-44")
  b <- fips_keygen("ML-DSA-65")
  sa <- capsule_sign("m", a)
  expect_true(capsule_verify("m", sa, a))
  # the scheme is checked before the bytes: a 2420-byte signature would
  # be rejected by ML-DSA-65 on length alone, and an incidental check is
  # one a later change can remove without noticing
  expect_false(capsule_verify("m", sa, b))
  mixed <- sa
  mixed$scheme <- "ML-DSA-65"
  expect_false(capsule_verify("m", mixed, b))
  # nor does an XMSS key verify a lattice signature, or the reverse
  x <- pqc_keygen(height = 2L)
  expect_false(capsule_verify("m", sa, signing_public_key(x)))
})

test_that("bad input is refused rather than silently coerced", {
  key <- fips_keygen("ML-DSA-44")
  expect_error(fips_keygen("ML-DSA-44", seed = as.raw(1:31)),
               "32 bytes")
  expect_error(fips_keygen("ML-DSA-44", seed = 1:32), "raw vector")
  expect_error(fips_keygen("SLH-DSA-SHAKE-128s", seed = as.raw(1:32)),
               "48 bytes")
  expect_error(capsule_sign(c("a", "b"), key), "length-1")
  expect_error(capsule_sign("m", key, context = c("a", "b")), "length-1")
  expect_error(capsule_sign("m", key,
                            context = strrep("x", 256L)),
               "255 bytes")
  expect_error(fips_public_key(list()), "fips_keygen")
  # a 255-byte context is the largest the one-byte length field allows
  sig <- capsule_sign("m", key, context = strrep("x", 255L))
  expect_true(capsule_verify("m", sig, key, context = strrep("x", 255L)))
  expect_false(capsule_verify("m", sig, key, context = strrep("x", 254L)))
})

test_that("the deprecated liboqs-era names still work", {
  expect_warning(key <- oqs_keygen("ML-DSA-44"), "fips_keygen")
  expect_identical(key$scheme, "ML-DSA-44")
  expect_warning(pub <- oqs_public_key(key), "fips_public_key")
  expect_identical(pub$public, key$public)
  # and the old class is still what they carry, so code that tested for
  # it keeps working
  expect_s3_class(key, "bricklayer_oqs_key")
  expect_s3_class(pub, "bricklayer_oqs_public_key")
  sig <- suppressWarnings(capsule_sign("m", key))
  expect_true(capsule_verify("m", sig, pub))
})

test_that("the slow parameter sets sign and verify too", {
  skip_if_not(nzchar(Sys.getenv("BRICKLAYER_SLOW_TESTS")),
              "set BRICKLAYER_SLOW_TESTS to sign with an SLH-DSA s set")
  vec <- fips_vectors("fips-self-vectors.txt")
  for (s in SLOW_TO_SIGN) {
    sz <- fips_sizes(s)
    key <- fips_keygen(s, seed = as.raw(seq_len(sz[["seed"]]) %% 256L))
    sig <- capsule_sign("a manifest digest", key, context = "release",
                        deterministic = TRUE)
    expect_identical(core_sha256(sig$signature), vec[[s]][3L], info = s)
    expect_true(capsule_verify("a manifest digest", sig,
                               fips_public_key(key), context = "release"))
  }
})

test_that("the print methods say which scheme and withhold the secret", {
  key <- fips_keygen("ML-DSA-65")
  out <- format(key)
  expect_true(any(grepl("FIPS 204", out)))
  expect_true(any(grepl("ML-DSA-65", out, fixed = TRUE)))
  expect_true(any(grepl("withheld", out)))
  # The secret must not appear, and the substring tested has to be one
  # that is actually secret: an ML-DSA secret key OPENS with rho, the
  # same 32 bytes the public key opens with, so its first characters
  # leak nothing and asserting on them tests nothing.
  tail_of_secret <- substring(key$secret, nchar(key$secret) - 31L)
  expect_false(any(grepl(tail_of_secret, out, fixed = TRUE)))
  expect_false(any(grepl(tail_of_secret, paste(out, collapse = ""),
                         fixed = TRUE)))
  expect_true(any(grepl("stateless", out)))
  pub <- format(fips_public_key(key))
  expect_true(any(grepl("ML-DSA-65", pub, fixed = TRUE)))
  expect_false(any(grepl(tail_of_secret, paste(pub, collapse = ""),
                         fixed = TRUE)))
})
