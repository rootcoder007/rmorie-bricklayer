testthat::skip_on_cran()  # battery: runs in CI and locally; CRAN runs the correctness core
# Second review round (2026-10-06): the neighbours of every 0.5.6 fix, each
# pinned here through the public API or the registered entry point.

C <- function(nm) get(nm, envir = asNamespace("rmoriebricklayer"))

test_that("every entry point answers a hostile argument with an R error, never an abort", {
  expect_error(.Call(C("C_rmbl_hawkes_rescaled"), NULL, NULL, NULL, NULL, NULL, NULL, NULL), "bkind")
  expect_error(.Call(C("C_rmbl_hawkes_em_pass"), numeric(10), numeric(2), 1, 0L, 1, 1), "lamOld")
  expect_error(.Call(C("C_rmbl_shake"), 128L, as.raw(1), 2147483647L), "16 MiB")
  expect_error(.Call(C("C_rmbl_theil_sen"), numeric(5e6), 1.0), "same length")
  expect_error(.Call(C("C_rmbl_sen_slopes"), rep(0.5, 1e6), rep(0.5, 1e6)), "20000")
  expect_error(.Call(C("C_rmbl_reservoir"), 2147483647L, 2147483647L, 1L), "1e8")
  expect_error(.Call(C("C_rmbl_pbkdf2"), "p", "s", 2147483647L, 16L), "2\\^26")
  expect_error(.Call(C("C_rmbl_hmac_sha256"), NA_character_, "m"), "non-missing")
  expect_error(.Call(C("C_rmbl_fetch_fallback"), NA_character_, "", tempfile(), 5L, ""), "non-missing")
  expect_error(.Call(C("C_rmbl_siu_to_iso_date"), strrep("x", 100000)), "longer than 4096 bytes")
  # the generator that keeps the barrier in step with init.c ships with the package
  expect_true(file.exists(system.file("scripts", "gen_barrier.R", package = "rmoriebricklayer")))
})

test_that("the RSA public exponent is bounded, so a hostile certificate cannot buy hours of CPU", {
  n <- as.raw(c(0xc0, rep(0xff, 127)))
  s <- as.raw(rep(0x42, 128))
  expect_error(.Call(C("C_rmbl_rsa_recover"), s, n, as.raw(c(1, rep(0xff, 1023)))), "exponent is implausibly large")
  t <- system.time(.Call(C("C_rmbl_rsa_recover"), s, n, as.raw(c(1, rep(0xff, 63)))))[["elapsed"]]
  expect_lt(t, wall_limit(2))
})

test_that("the DER parser refuses BER: non-minimal lengths and padded tags", {
  expect_error(.Call(C("C_rmbl_der_parse"), as.raw(c(0x04, 0x87, 0, 0, 0, 0, 0, 0, 0x01, 0x41))), "not well-formed")
  expect_error(.Call(C("C_rmbl_der_parse"), as.raw(c(0x04, 0x81, 0x01, 0x41))), "not well-formed")
  expect_error(.Call(C("C_rmbl_der_parse"), as.raw(c(0x1f, 0x80, 0x80, 0x01, 0x01, 0xff))), "not well-formed")
  expect_error(.Call(C("C_rmbl_der_parse"), as.raw(c(0x00, 0x00))), "not well-formed")
  expect_identical(.Call(C("C_rmbl_der_parse"), as.raw(c(0x04, 0x01, 0x41)))$value, as.raw(0x41))
})

test_that("the URL gate canonicalises instead of matching spellings", {
  bad <- c("https://127.1/x", "https://0177.0.0.1/x", "https://2130706433/x", "https://0x7f000001/x",
           "https://0x7f.1/x", "https://[0::1]/x", "https://[::0001]/x", "https://[0:0:0:0:0:ffff:7f00:1]/x",
           "https://localhost./x", "https://metadata.google.internal/x", "https://foo.local/x",
           "https://169.254.169.254#@example.com/", "https://169.254.169.254?@example.com/",
           "https://127.0.0.1#@good.example/", "https://user:pass@127.0.0.1/", "https://good@data.ontario.ca/",
           "https://100.64.0.1/x", "https://[fe80::1]/x", "https://[fd00::1]/x", "https://[64:ff9b::7f00:1]/x")
  for (u in bad) expect_error(rmoriebricklayer:::.rmbl_check_public_url(u), "local|private|refused", label = u)
  chk <- rmoriebricklayer:::.rmbl_check_public_url
  expect_identical(chk("https://data.ontario.ca/x.csv"), "https://data.ontario.ca/x.csv")
  expect_identical(chk("https://DATA.ontario.ca:443/x"), "https://DATA.ontario.ca:443/x")
  expect_error(rmoriebricklayer:::.rmbl_check_public_url("https://data.ontario.ca:99999/x"), "port")
  why <- function(h) rmoriebricklayer:::.rmbl_url_why(paste0("https://", h, "/"))
  expect_true(nzchar(why("0x7f000001")))
  expect_true(nzchar(why("[::ffff:127.0.0.1]")))
  expect_false(nzchar(why("data.ontario.ca")))
  # the name resolves to loopback: refused when resolving, whatever it is called
  expect_error(rmoriebricklayer:::.rmbl_check_public_url("https://localhost./x", resolve = TRUE), "local")
  # the transport is gated too, before any network
  expect_error(blfetch("https://127.1/x", tempfile()), "local or private")
  expect_error(wbsnpnat("https://0x7f000001/x"), "local or private")
})

cap <- function() {
  d <- file.path(tempfile("cap2-"), "c")
  dir.create(d, recursive = TRUE)
  f <- file.path(d, "data.csv")
  utils::write.csv(data.frame(region = c("A", "B"), count = c(10, 20)), f, row.names = FALSE)
  writeLines(sprintf('{"resource":{"filename":"data.csv","sha256":"%s"}}', sha256file(f)),
             file.path(d, "data_provenance.json"))
  list(dir = d, file = f)
}

test_that("vrfcps contains the provenance path like every other path", {
  cp <- cap()
  out <- file.path(dirname(cp$dir), "out")
  dir.create(out)
  utils::write.csv(data.frame(region = c("A", "B"), count = c(10, 999)), cp$file, row.names = FALSE)
  writeLines(sprintf('{"resource":{"filename":"data.csv","sha256":"%s"}}', sha256file(cp$file)),
             file.path(out, "evil.json"))
  expect_false(vrfcps(cp$dir)$ok)
  r <- vrfcps(cp$dir, provfile = "../out/evil.json")
  expect_false(r$ok)
  expect_false(r$checks$ok[r$checks$check == "provenance_readable"])
  skip_on_os("windows")
  unlink(file.path(cp$dir, "data_provenance.json"))
  file.symlink(normalizePath(file.path(out, "evil.json")), file.path(cp$dir, "data_provenance.json"))
  expect_false(vrfcps(cp$dir)$ok)
})

test_that("vrfcps records the synthetic verdict, the manifest and malformed fields as rows", {
  cp <- cap()
  r <- vrfcps(cp$dir)
  expect_true(r$ok)
  expect_true("data_not_synthetic" %in% r$required)
  expect_true("data_not_synthetic" %in% r$checks$check)
  # the sidecar makes the row fail; removing the sidecar does not remove the row
  writeLines("generated", paste0(cp$file, ".synthetic"))
  r2 <- vrfcps(cp$dir)
  expect_false(r2$ok)
  expect_false(r2$checks$ok[r2$checks$check == "data_not_synthetic"])
  unlink(paste0(cp$file, ".synthetic"))
  # a manifest.json in the capsule is checked by default, and is required
  man <- mkmnf(list(project = "p"), env = FALSE)
  man$results$r1 <- list(observed = 1, expected = 1, tol = 0.1, status = "DIFFER")
  wrmnfjs(man, file.path(cp$dir, "manifest.json"))
  r3 <- vrfcps(cp$dir)
  expect_true("manifest_consistent" %in% r3$required)
  expect_false(r3$checks$ok[r3$checks$check == "manifest_consistent"])
  unlink(file.path(cp$dir, "manifest.json"))
  # a manifest that says synthetic fails the synthetic row
  man$results <- list()
  man$meta$synthetic <- TRUE
  wrmnfjs(man, file.path(cp$dir, "manifest.json"))
  r4 <- vrfcps(cp$dir)
  expect_false(r4$checks$ok[r4$checks$check == "data_not_synthetic"])
  unlink(file.path(cp$dir, "manifest.json"))
  # structures where a string belongs are failed rows, not R errors
  for (prov in c('{"resource":{"filename":"data.csv","sha256":{}}}',
                 '{"resource":{"filename":"data.csv","sha256":[]}}',
                 '{"resource":{"filename":"data.csv","sha256":["a","b"]}}',
                 '{"resource":{"filename":{"n":"data.csv"},"sha256":"00"}}',
                 '{"resource":{"filename":["data.csv","x"],"sha256":"00"}}')) {
    writeLines(prov, file.path(cp$dir, "data_provenance.json"))
    rr <- vrfcps(cp$dir)
    expect_false(rr$ok, label = prov)
  }
  # a directory where the data file should be
  dir.create(file.path(cp$dir, "d.csv"))
  writeLines('{"resource":{"filename":"d.csv","sha256":"00"}}', file.path(cp$dir, "data_provenance.json"))
  rr <- vrfcps(cp$dir)
  expect_false(rr$checks$ok[rr$checks$check == "data_present"])
})

test_that("mkmnf leaves a real-data digest alone and owns the synthetic flag in-process", {
  st <- rmoriebricklayer:::.rmbl_synth_state
  old <- st$made
  on.exit(st$made <- old, add = TRUE)
  st$made <- FALSE
  x <- mnfdgst(list(meta = list(dataset = "x"), results = list()))
  y <- mnfdgst(mkmnf(list(dataset = "x"), env = FALSE))
  expect_identical(x, y)
  f <- tempfile(fileext = ".csv")
  mksyncsv(list(seed = 3L, n_rows = 5L,
                          columns = list(region = list(type = "sample", values = list("E", "W")))), f)
  expect_true(mkmnf(list(dataset = "x"), env = FALSE)$meta$synthetic)
})

test_that("mnfdgst is injective on an empty key", {
  A <- fromjs('{"meta":{"":"X","a":1},"results":{}}', simplifyVector = FALSE)
  B <- fromjs('{"meta":{"1":"X","a":1},"results":{}}', simplifyVector = FALSE)
  expect_match(as.character(mnfcanon(A)), '"":"X"', fixed = TRUE)
  expect_false(identical(mnfdgst(A), mnfdgst(B)))
  k <- fipskg("ML-DSA-44")
  att <- cpsatst(A, k)
  expect_true(cpschkatst(att, A)$ok)
  expect_false(cpschkatst(att, B)$ok)
})

test_that("JSON strings are assembled in linear time, and the reformatter refuses what the parser refuses", {
  txt <- paste0('["', strrep("\\n", 65536L), '"]')
  t <- system.time(v <- fromjs(txt))[["elapsed"]]
  expect_identical(nchar(v), 65536L)
  expect_lt(t, wall_limit(5))
  expect_error(fromjs('{"a":"\\ud83d"}'), "surrogate")
  expect_error(fromjs('{"a":"x\\u0000y"}'), "NUL")
  expect_error(fromjs(paste0(strrep("[", 101), strrep("]", 101))), "100 levels")
  deep <- Reduce(function(acc, i) list(acc), seq_len(101), accumulate = FALSE, right = FALSE, list(1))
  expect_error(tojs(deep), "100 levels")
  expect_silent(tojs(Reduce(function(acc, i) list(acc), seq_len(90), list(1))))
  expect_error(jsb64dec("!!!!"), "alphabet")
  expect_error(jsb64dec("@@@@"), "alphabet")
  expect_identical(jsb64dec("YWJj"), charToRaw("abc"))
  expect_warning(fromjs("[9007199254740993.0]"), "beyond 2\\^53")
  expect_warning(fromjs("[9.007199254740993e15]"), "beyond 2\\^53")
  expect_silent(fromjs("[9007199254740993.0]", bigint_warn = FALSE))
  expect_silent(rmoriebricklayer:::.rmbl_read_json('{"id":9007199254740993,"a":1,"a":2}', strict = FALSE))
  expect_error(rmoriebricklayer:::.rmbl_read_json('{"a":1,"a":2}'), "duplicate key")
})

test_that("cpsdrft: identifier columns are not distributions, dates are numbers, same data is no drift", {
  set.seed(10)
  a <- data.frame(id = as.character(sample(5000, 2000, TRUE)))
  b <- data.frame(id = as.character(sample(5000, 2000, TRUE)))
  d <- cpsdrft(a, b, alpha = 0.01)
  expect_identical(d$columns$type, "identifier")
  expect_true(is.na(d$columns$drifted))
  expect_false(d$anydrft)
  expect_true(d$columns$unseen_share > 0.3 && d$columns$unseen_share < 0.8)
  set.seed(11)
  fp <- 0L
  for (i in 1:20) {
    a <- data.frame(g = as.character(sample(50, 2000, TRUE)))
    b <- data.frame(g = as.character(sample(50, 2000, TRUE)))
    fp <- fp + isTRUE(cpsdrft(a, b, alpha = 0.01)$columns$drifted)
  }
  expect_lte(fp, 2L)
  ref <- data.frame(day = as.character(as.Date("2020-01-01") + 1:400))
  cur <- data.frame(day = as.character(as.Date("2024-06-01") + 1:400))
  dd <- cpsdrft(ref, cur)
  expect_identical(dd$columns$type, "date")
  expect_true(dd$columns$drifted)
  same <- cpsdrft(ref, ref)
  expect_false(same$columns$drifted)
})

test_that("drfthomog leaves the RNG alone and says when it does not apply", {
  a <- c(x = 3, y = 2, z = 1)
  b <- c(x = 1, y = 2, z = 3)
  set.seed(7)
  u1 <- stats::runif(1)
  set.seed(7)
  invisible(drfthomog(a, b))
  u2 <- stats::runif(1)
  expect_identical(u1, u2)
  expect_identical(drfthomog(a, b)[["p_value"]], drfthomog(a, b)[["p_value"]])
  ref <- as.character(as.Date("2020-01-01") + 1:400)
  cur <- as.character(as.Date("2024-06-01") + 1:400)
  h <- drfthomog(table(ref), table(cur))
  expect_true(is.na(h[["p_value"]]))
  expect_match(attr(h, "method"), "inapplicable")
  expect_error(drfthomog(c(a = -5, b = 10), c(a = 5, b = 5)), "non-negative")
  expect_error(drfthomog(c(a = NA, b = 10), c(a = 5, b = 5)), "finite")
  expect_error(drftchisq(c(a = 5, b = 10), c(a = Inf, b = 1)), "finite")
})

test_that("chi-square sites carry the log p-value past the double's floor", {
  d <- drftchisq(c(a = 1e6, b = 1), c(a = 1, b = 1))
  expect_identical(d[["p_value"]], 0)
  expect_lt(d[["logpvalue"]], -1000)
  dh <- drfthomog(table(rep(paste0("a", 1:20), each = 100)), table(rep(paste0("b", 1:20), each = 100)))
  expect_lt(dh[["logpvalue"]], -500)
  set.seed(1)
  b <- benfordtst(stats::rnorm(1e5))
  expect_lt(b$logpvalue, -100)
  expect_equal(exp(drftchisq(c(a = 60, b = 40), c(a = 50, b = 50))[["logpvalue"]]),
               drftchisq(c(a = 60, b = 40), c(a = 50, b = 50))[["p_value"]])
})

test_that("cramerv drops an unused level instead of returning NaN", {
  cv <- cramerv(matrix(c(5, 3, 0, 0, 4, 6), nrow = 2))
  expect_false(is.nan(cv$v))
  expect_identical(cv$df, 1L)
  expect_match(cv$method, "dropped")
  expect_equal(cv$v, cramerv(matrix(c(5, 3, 4, 6), nrow = 2))$v)
})

test_that("concentration and tail measures refuse empty input instead of returning NA", {
  expect_error(ginicoef(numeric(0)), "no values")
  expect_error(ginicoef(rep(0, 5)), "every value is zero")
  expect_error(topshr(numeric(0), 0.1), "no values")
  expect_error(hilltlidx(numeric(0)), "no positive")
  expect_equal(ginicoef(c(1, 1, 1, 1)), 0)
})

test_that("prsbands reads trailing units, refuses cue words anywhere, and survives an en dash", {
  p <- prsbands(c("18 to 24 (years)", "0 to 5 overnight stays", "5 to 9 years, inclusive",
                     "under 18 to 24", "over 10 to 20", "more than 10 - 20", "12,34,567+",
                     "1,000 to 2,499", "18\u201324", "less than 0.5", "under 0"))
  expect_equal(p$lower[1:3], c(18, 0, 5))
  expect_equal(p$upper[1:3], c(24, 5, 9))
  expect_true(all(is.na(p$lower[4:7])))
  expect_true(all(is.na(p$upper[4:7])))
  expect_equal(c(p$lower[8], p$upper[8]), c(1000, 2499))
  expect_equal(c(p$lower[9], p$upper[9]), c(18, 24))
  # a decimal label is on a decimal scale: "less than 0.5" is below 0.5, not at most -0.5
  expect_equal(p$upper[10], 0.5)
  expect_true(p$openlo[10])
  bv <- bandvals(prsbands("under 0"))
  expect_lte(bv$value, bv$upper)
  expect_error(bandvals(prsbands(c("under 5", "10 to 20")), openloflr = 100), "floor")
  expect_error(bandvals(prsbands("50+"), openupcap = 10), "cap")
})

test_that("trend helpers: the clamp flag, zero counts, infinite values, the exact switch", {
  set.seed(3)
  r <- trndtst(c(1, 3, 2, 5, 4), conflvl = 0.90)
  expect_true(r$slopecicla)
  expect_error(cnttrnd(rep(0, 10)), "every count is zero")
  expect_error(stepchg(c(1, 2, Inf, 4, 5, 6)), "infinite")
  expect_warning(trndtst(c(1, 3, 2, 5, 4, 6, 8, 7, 9, 10), exact = TRUE), "up to n = 8")
  t1 <- system.time(for (i in 1:20) trndtst(c(1, 1, 2, 2, 3, 3, 4, 4), exact = TRUE))[["elapsed"]]
  expect_lt(t1, wall_limit(10))
})

test_that("morani refuses negative weights and a constant variable", {
  W <- matrix(0, 4, 4)
  W[1, 2] <- W[2, 1] <- 1
  W[2, 3] <- W[3, 2] <- 1
  W[3, 4] <- W[4, 3] <- 1
  expect_error(morani(c(1, 2, 3, 4), -W), "non-negative")
  expect_error(morani(c(2, 2, 2, 2), W), "constant")
})

test_that("Hurwitz zeta at non-positive integers and the first digit of a subnormal", {
  expect_equal(hurwzeta(0, 1), -0.5)
  expect_equal(hurwzeta(-1, 1), -1 / 12)
  expect_equal(hurwzeta(-2, 1), 0)
  counts <- .Call(C("C_rmbl_first_digit_counts"), c(1e-310, 2e-300, 7e120))
  expect_equal(counts, c(1, 1, 0, 0, 0, 0, 1, 0, 0))
})

test_that("PSI: validated eps, and a float jitter on tied integers does not move bins", {
  set.seed(5)
  x <- stats::rpois(5000, 3)
  expect_equal(drftpsi(x, x + 1e-12)[["psi"]], 0)
  expect_equal(drftpsi(x, x - 1e-12)[["psi"]], 0)
  expect_error(drftpsi(x, x, eps = 0), "eps")
  expect_error(drftpsi(x, x, eps = -1), "eps")
})


test_that("ML-DSA refuses a corrupt secret key at once instead of looping on it", {
  kp <- .Call(C("C_rmbl_mldsa_keypair"), 44L, as.raw(1:32))
  sk <- kp[[2]]
  # s1 is packed after rho (32), K (32) and tr (64): bytes outside the
  # [-eta, eta] encoding can only come from corruption
  sk[129:260] <- as.raw(0xff)
  t <- system.time(
    expect_error(.Call(C("C_rmbl_mldsa_sign"), 44L, sk, as.raw(1:3), raw(0), raw(32), NULL, TRUE), "malformed")
  )[["elapsed"]]
  expect_lt(t, wall_limit(1))
  # a sound key signs in well under the attempt cap
  sig <- .Call(C("C_rmbl_mldsa_sign"), 44L, kp[[2]], as.raw(1:3), raw(0), raw(32), NULL, TRUE)
  expect_true(.Call(C("C_rmbl_mldsa_verify"), 44L, kp[[1]], as.raw(1:3), raw(0), sig, NULL))
})
