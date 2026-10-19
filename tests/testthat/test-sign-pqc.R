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
  b <- pqcbknd()
  expect_type(b, "character")
  expect_true("xmss-sha256" %in% b)
  expect_true(length(b) >= 1L)
})

test_that("HMAC signing authenticates and rejects tampering", {
  sig <- cpssign("sha256:abc123",
    key = "shared-secret",
    scheme = "hmac"
  )
  expect_s3_class(sig, "bricklayer_signature")
  expect_equal(sig$scheme, "hmac")
  expect_match(sig$signature, "^[0-9a-f]{64}$")
  expect_true(cpsvrf("sha256:abc123", sig, "shared-secret"))

  # every way of being wrong fails
  expect_false(cpsvrf("sha256:TAMPERED", sig, "shared-secret"))
  expect_false(cpsvrf("sha256:abc123", sig, "wrong-secret"))
  expect_false(cpsvrf("", sig, "shared-secret"))
  bad <- sig
  bad$signature <- paste0("ff", substring(sig$signature, 3L))
  expect_false(cpsvrf("sha256:abc123", bad, "shared-secret"))

  # the tag is exactly the keyed digest, and deterministic
  expect_equal(
    sig$signature,
    chmac("shared-secret", "sha256:abc123")
  )
  expect_equal(cpssign(
    "sha256:abc123", "shared-secret",
    "hmac"
  )$signature, sig$signature)
  # the scheme is inferred when the key is a bare secret
  expect_equal(cpssign("m", "k")$scheme, "hmac")
  # raw keys and messages work
  expect_true(cpsvrf(
    charToRaw("m"),
    cpssign(charToRaw("m"), "k", "hmac"), "k"
  ))
})

test_that("a post-quantum key generates deterministically from its seeds", {
  s1 <- paste(rep("11", 32), collapse = "")
  s2 <- paste(rep("22", 32), collapse = "")
  key <- pqckg(height = 3, skseed = s1, pubseed = s2)
  expect_s3_class(key, "bricklayer_signing_key")
  expect_equal(key$scheme, "xmss-sha256")
  expect_match(key$root, "^[0-9a-f]{64}$")
  expect_equal(key$height, 3L)
  expect_equal(key$capacity, 8L)
  expect_equal(key$next_index, 0L)

  # the same seeds reproduce the same public root
  expect_equal(pqckg(3, s1, s2)$root, key$root)
  # and any change to either seed, or the height, changes it
  expect_false(identical(pqckg(
    3, paste(rep("12", 32), collapse = ""),
    s2
  )$root, key$root))
  expect_false(identical(
    pqckg(
      3, s1,
      paste(rep("23", 32), collapse = "")
    )$root,
    key$root
  ))
  expect_false(identical(pqckg(4, s1, s2)$root, key$root))
  # capacity is 2^height
  expect_equal(pqckg(1, s1, s2)$capacity, 2L)
  expect_equal(pqckg(5, s1, s2)$capacity, 32L)
  # a key generated without seeds is unpredictable
  expect_false(identical(pqckg(2)$root, pqckg(2)$root))

  # the public half carries no secret
  pub <- signpubkey(key)
  expect_s3_class(pub, "bricklayer_public_key")
  expect_null(pub$skseed)
  expect_equal(pub$root, key$root)
  expect_equal(pub$height, key$height)

  expect_error(pqckg(3, "abc", s2), "64 hex characters")
  expect_error(pqckg(3, s1, "zz"), "64 hex characters")
  expect_error(pqckg(0), "between 1 and 16")
  expect_error(pqckg(17), "between 1 and 16")
  expect_error(signpubkey(list()), "pqckg")
})

test_that("a post-quantum signature verifies and resists every forgery", {
  key <- pqckg(
    height = 3, skseed = paste(rep("aa", 32), collapse = ""),
    pubseed = paste(rep("bb", 32), collapse = "")
  )
  xmssregkey(key)   # a key from given seeds is not registered at birth (review of 52a8883)
  pub <- signpubkey(key)
  msg <- "capsule manifest sha256:deadbeef"
  sig <- cpssign(msg, key)

  expect_s3_class(sig, "bricklayer_signature")
  expect_equal(sig$scheme, "xmss-sha256")
  expect_equal(sig$index, 0L)
  expect_equal(sig$root, key$root)
  # 67 Winternitz chains of 32 bytes, and a path of `height` nodes
  expect_equal(nchar(sig$signature) / 2, 67 * 32)
  expect_equal(nchar(sig$auth) / 2, 3 * 32)

  expect_true(cpsvrf(msg, sig, pub))
  # verifying from the full key works too
  expect_true(cpsvrf(msg, sig, key))

  # the message is bound to the signature
  expect_false(cpsvrf("capsule manifest sha256:deadbeeg", sig, pub))
  expect_false(cpsvrf("", sig, pub))
  # so is every byte of the signature and the authentication path
  flip <- function(h, pos) {
    ch <- substring(h, pos, pos)
    paste0(
      substring(h, 1L, pos - 1L), if (ch == "a") "b" else "a",
      substring(h, pos + 1L)
    )
  }
  bad <- sig
  bad$signature <- flip(sig$signature, 7L)
  expect_false(cpsvrf(msg, bad, pub))
  bad2 <- sig
  bad2$auth <- flip(sig$auth, 3L)
  expect_false(cpsvrf(msg, bad2, pub))
  # and the leaf index
  bad3 <- sig
  bad3$index <- 1L
  expect_false(cpsvrf(msg, bad3, pub))
  # a foreign key does not verify it
  expect_false(cpsvrf(msg, sig, signpubkey(pqckg(3))))
  # nor does the right root under the wrong public seed
  wrongseed <- pub
  wrongseed$pubseed <- paste(rep("cc", 32), collapse = "")
  expect_false(cpsvrf(msg, sig, wrongseed))

  # malformed input is "not verified", never an error a caller might
  # catch and ignore
  for (mangle in list(
    function(s) {
      s$signature <- substring(s$signature, 1L, 64L)
      s
    },
    function(s) {
      s$signature <- substring(
        s$signature, 1L,
        nchar(s$signature) - 1L
      )
      s
    },
    function(s) {
      s$signature <- paste0("zz", substring(s$signature, 3L))
      s
    },
    function(s) {
      s$auth <- substring(s$auth, 1L, 64L)
      s
    },
    function(s) {
      s$auth <- ""
      s
    }
  )) {
    expect_false(cpsvrf(msg, mangle(sig), pub))
  }
})

test_that("every leaf of the tree signs under one public root", {
  key <- pqckg(
    height = 3, skseed = paste(rep("0f", 32), collapse = ""),
    pubseed = paste(rep("f0", 32), collapse = "")
  )
  xmssregkey(key)   # a key from given seeds is not registered at birth (review of 52a8883)
  pub <- signpubkey(key)
  root <- key$root

  sigs <- list()
  for (i in seq_len(8L)) {
    s <- cpssign(paste0("manifest-", i), key)
    expect_equal(s$index, i - 1L)
    expect_equal(s$root, root)
    expect_true(cpsvrf(paste0("manifest-", i), s, pub))
    sigs[[i]] <- s
    # the returned state is what advances the index
    if (i < 8L) key <- xmssadv(key, s) else expect_warning(key <- xmssadv(key, s), "used all 8")
    expect_equal(key$next_index, i)
  }
  # the key is now exhausted, and says so rather than wrapping around and
  # silently reusing a leaf
  expect_error(cpssign("one-too-many", key), "exhausted")

  # signatures do not transfer between messages or between leaves
  expect_false(cpsvrf("manifest-2", sigs[[1]], pub))
  expect_false(cpsvrf("manifest-1", sigs[[2]], pub))
  # every signature is distinct even though the root is shared
  expect_equal(length(unique(vapply(
    sigs, function(s) s$signature,
    character(1)
  ))), 8L)
  # the same message at two indices gives two different signatures
  k2 <- pqckg(
    2, paste(rep("01", 32), collapse = ""),
    paste(rep("02", 32), collapse = "")
  )
  xmssregkey(k2)
  a <- cpssign("same", k2)
  b <- cpssign("same", xmssadv(k2, a))
  expect_false(identical(a$signature, b$signature))
  expect_true(cpsvrf("same", a, signpubkey(k2)))
  expect_true(cpsvrf("same", b, signpubkey(k2)))
})

test_that("signing rejects the inputs it cannot honour", {
  key <- pqckg(
    height = 1, skseed = paste(rep("07", 32), collapse = ""),
    pubseed = paste(rep("70", 32), collapse = "")
  )
  xmssregkey(key)   # a key from given seeds is not registered at birth (review of 52a8883)
  expect_error(cpssign(c("a", "b"), key), "length-1")
  expect_error(cpssign("m", list(), scheme = "xmss"), "pqckg")
  expect_error(cpsvrf("m", list(), key), "cpssign")
  sig <- cpssign("m", key)
  expect_error(cpsvrf("m", sig, "not-a-key"), "pqckg")
  # a raw message signs and verifies on the next unused leaf
  r <- cpssign(charToRaw("abc"), xmssadv(key, sig))
  expect_equal(r$index, 1L)
  expect_true(cpsvrf(charToRaw("abc"), r, signpubkey(key)))
})

test_that("a signed manifest digest is the intended end-to-end use", {
  # the realistic flow: hash the manifest, sign the digest, publish the
  # public key, and let a third party check both
  manifest <- paste0(
    "source=https://example.org/data.csv\n",
    "sha256=", csha256("the,data\n1,2\n"), "\n",
    "fetched=2026-09-12"
  )
  digest <- csha256(manifest)
  key <- pqckg(height = 2)
  sig <- cpssign(digest, key)
  pub <- signpubkey(key)

  expect_true(cpsvrf(digest, sig, pub))
  # an edited manifest produces a different digest, which the signature
  # does not cover
  edited <- sub("fetched=2026-09-12", "fetched=2026-01-01", manifest)
  expect_false(identical(csha256(edited), digest))
  expect_false(cpsvrf(csha256(edited), sig, pub))

  # the same flow with a Merkle root over the data's chunks
  chunks <- c("the,data", "1,2", "3,4")
  root <- mrkroot(chunks)
  rsig <- cpssign(root, xmssadv(key, sig))
  expect_true(cpsvrf(root, rsig, pub))
  expect_false(cpsvrf(mrkroot(c(chunks[1:2], "3,5")), rsig, pub))
})

test_that("an XMSS index never signs twice: one key object, or a stale copy, is refused", {
  key <- pqckg(height = 3)
  s1 <- cpssign("message one", key)
  expect_identical(s1$index, 0L)
  # the same key object again: index 0 is spent
  expect_error(cpssign("message two", key), "index 0 of this key was already used")
  s2 <- cpssign("message two", xmssadv(key, s1))
  expect_identical(s2$index, 1L)
  # a stale copy (the state after the first signature) is refused too; advancing it with
  # xmssadv() consults the record and moves it past every used index instead
  stale <- key
  stale$next_index <- 1L
  expect_error(cpssign("message three", stale), "index 1 of this key was already used")
  expect_identical(xmssadv(key, s1)$next_index, 2L)
  s3 <- cpssign("message three", xmssadv(key, s2))
  expect_identical(s3$index, 2L)
  pub <- signpubkey(key)
  expect_true(all(c(cpsvrf("message one", s1, pub), cpsvrf("message two", s2, pub),
                    cpsvrf("message three", s3, pub))))
  # another key is independent
  other <- pqckg(height = 2)
  expect_identical(cpssign("m", other)$index, 0L)
})

test_that("a damaged next_index is refused in words", {
  key <- pqckg(height = 2)
  for (bad in list(NA, -1L, 1.5, c(0L, 1L), "0")) {
    k <- key
    k$next_index <- bad
    expect_error(cpssign("m", k), "not a whole number >= 0", info = deparse(bad))
  }
})
