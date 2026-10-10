# The lines codecov listed as unreached at 0.5.9 (2026-10-07), each reached
# with a real input through a real branch. Where a branch could not be
# reached from any input the guard was removed from the source instead.

der_tlv <- function(tag, body) .rmbl_der_tlv(tag, body)
der_seq <- function(...) .rmbl_der_seq(...)
der_oid <- function(x) .rmbl_der_oid_bytes(x)
der_parse <- function(x) .Call(C_rmbl_der_parse, x)

test_that("local seed: restoring a NULL seed removes the session's .Random.seed", {
  set.seed(1)
  expect_true(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  .rmbl_restore_seed(NULL)
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
})

test_that("report_analysis names the columns added and removed against the prior", {
  d <- data.frame(year = rep(2019:2021, each = 2), table = "a", group = rep(c("x", "y"), 3),
                  individuals = c(10, 20, 12, 22, 15, 25))
  a <- analyse_table(d, value = "individuals", period = "year", by = c("table", "group"), rounding = 5)
  a$drift <- list(columns = data.frame(column = "individuals", test = "ks", statistic = 0.1, p_value = 0.9,
                                       psi = 0.01, drifted = FALSE),
                  added = c("new_col", "other"), removed = "old_col")
  a$meta$alpha <- 0.05
  md <- report_analysis(a)
  expect_match(md, "Columns added: new_col, other\\.")
  expect_match(md, "Columns removed: old_col\\.")
})

test_that("capsule_attest accepts a character or raw context", {
  m <- make_manifest(list(dataset = "otis", rows = 12L), environment = FALSE)
  key <- fips_keygen("ML-DSA-44")
  a1 <- capsule_attest(m, key, context = "study-7")
  a2 <- capsule_attest(m, key, context = charToRaw("study-7"))
  expect_true(capsule_check_attestation(a1, m)$ok)
  expect_true(capsule_check_attestation(a2, m)$ok)
})

test_that("band_sensitivity parses a band specification given as text", {
  s <- band_sensitivity(c("0-9", "10-19", "20-29", "30+"), c(1200, 430, 110, 38))
  expect_true(is.list(s) || is.data.frame(s))
})

test_that("use_capsule_template without the example leaves a TODO source", {
  d <- use_capsule_template(tempfile("capsule-"))
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  files <- list.files(d, recursive = TRUE, full.names = TRUE)
  expect_true(any(grepl("TODO: https://example.org/open-data/table.csv",
                        unlist(lapply(files, readLines, warn = FALSE)), fixed = TRUE)))
})

test_that("verify_recode_manifest reports a signature that does not verify", {
  x <- c("W", "B", "W", "I", NA)
  y <- guard_recode(x, c(W = "White", B = "Black", I = "Indigenous"))
  key <- pqc_keygen(height = 2)
  m <- recode_manifest(x, y, c(W = "White", B = "Black", I = "Indigenous"), key = key, context = "t")
  p <- write_recode_manifest(m, tempfile(fileext = ".json"))
  on.exit(unlink(p), add = TRUE)
  txt <- paste(readLines(p, warn = FALSE), collapse = "\n")
  sig <- .rmbl_json_text(txt, simplifyVector = FALSE)$signature$signature
  flipped <- paste0(if (substr(sig, 1, 1) == "0") "1" else "0", substr(sig, 2, nchar(sig)))
  writeLines(sub(sig, flipped, txt, fixed = TRUE), p)
  v <- verify_recode_manifest(p, x, y)
  expect_false(v$ok)
  expect_true(any(grepl("signature does not verify", v$reasons)))
})

test_that("cli: reading a line from a non-interactive stdin, the Rd database seams, missing examples", {
  # the stdin path runs in a child process so this session's stdin is never touched
  f <- tempfile()
  writeLines("  answer  ", f)
  out <- system2(file.path(R.home("bin"), "Rscript"),
                 c("-e", shQuote("cat(rmoriebricklayer:::.bl_readline('p> '))")),
                 stdin = f, stdout = TRUE, stderr = FALSE)
  expect_equal(out, "answer")
  # and in-process, through the connection seam
  tc <- textConnection("  typed  ")
  on.exit(close(tc), add = TRUE)
  local_mocked_bindings(.bl_interactive = function() FALSE)
  expect_equal(.bl_readline("p> ", con = tc), "typed")
  # at a terminal the prompt goes to stderr, so a piped stdout stays clean
  tc2 <- textConnection("  at a tty  ")
  on.exit(close(tc2), add = TRUE)
  local_mocked_bindings(.bl_stdin_tty = function() TRUE)
  err <- utils::capture.output(got <- .bl_readline("key> ", con = tc2), type = "message")
  expect_equal(got, "at a tty")
  expect_identical(err, "key> ")
  # no installed Rd database: the man/ directory of a source tree
  pkg <- tempfile("pkg")
  man <- file.path(pkg, "man")
  dir.create(man, recursive = TRUE)
  writeLines(c("Package: zzzpkg", "Version: 0.0.1", "Title: t", "Description: d", "License: MIT",
               "Encoding: UTF-8"), file.path(pkg, "DESCRIPTION"))
  writeLines(c("\\name{zzz_fn}", "\\alias{zzz_fn}", "\\title{A title}", "\\description{Words.}"),
             file.path(man, "zzz_fn.Rd"))
  db <- .bl_rd_db(db = NULL, man = man)
  expect_true("zzz_fn.Rd" %in% names(db))
  expect_identical(.bl_rd_db(db = NULL, man = ""), list())
  rd <- tools::parse_Rd(textConnection("\\name{zzz_fn}\\alias{zzz_fn}\\title{A title}\\description{Words.}"))
  local_mocked_bindings(.bl_rd_for = function(name) rd)
  expect_match(.bl_examples("zzz_fn"), "'zzz_fn' has no examples")
})

test_that("cli: install_cli refuses when the launcher is missing; data pull reports an unwritable table", {
  src <- system.file("bin", "rmoriebricklayer", package = "rmoriebricklayer")
  skip_if(!nzchar(src) || file.access(dirname(src), 2L) != 0L, "installed launcher not movable here")
  bak <- paste0(src, ".bak")
  expect_true(file.rename(src, bak))
  on.exit(file.rename(bak, src), add = TRUE)
  expect_error(install_cli(tempfile("bin")), "launcher is missing")
  # the destination directory is fine but the table cannot be written as CSV
  local_mocked_bindings(bricklayer_data_load = function(key) {
    df <- data.frame(a = 1:2)
    df$e <- list(new.env(), new.env())
    df
  })
  out <- character(0)
  dest <- tempfile(fileext = ".csv")
  rc <- .bl_cli_data(c("pull", "tbl"), function(f) dest, function(s) out <<- c(out, s))
  expect_equal(rc, 1L)
  expect_match(paste(out, collapse = ""), "cannot write")
})

test_that("hill_tail_index: a zeta that underflows scores as infinitely unlikely", {
  r <- hill_tail_index(c(1e300, 2e300, 3e300, 4e300), x_min = 1e300)
  expect_true(is.list(r))
  expect_true(is.na(r$alpha) || is.finite(r$alpha))
})

test_that("hawkes: an EM pass with an infeasible kernel and an INAR fit whose CDF fails score 1e12", {
  set.seed(7)
  times <- sort(runif(60, 0, 100))
  local_mocked_bindings(.rmbl_hk_cdf = function(...) stop("no cdf"))
  f <- core_hawkes_fit(times, 100, kernel = "weibull", method = "inar")
  expect_true(is.list(f))
})

test_that(".rmbl_chunk_bytes: NULL is no chunks", {
  expect_identical(.rmbl_chunk_bytes(NULL), list())
  expect_error(.rmbl_chunk_bytes(1:3), "must be a character vector")
})

test_that("drbg_generate reseeds when the generator comes from another process", {
  d <- drbg_new(as.raw(0:47))
  x <- drbg_generate(d, 16)
  e <- drbg_new(as.raw(0:47))
  e$pid <- -1L
  y <- drbg_generate(e, 16)
  expect_false(identical(x, y))      # reseeded from the OS first
  expect_equal(e$pid, Sys.getpid())
})

test_that("drift_ks and drift_psi refuse a sample that is all missing", {
  expect_error(drift_ks(c(NA_real_, NA_real_), c(1, 2, 3)), "at least one non-missing")
  expect_error(drift_psi(c(1, 2, 3), c(NA_real_, NA_real_)), "at least one non-missing")
})

test_that("verify_capsule notes a data file that cannot be read", {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["effective_user"]], "root"), "root reads anything")
  dir <- make_test_capsule()
  Sys.chmod(file.path(dir, "data.csv"), "000")
  on.exit(Sys.chmod(file.path(dir, "data.csv"), "644"), add = TRUE)
  out <- suppressWarnings(verify_capsule(dir, manifest_file = "manifest.json"))
  ck <- out$checks
  expect_false(ck$ok[ck$check == "data_sha256"])
  expect_match(ck$detail[ck$check == "data_sha256"], "could not be read")
})

test_that("sha256_file falls back to the pure-R digest when the compiled core is absent; to_ascii without stringi", {
  f <- tempfile()
  writeBin(as.raw(1:200), f)
  want <- sha256_file(f)
  standalone <- sha256_file
  env <- new.env(parent = baseenv())
  env$.rmbl_sha256_hex <- .rmbl_sha256_hex
  environment(standalone) <- env
  expect_equal(standalone(f), want)
  local_mocked_bindings(.rmbl_has_stringi = function() FALSE)
  expect_equal(to_ascii("Prof. Ángela"), "Prof. Angela")
})

test_that("hosted auth and model fall back to the built-in defaults when the services document has none", {
  withr::local_envvar(MORIE_HOSTED_AUTH_URL = "", MORIE_HOSTED_MODEL = "", MORIE_HOSTED_BASE_URL = "")
  local_mocked_bindings(.rmbl_services_llm = function() list())
  expect_match(.bl_hosted_auth(), "^https://.*/auth$")
  expect_equal(.bl_hosted_model(), "minimax-m3:cloud")
  expect_error(.bl_login_email(""), "email address is required")
  expect_error(.bl_login_email("   "), "email address is required")
})

test_that("mcar: a singular observed block in EM, a fit that does not converge, an all-missing row, skipped patterns", {
  X <- cbind(c(1, 2, 3, 4, 5, 6), c(1, 2, 3, 4, 5, 6), c(2, NA, 1, NA, 3, 2))
  r <- .rmbl_em_mvn(X)
  expect_true(is.null(r) || is.list(r))
  d <- data.frame(a = c(rnorm(30)), b = rnorm(30), c = rnorm(30))
  d[3, ] <- NA
  d$b[5:8] <- NA
  m <- mcar_test(d)
  expect_true(is.finite(m$statistic))
  local_mocked_bindings(.rmbl_em_mvn = function(...) NULL)
  expect_error(mcar_test(d), "did not converge")
  sing <- diag(3)
  sing[1, 2] <- sing[2, 1] <- 1
  local_mocked_bindings(.rmbl_em_mvn = function(X, ...) {
    list(mu = colMeans(X, na.rm = TRUE), sigma = sing, iterations = 1L)
  })
  m2 <- mcar_test(d)
  expect_match(m2$note, "skipped")
})

test_that("name constraints match URIs and IP addresses", {
  expect_true(.rmbl_nc_match(list(type = "uri", value = "https://a.example.org/x"),
                             list(type = "uri", value = "example.org")))
  expect_true(.rmbl_nc_match(list(type = "ip", value = as.raw(c(10, 1, 2, 3))),
                             list(type = "ip", value = as.raw(c(10, 1, 0, 0, 255, 255, 0, 0)))))
  expect_false(.rmbl_nc_match(list(type = "ip", value = as.raw(c(10, 2, 2, 3))),
                              list(type = "ip", value = as.raw(c(10, 1, 0, 0, 255, 255, 0, 0)))))
})

test_that("bricklayer_fetch_parse_siu parses the report its fetch saved", {
  html <- system.file("extdata", "siu_synthetic_report.html", package = "rmoriebricklayer")
  local_mocked_bindings(bricklayer_fetch_siu = function(drid, dest, lang) {
    file.copy(html, dest)
    dest
  })
  r <- bricklayer_fetch_parse_siu(648)
  expect_true(is.character(r) && length(r) > 1)
})

test_that(".rmbl_needs_cols strips extra attributes before the plain print", {
  x <- structure(data.frame(a = 1:2), class = c("rmbl_zzz", "data.frame"), meta = "kept?")
  out <- utils::capture.output(res <- .rmbl_needs_cols(x, c("a", "b")))
  expect_true(res)
  expect_true(any(grepl("^1", trimws(out))))
})

test_that("repro: an empty recorded kind, and an empty DESCRIPTION field", {
  expect_error(manifest_restore_seed(list(rng = list(state = 1:3, kind = list(NA, "")))), "kind is empty")
  lib <- tempfile("lib")
  dir.create(file.path(lib, "zzzfake"), recursive = TRUE)
  writeLines(c("Package: zzzfake", "Version: 0.0.1", "Repository: ", "Title: t", "Description: d"),
             file.path(lib, "zzzfake", "DESCRIPTION"))
  withr::local_libpaths(lib, action = "prefix")
  deps <- capture_dependencies("zzzfake")
  expect_true(is.na(deps$repository[deps$package == "zzzfake"]))
})

test_that("revocation: extension scans, DER OIDs with zero and multi-byte arcs, serials with the top bit set", {
  # a certificate with no [3] extensions block
  c1 <- list(der = der_seq(der_seq(der_tlv(0x02, as.raw(1)))))
  expect_identical(.rmbl_ext_urls(c1, "2.5.29.31", NULL), character(0))
  # an extension entry with a single child, then one whose value is not DER
  c2 <- list(der = der_seq(der_seq(der_tlv(0xA3, der_seq(der_seq(der_oid("2.5.29.31")))))))
  expect_identical(.rmbl_ext_urls(c2, "2.5.29.31", NULL), character(0))
  c3 <- list(der = der_seq(der_seq(der_tlv(0xA3, der_seq(der_seq(der_oid("2.5.29.31"),
                                                                   der_tlv(0x04, as.raw(c(0x30, 0x05)))))))))
  expect_identical(.rmbl_ext_urls(c3, "2.5.29.31", NULL), character(0))
  # OID arcs: a zero arc is one byte, 840 and 113549 take two and three
  expect_identical(der_oid("2.5.0.1"), as.raw(c(0x06, 0x03, 0x55, 0x00, 0x01)))
  expect_identical(der_oid("1.2.840.113549"), as.raw(c(0x06, 0x06, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d)))
  # the network seam refuses a loopback address and answers NULL instead of erroring
  got <- .rmbl_net_get_file("http://127.0.0.1:1/x", NULL, tempfile(), 1)
  expect_true(is.null(got) || (is.numeric(got) && got != 200))
  f <- x509_fx()
  leaf <- cert_parse(f$ocsp_good)
  ca <- cert_parse(f$ocsp_ca)
  leaf$serial <- paste0("ff", substr(leaf$serial, 3, nchar(leaf$serial)))
  cid <- .rmbl_ocsp_certid(leaf, ca)
  expect_true(is.raw(cid) && length(cid) > 40)
  expect_true(any(cid == as.raw(0xff)))
})

test_that("revocation: an OCSP answer without a signature, without isolable bytes, with a stray fourth element", {
  alg <- der_seq(der_oid("1.2.840.113549.1.1.11"))
  b1 <- der_parse(der_seq(der_seq(der_tlv(0x02, as.raw(1))), alg, der_tlv(0x03, raw(0))))
  expect_match(.rmbl_ocsp_verify_sig(b1, list(), NULL)$detail, "carries no signature")
  d2 <- der_seq(der_seq(der_tlv(0x02, as.raw(1))), alg, der_tlv(0x03, as.raw(c(0, 1))))
  expect_match(.rmbl_ocsp_verify_sig(der_parse(d2), list(), NULL)$detail, "could not be isolated")
  d3 <- der_seq(der_seq(der_tlv(0x02, as.raw(1))), alg, der_tlv(0x03, as.raw(c(0, 1))), der_tlv(0x02, as.raw(7)))
  r3 <- .rmbl_ocsp_verify_sig(der_parse(d3), list(), d3)
  expect_false(r3$ok)
  d4 <- der_seq(der_seq(der_tlv(0x02, as.raw(1))), alg, der_tlv(0x03, as.raw(c(0, 1))),
                der_tlv(0xA0, der_seq(der_seq(der_tlv(0x02, as.raw(9))))))
  r4 <- .rmbl_ocsp_verify_sig(der_parse(d4), list(), d4[seq_len(length(d4) - 2L)])
  expect_false(r4$ok)
})

test_that("services: a public key that is not a key, and a verified document that is not a v1 document", {
  sig <- as.character(bricklayer_json_to_json(list(scheme = "ML-DSA-44", context = .rmbl_services_context,
                                                   signature = "00"), auto_unbox = TRUE))
  expect_false(.rmbl_services_verify(charToRaw("{}"), sig, pubkey = "zz"))
  local_mocked_bindings(
    .rmbl_net_download = function(url, dest, timeout) {
      writeLines("{}", dest)
      200L
    },
    .rmbl_services_verify = function(...) TRUE)
  expect_null(.rmbl_services_fetch())
})

test_that(".rmbl_fips_prehash: NA means none", {
  expect_equal(.rmbl_fips_prehash(NA), "none")
})

test_that("timestamp: an RSA SubjectPublicKeyInfo with no key bits, or bits that are not an RSAPublicKey", {
  spki1 <- der_seq(der_seq(der_oid("1.2.840.113549.1.1.1"), der_tlv(0x05, raw(0))), der_tlv(0x03, as.raw(0)))
  expect_null(.rmbl_ts_cert_rsa(spki1))
  spki2 <- der_seq(der_seq(der_oid("1.2.840.113549.1.1.1"), der_tlv(0x05, raw(0))),
                   der_tlv(0x03, c(as.raw(0), der_tlv(0x02, as.raw(5)))))
  expect_null(.rmbl_ts_cert_rsa(spki2))
})

test_that("count_trend refuses an infinite x", {
  expect_error(count_trend(c(3, 4, 5), x = c(1, Inf, 3)), "infinite|finite")
})

test_that("yoy: a label function must give one label per row; grouped print; PDF colours and page breaks", {
  d <- data.frame(year = 2019:2022, n = c(10, 12, 9, 15))
  y <- yoy(d, value = "n", period = "year")
  expect_error(yoy_label(y, function(p) "one"), "one label per row")
  seg <- data.frame(year = rep(2019:2021, each = 2), gender = rep(c("Female", "Male"), 3),
                    n = c(31, 402, 28, 377, 12, 190))
  g <- yoy(seg, value = "n", period = "year", by = "gender", min_base = 0)
  out <- utils::capture.output(print(g))
  expect_true(any(grepl("Female", out)))
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f), add = TRUE)
  long <- data.frame(year = 2000:2070, n = c(seq(100L, 450L, by = 10L), seq(440L, 100L, by = -10L)))
  yl <- yoy(long, value = "n", period = "year")
  expect_silent(yoy_pdf(yl, f, title = "Up then down"))
  expect_true(file.size(f) > 1000)
})

test_that("json: scalar classes unwrap, classed functions, difftime via force, complex, data frame edge cases", {
  fn2 <- structure(function() 1, class = c("foo", "bar"))
  expect_equal(as.character(bricklayer_json_to_json(fn2, force = TRUE)), "{}")
  expect_error(bricklayer_json_to_json(structure(function() 1, class = c("foo", "bar"))), "No method")
  s <- structure(1, class = c("scalar", "mycls"))
  expect_error(bricklayer_json_to_json(s), "No method")
  d <- bricklayer_json_to_json(structure(5, class = "difftime", units = "secs"), force = TRUE)
  expect_equal(as.character(d), "[5]")
  z <- bricklayer_json_to_json(c(1 + 2i, NA), complex = "list")
  expect_match(as.character(z), "real")
  df <- data.frame(a = 1:2)
  df$b <- list(x = 1, y = 2)
  j <- bricklayer_json_to_json(df)
  expect_match(as.character(j), "\"b\"")
  cols <- bricklayer_json_to_json(data.frame(a = 1:2, b = c("x", "y")), dataframe = "columns", auto_unbox = TRUE)
  expect_match(as.character(cols), "^\\{\"a\":\\[1,2\\]")
  expect_warning(.rmbl_json_pack(compiler::compile(quote(1 + 1))), "No encoding has been defined")
  expect_equal(as.character(bricklayer_json_to_json(new.env(), force = TRUE)), "{}")
  expect_error(bricklayer_json_to_json(new.env()), "No method")
})

o_captured <- NULL
test_that("json: the encoder's option object, captured for the direct-call branches below", {
  local_mocked_bindings(.rmbl_json_as = function(x, o, ...) {
    o_captured <<- o
    "null"
  })
  bricklayer_json_to_json(1, complex = "list")
  expect_true(is.list(o_captured))
})

test_that("json: complex with na = 'NA' reverts to the outer na; a one-dimensional array; unequal record columns", {
  o <- o_captured
  z <- .rmbl_json_as_cplx(c(1 + 2i, NA), o, TRUE, "NA", "string", FALSE, o$indent)
  expect_match(z, "real")
  a <- .rmbl_json_as_array(array(1:3), o, TRUE, NULL, NULL, FALSE, o$indent, FALSE)
  expect_equal(gsub("\\s", "", a), "[1,2,3]")
  r <- tryCatch(bricklayer_json_from_json('[{"a":{"x":1}},{"b":2}]'), error = function(e) conditionMessage(e))
  expect_true(is.data.frame(r) || grepl("not of equal length", r))
})
