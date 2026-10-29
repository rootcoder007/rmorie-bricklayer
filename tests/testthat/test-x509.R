# battery: runs in CI and locally; CRAN runs the correctness core
testthat::skip_on_cran()
# Certificate path validation, ECDSA, and the positive controls.
#
# The timestamp fixtures carry two tokens over the same payload under
# the same CA -- one signed with RSA, one with ECDSA on P-256 -- so the
# two signature paths are exercised against real tokens rather than
# against each other.

ts_fixtures <- function() {
  fx <- readLines(test_path("timestamp-token.txt"), warn = FALSE)
  fx <- fx[!startsWith(fx, "#") & nzchar(fx)]
  parts <- strsplit(fx, "|", fixed = TRUE)
  stats::setNames(
    lapply(parts, function(p) .rmbl_hex_to_raw(p[2L])),
    vapply(parts, `[[`, character(1), 1L)
  )
}

test_that("ECDSA verifies on every curve, and rejects what it must", {
  # The curve arithmetic, against the published base-point multiples.
  # 2G and 3G on P-256 are the values in SEC 2 and every other table.
  g2 <- .Call(C_rmbl_ec_mul, "P-256", as.raw(2L))
  expect_identical(
    .rmbl_hexlify(g2$x),
    "7cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978"
  )
  g3 <- .Call(C_rmbl_ec_mul, "P-256", as.raw(3L))
  expect_identical(
    .rmbl_hexlify(g3$x),
    "5ecbe4d1a6330a44c8f7ef951d4bf165e6c6b721efada985fb41661bc6e7fd6c"
  )

  # The definitive check on each group order: n*G is the point at
  # infinity. The P-521 order was once four hex digits short here, which
  # left the curve arithmetic correct -- 2G still matched the published
  # value -- while every operation mod n was wrong and no signature
  # verified. This is the check that would have caught it immediately.
  for (cv in c("P-256", "P-384", "P-521")) {
    n <- .Call(C_rmbl_ec_order, cv)
    expect_true(.Call(C_rmbl_ec_mul, cv, n)$infinity, info = cv)
    expect_length(n, switch(cv, "P-256" = 32L, "P-384" = 48L, 66L))
  }
  expect_error(.Call(C_rmbl_ec_mul, "P-192", as.raw(1L)), "unsupported")
})

test_that("a certificate parses into the fields a verifier needs", {
  f <- ts_fixtures()
  cert <- certprs(f$rsa_cert)
  expect_s3_class(cert, "bricklayer_certificate")
  expect_match(cert$subject, "TSA")
  expect_match(cert$issuer, "CA")
  expect_identical(cert$key$type, "RSA")
  expect_identical(cert$key$bits, 2048L)
  expect_identical(cert$signature_algorithm, "RSA-SHA256")
  expect_false(cert$is_ca)
  # the leaf is issued for timestamping and nothing else
  expect_identical(cert$extended_key_usage, "1.3.6.1.5.5.7.3.8")
  expect_s3_class(cert$not_before, "POSIXct")
  expect_gt(cert$not_after, cert$not_before)
  expect_false(cert$self_signed)

  ec <- certprs(f$ecdsa_cert)
  expect_identical(ec$key$type, "EC")
  expect_identical(ec$key$curve, "P-256")

  ca <- certprs(f$ca)
  expect_true(ca$is_ca)
  expect_true(ca$self_signed)
  expect_output(print(cert), "X.509 certificate")
})

test_that("a chain verifies to an anchor, and fails every other way", {
  f <- ts_fixtures()
  leaf <- certprs(f$rsa_cert)
  ca <- certprs(f$ca)
  at <- leaf$not_before + 86400

  ok <- certchnvrf(leaf, trust = ca, attm = at, purp = "timeStamping")
  expect_true(ok$ok)
  expect_length(ok$path, 2L)
  expect_true(all(ok$checks$ok))

  # an anchor that did not issue it
  bad <- certchnvrf(leaf, trust = certprs(f$other_ca), attm = at)
  expect_false(bad$ok)
  expect_false(bad$checks$ok[bad$checks$check == "path_to_anchor"])

  # outside the validity window, in both directions
  expect_false(certchnvrf(leaf, trust = ca, attm = leaf$not_before - 86400)$ok)
  expect_false(certchnvrf(leaf, trust = ca, attm = leaf$not_after + 86400)$ok)

  # a purpose the leaf was not issued for
  expect_false(certchnvrf(leaf, trust = ca, attm = at, purp = "codeSigning")$ok)

  # the leaf is not a CA, so it cannot stand in as its own issuer
  self <- certchnvrf(leaf, trust = leaf, attm = at)
  expect_false(self$ok)

  # a CRL naming the leaf's serial revokes it
  expect_error(certchnvrf(leaf, trust = list()), "at least one")
  expect_output(print(ok), "Certificate chain")
})

test_that("a token is verified with its trust chain, RSA and ECDSA", {
  f <- ts_fixtures()
  for (nm in c("rsa_token", "ecdsa_token")) {
    tok <- f[[nm]]
    # without an anchor the signature still checks, but trust is
    # reported as not established rather than assumed
    bare <- tsvrf(tok, f$payload)
    expect_true(bare$checks$ok[bare$checks$check == "signature"], info = nm)
    expect_false(
      bare$checks$ok[bare$checks$check == "certificate_trust"],
      info = nm
    )
    expect_false(bare$ok, info = nm)

    full <- tsvrf(tok, f$payload, trust = f$ca)
    expect_true(full$ok, info = nm)
    expect_true(any(startsWith(full$checks$check, "chain:")), info = nm)
    # the chain's validity was judged at the time the token asserts
    expect_match(
      full$checks$detail[
        full$checks$check == "certificate_trust"
      ],
      format(full$time, "%Y-%m-%d", tz = "UTC"),
      info = nm
    )

    # an anchor that did not issue it
    expect_false(tsvrf(tok, f$payload, trust = f$other_ca)$ok, info = nm)
    # and a time the certificate did not cover
    expect_false(
      tsvrf(
        tok,
        f$payload,
        trust = f$ca,
        attm = as.POSIXct("1999-01-01", tz = "UTC")
      )$ok,
      info = nm
    )
  }
  # the ECDSA token really is ECDSA, so the two paths are distinct
  ec <- tsvrf(f$ecdsa_token, f$payload, trust = f$ca)
  expect_match(ec$checks$detail[ec$checks$check == "signature"], "ECDSA")
  rsa <- tsvrf(f$rsa_token, f$payload, trust = f$ca)
  expect_match(rsa$checks$detail[rsa$checks$check == "signature"], "RSA")
})

test_that("tampering is caught on both signature algorithms", {
  f <- ts_fixtures()
  for (nm in c("rsa_token", "ecdsa_token")) {
    tok <- f[[nm]]
    k <- length(tok) - 40L
    tok[k] <- as.raw(bitwXor(as.integer(tok[k]), 1L))
    r <- tsvrf(tok, f$payload, trust = f$ca)
    expect_false(r$ok, info = nm)
    expect_false(r$checks$ok[r$checks$check == "signature"], info = nm)
  }
})

test_that("SHA-384 matches its FIPS 180-4 vectors", {
  # needed because ecdsa-with-SHA384 is a certificate signature
  # algorithm in common use, and a verifier that cannot compute the
  # digest cannot check the signature
  expect_identical(
    .rmbl_hexlify(.Call(C_rmbl_sha384, charToRaw("abc"))),
    paste0(
      "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43",
      "ff5bed8086072ba1e7cc2358baeca134c825a7"
    )
  )
  expect_identical(
    .rmbl_hexlify(.Call(C_rmbl_sha384, raw(0))),
    paste0(
      "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63",
      "f6e1da274edebfe76f65fbd51ad2f14898b95b"
    )
  )
  # the padding boundary, where the length no longer fits the block
  got <- vapply(
    c(111L, 112L, 113L),
    function(n) {
      substring(
        .rmbl_hexlify(.Call(C_rmbl_sha384, charToRaw(strrep("a", n)))),
        1L,
        16L
      )
    },
    character(1)
  )
  expect_length(unique(got), 3L)
})

test_that("the positive control finds an injected effect, or says not", {
  set.seed(1)
  d <- data.frame(x = stats::rnorm(120), y = stats::rnorm(120))
  inj <- function(z, size) {
    z$y <- z$y + size * z$x
    z
  }
  pw <- cpspwr(
    d,
    function(z) stats::cor(z$x, z$y),
    inj,
    sizes = c(0, 0.1, 0.4),
    trt = "x",
    n = 99L,
    reps = 6L,
    seed = 42L
  )
  expect_s3_class(pw, "bricklayer_power")
  expect_identical(nrow(pw$curve), 3L)
  # a large effect is found every time, a tiny one is not, and the
  # smallest reliably detected is what a null result can speak to
  expect_identical(pw$curve$rate[pw$curve$size == 0.4], 1)
  expect_lt(pw$curve$rate[pw$curve$size == 0.1], 0.8)
  expect_identical(pw$smadet, 0.4)
  # the false-positive rate at size 0 must not be large
  expect_lt(pw$curve$rate[pw$curve$size == 0], 0.5)

  # A statistic blind to the effect detects nothing at any size. This is
  # the case that every falsification control passes and that matters
  # most: a null result from here is not evidence of absence.
  blind <- cpspwr(
    d,
    function(z) mean(z$x),
    inj,
    sizes = c(0, 0.8),
    trt = "x",
    n = 99L,
    reps = 4L,
    seed = 7L
  )
  expect_true(is.na(blind$smadet))
  expect_output(print(blind), "could not")

  # a design whose permutation floor is above alpha could never detect
  # anything, and is refused rather than run
  expect_error(
    cpspwr(
      d,
      function(z) stats::cor(z$x, z$y),
      inj,
      trt = "x",
      n = 9L,
      alpha = 0.05
    ),
    "no size could ever be detected"
  )
  expect_error(cpspwr(d, function(z) 1, inj), "`trt` is required")
  expect_error(
    cpspwr(d, function(z) 1, "notafunction", trt = "x"),
    "must both be functions"
  )
})

test_that("certchnvrf names purp and pols", {
  f <- function() 1
  expect_error(certchnvrf(NULL, NULL, purp = f), "certchnvrf: `purp` must be")
  expect_error(certchnvrf(NULL, NULL, pols = f), "certchnvrf: `pols` must be")
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

test_that("certificates and chain checks print as boxes", {
  f <- ts_fixtures()
  cert <- certprs(f$rsa_cert)
  o1_expect_box(
    o1_box(cert),
    cert,
    "X.509 certificate",
    c("Subject", "Valid to", "certchnvrf()")
  )
  ok <- certchnvrf(cert, trust = list(certprs(f$ca)))
  b <- o1_box(ok)
  o1_expect_box(b, ok, "Certificate chain:", c("Certificates", "Checked at"))
  expect_true(any(grepl("VERIFIED", b$out, fixed = TRUE)))
})

# ---- restored key usage and result-driven reading --------------------------

test_that("certprs()'s box shows both key usages and reads its validity", {
  f <- system.file("extdata", "x509", "test-root.der",
    package = "rmoriebricklayer")
  root <- certprs(f)
  txt <- gsub("\\s+", " ", paste(format(root), collapse = " "))
  expect_match(txt, "Key usage keyCertSign", fixed = TRUE)
  expect_match(txt, "Extended key usage none stated", fixed = TRUE)
  early <- .rmbl_cert_reading(root, root$not_before - 86400)
  mid <- .rmbl_cert_reading(root, root$not_before + 86400)
  late <- .rmbl_cert_reading(root, root$not_after + 2 * 86400)
  expect_match(early[1L], "^Not yet valid")
  expect_match(mid[1L], "^In force now")
  expect_match(late[1L], "^Expired on .*, 2 days ago")
  expect_match(mid[2L], "self-signed CA", fixed = TRUE)
  leaf <- certprs(system.file("extdata", "x509", "test-leaf.der",
    package = "rmoriebricklayer"))
  expect_match(.rmbl_cert_reading(leaf, Sys.time())[2L], "end-entity",
    fixed = TRUE)
})

test_that("a certificate with no key usage says none is stated", {
  f <- system.file("extdata", "x509", "test-root.der",
    package = "rmoriebricklayer")
  root <- certprs(f)
  root$key_usage <- character()
  expect_match(box_text(root), "Key usage none stated", fixed = TRUE)
})

test_that("no byte mutation of a token verifies but the ones proven harmless", {
  f <- ts_fixtures()
  for (nm in c("rsa_token", "ecdsa_token")) {
    tok <- f[[nm]]
    top <- .Call(C_rmbl_der_parse, tok)
    # Harmless, and the only ones allowed: (1) PKIStatus 0 -> 1
    # (grantedWithMods), which carries the same token; (2) a byte of the CA
    # certificate the token carries a second time whose mutation leaves it a
    # certificate certprs() reads (strictly): nothing verified depends on
    # that copy, as the chain is built to `trust`.
    sd <- top$children[[2L]]$children[[2L]]$children[[1L]]
    certs <- Filter(function(n) {
      identical(n$class, 2L) && identical(n$tag, 0) && isTRUE(n$constructed)
    }, sd$children)[[1L]]$children
    expect_length(certs, 2L)
    ca <- (certs[[2L]]$start + 1):(certs[[2L]]$offset + certs[[2L]]$length)
    st <- top$children[[1L]]$children[[1L]]$offset + 1
    harmless <- function(m, i, b) {
      if (i == st && b == 1) {
        return(TRUE)
      }
      i %in% ca && !inherits(
        tryCatch(certprs(m[ca]), error = function(e) e), "error"
      )
    }
    survive <- character()
    for (i in seq_along(tok)) {
      # one flip a byte, the low bit or the high one in turn (about 5
      # minutes for both tokens); RMBL_MUTATE_ALL=1 tries both on every byte
      flips <- if (nzchar(Sys.getenv("RMBL_MUTATE_ALL"))) {
        c(0x01, 0x80)
      } else if (i %% 2L) {
        0x80
      } else {
        0x01
      }
      for (b in flips) {
        m <- tok
        m[i] <- xor(m[i], as.raw(b))
        r <- tryCatch(tsvrf(m, f$payload, trust = f$ca)$ok,
                      error = function(e) conditionMessage(e))
        if (is.character(r)) {
          survive <- c(survive, sprintf("%d^%02x error: %s", i, b, r))
        } else if (isTRUE(r) && !harmless(m, i, b)) {
          survive <- c(survive, sprintf("%d^%02x verifies", i, b))
        }
      }
    }
    expect_identical(survive, character(), info = nm)
  }
})

test_that("a GeneralizedTime with stray bytes reads as NA, without warnings", {
  bad <- rawToChar(as.raw(c(0x32, 0xb2, 0x32, 0x36, 0x30, 0x39, 0x31, 0x32,
                            0x32, 0x32, 0x30, 0x30, 0x33, 0x35, 0x5a)))
  expect_no_warning(t <- .rmbl_ts_gentime(bad))
  expect_true(is.na(t))
  expect_s3_class(t, "POSIXct")
  expect_true(is.na(.rmbl_ts_gentime("20260912220035")))
  expect_identical(
    format(.rmbl_ts_gentime("20260912220035Z"), "%Y-%m-%d %H:%M:%S",
           tz = "UTC"),
    "2026-09-12 22:00:35"
  )
  expect_equal(as.numeric(.rmbl_ts_gentime("20260912220035.25Z")) -
                 as.numeric(.rmbl_ts_gentime("20260912220035Z")), 0.25)
})
