# SPDX-License-Identifier: AGPL-3.0-or-later
#
# RFC 3161 timestamp tokens.
#
# A hash chain proves the order of a sequence of manifests. It does not
# prove that any of them existed at a particular time -- the whole chain
# can be built in an afternoon and dated however one likes. A timestamp
# token from a third party is what supplies the date, and verifying one
# means three separate things:
#
#   1. the token is about THESE bytes (the message imprint matches);
#   2. the token says WHEN (the genTime inside TSTInfo);
#   3. the authority really signed it (the signature over the signed
#      attributes verifies under the authority's public key).
#
# All three are checked here. What is NOT checked, and has to be said
# plainly because it is the difference between this and a browser's
# padlock: whether the authority's certificate should be trusted. That
# is a path-validation problem -- chain to a root, validity dates,
# revocation, the timeStamping extended key usage -- and this does none
# of it. Supply the certificate you have decided to trust.

#' Verify an RFC 3161 timestamp token
#'
#' Checks that a timestamp token covers the bytes given, reports the time
#' it asserts, and verifies the timestamping authority's signature under a
#' certificate you supply.
#'
#' What a passing check establishes: the holder of the key in
#' `certificate` signed a statement that the hash of `data`
#' existed at the reported time. What it does not establish: that the
#' certificate is one anybody should believe. No chain building, no
#' validity dates, no revocation, no check of the timeStamping key usage --
#' so pass the certificate you have independently decided to trust, and
#' treat a pass as saying "this key said so", not "this is true".
#'
#' RSA signatures are verified. A token signed with ECDSA or a post-quantum
#' algorithm is reported as unverifiable rather than treated as valid,
#' which is the safe direction for a verifier.
#'
#' @param token The token: a raw vector, or a path to a
#' `.tsr` / `.tst` file. A full `TimeStampResp` or a bare
#' `TimeStampToken` are both accepted.
#' @param data The bytes the token should cover: a raw vector,
#' or a path to a file.
#' @param certificate The authority's certificate, DER
#' or PEM, as raw or a path. Optional: when the token embeds a certificate,
#' that one is used and the fact is reported.
#' @return A list of class `bricklayer_timestamp`: `ok`,
#' `time` (a `POSIXct` in UTC), `serial`, `policy`,
#' `hash_algorithm`, `signature_algorithm`, and a `checks`
#' data frame.
#' @references Adams, C., Cain, P., Pinkas, D., and Zuccherato, R. (2001).
#' Internet X.509 Public Key Infrastructure Time-Stamp Protocol (TSP). RFC
#' 3161.
#' @seealso
#' [chain_seal()] for the ordering a timestamp
#' cannot give, [capsule_attest()] for
#' authorship.
#' @examples
#' # Tokens come from a timestamping authority, so there is nothing to
#' # demonstrate offline; this is the shape of the call.
#' \dontrun{
#' res <- timestamp_verify("response.tsr", data = "manifest.json")
#' res$ok
#' res$time
#' }
#' @export
timestamp_verify <- function(token, data, certificate = NULL) {
  token <- .rmbl_as_bytes(token, "token")
  data <- .rmbl_as_bytes(data, "data")
  checks <- list()
  note_row <- function(check, ok, detail = "") {
    checks[[length(checks) + 1L]] <<- data.frame(
      check = check, ok = isTRUE(ok), detail = as.character(detail),
      stringsAsFactors = FALSE)
  }
  der <- tryCatch(.Call(C_rmbl_der_parse, token), error = function(e) e)
  if (inherits(der, "error")) {
    note_row("token_parses", FALSE, conditionMessage(der))
    return(.rmbl_ts_result(checks, NULL))
  }
  note_row("token_parses", TRUE, sprintf("%d bytes of DER", length(token)))

  info <- tryCatch(.rmbl_ts_extract(der, token), error = function(e) e)
  if (inherits(info, "error")) {
    note_row("token_structure", FALSE, conditionMessage(info))
    return(.rmbl_ts_result(checks, NULL))
  }
  note_row("token_structure", TRUE,
           sprintf("TSTInfo of %d bytes", length(info$tst_der)))

  # 1. is the token about these bytes
  alg <- .rmbl_ts_digest_name(info$imprint_oid)
  if (is.na(alg)) {
    note_row("message_imprint", FALSE,
             paste("unsupported imprint algorithm", info$imprint_oid))
  } else {
    got <- .rmbl_ts_digest(alg, data)
    ok <- identical(got, info$imprint)
    note_row("message_imprint", ok,
             if (ok) sprintf("%s of the data matches the imprint", alg)
             else sprintf("%s of the data is %s, the token says %s", alg,
                          .rmbl_hexlify(got), .rmbl_hexlify(info$imprint)))
  }

  # 2. the signature over the signed attributes, under a key we are given
  cert <- if (!is.null(certificate)) {
    .rmbl_as_bytes(certificate, "certificate")
  } else if (!is.null(info$cert_der)) {
    info$cert_der
  } else {
    NULL
  }
  if (is.null(cert)) {
    note_row("signature", FALSE,
             "no certificate supplied and none embedded in the token")
  } else {
    note_row("certificate_source", TRUE,
             if (is.null(certificate)) "the token's embedded certificate"
             else "the certificate supplied by the caller")
    v <- tryCatch(.rmbl_ts_verify_sig(info, cert), error = function(e) e)
    if (inherits(v, "error")) {
      note_row("signature", FALSE, conditionMessage(v))
    } else {
      note_row("signature", v$ok, v$detail)
      # the signed attributes must themselves commit to the TSTInfo
      note_row("attribute_digest", v$content_ok, v$content_detail)
    }
  }
  .rmbl_ts_result(checks, info)
}

#' @rdname timestamp_verify
#' @export
timestamp_info <- function(token) {
  token <- .rmbl_as_bytes(token, "token")
  der <- .Call(C_rmbl_der_parse, token)
  info <- .rmbl_ts_extract(der, token)
  out <- list(time = info$time, serial = info$serial,
              policy = info$policy,
              hash_algorithm = .rmbl_ts_digest_name(info$imprint_oid),
              imprint = .rmbl_hexlify(info$imprint),
              signature_algorithm = info$sig_oid,
              has_certificate = !is.null(info$cert_der))
  out
}

.rmbl_ts_result <- function(checks, info) {
  df <- do.call(rbind, checks)
  rownames(df) <- NULL
  out <- list(ok = all(df$ok),
              time = if (is.null(info)) NA else info$time,
              serial = if (is.null(info)) NA_character_ else info$serial,
              policy = if (is.null(info)) NA_character_ else info$policy,
              hash_algorithm = if (is.null(info)) NA_character_ else
                .rmbl_ts_digest_name(info$imprint_oid),
              signature_algorithm = if (is.null(info)) NA_character_ else
                info$sig_oid,
              checks = df)
  class(out) <- c("bricklayer_timestamp", "list")
  out
}

#' @export
format.bricklayer_timestamp <- function(x, ...) {
  c(.rmbl_rule(sprintf("Timestamp token: %s",
                       if (x$ok) "verified" else "NOT verified")),
    .rmbl_kv(list(time = if (inherits(x$time, "POSIXct"))
                    format(x$time, "%Y-%m-%d %H:%M:%S UTC", tz = "UTC")
                  else "<unknown>",
                  serial = x$serial,
                  policy = x$policy,
                  imprint = x$hash_algorithm,
                  signature = x$signature_algorithm)),
    .rmbl_rule(),
    sprintf("  %-20s %-5s %s", x$checks$check,
            ifelse(x$checks$ok, "ok", "FAIL"),
            substring(x$checks$detail, 1L, 42L)),
    "  trust in the certificate is NOT checked here",
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_timestamp <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

# ---------------------------------------------------------------- #
# DER navigation. Everything below walks the structures RFC 3161,
# RFC 5652 (CMS) and RFC 5280 (X.509) define, by tag and by OID.
# ---------------------------------------------------------------- #

.rmbl_as_bytes <- function(x, what) {
  if (is.raw(x)) return(x)
  if (is.character(x) && length(x) == 1L && file.exists(x)) {
    b <- readBin(x, "raw", file.size(x))
    # a PEM file is base64 between markers; DER is what everything here
    # expects
    txt <- tryCatch(rawToChar(b), error = function(e) "")
    if (grepl("-----BEGIN", txt, fixed = TRUE)) {
      body <- sub(".*-----BEGIN[^-]*-----", "", txt)
      body <- sub("-----END.*", "", body)
      body <- gsub("[\r\n[:space:]]", "", body)
      return(bricklayer_json_base64_dec(body))
    }
    return(b)
  }
  stop(sprintf("`%s` must be a raw vector or the path to a file", what),
       call. = FALSE)
}

# An OID's dotted form, from its DER contents.
.rmbl_oid_string <- function(v) {
  if (!length(v)) return(NA_character_)
  b <- as.integer(v)
  first <- b[1]
  out <- c(first %/% 40L, first %% 40L)
  acc <- 0L
  for (i in seq_along(b)[-1]) {
    acc <- acc * 128L + (b[i] %% 128L)
    if (b[i] < 128L) {
      out <- c(out, acc)
      acc <- 0L
    }
  }
  paste(out, collapse = ".")
}

.rmbl_der_kids <- function(nd) nd$children

# Depth-first search for the first node satisfying `pred`.
.rmbl_der_find <- function(nd, pred) {
  if (isTRUE(pred(nd))) return(nd)
  for (k in .rmbl_der_kids(nd)) {
    r <- .rmbl_der_find(k, pred)
    if (!is.null(r)) return(r)
  }
  NULL
}

.rmbl_der_oid_eq <- function(nd, oid) {
  identical(nd$class, 0L) && identical(nd$tag, 6) &&
    identical(.rmbl_oid_string(nd$value), oid)
}

.rmbl_ts_digest_name <- function(oid) {
  switch(as.character(oid),
         "2.16.840.1.101.3.4.2.1" = "sha256",
         "2.16.840.1.101.3.4.2.2" = "sha384",
         "2.16.840.1.101.3.4.2.3" = "sha512",
         "1.3.14.3.2.26" = "sha1",
         NA_character_)
}

.rmbl_ts_digest <- function(alg, bytes) {
  switch(alg,
         sha256 = .rmbl_hex_to_raw(core_sha256(bytes)),
         sha512 = .rmbl_hex_to_raw(core_sha512(bytes)),
         stop(sprintf("digest %s is not available here", alg),
              call. = FALSE))
}

# Pull out the pieces of a TimeStampResp or bare TimeStampToken.
.rmbl_ts_extract <- function(der, token) {
  # The token is a CMS ContentInfo whose contentType is id-signedData.
  ci <- .rmbl_der_find(der, function(nd) {
    if (!isTRUE(nd$constructed) || !identical(nd$tag, 16)) return(FALSE)
    k <- nd$children
    length(k) >= 2L && .rmbl_der_oid_eq(k[[1]], "1.2.840.113549.1.7.2")
  })
  if (is.null(ci)) stop("no CMS SignedData in the token", call. = FALSE)
  sd <- ci$children[[2]]$children[[1]]      # [0] EXPLICIT SignedData
  # encapContentInfo: eContentType id-ct-TSTInfo, eContent [0] OCTET STRING
  eci <- .rmbl_der_find(sd, function(nd) {
    if (!isTRUE(nd$constructed) || !identical(nd$tag, 16)) return(FALSE)
    k <- nd$children
    length(k) >= 1L && .rmbl_der_oid_eq(k[[1]], "1.2.840.113549.1.9.16.1.4")
  })
  if (is.null(eci)) stop("no TSTInfo content in the token", call. = FALSE)
  oct <- .rmbl_der_find(eci$children[[2]], function(nd) {
    identical(nd$class, 0L) && identical(nd$tag, 4)
  })
  if (is.null(oct)) stop("the TSTInfo content is empty", call. = FALSE)
  tst_der <- oct$value
  tst <- .Call(C_rmbl_der_parse, tst_der)

  # TSTInfo: version, policy, messageImprint, serialNumber, genTime, ...
  k <- tst$children
  policy <- .rmbl_oid_string(k[[2]]$value)
  imprint_seq <- k[[3]]
  imprint_oid <- .rmbl_oid_string(imprint_seq$children[[1]]$children[[1]]$value)
  imprint <- imprint_seq$children[[2]]$value
  serial <- .rmbl_hexlify(k[[4]]$value)
  gen <- rawToChar(k[[5]]$value)
  time <- .rmbl_ts_gentime(gen)

  # the signer's information, and the certificate if one travelled
  si <- .rmbl_der_find(sd, function(nd) {
    isTRUE(nd$constructed) && identical(nd$tag, 17) &&
      length(nd$children) == 1L && isTRUE(nd$children[[1]]$constructed) &&
      length(nd$children[[1]]$children) >= 5L &&
      identical(nd$children[[1]]$children[[1]]$tag, 2)
  })
  if (is.null(si)) stop("no SignerInfo in the token", call. = FALSE)
  signer <- si$children[[1]]
  cert_der <- NULL
  certs <- Filter(function(nd) identical(nd$class, 2L) &&
                    identical(nd$tag, 0) && isTRUE(nd$constructed),
                  sd$children)
  if (length(certs)) {
    c1 <- certs[[1]]$children
    if (length(c1)) {
      st <- c1[[1]]$start
      cert_der <- token[(st + 1L):(c1[[1]]$offset + c1[[1]]$length)]
    }
  }
  list(tst_der = tst_der, policy = policy, imprint_oid = imprint_oid,
       imprint = imprint, serial = serial, time = time,
       signer = signer, cert_der = cert_der,
       sig_oid = .rmbl_ts_signer_sig_oid(signer),
       token = token)
}

# GeneralizedTime: YYYYMMDDHHMMSS[.fff]Z
.rmbl_ts_gentime <- function(s) {
  s <- sub("Z$", "", s)
  frac <- 0
  if (grepl("[.]", s)) {
    frac <- as.numeric(paste0("0.", sub(".*[.]", "", s)))
    s <- sub("[.].*", "", s)
  }
  t <- as.POSIXct(strptime(s, "%Y%m%d%H%M%S", tz = "UTC"), tz = "UTC")
  t + frac
}

.rmbl_ts_signer_sig_oid <- function(signer) {
  # SignerInfo: version, sid, digestAlgorithm, [0] signedAttrs,
  # signatureAlgorithm, signature
  algs <- Filter(function(nd) isTRUE(nd$constructed) &&
                   identical(nd$tag, 16) && length(nd$children) >= 1L &&
                   identical(nd$children[[1]]$tag, 6),
                 signer$children)
  if (length(algs) < 2L) return(NA_character_)
  .rmbl_oid_string(algs[[length(algs)]]$children[[1]]$value)
}

.rmbl_ts_verify_sig <- function(info, cert) {
  signer <- info$signer
  # signedAttrs is [0] IMPLICIT; the bytes that are SIGNED are the same
  # contents re-tagged as a SET, which is the one step in CMS that a
  # verifier gets wrong and then reports a valid signature as invalid.
  sa <- Filter(function(nd) identical(nd$class, 2L) &&
                 identical(nd$tag, 0) && isTRUE(nd$constructed),
               signer$children)
  if (!length(sa)) {
    stop("this token has no signed attributes; only that form is ",
         "supported here", call. = FALSE)
  }
  sa <- sa[[1]]
  body <- info$token[(sa$offset + 1L):(sa$offset + sa$length)]
  signed_bytes <- c(as.raw(0x31), .rmbl_der_length(length(body)), body)

  # messageDigest attribute: must equal the digest of the TSTInfo
  md_attr <- .rmbl_der_find(sa, function(nd) {
    isTRUE(nd$constructed) && identical(nd$tag, 16) &&
      length(nd$children) >= 2L &&
      .rmbl_der_oid_eq(nd$children[[1]], "1.2.840.113549.1.9.4")
  })
  content_ok <- FALSE
  content_detail <- "no messageDigest attribute"
  dalg <- .rmbl_ts_signer_digest(signer)
  if (!is.null(md_attr) && !is.na(dalg)) {
    want <- md_attr$children[[2]]$children[[1]]$value
    got <- .rmbl_ts_digest(dalg, info$tst_der)
    content_ok <- identical(want, got)
    content_detail <- if (content_ok)
      sprintf("the signed attributes commit to the TSTInfo (%s)", dalg)
    else sprintf("attribute says %s, the TSTInfo digests to %s",
                 .rmbl_hexlify(want), .rmbl_hexlify(got))
  }

  sig <- .rmbl_ts_signature(signer)
  key <- .rmbl_ts_cert_rsa(cert)
  if (is.null(key)) {
    stop("the certificate does not carry an RSA public key; only RSA ",
         "signatures are verified here, and an unverifiable signature ",
         "is reported as such rather than accepted", call. = FALSE)
  }
  em <- .Call(C_rmbl_rsa_recover, sig, key$modulus, key$exponent)
  ok <- .rmbl_pkcs1_check(em, dalg, signed_bytes)
  list(ok = ok$ok, detail = ok$detail, content_ok = content_ok,
       content_detail = content_detail)
}

.rmbl_ts_signer_digest <- function(signer) {
  algs <- Filter(function(nd) isTRUE(nd$constructed) &&
                   identical(nd$tag, 16) && length(nd$children) >= 1L &&
                   identical(nd$children[[1]]$tag, 6),
                 signer$children)
  if (!length(algs)) return(NA_character_)
  .rmbl_ts_digest_name(.rmbl_oid_string(algs[[1]]$children[[1]]$value))
}

.rmbl_ts_signature <- function(signer) {
  octs <- Filter(function(nd) identical(nd$class, 0L) &&
                   identical(nd$tag, 4), signer$children)
  if (!length(octs)) stop("no signature in the SignerInfo", call. = FALSE)
  octs[[length(octs)]]$value
}

# The DER length octets for a given length.
.rmbl_der_length <- function(n) {
  if (n < 128L) return(as.raw(n))
  bytes <- raw(0)
  v <- n
  while (v > 0) {
    bytes <- c(as.raw(v %% 256L), bytes)
    v <- v %/% 256L
  }
  c(as.raw(0x80 + length(bytes)), bytes)
}

# The RSA modulus and exponent from a certificate's SubjectPublicKeyInfo.
.rmbl_ts_cert_rsa <- function(cert) {
  der <- tryCatch(.Call(C_rmbl_der_parse, cert), error = function(e) NULL)
  if (is.null(der)) return(NULL)
  spki <- .rmbl_der_find(der, function(nd) {
    isTRUE(nd$constructed) && identical(nd$tag, 16) &&
      length(nd$children) == 2L &&
      isTRUE(nd$children[[1]]$constructed) &&
      length(nd$children[[1]]$children) >= 1L &&
      .rmbl_der_oid_eq(nd$children[[1]]$children[[1]],
                       "1.2.840.113549.1.1.1") &&
      identical(nd$children[[2]]$tag, 3)
  })
  if (is.null(spki)) return(NULL)
  bits <- spki$children[[2]]$value
  if (length(bits) < 2L) return(NULL)
  # a BIT STRING's first content octet is the number of unused bits
  inner <- bits[-1]
  rsa <- tryCatch(.Call(C_rmbl_der_parse, inner), error = function(e) NULL)
  if (is.null(rsa) || length(rsa$children) < 2L) return(NULL)
  strip <- function(v) {
    while (length(v) > 1L && v[1] == as.raw(0)) v <- v[-1]
    v
  }
  list(modulus = strip(rsa$children[[1]]$value),
       exponent = strip(rsa$children[[2]]$value))
}

# EMSA-PKCS1-v1_5: 0x00 0x01 0xff...0xff 0x00 DigestInfo.
.rmbl_pkcs1_check <- function(em, alg, message) {
  if (is.na(alg)) {
    return(list(ok = FALSE, detail = "unsupported signature digest"))
  }
  if (length(em) < 11L || em[1] != as.raw(0x00) ||
      em[2] != as.raw(0x01)) {
    return(list(ok = FALSE, detail = "the padding is not PKCS#1 v1.5"))
  }
  i <- 3L
  while (i <= length(em) && em[i] == as.raw(0xff)) i <- i + 1L
  if (i > length(em) || em[i] != as.raw(0x00) || i < 11L) {
    return(list(ok = FALSE,
                detail = "the padding has no separator, or too little of it"))
  }
  di <- em[(i + 1L):length(em)]
  want_digest <- .rmbl_ts_digest(alg, message)
  # The DigestInfo is a SEQUENCE of the algorithm and the digest; the
  # digest is compared rather than the whole encoding, so that an
  # absent-versus-NULL parameters difference does not read as a forgery.
  parsed <- tryCatch(.Call(C_rmbl_der_parse, di), error = function(e) NULL)
  if (is.null(parsed) || length(parsed$children) < 2L) {
    return(list(ok = FALSE, detail = "the recovered DigestInfo is malformed"))
  }
  got <- parsed$children[[2]]$value
  oid <- .rmbl_oid_string(parsed$children[[1]]$children[[1]]$value)
  if (!identical(.rmbl_ts_digest_name(oid), alg)) {
    return(list(ok = FALSE,
                detail = sprintf("the signature is over %s, not %s",
                                 .rmbl_ts_digest_name(oid), alg)))
  }
  if (!identical(got, want_digest)) {
    return(list(ok = FALSE,
                detail = sprintf("the signed digest is %s, the attributes ",
                                 .rmbl_hexlify(got))))
  }
  list(ok = TRUE,
       detail = sprintf("RSA over %s of the signed attributes", alg))
}
