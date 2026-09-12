# Signed provenance: keyed digests and post-quantum hash-based
# signatures.
#
# A signature scheme cannot be anchored on an external reference value
# here (no RFC 8391 known-answer vectors were available offline), so it
# is verified against the properties that MUST hold for it to be worth
# anything: a genuine signature verifies, and every way of tampering
# with the message, the signature, the authentication path, the index or
# the key fails. Each of those is a test that the implementation could
# fail, which is what makes them worth running.

test_that("the always-available backend is reported", {
  b <- pqc_backends()
  expect_type(b, "character")
  expect_true("xmss-sha256" %in% b)
  expect_true(length(b) >= 1L)
})

test_that("HMAC signing authenticates and rejects tampering", {
  sig <- capsule_sign("sha256:abc123", key = "shared-secret",
                      scheme = "hmac")
  expect_s3_class(sig, "bricklayer_signature")
  expect_equal(sig$scheme, "hmac")
  expect_match(sig$signature, "^[0-9a-f]{64}$")
  expect_true(capsule_verify("sha256:abc123", sig, "shared-secret"))

  # every way of being wrong fails
  expect_false(capsule_verify("sha256:TAMPERED", sig, "shared-secret"))
  expect_false(capsule_verify("sha256:abc123", sig, "wrong-secret"))
  expect_false(capsule_verify("", sig, "shared-secret"))
  bad <- sig
  bad$signature <- paste0("ff", substring(sig$signature, 3L))
  expect_false(capsule_verify("sha256:abc123", bad, "shared-secret"))

  # the tag is exactly the keyed digest, and deterministic
  expect_equal(sig$signature,
               core_hmac_sha256("shared-secret", "sha256:abc123"))
  expect_equal(capsule_sign("sha256:abc123", "shared-secret",
                            "hmac")$signature, sig$signature)
  # the scheme is inferred when the key is a bare secret
  expect_equal(capsule_sign("m", "k")$scheme, "hmac")
  # raw keys and messages work
  expect_true(capsule_verify(charToRaw("m"),
                             capsule_sign(charToRaw("m"), "k", "hmac"), "k"))
})

test_that("a post-quantum key generates deterministically from its seeds", {
  s1 <- paste(rep("11", 32), collapse = "")
  s2 <- paste(rep("22", 32), collapse = "")
  key <- pqc_keygen(height = 3, sk_seed = s1, pub_seed = s2)
  expect_s3_class(key, "bricklayer_signing_key")
  expect_equal(key$scheme, "xmss-sha256")
  expect_match(key$root, "^[0-9a-f]{64}$")
  expect_equal(key$height, 3L)
  expect_equal(key$capacity, 8L)
  expect_equal(key$next_index, 0L)

  # the same seeds reproduce the same public root
  expect_equal(pqc_keygen(3, s1, s2)$root, key$root)
  # and any change to either seed, or the height, changes it
  expect_false(identical(pqc_keygen(3, paste(rep("12", 32), collapse = ""),
                                    s2)$root, key$root))
  expect_false(identical(pqc_keygen(3, s1,
                                    paste(rep("23", 32), collapse = ""))$root,
                         key$root))
  expect_false(identical(pqc_keygen(4, s1, s2)$root, key$root))
  # capacity is 2^height
  expect_equal(pqc_keygen(1, s1, s2)$capacity, 2L)
  expect_equal(pqc_keygen(5, s1, s2)$capacity, 32L)
  # a key generated without seeds is unpredictable
  expect_false(identical(pqc_keygen(2)$root, pqc_keygen(2)$root))

  # the public half carries no secret
  pub <- signing_public_key(key)
  expect_s3_class(pub, "bricklayer_public_key")
  expect_null(pub$sk_seed)
  expect_equal(pub$root, key$root)
  expect_equal(pub$height, key$height)

  expect_error(pqc_keygen(3, "abc", s2), "64 hex characters")
  expect_error(pqc_keygen(3, s1, "zz"), "64 hex characters")
  expect_error(pqc_keygen(0), "between 1 and 16")
  expect_error(pqc_keygen(17), "between 1 and 16")
  expect_error(signing_public_key(list()), "pqc_keygen")
})

test_that("a post-quantum signature verifies and resists every forgery", {
  key <- pqc_keygen(height = 3, sk_seed = paste(rep("aa", 32), collapse = ""),
                    pub_seed = paste(rep("bb", 32), collapse = ""))
  pub <- signing_public_key(key)
  msg <- "capsule manifest sha256:deadbeef"
  sig <- capsule_sign(msg, key)

  expect_s3_class(sig, "bricklayer_signature")
  expect_equal(sig$scheme, "xmss-sha256")
  expect_equal(sig$index, 0L)
  expect_equal(sig$root, key$root)
  # 67 Winternitz chains of 32 bytes, and a path of `height` nodes
  expect_equal(nchar(sig$signature) / 2, 67 * 32)
  expect_equal(nchar(sig$auth) / 2, 3 * 32)

  expect_true(capsule_verify(msg, sig, pub))
  # verifying from the full key works too
  expect_true(capsule_verify(msg, sig, key))

  # the message is bound to the signature
  expect_false(capsule_verify("capsule manifest sha256:deadbeeg", sig, pub))
  expect_false(capsule_verify("", sig, pub))
  # so is every byte of the signature and the authentication path
  flip <- function(h, pos) {
    ch <- substring(h, pos, pos)
    paste0(substring(h, 1L, pos - 1L), if (ch == "a") "b" else "a",
           substring(h, pos + 1L))
  }
  bad <- sig; bad$signature <- flip(sig$signature, 7L)
  expect_false(capsule_verify(msg, bad, pub))
  bad2 <- sig; bad2$auth <- flip(sig$auth, 3L)
  expect_false(capsule_verify(msg, bad2, pub))
  # and the leaf index
  bad3 <- sig; bad3$index <- 1L
  expect_false(capsule_verify(msg, bad3, pub))
  # a foreign key does not verify it
  expect_false(capsule_verify(msg, sig, signing_public_key(pqc_keygen(3))))
  # nor does the right root under the wrong public seed
  wrongseed <- pub
  wrongseed$pub_seed <- paste(rep("cc", 32), collapse = "")
  expect_false(capsule_verify(msg, sig, wrongseed))

  # malformed input is "not verified", never an error a caller might
  # catch and ignore
  for (mangle in list(
    function(s) { s$signature <- substring(s$signature, 1L, 64L); s },
    function(s) { s$signature <- substring(s$signature, 1L,
                                           nchar(s$signature) - 1L); s },
    function(s) { s$signature <- paste0("zz", substring(s$signature, 3L)); s },
    function(s) { s$auth <- substring(s$auth, 1L, 64L); s },
    function(s) { s$auth <- ""; s })) {
    expect_false(capsule_verify(msg, mangle(sig), pub))
  }
})

test_that("every leaf of the tree signs under one public root", {
  key <- pqc_keygen(height = 3, sk_seed = paste(rep("0f", 32), collapse = ""),
                    pub_seed = paste(rep("f0", 32), collapse = ""))
  pub <- signing_public_key(key)
  root <- key$root

  sigs <- list()
  for (i in seq_len(8L)) {
    s <- capsule_sign(paste0("manifest-", i), key)
    expect_equal(s$index, i - 1L)
    expect_equal(s$root, root)
    expect_true(capsule_verify(paste0("manifest-", i), s, pub))
    sigs[[i]] <- s
    # the returned state is what advances the index
    key <- s$key_state
    expect_equal(key$next_index, i)
  }
  # the key is now exhausted, and says so rather than wrapping around and
  # silently reusing a leaf
  expect_error(capsule_sign("one-too-many", key), "exhausted")

  # signatures do not transfer between messages or between leaves
  expect_false(capsule_verify("manifest-2", sigs[[1]], pub))
  expect_false(capsule_verify("manifest-1", sigs[[2]], pub))
  # every signature is distinct even though the root is shared
  expect_equal(length(unique(vapply(sigs, function(s) s$signature,
                                    character(1)))), 8L)
  # the same message at two indices gives two different signatures
  k2 <- pqc_keygen(2, paste(rep("01", 32), collapse = ""),
                   paste(rep("02", 32), collapse = ""))
  a <- capsule_sign("same", k2)
  b <- capsule_sign("same", a$key_state)
  expect_false(identical(a$signature, b$signature))
  expect_true(capsule_verify("same", a, signing_public_key(k2)))
  expect_true(capsule_verify("same", b, signing_public_key(k2)))
})

test_that("signing rejects the inputs it cannot honour", {
  key <- pqc_keygen(height = 1, sk_seed = paste(rep("07", 32), collapse = ""),
                    pub_seed = paste(rep("70", 32), collapse = ""))
  expect_error(capsule_sign(c("a", "b"), key), "length-1")
  expect_error(capsule_sign("m", list(), scheme = "xmss"), "pqc_keygen")
  expect_error(capsule_verify("m", list(), key), "capsule_sign")
  sig <- capsule_sign("m", key)
  expect_error(capsule_verify("m", sig, "not-a-key"), "pqc_keygen")
  # a raw message signs and verifies on the next unused leaf
  r <- capsule_sign(charToRaw("abc"), sig$key_state)
  expect_equal(r$index, 1L)
  expect_true(capsule_verify(charToRaw("abc"), r, signing_public_key(key)))
})

test_that("a signed manifest digest is the intended end-to-end use", {
  # the realistic flow: hash the manifest, sign the digest, publish the
  # public key, and let a third party check both
  manifest <- paste0("source=https://example.org/data.csv\n",
                     "sha256=", core_sha256("the,data\n1,2\n"), "\n",
                     "fetched=2026-09-12")
  digest <- core_sha256(manifest)
  key <- pqc_keygen(height = 2)
  sig <- capsule_sign(digest, key)
  pub <- signing_public_key(key)

  expect_true(capsule_verify(digest, sig, pub))
  # an edited manifest produces a different digest, which the signature
  # does not cover
  edited <- sub("fetched=2026-09-12", "fetched=2026-01-01", manifest)
  expect_false(identical(core_sha256(edited), digest))
  expect_false(capsule_verify(core_sha256(edited), sig, pub))

  # the same flow with a Merkle root over the data's chunks
  chunks <- c("the,data", "1,2", "3,4")
  root <- merkle_root(chunks)
  rsig <- capsule_sign(root, sig$key_state)
  expect_true(capsule_verify(root, rsig, pub))
  expect_false(capsule_verify(merkle_root(c(chunks[1:2], "3,5")), rsig, pub))
})
