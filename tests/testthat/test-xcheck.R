# cpsxvrf(): a second verdict on a signature from OpenSSL 3.5

has_ossl35 <- function() {
  o <- Sys.which("openssl")
  if (!nzchar(o)) {
    return(FALSE)
  }
  v <- .rmbl_xvrf_version(o)$number
  !is.na(v) && utils::compareVersion(v, "3.5.0") >= 0
}

test_that("OpenSSL and this package agree on ML-DSA and SLH-DSA", {
  skip_on_cran()
  skip_if_not(has_ossl35(), "OpenSSL 3.5 or later is not installed")
  for (s in c("ML-DSA-44", "ML-DSA-87", "SLH-DSA-SHA2-128f",
              "SLH-DSA-SHAKE-128f")) {
    k <- fipskg(s)
    sg <- cpssign("manifest 1", k, ctx = "release")
    r <- cpsxvrf("manifest 1", sg, fipspubkey(k), ctx = "release")
    expect_true(r$ok, info = s)
    expect_true(r$agree, info = s)
    expect_match(r$version, "^OpenSSL [0-9]")
    # a changed message, a wrong context, a wrong key: both reject
    bad <- cpsxvrf("manifest 2", sg, k, ctx = "release")
    expect_false(bad$ok, info = s)
    expect_identical(c(bad$ours, bad$openssl), c(FALSE, FALSE))
    expect_false(cpsxvrf("manifest 1", sg, k, ctx = "staging")$openssl)
    other <- fipskg(s)
    expect_false(cpsxvrf("manifest 1", sg, other, ctx = "release")$openssl)
  }
  # a binary context goes through as hex; no context at all works too
  k <- fipskg("ML-DSA-65")
  cx <- as.raw(c(0, 1, 255))
  expect_true(cpsxvrf("m", cpssign("m", k, ctx = cx), k, ctx = cx)$ok)
  expect_true(cpsxvrf(charToRaw("m"), cpssign("m", k), k)$ok)
})

test_that("the default SLH-DSA-SHA2-128s key cross-verifies", {
  skip_on_cran()
  skip_if_not(has_ossl35(), "OpenSSL 3.5 or later is not installed")
  k <- fipskg()
  expect_identical(k$scheme, "SLH-DSA-SHA2-128s")
  r <- cpsxvrf("a capsule digest", cpssign("a capsule digest", k), k)
  expect_true(r$ok)
  out <- expect_box2(r, "VERIFIED by both implementations",
                     c("SLH-DSA-SHA2-128s", "accepts", "share no code"))
  expect_false(any(grepl(k$secret, out, fixed = TRUE)))
})

test_that("without OpenSSL the verdict is ours alone, and says so", {
  k <- fipskg("ML-DSA-44")
  sg <- cpssign("m", k)
  r <- cpsxvrf("m", sg, k, openssl = "")
  expect_true(r$ours)
  expect_true(is.na(r$openssl))
  expect_false(r$ok)
  expect_false(r$agree)
  expect_match(r$reason, "not found")
  expect_box2(r, "verified here; OpenSSL gave no verdict",
              c("no verdict", "install OpenSSL"))
  expect_false(cpsxvrf("x", sg, k, openssl = "")$ours)
  expect_box2(cpsxvrf("x", sg, k, openssl = ""), "NOT VERIFIED",
              "does not match")
})

test_that("an old or silent openssl is not asked", {
  skip_on_os("windows")
  d <- withr::local_tempdir()
  old <- file.path(d, "openssl-old")
  writeLines(c("#!/bin/sh", "echo 'OpenSSL 3.0.13 30 Jan 2024'"), old)
  Sys.chmod(old, "0755")
  mute <- file.path(d, "openssl-mute")
  writeLines(c("#!/bin/sh", "exit 0"), mute)
  Sys.chmod(mute, "0755")
  k <- fipskg("ML-DSA-44")
  sg <- cpssign("m", k)
  r <- cpsxvrf("m", sg, k, openssl = old)
  expect_true(is.na(r$openssl))
  expect_identical(r$version, "OpenSSL 3.0.13")
  expect_match(r$reason, "older than 3.5")
  expect_match(cpsxvrf("m", sg, k, openssl = mute)$reason,
               "did not report its version")
  # an answer that is neither a pass nor a signature failure
  odd <- file.path(d, "openssl-odd")
  writeLines(c(
    "#!/bin/sh",
    "if [ \"$1\" = version ]; then echo 'OpenSSL 3.5.0'; exit 0; fi",
    "echo 'unsupported key type'; exit 1"
  ), odd)
  Sys.chmod(odd, "0755")
  r <- cpsxvrf("m", sg, k, openssl = odd)
  expect_true(is.na(r$openssl))
  expect_match(r$reason, "could not check it: unsupported key type")
})

test_that("schemes OpenSSL cannot check are reported, not guessed", {
  sk <- drvkey("a shared secret", "salt-0123456789")
  h <- cpssign("m", sk, scheme = "hmac")
  r <- cpsxvrf("m", h, sk, openssl = "")
  expect_true(is.na(r$openssl))
  expect_match(r$reason, "no check for hmac")
  k <- fipskg("ML-DSA-44")
  ph <- cpssign("m", k, prehash = "sha256")
  expect_match(cpsxvrf("m", ph, k)$reason, "pure")
  # a mismatched key never reaches OpenSSL
  k2 <- fipskg("ML-DSA-65")
  skip_if_not(has_ossl35(), "OpenSSL 3.5 or later is not installed")
  expect_false(cpsxvrf("m", cpssign("m", k), k2)$openssl)
})

test_that("cpsxvrf refuses a signature that is not one", {
  expect_error(cpsxvrf("m", list(), fipskg("ML-DSA-44")), "cpssign")
  expect_true(is.na(.rmbl_xvrf_oid("xmss-sha256")))
  expect_true(is.na(.rmbl_xvrf_oid(c("a", "b"))))
  expect_identical(.rmbl_xvrf_oid("SLH-DSA-SHAKE-256f"), 31L)
  der <- .rmbl_xvrf_spki(17L, as.raw(rep(1, 1312)))
  expect_identical(der[1:4], as.raw(c(0x30, 0x82, 0x05, 0x32)))
})
