# The two operations CRAN's gcc-UBSAN run flagged in 0.5.0: HMAC with an
# empty key (null source for a zero-byte memcpy) and ML-KEM's Montgomery
# reduction (16-bit product overflowing int). Both must simply work.

test_that("HMAC-SHA-256 accepts an empty key", {
  h <- chmac(raw(0), charToRaw("msg"))
  expect_match(h, "^[0-9a-f]{64}$")
  expect_identical(h, chmac("", charToRaw("msg")))
})

test_that("ML-KEM round-trips through the widened Montgomery reduction", {
  for (lv in c(512L, 768L, 1024L)) {
    key <- kemkg(lv, seed = as.raw(1:64))
    sent <- kemencap(kempubkey(key))
    expect_identical(kemdecap(key, sent$ciphertext), sent$shared)
  }
})
