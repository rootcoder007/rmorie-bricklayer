# Branches the 0.5.6 review fixes added, and the pre-existing gaps in the same
# files, each exercised through the public API (or a .Call for an entry-point
# guard that the R wrappers never reach).

skip_if_no_pqc <- function() if (!exists("pqc_keygen")) skip("no pqc")

test_that("verify_capsule records the checks it cannot make", {
  d <- file.path(tempfile("cap"), "c")
  dir.create(d, recursive = TRUE)
  f <- file.path(d, "data.bin")
  writeBin(as.raw(1:10), f)
  writeLines(sprintf('{"resource":{"filename":"data.bin","sha256":"%s","row_count_data_rows":3}}',
                     sha256_file(f)), file.path(d, "data_provenance.json"))
  r <- verify_capsule(d)
  expect_false(r$ok)
  expect_match(r$checks$detail[r$checks$check == "data_readable"], "not a CSV")
  r2 <- verify_capsule(d, manifest_file = "nope.json")
  expect_match(r2$checks$detail[r2$checks$check == "manifest_consistent"], "missing or outside")
  writeLines("x <- 1", file.path(d, "a.R"))
  r3 <- verify_capsule(d, script_file = "a.R")
  expect_match(r3$checks$detail[r3$checks$check == "script_sha256"], "no script digest")
})

test_that("bundles: empty directory, foreign json, escaping and missing entries, print", {
  d <- tempfile("bundle-")
  dir.create(d)
  key <- pqc_keygen(height = 2L)
  man <- make_manifest(list(project = "p"), environment = FALSE)
  expect_error(capsule_bundle(d, man, key), "no files to bundle")
  writeLines("x", file.path(d, "a.txt"))
  capsule_bundle(d, man, key)
  p <- file.path(d, "capsule_bundle.json")
  j <- bricklayer_json_from_json(p, simplifyVector = FALSE)
  j$files[[2]] <- list(path = "../outside.txt", sha256 = strrep("0", 64), size_bytes = 1)
  j$files[[3]] <- list(path = "gone.txt", sha256 = strrep("0", 64), size_bytes = 1)
  writeLines(bricklayer_json_to_json(j, auto_unbox = TRUE, pretty = TRUE, digits = I(17)), p)
  chk <- capsule_bundle_verify(p, d, manifest = man)
  expect_false(chk$ok)
  expect_match(chk$checks$detail[chk$checks$check == "file:../outside.txt"], "not a plain relative path")
  expect_match(chk$checks$detail[chk$checks$check == "file:gone.txt"], "missing")
  expect_output(print(chk), "Bundle check: FAILED")
  nb <- tempfile(fileext = ".json")
  writeLines('{"a":1}', nb)
  expect_error(capsule_bundle_read(nb), "not a capsule bundle")
})

test_that("path and URL gates: empty, NA, symlink out, no scheme", {
  d <- tempfile("s")
  dir.create(d)
  safe <- rmoriebricklayer:::.rmbl_safe_rel
  expect_null(safe("", d))
  expect_null(safe(NA_character_, d))
  expect_null(safe(NULL, d))
  chk <- rmoriebricklayer:::.rmbl_check_public_url
  expect_error(chk("", "url"), "is empty")
  expect_error(chk("data.ontario.ca/x.csv", "url"), "no URL scheme")
  skip_on_os("windows")
  out <- tempfile("out")
  dir.create(out)
  file.create(file.path(out, "f.txt"))
  file.symlink(out, file.path(d, "link"))
  expect_null(safe("link/f.txt", d))
})

test_that("areal guards: negative counts, zero-neighbour row, non-finite matrix", {
  expect_error(expected_counts(counts = c(-1, 5), population = c(10, 20), area = c("a", "b")),
               "non-negative")
  expect_error(sir(c(-1, 2), c(1, 2)), "non-negative")
  W <- matrix(0, 4, 4)
  W[1, 2] <- W[2, 1] <- 1
  W[2, 3] <- W[3, 2] <- 1
  # area 4 has no neighbour: its weights are empty under style "W"
  m <- morans_i(c(1, 2, 3, 4), W, style = "W", n_perm = 49L)
  expect_true(is.finite(m$I))
  W[1, 2] <- NA
  expect_error(morans_i(c(1, 2, 3, 4), W), "finite")
})

test_that("trend_test refuses infinite values", {
  expect_error(trend_test(c(1, Inf, 3, 4)), "infinite")
})

test_that("JSON encoder: large integers, rounding carry, empty object, classes, arrays, complex", {
  expect_match(bricklayer_json_to_json(c(1e12, 2.5e15)), "1e\\+12|1000000000000")
  expect_match(bricklayer_json_to_json(0.99999999999, digits = 2), "^\\[1\\]$")
  expect_identical(as.character(bricklayer_json_to_json(structure(list(), names = character(0)))), "{}")
  expect_error(bricklayer_json_to_json(structure(list(1), class = c("foo", "bar"))), "S3 class: bar")
  expect_identical(as.character(bricklayer_json_to_json(structure(list(1), class = "foo"), force = TRUE)), "[[1]]")
  expect_identical(as.character(bricklayer_json_to_json(structure(function() 1, class = "foo"), force = TRUE)), "{}")
  methods::setClass("RmblTmpS4", representation(a = "numeric"), where = globalenv())
  expect_error(bricklayer_json_to_json(methods::new("RmblTmpS4", a = 1)), "S4 class")
  expect_match(bricklayer_json_to_json(methods::new("RmblTmpS4", a = 1), force = TRUE), "\"a\":\\[1\\]")
  expect_match(bricklayer_json_to_json(array(1:8, c(2, 2, 2))), "\\[\\[\\[")
  expect_match(bricklayer_json_to_json(list(list(1), list(a = 2))), "\\{\"a\":\\[2\\]\\}")
  expect_match(bricklayer_json_to_json(data.frame(a = I(list(1:2, 3)))), "\\[1,2\\]")
  expect_match(bricklayer_json_to_json(complex(real = NA, imaginary = 1)), "NA|null")
  expect_error(bricklayer_json_to_json(function() 1), "S3 class: function")
  expect_identical(as.character(bricklayer_json_to_json(function() 1, force = TRUE)), "{}")
  expect_match(bricklayer_json_to_json(list(a = 1, b = "x"), auto_unbox = TRUE), "\"a\":1")
})

test_that("JSON simplifier: dates, arrays of arrays, empty frames, unequal lengths", {
  d <- bricklayer_json_from_json('[{"a":{"$date":1700000000000}},{"a":{"$date":1700000001000}}]')
  expect_true(inherits(d$a, "POSIXct") || is.numeric(d$a) || is.list(d$a))
  expect_true(is.array(bricklayer_json_from_json("[[[1,2],[3,4]],[[5,6],[7,8]]]")))
  lst <- bricklayer_json_from_json('[[{"a":1}],[]]')
  expect_true(is.list(lst))
  sdf <- rmoriebricklayer:::.rmbl_json_simplify_df
  expect_identical(nrow(sdf(list(), columns = c("a", "b"), flatten = FALSE, simplifyMatrix = FALSE)), 0L)
  expect_identical(nrow(sdf(list(), flatten = FALSE, simplifyMatrix = FALSE)), 0L)
  expect_identical(dim(sdf(list(list(), list()), flatten = FALSE, simplifyMatrix = FALSE)), c(2L, 0L))
  expect_identical(rmoriebricklayer:::bricklayer_json_parse_json("[1]", simplifyVector = TRUE), 1L)
  expect_identical(bricklayer_json_from_json("[1,null,3]"), c(1L, NA, 3L))
})

test_that("JSON validator: surrogate pairs and every state error", {
  expect_true(isTRUE(bricklayer_json_validate('"\\ud83d\\ude00"')))
  bads <- c("-", "{1:2}", "[1:2]", "{\"a\":1 \"b\":2}", "{\"a\":1,2}", "[1,", "{\"a\"}", "{,}")
  for (bad in bads) {
    v <- bricklayer_json_validate(bad)
    expect_false(isTRUE(v), label = bad)
    expect_true(nzchar(attr(v, "err")), label = bad)
  }
})

test_that("JSON serializer: namespaces and S4 .Data round-trip under trusted = TRUE", {
  ns <- bricklayer_json_serialize(asNamespace("stats"))
  expect_match(ns, "namespace")
  expect_identical(bricklayer_json_unserialize(ns, trusted = TRUE), asNamespace("stats"))
  methods::setClass("RmblTmpNum", contains = "numeric", where = globalenv())
  obj <- methods::new("RmblTmpNum", c(1, 2, 3))
  back <- bricklayer_json_unserialize(bricklayer_json_serialize(obj), trusted = TRUE)
  expect_s4_class(back, "RmblTmpNum")
  expect_equal(as.numeric(back), c(1, 2, 3))
  expect_identical(bricklayer_json_base64_dec("@@@@"), raw(0))
})

test_that("entry points refuse a missing string and bad lengths", {
  C <- function(nm) get(nm, envir = asNamespace("rmoriebricklayer"))
  expect_error(.Call(C("C_rmbl_hmac_sha256"), character(0), "m"), "non-missing string")
  expect_error(.Call(C("C_rmbl_shake"), 256L, character(0), 4L), "non-missing string")
  expect_error(.Call(C("C_rmbl_pbkdf2"), character(0), "salt", 1L, 16L), "non-missing string")
  expect_error(.Call(C("C_rmbl_xmss_keygen"), character(0), "00", 2L), "non-missing string")
  expect_error(.Call(C("C_rmbl_ecdsa_verify"), character(0), raw(32), raw(32), raw(32), raw(32), raw(32)),
               "curve")
  # XMSS guards
  h64 <- strrep("11", 32)
  expect_error(.Call(C("C_rmbl_xmss_keygen"), "zz", h64, 2L), "sk_seed")
  expect_error(.Call(C("C_rmbl_xmss_keygen"), h64, "zz", 2L), "pub_seed")
  expect_error(.Call(C("C_rmbl_xmss_sign"), "zz", h64, h64, 2L, 0L, "m"), "sk_seed")
  expect_error(.Call(C("C_rmbl_xmss_sign"), h64, "zz", h64, 2L, 0L, "m"), "sk_prf")
  expect_error(.Call(C("C_rmbl_xmss_sign"), h64, h64, "zz", 2L, 0L, "m"), "pub_seed")
  expect_error(.Call(C("C_rmbl_xmss_sign"), h64, h64, h64, 2L, 4L, "m"), "exhausted")
  expect_false(.Call(C("C_rmbl_xmss_verify"), "zz", h64, 2L, 0L, "m", "00", "00", h64))
  expect_false(.Call(C("C_rmbl_xmss_verify"), h64, "zz", 2L, 0L, "m", "00", "00", h64))
  expect_false(.Call(C("C_rmbl_xmss_verify"), h64, h64, 2L, 0L, "m", "zz", "00", h64))
  expect_false(.Call(C("C_rmbl_xmss_verify"), h64, h64, 2L, 0L, "m", strrep("00", 67 * 32), "zz", h64))
  # RSA recovery guards
  expect_error(.Call(C("C_rmbl_rsa_recover"), "a", raw(4), raw(1)), "raw vectors")
  expect_error(.Call(C("C_rmbl_rsa_recover"), raw(4), raw(1025), raw(1)), "implausibly large")
  expect_error(.Call(C("C_rmbl_rsa_recover"), raw(4), raw(4), as.raw(3)), "modulus is zero")
  expect_error(.Call(C("C_rmbl_rsa_recover"), as.raw(c(0, 0, 0, 9)), as.raw(c(0, 0, 0, 7)), as.raw(3)),
               "not less than the modulus")
  # DER high-tag-number form
  node <- .Call(C("C_rmbl_der_parse"), as.raw(c(0x1f, 0x81, 0x01, 0x00)))
  expect_equal(node$tag, 129)
  # ML-DSA entry guards
  expect_error(.Call(C("C_rmbl_mldsa_keypair"), 99L, raw(32)), "44, 65 or 87")
  expect_error(.Call(C("C_rmbl_mldsa_keypair"), c(44L, 65L), raw(32)), "single integer|44, 65 or 87")
  expect_error(.Call(C("C_rmbl_mldsa_keypair"), 44L, raw(31)), "32 bytes")
  kp <- .Call(C("C_rmbl_mldsa_keypair"), 44L, as.raw(1:32))
  sk <- kp[[2]]
  expect_error(.Call(C("C_rmbl_mldsa_sign"), 44L, sk, raw(3), raw(256), raw(32), NULL), "at most 255")
  expect_error(.Call(C("C_rmbl_mldsa_sign"), 44L, sk, raw(3), raw(0), raw(31), NULL), "32 bytes")
  expect_error(.Call(C("C_rmbl_mldsa_sign_mu"), 44L, sk, raw(63), raw(32)), "64 bytes")
  expect_error(.Call(C("C_rmbl_mldsa_sign_mu"), 44L, sk, raw(64), raw(31)), "32 bytes")
  expect_false(.Call(C("C_rmbl_mldsa_verify_mu"), 44L, kp[[1]], raw(63), raw(10)))
  expect_false(.Call(C("C_rmbl_mldsa_verify"), 44L, kp[[1]], raw(3), raw(0), raw(10), NULL))
  expect_false(.Call(C("C_rmbl_mldsa_verify"), 44L, kp[[1]], raw(3), raw(256), raw(10), NULL))
  # ECDSA verify: out-of-range r/s and a point off the curve, plus a digest longer than n
  one <- as.raw(c(rep(0, 31), 1))
  expect_false(.Call(C("C_rmbl_ecdsa_verify"), "P-256", one, one, raw(32), one, one))
  expect_false(.Call(C("C_rmbl_ecdsa_verify"), "P-256", as.raw(rep(255, 32)), one, one, one, one))
  expect_false(.Call(C("C_rmbl_ecdsa_verify"), "P-256", one, one, one, one, as.raw(rep(7, 64))))
  expect_error(.Call(C("C_rmbl_ecdsa_verify"), "P-999", one, one, one, one, one), "unsupported curve")
  expect_error(.Call(C("C_rmbl_ecdsa_verify"), "P-256", "x", one, one, one, one), "raw vectors")
})

test_that("ML-DSA sampling refills its squeeze buffer across many seeds", {
  C <- function(nm) get(nm, envir = asNamespace("rmoriebricklayer"))
  ok <- 0L
  for (i in 1:40) {
    seed <- as.raw((i * 7 + 0:31) %% 256)
    kp <- .Call(C("C_rmbl_mldsa_keypair"), 87L, seed)
    sig <- .Call(C("C_rmbl_mldsa_sign_mu"), 87L, kp[[2]], as.raw(1:64), seed)
    ok <- ok + .Call(C("C_rmbl_mldsa_verify_mu"), 87L, kp[[1]], as.raw(1:64), sig)
  }
  expect_identical(ok, 40L)
})
