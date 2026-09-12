# Attestation, the canonical manifest form, and the falsification
# controls.
#
# These three answer different questions and the tests are kept apart
# accordingly: whether the record is byte-stable, whether a signature
# binds it to a key a third party can check, and whether the finding it
# records survives having its association destroyed on purpose.

test_that("the canonical form does not depend on assembly order", {
  a <- make_manifest(list(b = 2, a = 1), environment = FALSE)
  b <- make_manifest(list(a = 1, b = 2), environment = FALSE)
  expect_identical(manifest_digest(a), manifest_digest(b))
  expect_identical(manifest_canonical(a), manifest_canonical(b))
  # nested objects too
  x <- list(meta = list(z = list(q = 1, p = 2), a = 3), results = list())
  y <- list(results = list(), meta = list(a = 3, z = list(p = 2, q = 1)))
  expect_identical(manifest_digest(x), manifest_digest(y))
  # but an ARRAY's order is content, not presentation, and must survive
  expect_false(identical(
    manifest_digest(list(v = list(1, 2))),
    manifest_digest(list(v = list(2, 1)))))
  # the digest is 64 hex characters and changes with the content
  expect_match(manifest_digest(a), "^[0-9a-f]{64}$")
  expect_false(identical(manifest_digest(a),
                         manifest_digest(list(meta = list(a = 1, b = 3)))))
})

test_that("a recorded number can be recovered from the manifest", {
  # The writer used to emit four significant digits, so 1/3 was recorded
  # as 0.3333 and no later recomputation could match what was written.
  # A provenance record that cannot reproduce its own numbers is the one
  # failure mode this whole file exists to prevent.
  for (x in c(1 / 3, pi, 1e-300, 2^-1074, .Machine$double.xmax,
              .Machine$double.eps, 1234567.891011)) {
    m <- make_manifest(list(x = x), environment = FALSE)
    back <- bricklayer_json_from_json(manifest_canonical(m))
    expect_identical(back$meta$x, x, info = format(x, digits = 17))
    tmp <- tempfile(fileext = ".json")
    write_manifest_json(m, tmp)
    got <- bricklayer_json_from_json(paste(readLines(tmp), collapse = "\n"))
    expect_identical(got$meta$x, x, info = format(x, digits = 17))
    unlink(tmp)
  }
  # the canonical file is one line, so it can be hashed without
  # worrying about line endings
  m <- make_manifest(list(x = 1), environment = FALSE)
  tmp <- tempfile(fileext = ".json")
  write_manifest_json(m, tmp, canonical = TRUE)
  expect_length(readLines(tmp), 1L)
  expect_identical(core_sha256(charToRaw(readLines(tmp))),
                   manifest_digest(m))
  unlink(tmp)
})

test_that("the environment record carries the generator", {
  env <- capture_environment()
  # Without the generator's identity a stochastic result cannot be
  # reproduced: R has changed its default sample() algorithm before, and
  # a seed means nothing without the kind it was fed to.
  expect_true("rng_kind" %in% names(env))
  expect_match(env$rng_kind, "Mersenne-Twister|Wichmann|Marsaglia|Knuth")
  expect_true(is.logical(env$rng_seeded))
  expect_true(all(c("r_version", "platform", "os", "captured_utc",
                    "packages") %in% names(env)))
  # and the recorded kind is the one in force
  old <- RNGkind()
  on.exit(RNGkind(old[1], old[2], old[3]), add = TRUE)
  suppressWarnings(RNGkind("Wichmann-Hill"))
  expect_match(capture_environment()$rng_kind, "Wichmann-Hill")
})

test_that("an attestation binds the manifest, the key and the note", {
  m <- make_manifest(list(dataset = "otis", rows = 1200L),
                     environment = FALSE)
  for (sch in c("ML-DSA-44", "SLH-DSA-SHAKE-128f")) {
    key <- fips_keygen(sch)
    att <- capsule_attest(m, key, context = "release",
                          note = "counts as published")
    expect_s3_class(att, "bricklayer_attestation")
    expect_identical(att$scheme, sch)
    expect_identical(att$digest, manifest_digest(m))
    res <- capsule_check_attestation(att, m)
    expect_true(res$ok, info = sch)
    expect_true(all(res$checks$ok))
    # naming the key that should have signed is part of the check
    expect_true(capsule_check_attestation(att, m,
      key_expected = key$public)$ok, info = sch)
    expect_false(capsule_check_attestation(att, m,
      key_expected = fips_keygen(sch)$public)$ok, info = sch)

    # every field inside the payload is covered by the signature, so
    # editing any of them afterwards is detected
    m2 <- m
    m2$meta$rows <- 1201L
    expect_false(capsule_check_attestation(att, m2)$ok, info = sch)
    for (field in c("note", "context", "prehash", "signed_utc", "digest")) {
      bad <- att
      bad[[field]] <- paste0(bad[[field]], "x")
      expect_false(capsule_check_attestation(bad, m)$ok,
                   info = paste(sch, field))
    }
    # and a signature lifted from another attestation does not fit
    other <- capsule_attest(m, key, context = "release", note = "other")
    swapped <- att
    swapped$signature <- other$signature
    expect_false(capsule_check_attestation(swapped, m)$ok, info = sch)
  }
})

test_that("an attestation works with the stateful hash-based key too", {
  m <- make_manifest(list(a = 1), environment = FALSE)
  key <- pqc_keygen(height = 4L)
  att <- capsule_attest(m, key, note = "hash-based")
  expect_identical(att$scheme, "xmss-sha256")
  # the XMSS public key is root and public seed together: both are
  # needed to verify, so both have to be recorded
  expect_identical(nchar(att$public), 128L)
  expect_true(capsule_check_attestation(att, m)$ok)
  m2 <- m
  m2$meta$a <- 2
  expect_false(capsule_check_attestation(att, m2)$ok)
})

test_that("the attestation surface refuses what it cannot check", {
  m <- make_manifest(list(a = 1), environment = FALSE)
  expect_error(capsule_attest(m, list()), "fips_keygen")
  expect_error(capsule_attest("not a manifest", fips_keygen("ML-DSA-44")),
               "manifest")
  expect_error(capsule_check_attestation(list(), m), "capsule_attest")
  # an attestation missing a field fails rather than being read around
  att <- capsule_attest(m, fips_keygen("ML-DSA-44"))
  stripped <- att
  stripped$public <- NULL
  res <- capsule_check_attestation(stripped, m)
  expect_false(res$ok)
  expect_false(res$checks$ok[res$checks$check == "attestation_complete"])
  expect_output(print(att), "Capsule attestation")
  expect_output(print(capsule_check_attestation(att, m)), "OK")
})

test_that("the falsification controls can fail, and do", {
  set.seed(1)
  d <- data.frame(x = stats::rnorm(200))
  d$y <- 0.8 * d$x + stats::rnorm(200)
  verdict <- function(r, ctrl) {
    r$controls$passed[r$controls$control == ctrl]
  }

  real <- capsule_falsify(d, function(z) stats::cor(z$x, z$y),
                          treatment = "x", n = 199L, seed = 42L)
  expect_s3_class(real, "bricklayer_falsification")
  expect_true(all(real$controls$passed))
  expect_length(real$permutation, 199L)

  # a constant is not an association, and the permutation control is
  # what says so: everything else about a constant is perfectly stable
  const <- capsule_falsify(d, function(z) 0.5, treatment = "x",
                           n = 199L, seed = 42L)
  expect_false(verdict(const, "permutation"))
  expect_true(verdict(const, "subset_stability"))

  # nor is noise
  noise <- data.frame(x = stats::rnorm(200), y = stats::rnorm(200))
  nul <- capsule_falsify(noise, function(z) stats::cor(z$x, z$y),
                         treatment = "x", n = 199L, seed = 7L)
  expect_false(verdict(nul, "permutation"))

  # a statistic that reads the injected noise column is caught by the
  # control whose whole point is that the column cannot matter
  peek <- capsule_falsify(
    d,
    function(z) stats::cor(z$x, z$y) +
      if (".rmbl_random_common_cause" %in% names(z)) 1 else 0,
    treatment = "x", n = 99L, seed = 3L)
  expect_false(verdict(peek, "random_common_cause"))
  expect_true(verdict(peek, "permutation"))
})

test_that("the permutation floor is reported rather than implied", {
  set.seed(2)
  d <- data.frame(x = stats::rnorm(60))
  d$y <- 2 * d$x + stats::rnorm(60, sd = 0.1)
  r <- capsule_falsify(d, function(z) stats::cor(z$x, z$y),
                       treatment = "x", n = 19L, seed = 1L)
  p <- r$controls$value[r$controls$control == "permutation"]
  # 19 permutations cannot produce a p-value below 1/20, however strong
  # the association: the floor is a property of the design, and a
  # reader who does not know it will over-read a p of 0.05
  expect_gte(p, 1 / 20)
  expect_match(r$controls$detail[r$controls$control == "permutation"],
               "smallest this design can report")
  expect_error(capsule_falsify(d, function(z) 1, n = 8L), "at least 9")
})

test_that("a skipped control is reported as skipped", {
  set.seed(3)
  d <- data.frame(x = stats::rnorm(50), y = stats::rnorm(50))
  r <- capsule_falsify(d, function(z) mean(z$y), n = 49L, seed = 1L)
  sk <- r$controls[r$controls$control %in% c("permutation", "placebo"), ]
  expect_true(all(is.na(sk$passed)))
  expect_true(all(grepl("skipped", sk$detail)))
  # the controls that do not need a treatment still ran
  expect_true(all(!is.na(
    r$controls$passed[r$controls$control == "subset_stability"])))
  expect_null(r$treatment)
  # the RNG state is recorded, so the run can be repeated
  expect_match(r$rng_kind, "Mersenne-Twister")
  expect_identical(r$seed, 1L)
  expect_output(print(r), "Falsification controls")
})

test_that("falsification input is checked", {
  d <- data.frame(x = 1:10, y = 1:10)
  expect_error(capsule_falsify(d[1:3, ], function(z) 1), "at least 4 rows")
  expect_error(capsule_falsify(as.list(d), function(z) 1), "data frame")
  expect_error(capsule_falsify(d, "notafunction"), "must be a function")
  expect_error(capsule_falsify(d, function(z) c(1, 2), treatment = "x"),
               "one finite number")
  expect_error(capsule_falsify(d, function(z) NA_real_, treatment = "x"),
               "one finite number")
  expect_error(capsule_falsify(d, function(z) stop("boom"),
                               treatment = "x"), "the statistic failed")
  expect_error(capsule_falsify(d, function(z) 1, treatment = "nope"),
               "not a column")
  expect_error(capsule_falsify(d, function(z) 1, subset_frac = 1),
               "between 0 and 1")
})
