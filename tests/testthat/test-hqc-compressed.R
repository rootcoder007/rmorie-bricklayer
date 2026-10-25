test_that("a v5 key compressed to its seed decapsulates like the full key", {
  for (level in c(1L, 3L, 5L)) {
    key <- hqckg(level, seed = as.raw(seq_len(32) + level))
    small <- hqccmpkey(key)
    expect_identical(nchar(small$secret), 64L)
    # the compressed format is the last 32 bytes of ek || seed_dk || sigma ||
    # seed_KEM
    expect_identical(
      small$secret,
      substring(key$secret, nchar(key$secret) - 63L)
    )
    expect_identical(
      hqckg(level, seed = as.raw(seq_len(32) + level))$secret,
      key$secret
    )
    sent <- hqcencap(hqcpubkey(key))
    expect_identical(hqcdecap(small, sent$ciphertext), sent$shared)
    expect_identical(
      hqcdecap(small, sent$ciphertext),
      hqcdecap(key, sent$ciphertext)
    )
    expect_identical(hqccmpkey(small), small)
  }
})

test_that("a compressed key whose seed is not the key's own is refused", {
  key <- hqckg(1, seed = as.raw(1:32))
  other <- hqccmpkey(hqckg(1, seed = as.raw(32:1)))
  forged <- key
  forged$secret <- other$secret
  sent <- hqcencap(hqcpubkey(key))
  expect_error(
    hqcdecap(forged, sent$ciphertext),
    "does not derive this key's public key"
  )
})

test_that("a round-4 key compresses to its key-generation seed", {
  for (level in c(1L, 3L, 5L)) {
    n <- hqcsz(level, "round4")[["seed"]]
    seed <- as.raw((seq_len(n) * 7L + level) %% 256L)
    key <- hqckg(level, seed = seed, ver = "round4")
    small <- hqccmpkey(key)
    # the compressed form IS the seed key generation drew
    expect_identical(
      small$secret,
      paste(sprintf("%02x", as.integer(seed)), collapse = "")
    )
    sent <- hqcencap(hqcpubkey(key))
    expect_identical(nchar(sent$shared), 128L)
    expect_identical(hqcdecap(small, sent$ciphertext), sent$shared)
    expect_identical(hqccmpkey(small), small)
  }
  key <- hqckg(1, ver = "round4")
  forged <- hqccmpkey(key)
  forged$secret <- hqccmpkey(hqckg(1, ver = "round4"))$secret
  expect_error(
    hqcdecap(forged, hqcencap(hqcpubkey(key))$ciphertext),
    "does not derive this key's public key"
  )
  expect_error(hqccmpkey(list()), "must come from hqckg")
})

test_that(
  paste0(
    "a secret key of the wrong length is refused, and a compressed key ",
    "needs no public half"
  ),
  {
    key <- hqckg(1, seed = as.raw(1:32))
    bad <- key
    bad$secret <- substring(key$secret, 3L)
    expect_error(hqccmpkey(bad), "no usable HQC secret key")
    small <- hqccmpkey(key)
    sent <- hqcencap(hqcpubkey(key))
    small$public <- NULL
    expect_identical(hqcdecap(small, sent$ciphertext), sent$shared)
  }
)
