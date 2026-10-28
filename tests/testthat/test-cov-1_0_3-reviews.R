# Lines added by the fixes after the 1.0.3 reviews that no other test
# reached (codecov on update 68): each one is called here with the input
# that takes it.

# DER bytes from a tag and contents
der <- function(tag, ...) {
  body <- c(raw(0), ...)
  c(as.raw(tag), .rmbl_der_length(length(body)), body)
}
parse_der <- function(b) .Call(C_rmbl_der_parse, b)

test_that("a measure with no box prints, compares and assigns as a number", {
  m <- structure(2, rmbl_value = 2,
                 class = c("rmbl_other", "rmbl_measure", "numeric"))
  expect_output(print(m), "2")
  expect_true(all.equal(m, m))
  v <- .rmbl_measure_assign(m, 1L, value = 5)
  expect_false(inherits(v, "rmbl_measure"))
  expect_identical(v, 5)
  expect_true(.rmbl_measure_choose(m, Sys.Date(), NULL, NULL, NULL, FALSE))
})

test_that("each measure box without its record is the plain number", {
  boxes <- list(.rmbl_mbox_adp, .rmbl_mbox_alos, .rmbl_mbox_admits,
                .rmbl_mbox_adpcnts, .rmbl_mbox_perdays, .rmbl_mbox_drftks,
                .rmbl_mbox_drftpsi, .rmbl_mbox_drftchisq,
                .rmbl_mbox_drfthomog, .rmbl_mbox_gini, .rmbl_mbox_attrfrac)
  m <- structure(3.5, class = c("rmbl_adp", "rmbl_measure", "numeric"))
  for (f in boxes) {
    expect_identical(f(m), "3.5")
  }
})

test_that(".onLoad registers the Ops method for measures", {
  withr::local_options(rmbl.examples = TRUE)
  .onLoad("lib", "rmoriebricklayer")
  expect_true(getOption("rmbl.examples"))
  skip_if_not(exists("chooseOpsMethod", envir = baseenv()))
  expect_type(
    getS3method("chooseOpsMethod", "rmbl_measure", envir = baseenv()),
    "closure"
  )
})

test_that("a planted-effect check with a tiny tolerance says too noisy", {
  set.seed(11)
  d <- data.frame(x = stats::rbinom(80, 1, 0.5), z = stats::rnorm(80))
  d$y <- 2 * d$x + d$z + stats::rnorm(80)
  dm <- function(df) mean(df$y[df$x == 1]) - mean(df$y[df$x == 0])
  p <- cpsplant(d, dm, y = "y", trt = "x", n = 20, tol = 1e-9, seed = 3)
  expect_match(paste(format(p), collapse = "\n"), "Too noisy")
})

test_that("a bad timeout option falls back to the default", {
  withr::local_options(rmbl.fips.timeout = "soon")
  expect_identical(.rmbl_fipsmod_timeout(), 300L)
  withr::local_options(rmbl.fips.timeout = 0L)
  expect_identical(.rmbl_fipsmod_timeout(), 300L)
})

test_that("a FIPS configuration that is not a file is refused", {
  expect_error(.rmbl_fipsmod_given_conf(tempdir()), "`conf` is not a file")
})

test_that("a bundle run longer than its timeout is stopped and logged", {
  skip_on_cran()
  root <- withr::local_tempdir()
  writeLines("cat('ran\\n')", file.path(root, "setup_and_run.R"))
  withr::local_options(rmbl.bundle.timeout = "never")
  r <- .bndlchk_run(root, NULL, TRUE)
  expect_identical(r$status, 0L)
  expect_true(any(grepl("ran", r$log, fixed = TRUE)))
  writeLines("Sys.sleep(30)", file.path(root, "setup_and_run.R"))
  withr::local_options(rmbl.bundle.timeout = 1L)
  r <- .bndlchk_run(root, NULL, FALSE)
  expect_identical(r$status, 124L)
  expect_true(any(grepl("longer than 1 seconds", r$log, fixed = TRUE)))
})

test_that("plot periods follow prdord, the rest after it", {
  expect_identical(.bl_period_order(c("b", "a", "c"), prdord = c("c", "a")),
                   c("c", "a", "b"))
})

test_that("control characters are escaped one by one", {
  expect_identical(.rmbl_ctl_char(7L), "\\a")
  expect_identical(.rmbl_ctl_char(1L), "\\001")
  expect_identical(.rmbl_ctl_char(0x200e), "<U+200E>")
  bad <- "\xff\001"
  Encoding(bad) <- "bytes"
  expect_identical(.rmbl_ctl_escape1(bad), bad)
})

test_that("text too wide for a box is cut with an ellipsis", {
  expect_identical(.rmbl_box_fit("abcdefghij", 5L, FALSE), "ab...")
  expect_identical(.rmbl_box_fit("abcdefghij", 5L, TRUE), "abcd\u2026")
  expect_identical(.rmbl_box_fit("abc", 5L, TRUE), "abc")
})

test_that("OCSP: the clock, a CertID that is not one, dates that are not", {
  expect_s3_class(.rmbl_ocsp_now(), "POSIXct")
  expect_null(.rmbl_ocsp_cid_key(list(tag = 4, children = list())))
  nd <- list(children = list(
    list(), list(),
    list(class = 0L, tag = 23, value = charToRaw("260101000000Z"))
  ))
  expect_identical(.rmbl_ocsp_current(nd, Sys.time()),
                   "the answer's dates are not GeneralizedTime")
})

test_that("timestamp tokens with fields out of place are refused", {
  si <- list(constructed = TRUE, tag = 17, children = list(list(
    constructed = TRUE,
    children = list(list(tag = 2), list(), list(), list(), list())
  )))
  k <- list(list(), list(), list(), list(class = 0L, tag = 16), si)
  expect_error(.rmbl_ts_signer(k), "RFC 5652 does not define")
  expect_error(.rmbl_ts_want(NULL, 0L, 2, "version"),
               "version is not where RFC 3161 puts it")
  resp <- list(tag = 16, children = list(
    list(class = 0L, tag = 16, children = list())
  ))
  expect_error(.rmbl_ts_content_info(resp), "has no PKIStatus")
  expect_error(.rmbl_ts_content_info(list(tag = 4, children = list())),
               "no CMS SignedData")
  # the SignedData OID, then something other than its [0] content
  sd_oid <- as.raw(c(0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x07, 0x02))
  wrapped <- parse_der(der(0x30, der(0x06, sd_oid), der(0x04)))
  expect_error(.rmbl_ts_content_info(wrapped), "no CMS SignedData")
})

test_that("a SignerInfo short of fields or with extra ones is refused", {
  sha256 <- as.raw(c(0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01))
  alg <- parse_der(der(0x30, der(0x06, sha256)))
  ver <- list(class = 0L, tag = 2)
  short <- list(children = list(ver, list(), alg, list(class = 2L, tag = 0)))
  expect_error(.rmbl_ts_signer_algs(short), "SignerInfo is incomplete")
  extra <- list(children = list(ver, list(), alg, alg,
                                list(class = 0L, tag = 4),
                                list(class = 0L, tag = 16)))
  expect_error(.rmbl_ts_signer_algs(extra), "RFC 5652 does not define")
})

test_that("a SignerInfo naming its signer by key identifier is checked", {
  ski_ext <- der(0xa3, der(0x30, der(
    0x30, der(0x06, as.raw(c(0x55, 0x1d, 0x0e))),
    der(0x04, der(0x04, as.raw(c(0xab, 0xcd))))
  )))
  tbs <- function(...) {
    der(0x30, der(0x30, der(0xa0, der(0x02, as.raw(2))),
                  der(0x02, as.raw(5)), der(0x30), der(0x30), der(0x30),
                  der(0x30), der(0x30, der(0x30),
                                 der(0x03, as.raw(c(0, 1, 2, 3)))), ...))
  }
  with_ski <- tbs(ski_ext)
  signer <- function(sid) list(children = list(list(), sid))
  kid <- function(v) list(class = 2L, tag = 0, constructed = FALSE, value = v)
  expect_null(.rmbl_ts_sid_check(signer(kid(as.raw(c(0xab, 0xcd)))),
                                 with_ski, raw(0)))
  expect_error(.rmbl_ts_sid_check(signer(kid(as.raw(1))), with_ski, raw(0)),
               "another certificate \\(key identifier\\)")
  expect_error(.rmbl_ts_sid_check(signer(list(class = 1L, tag = 3)),
                                  with_ski, raw(0)),
               "a form RFC 5652 does not define")
  # no extension: the identifier is the SHA-1 of the key's bits
  tk <- parse_der(tbs())$children[[1L]]$children
  expect_identical(.rmbl_ts_cert_ski(tk, 2L),
                   .Call(C_rmbl_sha1, as.raw(c(1, 2, 3))))
})

test_that("a nonce of zero bytes matches zero bytes", {
  acc <- new.env()
  note <- function(check, ok, detail) {
    assign("got", list(check, ok), envir = acc)
  }
  .rmbl_ts_nonce_row(list(nonce = as.raw(c(0, 0))), as.raw(0), note)
  expect_identical(acc$got, list("nonce", TRUE))
})

test_that("a messageDigest without the TSTInfo content type fails", {
  md_oid <- as.raw(c(0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x09, 0x04))
  sa <- parse_der(der(0x31, der(
    0x30, der(0x06, md_oid), der(0x31, der(0x04, as.raw(1:4)))
  )))
  r <- .rmbl_ts_content(sa, list(children = list()), list())
  expect_false(r$ok)
  expect_identical(r$detail,
                   "the signed contentType attribute is not TSTInfo")
})

test_that("CRLs: none covering the path, a signature that errors, bad ones", {
  local_mocked_bindings(
    .rmbl_crl_cover = function(path, crls, at_time, add) {
      list(covered = list(NULL), listed = 1L)
    }
  )
  r <- .rmbl_crl_check(list(list(serial = "01")), list(raw(1)), Sys.time())
  expect_false(r$ok)
  expect_match(r$detail, "no CRL supplied covers")
  local_mocked_bindings(
    .rmbl_cert_verify_sig = function(cr, s) stop("unreadable")
  )
  expect_identical(
    .rmbl_crl_trusted(list(issuer = "CN=X"),
                      list(list(subject = "CN=X", is_ca = TRUE)),
                      Sys.time()),
    "its signature does not verify under the CA that issued it"
  )
  alg <- der(0x30, der(0x05))
  bits <- der(0x03, as.raw(0))
  no_time <- der(0x30, der(0x30, der(0x02, as.raw(1))), alg, bits)
  expect_null(.rmbl_crl_read(no_time))
  t <- der(0x17, charToRaw("260101000000Z"))
  empty_entry <- der(0x30, alg, der(0x30), t, der(0x30, der(0x30)))
  cr <- .rmbl_crl_read(der(0x30, empty_entry, alg, bits))
  expect_identical(cr$serials, "")
})

test_that("yoy() warns of rows with no period and keeps them", {
  d <- data.frame(p = c(2019, 2020, NA), n = c(5, 6, 7))
  expect_warning(out <- yoy(d, value = "n", prd = "p"),
                 "1 row\\(s\\) have no period")
  expect_identical(nrow(as.data.frame(out)), 3L)
})
