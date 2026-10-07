# rmoriebricklayer 0.5.10: the C2SP Wycheproof post-quantum vectors and the NIST ACVP sets.
# The full pinned sets (about 10,000 tests) run in .github/workflows/vectors.yml through
# tools/vectors; this file runs the offline subset in tests/testthat/vectors (one Wycheproof
# test per result/flags class, one ACVP test per group) through the same runner
# (helper-vectors.R), and pins the new code paths those vectors reach.

dig <- function(nm, x) {
  paste(as.character(.Call(rmoriebricklayer:::C_rmbl_prehash_digest, nm, charToRaw(x))), collapse = "")
}

test_that("the offline vector subset passes with no failures", {
  skip_on_cran() # a few seconds of signing; the full sets run in CI
  vec <- test_path("vectors")
  skip_if_not(dir.exists(vec))
  tot <- rmbl_run_vectors(vec)
  fails <- unlist(lapply(tot, `[[`, "failures"))
  expect_identical(fails, character())
  expect_gt(sum(vapply(tot, `[[`, 0L, "pass")), 300L)
  # every family is represented
  expect_true(all(c("ML-KEM-encapDecap-FIPS203", "ML-DSA-sigGen-FIPS204", "SLH-DSA-sigVer-FIPS205",
                    "SHA3-256-2.0", "mlkem_768_test.json", "mldsa_65_verify_test.json") %in% names(tot)))
})

test_that("all twelve FIPS 204/205 pre-hash digests match OpenSSL on \"abc\"", {
  ref <- c(
    sha224 = "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7",
    sha256 = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    sha384 = paste0("cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed",
                    "8086072ba1e7cc2358baeca134c825a7"),
    sha512 = paste0("ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a",
                    "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"),
    sha512_224 = "4634270f707b6a54daae7530460842e20e37ed265ceee9a43e8924aa",
    sha512_256 = "53048e2681941ef99b2e29b76b4c7dabe4c2d0c634fc6d46e0e2f13107e7af23",
    sha3_224 = "e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf",
    sha3_256 = "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532",
    sha3_384 = paste0("ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b2",
                      "98d88cea927ac7f539f1edf228376d25"),
    sha3_512 = paste0("b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e",
                      "10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0"),
    shake128 = "5881092dd818bf5cf8a3ddb793fbcba74097d5c526a6d35f97b83351940f2cc8",
    shake256 = paste0("483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739",
                      "d5a15bef186a5386c75744c0527e1faa9f8726e462a12a4feb06bd8801e751e4")
  )
  for (nm in names(ref)) expect_identical(dig(nm, "abc"), ref[[nm]], info = nm)
  expect_error(dig("md5", "abc"), "must be one of none, sha224")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_prehash_digest, "sha256", "abc"), "raw vector")
})

test_that("every pre-hash signs and verifies, and is bound to its own OID", {
  key <- fips_keygen("ML-DSA-44", seed = as.raw(1:32))
  pub <- fips_public_key(key)
  for (ph in c("sha224", "sha384", "sha512_224", "sha512_256", "sha3_224", "sha3_256",
               "sha3_384", "sha3_512")) {
    sig <- capsule_sign("a manifest", key, prehash = ph, deterministic = TRUE)
    expect_true(capsule_verify("a manifest", sig, pub), info = ph)
    # SHA-512/224 and SHA3-224 have the same digest length: the OID keeps them apart
    other <- if (ph == "sha512_224") "sha3_224" else "sha512_224"
    expect_false(capsule_verify("a manifest", sig, pub, prehash = other), info = ph)
  }
})

test_that("ML-KEM decapsulation refuses a key that fails the FIPS 203 hash check", {
  kp <- .Call(rmoriebricklayer:::C_rmbl_mlkem_keygen, 768L, as.raw(rep(7L, 64L)))
  dk <- kp[[2]]
  ct <- .Call(rmoriebricklayer:::C_rmbl_mlkem_encaps, 768L, kp[[1]], as.raw(rep(9L, 32L)))
  expect_identical(.Call(rmoriebricklayer:::C_rmbl_mlkem_decaps, 768L, dk, ct$ciphertext), ct$shared)
  # flip one byte of the stored H(ek): the key no longer describes its own public half
  bad <- dk
  h_at <- length(dk) - 64L + 1L
  bad[h_at] <- xor(bad[h_at], as.raw(1L))
  expect_error(.Call(rmoriebricklayer:::C_rmbl_mlkem_decaps, 768L, bad, ct$ciphertext),
               "FIPS 203 hash check")
  # and through the exported interface
  key <- kem_keygen(512L, seed = as.raw(rep(3L, 64L)))
  cap <- kem_encapsulate(key, m = as.raw(rep(5L, 32L)))
  expect_identical(kem_decapsulate(key, cap$ciphertext), cap$shared)
})

test_that("SLH-DSA internal signing is FIPS 205 slh_sign_internal and differs from the public interface", {
  set <- "SLH-DSA-SHAKE-128f"
  kp <- .Call(rmoriebricklayer:::C_rmbl_slhdsa_keypair, set, as.raw(1:48))
  msg <- charToRaw("an internal message")
  opt <- kp[[2]][33:48] # PK.seed: the deterministic variant
  sig <- .Call(rmoriebricklayer:::C_rmbl_slhdsa_sign_internal, set, kp[[2]], msg, opt)
  expect_true(.Call(rmoriebricklayer:::C_rmbl_slhdsa_verify_internal, set, kp[[1]], msg, sig))
  # the public interface signs M' = 0x00 || 0x00 || M, so the two signatures differ
  ext <- .Call(rmoriebricklayer:::C_rmbl_slhdsa_sign, set, kp[[2]], msg, raw(0), opt, "none")
  expect_false(identical(sig, ext))
  # ... and an internal signature over exactly that M' is the external signature
  mprime <- c(as.raw(c(0, 0)), msg)
  expect_identical(.Call(rmoriebricklayer:::C_rmbl_slhdsa_sign_internal, set, kp[[2]], mprime, opt), ext)
  expect_false(.Call(rmoriebricklayer:::C_rmbl_slhdsa_verify_internal, set, kp[[1]], msg, ext))
  expect_false(.Call(rmoriebricklayer:::C_rmbl_slhdsa_verify_internal, set, kp[[1]][-1], msg, sig))
  expect_error(.Call(rmoriebricklayer:::C_rmbl_slhdsa_sign_internal, set, kp[[2]], msg, raw(3)), "opt_rand")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_slhdsa_sign_internal, set, kp[[2]][-1], msg, opt), "`sk`")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_slhdsa_sign_internal, set, kp[[2]], "x", opt), "raw vector")
})
