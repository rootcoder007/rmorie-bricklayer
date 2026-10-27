# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Fetching revocation data.
#
# Everything here is opt-in, and that is a design decision rather than
# caution. A verifier that reaches out during a check:
#
#   * stops working offline, which is exactly where an archival capsule
#     is most likely to be verified;
#   * becomes non-deterministic, so the same inputs can give different
#     answers on different days;
#   * tells whoever runs the responder which certificates are being
#     checked, and when. For a capsule that is a disclosure about what
#     someone is auditing.
#
# So `revocation = "fetch"` has to be asked for, and what it does is
# reported check by check rather than folded into one verdict.

#' Fetch revocation data for a certificate path
#'
#' @description
#' Checks over the network whether any certificate in a chain has been
#' revoked by its issuer. It downloads the certificate revocation lists
#' (CRLs) that the certificates point to, and asks each OCSP responder they
#' name about the certificate. It is called by
#' [certchnvrf()] when
#' `revocation = "fetch"`; you would call it directly only to inspect the
#' raw revocation data. Nothing in the package does this unless asked,
#' because a verifier that goes online stops working offline, can give
#' different answers on different days, and tells the responder which
#' certificates are being checked.
#'
#' @details
#' For each certificate, every http(s) URL in its CRL distribution points
#' extension (2.5.29.31) is fetched; a PEM CRL is converted to DER. For each
#' certificate except the last (which has no issuer in the path), every OCSP
#' URL in its authority information access extension is asked about it. The
#' OCSP request is sent by POST first, which RFC 6960 requires responders to
#' accept, and if that gets no answer, by GET with the DER request
#' base64-encoded into the URL, as RFC 6960 appendix A.1.1 allows. A
#' responder that answers neither is reported as unreachable rather than
#' treated as a pass.
#'
#' A responder's answer is only believed when its signature verifies under
#' a certificate in the path or one it carries that the path issued. An
#' unsigned or unverifiable answer is reported as such -- treating it as
#' \code{"good"} would make revocation checking worse than skipping it, since it
#' would look like it had happened.
#'
#' The fetched CRLs are returned, not checked:
#' [certchnvrf()] checks
#' the certificates against them. Network: plain http is allowed here,
#' because CRLs and OCSP answers are signed and RFC 5280 and RFC 6960
#' distribute them over http, but URLs that point at local or private
#' addresses are refused (and reported as not retrieved). A certificate with
#' no CRL or OCSP URL produces no request at all.
#'
#' Errors: `path` not a non-empty list of parsed certificates (each a list
#' with a raw `der` element); `tmout` not positive. Network failures are
#' not errors; they are reported in `ok` and `notes`.
#'
#' @param path A certificate path, leaf first, as
#' [certchnvrf()] builds it.
#' @param tmout Number, default 10: seconds to allow each request.
#' @return A list with `crls` (a list of raw DER vectors fetched), `ok` (a
#' logical vector, one element per CRL fetch or OCSP query, `TRUE` for a
#' success) and `notes` (a named list of character details, named like
#' `"crl fetch [1]"` or `"ocsp [1]"` by the certificate's position in
#' the
#' path; a later attempt for the same certificate overwrites an earlier
#' note of the same name).
#' @seealso
#' [certchnvrf()],
#' [tsvrf()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Offline: a path entry that names no CRL or OCSP URL (here, bytes that
#' # are not a certificate at all) makes no request and returns empty results.
#' str(rvkfetch(list(list(der = as.raw(1:3)))))
#'
#' # the input checks
#' try(rvkfetch(list()))
#' try(rvkfetch(list(list(der = as.raw(1:3))), tmout = 0))
#'
#' # Reaches the network, so it is not run here.
#'
#' @examplesIf interactive()
#' res <- certchnvrf("leaf.crt", trust = "ca.crt",
#'                          rvk = "fetch")
#' res$checks
#' @export
rvkfetch <- function(path, tmout = 10) {
  if (
    !is.list(path) ||
      !length(path) ||
      !all(vapply(path, function(p) is.list(p) && is.raw(p$der), logical(1)))
  ) {
    stop(
      "`path` must be a non-empty list of parsed certificates (certprs())",
      call. = FALSE
    )
  }
  tmout <- .rmbl_num(tmout, "tmout")[1L]
  if (is.na(tmout) || tmout <= 0) {
    stop("`tmout` must be positive", call. = FALSE)
  }
  .rmbl_revocation_fetch(path, tmout)
}

#' Fetches the CRLs and asks the OCSP responders named in a certificate path.
#' @param path The certificate path, leaf first, as parsed by certprs().
#' @param timeout The network timeout in seconds.
#' @return A list with the fetched `crls`, an `ok` flag per check and the
#'   `notes`.
#' @noRd
.rmbl_revocation_fetch <- function(path, timeout = 10) {
  crls <- list()
  acc <- new.env(parent = emptyenv())
  acc$notes <- list()
  acc$ok <- logical(0)
  add <- function(name, good, detail) {
    # one certificate can carry several CRL or OCSP URLs: number repeats so none
    # is overwritten
    if (!is.null(acc$notes[[name]])) {
      name <- sprintf(
        "%s #%d",
        name,
        sum(startsWith(names(acc$notes), name)) + 1L
      )
    }
    acc$notes[[name]] <- detail
    acc$ok <- c(acc$ok, isTRUE(good))
  }
  for (i in seq_along(path)) {
    cert <- path[[i]]
    for (url in .rmbl_crl_urls(cert)) {
      got <- .rmbl_http_der(url, timeout)
      if (is.null(got)) {
        add(
          sprintf("crl fetch [%d]", i),
          FALSE,
          sprintf("could not retrieve %s", url)
        )
      } else {
        crls[[length(crls) + 1L]] <- got
        add(
          sprintf("crl fetch [%d]", i),
          TRUE,
          sprintf("%d bytes from %s", length(got), url)
        )
      }
    }
    # OCSP needs the issuer, so the last certificate in the path has
    # nobody to ask about it
    if (i >= length(path)) {
      next
    }
    issuer <- path[[i + 1L]]
    for (url in .rmbl_ocsp_urls(cert)) {
      res <- .rmbl_ocsp_query(cert, issuer, url, path, timeout)
      add(sprintf("ocsp [%d]", i), res$ok, res$detail)
    }
  }
  list(crls = crls, ok = acc$ok, notes = acc$notes)
}

#' cRLDistributionPoints (2.5.29.31): the http URLs in it.
#' @param cert A parsed certificate.
#' @return The http(s) CRL URLs.
#' @noRd
.rmbl_crl_urls <- function(cert) {
  .rmbl_ext_urls(cert, "2.5.29.31", NULL)
}

#' authorityInfoAccess (1.3.6.1.5.5.7.1.1), the entries whose method is
#' id-ad-ocsp (1.3.6.1.5.5.7.48.1).
#' @param cert A parsed certificate.
#' @return The http(s) OCSP URLs.
#' @noRd
.rmbl_ocsp_urls <- function(cert) {
  .rmbl_ext_urls(cert, "1.3.6.1.5.5.7.1.1", "1.3.6.1.5.5.7.48.1")
}

#' Reads the http(s) URLs out of a certificate extension.
#' @param cert A parsed certificate.
#' @param oid The extension's OID.
#' @param method The access method OID the URLs must sit under, or NULL for any.
#' @return A character vector of URLs.
#' @noRd
.rmbl_ext_urls <- function(cert, oid, method) {
  der <- cert$der
  top <- tryCatch(.Call(C_rmbl_der_parse, der), error = function(e) NULL)
  if (is.null(top) || !length(top$children)) {
    return(character(0))
  }
  k <- top$children[[1]]$children
  ext <- NULL
  for (nd in k) {
    if (identical(nd$class, 2L) && identical(nd$tag, 3)) ext <- nd
  }
  if (is.null(ext) || !length(ext$children)) {
    return(character(0))
  }
  urls <- character(0)
  for (e in ext$children[[1]]$children) {
    if (length(e$children) < 2L) {
      next
    }
    if (!identical(.rmbl_oid_string(e$children[[1]]$value), oid)) {
      next
    }
    inner <- tryCatch(
      .Call(C_rmbl_der_parse, e$children[[length(e$children)]]$value),
      error = function(z) NULL
    )
    if (is.null(inner)) {
      next
    }
    urls <- c(urls, .rmbl_collect_uris(inner, method))
  }
  # only http; a verifier that followed ldap or file URLs from a
  # certificate would be following instructions from the thing it is
  # checking
  grep("^https?://", urls, value = TRUE)
}

#' Collects the IA5String URIs in a parsed DER structure.
#'
#' Walk a structure collecting \[6\] IA5String URIs. When `method` is
#' given, only from SEQUENCEs whose first element is that OID.
#' @param nd A parsed DER node.
#' @param method The OID a URI's SEQUENCE must start with, or NULL.
#' @return A character vector of URIs.
#' @noRd
.rmbl_collect_uris <- function(nd, method = NULL) {
  if (!is.null(method) && .rmbl_is_access_for(nd, method)) {
    tail <- nd$children[[2]]
    if (identical(tail$class, 2L) && identical(tail$tag, 6)) {
      return(.rmbl_raw_text(tail$value))
    }
  }
  if (
    identical(nd$class, 2L) &&
      identical(nd$tag, 6) &&
      !isTRUE(nd$constructed) &&
      is.null(method)
  ) {
    return(.rmbl_raw_text(nd$value))
  }
  out <- character(0)
  for (kid in nd$children) {
    out <- c(out, .rmbl_collect_uris(kid, method))
  }
  out
}

#' Whether a node is an AccessDescription for the access method `method`: a
#' SEQUENCE whose first element is that OID.
#' @param nd The parsed DER node to test for an AccessDescription.
#' @param method The access method's OID.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_is_access_for <- function(nd, method) {
  isTRUE(nd$constructed) &&
    length(nd$children) >= 2L &&
    identical(nd$children[[1]]$tag, 6) &&
    identical(.rmbl_oid_string(nd$children[[1]]$value), method)
}

#' Fetches a URL as raw DER bytes.
#'
#' A GET that returns the body as raw bytes, through the package's own
#' fetch so there is one place where the network is touched.
#' @param url The URL, taken from the certificate.
#' @param timeout The network timeout in seconds.
#' @return The body as raw DER (a PEM body is decoded), or NULL.
#' @noRd
.rmbl_http_der <- function(url, timeout = 10) {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  # The fallback URL goes in a variable rather than inline. R's own
  # checkFF, which walks .Call arguments during R CMD check, does
  # `as.character()` on each one and tests the result against "..." --
  # a literal NA_character_ makes that comparison NA and the check
  # errors out, which surfaces as a NOTE about foreign function calls
  # that says nothing about the call being wrong.
  no_fallback <- NA_character_
  # the URL comes out of the certificate being verified -- the most
  # attacker-controlled URL in the package. Plain http is what RFC 6960
  # and RFC 5280 use for OCSP and CRL distribution (the answers are
  # signed, so the transport adds nothing); the private-address and
  # local-name refusals still apply.
  if (
    is.null(tryCatch(
      .rmbl_check_public_url(url, "the CRL/OCSP URL", allow_http = TRUE),
      error = function(e) NULL
    ))
  ) {
    return(NULL)
  }
  got <- .rmbl_net_get_file(url, no_fallback, tmp, timeout)
  if (is.null(got) || !file.exists(tmp) || file.size(tmp) == 0) {
    return(NULL)
  }
  b <- readBin(tmp, "raw", file.size(tmp))
  # a PEM CRL is as likely as a DER one
  txt <- tryCatch(
    rawToChar(b[seq_len(min(64L, length(b)))]),
    error = function(e) ""
  )
  if (grepl("-----BEGIN", txt, fixed = TRUE)) {
    all_txt <- rawToChar(b)
    body <- sub(".*-----BEGIN[^-]*-----", "", all_txt)
    body <- sub("-----END.*", "", body)
    body <- gsub("[\r\n[:space:]]", "", body)
    return(tryCatch(jsb64dec(body), error = function(e) NULL))
  }
  b
}

# The two network calls, each one line, so the protocol logic above and
# below can be exercised against recorded answers.
#' Downloads a URL to a file.
#' @param url The CRL or certificate URL to download.
#' @param fallback A fallback URL, or NA for none.
#' @param tmp The file to write.
#' @param timeout The network timeout in seconds.
#' @return The fetch result, or NULL on error.
#' @noRd
.rmbl_net_get_file <- function(url, fallback, tmp, timeout) {
  tryCatch(
    .bl_net(
      url,
      .Call(C_rmbl_fetch_fallback, url, fallback, tmp, as.integer(timeout), "")
    ),
    error = function(e) NULL
  )
}

#' Posts a body to a URL.
#' @param url The OCSP responder URL the request is posted to.
#' @param body The raw request body.
#' @param content_type The request's Content-Type.
#' @param timeout The network timeout in seconds.
#' @return The response, with its `status` and `body`, or NULL on error.
#' @noRd
.rmbl_net_post <- function(url, body, content_type, timeout) {
  tryCatch(
    .bl_net(
      url,
      .Call(
        C_rmbl_http_post,
        url,
        body,
        content_type,
        as.integer(timeout),
        NULL,
        FALSE
      )
    ),
    error = function(e) NULL
  )
}

# ---------------------------------------------------------------- #
# OCSP (RFC 6960)
# ---------------------------------------------------------------- #

# Minimal DER encoding. Only what an OCSP request needs, because a
# general encoder is a great deal of surface for one message shape.
#' Encodes one DER tag-length-value.
#' @param tag The DER tag byte of the element encoded.
#' @param body The raw contents.
#' @return The encoding as raw bytes.
#' @noRd
.rmbl_der_tlv <- function(tag, body) {
  c(as.raw(tag), .rmbl_der_length(length(body)), body)
}

#' Encodes a DER SEQUENCE of already encoded elements.
#' @param ... The encoded elements, as raw vectors.
#' @return The encoding as raw bytes.
#' @noRd
.rmbl_der_seq <- function(...) {
  .rmbl_der_tlv(0x30, c(...))
}

#' Encodes a dotted object identifier as a DER OBJECT IDENTIFIER.
#' @param dotted The OID, such as \code{"1.3.14.3.2.26"}.
#' @return The encoding as raw bytes.
#' @noRd
.rmbl_der_oid_bytes <- function(dotted) {
  parts <- as.integer(strsplit(dotted, ".", fixed = TRUE)[[1]])
  first <- as.raw(40L * parts[1] + parts[2])
  rest <- raw(0)
  for (v in parts[-(1:2)]) {
    if (v == 0L) {
      rest <- c(rest, as.raw(0))
      next
    }
    chunks <- integer(0)
    x <- v
    while (x > 0L) {
      chunks <- c(x %% 128L, chunks)
      x <- x %/% 128L
    }
    for (i in seq_along(chunks)) {
      b <- chunks[i]
      if (i < length(chunks)) {
        b <- b + 128L
      }
      rest <- c(rest, as.raw(b))
    }
  }
  .rmbl_der_tlv(0x06, c(first, rest))
}

#' Builds the DER CertID of a certificate.
#'
#' The issuer name and key as the CertID wants them: the SHA-1 of the
#' issuer's encoded Name, and of the BIT STRING contents of its public
#' key. SHA-1 is what RFC 6960 specifies for CertID and what responders
#' key on; it is not verifying anything here.
#' @param cert The parsed certificate asked about.
#' @param issuer Its parsed issuer certificate.
#' @return The CertID as raw DER.
#' @noRd
.rmbl_ocsp_certid <- function(cert, issuer) {
  top <- .Call(C_rmbl_der_parse, cert$der)
  k <- top$children[[1]]$children
  off <- if (
    length(k) && identical(k[[1]]$class, 2L) && identical(k[[1]]$tag, 0)
  ) {
    1L
  } else {
    0L
  }
  iss <- k[[off + 3L]]
  issuer_der <- cert$der[(iss$start + 1L):(iss$offset + iss$length)]

  itop <- .Call(C_rmbl_der_parse, issuer$der)
  ik <- itop$children[[1]]$children
  ioff <- if (
    length(ik) && identical(ik[[1]]$class, 2L) && identical(ik[[1]]$tag, 0)
  ) {
    1L
  } else {
    0L
  }
  spki <- ik[[ioff + 6L]]
  bits <- spki$children[[2]]$value
  keybytes <- if (length(bits) > 1L) bits[-1] else raw(0)

  serial_raw <- .rmbl_hex_to_raw(cert$serial)
  # INTEGER: a leading zero when the top bit is set, or the value reads
  # as negative
  if (length(serial_raw) && as.integer(serial_raw[1]) >= 128L) {
    serial_raw <- c(as.raw(0), serial_raw)
  }
  .rmbl_der_seq(
    .rmbl_der_seq(
      .rmbl_der_oid_bytes("1.3.14.3.2.26"),
      .rmbl_der_tlv(0x05, raw(0))
    ),
    .rmbl_der_tlv(0x04, .Call(C_rmbl_sha1, issuer_der)),
    .rmbl_der_tlv(0x04, .Call(C_rmbl_sha1, keybytes)),
    .rmbl_der_tlv(0x02, serial_raw)
  )
}

#' Builds a DER OCSP request for one certificate.
#' @param cert The parsed certificate asked about.
#' @param issuer Its parsed issuer certificate.
#' @return The OCSPRequest as raw DER.
#' @noRd
.rmbl_ocsp_request <- function(cert, issuer) {
  req <- .rmbl_der_seq(.rmbl_der_seq(.rmbl_der_seq(
    .rmbl_ocsp_certid(cert, issuer)
  )))
  .rmbl_der_seq(req)
}

#' Asks an OCSP responder about a certificate, by POST then GET.
#' @param cert The parsed certificate asked about.
#' @param issuer Its parsed issuer certificate.
#' @param url The responder's URL.
#' @param path The certificate path, whose certificates may sign the answer.
#' @param timeout The network timeout in seconds.
#' @return A list with `ok` and a `detail` sentence.
#' @noRd
.rmbl_ocsp_query <- function(cert, issuer, url, path, timeout = 10) {
  req <- tryCatch(.rmbl_ocsp_request(cert, issuer), error = function(e) NULL)
  if (is.null(req)) {
    return(list(ok = FALSE, detail = "could not build an OCSP request"))
  }
  # POST first, which is what RFC 6960 requires a responder to accept,
  # then fall back to the optional GET form. The other way round fails
  # against most responders, which refuse GET.
  body <- NULL
  res <- .rmbl_net_post(url, req, "application/ocsp-request", timeout)
  if (!is.null(res) && identical(res$status, 200L) && length(res$body) > 0L) {
    body <- res$body
  }
  if (is.null(body)) {
    b64 <- jsb64enc(req)
    full <- sprintf("%s/%s", sub("/+$", "", url), .rmbl_url_encode(b64))
    body <- .rmbl_http_der(full, timeout)
  }
  if (is.null(body)) {
    return(list(
      ok = FALSE,
      detail = sprintf("no answer from %s over POST or GET", url)
    ))
  }
  .rmbl_ocsp_parse(body, cert, path)
}

#' Percent-encodes every character outside the unreserved set of RFC 3986.
#' @param x One string.
#' @return The encoded string.
#' @noRd
.rmbl_url_encode <- function(x) {
  chars <- strsplit(x, "", fixed = TRUE)[[1]]
  out <- vapply(
    chars,
    function(ch) {
      if (grepl("[A-Za-z0-9._~-]", ch)) {
        return(ch)
      }
      sprintf("%%%02X", as.integer(charToRaw(ch)))
    },
    character(1)
  )
  paste(out, collapse = "")
}

#' Reads an OCSP answer and checks its signature.
#'
#' OCSPResponse ::= SEQUENCE { responseStatus ENUMERATED,
#'                             responseBytes \[0\] EXPLICIT OPTIONAL }
#' The status is what says whether there is an answer at all; the answer
#' is a BasicOCSPResponse whose tbsResponseData carries one
#' SingleResponse per certificate asked about.
#' @param body The answer as raw DER.
#' @param cert The parsed certificate asked about.
#' @param path The certificate path, whose certificates may sign the answer.
#' @return A list with `ok` (TRUE only for a signed \code{"good"}) and a
#'   `detail` sentence.
#' @noRd
.rmbl_ocsp_parse <- function(body, cert, path) {
  d <- tryCatch(.Call(C_rmbl_der_parse, body), error = function(e) NULL)
  if (is.null(d) || !length(d$children)) {
    return(list(ok = FALSE, detail = "the OCSP answer is not DER"))
  }
  status <- .rmbl_int_of(d$children[[1]]$value)
  if (!identical(status, 0L)) {
    return(list(
      ok = FALSE,
      detail = sprintf(
        "the responder answered '%s'",
        .rmbl_ocsp_status_name(status)
      )
    ))
  }
  b <- .rmbl_ocsp_basic(d)
  if (is.character(b)) {
    return(list(ok = FALSE, detail = b))
  }
  state <- .rmbl_ocsp_state(b$basic$children[[1]])
  if (is.null(state)) {
    return(list(ok = FALSE, detail = "no SingleResponse in the answer"))
  }
  # The answer is only worth anything if it is signed by someone the
  # path vouches for. An unverified "good" is worse than no check: it
  # looks like one happened.
  sig_ok <- .rmbl_ocsp_verify_sig(b$basic, path, b$src)
  if (!sig_ok$ok) {
    return(list(
      ok = FALSE,
      detail = sprintf("the responder said '%s' but %s", state, sig_ok$detail)
    ))
  }
  if (identical(state, "good")) {
    return(list(ok = TRUE, detail = "the responder says good, signed"))
  }
  list(ok = FALSE, detail = sprintf("the responder says %s, signed", state))
}

#' The name of an OCSPResponseStatus that is not "successful".
#' @param status The status number.
#' @return The name (the number when it is not one RFC 6960 names).
#' @noRd
.rmbl_ocsp_status_name <- function(status) {
  labels <- c(
    "malformedRequest",
    "internalError",
    "tryLater",
    "",
    "sigRequired",
    "unauthorized"
  )
  if (status >= 1L && status <= 6L) labels[status] else as.character(status)
}

#' The BasicOCSPResponse of an OCSP answer.
#'
#' responseBytes ::= \[0\] EXPLICIT SEQUENCE { responseType OID, response OCTET
#' STRING }. The BasicOCSPResponse is the CONTENTS of that octet string, which
#' is a DER document of its own -- the outer parse stops at the string, so it
#' has to be parsed again. Walking the outer tree looking for it finds nothing,
#' which is exactly what happened the first time.
#' @param d The parsed answer.
#' @return A list (basic: the parsed response, src: its bytes), or what is
#'   wrong.
#' @noRd
.rmbl_ocsp_basic <- function(d) {
  oct <- .rmbl_der_find(d, function(nd) {
    identical(nd$class, 0L) && identical(nd$tag, 4) && length(nd$value) > 8L
  })
  if (is.null(oct)) {
    return("the answer carries no response bytes")
  }
  inner_src <- oct$value
  basic <- tryCatch(.Call(C_rmbl_der_parse, inner_src), error = function(e) {
    NULL
  })
  if (
    is.null(basic) ||
      length(basic$children) < 3L ||
      !isTRUE(basic$children[[1]]$constructed) ||
      !identical(basic$children[[3]]$tag, 3)
  ) {
    return("no BasicOCSPResponse in the answer")
  }
  list(basic = basic, src = inner_src)
}

#' The single response's certStatus: \[0\] good, \[1\] revoked, \[2\] unknown.
#' @param tbs The parsed tbsResponseData.
#' @return "good", "revoked" or "unknown", or NULL when there is no
#'   SingleResponse.
#' @noRd
.rmbl_ocsp_state <- function(tbs) {
  single <- .rmbl_der_find(tbs, function(nd) {
    isTRUE(nd$constructed) &&
      identical(nd$tag, 16) &&
      length(nd$children) >= 2L &&
      isTRUE(nd$children[[1]]$constructed) &&
      length(nd$children[[1]]$children) >= 4L &&
      identical(nd$children[[1]]$children[[1]]$tag, 16)
  })
  if (is.null(single)) {
    return(NULL)
  }
  st <- single$children[[2]]
  if (identical(st$class, 2L) && identical(st$tag, 0)) {
    return("good")
  }
  if (identical(st$class, 2L) && identical(st$tag, 1)) {
    return("revoked")
  }
  "unknown"
}

#' Verifies a BasicOCSPResponse's signature under a certificate in the path.
#' @param basic The parsed BasicOCSPResponse.
#' @param path The certificate path whose keys may have signed the answer.
#' @param src The raw bytes `basic` was parsed from.
#' @return A list with `ok` and a `detail` sentence.
#' @noRd
.rmbl_ocsp_verify_sig <- function(basic, path, src) {
  tbs_nd <- basic$children[[1]]
  alg <- basic$children[[2]]
  sig_bits <- basic$children[[3]]$value
  if (!length(sig_bits)) {
    return(list(ok = FALSE, detail = "it carries no signature"))
  }
  sig <- sig_bits[-1]
  oid <- if (length(alg$children)) {
    .rmbl_oid_string(alg$children[[1]]$value)
  } else {
    NA_character_
  }
  name <- .rmbl_x509_sigalg_name(oid)
  dalg <- .rmbl_ocsp_digest(name)
  if (is.na(dalg)) {
    return(list(
      ok = FALSE,
      detail = sprintf("it is signed with %s, which is not verified here", name)
    ))
  }
  # the bytes signed are the DER of tbsResponseData, exactly as they
  # arrived
  tbs <- .rmbl_node_bytes(tbs_nd, src)
  if (is.null(tbs)) {
    return(list(ok = FALSE, detail = "the signed bytes could not be isolated"))
  }
  for (cand in .rmbl_ocsp_candidates(basic, path, src)) {
    if (.rmbl_ocsp_key_verifies(cand$key, sig, dalg, tbs)) {
      return(list(ok = TRUE, detail = "signed"))
    }
  }
  list(
    ok = FALSE,
    detail = "its signature does not verify under any certificate in the path"
  )
}

#' The digest a signature algorithm's name implies.
#' @param name The algorithm's name.
#' @return "sha256", "sha384", "sha512", or NA.
#' @noRd
.rmbl_ocsp_digest <- function(name) {
  if (grepl("SHA256", name, fixed = TRUE)) {
    return("sha256")
  }
  if (grepl("SHA384", name, fixed = TRUE)) {
    return("sha384")
  }
  if (grepl("SHA512", name, fixed = TRUE)) {
    return("sha512")
  }
  NA_character_
}

#' The certificates that may have signed an OCSP answer.
#'
#' A responder may sign with a certificate the path issued, carried in the
#' answer; otherwise it must be one already in the path. The certificates are
#' the fourth element of BasicOCSPResponse (\[0\] EXPLICIT SEQUENCE OF
#' Certificate), read by position: a tree search for a \[0\] lands on nextUpdate
#' inside the SingleResponse first.
#' @param basic The parsed BasicOCSPResponse.
#' @param path The certificate path, the first candidates.
#' @param src The response's bytes.
#' @return A list of certificates, the embedded ones first.
#' @noRd
.rmbl_ocsp_candidates <- function(basic, path, src) {
  candidates <- path
  embedded <- if (length(basic$children) >= 4L) basic$children[[4]] else NULL
  if (
    is.null(embedded) ||
      !(identical(embedded$class, 2L) &&
        identical(embedded$tag, 0) &&
        isTRUE(embedded$constructed))
  ) {
    return(candidates)
  }
  for (c1 in embedded$children) {
    for (c2 in c1$children) {
      b <- .rmbl_node_bytes(c2, src)
      if (is.null(b)) {
        next
      }
      pc <- tryCatch(certprs(b), error = function(e) NULL)
      if (!is.null(pc)) candidates <- c(list(pc), candidates)
    }
  }
  candidates
}

#' Whether a certificate's key verifies the signature over the signed bytes.
#' @param key The certificate's public key.
#' @param sig The OCSP response's signature bytes.
#' @param dalg The digest.
#' @param tbs The signed bytes.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_ocsp_key_verifies <- function(key, sig, dalg, tbs) {
  if (identical(key$type, "RSA")) {
    em <- tryCatch(
      .Call(C_rmbl_rsa_recover, sig, key$modulus, key$exponent),
      error = function(e) NULL
    )
    return(!is.null(em) && isTRUE(.rmbl_pkcs1_check(em, dalg, tbs)$ok))
  }
  if (!identical(key$type, "EC") || is.null(key$x)) {
    return(FALSE)
  }
  rs <- .rmbl_ecdsa_rs(sig)
  if (is.null(rs)) {
    return(FALSE)
  }
  isTRUE(tryCatch(
    .Call(
      C_rmbl_ecdsa_verify,
      key$curve,
      key$x,
      key$y,
      rs$r,
      rs$s,
      .rmbl_ts_digest(dalg, tbs)
    ),
    error = function(e) FALSE
  ))
}

#' Slices a parsed node's exact DER out of its source.
#'
#' One node's complete DER, sliced out of the input it was parsed from.
#' The parser reports offsets rather than copying, so the source has to
#' travel with the node -- and it matters that this is the exact
#' encoding, because an OCSP signature is over the bytes of
#' tbsResponseData as they appeared, not over a re-encoding of them.
#' @param nd A parsed DER node.
#' @param src The raw bytes it was parsed from.
#' @return The node's bytes, or NULL when they are out of range.
#' @noRd
.rmbl_node_bytes <- function(nd, src) {
  if (is.null(nd) || is.null(src)) {
    return(NULL)
  }
  from <- nd$start + 1L
  to <- nd$offset + nd$length
  if (from < 1L || to > length(src) || to < from) {
    return(NULL)
  }
  src[from:to]
}
