# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("an XMSS key signs, verifies and moves forward", {
  withr::local_options(
    rmoriebricklayer.xmssidxfile = tempfile("xmss-", fileext = ".txt")
  )
  key <- pqckg(height = 2)
  expect_s3_class(key, "bricklayer_signing_key")
  expect_identical(key$next_index, 0L)
  expect_identical(key$capacity, 4L)
  sig <- cpssign("a manifest", key)
  expect_s3_class(sig, "bricklayer_signature")
  expect_identical(sig$index, 0L)
  expect_null(sig$skseed)
  pub <- signpubkey(key)
  expect_true(cpsvrf("a manifest", sig, pub))
  expect_false(cpsvrf("another manifest", sig, pub))
  # an index is never used twice
  expect_error(cpssign("again", key), "already used")
  key <- xmssadv(key, sig, "a manifest")
  expect_identical(key$next_index, 1L)
  expect_identical(cpssign("next", key)$index, 1L)
  # an edited signature does not verify
  bad <- sig
  bad$root <- strrep("0", 64)
  expect_false(cpsvrf("a manifest", bad, pub))
  bad <- sig
  bad$height <- 3L
  expect_false(cpsvrf("a manifest", bad, pub))
  expect_error(xmssadv(key, sig, "not what was signed"), "does not verify")
  expect_error(xmssadv(list(), sig), "signing key from pqckg")
})

test_that("pqckg checks its height and seeds", {
  expect_error(pqckg(height = 0), "between 1 and 16")
  expect_error(pqckg(height = 17), "between 1 and 16")
  s <- strrep("ab", 32)
  k1 <- pqckg(height = 2, skseed = s, pubseed = s, skprf = s)
  k2 <- pqckg(height = 2, skseed = s, pubseed = s, skprf = s)
  expect_identical(k1$root, k2$root)
  expect_identical(k1$skprf, s)
  expect_error(pqckg(height = 2, skseed = "zz"))
})

test_that("the used-index record path is checked", {
  withr::local_options(rmoriebricklayer.xmssidxfile = "relative/path.txt")
  expect_error(.rmbl_xmss_index_file(), "a relative path")
  withr::local_options(rmoriebricklayer.xmssidxfile = "on")
  expect_error(.rmbl_xmss_index_file(), "which is not a file path")
  withr::local_options(rmoriebricklayer.xmssidxfile = "")
  expect_null(.rmbl_xmss_index_file())
  withr::local_options(rmoriebricklayer.xmssidxfile = FALSE)
  expect_null(.rmbl_xmss_index_file())
  withr::local_options(rmoriebricklayer.xmssidxfile = 1)
  expect_error(.rmbl_xmss_index_file(), "must be a file path")
  withr::local_options(rmoriebricklayer.xmssidxfile = tempdir())
  expect_error(.rmbl_xmss_index_file(), "is a directory, not a regular file")
  f <- tempfile(fileext = ".txt")
  withr::local_options(rmoriebricklayer.xmssidxfile = f)
  expect_identical(.rmbl_xmss_index_file(), f)
})

test_that("the used-index record round-trips and refuses a malformed line", {
  f <- tempfile(fileext = ".txt")
  expect_identical(.rmbl_xmss_record_read(f), integer(0))
  ida <- paste0("k:", strrep("a", 64))
  idb <- paste0("k:", strrep("b", 64))
  .rmbl_xmss_record_write(f, stats::setNames(c(3L, 1L), c(ida, idb)))
  expect_identical(
    .rmbl_xmss_record_read(f),
    stats::setNames(c(3L, 1L), c(ida, idb))
  )
  # a key listed twice keeps its highest index
  cat(ida, "\t", 7L, "\n", sep = "", file = f, append = TRUE)
  expect_identical(.rmbl_xmss_record_read(f)[[ida]], 7L)
  cat("not a record line\n", file = f, append = TRUE)
  expect_error(.rmbl_xmss_record_read(f), "1 malformed line")
})

test_that("an HMAC signature verifies and an edited one does not", {
  sig <- cpssign("m", "a shared secret", "hmac")
  expect_true(cpsvrf("m", sig, "a shared secret"))
  expect_false(cpsvrf("m", sig, "another secret"))
  bad <- sig
  bad$signature <- "not hex"
  expect_false(cpsvrf("m", bad, "a shared secret"))
  bad$signature <- c(sig$signature, sig$signature)
  expect_false(cpsvrf("m", bad, "a shared secret"))
  expect_error(cpsvrf("m", list(), "k"), "must come from cpssign")
})

test_that("an ML-DSA key signs through mu and verifies both ways", {
  key <- fipskg("ML-DSA-44", seed = as.raw(1:32))
  pub <- fipspubkey(key)
  expect_null(pub$secret)
  mu <- fipsmu(key, "m", ctx = "release")
  expect_length(mu, 64L)
  expect_identical(fipsmu(pub, "m", ctx = "release"), mu)
  sig <- fipssignmu(key, mu)
  expect_true(fipsvrfmu(pub, mu, sig))
  expect_true(cpsvrf("m", sig, pub, ctx = "release"))
  expect_false(cpsvrf("m", sig, pub, ctx = "staging"))
  # a short mu, an edited scheme or an edited key is "not verified"
  expect_false(fipsvrfmu(pub, mu[1:32], sig))
  bad <- sig
  bad$scheme <- "ML-DSA-65"
  expect_false(fipsvrfmu(pub, mu, bad))
  epub <- pub
  epub$scheme <- "nonsense"
  expect_false(fipsvrfmu(epub, mu, sig))
  expect_error(fipsvrfmu("k", mu, sig), "must come from fipskg")
  expect_error(fipsvrfmu(pub, mu, list()), "must come from fipssignmu")
  expect_identical(
    fipskey("ML-DSA-44", key$public, key$secret)$secret,
    key$secret
  )
})

test_that("fipssz knows each set and refuses XMSS", {
  expect_lt(
    fipssz("ML-DSA-44")[["signature"]],
    fipssz("ML-DSA-65")[["signature"]]
  )
  expect_true(all(c("xmss-sha256", "ML-DSA-65") %in% pqcbknd()))
  expect_error(fipssz("xmss-sha256"))
  expect_error(fipskg("ML-DSA-99"))
})

test_that("sign errors name msg, ctx, determ and public as the user wrote", {
  k <- fipskg("ML-DSA-44")
  f <- function() 1
  expect_error(fipsmu(k, f), "fipsmu: `msg` must be data")
  expect_error(fipsmu(k, "m", ctx = f), "fipsmu: `ctx` must be data")
  expect_error(cpsvrf(f, NULL, k), "cpsvrf: `msg` must be data")
  expect_error(fipsmu(k, c("a", "b")), "`msg` must be a length-1")
  expect_error(fipsmu(k, "m", ctx = c("a", "b")), "`ctx` must be a length-1")
  mu <- fipsmu(k, "m")
  expect_error(
    fipssignmu(k, mu, determ = "yes"),
    "fipssignmu: `determ` must be TRUE or FALSE"
  )
  expect_error(cpssign("m", k, determ = NA), "`determ` must be TRUE or FALSE")
  expect_identical(
    fipssignmu(k, mu, determ = TRUE)$signature,
    fipssignmu(k, mu, determ = TRUE)$signature
  )
  expect_error(
    fipskey("ML-DSA-44", c(k$public, k$public)),
    "`public` must be 1312 bytes"
  )
  expect_s3_class(fipskey("ML-DSA-44", k$public), "bricklayer_fips_public_key")
})

# Prints `x` on an ASCII console: the lines and what print() returned.
o1_box <- function(x, ...) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  tmp <- withr::local_tempfile()
  v <- withr::with_output_sink(tmp, withVisible(print(x, ...)))
  list(out = readLines(tmp), v = v)
}

# The box's frame, its title and the facts expected in it.
o1_expect_box <- function(b, x, title, facts = character()) {
  expect_false(b$v$visible)
  expect_identical(b$v$value, x)
  expect_match(b$out[1L], "^\\+-- ")
  expect_true(grepl(title, b$out[1L], fixed = TRUE))
  expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  for (f in facts) {
    expect_true(any(grepl(f, b$out, fixed = TRUE)), info = f)
  }
}

test_that("standardised keys print as boxes with their fingerprint", {
  key <- fipskg("ML-DSA-44")
  b <- o1_box(key)
  o1_expect_box(
    b,
    key,
    "Signing key (FIPS 204)",
    c("ML-DSA-44", "Fingerprint", "<withheld>", "stateless")
  )
  fp <- .bl_id_fpr(list(scheme = key$scheme, public = key$public))
  expect_true(any(grepl(substr(fp, 1L, 19L), b$out, fixed = TRUE)))
  tail <- substring(key$secret, nchar(key$secret) - 63L)
  expect_false(any(grepl(tail, c(b$out, format(key)), fixed = TRUE)))
  pub <- fipspubkey(key)
  pb <- o1_box(pub)
  o1_expect_box(pb, pub, "Public verification key (FIPS 204)", "Fingerprint")
  expect_false(any(grepl("withheld", pb$out, fixed = TRUE)))
  slh <- list(public = "ab", scheme = "SLH-DSA-SHA2-128s")
  class(slh) <- c("bricklayer_fips_public_key", "bricklayer_oqs_public_key")
  expect_true(any(grepl("FIPS 205", format(slh), fixed = TRUE)))
  expect_identical(.rmbl_fips_standard("other"), "FIPS 204 / FIPS 205")
  old <- key
  class(old) <- c("bricklayer_oqs_key", "list")
  o1_expect_box(o1_box(old), old, "Signing key (standardised", "ML-DSA-44")
  oldp <- pub
  class(oldp) <- c("bricklayer_oqs_public_key", "list")
  o1_expect_box(o1_box(oldp), oldp, "Public verification key", "ML-DSA-44")
})
