test_that("a v5 key compressed to its seed decapsulates like the full key", {
  for (level in c(1L, 3L, 5L)) {
    key <- hqc_keygen(level, seed = as.raw(seq_len(32) + level))
    small <- hqc_compress_key(key)
    expect_identical(nchar(small$secret), 64L)
    # the compressed format is the last 32 bytes of ek || seed_dk || sigma || seed_KEM
    expect_identical(small$secret, substring(key$secret, nchar(key$secret) - 63L))
    expect_identical(hqc_keygen(level, seed = as.raw(seq_len(32) + level))$secret, key$secret)
    sent <- hqc_encapsulate(hqc_public_key(key))
    expect_identical(hqc_decapsulate(small, sent$ciphertext), sent$shared)
    expect_identical(hqc_decapsulate(small, sent$ciphertext), hqc_decapsulate(key, sent$ciphertext))
    expect_identical(hqc_compress_key(small), small)
  }
})

test_that("a compressed key whose seed is not the key's own is refused", {
  key <- hqc_keygen(1, seed = as.raw(1:32))
  other <- hqc_compress_key(hqc_keygen(1, seed = as.raw(32:1)))
  forged <- key
  forged$secret <- other$secret
  sent <- hqc_encapsulate(hqc_public_key(key))
  expect_error(hqc_decapsulate(forged, sent$ciphertext), "does not derive this key's public key")
})

test_that("a round-4 key compresses to its key-generation seed", {
  for (level in c(1L, 3L, 5L)) {
    n <- hqc_sizes(level, "round4")[["seed"]]
    seed <- as.raw((seq_len(n) * 7L + level) %% 256L)
    key <- hqc_keygen(level, seed = seed, version = "round4")
    small <- hqc_compress_key(key)
    # the compressed form IS the seed key generation drew
    expect_identical(small$secret, paste(sprintf("%02x", as.integer(seed)), collapse = ""))
    sent <- hqc_encapsulate(hqc_public_key(key))
    expect_identical(nchar(sent$shared), 128L)
    expect_identical(hqc_decapsulate(small, sent$ciphertext), sent$shared)
    expect_identical(hqc_compress_key(small), small)
  }
  key <- hqc_keygen(1, version = "round4")
  forged <- hqc_compress_key(key)
  forged$secret <- hqc_compress_key(hqc_keygen(1, version = "round4"))$secret
  expect_error(hqc_decapsulate(forged, hqc_encapsulate(hqc_public_key(key))$ciphertext),
               "does not derive this key's public key")
  expect_error(hqc_compress_key(list()), "must come from hqc_keygen")
})

test_that("a secret key of the wrong length is refused, and a compressed key needs no public half", {
  key <- hqc_keygen(1, seed = as.raw(1:32))
  bad <- key
  bad$secret <- substring(key$secret, 3L)
  expect_error(hqc_compress_key(bad), "no usable HQC secret key")
  small <- hqc_compress_key(key)
  sent <- hqc_encapsulate(hqc_public_key(key))
  small$public <- NULL
  expect_identical(hqc_decapsulate(small, sent$ciphertext), sent$shared)
})
