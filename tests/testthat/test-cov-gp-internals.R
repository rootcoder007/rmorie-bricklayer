# SPDX-License-Identifier: AGPL-3.0-or-later
# Fallbacks and refusals of internal helpers no other test reached: a cache
# off outside an interactive session, a locale with no known country, readers
# that fail, certificates without a version field, and the like.

test_that("no download cache is kept outside an interactive session", {
  skip_if(interactive())
  expect_false(.bl_default_cache())
})

test_that("a locale whose country is unknown gives no location", {
  expect_null(.rmbl_loc_from_locale("en_ZZ", function(k) NA_character_))
  expect_identical(
    .rmbl_loc_from_locale("en_CA", function(k) "CA-ON"),
    list(location = "CA-ON", method = "locale en_CA")
  )
})

test_that("an unreadable meminfo gives no memory size off macOS", {
  d <- tempfile()
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE))
  expect_identical(
    suppressWarnings(.rmbl_total_memory_gb(meminfo = d, sysname = "Linux")),
    NA_real_
  )
})

test_that("cores given to the footprint are taken as given", {
  expect_identical(.fp_cores(4L, NULL), 4L)
})

test_that("the INAR start of a single event uses the mean gap", {
  b <- .rmbl_hk_bounds("exponential", "constant")
  th <- .rmbl_hk_inar(5, 10, "exponential", "constant", b)
  expect_length(th, 3L)
  expect_true(all(is.finite(th)))
  expect_true(all(th >= b$lower & th <= b$upper))
})

test_that("a Hawkes fit from a start where the likelihood is not finite", {
  # exp(15) events a day over 10^5 days: a compensator past 10^11, where the
  # core reports no likelihood; the line search finds no finite point
  far <- seq(1, 1e5, length.out = 100L)
  expect_error(
    chwkfit(far, 1e5 + 1, start = c(15, 0.5, 1)),
    "the likelihood is not finite at `start`"
  )
})

test_that("blfetch's error for an answered request and a failed Wayback", {
  expect_error(
    .bl_fetch_fail(-4040L, "https://x.org/f", "d"),
    paste0(
      "blfetch: https://x.org/f answered HTTP 404; the Wayback fallback ",
      "failed (the Wayback Machine has no snapshot of it, or did not answer)"
    ),
    fixed = TRUE
  )
})

test_that("a WARC that cannot be read is noted as failed, not thrown", {
  got <- new.env()
  note <- function(w, m) got$m <- c(got$m, paste(w, m))
  local_mocked_bindings(.bl_warc_get = function(...) stop("bad warc"))
  r <- .fv_try_archive(
    "/nonexistent-gp/a.warc.gz",
    "https://x.org/",
    tempfile(),
    tempfile(),
    NULL,
    5,
    note,
    new.env()
  )
  expect_null(r)
  expect_identical(got$m, "/nonexistent-gp/a.warc.gz failed: bad warc")
})

test_that("sctidy() loads a key that is not a table number as given", {
  got <- new.env()
  local_mocked_bindings(dload = function(key) {
    got$key <- key
    data.frame()
  })
  expect_error(
    sctidy("statcan_indigenous/other"),
    "it is not a Statistics Canada table"
  )
  expect_identical(got$key, "statcan_indigenous/other")
})

test_that("a Wayback availability lookup that fails gives no snapshot", {
  local_mocked_bindings(.rmbl_read_json = function(...) stop("offline"))
  expect_null(wbsnpurl("https://x.org/"))
})

test_that("the resolved URL check refuses a private literal", {
  expect_identical(
    .bl_wb_resolved_why("http://127.0.0.1/"),
    "a local or private address (127.0.0.1)"
  )
  expect_identical(
    .bl_wb_resolved_why("https://10.0.0.1/"),
    "a local or private address (10.0.0.1)"
  )
})

test_that("no CRL at all lists nothing revoked", {
  r <- .rmbl_crl_check("p", list(), Sys.time())
  expect_identical(r$check, "revocation")
  expect_true(r$ok)
  expect_identical(r$detail, "the CRLs supplied list nothing revoked")
})

test_that("a name value that is not text is written empty", {
  nd <- list(
    children = list(list(
      children = list(list(
        children = list(
          list(value = as.raw(c(0x55, 0x04, 0x03))),
          list(value = as.raw(c(0x41, 0x00, 0x42)))
        )
      ))
    ))
  )
  expect_identical(.rmbl_x509_name(nd), "CN=")
})

test_that("a timestamp token with no certificates, or an empty set, has none", {
  expect_null(.rmbl_ts_cert_der(
    list(children = list(list(class = 0L, tag = 16, constructed = TRUE))),
    NULL
  ))
  expect_null(.rmbl_ts_cert_der(
    list(
      children = list(list(
        class = 2L,
        tag = 0,
        constructed = TRUE,
        children = list()
      ))
    ),
    NULL
  ))
})

test_that("an OCSP key that cannot verify says FALSE", {
  expect_false(.rmbl_ocsp_key_verifies(
    list(type = "EC", x = NULL),
    raw(4),
    "sha256",
    raw(4)
  ))
  expect_false(.rmbl_ocsp_key_verifies(
    list(type = "DSA"),
    raw(4),
    "sha256",
    raw(4)
  ))
  # a signature that is not a DER pair of integers
  expect_false(.rmbl_ocsp_key_verifies(
    list(type = "EC", x = as.raw(1:32), y = as.raw(1:32), curve = "P-256"),
    as.raw(1:4),
    "sha256",
    raw(4)
  ))
})

test_that("an OCSP answer whose response bytes are not DER", {
  d <- .Call(
    C_rmbl_der_parse,
    .rmbl_der_seq(.rmbl_der_tlv(0x04, as.raw(rep(0xff, 12))))
  )
  expect_identical(.rmbl_ocsp_basic(d), "no BasicOCSPResponse in the answer")
})

test_that("the OCSP CertID of a version 1 certificate (no [0] version)", {
  name <- .rmbl_der_seq(.rmbl_der_tlv(
    0x31,
    .rmbl_der_seq(
      .rmbl_der_oid_bytes("2.5.4.3"),
      .rmbl_der_tlv(0x0c, charToRaw("CA"))
    )
  ))
  key <- as.raw(c(4, 1, 2, 3, 4))
  spki <- .rmbl_der_seq(
    .rmbl_der_seq(.rmbl_der_oid_bytes("1.2.840.10045.2.1")),
    .rmbl_der_tlv(0x03, c(as.raw(0), key))
  )
  alg <- .rmbl_der_seq(.rmbl_der_oid_bytes("1.2.840.10045.4.3.2"))
  tbs <- .rmbl_der_seq(
    .rmbl_der_tlv(0x02, as.raw(5)),
    alg,
    name,
    .rmbl_der_seq(
      .rmbl_der_tlv(0x17, charToRaw("240101000000Z")),
      .rmbl_der_tlv(0x17, charToRaw("250101000000Z"))
    ),
    name,
    spki
  )
  der <- .rmbl_der_seq(tbs, alg, .rmbl_der_tlv(0x03, as.raw(c(0, 1))))
  cert <- list(der = der, serial = "05")
  want <- .rmbl_der_seq(
    .rmbl_der_seq(
      .rmbl_der_oid_bytes("1.3.14.3.2.26"),
      .rmbl_der_tlv(0x05, raw(0))
    ),
    .rmbl_der_tlv(0x04, .Call(C_rmbl_sha1, name)),
    .rmbl_der_tlv(0x04, .Call(C_rmbl_sha1, key)),
    .rmbl_der_tlv(0x02, as.raw(5))
  )
  expect_identical(.rmbl_ocsp_certid(cert, cert), want)
})

test_that("an XMSS legacy record that cannot be read stops the signature", {
  skip_on_os("windows")
  skip_if(
    identical(Sys.info()[["effective_user"]], "root"),
    "root reads anything"
  )
  d <- tempfile()
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE, force = TRUE))
  j <- file.path(d, "xmss_index.json")
  writeLines("{\"a\": 1}", j)
  Sys.chmod(j, "000")
  on.exit(Sys.chmod(j, "644"), add = TRUE, after = FALSE)
  expect_error(
    suppressWarnings(.rmbl_xmss_legacy_json(file.path(d, "xmss_used.tsv"))),
    "cannot be read: no XMSS signature is made",
    fixed = TRUE
  )
})

test_that("an empty XMSS record is written as an empty file", {
  d <- tempfile()
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE))
  p <- file.path(d, "xmss_used.tsv")
  .rmbl_xmss_record_write(p, integer(0))
  expect_true(file.exists(p))
  expect_identical(file.size(p), 0)
  expect_identical(.rmbl_xmss_record_read(p), integer(0))
})

test_that("a CSV the streamed reader cannot count is refused in words", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f))
  writeLines(c("a,b", "1,2"), f)
  local_mocked_bindings(
    count.fields = function(...) stop("boom"),
    .package = "utils"
  )
  expect_error(
    .bl_read_csv_streamed(f),
    "the CSV cannot be read: boom",
    fixed = TRUE
  )
})

test_that("a gzip file past 2 GB is not held in memory", {
  skip_on_os("windows")
  s <- tempfile()
  on.exit(unlink(s))
  con <- file(s, "wb")
  ok <- tryCatch(
    {
      seek(con, 2^31 + 10, rw = "write")
      writeBin(as.raw(1), con)
      TRUE
    },
    error = function(e) FALSE,
    finally = close(con)
  )
  skip_if(!ok || !isTRUE(file.size(s) > 2^31), "no sparse file here")
  expect_null(.bl_gunzip_held(s, 1e6))
})

test_that("the SIU schema lists its fields", {
  x <- siusch()
  expect_named(x, c("name", "count", "description"))
  expect_identical(x$name[[1L]], "police_service")
  expect_identical(
    x$description[[1L]],
    "the police service(s) whose officials the SIU investigated"
  )
})

test_that("a French SIU report without the officials section", {
  txt <- paste0(
    "L'UES a mené l'enquête. L'UES a interrogé l'agent ",
    "impliqué no 1 et deux agents témoins."
  )
  r <- siuso(txt)
  expect_identical(r$count, 1L)
  expect_match(r$reason, "AI no 1", fixed = TRUE)
})

test_that("text that cannot be written in UTF-8 is written as ASCII", {
  f <- tempfile(fileext = ".txt")
  on.exit(unlink(f))
  calls <- new.env()
  calls$n <- 0L
  # the first conversion fails, as an encoding error would; the retry works
  registerS3method(
    "as.character",
    "gp_flaky_text",
    function(x, ...) {
      calls$n <- calls$n + 1L
      if (calls$n == 1L) {
        stop("cannot convert")
      }
      "café"
    },
    envir = environment()
  )
  wrtxtfb(structure(list("x"), class = "gp_flaky_text"), f)
  expect_identical(readLines(f), "cafe")
  expect_identical(calls$n, 2L)
})

test_that("projected BFGS with no gradient tolerance stops by decrease", {
  set.seed(2)
  times <- sort(stats::runif(200, 0, 50))
  hor <- 50
  b <- .rmbl_hk_bounds("exponential", "constant")
  soe <- .rmbl_hk_soe(times, hor, "exponential")
  run <- function(gtol) {
    .Call(
      C_rmbl_hawkes_fit_pbfgs,
      times,
      hor,
      .rmbl_hk_bkind[["constant"]],
      .rmbl_hk_kind[["exponential"]],
      0L,
      1e-12,
      soe[[1]],
      soe[[2]],
      b$lower,
      b$upper,
      c(log(3), 0.2, 2),
      2000L,
      gtol
    )
  }
  usual <- run(1e-6)
  # gtol = 0 is never met: the fit stops when the likelihood no longer
  # decreases, well before the iteration cap, at the same optimum
  exact <- run(0)
  expect_length(exact, 5L)
  expect_lte(exact[[4L]], usual[[4L]] + 1e-9)
  expect_lt(exact[[5L]], 2000)
  expect_equal(exact[1:3], usual[1:3], tolerance = 1e-3)
})

test_that("an interactive session keeps the download cache", {
  local_mocked_bindings(.bl_interactive = function() TRUE)
  expect_identical(
    .bl_default_cache(),
    tools::R_user_dir("rmoriebricklayer", "cache")
  )
  local_mocked_bindings(.bl_interactive = function() FALSE)
  expect_false(.bl_default_cache())
})

test_that("projected BFGS restarts on a flat direction and a failed search", {
  set.seed(2)
  times <- sort(stats::runif(200, 0, 50))
  b <- .rmbl_hk_bounds("exponential", "constant")
  soe <- .rmbl_hk_soe(times, 50, "exponential")
  run <- function(x0, lo, hi) {
    .Call(
      C_rmbl_hawkes_fit_pbfgs,
      times,
      50,
      .rmbl_hk_bkind[["constant"]],
      .rmbl_hk_kind[["exponential"]],
      0L,
      1e-12,
      soe[[1]],
      soe[[2]],
      lo,
      hi,
      x0,
      2000L,
      0
    )
  }
  x0 <- c(log(3), 0.2, 2)
  # a box pinned at the start: every variable is held at its bound, so the
  # direction is zero, not a descent; the fit restarts from steepest descent
  # (zero too), and with gtol = 0 never met it stops after one more pass
  pin <- run(x0, x0, x0)
  expect_identical(pin[1:3], x0)
  expect_true(is.finite(pin[[4L]]))
  expect_identical(pin[[5L]], 2)
  # a start that is not a number: the likelihood is the sentinel, the Armijo
  # test reads NaN for every step, the search fails, restarts once and stops
  bad <- run(c(NaN, 0.2, 2), b$lower, b$upper)
  expect_true(is.nan(bad[[1L]]))
  expect_identical(bad[[4L]], 1e12)
  expect_identical(bad[[5L]], 2)
})

test_that("the native spinner gives a wait of a minute in minutes", {
  wl <- function(...) invisible(.Call(C_rmbl_wait_label, ...))
  tick <- function() invisible(.Call(C_rmbl_check_interrupt))
  withr::defer(wl("", FALSE, FALSE))
  # a fifth element starts the clock 65 seconds back, where nothing redraws
  out <- capture.output(type = "message", {
    wl("hashing", FALSE, c(1, 0, 0, 1, 65))
    tick()
    wl("", FALSE, c(1, 0, 0, 1))
  })
  expect_identical(out, c("  hashing (1m05s)", "  hashing: done (1m05s)"))
})

test_that("a Ctrl-C stops a long key derivation as R's interrupt", {
  skip_on_cran()
  skip_on_os("windows")
  skip_if(
    !nzchar(Sys.which("python3")) || !nzchar(Sys.which("timeout")),
    "no python3/timeout"
  )
  # 2^26 PBKDF2 iterations are a minute of work unless the poll (every 4,096
  # iterations) sees the signal: the key is zeroed, the kernel stops and the
  # barrier raises the interrupt (src/rmbl_kdf.cpp)
  got <- interrupt_probe("drvkey('pass', 'salt', iter = 67108864L)")
  skip_if(startsWith(got, "inconclusive"), got)
  expect_identical(got, "interrupt")
})

test_that("a streamed table of a header alone has no rows", {
  f <- tempfile(fileext = ".csv.gz")
  on.exit(unlink(f))
  con <- gzfile(f, "w")
  writeLines("a,b", con)
  close(con)
  x <- .bl_read_csv_streamed(f)
  expect_identical(dim(x), c(0L, 2L))
  expect_named(x, c("a", "b"))
})
