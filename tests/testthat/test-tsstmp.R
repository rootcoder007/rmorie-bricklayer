# tsstmp(): a public RFC 3161 timestamp for a commitment, checked offline
# against a time-stamping authority that OpenSSL plays locally

local_tsa <- function(env = parent.frame()) {
  o <- Sys.which("openssl")
  testthat::skip_if(!nzchar(o), "openssl is not installed")
  d <- withr::local_tempdir(.local_envir = env)
  cfg <- file.path(d, "tsa.cnf")
  writeLines(c(
    "[ req ]", "distinguished_name = dn", "prompt = no",
    "[ dn ]", "CN = Test TSA",
    "[ ca ]", "basicConstraints = critical,CA:true",
    "keyUsage = critical,keyCertSign,cRLSign",
    "[ ext ]", "basicConstraints = critical,CA:false",
    "keyUsage = critical,digitalSignature",
    "extendedKeyUsage = critical,timeStamping",
    "[ tsa ]", "default_tsa = tsa1",
    "[ tsa1 ]", paste0("serial = ", file.path(d, "serial")),
    "default_policy = 1.2.3.4.1", "digests = sha256",
    "signer_digest = sha256",
    "accuracy = secs:1", "ordering = no", "tsa_name = no",
    "ess_cert_id_chain = no", "ess_cert_id_alg = sha256"
  ), cfg)
  writeLines("01", file.path(d, "serial"))
  # a root that issues the time-stamping certificate, as a real
  # authority's does
  cak <- file.path(d, "ca.key")
  cac <- file.path(d, "ca.crt")
  key <- file.path(d, "tsa.key")
  csr <- file.path(d, "tsa.csr")
  crt <- file.path(d, "tsa.crt")
  run <- function(...) {
    system2(o, c(...), stdout = FALSE, stderr = FALSE)
  }
  st <- c(
    run("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", cak,
        "-out", cac, "-days", "2", "-config", cfg, "-extensions", "ca",
        "-subj", "/CN=Test-TSA-Root"),
    run("req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", key,
        "-out", csr, "-config", cfg),
    run("x509", "-req", "-in", csr, "-CA", cac, "-CAkey", cak,
        "-CAcreateserial", "-out", crt, "-days", "2",
        "-extfile", cfg, "-extensions", "ext")
  )
  testthat::skip_if(any(st != 0L), "openssl could not make test certificates")
  list(
    crt = crt,
    ca = cac,
    post = function(url, body, timeout) {
      q <- tempfile(tmpdir = d)
      r <- tempfile(tmpdir = d)
      writeBin(body, q)
      st <- system2(o, c("ts", "-reply", "-config", cfg, "-queryfile", q,
                         "-signer", crt, "-inkey", key, "-out", r),
                    stdout = FALSE, stderr = FALSE)
      if (st != 0L) {
        return(list(status = 500L, body = raw(), error = "tsa failed"))
      }
      list(status = 200L, body = readBin(r, "raw", file.size(r)),
           error = "")
    }
  )
}

test_that("a commitment is stamped and the token verifies offline", {
  skip_on_cran()
  tsa <- local_tsa()
  local_mocked_bindings(.bl_tsa_post = tsa$post)
  a <- ralloc(20, seed = "teaching example")
  f <- file.path(withr::local_tempdir(), "alloc.tsr")
  ts <- tsstmp(a, tsa = "https://tsa.example/tsr", file = f)
  expect_s3_class(ts, "bricklayer_timestamp")
  imp <- ts$checks$ok[ts$checks$check == "message_imprint"]
  expect_true(isTRUE(imp))
  expect_lt(abs(as.numeric(difftime(ts$time, Sys.time(), units = "mins"))),
            5)
  expect_identical(ts$file, f)
  expect_identical(ts$tsa, "https://tsa.example/tsr")
  expect_identical(readBin(f, "raw", file.size(f)), ts$token)
  # years later: the saved token against the commitment and the
  # authority's certificate
  commit <- charToRaw(attr(a, "alloc")$digest)
  later <- tsvrf(f, commit, cert = tsa$crt)
  expect_true(isTRUE(later$checks$ok[later$checks$check == "signature"]))
  expect_true(isTRUE(
    later$checks$ok[later$checks$check == "message_imprint"]
  ))
  # with the authority's certificate as the trust anchor, all checks pass
  anchored <- tsstmp(a, tsa = "https://tsa.example/tsr", trust = tsa$ca)
  expect_true(isTRUE(anchored$ok))
  # a different commitment does not match the token
  other <- tsvrf(f, charToRaw("another list"), cert = tsa$crt)
  expect_false(isTRUE(
    other$checks$ok[other$checks$check == "message_imprint"]
  ))
  expect_false(other$ok)
})

test_that("files and raw bytes are stamped the same way", {
  skip_on_cran()
  tsa <- local_tsa()
  local_mocked_bindings(.bl_tsa_post = tsa$post)
  p <- file.path(withr::local_tempdir(), "outcomes.txt")
  writeLines("primary: survival", p)
  ts <- tsstmp(p, tsa = "https://tsa.example/tsr")
  expect_true(is.na(ts$file))
  expect_true(isTRUE(ts$checks$ok[ts$checks$check == "message_imprint"]))
  rb <- tsstmp(readBin(p, "raw", file.size(p)), tsa = "http://tsa.example")
  expect_identical(tsinfo(rb$token)$imprint, tsinfo(ts$token)$imprint)
})

test_that("an authority that does not answer is an error", {
  local_mocked_bindings(.bl_tsa_post = function(url, body, timeout) {
    list(status = 503L, body = raw(), error = "")
  })
  expect_error(tsstmp(charToRaw("x")), "HTTP 503")
  local_mocked_bindings(.bl_tsa_post = function(url, body, timeout) {
    list(status = 0L, body = raw(), error = "could not resolve host")
  })
  expect_error(tsstmp(charToRaw("x")), "could not resolve host")
})

test_that("tsstmp refuses what it cannot stamp", {
  expect_error(tsstmp(1:3), "data")
  expect_error(tsstmp(charToRaw("x"), tsa = "ftp://x"), "http")
  expect_error(tsstmp(charToRaw("x"), timeout = 0), "positive")
  f <- tempfile()
  writeLines("x", f)
  expect_error(tsstmp(charToRaw("x"), file = f), "not overwritten")
  bare <- structure(data.frame(id = 1), class = c("rmbl_alloc",
                                                  "data.frame"))
  expect_error(tsstmp(bare), "no commitment")
})

# A token from the local authority, for a request this test sends itself.
tsa_token <- function(tsa, bytes, nonce = c(as.raw(0x01), rndbytes(7L))) {
  q <- if (is.null(nonce)) {
    alg <- .bl_der(0x30, c(.rmbl_hex_to_raw("0609608648016503040201"),
                           as.raw(c(0x05, 0x00))))
    .bl_der(0x30, c(.bl_der(0x02, as.raw(1L)),
                    .bl_der(0x30, c(alg, .bl_der(0x04, .bl_hex_raw(
                      csha256(bytes)
                    ))))))
  } else {
    .bl_tsq(.bl_hex_raw(csha256(bytes)), nonce)
  }
  tsa$post("https://tsa.example/tsr", q, 10L)$body
}

ts_row <- function(r, check) r$checks[r$checks$check == check, ]

test_that("a token answering another request is refused by its nonce", {
  skip_on_cran()
  tsa <- local_tsa()
  n1 <- c(as.raw(0x01), rndbytes(7L))
  tok <- tsa_token(tsa, charToRaw("commitment"), n1)
  ok <- tsvrf(tok, charToRaw("commitment"), trust = tsa$ca, nonce = n1)
  expect_true(ok$ok)
  expect_true(ts_row(ok, "nonce")$ok)
  # a replayed token: the nonce sent this time is another one
  n2 <- c(as.raw(0x01), rndbytes(7L))
  bad <- tsvrf(tok, charToRaw("commitment"), trust = tsa$ca, nonce = n2)
  expect_false(bad$ok)
  expect_identical(ts_row(bad, "nonce")$detail,
                   "the token's nonce is another request's")
  # a token for a request that sent none
  bare <- tsa_token(tsa, charToRaw("commitment"), NULL)
  none <- tsvrf(bare, charToRaw("commitment"), trust = tsa$ca, nonce = n1)
  expect_false(none$ok)
  expect_match(ts_row(none, "nonce")$detail, "carries no nonce")
  # tsstmp() and the archive capture check the nonce they sent
  local_mocked_bindings(.bl_tsa_post = tsa$post)
  st <- tsstmp(charToRaw("commitment"), tsa = "https://tsa.example/tsr")
  expect_true(ts_row(st, "nonce")$ok)
  d <- withr::local_tempdir()
  writeLines("{}", file.path(d, "manifest.json"))
  cap <- .bl_cap_timestamp("https://tsa.example/tsr",
                           file.path(d, "manifest.json"), d)
  expect_true(ts_row(cap, "nonce")$ok)
  expect_error(tsvrf(tok, as.raw(1), nonce = "01"), "`nonce` must be")
})

test_that("a response the authority did not grant carries no timestamp", {
  skip_on_cran()
  tsa <- local_tsa()
  tok <- tsa_token(tsa, charToRaw("commitment"))
  d <- .Call(C_rmbl_der_parse, tok)
  ci <- tok[(d$children[[2]]$start + 1L):length(tok)]
  for (st in 2:5) {
    # rejection, waiting, revocationWarning, revocationNotification, with
    # and without a token after them
    for (body in list(raw(0), ci)) {
      resp <- .bl_der(0x30, c(.bl_der(0x30, .bl_der(0x02, as.raw(st))), body))
      r <- tsvrf(resp, charToRaw("commitment"), trust = tsa$ca)
      expect_false(r$ok)
      expect_identical(
        ts_row(r, "token_structure")$detail,
        sprintf("the authority did not grant the timestamp (PKIStatus %d)", st)
      )
    }
  }
  # granted: the response and the bare token both verify
  expect_true(tsvrf(tok, charToRaw("commitment"), trust = tsa$ca)$ok)
  expect_true(tsvrf(ci, charToRaw("commitment"), trust = tsa$ca)$ok)
})

test_that("a token wrapped in another structure or altered is refused", {
  skip_on_cran()
  tsa <- local_tsa()
  tok <- tsa_token(tsa, charToRaw("commitment"))
  d <- .Call(C_rmbl_der_parse, tok)
  ci <- tok[(d$children[[2]]$start + 1L):length(tok)]
  wraps <- list(
    .bl_der(0x30, c(.bl_der(0x02, as.raw(1L)),
                    .bl_der(0x0c, charToRaw("note")), ci)),
    .bl_der(0xa5, ci),
    .bl_der(0x30, c(.bl_der(0x30, .bl_der(0x02, as.raw(0L))), ci,
                    .bl_der(0x05, raw(0))))
  )
  for (w in wraps) {
    r <- tsvrf(w, charToRaw("commitment"), trust = tsa$ca)
    expect_false(r$ok)
    expect_false(ts_row(r, "token_structure")$ok)
  }
  # the digestAlgorithms sit outside the signed bytes: an altered OID tag,
  # or parameters that are not a NULL, are refused rather than ignored
  cd <- .Call(C_rmbl_der_parse, ci)
  alg <- cd$children[[2]]$children[[1]]$children[[2]]$children[[1]]
  oid_at <- alg$children[[1]]$start + 1L
  bad <- ci
  bad[oid_at] <- as.raw(0x04)
  r <- tsvrf(bad, charToRaw("commitment"), trust = tsa$ca)
  expect_identical(ts_row(r, "token_structure")$detail,
                   "the token's digest algorithm has no algorithm OID")
  if (length(alg$children) == 2L) {
    bad <- ci
    bad[alg$children[[2]]$start + 1L] <- as.raw(0x04)
    r <- tsvrf(bad, charToRaw("commitment"), trust = tsa$ca)
    expect_match(ts_row(r, "token_structure")$detail,
                 "parameters RFC 5754 does not allow")
  }
})

test_that("the SignerInfo must name the certificate it is checked under", {
  skip_on_cran()
  tsa <- local_tsa()
  tok <- tsa_token(tsa, charToRaw("commitment"))
  r <- tsvrf(tok, charToRaw("commitment"), cert = tsa$crt)
  expect_true(ts_row(r, "signer_id")$ok)
  other <- tsvrf(tok, charToRaw("commitment"), cert = tsa$ca)
  expect_false(other$ok)
  expect_identical(
    ts_row(other, "signer_id")$detail,
    "the SignerInfo names another certificate (issuer and serial)"
  )
})

test_that("signed attributes are read among themselves, not searched", {
  der <- function(tag, ...) .bl_der(tag, c(...))
  oid <- function(h) .rmbl_hex_to_raw(h)
  md_oid <- oid("06092a864886f70d010904")
  ct_oid <- oid("06092a864886f70d010903")
  md <- der(0x30, md_oid, der(0x31, der(0x04, as.raw(1:4))))
  # a messageDigest hidden in another attribute's value is not one
  nested <- der(0xa0, der(0x30, ct_oid, der(0x31, md)))
  sa <- .Call(C_rmbl_der_parse, nested)
  expect_null(.rmbl_ts_attr(sa, "1.2.840.113549.1.9.4"))
  # twice, or with two values, is no attribute either
  twice <- .Call(C_rmbl_der_parse, der(0xa0, md, md))
  expect_null(.rmbl_ts_attr(twice, "1.2.840.113549.1.9.4"))
  two <- der(0x30, md_oid,
             der(0x31, der(0x04, as.raw(1)), der(0x04, as.raw(2))))
  expect_null(.rmbl_ts_attr(.Call(C_rmbl_der_parse, der(0xa0, two)),
                            "1.2.840.113549.1.9.4"))
  one <- .rmbl_ts_attr(.Call(C_rmbl_der_parse, der(0xa0, md)),
                       "1.2.840.113549.1.9.4")
  expect_identical(one$value, as.raw(1:4))
})
