# Recomputation, seed replay, dependency capture, pre-registration,
# multiple testing, sensitivity, bundles and timestamps.
#
# These are the parts of the provenance story that are about the claim
# rather than the bytes. The bytes are covered in test-attest.R.

test_that("recomputation catches a manifest the data no longer supports", {
  d <- data.frame(x = 1:10)
  m <- make_manifest(list(dataset = "demo"), environment = FALSE)
  m <- suppressMessages(record(m, "mean_x", observed = mean(d$x),
                               expected = 5.5))
  m <- suppressMessages(record(m, "n", observed = nrow(d), expected = 10))
  stats <- list(mean_x = function(z) mean(z$x), n = function(z) nrow(z))

  r <- manifest_recompute(m, d, stats)
  expect_true(r$ok)
  expect_identical(sort(r$results$status), c("MATCH", "MATCH"))
  expect_length(r$unchecked, 0L)

  # This is the check verify_capsule() cannot make: the manifest is
  # internally consistent either way, and only re-running the
  # statistics against the data can tell that the data moved.
  r2 <- manifest_recompute(m, data.frame(x = 1:11), stats)
  expect_false(r2$ok)
  expect_true(all(r2$results$status == "DIFFER"))
  expect_identical(r2$results$recomputed[r2$results$name == "n"], 11)

  # a result recorded but not recomputed is reported, not dropped
  r3 <- manifest_recompute(m, d, stats["n"])
  expect_false(r3$ok)
  expect_identical(r3$unchecked, "mean_x")
  # a statistic recomputed but never recorded is reported too
  r4 <- manifest_recompute(m, d, list(nope = function(z) 1))
  expect_identical(r4$results$status, "NOT_RECORDED")
  # and a statistic that fails is an ERROR row rather than a crash
  r5 <- manifest_recompute(m, d, list(n = function(z) stop("boom")))
  expect_identical(r5$results$status, "ERROR")
  expect_match(r5$results$detail, "boom")

  # the recorded tolerance is respected, and can be overridden
  m2 <- suppressMessages(record(m, "loose", observed = 1,
                                expected = 1, tol = 0.5))
  st <- list(loose = function(z) 1.4)
  expect_identical(
    manifest_recompute(m2, d, st)$results$status, "MATCH")
  expect_identical(
    manifest_recompute(m2, d, st, tol = 0.01)$results$status, "DIFFER")
  expect_error(manifest_recompute(m, d, list()), "named list")
  expect_error(manifest_recompute(m, d, list(a = 1)), "must be a function")
  expect_error(manifest_recompute(list(), d, st), "recorded results")
  expect_output(print(r), "Recomputation")
})

test_that("a recorded generator state replays exactly", {
  set.seed(42)
  m <- manifest_record_seed(make_manifest(list(a = 1),
                                          environment = FALSE))
  first <- stats::runif(3)
  # set.seed() alone is not enough: a single extra draw upstream shifts
  # everything after it, which is why the STATE is recorded and not the
  # seed that produced it
  invisible(stats::runif(1000))
  manifest_restore_seed(m)
  expect_identical(stats::runif(3), first)
  expect_true(is.integer(m$rng$state))
  expect_gt(length(m$rng$state), 1L)
  expect_error(manifest_restore_seed(make_manifest(list(a = 1),
                                                   environment = FALSE)),
               "no recorded generator state")
  expect_error(manifest_record_seed("not a manifest"), "manifest")
})

test_that("dependency capture records where a package came from", {
  d <- capture_dependencies(c("stats", "utils"))
  expect_identical(nrow(d), 2L)
  expect_true(all(c("package", "version", "library", "repository",
                    "remote_url", "remote_sha", "built") %in% names(d)))
  expect_identical(d$package, c("stats", "utils"))
  expect_false(any(is.na(d$version)))
  # a field that is absent is NA rather than omitted, so a reader can
  # see the information was missing rather than forgotten
  expect_true(all(is.na(d$remote_sha)))
  expect_identical(nrow(capture_dependencies(character(0))), 0L)
})

test_that("a declaration catches switching and additions differently", {
  plan <- prereg_declare(c(ate = "force is higher in the exposed division",
                           n_rows = "the row count matches the source"),
                         note = "pre-specified")
  expect_s3_class(plan, "bricklayer_prereg")
  expect_true(prereg_check(plan, c("ate", "n_rows"))$ok)

  # dropping a declared outcome and adding an undeclared one are
  # different failures and are reported separately
  sw <- prereg_check(plan, "n_rows")
  expect_false(sw$ok)
  expect_identical(sw$declared_not_reported, "ate")
  expect_length(sw$reported_not_declared, 0L)

  ad <- prereg_check(plan, c("ate", "n_rows", "by_year", "by_precinct"))
  expect_false(ad$ok)
  expect_identical(ad$reported_not_declared, c("by_year", "by_precinct"))
  expect_length(ad$declared_not_reported, 0L)

  # a manifest can be passed instead of a list of names
  m <- make_manifest(list(a = 1), environment = FALSE)
  m <- suppressMessages(record(m, "ate", observed = 1, expected = 1))
  m <- suppressMessages(record(m, "n_rows", observed = 1, expected = 1))
  expect_true(prereg_check(plan, m)$ok)

  # a declaration can be sealed, which is what gives it a date
  att <- capsule_attest(list(meta = unclass(plan), results = list()),
                        fips_keygen("ML-DSA-44"))
  expect_true(capsule_check_attestation(
    att, list(meta = unclass(plan), results = list()))$ok)

  expect_error(prereg_declare("unnamed"), "named character vector")
  expect_error(prereg_declare(c(a = "x", a = "y")), "duplicate names")
  expect_error(prereg_check(list(), "a"), "prereg_declare")
  expect_output(print(plan), "Pre-registration")
  expect_output(print(sw), "outcome switching")
})

test_that("the corrections agree with the reference implementation", {
  set.seed(9)
  p <- stats::runif(12)
  names(p) <- paste0("s", seq_along(p))
  for (m in c("holm", "bh", "bonferroni", "none")) {
    got <- falsify_family(p, method = m)$results
    got <- got[match(names(p), got$name), ]
    want <- stats::p.adjust(p, method = if (m == "bh") "BH" else m)
    # stats::p.adjust is an independent implementation of the same
    # step-up and step-down procedures; agreeing with it is the check
    # that the directions were not swapped
    expect_equal(got$adjusted, unname(want), info = m)
  }
  # The correction is what stops the smallest of several being read as
  # the finding. Holm multiplies the smallest p by the family size, so
  # 0.01 among four tests becomes 0.04 and still survives at 0.05,
  # while 0.02 among five becomes 0.10 and does not -- which is the
  # arithmetic worth having in front of you rather than assumed.
  f <- falsify_family(c(a = 0.01, b = 0.04, c = 0.2, d = 0.5),
                      method = "holm")
  expect_identical(f$family_size, 4L)
  expect_equal(f$results$adjusted[f$results$name == "a"], 0.04)
  expect_true(f$results$survives[f$results$name == "a"])
  expect_false(any(f$results$survives[f$results$name != "a"]))
  g <- falsify_family(c(a = 0.02, b = 0.3, c = 0.4, d = 0.6, e = 0.7),
                      method = "holm")
  expect_equal(g$results$adjusted[g$results$name == "a"], 0.10)
  expect_false(any(g$results$survives))
  # Benjamini-Hochberg is less conservative and says something weaker
  expect_lte(
    falsify_family(c(a = 0.02, b = 0.3, c = 0.4, d = 0.6, e = 0.7),
                   method = "bh")$results$adjusted[1],
    g$results$adjusted[g$results$name == "a"])
  expect_true(falsify_family(c(a = 0.001), method = "holm")$results$survives)
  expect_error(falsify_family(c(a = -1)), "must lie in")
  expect_error(falsify_family(c(a = NA_real_)), "needs a p-value")
  expect_error(falsify_family("x"), "named list")
})

test_that("a family of falsifications reports which sit at the floor", {
  set.seed(4)
  d <- data.frame(x = stats::rnorm(120))
  d$y <- 0.7 * d$x + stats::rnorm(120)
  d$a <- stats::rnorm(120)
  fam <- list(
    real = capsule_falsify(d, function(z) stats::cor(z$x, z$y),
                           treatment = "x", n = 99L, seed = 1L),
    noise = capsule_falsify(d, function(z) stats::cor(z$a, z$y),
                            treatment = "a", n = 99L, seed = 2L))
  res <- falsify_family(fam, method = "holm")
  expect_identical(res$family_size, 2L)
  expect_true(res$results$survives[res$results$name == "real"])
  expect_false(res$results$survives[res$results$name == "noise"])
  # a p-value at 1/(n+1) is the smallest the design could produce, and
  # saying so is the difference between evidence and an artefact of the
  # permutation count
  expect_identical(res$at_floor, "real")
  expect_output(print(res), "permutation floor")
})

test_that("the E-value is its closed form", {
  # 2 + sqrt(2 * 1) = 3.414214, by hand
  expect_equal(unname(evalue_rr(2)), 2 + sqrt(2), tolerance = 1e-12)
  # the measure is symmetric about the null
  expect_equal(evalue_rr(0.5), evalue_rr(2))
  expect_equal(unname(evalue_rr(1)), 1)
  # an interval that already includes the null needs no confounding
  expect_equal(unname(evalue_rr(2, lo = 0.9, hi = 4.4)["evalue_limit"]), 1)
  # and a limit above the null needs some
  expect_equal(unname(evalue_rr(3, lo = 2.1, hi = 4.3)["evalue_limit"]),
               2.1 + sqrt(2.1 * 1.1), tolerance = 1e-12)
  # a stronger estimate is harder to explain away
  expect_gt(evalue_rr(5), evalue_rr(2))
  expect_error(evalue_rr(0), "finite and positive")
  expect_error(evalue_rr(-1), "finite and positive")
  expect_error(evalue_rr(Inf), "finite and positive")
})

test_that("a bundle covers the files, the manifest and itself", {
  dir <- tempfile()
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  utils::write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"),
                   row.names = FALSE)
  writeLines("notes", file.path(dir, "README.txt"))
  m <- make_manifest(list(dataset = "demo"), environment = FALSE)
  key <- fips_keygen("ML-DSA-44")

  b <- capsule_bundle(dir, m, key, note = "as published")
  p <- attr(b, "path")
  expect_true(file.exists(p))
  res <- capsule_bundle_verify(p, dir, manifest = m,
                               key_expected = key$public)
  expect_true(res$ok)
  expect_true(any(grepl("file:data.csv", res$checks$check)))

  # editing a covered file breaks it
  utils::write.csv(data.frame(x = 1:4), file.path(dir, "data.csv"),
                   row.names = FALSE)
  expect_false(capsule_bundle_verify(p, dir, manifest = m)$ok)
  utils::write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"),
                   row.names = FALSE)
  expect_true(capsule_bundle_verify(p, dir, manifest = m)$ok)

  # a file added beside the capsule is reported: a signed list of what
  # should be there says nothing about what else was put next to it
  writeLines("sneaky", file.path(dir, "extra.csv"))
  r2 <- capsule_bundle_verify(p, dir, manifest = m)
  expect_false(r2$ok)
  expect_false(r2$checks$ok[r2$checks$check == "no_unlisted_files"])
  file.remove(file.path(dir, "extra.csv"))

  # the file digests are INSIDE the signature, so rewriting one in the
  # bundle is caught twice over
  raw <- readLines(p)
  i <- grep("sha256", raw)[1]
  raw[i] <- sub("[0-9a-f]{64}", strrep("a", 64), raw[i])
  tf <- tempfile(fileext = ".json")
  writeLines(raw, tf)
  r3 <- capsule_bundle_verify(tf, dir, manifest = m)
  expect_false(r3$ok)
  expect_gte(sum(!r3$checks$ok), 2L)

  # and so is the bundle's own timestamp, which nothing else covers
  raw2 <- readLines(p)
  j <- grep("bundled_utc", raw2)[1]
  raw2[j] <- sub("20[0-9]{2}", "1999", raw2[j])
  tf2 <- tempfile(fileext = ".json")
  writeLines(raw2, tf2)
  expect_false(capsule_bundle_verify(tf2, dir, manifest = m)$ok)

  expect_false(capsule_bundle_verify(p, dir,
    manifest = make_manifest(list(d = 2), environment = FALSE))$ok)
  expect_error(capsule_bundle(tempfile(), m, key), "does not exist")
  expect_error(capsule_bundle(dir, m, key, files = "nope.csv"),
               "not in `dir`")
  expect_error(capsule_bundle_verify(list(), dir), "capsule_bundle")
  expect_output(print(b), "Capsule bundle")
})

test_that("an RFC 3161 token verifies, and every tamper is caught", {
  fx <- readLines(test_path("timestamp-token.txt"), warn = FALSE)
  fx <- fx[!startsWith(fx, "#") & nzchar(fx)]
  parts <- strsplit(fx, "|", fixed = TRUE)
  f <- stats::setNames(
    lapply(parts, function(p) .rmbl_hex_to_raw(p[2L])),
    vapply(parts, `[[`, character(1), 1L))

  res <- timestamp_verify(f$token, f$payload)
  expect_s3_class(res, "bricklayer_timestamp")
  expect_true(res$ok)
  expect_s3_class(res$time, "POSIXct")
  expect_identical(res$hash_algorithm, "sha256")
  # the caller's own copy of the certificate works as well as the
  # embedded one
  expect_true(timestamp_verify(f$token, f$payload,
                               certificate = f$certificate)$ok)

  # the token, the data and the certificate may each arrive as raw
  # bytes, as a DER file, or -- for the certificate -- as PEM, and the
  # PEM path has its own base64 decode to get wrong
  tk <- tempfile(); writeBin(f$token, tk)
  pl <- tempfile(); writeBin(f$payload, pl)
  der <- tempfile(); writeBin(f$certificate, der)
  pem <- tempfile()
  writeLines(c("-----BEGIN CERTIFICATE-----",
               strsplit(bricklayer_json_base64_enc(f$certificate),
                        "(?<=.{64})", perl = TRUE)[[1]],
               "-----END CERTIFICATE-----"), pem)
  expect_true(timestamp_verify(tk, pl)$ok)
  expect_true(timestamp_verify(tk, pl, certificate = der)$ok)
  expect_true(timestamp_verify(tk, pl, certificate = pem)$ok)
  unlink(c(tk, pl, der, pem))

  info <- timestamp_info(f$token)
  expect_identical(info$hash_algorithm, "sha256")
  expect_true(info$has_certificate)
  expect_identical(info$imprint, core_sha256(f$payload))

  # a token is about particular bytes and nothing else
  bad <- timestamp_verify(f$token, charToRaw("other bytes"))
  expect_false(bad$ok)
  expect_false(bad$checks$ok[bad$checks$check == "message_imprint"])
  # and the signature was still fine, which is the point of reporting
  # the checks separately rather than one verdict
  expect_true(bad$checks$ok[bad$checks$check == "signature"])

  # flipping a byte of the TSTInfo breaks what the attributes commit to
  for (off in c(80L, 200L)) {
    t2 <- f$token
    t2[off] <- as.raw(bitwXor(as.integer(t2[off]), 1L))
    r <- timestamp_verify(t2, f$payload)
    expect_false(r$ok, info = as.character(off))
    expect_false(r$checks$ok[r$checks$check == "attribute_digest"],
                 info = as.character(off))
  }
  # flipping a byte of the signature breaks the RSA recovery
  t3 <- f$token
  k <- length(t3) - 40L
  t3[k] <- as.raw(bitwXor(as.integer(t3[k]), 1L))
  r3 <- timestamp_verify(t3, f$payload)
  expect_false(r3$ok)
  expect_false(r3$checks$ok[r3$checks$check == "signature"])

  # a different authority's certificate does not verify it
  other <- fips_keygen("ML-DSA-44")
  expect_error(timestamp_verify(f$token, f$payload,
                                certificate = charToRaw("nonsense")),
               NA)
  r4 <- timestamp_verify(f$token, f$payload,
                         certificate = charToRaw("nonsense"))
  expect_false(r4$ok)

  # malformed input is a verdict, never an error: a verifier that
  # throws on bad input is one a caller has to wrap
  expect_false(timestamp_verify(charToRaw("not der"), f$payload)$ok)
  expect_error(timestamp_verify(42, f$payload), "raw vector")
  expect_output(print(res), "Timestamp token")
  expect_output(print(res), "trust in the certificate is NOT checked")
})
