# C++ branches codecov listed as unreached at 0.5.9, each driven from R
# through the registered entry points.

test_that("incremental hashing: a digest fed in two pieces equals the one-shot digest at every split", {
  x <- as.raw((1:300) %% 256)
  one256 <- core_sha256(x)
  one512 <- .Call(C_rmbl_sha512, x)
  for (sp in c(0L, 1L, 63L, 64L, 65L, 100L, 127L, 128L, 129L, 200L, 300L, 400L)) {
    two <- .Call(C_rmbl_hash_two_part, x, sp)
    expect_identical(two[1], one256, info = sp)
    expect_identical(two[2], one512, info = sp)
  }
  expect_error(.Call(C_rmbl_hash_two_part, "abc", 1L), "raw vector")
  expect_error(.Call(C_rmbl_hash_two_part, x, -1L), "non-negative")
})

test_that("core_mean survives a sum that overflows when every value is finite", {
  expect_equal(core_mean(c(1e308, 1e308)), 1e308)
  expect_equal(core_mean(c(1e308, 1e308, -1e308)), 1e308 / 3)
})

test_that("Theil-Sen takes the mean of the two middle slopes when their count is even", {
  r <- .Call(C_rmbl_theil_sen, c(1, 2, 3, 4), c(1, 3, 2, 5))
  slopes <- c(2, 0.5, 4 / 3, -1, 1, 3)       # the six pairwise slopes
  expect_equal(r[[1]], stats::median(slopes))
})

test_that("ECDSA: a verified chain signature, an all-zero digest, a digest longer than the group order", {
  f <- x509_fx()
  leaf <- cert_parse(f$chain_ecleaf256)
  ca <- cert_parse(f$chain_ec256)
  rs <- .rmbl_ecdsa_rs(leaf$signature)
  dig <- .rmbl_ts_digest("sha256", leaf$tbs)
  key <- ca$key
  expect_true(.Call(C_rmbl_ecdsa_verify, key$curve, key$x, key$y, rs$r, rs$s, dig))
  # e = 0: u1 = 0 and the scalar has no bits
  expect_false(.Call(C_rmbl_ecdsa_verify, key$curve, key$x, key$y, rs$r, rs$s, raw(32)))
  # a 512-bit digest against a 256-bit order: the excess low bits are shifted off
  expect_false(.Call(C_rmbl_ecdsa_verify, key$curve, key$x, key$y, rs$r, rs$s, .rmbl_ts_digest("sha512", leaf$tbs)))
  expect_false(.Call(C_rmbl_ecdsa_verify, key$curve, key$x, key$y, rs$r, rs$s, .rmbl_ts_digest("sha384", leaf$tbs)))
})

test_that("entry guards: headers that are not strings, a missing pre-hash name, a masked flag that is NA", {
  expect_error(.Call(C_rmbl_http_download, "https://example.org/", tempfile(), 5L, 1L, NULL, 1e6, FALSE),
               "must be a character vector")
  expect_error(.Call(C_rmbl_prehash_digest, NA_character_, as.raw(1:3)), "must not be NA")
  key <- fips_keygen("ML-DSA-44")
  sk <- .rmbl_hex_to_raw(key$secret)
  expect_error(.Call(C_rmbl_mldsa_sign, 44L, sk, as.raw(1:3), raw(0), raw(32), "none", NA), "TRUE or FALSE")
})

test_that("XMSS: an index past the tree and a malformed randomiser", {
  key <- pqc_keygen(height = 2)
  s <- capsule_sign("hello", key)
  args <- list(key$pub_seed, key$root, 2L, s$index, "hello", s$signature, s$auth, s$randomizer)
  expect_true(do.call(.Call, c(list(C_rmbl_xmss_verify), args)))
  args4 <- args
  args4[[4]] <- 4L
  expect_false(do.call(.Call, c(list(C_rmbl_xmss_verify), args4)))
  argsr <- args
  argsr[[8]] <- "zz"
  expect_error(do.call(.Call, c(list(C_rmbl_xmss_verify), argsr)), "randomizer")
})

test_that("the decimal parser agrees with R on the awkward inputs: zero, subnormals, halfway cases, long mantissas", {
  xs <- c("0", "0.0", "-0", "0e5", "0.000", "1e-320", "4.9406564584124654e-324", "2.2250738585072011e-308",
          "2.2250738585072014e-308", "1.7976931348623157e308", "9007199254740993", "9007199254740992.5",
          "0.1", "0.3", "1e23", "8.98846567431158e307", "123456789012345678901234567890", "1e-400", "1e400",
          "3.0000000000000001", "0.30000000000000004", "5e-324", "2.4703282292062327e-324", "2.4703282292062328e-324",
          "1.00000000000000011102230246251565404236316680908203125",
          "1.0000000000000001110223024625156540423631668090820312")
  got <- .rmbl_strtod(xs)
  want <- as.numeric(xs)
  # R's own parser on macOS reads the largest finite double as Inf; the correctly rounded value is DBL_MAX
  want[xs == "1.7976931348623157e308"] <- .Machine$double.xmax
  expect_equal(got, want)
})

test_that("SIU reports: a team size given as digits, and the French resolver without a roster section", {
  fr <- paste0("<html><body><h2>L'enquête</h2><p>Exercice du mandat</p><p>Témoins civils</p>",
               "<p>15 enqu\u00eateurs de l'UES et 2 techniciens en identification ont \u00e9t\u00e9 affect\u00e9s.</p>",
               "<p>L'agent impliqué no 2 a participé à une entrevue; deux agents impliqués ont été désignés.</p>",
               "</body></html>")
  r <- bricklayer_parse_siu(fr)
  expect_true(is.character(r))
  expect_equal(unname(r[["siu_investigators"]]), "15")   # a number, not one of the twelve words
  en <- paste0("<html><body><h2>The Investigation</h2><p>Mandate engaged</p><p>Witness Officers</p>",
               "<p>Fifteen SIU investigators and 14 forensic investigators were dispatched.</p></body></html>")
  r2 <- bricklayer_parse_siu(en)
  expect_equal(unname(r2[["siu_forensics_investigators"]]), "14")
  so <- bricklayer_siu_resolve_so(fr)
  expect_true(is.list(so) || is.character(so) || is.numeric(so))
  one <- paste0("<html><body><h2>L'enqu\u00eate</h2><p>Exercice du mandat</p><p>T\u00e9moins civils</p>",
                "<p>L'agent impliqu\u00e9 no 1 a particip\u00e9 \u00e0 une entrevue.</p></body></html>")
  so1 <- bricklayer_siu_resolve_so(one)
  expect_true(is.list(so1) || is.character(so1) || is.numeric(so1))
  notified <- paste0("<html><body><h2>The Investigation</h2><p>Mandate engaged</p><p>Witness Officers</p>",
                     "<p>On June 3, the Toronto Police Service notified the SIU of an injury.</p></body></html>")
  expect_match(unname(bricklayer_parse_siu(notified)[["police_service"]]), "Toronto Police Service")
})

online_now <- function() {
  r <- tryCatch(.Call(C_rmbl_http_download, "https://cloud.r-project.org/", tempfile(), 20L, NULL, NULL, NULL, FALSE),
                error = function(e) NULL)
  !is.null(r) && identical(r$status, 200L)
}

test_that("live: a Wayback snapshot, a redirect chain that is too long, a download whose size the server announces", {
  skip_on_cran()
  skip_if_not(online_now(), "no network")
  snap <- wayback_snapshot_url_native("https://www.r-project.org/", timeout = 30L)
  expect_true(is.null(snap) || grepl("^https://web\\.archive\\.org/", snap))
  dest <- tempfile()
  expect_error(bricklayer_download("https://httpbin.org/redirect/6", dest, quiet = TRUE, timeout = 60),
               "redirect")
  dest2 <- tempfile()
  out <- utils::capture.output(
    res <- bricklayer_download("https://cloud.r-project.org/favicon.ico", dest2, quiet = FALSE, tty = FALSE,
                               timeout = 60), type = "message")
  expect_true(file.exists(dest2) && file.size(dest2) > 0)
})
