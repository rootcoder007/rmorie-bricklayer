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
#' @description
#' A timestamp token is a small file, signed by an independent timestamping
#' authority, saying that a given set of bytes (for example a manifest of
#' results) existed at a given time. `tsvrf()` checks that a
#' token covers the bytes given, reports the time it asserts, and verifies
#' the timestamping authority's signature under a certificate you supply or
#' the one the token carries. `tsinfo()` reads the token's fields
#' without verifying anything. Use them to prove that an analysis output
#' existed by a certain date.
#'
#' @details
#' Every step is recorded as a row of `checks`:
#'
#' * `token_parses`;
#' * `token_structure`;
#' * `message_imprint` (the hash of `data` equals the token's imprint);
#' * `certificate_source`;
#' * `signature`;
#' * `attribute_digest` (the signed attributes commit to the token's contents);
#' * `certificate_trust`;
#' * with `trust`, the `chain:` checks of
#'   [certchnvrf()].
#'
#' `ok` is `TRUE` only
#' when every row passes. A token
#' that cannot be parsed is not an error: it gives `ok = FALSE` and the
#' rows up to the failure.
#'
#' Pass `trust` and the certificate is validated too: the chain is
#' built to an anchor you name, every signature in it is verified, every
#' validity window is checked, an issuer must be a CA, and the leaf must
#' carry the timeStamping extended key usage. Omit `trust` and the
#' signature is still checked but `certificate_trust` is reported as
#' failed, because without an anchor a passing signature says only that the
#' key in the certificate signed the token -- not that anyone should
#' believe that certificate.
#'
#' Validity windows are checked at the time the TOKEN asserts, unless
#' `attm` says otherwise. A token signed in 2020 under a
#' certificate that expired in 2021 was validly signed, and judging it by
#' today's date would reject it for a reason unconnected to its validity.
#'
#' RSA and ECDSA over the NIST prime curves P-256, P-384 and P-521 are
#' verified. Anything else -- a post-quantum signature, a compressed EC
#' point, an Edwards curve -- is reported as unverifiable rather than
#' treated as valid, which is the safe direction for a verifier.
#'
#' Revocation data are not fetched: a CRL has to be handed in through
#' `crls`, and nothing is retrieved over the network (chain checks such as
#' name constraints and certificate policies are done by
#' [certchnvrf()]). Nothing is written to disk.
#'
#' Errors: `token`, `data` or `cert` neither a raw vector nor the
#' path of an existing file. `tsinfo()` errors on a token it cannot
#' parse.
#'
#' @param token The token: a raw vector, or a path to a
#' `.tsr` / `.tst` file. A full `TimeStampResp` or a bare
#' `TimeStampToken` are both accepted.
#' @param data The bytes the token should cover: a raw vector,
#' or a path to a file.
#' @param cert The authority's certificate, DER
#' or PEM, as raw or a path. Optional: when the token embeds a certificate,
#' that one is used and the fact is reported.
#' @param trust Trust anchors for validating that certificate
#' -- see [certchnvrf()]. Without
#' them the signature is still checked, but nothing vouches for the key
#' that made it.
#' @param crls Optional CRLs to check the chain against, as raw
#' vectors or paths.
#' @param attm The time to check certificate validity at.
#' Defaults to the time the token asserts, which is usually what is wanted.
#' @param nonce The raw nonce the request sent, or `NULL` (the default)
#'   when it is not known. Given, the token must carry it: a token answering
#'   another request is refused.
#' @return `tsvrf()` returns a list of class
#' `bricklayer_timestamp`: `ok` (logical), `time` (a `POSIXct` in
#' UTC, or
#' `NA` when the token could not be read), `serial` and `policy`
#' (character), `hash_algorithm` (for example `"sha256"`),
#' `signature_algorithm` (an OID string), and a `checks` data frame with
#' columns `check`, `ok` and `detail`. The print method lists the checks.
#' `tsinfo()` returns a plain list with `time`, `serial`,
#' `policy`,
#' `hash_algorithm`, `imprint` (hex), `signature_algorithm` and
#' `has_certificate` (logical).
#' @references Adams, C., Cain, P., Pinkas, D., and Zuccherato, R. (2001).
#' Internet X.509 Public Key Infrastructure Time-Stamp Protocol (TSP). RFC
#' 3161.
#' @seealso
#' [chnseal()] for the ordering a timestamp
#' cannot give, [cpsatst()] for
#' authorship.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Offline: bytes that are not a timestamp token are reported, not
#' # thrown, so a batch check can carry on.
#' bad <- tsvrf(as.raw(c(0x30, 0x03, 0x02, 0x01, 0x05)),
#'                         data = charToRaw("manifest"))
#' bad$ok
#' bad$checks
#'
#' # tsinfo() does refuse an unreadable token
#' try(tsinfo(as.raw(1:10)))
#'
#' # Real tokens come from a timestamping authority; this is the shape of
#' # the call.
#'
#' @examplesIf interactive()
#' res <- tsvrf("response.tsr", data = "manifest.json")
#' res$ok
#' res$time
#' @export
tsvrf <- function(
  token,
  data,
  cert = NULL,
  trust = NULL,
  crls = list(),
  attm = NULL,
  nonce = NULL
) {
  token <- .rmbl_as_bytes(token, "token")
  data <- .rmbl_as_bytes(data, "data")
  if (!is.null(nonce) && (!is.raw(nonce) || !length(nonce) ||
                            length(nonce) > 64L)) {
    stop("`nonce` must be the raw bytes the request sent, or NULL",
         call. = FALSE)
  }
  acc <- new.env(parent = emptyenv())
  acc$checks <- list()
  note_row <- .rmbl_ts_recorder(acc)
  der <- tryCatch(.Call(C_rmbl_der_parse, token), error = function(e) e)
  if (inherits(der, "error")) {
    note_row("token_parses", FALSE, conditionMessage(der))
    return(.rmbl_ts_result(acc$checks, NULL))
  }
  note_row("token_parses", TRUE, sprintf("%d bytes of DER", length(token)))

  info <- tryCatch(.rmbl_ts_extract(der, token), error = function(e) e)
  if (inherits(info, "error")) {
    note_row("token_structure", FALSE, conditionMessage(info))
    return(.rmbl_ts_result(acc$checks, NULL))
  }
  note_row(
    "token_structure",
    TRUE,
    sprintf("TSTInfo of %d bytes", length(info$tst_der))
  )
  .rmbl_ts_nonce_row(info, nonce, note_row)

  .rmbl_ts_imprint_row(info, data, note_row)
  # 2. the signature over the signed attributes, under a key we are given
  .cert <- if (is.null(cert)) info$cert_der else .rmbl_as_bytes(cert, "cert")
  if (is.null(.cert)) {
    note_row(
      "signature",
      FALSE,
      "no certificate supplied and none embedded in the token"
    )
  } else {
    note_row(
      "certificate_source",
      TRUE,
      if (is.null(cert)) {
        "the token's embedded certificate"
      } else {
        "the certificate supplied by the caller"
      }
    )
    .rmbl_ts_sid_row(info, .cert, note_row)
    .rmbl_ts_sig_rows(info, .cert, note_row)
    .rmbl_ts_trust_rows(info, .cert, trust, attm, crls, note_row)
  }
  .rmbl_ts_result(acc$checks, info)
}

#' @rdname tsvrf
#' @export
tsinfo <- function(token) {
  token <- .rmbl_as_bytes(token, "token")
  der <- .Call(C_rmbl_der_parse, token)
  info <- .rmbl_ts_extract(der, token)
  out <- list(
    time = info$time,
    serial = info$serial,
    policy = info$policy,
    hash_algorithm = .rmbl_ts_digest_name(info$imprint_oid),
    imprint = .rmbl_hexlify(info$imprint),
    signature_algorithm = info$sig_oid,
    has_certificate = !is.null(info$cert_der)
  )
  out
}

#' @export
format.bricklayer_timestamp <- function(x, ...) {
  .rmbl_stat_block(
    sprintf(
      "Timestamp token: %s",
      if (isTRUE(x$ok)) "verified" else "NOT verified"
    ),
    facts = list(
      Time = if (inherits(x$time, "POSIXct")) {
        format(x$time, "%Y-%m-%d %H:%M:%S UTC", tz = "UTC")
      } else {
        "<unknown>"
      },
      Serial = x$serial,
      Policy = x$policy,
      Imprint = x$hash_algorithm,
      Signature = x$signature_algorithm
    ),
    reading = .rmbl_check_reading(
      x$ok,
      "the authority vouches that the data existed at this time",
      "the token does not prove when the data existed"
    ),
    notes = c(
      .rmbl_check_lines(x$checks),
      # Only say this when it is true. Trust IS checked when an anchor
      # was given, and a line claiming otherwise under a verified chain
      # would be the most misleading thing on the screen.
      if (
        any(x$checks$check == "certificate_trust" & !x$checks$ok) &&
          !any(startsWith(x$checks$check, "chain:"))
      ) {
        c("", "no anchor was given: nothing vouches for the certificate")
      }
    )
  )
}

#' A function that records one check of tsvrf() as a row in `acc$checks`.
#' @param acc The environment the rows are kept in.
#' @return The function (check, ok, detail).
#' @noRd
.rmbl_ts_recorder <- function(acc) {
  function(check, ok, detail = "") {
    acc$checks[[length(acc$checks) + 1L]] <- data.frame(
      check = check,
      ok = isTRUE(ok),
      detail = as.character(detail),
      stringsAsFactors = FALSE
    )
  }
}

#' tsvrf()'s row on whether the token's imprint is a digest of the data.
#' @param info The token's contents (.rmbl_ts_extract()).
#' @param data The data's bytes.
#' @param note_row The function that records the imprint check.
#' @return NULL, invisibly.
#' @noRd
.rmbl_ts_imprint_row <- function(info, data, note_row) {
  # 1. is the token about these bytes
  alg <- .rmbl_ts_digest_name(info$imprint_oid)
  if (is.na(alg)) {
    note_row(
      "message_imprint",
      FALSE,
      paste("unsupported imprint algorithm", info$imprint_oid)
    )
  } else {
    got <- .rmbl_ts_digest(alg, data)
    ok <- identical(got, info$imprint)
    note_row(
      "message_imprint",
      ok,
      if (ok) {
        sprintf("%s of the data matches the imprint", alg)
      } else {
        sprintf(
          "%s of the data is %s, the token says %s",
          alg,
          .rmbl_hexlify(got),
          .rmbl_hexlify(info$imprint)
        )
      }
    )
  }
  invisible(NULL)
}

#' tsvrf()'s rows on the signature over the signed attributes.
#' @param info The token's contents.
#' @param .cert The certificate's DER bytes.
#' @param note_row The function that records the signature checks.
#' @return NULL, invisibly.
#' @noRd
.rmbl_ts_sig_rows <- function(info, .cert, note_row) {
  v <- tryCatch(.rmbl_ts_verify_sig(info, .cert), error = function(e) e)
  if (inherits(v, "error")) {
    note_row("signature", FALSE, conditionMessage(v))
  } else {
    note_row("signature", v$ok, v$detail)
    # the signed attributes must themselves commit to the TSTInfo
    note_row("attribute_digest", v$content_ok, v$content_detail)
  }
  invisible(NULL)
}

#' tsvrf()'s rows on whether a trust anchor vouches for the certificate.
#' @param info The token's contents.
#' @param .cert The certificate's DER bytes.
#' @param trust,attm,crls As for tsvrf().
#' @param note_row The function that records the trust checks.
#' @return NULL, invisibly.
#' @noRd
.rmbl_ts_trust_rows <- function(info, .cert, trust, attm, crls, note_row) {
  # Trust. Without an anchor the check above says only that the key in
  # the certificate signed the token; with one it says a key you chose
  # to believe vouches for that certificate.
  if (is.null(trust)) {
    note_row(
      "certificate_trust",
      FALSE,
      paste(
        "no trust anchor given: the key in the certificate",
        "signed the token, but nothing vouches for the",
        "certificate itself"
      )
    )
  } else {
    # Validity windows are checked at the time the TOKEN asserts, not
    # now. A token signed in 2020 under a certificate that expired in
    # 2021 was validly signed, and judging it by today's date would
    # reject it for a reason unconnected to its validity.
    when <- if (is.null(attm)) info$time else attm
    ch <- tryCatch(
      certchnvrf(
        .cert,
        trust = trust,
        attm = when,
        purp = "timeStamping",
        crls = crls
      ),
      error = function(e) e
    )
    .rmbl_ts_chain_rows(ch, when, note_row)
  }
  invisible(NULL)
}

#' tsvrf()'s rows from the certificate chain's check.
#' @param ch What certchnvrf() returned, or the error it gave.
#' @param when The time the chain was checked at.
#' @param note_row The function that records the certificate chain's check.
#' @return NULL, invisibly.
#' @noRd
.rmbl_ts_chain_rows <- function(ch, when, note_row) {
  if (inherits(ch, "error")) {
    note_row("certificate_trust", FALSE, conditionMessage(ch))
  } else {
    note_row(
      "certificate_trust",
      ch$ok,
      sprintf(
        "%d certificate(s), checked at %s",
        length(ch$path),
        format(when, "%Y-%m-%d", tz = "UTC")
      )
    )
    for (i in seq_len(nrow(ch$checks))) {
      note_row(
        paste0("chain:", ch$checks$check[i]),
        ch$checks$ok[i],
        ch$checks$detail[i]
      )
    }
  }
  invisible(NULL)
}

#' Assembles the result of a timestamp verification.
#' @param checks A list of one-row data frames, one per check.
#' @param info The token's pieces from `.rmbl_ts_extract()`, or NULL when it
#'   could not be read.
#' @return A `bricklayer_timestamp` list.
#' @noRd
.rmbl_ts_result <- function(checks, info) {
  df <- do.call(rbind, checks)
  rownames(df) <- NULL
  out <- list(
    ok = all(df$ok),
    time = if (is.null(info)) NA else info$time,
    serial = if (is.null(info)) NA_character_ else info$serial,
    policy = if (is.null(info)) NA_character_ else info$policy,
    hash_algorithm = if (is.null(info)) {
      NA_character_
    } else {
      .rmbl_ts_digest_name(info$imprint_oid)
    },
    signature_algorithm = if (is.null(info)) {
      NA_character_
    } else {
      info$sig_oid
    },
    checks = df
  )
  class(out) <- c("bricklayer_timestamp", "list")
  out
}

# ---------------------------------------------------------------- #
# DER navigation. Everything below walks the structures RFC 3161,
# RFC 5652 (CMS) and RFC 5280 (X.509) define, by tag and by OID.
# ---------------------------------------------------------------- #

#' Reads a token or certificate as DER bytes, from a raw vector or a DER or PEM
#' file.
#' @param x A raw vector or the path to a file.
#' @param what The argument's name, quoted when the token cannot be read.
#' @return A raw vector.
#' @noRd
.rmbl_as_bytes <- function(x, what) {
  if (is.raw(x)) {
    return(x)
  }
  if (is.character(x) && length(x) == 1L && dir.exists(x)) {
    stop(
      sprintf("`%s` is a directory, not a token file: %s", what, x),
      call. = FALSE
    )
  }
  if (is.character(x) && length(x) == 1L && file.exists(x)) {
    b <- readBin(x, "raw", file.size(x))
    # a PEM file is base64 between markers; DER is what everything here
    # expects
    txt <- tryCatch(rawToChar(b), error = function(e) "")
    if (grepl("-----BEGIN", txt, fixed = TRUE)) {
      body <- sub(".*-----BEGIN[^-]*-----", "", txt)
      body <- sub("-----END.*", "", body)
      body <- gsub("[\r\n[:space:]]", "", body)
      return(jsb64dec(body))
    }
    return(b)
  }
  stop(
    sprintf("`%s` must be a raw vector or the path to a file", what),
    call. = FALSE
  )
}

#' An OID's dotted form, from its DER contents.
#' @param v The OID's DER contents, as a raw vector.
#' @return The dotted OID, or NA for empty contents.
#' @noRd
.rmbl_oid_string <- function(v) {
  if (!length(v)) {
    return(NA_character_)
  }
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

#' Returns the children of a parsed DER node.
#' @param nd A node from the DER parser.
#' @return A list of nodes.
#' @noRd
.rmbl_der_kids <- function(nd) nd$children

#' Depth-first search for the first node satisfying `pred`.
#' @param nd A node from the DER parser.
#' @param pred A function of a node that returns `TRUE` for a match.
#' @return The first matching node, or NULL.
#' @noRd
.rmbl_der_find <- function(nd, pred) {
  if (isTRUE(pred(nd))) {
    return(nd)
  }
  for (k in .rmbl_der_kids(nd)) {
    r <- .rmbl_der_find(k, pred)
    if (!is.null(r)) {
      return(r)
    }
  }
  NULL
}

#' Tells whether a DER node is an OBJECT IDENTIFIER with the given dotted value.
#' @param nd A node from the DER parser.
#' @param oid The dotted OID.
#' @return `TRUE` or `FALSE`.
#' @noRd
.rmbl_der_oid_eq <- function(nd, oid) {
  identical(nd$class, 0L) &&
    identical(nd$tag, 6) &&
    identical(.rmbl_oid_string(nd$value), oid)
}

#' Names the digest algorithm of a dotted OID.
#' @param oid The dotted OID.
#' @return \code{"sha256"}, \code{"sha384"}, \code{"sha512"} or \code{"sha1"},
#' or NA for another OID.
#' @noRd
.rmbl_ts_digest_name <- function(oid) {
  switch(
    as.character(oid),
    "2.16.840.1.101.3.4.2.1" = "sha256",
    "2.16.840.1.101.3.4.2.2" = "sha384",
    "2.16.840.1.101.3.4.2.3" = "sha512",
    "1.3.14.3.2.26" = "sha1",
    NA_character_
  )
}

#' Computes a digest of bytes with a named algorithm.
#' @param alg \code{"sha256"}, \code{"sha384"} or \code{"sha512"}.
#' @param bytes A raw vector to digest.
#' @return The digest as a raw vector.
#' @noRd
.rmbl_ts_digest <- function(alg, bytes) {
  if (!alg %in% c("sha256", "sha384", "sha512")) {
    stop(sprintf("digest %s is not available here", alg), call. = FALSE)
  }
  switch(
    alg,
    sha256 = .rmbl_hex_to_raw(csha256(bytes)),
    sha384 = .Call(C_rmbl_sha384, bytes),
    sha512 = .rmbl_hex_to_raw(csha512(bytes))
  )
}

#' Whether a DER node is a SEQUENCE of at least `n` elements whose first is the
#' OID `oid`.
#' @param nd The parsed DER node to test for a SEQUENCE led by the OID.
#' @param n The least number of elements.
#' @param oid The OID, dotted.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_ts_seq_with_oid <- function(nd, n, oid) {
  if (!isTRUE(nd$constructed) || !identical(nd$tag, 16)) {
    return(FALSE)
  }
  k <- nd$children
  length(k) >= n && .rmbl_der_oid_eq(k[[1]], oid)
}

#' Whether a DER node is a SignerInfos SET holding one SignerInfo.
#' @param nd The parsed DER node to test for a SignerInfos SET.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_ts_is_signer_infos <- function(nd) {
  isTRUE(nd$constructed) &&
    identical(nd$tag, 17) &&
    length(nd$children) == 1L &&
    isTRUE(nd$children[[1]]$constructed) &&
    length(nd$children[[1]]$children) >= 5L &&
    identical(nd$children[[1]]$children[[1]]$tag, 2)
}

#' The first certificate that travelled with a SignedData, as DER, or NULL.
#' @param sd The SignedData.
#' @param token The token's bytes.
#' @return The certificate's bytes, or NULL.
#' @noRd
.rmbl_ts_cert_der <- function(sd, token) {
  certs <- Filter(
    function(nd) {
      identical(nd$class, 2L) &&
        identical(nd$tag, 0) &&
        isTRUE(nd$constructed)
    },
    sd$children
  )
  if (!length(certs)) {
    return(NULL)
  }
  c1 <- certs[[1]]$children
  if (!length(c1)) {
    return(NULL)
  }
  st <- c1[[1]]$start
  token[(st + 1L):(c1[[1]]$offset + c1[[1]]$length)]
}

#' Pull out the pieces of a TimeStampResp or bare TimeStampToken.
#' @param der The parsed DER of the response or token.
#' @param token The token's bytes.
#' @return A list with the TSTInfo DER, policy, message imprint and its OID,
#'   serial, time, signer, certificate (or NULL), signature OID and the token.
#' @noRd
.rmbl_ts_extract <- function(der, token) {
  # Read by position, as RFC 3161 and RFC 5652 lay the token out. A search
  # for the first SignedData anywhere let a token wrapped in any outer
  # structure verify, and never read the authority's PKIStatus.
  ci <- .rmbl_ts_content_info(der)
  sd <- ci$children[[2]]$children[[1]] # [0] EXPLICIT SignedData
  k <- sd$children
  # SignedData: version, digestAlgorithms, encapContentInfo,
  # [0] certificates?, [1] crls?, signerInfos
  if (length(k) < 3L || !.rmbl_ts_seq_with_oid(
    k[[3L]], 1L, "1.2.840.113549.1.9.16.1.4"
  )) {
    stop("no TSTInfo content in the token", call. = FALSE)
  }
  .rmbl_ts_want(k[[1L]], 0L, 2, "SignedData version")
  .rmbl_ts_digest_algs(k[[2L]])
  e0 <- if (length(k[[3L]]$children) >= 2L) k[[3L]]$children[[2L]]
  oct <- if (length(e0$children)) e0$children[[1L]]
  if (is.null(oct)) {
    stop("the TSTInfo content is empty", call. = FALSE)
  }
  .rmbl_ts_want(e0, 2L, 0, "eContent [0]")
  .rmbl_ts_want(oct, 0L, 4, "eContent OCTET STRING")
  tst_der <- oct$value
  ti <- .rmbl_ts_tstinfo(.Call(C_rmbl_der_parse, tst_der))
  si <- if (length(k) >= 4L) k[[length(k)]]
  if (is.null(si) || !.rmbl_ts_is_signer_infos(si)) {
    stop("no SignerInfo in the token", call. = FALSE)
  }
  for (nd in k[-c(1:3, length(k))]) {
    if (!identical(nd$class, 2L) || !nd$tag %in% c(0, 1)) {
      stop("the SignedData has a field RFC 5652 does not define",
           call. = FALSE)
    }
  }
  signer <- si$children[[1]]
  .rmbl_ts_signer_algs(signer)
  list(
    tst_der = tst_der,
    policy = ti$policy,
    imprint_oid = ti$imprint_oid,
    imprint = ti$imprint,
    serial = ti$serial,
    time = ti$time,
    nonce = ti$nonce,
    signer = signer,
    cert_der = .rmbl_ts_cert_der(sd, token),
    sig_oid = .rmbl_ts_signer_sig_oid(signer),
    token = token
  )
}

#' A DER node of the class and tag expected, or an error naming it.
#' @param nd The node, or NULL.
#' @param class,tag The class (0 universal, 2 context-specific) and tag.
#' @param what What it is, for the error.
#' @return `nd`.
#' @noRd
.rmbl_ts_want <- function(nd, class, tag, what) {
  if (is.null(nd) || !identical(nd$class, class) ||
        !identical(nd$tag, tag)) {
    stop(sprintf("the token's %s is not where RFC 3161 puts it", what),
         call. = FALSE)
  }
  nd
}

#' The token's ContentInfo: the input itself, or the token inside a
#' TimeStampResp once its PKIStatus says the authority granted it.
#' @param der The parsed input.
#' @return The ContentInfo node.
#' @noRd
.rmbl_ts_content_info <- function(der) {
  k <- der$children
  # a TimeStampResp opens with PKIStatusInfo, a SEQUENCE; a ContentInfo
  # opens with its contentType OID
  if (identical(der$tag, 16) && length(k) &&
        identical(k[[1L]]$class, 0L) && identical(k[[1L]]$tag, 16)) {
    st <- k[[1L]]$children
    st <- if (length(st)) st[[1L]]
    if (is.null(st) || !identical(st$class, 0L) || !identical(st$tag, 2) ||
          !length(st$value) || length(st$value) > 3L) {
      stop("the authority's response has no PKIStatus", call. = FALSE)
    }
    status <- .rmbl_int_of(st$value)
    # granted (0) and grantedWithMods (1) carry a token; rejection (2),
    # waiting (3) and the revocation notices (4, 5) do not
    if (!status %in% c(0L, 1L)) {
      stop(sprintf("the authority did not grant the timestamp (PKIStatus %d)",
                   status), call. = FALSE)
    }
    if (length(k) != 2L) {
      stop("the authority's response carries no token", call. = FALSE)
    }
    der <- k[[2L]]
  }
  if (!.rmbl_ts_seq_with_oid(der, 2L, "1.2.840.113549.1.7.2") ||
        length(der$children) != 2L) {
    stop("no CMS SignedData at the top of the token", call. = FALSE)
  }
  sd <- der$children[[2L]]
  if (!identical(sd$class, 2L) || !identical(sd$tag, 0) ||
        length(sd$children) != 1L ||
        !identical(sd$children[[1L]]$tag, 16)) {
    stop("no CMS SignedData at the top of the token", call. = FALSE)
  }
  der
}

#' The SignedData's digestAlgorithms: a SET of AlgorithmIdentifiers.
#' @param nd The node.
#' @return NULL, invisibly; an error when malformed.
#' @noRd
.rmbl_ts_digest_algs <- function(nd) {
  .rmbl_ts_want(nd, 0L, 17, "digestAlgorithms")
  for (a in nd$children) {
    .rmbl_ts_alg(a, "digest algorithm")
  }
  invisible(NULL)
}

#' An AlgorithmIdentifier: an OID, then no parameters or a DER NULL (or,
#' for a signature, a parameter SEQUENCE such as RSASSA-PSS's).
#' @param nd The node.
#' @param what What it is, for the error.
#' @param params TRUE when a parameter SEQUENCE is allowed.
#' @return NULL, invisibly; an error when malformed.
#' @noRd
.rmbl_ts_alg <- function(nd, what, params = FALSE) {
  .rmbl_ts_want(nd, 0L, 16, what)
  k <- nd$children
  if (!length(k) || !identical(k[[1L]]$class, 0L) ||
        !identical(k[[1L]]$tag, 6)) {
    stop(sprintf("the token's %s has no algorithm OID", what), call. = FALSE)
  }
  p <- if (length(k) == 2L) k[[2L]]
  null <- !is.null(p) && identical(p$class, 0L) && identical(p$tag, 5) &&
    !length(p$value)
  pseq <- params && !is.null(p) && identical(p$class, 0L) &&
    identical(p$tag, 16)
  # the parameters sit outside the signed bytes: anything else there made
  # the token malleable
  if (length(k) > 2L || (!is.null(p) && !null && !pseq)) {
    stop(sprintf("the token's %s has parameters RFC 5754 does not allow",
                 what), call. = FALSE)
  }
  invisible(NULL)
}

#' The SignerInfo's fields, checked by position.
#'
#' SignerInfo: version, sid, digestAlgorithm, \[0\] signedAttrs?,
#' signatureAlgorithm, signature, \[1\] unsignedAttrs?.
#' @param signer The SignerInfo.
#' @return NULL, invisibly; an error when malformed.
#' @noRd
.rmbl_ts_signer_algs <- function(signer) {
  k <- signer$children
  .rmbl_ts_want(k[[1L]], 0L, 2, "SignerInfo version")
  .rmbl_ts_alg(k[[3L]], "SignerInfo digest algorithm")
  i <- 4L
  if (identical(k[[i]]$class, 2L) && identical(k[[i]]$tag, 0)) {
    i <- 5L
  }
  if (length(k) < i + 1L) {
    stop("the SignerInfo is incomplete", call. = FALSE)
  }
  .rmbl_ts_alg(k[[i]], "SignerInfo signature algorithm", params = TRUE)
  .rmbl_ts_want(k[[i + 1L]], 0L, 4, "signature")
  rest <- k[-seq_len(i + 1L)]
  if (length(rest) > 1L || (length(rest) == 1L &&
                              !(identical(rest[[1L]]$class, 2L) &&
                                  identical(rest[[1L]]$tag, 1)))) {
    stop("the SignerInfo has a field RFC 5652 does not define",
         call. = FALSE)
  }
  invisible(NULL)
}

#' Whether the SignerInfo's sid names the certificate checked against it.
#'
#' issuerAndSerialNumber must be the certificate's issuer (byte for byte)
#' and serial; a subjectKeyIdentifier must be its key identifier (the
#' extension, or the SHA-1 of the key when it has none, RFC 5280 4.2.1.2).
#' @param signer The SignerInfo.
#' @param cert The certificate's DER.
#' @param token The token's bytes.
#' @return NULL when it does; an error saying why not.
#' @noRd
.rmbl_ts_sid_check <- function(signer, cert, token) {
  sid <- signer$children[[2L]]
  tk <- .Call(C_rmbl_der_parse, cert)$children[[1L]]$children
  i <- if (identical(tk[[1L]]$class, 2L)) 2L else 1L
  span <- function(nd, raw) raw[(nd$start + 1L):(nd$offset + nd$length)]
  if (identical(sid$class, 0L) && identical(sid$tag, 16) &&
        length(sid$children) == 2L) {
    same <- identical(span(sid$children[[1L]], token),
                      span(tk[[i + 2L]], cert)) &&
      identical(sid$children[[2L]]$value, tk[[i]]$value)
    if (same) {
      return(NULL)
    }
    stop("the SignerInfo names another certificate (issuer and serial)",
         call. = FALSE)
  }
  if (identical(sid$class, 2L) && identical(sid$tag, 0) &&
        !isTRUE(sid$constructed)) {
    if (identical(sid$value, .rmbl_ts_cert_ski(tk, i))) {
      return(NULL)
    }
    stop("the SignerInfo names another certificate (key identifier)",
         call. = FALSE)
  }
  stop("the SignerInfo names its signer in a form RFC 5652 does not define",
       call. = FALSE)
}

#' A certificate's subject key identifier.
#' @param tk The tbsCertificate's children.
#' @param i The serial number's position among them.
#' @return The identifier's bytes.
#' @noRd
.rmbl_ts_cert_ski <- function(tk, i) {
  for (nd in tk) {
    if (!identical(nd$class, 2L) || !identical(nd$tag, 3) ||
          !length(nd$children)) {
      next
    }
    for (ext in nd$children[[1L]]$children) {
      e <- ext$children
      if (length(e) >= 2L && .rmbl_der_oid_eq(e[[1L]], "2.5.29.14")) {
        return(.Call(C_rmbl_der_parse, e[[length(e)]]$value)$value)
      }
    }
  }
  bits <- tk[[i + 5L]]$children[[2L]]$value
  .Call(C_rmbl_sha1, if (length(bits) > 1L) bits[-1L] else raw(0))
}

#' tsvrf()'s row on whether the SignerInfo names the certificate used.
#' @param info The token's contents.
#' @param .cert The certificate's DER bytes.
#' @param note_row The function that records the check.
#' @return NULL, invisibly.
#' @noRd
.rmbl_ts_sid_row <- function(info, .cert, note_row) {
  # the certificate may come as PEM; certprs() reads either form
  why <- tryCatch(
    .rmbl_ts_sid_check(info$signer, certprs(.cert)$der, info$token),
    error = function(e) conditionMessage(e)
  )
  note_row("signer_id", is.null(why),
           why %||% "the SignerInfo names this certificate")
  invisible(NULL)
}

#' tsvrf()'s row on the nonce, when the request's nonce is known.
#' @param info The token's contents.
#' @param nonce The nonce sent, or NULL.
#' @param note_row The function that records the check.
#' @return NULL, invisibly.
#' @noRd
.rmbl_ts_nonce_row <- function(info, nonce, note_row) {
  if (is.null(nonce)) {
    return(invisible(NULL))
  }
  strip <- function(b) {
    nz <- which(b != as.raw(0L))
    if (length(nz)) b[nz[1L]:length(b)] else raw(0)
  }
  got <- info$nonce
  same <- !is.null(got) && identical(strip(got), strip(nonce))
  note_row("nonce", same, if (same) {
    "the token answers this request's nonce"
  } else if (is.null(got)) {
    "the token carries no nonce, so it may answer another request"
  } else {
    "the token's nonce is another request's"
  })
  invisible(NULL)
}

#' The fields of a TSTInfo that tsvrf() reports.
#' @param tst The parsed TSTInfo.
#' @return A list: policy, imprint_oid, imprint, serial and time.
#' @noRd
.rmbl_ts_tstinfo <- function(tst) {
  # TSTInfo: version, policy, messageImprint, serialNumber, genTime, ...
  k <- tst$children
  imprint_seq <- k[[3]]
  # accuracy?, ordering?, nonce?, tsa?, extensions? follow genTime; the
  # nonce is the only universal INTEGER among them
  ints <- Filter(
    function(nd) identical(nd$class, 0L) && identical(nd$tag, 2),
    k[-seq_len(min(5L, length(k)))]
  )
  list(
    nonce = if (length(ints)) ints[[1L]]$value,
    policy = .rmbl_oid_string(k[[2]]$value),
    imprint_oid = .rmbl_oid_string(
      imprint_seq$children[[1]]$children[[1]]$value
    ),
    imprint = imprint_seq$children[[2]]$value,
    serial = .rmbl_hexlify(k[[4]]$value),
    time = .rmbl_ts_gentime(rawToChar(k[[5]]$value))
  )
}

#' GeneralizedTime: YYYYMMDDHHMMSS\[.fff\]Z
#' @param s A GeneralizedTime string.
#' @return A POSIXct time in UTC.
#' @noRd
.rmbl_ts_gentime <- function(s) {
  s <- sub("Z$", "", s)
  frac <- 0
  if (grepl(".", s, fixed = TRUE)) {
    frac <- as.numeric(paste0("0.", sub(".*[.]", "", s)))
    s <- sub("[.].*", "", s)
  }
  t <- as.POSIXct(strptime(s, "%Y%m%d%H%M%S", tz = "UTC"), tz = "UTC")
  t + frac
}

#' Reads the signature algorithm's OID from a SignerInfo.
#' @param signer The SignerInfo node.
#' @return The dotted OID, or NA when it is not there.
#' @noRd
.rmbl_ts_signer_sig_oid <- function(signer) {
  # SignerInfo: version, sid, digestAlgorithm, [0] signedAttrs,
  # signatureAlgorithm, signature
  algs <- Filter(
    function(nd) {
      isTRUE(nd$constructed) &&
        identical(nd$tag, 16) &&
        length(nd$children) >= 1L &&
        identical(nd$children[[1]]$tag, 6)
    },
    signer$children
  )
  if (length(algs) < 2L) {
    return(NA_character_)
  }
  .rmbl_oid_string(algs[[length(algs)]]$children[[1]]$value)
}

#' Verifies a token's RSA or ECDSA signature over its signed attributes, and its
#' messageDigest attribute.
#' @param info The token's pieces from `.rmbl_ts_extract()`.
#' @param cert The signer's certificate in DER.
#' @return A list with `ok`, `detail`, `content_ok` and
#'   `content_detail`.
#' @noRd
.rmbl_ts_verify_sig <- function(info, cert) {
  signer <- info$signer
  sb <- .rmbl_ts_signed_attrs(info)
  ct <- .rmbl_ts_content(sb$sa, signer, info)
  sig <- .rmbl_ts_signature(signer)
  parsed <- tryCatch(certprs(cert), error = function(e) NULL)
  if (is.null(parsed)) {
    stop("the certificate could not be parsed", call. = FALSE)
  }
  key <- parsed$key
  r <- if (identical(key$type, "RSA")) {
    .rmbl_ts_rsa_verify(key, sig, ct$dalg, sb$signed_bytes)
  } else if (identical(key$type, "EC") && !is.null(key$x)) {
    .rmbl_ts_ec_verify(key, sig, ct$dalg, sb$signed_bytes)
  } else {
    stop(
      "the certificate carries a ",
      key$type,
      " key; RSA and ECDSA over ",
      "the NIST prime curves are verified here, and anything else is ",
      "reported as unverifiable rather than accepted",
      call. = FALSE
    )
  }
  list(
    ok = r$ok,
    detail = r$detail,
    content_ok = ct$ok,
    content_detail = ct$detail
  )
}

#' A SignerInfo's signed attributes, and the bytes its signature is over.
#' @param info The token's pieces from `.rmbl_ts_extract()`.
#' @return A list: `sa` (the attributes' node) and `signed_bytes`.
#' @noRd
.rmbl_ts_signed_attrs <- function(info) {
  signer <- info$signer
  # signedAttrs is [0] IMPLICIT; the bytes that are SIGNED are the same
  # contents re-tagged as a SET, which is the one step in CMS that a
  # verifier gets wrong and then reports a valid signature as invalid.
  sa <- Filter(
    function(nd) {
      identical(nd$class, 2L) &&
        identical(nd$tag, 0) &&
        isTRUE(nd$constructed)
    },
    signer$children
  )
  if (!length(sa)) {
    stop(
      "this token has no signed attributes; only that form is ",
      "supported here",
      call. = FALSE
    )
  }
  sa <- sa[[1]]
  body <- info$token[(sa$offset + 1L):(sa$offset + sa$length)]
  signed_bytes <- c(as.raw(0x31), .rmbl_der_length(length(body)), body)
  list(sa = sa, signed_bytes = signed_bytes)
}

#' Whether a token's messageDigest attribute is the digest of its TSTInfo.
#' @param sa The signed attributes' node.
#' @param signer The SignerInfo node.
#' @param info The token's pieces from `.rmbl_ts_extract()`.
#' @return A list: `ok`, `detail` and `dalg` (the signer's digest algorithm).
#' @noRd
.rmbl_ts_content <- function(sa, signer, info) {
  # messageDigest attribute: must equal the digest of the TSTInfo
  # read among the attributes themselves: a search inside them found a
  # messageDigest nested in another attribute's value
  md <- .rmbl_ts_attr(sa, "1.2.840.113549.1.9.4")
  ctype <- .rmbl_ts_attr(sa, "1.2.840.113549.1.9.3")
  content_ok <- FALSE
  content_detail <- "no messageDigest attribute"
  dalg <- .rmbl_ts_signer_digest(signer)
  if (!is.null(md) && (is.null(ctype) || !.rmbl_der_oid_eq(
    ctype, "1.2.840.113549.1.9.16.1.4"
  ))) {
    content_detail <- "the signed contentType attribute is not TSTInfo"
  } else if (!is.null(md) && identical(md$tag, 4) && !is.na(dalg)) {
    want <- md$value
    got <- .rmbl_ts_digest(dalg, info$tst_der)
    content_ok <- identical(want, got)
    content_detail <- if (content_ok) {
      sprintf("the signed attributes commit to the TSTInfo (%s)", dalg)
    } else {
      sprintf(
        "attribute says %s, the TSTInfo digests to %s",
        .rmbl_hexlify(want),
        .rmbl_hexlify(got)
      )
    }
  }
  list(ok = content_ok, detail = content_detail, dalg = dalg)
}

#' The one value of a signed attribute, or NULL when it is absent, appears
#' twice, or holds other than one value.
#' @param sa The signed attributes' node.
#' @param oid The attribute's OID.
#' @return The value's node, or NULL.
#' @noRd
.rmbl_ts_attr <- function(sa, oid) {
  hits <- Filter(function(nd) .rmbl_ts_seq_with_oid(nd, 2L, oid),
                 sa$children)
  if (length(hits) != 1L || length(hits[[1L]]$children) != 2L) {
    return(NULL)
  }
  v <- hits[[1L]]$children[[2L]]
  if (!identical(v$tag, 17) || length(v$children) != 1L) {
    return(NULL)
  }
  v$children[[1L]]
}

#' Verifies an RSA (PKCS #1 v1.5) signature over the signed attributes.
#' @param key The certificate's key.
#' @param sig The signature's bytes.
#' @param dalg The digest algorithm the PKCS #1 v1.5 encoding must name.
#' @param signed_bytes The bytes signed.
#' @return A list: `ok` and `detail`.
#' @noRd
.rmbl_ts_rsa_verify <- function(key, sig, dalg, signed_bytes) {
  # a signature of the wrong length (or otherwise not one) is not
  # verified, as for ECDSA below, rather than an error
  em <- tryCatch(
    .Call(C_rmbl_rsa_recover, sig, key$modulus, key$exponent),
    error = function(e) e
  )
  if (inherits(em, "error")) {
    return(list(
      ok = FALSE,
      detail = conditionMessage(em)
    ))
  }
  ok <- .rmbl_pkcs1_check(em, dalg, signed_bytes)
  list(
    ok = ok$ok,
    detail = ok$detail
  )
}

#' Verifies an ECDSA signature over the signed attributes.
#' @param key The certificate's key.
#' @param sig The signature's bytes.
#' @param dalg The digest algorithm applied to the signed bytes for ECDSA.
#' @param signed_bytes The bytes signed.
#' @return A list: `ok` and `detail`.
#' @noRd
.rmbl_ts_ec_verify <- function(key, sig, dalg, signed_bytes) {
  rs <- .rmbl_ecdsa_rs(sig)
  if (is.null(rs)) {
    return(list(
      ok = FALSE,
      detail = "the ECDSA signature is malformed"
    ))
  }
  dig <- .rmbl_ts_digest(dalg, signed_bytes)
  v <- tryCatch(
    .Call(
      C_rmbl_ecdsa_verify,
      key$curve,
      key$x,
      key$y,
      rs$r,
      rs$s,
      dig
    ),
    error = function(e) FALSE
  )
  list(
    ok = isTRUE(v),
    detail = sprintf("ECDSA over %s on %s", dalg, key$curve)
  )
}

#' Names the digest algorithm a SignerInfo declares.
#' @param signer The SignerInfo node.
#' @return The digest's name, or NA.
#' @noRd
.rmbl_ts_signer_digest <- function(signer) {
  algs <- Filter(
    function(nd) {
      isTRUE(nd$constructed) &&
        identical(nd$tag, 16) &&
        length(nd$children) >= 1L &&
        identical(nd$children[[1]]$tag, 6)
    },
    signer$children
  )
  if (!length(algs)) {
    return(NA_character_)
  }
  .rmbl_ts_digest_name(.rmbl_oid_string(algs[[1]]$children[[1]]$value))
}

#' Returns the signature bytes of a SignerInfo.
#' @param signer The SignerInfo node.
#' @return A raw vector.
#' @noRd
.rmbl_ts_signature <- function(signer) {
  octs <- Filter(
    function(nd) {
      identical(nd$class, 0L) &&
        identical(nd$tag, 4)
    },
    signer$children
  )
  if (!length(octs)) {
    stop("no signature in the SignerInfo", call. = FALSE)
  }
  octs[[length(octs)]]$value
}

#' The DER length octets for a given length.
#' @param n The length.
#' @return A raw vector.
#' @noRd
.rmbl_der_length <- function(n) {
  if (n < 128L) {
    return(as.raw(n))
  }
  bytes <- raw(0)
  v <- n
  while (v > 0) {
    bytes <- c(as.raw(v %% 256L), bytes)
    v <- v %/% 256L
  }
  c(as.raw(0x80 + length(bytes)), bytes)
}

#' Checks an EMSA-PKCS1-v1_5 encoded block against the digest of a message.
#'
#' EMSA-PKCS1-v1_5: 0x00 0x01 0xff...0xff 0x00 DigestInfo.
#' @param em The encoded block recovered from the signature.
#' @param alg The digest's name, or NA when it is not supported.
#' @param message The signed bytes.
#' @return A list with `ok` and `detail`.
#' @noRd
.rmbl_pkcs1_check <- function(em, alg, message) {
  if (is.na(alg)) {
    return(list(ok = FALSE, detail = "unsupported signature digest"))
  }
  if (length(em) < 11L || em[1] != as.raw(0x00) || em[2] != as.raw(0x01)) {
    return(list(ok = FALSE, detail = "the padding is not PKCS#1 v1.5"))
  }
  i <- 3L
  while (i <= length(em) && em[i] == as.raw(0xff)) {
    i <- i + 1L
  }
  if (i > length(em) || em[i] != as.raw(0x00) || i < 11L) {
    return(list(
      ok = FALSE,
      detail = "the padding has no separator, or too little of it"
    ))
  }
  di <- em[(i + 1L):length(em)]
  want_digest <- .rmbl_ts_digest(alg, message)
  # RFC 8017 section 9.2 fixes DigestInfo to one DER encoding per hash
  # (note 1 lists the bytes). The recovered block must be exactly that
  # prefix followed by the digest: comparing bytes, rather than parsing
  # and comparing fields, leaves no room for a forged block whose fields
  # read right -- the Bleichenbacher 2006 e = 3 attack lived in that room.
  # The AlgorithmIdentifier's NULL parameters are required (RFC 4055).
  prefix <- .rmbl_pkcs1_prefix(alg)
  if (is.null(prefix) || !identical(di, c(prefix, want_digest))) {
    return(list(
      ok = FALSE,
      detail = sprintf(
        "the recovered block is not DigestInfo(%s) of the signed bytes",
        alg
      )
    ))
  }
  list(
    ok = TRUE,
    detail = sprintf("RSA over %s of the signed attributes", alg)
  )
}

#' The DER DigestInfo prefixes of RFC 8017 section 9.2, note 1.
#' @param alg The digest's name.
#' @return The prefix as a raw vector, or NULL for another digest.
#' @noRd
.rmbl_pkcs1_prefix <- function(alg) {
  hex <- switch(
    alg,
    sha1 = "3021300906052b0e03021a05000414",
    sha256 = "3031300d060960864801650304020105000420",
    sha384 = "3041300d060960864801650304020205000430",
    sha512 = "3051300d060960864801650304020305000440",
    NULL
  )
  if (is.null(hex)) NULL else .rmbl_hex_to_raw(hex)
}
