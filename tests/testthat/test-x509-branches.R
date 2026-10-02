# The branches of the certificate and timestamp verifiers that the two
# fixture chains never reach: a version 1 certificate, a three-link path
# with a pathLenConstraint, the policy mapping and constraint extensions,
# ECDSA certificate signatures on P-256 and P-384, SHA-512 RSA
# signatures, and the answer every DER helper gives to malformed input.
#
# The chain_* certificates were built with OpenSSL 3.6 (see the fixture
# file); chain_v1 is chain_root's tbsCertificate with the [0] version
# removed, so it parses as v1 but no longer verifies.

x509_branch_fx <- function(file) {
  fx <- readLines(test_path(file), warn = FALSE)
  fx <- fx[!startsWith(fx, "#") & nzchar(fx)]
  parts <- strsplit(fx, "|", fixed = TRUE)
  stats::setNames(
    lapply(parts, function(p) .rmbl_hex_to_raw(p[2L])),
    vapply(parts, `[[`, character(1), 1L)
  )
}

der_tlv <- function(tag, body) c(as.raw(tag), .rmbl_der_length(length(body)), body)
der_oid <- function(hex) der_tlv(0x06, .rmbl_hex_to_raw(hex))
der_seq <- function(...) der_tlv(0x30, c(...))
der_ctx0 <- function(...) der_tlv(0xa0, c(...))
der_parse <- function(b) .Call(C_rmbl_der_parse, b)

test_that("a three-link chain honours pathLenConstraint and names its anchor", {
  f <- x509_branch_fx("x509-fixtures.txt")
  leaf <- cert_parse(f$chain_leaf)
  inter <- cert_parse(f$chain_inter)
  root <- cert_parse(f$chain_root)
  expect_identical(inter$path_len, 0L)
  expect_true(is.na(root$path_len))
  at <- leaf$not_before + 86400

  ch <- cert_chain_verify(leaf, trust = root, intermediates = inter, at_time = at, crls = NULL)
  expect_true(ch$ok)
  expect_length(ch$path, 3L)
  pl <- ch$checks[startsWith(ch$checks$check, "path length"), ]
  expect_identical(nrow(pl), 1L)
  expect_true(pl$ok)
  expect_match(pl$detail, "permits 0 intermediate")

  # the leaf is asked for a purpose it never states
  p <- cert_chain_verify(leaf, trust = root, intermediates = inter, at_time = at, purpose = "timeStamping")
  expect_false(p$ok)
  expect_match(p$checks$detail[p$checks$check == "purpose"], "no extended key usage")

  # anchoring at the intermediate: trusted because it was supplied
  mid <- cert_chain_verify(leaf, trust = inter, at_time = at)
  expect_true(mid$ok)
  expect_match(mid$checks$detail[mid$checks$check == "anchor_self_signed"], "supplied as trusted")

  # a certificate issued by a non-CA leaf: the signature is sound, the issuer may not issue
  leaf2 <- cert_parse(f$chain_leaf2)
  bad <- cert_chain_verify(leaf2, trust = leaf, at_time = leaf2$not_before + 86400)
  expect_false(bad$ok)
  expect_match(bad$checks$detail[startsWith(bad$checks$check, "is a CA")], "does not permit issuing")
  expect_true(bad$checks$ok[startsWith(bad$checks$check, "signature [1]")])

  # revocation = "fetch" consults the fetcher and folds its notes in
  testthat::local_mocked_bindings(.rmbl_revocation_fetch = function(path, ...) {
    list(crls = list(), notes = list(ocsp = "the responder said good"), ok = TRUE)
  })
  fe <- cert_chain_verify(leaf, trust = root, intermediates = inter, at_time = at, revocation = "fetch")
  expect_true(fe$checks$ok[fe$checks$check == "ocsp"])
  expect_match(fe$checks$detail[fe$checks$check == "ocsp"], "responder")

  # CRLs that are not files, not DER, or empty are skipped, and nothing is revoked
  rv <- .rmbl_crl_check(list(leaf), list("no-such-file.crl", as.raw(c(0x30, 0x00)), as.raw(c(0x30, 0x05))), at)
  expect_identical(rv$check, "revocation")
  expect_true(rv$ok)
  expect_match(rv$detail, "nothing revoked")
})

test_that("ECDSA-signed certificates verify on P-256 and P-384, and SHA-512 RSA too", {
  f <- x509_branch_fx("x509-fixtures.txt")
  for (nm in c("256", "384")) {
    root <- cert_parse(f[[paste0("chain_ec", nm)]])
    leaf <- cert_parse(f[[paste0("chain_ecleaf", nm)]])
    expect_identical(leaf$signature_algorithm, paste0("ECDSA-SHA", nm), info = nm)
    ch <- cert_chain_verify(leaf, trust = root, at_time = leaf$not_before + 86400)
    expect_true(ch$ok, info = nm)
    expect_match(ch$checks$detail[startsWith(ch$checks$check, "signature [1]")], "ECDSA.*on P-", info = nm)
    # the wrong key family, a signature that is not a DER pair, and other bytes
    v <- .rmbl_cert_verify_sig(leaf, cert_parse(f$chain_root))
    expect_false(v$ok)
    expect_match(v$detail, "not a usable EC key")
    broken <- leaf
    broken$signature <- as.raw(c(0x30, 0x00))
    expect_match(.rmbl_cert_verify_sig(broken, root)$detail, "malformed")
    tampered <- leaf
    tampered$tbs[10] <- xor(tampered$tbs[10], as.raw(1))
    expect_false(.rmbl_cert_verify_sig(tampered, root)$ok, info = nm)
  }

  l512 <- cert_parse(f$chain_leaf512)
  root <- cert_parse(f$chain_root)
  expect_identical(l512$signature_algorithm, "RSA-SHA512")
  ch <- cert_chain_verify(l512, trust = root, at_time = l512$not_before + 86400)
  expect_true(ch$ok)
  expect_match(ch$checks$detail[startsWith(ch$checks$check, "signature [1]")], "RSA over sha512")
  expect_match(.rmbl_cert_verify_sig(l512, cert_parse(f$chain_ec256))$detail, "not an RSA key")
  expect_false(.rmbl_cert_verify_sig(l512, list(key = list(type = "RSA", modulus = raw(0), exponent = raw(0))))$ok)
  unk <- l512
  unk$signature_algorithm <- "RSA-SHA1"
  expect_match(.rmbl_cert_verify_sig(unk, root)$detail, "not verified here")
  unk$signature_algorithm <- "DSA-SHA256"
  expect_match(.rmbl_cert_verify_sig(unk, root)$detail, "not verified here")
})

test_that("a version 1 certificate and the policy extensions parse", {
  f <- x509_branch_fx("x509-fixtures.txt")
  v1 <- cert_parse(f$chain_v1)
  expect_identical(v1$version, 1L)
  expect_match(v1$subject, "Version One")
  expect_true(v1$self_signed)
  expect_identical(v1$key$type, "RSA")

  pe <- cert_parse(f$chain_polext)
  expect_identical(pe$policies, "1.2.3.4.100")
  expect_identical(pe$policy_mappings, list(list(issuer = "1.2.3.4.100", subject = "1.2.3.4.101")))
  expect_identical(pe$require_explicit_policy, 0L)
  expect_identical(pe$inhibit_policy_mapping, 1L)
  expect_identical(pe$inhibit_any_policy, 2L)
  # a certificatePolicies extension whose one PolicyInformation is empty
  expect_identical(cert_parse(f$chain_polempty)$policies, character(0))

  expect_true(is.na(.rmbl_int_of(raw(0))))
  expect_identical(.rmbl_int_of(as.raw(c(1, 0))), 256L)
})

test_that("the DER helpers answer malformed input with NA, empty, or an error", {
  expect_error(cert_parse(as.raw(c(0x30, 0x03, 0x02, 0x01, 0x05))), "not an X.509")
  expect_error(cert_parse(as.raw(c(0x30, 0x08, 0x02, 0x01, 0x05, 0x02, 0x01, 0x05, 0x03, 0x00))), "no signature")
  expect_true(is.na(.rmbl_oid_string(raw(0))))
  expect_identical(.rmbl_key_usage_bits(as.raw(0x00)), character(0))
  expect_identical(.rmbl_x509_sigalg_name("1.2.840.113549.1.1.12"), "RSA-SHA384")
  expect_identical(.rmbl_x509_sigalg_name("1.2.840.113549.1.1.13"), "RSA-SHA512")
  expect_identical(.rmbl_x509_sigalg_name("1.2.840.113549.1.1.5"), "RSA-SHA1")
  expect_identical(.rmbl_x509_sigalg_name("1.2.840.10045.4.3.3"), "ECDSA-SHA384")
  expect_identical(.rmbl_x509_sigalg_name("1.2.840.10045.4.3.4"), "ECDSA-SHA512")
  expect_identical(.rmbl_x509_sigalg_name("1.2.3"), "1.2.3")
  expect_null(.rmbl_ecdsa_rs(as.raw(c(0x30, 0x00))))

  # keys: RSA bits that do not parse, a compressed EC point, an unknown algorithm
  mk <- function(alg, bits) list(children = list(list(children = alg), list(value = bits)))
  rsa_oid <- .rmbl_hex_to_raw("2a864886f70d010101")
  ec_oid <- .rmbl_hex_to_raw("2a8648ce3d0201")
  p256 <- .rmbl_hex_to_raw("2a8648ce3d030107")
  expect_identical(.rmbl_x509_key(mk(list(list(value = rsa_oid)), as.raw(c(0x00, 0xff))))$type, "unknown")
  comp <- .rmbl_x509_key(mk(list(list(value = ec_oid), list(value = p256)), as.raw(c(0x00, 0x02, 0x01))))
  expect_identical(comp$type, "EC")
  expect_identical(comp$bits, 0L)
  expect_null(comp$x)
  other <- .rmbl_x509_key(mk(list(list(value = as.raw(c(0x2a, 0x03)))), as.raw(c(0x00, 0x01))))
  expect_identical(other$type, "1.2.3")
  expect_identical(other$bits, 0L)

  # a name whose attribute has no value, and extensions that are empty or do not parse
  expect_identical(.rmbl_x509_name(list(children = list(list(children = list(list(children = list())))))), "")
  bc <- .rmbl_hex_to_raw("551d13")
  k <- list(list(class = 2L, tag = 3, children = list(list(children = list(
    list(children = list()),
    list(children = list(list(value = bc), list(value = as.raw(c(0x30, 0x05)))))
  )))))
  expect_false(.rmbl_x509_extensions(k)$is_ca)
  expect_identical(.rmbl_x509_extensions(list())$policies, character(0))
  # a policy mapping that is not a pair, and a policy constraint whose child is untagged
  ext <- function(oidhex, val) list(children = list(list(value = .rmbl_hex_to_raw(oidhex)), list(value = val)))
  k2 <- list(list(class = 2L, tag = 3, children = list(list(children = list(
    ext("551d21", as.raw(c(0x30, 0x02, 0x30, 0x00))),
    ext("551d24", as.raw(c(0x30, 0x03, 0x02, 0x01, 0x00)))
  )))))
  e2 <- .rmbl_x509_extensions(k2)
  expect_identical(e2$policy_mappings, list())
  expect_true(is.na(e2$require_explicit_policy))
})

test_that("a timestamp token with a broken structure is reported, not thrown", {
  f <- x509_branch_fx("timestamp-token.txt")
  tok <- f$rsa_token
  nd <- timestamp_verify(as.raw(c(0x30, 0x05)), f$payload)
  expect_false(nd$ok)
  expect_false(nd$checks$ok[nd$checks$check == "token_parses"])
  r <- timestamp_verify(as.raw(c(0x30, 0x00)), f$payload)
  expect_false(r$ok)
  expect_match(r$checks$detail[r$checks$check == "token_structure"], "no CMS SignedData")
  expect_output(print(r), "<unknown>")

  # with no anchor the printout says so, and an anchor that is not a certificate is reported
  bare <- timestamp_verify(tok, f$payload)
  expect_true(any(grepl("no anchor was given", format(bare), fixed = TRUE)))
  # other data than the token names, and a certificate handed in by the caller
  other <- timestamp_verify(tok, charToRaw("other bytes"))
  expect_false(other$checks$ok[other$checks$check == "message_imprint"])
  given <- timestamp_verify(tok, f$payload, certificate = f$rsa_cert, trust = f$ca)
  expect_true(given$ok)
  expect_match(given$checks$detail[given$checks$check == "certificate_source"], "supplied by the caller")
  testthat::with_mocked_bindings(
    .rmbl_ts_verify_sig = function(info, cert) stop("the verifier gave up", call. = FALSE),
    {
      thrown <- timestamp_verify(tok, f$payload)
      expect_match(thrown$checks$detail[thrown$checks$check == "signature"], "gave up")
    }
  )
  r <- timestamp_verify(tok, f$payload, trust = as.raw(c(0x30, 0x00)))
  expect_match(r$checks$detail[r$checks$check == "certificate_trust"], "not an X.509")

  real_extract <- .rmbl_ts_extract
  testthat::with_mocked_bindings(
    .rmbl_ts_extract = function(der, token) {
      i <- real_extract(der, token)
      i$imprint_oid <- "1.2.3"
      i
    },
    {
      r <- timestamp_verify(tok, f$payload)
      expect_match(r$checks$detail[r$checks$check == "message_imprint"], "unsupported imprint")
    }
  )
  testthat::with_mocked_bindings(
    .rmbl_ts_extract = function(der, token) {
      i <- real_extract(der, token)
      i$cert_der <- NULL
      i
    },
    {
      r <- timestamp_verify(tok, f$payload)
      expect_match(r$checks$detail[r$checks$check == "signature"], "no certificate supplied")
    }
  )

  # each layer of the CMS structure missing in turn
  sd_oid <- der_oid("2a864886f70d010702")
  tst_oid <- der_oid("2a864886f70d0109100104")
  expect_error(.rmbl_ts_extract(der_parse(der_seq()), raw(0)), "no CMS SignedData")
  expect_error(.rmbl_ts_extract(der_parse(der_seq(sd_oid, der_ctx0(der_seq()))), raw(0)), "no TSTInfo")
  empty <- der_seq(sd_oid, der_ctx0(der_seq(der_seq(tst_oid, der_ctx0()))))
  expect_error(.rmbl_ts_extract(der_parse(empty), raw(0)), "TSTInfo content is empty")
  tst <- der_seq(
    der_tlv(0x02, as.raw(1)), der_oid("2a0304"),
    der_seq(der_seq(der_oid("2b0e03021a")), der_tlv(0x04, as.raw(0))),
    der_tlv(0x02, as.raw(7)), der_tlv(0x18, charToRaw("20240101120000Z"))
  )
  no_signer <- der_seq(sd_oid, der_ctx0(der_seq(der_seq(tst_oid, der_ctx0(der_tlv(0x04, tst))))))
  expect_error(.rmbl_ts_extract(der_parse(no_signer), no_signer), "no SignerInfo")

  # fractional seconds in GeneralizedTime
  g <- .rmbl_ts_gentime("20240101120000Z")
  expect_equal(as.numeric(.rmbl_ts_gentime("20240101120000.5Z") - g, units = "secs"), 0.5)
})

test_that("the signer helpers and the digest helpers cover every algorithm they name", {
  f <- x509_branch_fx("timestamp-token.txt")
  empty_signer <- list(children = list())
  expect_true(is.na(.rmbl_ts_signer_sig_oid(empty_signer)))
  expect_true(is.na(.rmbl_ts_signer_digest(empty_signer)))
  expect_error(.rmbl_ts_signature(empty_signer), "no signature")

  info <- .rmbl_ts_extract(der_parse(f$rsa_token), f$rsa_token)
  bad <- info
  bad$signer <- empty_signer
  expect_error(.rmbl_ts_verify_sig(bad, f$rsa_cert), "no signed attributes")
  testthat::with_mocked_bindings(
    cert_parse = function(x) list(key = list(type = "DSA")),
    expect_error(.rmbl_ts_verify_sig(info, f$rsa_cert), "carries a DSA key")
  )

  # an ECDSA signature that is not a DER pair
  ei <- .rmbl_ts_extract(der_parse(f$ecdsa_token), f$ecdsa_token)
  k <- ei$signer$children
  idx <- which(vapply(k, function(nd) identical(nd$class, 0L) && identical(nd$tag, 4), logical(1)))
  k[[max(idx)]]$value <- as.raw(c(0x30, 0x00))
  ei$signer$children <- k
  v <- .rmbl_ts_verify_sig(ei, f$ecdsa_cert)
  expect_false(v$ok)
  expect_match(v$detail, "malformed")
  expect_true(v$content_ok)

  expect_identical(.rmbl_ts_digest_name("2.16.840.1.101.3.4.2.2"), "sha384")
  expect_identical(.rmbl_ts_digest_name("2.16.840.1.101.3.4.2.3"), "sha512")
  expect_identical(.rmbl_ts_digest_name("1.3.14.3.2.26"), "sha1")
  expect_true(is.na(.rmbl_ts_digest_name("9.9")))
  expect_identical(
    .rmbl_hexlify(.rmbl_ts_digest("sha512", charToRaw("abc"))),
    paste0(
      "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a",
      "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
    )
  )
  expect_identical(
    .rmbl_hexlify(.rmbl_ts_digest("sha384", charToRaw("abc"))),
    paste0(
      "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43",
      "ff5bed8086072ba1e7cc2358baeca134c825a7"
    )
  )
  expect_error(.rmbl_ts_digest("sha1", raw(0)), "not available")

  # the RSA key out of a certificate, and NULL for anything else
  rk <- .rmbl_ts_cert_rsa(f$rsa_cert)
  expect_identical(rk$modulus, cert_parse(f$rsa_cert)$key$modulus)
  expect_identical(rk$exponent, as.raw(c(1, 0, 1)))
  expect_null(.rmbl_ts_cert_rsa(f$ecdsa_cert))
  expect_null(.rmbl_ts_cert_rsa(as.raw(c(0x30, 0x05))))

  # PKCS#1 v1.5: every way the recovered block can be wrong
  msg <- charToRaw("abc")
  pad <- as.raw(c(0, 1, rep(0xff, 8), 0))
  dinfo <- function(oidhex, digest) der_seq(der_seq(der_oid(oidhex), der_tlv(0x05, raw(0))), der_tlv(0x04, digest))
  d256 <- .rmbl_ts_digest("sha256", msg)
  expect_match(.rmbl_pkcs1_check(raw(12), NA_character_, msg)$detail, "unsupported")
  expect_match(.rmbl_pkcs1_check(as.raw(c(0, 1, rep(0xff, 10))), "sha256", msg)$detail, "no separator")
  expect_match(.rmbl_pkcs1_check(c(pad, as.raw(c(0x30, 0x09))), "sha256", msg)$detail, "malformed")
  wrong_alg <- c(pad, dinfo("608648016503040203", .rmbl_ts_digest("sha512", msg)))
  expect_match(.rmbl_pkcs1_check(wrong_alg, "sha256", msg)$detail, "over sha512, not sha256")
  wrong_digest <- c(pad, dinfo("608648016503040201", rev(d256)))
  expect_match(.rmbl_pkcs1_check(wrong_digest, "sha256", msg)$detail, "signed digest is")
  expect_true(.rmbl_pkcs1_check(c(pad, dinfo("608648016503040201", d256)), "sha256", msg)$ok)
})
