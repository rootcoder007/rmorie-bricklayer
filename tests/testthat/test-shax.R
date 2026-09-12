# SHA-512, HMAC and MGF1: the SHA-2 half of FIPS 205 rests on all three.
#
# Anchored on the published vectors -- FIPS 180-4 for SHA-512, RFC 4231
# for HMAC -- and on the definition itself for MGF1, whose blocks are
# just H(seed || counter) and can therefore be recomputed here from the
# package's own SHA-256 without assuming the MGF1 code is right.

test_that("SHA-512 matches the FIPS 180-4 vectors", {
  expect_identical(
    core_sha512("abc"),
    paste0("ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55",
           "d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94f",
           "a54ca49f"))
  expect_identical(
    core_sha512(raw(0)),
    paste0("cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36c",
           "e9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327a",
           "f927da3e"))
  # The padding boundary: a message of 112 bytes leaves exactly room for
  # the 16-byte length field, 113 does not and needs a second block.
  # Getting that branch wrong is invisible on short inputs.
  lens <- c(111L, 112L, 113L, 128L)
  got <- vapply(lens, function(n) {
    substring(core_sha512(strrep("a", n)), 1L, 16L)
  }, character(1))
  expect_identical(got, c("fa9121c7b32b9e01", "c01d080efd492776",
                          "55ddd8ac210a6e18", "b73d1929aa615934"))
})

test_that("HMAC matches the RFC 4231 vectors", {
  key <- as.raw(rep(0x0b, 20L))
  msg <- charToRaw("Hi There")
  expect_identical(
    .rmbl_hexlify(.Call(C_rmbl_hmac_shax, 512L, key, msg)),
    paste0("87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e1",
           "7cdedaa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c20",
           "3a126854"))
  expect_identical(
    .rmbl_hexlify(.Call(C_rmbl_hmac_shax, 256L, key, msg)),
    "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7")
  # RFC 4231 case 2, a key shorter than the block
  expect_identical(
    .rmbl_hexlify(.Call(C_rmbl_hmac_shax, 256L, charToRaw("Jefe"),
                        charToRaw("what do ya want for nothing?"))),
    "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843")
  # A key LONGER than the block is hashed first, which is the branch a
  # short-key-only test never reaches.
  expect_identical(
    .rmbl_hexlify(.Call(C_rmbl_hmac_shax, 256L, as.raw(rep(0xaa, 131L)),
                        charToRaw("Test Using Larger Than Block-Size Key - Hash Key First"))),
    "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54")
  expect_error(.Call(C_rmbl_hmac_shax, 384L, key, msg), "256 or 512")
})

test_that("MGF1 is its definition, recomputed independently", {
  seed <- charToRaw("seed")
  got <- .Call(C_rmbl_mgf1, 256L, seed, 40L)
  # H(seed || 00000000) || H(seed || 00000001), truncated
  want <- c(.rmbl_hex_to_raw(core_sha256(c(seed, as.raw(c(0, 0, 0, 0))))),
            .rmbl_hex_to_raw(core_sha256(c(seed, as.raw(c(0, 0, 0, 1))))))
  expect_identical(got, want[seq_len(40L)])
  # a length shorter than one block is a plain truncation
  expect_identical(.Call(C_rmbl_mgf1, 256L, seed, 7L), want[seq_len(7L)])
  # and the 512-bit variant walks the same counter
  g5 <- .Call(C_rmbl_mgf1, 512L, seed, 100L)
  w5 <- c(.rmbl_hex_to_raw(core_sha512(c(seed, as.raw(c(0, 0, 0, 0))))),
          .rmbl_hex_to_raw(core_sha512(c(seed, as.raw(c(0, 0, 0, 1))))))
  expect_identical(g5, w5[seq_len(100L)])
  # an output spanning exactly one block must not consume a second
  expect_identical(.Call(C_rmbl_mgf1, 256L, seed, 32L), want[seq_len(32L)])
  expect_error(.Call(C_rmbl_mgf1, 256L, seed, 0L), "positive")
})
