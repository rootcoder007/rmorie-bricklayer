# battery: runs in CI and locally; CRAN runs the correctness core
testthat::skip_on_cran()
# Recomputation, seed replay, dependency capture, pre-registration,
# multiple testing, sensitivity, bundles and timestamps.
#
# These are the parts of the provenance story that are about the claim
# rather than the bytes. The bytes are covered in test-attest.R.

test_that("recomputation catches a manifest the data no longer supports", {
  d <- data.frame(x = 1:10)
  m <- mkmnf(list(dataset = "demo"), env = FALSE)
  m <- suppressMessages(recrd(m, "mean_x", obs = mean(d$x), expd = 5.5))
  m <- suppressMessages(recrd(m, "n", obs = nrow(d), expd = 10))
  stats <- list(mean_x = function(z) mean(z$x), n = function(z) nrow(z))

  r <- mnfrcmp(m, d, stats)
  expect_true(r$ok)
  expect_identical(sort(r$results$status), c("MATCH", "MATCH"))
  expect_length(r$unchecked, 0L)

  # This is the check vrfcps() cannot make: the manifest is
  # internally consistent either way, and only re-running the
  # statistics against the data can tell that the data moved.
  r2 <- mnfrcmp(m, data.frame(x = 1:11), stats)
  expect_false(r2$ok)
  expect_true(all(r2$results$status == "DIFFER"))
  expect_identical(r2$results$recomputed[r2$results$name == "n"], 11)

  # a result recorded but not recomputed is reported, not dropped
  r3 <- mnfrcmp(m, d, stats["n"])
  expect_false(r3$ok)
  expect_identical(r3$unchecked, "mean_x")
  # a statistic recomputed but never recorded is reported too
  r4 <- mnfrcmp(m, d, list(nope = function(z) 1))
  expect_identical(r4$results$status, "NOT_RECORDED")
  # and a statistic that fails is an ERROR row rather than a crash
  r5 <- mnfrcmp(m, d, list(n = function(z) stop("boom")))
  expect_identical(r5$results$status, "ERROR")
  expect_match(r5$results$detail, "boom")

  # the recorded tolerance is respected, and can be overridden
  m2 <- suppressMessages(recrd(m, "loose", obs = 1, expd = 1, tol = 0.5))
  st <- list(loose = function(z) 1.4)
  expect_identical(
    mnfrcmp(m2, d, st)$results$status,
    "MATCH"
  )
  expect_identical(
    mnfrcmp(m2, d, st, tol = 0.01)$results$status,
    "DIFFER"
  )
  expect_error(mnfrcmp(m, d, list()), "named list")
  expect_error(mnfrcmp(m, d, list(a = 1)), "must be a function")
  expect_error(mnfrcmp(list(), d, st), "recorded results")
  expect_output(print(r), "Recomputation")
})

test_that("a recorded generator state replays exactly", {
  set.seed(42)
  m <- mnfrecseed(mkmnf(list(a = 1), env = FALSE))
  first <- stats::runif(3)
  # set.seed() alone is not enough: a single extra draw upstream shifts
  # everything after it, which is why the STATE is recorded and not the
  # seed that produced it
  invisible(stats::runif(1000))
  mnfrstseed(m)
  expect_identical(stats::runif(3), first)
  expect_type(m$rng$state, "integer")
  expect_gt(length(m$rng$state), 1L)
  expect_error(
    mnfrstseed(mkmnf(list(a = 1), env = FALSE)),
    "no recorded generator state"
  )
  expect_error(mnfrecseed("not a manifest"), "manifest")
})

test_that("dependency capture records where a package came from", {
  d <- capdeps(c("stats", "utils"))
  expect_identical(nrow(d), 2L)
  expect_true(all(
    c(
      "package",
      "version",
      "library",
      "repository",
      "remote_url",
      "remote_sha",
      "built"
    ) %in%
      names(d)
  ))
  expect_identical(d$package, c("stats", "utils"))
  expect_false(anyNA(d$version))
  # a field that is absent is NA rather than omitted, so a reader can
  # see the information was missing rather than forgotten
  expect_true(all(is.na(d$remote_sha)))
  expect_identical(nrow(capdeps(character(0))), 0L)
})

test_that("a declaration catches switching and additions differently", {
  plan <- prrgdecl(
    c(
      ate = "force is higher in the exposed division",
      n_rows = "the row count matches the source"
    ),
    note = "pre-specified"
  )
  expect_s3_class(plan, "bricklayer_prereg")
  expect_true(prrgchk(plan, c("ate", "n_rows"))$ok)

  # dropping a declared outcome and adding an undeclared one are
  # different failures and are reported separately
  sw <- prrgchk(plan, "n_rows")
  expect_false(sw$ok)
  expect_identical(sw$decnotrep, "ate")
  expect_length(sw$repnotdec, 0L)

  ad <- prrgchk(plan, c("ate", "n_rows", "by_year", "by_precinct"))
  expect_false(ad$ok)
  expect_identical(ad$repnotdec, c("by_year", "by_precinct"))
  expect_length(ad$decnotrep, 0L)

  # a manifest can be passed instead of a list of names
  m <- mkmnf(list(a = 1), env = FALSE)
  m <- suppressMessages(recrd(m, "ate", obs = 1, expd = 1))
  m <- suppressMessages(recrd(m, "n_rows", obs = 1, expd = 1))
  expect_true(prrgchk(plan, m)$ok)

  # a declaration can be sealed, which is what gives it a date
  att <- cpsatst(
    list(meta = unclass(plan), results = list()),
    fipskg("ML-DSA-44")
  )
  expect_true(
    cpschkatst(
      att,
      list(meta = unclass(plan), results = list())
    )$ok
  )

  expect_error(prrgdecl("unnamed"), "named character vector")
  expect_error(
    prrgdecl(stats::setNames(c("x", "y"), c("a", "a"))),
    "duplicate names"
  )
  expect_error(prrgchk(list(), "a"), "prrgdecl")
  expect_output(print(plan), "Pre-registration")
  expect_output(print(sw), "outcome switching")
})

test_that("the corrections agree with the reference implementation", {
  set.seed(9)
  p <- stats::runif(12)
  names(p) <- paste0("s", seq_along(p))
  for (m in c("holm", "bh", "bonferroni", "none")) {
    got <- falsfam(p, meth = m)$results
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
  f <- falsfam(c(a = 0.01, b = 0.04, c = 0.2, d = 0.5), meth = "holm")
  expect_identical(f$famsz, 4L)
  expect_equal(f$results$adjusted[f$results$name == "a"], 0.04)
  expect_true(f$results$survives[f$results$name == "a"])
  expect_false(any(f$results$survives[f$results$name != "a"]))
  g <- falsfam(c(a = 0.02, b = 0.3, c = 0.4, d = 0.6, e = 0.7), meth = "holm")
  expect_equal(g$results$adjusted[g$results$name == "a"], 0.10)
  expect_false(any(g$results$survives))
  # Benjamini-Hochberg is less conservative and says something weaker
  expect_lte(
    falsfam(
      c(a = 0.02, b = 0.3, c = 0.4, d = 0.6, e = 0.7),
      meth = "bh"
    )$results$adjusted[1],
    g$results$adjusted[g$results$name == "a"]
  )
  expect_true(falsfam(c(a = 0.001), meth = "holm")$results$survives)
  expect_error(falsfam(c(a = -1)), "must lie in")
  expect_error(falsfam(c(a = NA_real_)), "needs a p-value")
  expect_error(falsfam("x"), "named list")
})

test_that("a family of falsifications reports which sit at the floor", {
  set.seed(4)
  d <- data.frame(x = stats::rnorm(120))
  d$y <- 0.7 * d$x + stats::rnorm(120)
  d$a <- stats::rnorm(120)
  fam <- list(
    real = cpsfals(
      d,
      function(z) stats::cor(z$x, z$y),
      trt = "x",
      n = 99L,
      seed = 1L
    ),
    noise = cpsfals(
      d,
      function(z) stats::cor(z$a, z$y),
      trt = "a",
      n = 99L,
      seed = 2L
    )
  )
  res <- falsfam(fam, meth = "holm")
  expect_identical(res$famsz, 2L)
  expect_true(res$results$survives[res$results$name == "real"])
  expect_false(res$results$survives[res$results$name == "noise"])
  # a p-value at 1/(n+1) is the smallest the design could produce, and
  # saying so is the difference between evidence and an artefact of the
  # permutation count
  expect_identical(res$atflr, "real")
  expect_output(print(res), "permutation floor")
})

test_that("the E-value is its closed form", {
  # 2 + sqrt(2 * 1) = 3.414214, by hand
  expect_equal(unname(evlrr(2)), 2 + sqrt(2), tolerance = 1e-12)
  # the measure is symmetric about the null
  expect_identical(evlrr(0.5), evlrr(2))
  expect_identical(unname(evlrr(1)), 1)
  # an interval that already includes the null needs no confounding
  expect_identical(unname(evlrr(2, lo = 0.9, hi = 4.4)["evllimit"]), 1)
  # and a limit above the null needs some
  expect_equal(
    unname(evlrr(3, lo = 2.1, hi = 4.3)["evllimit"]),
    2.1 + sqrt(2.1 * 1.1),
    tolerance = 1e-12
  )
  # a stronger estimate is harder to explain away
  expect_gt(evlrr(5), evlrr(2))
  expect_error(evlrr(0), "finite and positive")
  expect_error(evlrr(-1), "finite and positive")
  expect_error(evlrr(Inf), "finite and positive")
})

test_that("a bundle covers the files, the manifest and itself", {
  dir <- tempfile()
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  utils::write.csv(
    data.frame(x = 1:3),
    file.path(dir, "data.csv"),
    row.names = FALSE
  )
  writeLines("notes", file.path(dir, "README.txt"))
  m <- mkmnf(list(dataset = "demo"), env = FALSE)
  key <- fipskg("ML-DSA-44")

  b <- cpsbndl(dir, m, key, note = "as published")
  p <- attr(b, "path")
  expect_true(file.exists(p))
  res <- cpsbndlvrf(p, dir, man = m, keyexp = key$public)
  expect_true(res$ok)
  expect_true(any(grepl("file:data.csv", res$checks$check)))

  # editing a covered file breaks it
  utils::write.csv(
    data.frame(x = 1:4),
    file.path(dir, "data.csv"),
    row.names = FALSE
  )
  expect_false(cpsbndlvrf(p, dir, man = m)$ok)
  utils::write.csv(
    data.frame(x = 1:3),
    file.path(dir, "data.csv"),
    row.names = FALSE
  )
  expect_true(cpsbndlvrf(p, dir, man = m)$ok)

  # a file added beside the capsule is reported: a signed list of what
  # should be there says nothing about what else was put next to it
  writeLines("sneaky", file.path(dir, "extra.csv"))
  r2 <- cpsbndlvrf(p, dir, man = m)
  expect_false(r2$ok)
  expect_false(r2$checks$ok[r2$checks$check == "no_unlisted_files"])
  file.remove(file.path(dir, "extra.csv"))

  # the file digests are INSIDE the signature, so rewriting one in the
  # bundle is caught twice over
  raw <- readLines(p)
  i <- grep("sha256", raw, fixed = TRUE)[1]
  raw[i] <- sub("[0-9a-f]{64}", strrep("a", 64), raw[i])
  tf <- tempfile(fileext = ".json")
  writeLines(raw, tf)
  r3 <- cpsbndlvrf(tf, dir, man = m)
  expect_false(r3$ok)
  expect_gte(sum(!r3$checks$ok), 2L)

  # and so is the bundle's own timestamp, which nothing else covers
  raw2 <- readLines(p)
  j <- grep("bundled_utc", raw2, fixed = TRUE)[1]
  raw2[j] <- sub("20[0-9]{2}", "1999", raw2[j])
  tf2 <- tempfile(fileext = ".json")
  writeLines(raw2, tf2)
  expect_false(cpsbndlvrf(tf2, dir, man = m)$ok)

  expect_false(cpsbndlvrf(p, dir, man = mkmnf(list(d = 2), env = FALSE))$ok)
  expect_error(cpsbndl(tempfile(), m, key), "does not exist")
  expect_error(
    cpsbndl(dir, m, key, files = "nope.csv"),
    "not in `dir`"
  )
  expect_error(cpsbndlvrf(list(), dir), "cpsbndl")
  expect_output(print(b), "Capsule bundle")
})

test_that("an RFC 3161 token verifies, and every tamper is caught", {
  fx <- readLines(test_path("timestamp-token.txt"), warn = FALSE)
  fx <- fx[!startsWith(fx, "#") & nzchar(fx)]
  parts <- strsplit(fx, "|", fixed = TRUE)
  f <- stats::setNames(
    lapply(parts, function(p) .rmbl_hex_to_raw(p[2L])),
    vapply(parts, `[[`, character(1), 1L)
  )

  # Trust is part of the verdict now: without an anchor the signature
  # still checks but nothing vouches for the certificate, and `ok` says
  # so rather than passing on a check nobody made.
  res <- tsvrf(f$rsa_token, f$payload, trust = f$ca)
  expect_s3_class(res, "bricklayer_timestamp")
  expect_true(res$ok)
  expect_s3_class(res$time, "POSIXct")
  expect_identical(res$hash_algorithm, "sha256")
  expect_true(tsvrf(f$rsa_token, f$payload, cert = f$rsa_cert, trust = f$ca)$ok)

  # the token, the data and the certificate may each arrive as raw
  # bytes, as a DER file, or -- for the certificate -- as PEM, and the
  # PEM path has its own base64 decode to get wrong
  tk <- tempfile()
  writeBin(f$rsa_token, tk)
  pl <- tempfile()
  writeBin(f$payload, pl)
  der <- tempfile()
  writeBin(f$rsa_cert, der)
  pem <- tempfile()
  writeLines(
    c(
      "-----BEGIN CERTIFICATE-----",
      strsplit(jsb64enc(f$rsa_cert), "(?<=.{64})", perl = TRUE)[[1]],
      "-----END CERTIFICATE-----"
    ),
    pem
  )
  expect_true(tsvrf(tk, pl, trust = f$ca)$ok)
  expect_true(tsvrf(tk, pl, cert = der, trust = f$ca)$ok)
  expect_true(tsvrf(tk, pl, cert = pem, trust = f$ca)$ok)
  unlink(c(tk, pl, der, pem))

  info <- tsinfo(f$rsa_token)
  expect_identical(info$hash_algorithm, "sha256")
  expect_true(info$has_certificate)
  expect_identical(info$imprint, csha256(f$payload))

  # a token is about particular bytes and nothing else
  bad <- tsvrf(f$rsa_token, charToRaw("other bytes"), trust = f$ca)
  expect_false(bad$ok)
  expect_false(bad$checks$ok[bad$checks$check == "message_imprint"])
  # and the signature was still fine, which is the point of reporting
  # the checks separately rather than one verdict
  expect_true(bad$checks$ok[bad$checks$check == "signature"])

  # flipping a byte of the TSTInfo breaks what the attributes commit to
  for (off in c(80L, 200L)) {
    t2 <- f$rsa_token
    t2[off] <- as.raw(bitwXor(as.integer(t2[off]), 1L))
    r <- tsvrf(t2, f$payload, trust = f$ca)
    expect_false(r$ok, info = as.character(off))
    expect_false(
      r$checks$ok[r$checks$check == "attribute_digest"],
      info = as.character(off)
    )
  }
  # flipping a byte of the signature breaks the RSA recovery
  t3 <- f$rsa_token
  k <- length(t3) - 40L
  t3[k] <- as.raw(bitwXor(as.integer(t3[k]), 1L))
  r3 <- tsvrf(t3, f$payload, trust = f$ca)
  expect_false(r3$ok)
  expect_false(r3$checks$ok[r3$checks$check == "signature"])

  # a certificate that is not one
  r4 <- tsvrf(f$rsa_token, f$payload, cert = charToRaw("nonsense"))
  expect_false(r4$ok)

  # malformed input is a verdict, never an error: a verifier that
  # throws on bad input is one a caller has to wrap
  expect_false(tsvrf(charToRaw("not der"), f$payload)$ok)
  expect_error(tsvrf(42, f$payload), "raw vector")
  expect_output(print(res), "Timestamp token")
})

test_that("capdeps warns about a package that is not installed", {
  expect_warning(
    capdeps(c("stats", "statz.c1.none")),
    "capdeps: not installed, recorded with NA fields: statz.c1.none"
  )
  d <- suppressWarnings(capdeps(c("stats", "statz.c1.none")))
  expect_true(is.na(d$version[d$package == "statz.c1.none"]))
  expect_no_warning(capdeps("stats"))
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

test_that("a recomputation prints as a box", {
  d <- data.frame(x = 1:10)
  m <- mkmnf(list(dataset = "demo"), env = FALSE)
  m <- recrd(m, "mean_x", obs = mean(d$x), expd = 5.5)
  m <- recrd(m, "n", obs = nrow(d), expd = 10)
  r <- mnfrcmp(m, d, list(mean_x = function(z) mean(z$x)))
  b <- o1_box(r)
  o1_expect_box(b, r, "Recomputation: see below", c("NOT recomputed", "n"))
  ok <- mnfrcmp(m, d, list(mean_x = function(z) mean(z$x), n = nrow))
  expect_true(any(grepl("VERIFIED", o1_box(ok)$out, fixed = TRUE)))
})

test_that("a recomputation that differs names each row that did not match", {
  d <- data.frame(x = 1:10)
  m <- mkmnf(list(dataset = "demo"), env = FALSE)
  m <- suppressMessages(recrd(m, "mean_x", obs = mean(d$x), expd = 5.5))
  r <- mnfrcmp(m, data.frame(x = 1:11), list(mean_x = function(z) {
    mean(z$x)
  }))
  expect_false(r$ok)
  expect_match(box_text(r), "mean_x: ", fixed = TRUE)
})
