# Attestation, the canonical manifest form, and the falsification
# controls.
#
# These three answer different questions and the tests are kept apart
# accordingly: whether the record is byte-stable, whether a signature
# binds it to a key a third party can check, and whether the finding it
# records survives having its association destroyed on purpose.

test_that("the canonical form does not depend on assembly order", {
  a <- mkmnf(list(b = 2, a = 1), env = FALSE)
  b <- mkmnf(list(a = 1, b = 2), env = FALSE)
  expect_identical(mnfdgst(a), mnfdgst(b))
  expect_identical(mnfcanon(a), mnfcanon(b))
  # nested objects too
  x <- list(meta = list(z = list(q = 1, p = 2), a = 3), results = list())
  y <- list(results = list(), meta = list(a = 3, z = list(p = 2, q = 1)))
  expect_identical(mnfdgst(x), mnfdgst(y))
  # but an ARRAY's order is content, not presentation, and must survive
  expect_false(identical(
    mnfdgst(list(v = list(1, 2))),
    mnfdgst(list(v = list(2, 1)))
  ))
  # the digest is 64 hex characters and changes with the content
  expect_match(mnfdgst(a), "^[0-9a-f]{64}$")
  expect_false(identical(
    mnfdgst(a),
    mnfdgst(list(meta = list(a = 1, b = 3)))
  ))
})

test_that("a recorded number can be recovered from the manifest", {
  # The writer used to emit four significant digits, so 1/3 was recorded
  # as 0.3333 and no later recomputation could match what was written.
  # A provenance record that cannot reproduce its own numbers is the one
  # failure mode this whole file exists to prevent.
  for (x in c(
    1 / 3, pi, 1e-300, 2^-1074, .Machine$double.xmax,
    .Machine$double.eps, 1234567.891011
  )) {
    m <- mkmnf(list(x = x), env = FALSE)
    back <- fromjs(mnfcanon(m))
    expect_identical(back$meta$x, x, info = format(x, digits = 17))
    tmp <- tempfile(fileext = ".json")
    wrmnfjs(m, tmp)
    got <- fromjs(paste(readLines(tmp), collapse = "\n"))
    expect_identical(got$meta$x, x, info = format(x, digits = 17))
    unlink(tmp)
  }
  # the canonical file is one line, so it can be hashed without
  # worrying about line endings
  m <- mkmnf(list(x = 1), env = FALSE)
  tmp <- tempfile(fileext = ".json")
  wrmnfjs(m, tmp, canon = TRUE)
  expect_length(readLines(tmp), 1L)
  expect_identical(
    csha256(charToRaw(readLines(tmp))),
    mnfdgst(m)
  )
  unlink(tmp)
})

test_that("the extremes survive, because the reader is ours", {
  # This used to be a platform limitation, and the fix was to stop
  # relying on the platform. Seventeen significant digits recover any
  # double exactly, but only through a reader that rounds correctly:
  # macOS arm64's C library reads the correct decimal for the largest
  # double as infinity, so a manifest written on Linux came back
  # different there. The package now converts decimals itself, with
  # integer arithmetic and a remainder that decides the rounding, so
  # the answer is the same on every IEEE platform.
  for (x in c(
    .Machine$double.xmax, 1e308, 1.5e300, 1e200, 1e100,
    2^-1074, 5e-324, 1e-310
  )) {
    m <- mkmnf(list(x = x), env = FALSE)
    back <- fromjs(mnfcanon(m))$meta$x
    expect_identical(back, x, info = format(x, digits = 17))
  }
  # and the text is what it should be, which is the writer's half
  expect_match(
    mnfcanon(
      mkmnf(list(x = .Machine$double.xmax), env = FALSE)
    ),
    "1.7976931348623157e+308",
    fixed = TRUE
  )
})

test_that("decimal conversion is correctly rounded, not libc's guess", {
  # The inputs below are the ones that catch a decimal-to-binary
  # converter: the boundary between the largest subnormal and the
  # smallest normal, a value whose shortest form rounds the wrong way
  # under naive arithmetic, and the ends of the range.
  # The expected values arrive as the BYTES of the double, never as a
  # decimal literal. A literal here would be converted by whatever C
  # library R was built against -- the very thing under test -- so the
  # test would compare the platform to itself, pass everywhere, and
  # prove nothing. It did exactly that: on macOS both sides moved
  # together and the assertion failed against the correct answer.
  # These patterns are glibc's, which is correctly rounded, and are
  # what any conforming converter must produce on every platform.
  dbl <- function(hex) {
    readBin(
      as.raw(strtoi(substring(
        hex, seq(1L, 15L, 2L),
        seq(2L, 16L, 2L)
      ), 16L)),
      "double",
      n = 1L, size = 8L, endian = "little"
    )
  }
  cases <- list(
    # the largest subnormal, one below the smallest normal
    "2.2250738585072011e-308" = dbl("ffffffffffff0f00"),
    "1e23" = dbl("f64ae1c7022db544"),
    "0.1" = dbl("9a9999999999b93f"),
    "0.3" = dbl("333333333333d33f"),
    "1e-323" = dbl("0200000000000000"),
    "1.7976931348623157e+308" = dbl("ffffffffffffef7f"),
    # thirty significant digits: the naive answer is two ulps high
    "123456789012345678901234567890" = dbl("3e376cff90eef845"),
    # these need no rounding, so no platform can disagree about them
    "0" = 0,
    "-0" = 0,
    "1e400" = Inf,
    "-1e400" = -Inf,
    "1e-400" = 0
  )
  for (nm in names(cases)) {
    expect_identical(.rmbl_strtod(nm), cases[[nm]], info = nm)
  }
  # a run of digits far longer than can matter is handled, not refused
  long <- paste0("1.", strrep("0", 900), "1")
  expect_identical(.rmbl_strtod(long), 1)
  expect_identical(.rmbl_strtod(paste0("1", strrep("0", 400))), Inf)
  # and unparseable input is NA rather than an error, because this sits
  # inside a parser that reports a bad document its own way
  expect_true(is.na(.rmbl_strtod("")))
  expect_true(is.na(.rmbl_strtod("abc")))
  expect_true(is.na(.rmbl_strtod("1.2.3")))
  expect_true(is.na(.rmbl_strtod("1e")))
  expect_true(is.na(.rmbl_strtod(NA_character_)))
  expect_identical(.rmbl_strtod(c("1", "2.5")), c(1, 2.5))
})


test_that("the environment record carries the generator", {
  env <- capenv()
  # Without the generator's identity a stochastic result cannot be
  # reproduced: R has changed its default sample() algorithm before, and
  # a seed means nothing without the kind it was fed to.
  expect_true("rng_kind" %in% names(env))
  expect_match(env$rng_kind, "Mersenne-Twister|Wichmann|Marsaglia|Knuth")
  expect_true(is.logical(env$rng_seeded))
  expect_true(all(c(
    "r_version", "platform", "os", "captured_utc",
    "packages"
  ) %in% names(env)))
  # and the recorded kind is the one in force
  old <- RNGkind()
  on.exit(RNGkind(old[1], old[2], old[3]), add = TRUE)
  suppressWarnings(RNGkind("Wichmann-Hill"))
  expect_match(capenv()$rng_kind, "Wichmann-Hill")
})

test_that("an attestation binds the manifest, the key and the note", {
  m <- mkmnf(list(dataset = "otis", rows = 1200L),
    env = FALSE
  )
  for (sch in c("ML-DSA-44", "SLH-DSA-SHAKE-128f")) {
    key <- fipskg(sch)
    att <- cpsatst(m, key,
      ctx = "release",
      note = "counts as published"
    )
    expect_s3_class(att, "bricklayer_attestation")
    expect_identical(att$scheme, sch)
    expect_identical(att$digest, mnfdgst(m))
    res <- cpschkatst(att, m)
    expect_true(res$ok, info = sch)
    expect_true(all(res$checks$ok))
    # naming the key that should have signed is part of the check
    expect_true(cpschkatst(att, m,
      keyexp = key$public
    )$ok, info = sch)
    expect_false(cpschkatst(att, m,
      keyexp = fipskg(sch)$public
    )$ok, info = sch)

    # every field inside the payload is covered by the signature, so
    # editing any of them afterwards is detected
    m2 <- m
    m2$meta$rows <- 1201L
    expect_false(cpschkatst(att, m2)$ok, info = sch)
    for (field in c("note", "context", "prehash", "signed_utc", "digest")) {
      bad <- att
      bad[[field]] <- paste0(bad[[field]], "x")
      expect_false(cpschkatst(bad, m)$ok,
        info = paste(sch, field)
      )
    }
    # and a signature lifted from another attestation does not fit
    other <- cpsatst(m, key, ctx = "release", note = "other")
    swapped <- att
    swapped$signature <- other$signature
    expect_false(cpschkatst(swapped, m)$ok, info = sch)
  }
})

test_that("an attestation works with the stateful hash-based key too", {
  m <- mkmnf(list(a = 1), env = FALSE)
  key <- pqckg(height = 4L)
  att <- cpsatst(m, key, note = "hash-based")
  expect_identical(att$scheme, "xmss-sha256")
  # the XMSS public key is root and public seed together: both are
  # needed to verify, so both have to be recorded
  expect_identical(nchar(att$public), 128L)
  expect_true(cpschkatst(att, m)$ok)
  m2 <- m
  m2$meta$a <- 2
  expect_false(cpschkatst(att, m2)$ok)
})

test_that("the attestation surface refuses what it cannot check", {
  m <- mkmnf(list(a = 1), env = FALSE)
  expect_error(cpsatst(m, list()), "fipskg")
  expect_error(
    cpsatst("not a manifest", fipskg("ML-DSA-44")),
    "manifest"
  )
  expect_error(cpschkatst(list(), m), "cpsatst")
  # an attestation missing a field fails rather than being read around
  att <- cpsatst(m, fipskg("ML-DSA-44"))
  stripped <- att
  stripped$public <- NULL
  res <- cpschkatst(stripped, m)
  expect_false(res$ok)
  expect_false(res$checks$ok[res$checks$check == "attestation_complete"])
  expect_output(print(att), "Capsule attestation")
  expect_output(print(cpschkatst(att, m)), "OK")
})

test_that("the falsification controls can fail, and do", {
  set.seed(1)
  d <- data.frame(x = stats::rnorm(200))
  d$y <- 0.8 * d$x + stats::rnorm(200)
  verdict <- function(r, ctrl) {
    r$controls$passed[r$controls$control == ctrl]
  }

  real <- cpsfals(d, function(z) stats::cor(z$x, z$y),
    trt = "x", n = 199L, seed = 42L
  )
  expect_s3_class(real, "bricklayer_falsification")
  expect_true(all(real$controls$passed))
  expect_length(real$permutation, 199L)

  # a constant is not an association, and the permutation control is
  # what says so: everything else about a constant is perfectly stable
  const <- cpsfals(d, function(z) 0.5,
    trt = "x",
    n = 199L, seed = 42L
  )
  expect_false(verdict(const, "permutation"))
  expect_true(verdict(const, "subset_stability"))

  # nor is noise
  noise <- data.frame(x = stats::rnorm(200), y = stats::rnorm(200))
  nul <- cpsfals(noise, function(z) stats::cor(z$x, z$y),
    trt = "x", n = 199L, seed = 7L
  )
  expect_false(verdict(nul, "permutation"))

  # a statistic that reads the injected noise column is caught by the
  # control whose whole point is that the column cannot matter
  peek <- cpsfals(
    d,
    function(z) {
      stats::cor(z$x, z$y) +
        if (".rmbl_random_common_cause" %in% names(z)) 1 else 0
    },
    trt = "x", n = 99L, seed = 3L
  )
  expect_false(verdict(peek, "random_common_cause"))
  expect_true(verdict(peek, "permutation"))
})

test_that("the permutation floor is reported rather than implied", {
  set.seed(2)
  d <- data.frame(x = stats::rnorm(60))
  d$y <- 2 * d$x + stats::rnorm(60, sd = 0.1)
  r <- cpsfals(d, function(z) stats::cor(z$x, z$y),
    trt = "x", n = 19L, seed = 1L
  )
  p <- r$controls$value[r$controls$control == "permutation"]
  # 19 permutations cannot produce a p-value below 1/20, however strong
  # the association: the floor is a property of the design, and a
  # reader who does not know it will over-read a p of 0.05
  expect_gte(p, 1 / 20)
  expect_match(
    r$controls$detail[r$controls$control == "permutation"],
    "smallest this design can report"
  )
  expect_error(cpsfals(d, function(z) 1, n = 8L), "at least 9")
})

test_that("a skipped control is reported as skipped", {
  set.seed(3)
  d <- data.frame(x = stats::rnorm(50), y = stats::rnorm(50))
  r <- cpsfals(d, function(z) mean(z$y), n = 49L, seed = 1L)
  sk <- r$controls[r$controls$control %in% c("permutation", "placebo"), ]
  expect_true(all(is.na(sk$passed)))
  expect_true(all(grepl("skipped", sk$detail)))
  # the controls that do not need a treatment still ran
  expect_true(all(!is.na(
    r$controls$passed[r$controls$control == "subset_stability"]
  )))
  expect_null(r$treatment)
  # the RNG state is recorded, so the run can be repeated
  expect_match(r$rng_kind, "Mersenne-Twister")
  expect_identical(r$seed, 1L)
  expect_output(print(r), "Falsification controls")
})

test_that("falsification input is checked", {
  d <- data.frame(x = 1:10, y = 1:10)
  expect_error(cpsfals(d[1:3, ], function(z) 1), "at least 4 rows")
  expect_error(cpsfals(as.list(d), function(z) 1), "data frame")
  expect_error(cpsfals(d, "notafunction"), "must be a function")
  expect_error(
    cpsfals(d, function(z) c(1, 2), trt = "x"),
    "one finite number"
  )
  expect_error(
    cpsfals(d, function(z) NA_real_, trt = "x"),
    "one finite number"
  )
  expect_error(cpsfals(d, function(z) stop("boom"),
    trt = "x"
  ), "the statistic failed")
  expect_error(
    cpsfals(d, function(z) 1, trt = "nope"),
    "not a column"
  )
  expect_error(
    cpsfals(d, function(z) 1, subfrac = 1),
    "between 0 and 1"
  )
})

test_that("the bundle's reader fallback works, since a bundle runs it", {
  # A capsule bundle sources json_native.R with no compiled library
  # present, so .rmbl_strtod takes its fallback branch. Inside the
  # package the native symbol is always there, which means this branch
  # ships to every bundle recipient while being the one path the test
  # suite would otherwise never run.
  cache <- get(".rmbl_native", envir = asNamespace("rmoriebricklayer"))
  old <- cache$strtod
  on.exit(
    {
      cache$strtod <- old
    },
    add = TRUE
  )

  cache$strtod <- FALSE
  expect_identical(.rmbl_strtod("0.1"), 0.1)
  expect_identical(.rmbl_strtod("1e23"), 1e23)
  expect_identical(.rmbl_strtod("-2.5"), -2.5)
  expect_identical(.rmbl_strtod("0"), 0)
  # The two paths differ on unparseable input, and that difference is
  # worth stating rather than silencing: the fallback is as.numeric(),
  # which warns as it coerces, while the native converter returns NA
  # without a word. A test that suppressed the warning would hide a
  # real behavioural divergence between the path the package takes and
  # the path a bundle takes.
  expect_warning(
    fallback_na <- .rmbl_strtod("not a number"),
    "NAs introduced by coercion"
  )
  expect_true(is.na(fallback_na))

  # and the native path, restored, agrees with it on ordinary values and
  # is silent on the input that made the fallback warn
  cache$strtod <- TRUE
  expect_identical(.rmbl_strtod("0.1"), 0.1)
  expect_identical(.rmbl_strtod("1e23"), 1e23)
  expect_silent(native_na <- .rmbl_strtod("not a number"))
  expect_true(is.na(native_na))
})

test_that("the reader is chosen once, not re-decided per number", {
  cache <- get(".rmbl_native", envir = asNamespace("rmoriebricklayer"))
  old <- cache$strtod
  on.exit(
    {
      cache$strtod <- old
    },
    add = TRUE
  )
  cache$strtod <- NULL
  invisible(.rmbl_strtod("1"))
  # the decision is recorded, so a later call does not repeat the lookup
  expect_false(is.null(cache$strtod))
  expect_true(isTRUE(cache$strtod))
})

test_that("a hash-based attestation carries its context, and a damaged key is reported", {
  m <- mkmnf(list(a = 1), env = FALSE)
  key <- pqckg(height = 4L)
  att <- cpsatst(m, key, ctx = "release")
  expect_identical(att$context, "release")
  expect_true(cpschkatst(att, m)$ok)
  bad <- att
  bad$public <- substring(att$public, 1L, 100L)
  res <- cpschkatst(bad, m)
  expect_false(res$ok)
  expect_match(res$checks$detail[res$checks$check == "signature"], "not usable")
  expect_error(.rmbl_attest_key_from(bad), "64 bytes")
})
