# FIPS 202 known answers for SHA-3 and SHAKE, which every scheme above them
# (ML-KEM, ML-DSA, SLH-DSA, HQC) rests on. The OpenSSL cross-checks of those
# schemes exercise Keccak only transitively; these pin the primitive itself.
# Values: Python's hashlib (the CPython implementation is validated against
# the NIST vectors), reproduced here as strings.

shake <- function(which, x, n = 0L) {
  r <- .Call(rmoriebricklayer:::C_rmbl_shake, as.integer(which),
             if (is.character(x)) x else as.raw(x), as.integer(n))
  paste(sprintf("%02x", as.integer(r)), collapse = "")
}

test_that("SHA3-256 and SHA3-512 match FIPS 202", {
  expect_identical(shake(3256, ""),
                   "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a")
  expect_identical(shake(3256, "abc"),
                   "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532")
  expect_identical(shake(3256, strrep("a", 200)),
                   "cce34485baf2bf2aca99b94833892a4f52896d3d153f7b840cc4f9fe695f1387")
  expect_identical(shake(3512, ""),
                   paste0("a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a6",
                          "15b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26"))
  expect_identical(shake(3512, "abc"),
                   paste0("b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e",
                          "10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0"))
})

test_that("SHAKE128 and SHAKE256 match FIPS 202 at several output lengths", {
  expect_identical(shake(128, "", 32),
                   "7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26")
  expect_identical(shake(128, "abc", 32),
                   "5881092dd818bf5cf8a3ddb793fbcba74097d5c526a6d35f97b83351940f2cc8")
  expect_identical(shake(256, "", 64),
                   paste0("46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f",
                          "d75dc4ddd8c0f200cb05019d67b592f6fc821c49479ab48640292eacb3b7c4be"))
  expect_identical(shake(256, "abc", 64),
                   paste0("483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739",
                          "d5a15bef186a5386c75744c0527e1faa9f8726e462a12a4feb06bd8801e751e4"))
  # an output longer than one rate block (136 bytes for SHAKE256) squeezes twice
  expect_identical(shake(256, strrep("a", 200), 100),
                   paste0("e49647491c9d12d125a2f75826c96f6307d2fabebcbb9fb1616d76b09499380e",
                          "8bcf60f72750879140e73fb7453a979b69d25efa8de613462f108ce7f2f1d7c5",
                          "e444637301336604f42850beddef9434234ccc7d84196841069a7105379ca1e5",
                          "c6f79db0"))
  # a prefix of a longer squeeze is the shorter squeeze
  expect_identical(substr(shake(128, "abc", 64), 1L, 64L), shake(128, "abc", 32))
  expect_error(shake(7, "abc", 4), "unknown function selector")
})
