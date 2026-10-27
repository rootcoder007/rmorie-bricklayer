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
