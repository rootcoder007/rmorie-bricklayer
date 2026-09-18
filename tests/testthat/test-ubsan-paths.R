# The two operations CRAN's gcc-UBSAN run flagged in 0.5.0: HMAC with an
# empty key (null source for a zero-byte memcpy) and ML-KEM's Montgomery
# reduction (16-bit product overflowing int). Both must simply work.

test_that("HMAC-SHA-256 accepts an empty key", {
  h <- core_hmac_sha256(raw(0), charToRaw("msg"))
  expect_match(h, "^[0-9a-f]{64}$")
  expect_identical(h, core_hmac_sha256("", charToRaw("msg")))
})

test_that("ML-KEM round-trips through the widened Montgomery reduction", {
  for (lv in c(512L, 768L, 1024L)) {
    key <- kem_keygen(lv, seed = as.raw(1:64))
    sent <- kem_encapsulate(kem_public_key(key))
    expect_identical(kem_decapsulate(key, sent$ciphertext), sent$shared)
  }
})
