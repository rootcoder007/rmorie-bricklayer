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
#' Retrieves CRLs from the distribution points named in the certificates,
#' and asks any OCSP responder they name about each one. Called by
#' [cert_chain_verify()] when
#' `revocation = "fetch"`.
#'
#' The OCSP request is sent by GET with the DER request base64-encoded into
#' the URL, as RFC 6960 appendix A.1.1 allows. That avoids needing to POST,
#' and works with responders that accept it; one that requires POST is
#' reported as unreachable rather than treated as a pass.
#'
#' A responder's answer is only believed when its signature verifies under
#' a certificate in the path or one it carries that the path issued. An
#' unsigned or unverifiable answer is reported as such -- treating it as
#' "good" would make revocation checking worse than skipping it, since it
#' would look like it had happened.
#'
#' @param path A certificate path, leaf first, as
#' [cert_chain_verify()] builds it.
#' @param timeout Seconds to allow each request.
#' @return A list with `crls` (raw vectors fetched), `ok` (a
#' logical per note) and `notes` (a named list of details).
#' @seealso
#' [cert_chain_verify()],
#' [timestamp_verify()].
#' @examples
#' # Reaches the network, so it is not run here.
#' \dontrun{
#' res <- cert_chain_verify("leaf.crt", trust = "ca.crt",
#'                          revocation = "fetch")
#' res$checks
#' }
#' @export
revocation_fetch <- function(path, timeout = 10) {
  .rmbl_revocation_fetch(path, timeout)
}

.rmbl_revocation_fetch <- function(path, timeout = 10) {
  crls <- list()
  notes <- list()
  ok <- logical(0)
  add <- function(name, good, detail) {
    notes[[name]] <<- detail
    ok <<- c(ok, isTRUE(good))
  }
  for (i in seq_along(path)) {
    cert <- path[[i]]
    for (url in .rmbl_crl_urls(cert)) {
      got <- .rmbl_http_der(url, timeout)
      if (is.null(got)) {
        add(sprintf("crl fetch [%d]", i), FALSE,
            sprintf("could not retrieve %s", url))
      } else {
        crls[[length(crls) + 1L]] <- got
        add(sprintf("crl fetch [%d]", i), TRUE,
            sprintf("%d bytes from %s", length(got), url))
      }
    }
    # OCSP needs the issuer, so the last certificate in the path has
    # nobody to ask about it
    if (i >= length(path)) next
    issuer <- path[[i + 1L]]
    for (url in .rmbl_ocsp_urls(cert)) {
      res <- .rmbl_ocsp_query(cert, issuer, url, path, timeout)
      add(sprintf("ocsp [%d]", i), res$ok, res$detail)
    }
  }
  list(crls = crls, ok = ok, notes = notes)
}

# cRLDistributionPoints (2.5.29.31): the http URLs in it.
.rmbl_crl_urls <- function(cert) {
  .rmbl_ext_urls(cert, "2.5.29.31", NULL)
}

# authorityInfoAccess (1.3.6.1.5.5.7.1.1), the entries whose method is
# id-ad-ocsp (1.3.6.1.5.5.7.48.1).
.rmbl_ocsp_urls <- function(cert) {
  .rmbl_ext_urls(cert, "1.3.6.1.5.5.7.1.1", "1.3.6.1.5.5.7.48.1")
}

.rmbl_ext_urls <- function(cert, oid, method) {
  der <- cert$der
  top <- tryCatch(.Call(C_rmbl_der_parse, der), error = function(e) NULL)
  if (is.null(top)) return(character(0))
  k <- top$children[[1]]$children
  ext <- NULL
  for (nd in k) {
    if (identical(nd$class, 2L) && identical(nd$tag, 3)) ext <- nd
  }
  if (is.null(ext) || !length(ext$children)) return(character(0))
  urls <- character(0)
  for (e in ext$children[[1]]$children) {
    if (length(e$children) < 2L) next
    if (!identical(.rmbl_oid_string(e$children[[1]]$value), oid)) next
    inner <- tryCatch(
      .Call(C_rmbl_der_parse, e$children[[length(e$children)]]$value),
      error = function(z) NULL)
    if (is.null(inner)) next
    urls <- c(urls, .rmbl_collect_uris(inner, method))
  }
  # only http; a verifier that followed ldap or file URLs from a
  # certificate would be following instructions from the thing it is
  # checking
  urls[grepl("^https?://", urls)]
}

# Walk a structure collecting [6] IA5String URIs. When `method` is
# given, only from SEQUENCEs whose first element is that OID.
.rmbl_collect_uris <- function(nd, method = NULL) {
  out <- character(0)
  if (!is.null(method) && isTRUE(nd$constructed) &&
      length(nd$children) >= 2L &&
      identical(nd$children[[1]]$tag, 6) &&
      identical(.rmbl_oid_string(nd$children[[1]]$value), method)) {
    tail <- nd$children[[2]]
    if (identical(tail$class, 2L) && identical(tail$tag, 6)) {
      return(.rmbl_raw_text(tail$value))
    }
  }
  if (identical(nd$class, 2L) && identical(nd$tag, 6) &&
      !isTRUE(nd$constructed) && is.null(method)) {
    return(.rmbl_raw_text(nd$value))
  }
  for (kid in nd$children) {
    out <- c(out, .rmbl_collect_uris(kid, method))
  }
  out
}

# A GET that returns the body as raw bytes, through the package's own
# fetch so there is one place where the network is touched.
.rmbl_http_der <- function(url, timeout = 10) {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  got <- tryCatch(
    .Call(C_rmbl_fetch_fallback, url, NA_character_, tmp,
          as.integer(timeout)),
    error = function(e) NULL)
  if (is.null(got) || !file.exists(tmp) || file.size(tmp) == 0) {
    return(NULL)
  }
  b <- readBin(tmp, "raw", file.size(tmp))
  # a PEM CRL is as likely as a DER one
  txt <- tryCatch(rawToChar(b[seq_len(min(64L, length(b)))]),
                  error = function(e) "")
  if (grepl("-----BEGIN", txt, fixed = TRUE)) {
    all_txt <- rawToChar(b)
    body <- sub(".*-----BEGIN[^-]*-----", "", all_txt)
    body <- sub("-----END.*", "", body)
    body <- gsub("[\r\n[:space:]]", "", body)
    return(tryCatch(bricklayer_json_base64_dec(body),
                    error = function(e) NULL))
  }
  b
}

# ---------------------------------------------------------------- #
# OCSP (RFC 6960)
# ---------------------------------------------------------------- #

# Minimal DER encoding. Only what an OCSP request needs, because a
# general encoder is a great deal of surface for one message shape.
.rmbl_der_tlv <- function(tag, body) {
  c(as.raw(tag), .rmbl_der_length(length(body)), body)
}

.rmbl_der_seq <- function(...) {
  .rmbl_der_tlv(0x30, c(...))
}

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
      if (i < length(chunks)) b <- b + 128L
      rest <- c(rest, as.raw(b))
    }
  }
  .rmbl_der_tlv(0x06, c(first, rest))
}

# The issuer name and key as the CertID wants them: the SHA-1 of the
# issuer's encoded Name, and of the BIT STRING contents of its public
# key. SHA-1 is what RFC 6960 specifies for CertID and what responders
# key on; it is not verifying anything here.
.rmbl_ocsp_certid <- function(cert, issuer) {
  top <- .Call(C_rmbl_der_parse, cert$der)
  k <- top$children[[1]]$children
  off <- if (length(k) && identical(k[[1]]$class, 2L) &&
             identical(k[[1]]$tag, 0)) 1L else 0L
  iss <- k[[off + 3L]]
  issuer_der <- cert$der[(iss$start + 1L):(iss$offset + iss$length)]

  itop <- .Call(C_rmbl_der_parse, issuer$der)
  ik <- itop$children[[1]]$children
  ioff <- if (length(ik) && identical(ik[[1]]$class, 2L) &&
              identical(ik[[1]]$tag, 0)) 1L else 0L
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
    .rmbl_der_seq(.rmbl_der_oid_bytes("1.3.14.3.2.26"),
                  .rmbl_der_tlv(0x05, raw(0))),
    .rmbl_der_tlv(0x04, .Call(C_rmbl_sha1, issuer_der)),
    .rmbl_der_tlv(0x04, .Call(C_rmbl_sha1, keybytes)),
    .rmbl_der_tlv(0x02, serial_raw))
}

.rmbl_ocsp_request <- function(cert, issuer) {
  req <- .rmbl_der_seq(.rmbl_der_seq(.rmbl_der_seq(
    .rmbl_ocsp_certid(cert, issuer))))
  .rmbl_der_seq(req)
}

.rmbl_ocsp_query <- function(cert, issuer, url, path, timeout = 10) {
  req <- tryCatch(.rmbl_ocsp_request(cert, issuer),
                  error = function(e) NULL)
  if (is.null(req)) {
    return(list(ok = FALSE, detail = "could not build an OCSP request"))
  }
  # POST first, which is what RFC 6960 requires a responder to accept,
  # then fall back to the optional GET form. The other way round fails
  # against most responders, which refuse GET.
  body <- NULL
  res <- tryCatch(.Call(C_rmbl_http_post, url, req,
                        "application/ocsp-request", as.integer(timeout)),
                  error = function(e) NULL)
  if (!is.null(res) && identical(res$status, 200L) &&
      length(res$body) > 0L) {
    body <- res$body
  }
  if (is.null(body)) {
    b64 <- bricklayer_json_base64_enc(req)
    full <- paste0(sub("/+$", "", url), "/", .rmbl_url_encode(b64))
    body <- .rmbl_http_der(full, timeout)
  }
  if (is.null(body)) {
    return(list(ok = FALSE,
                detail = sprintf("no answer from %s over POST or GET",
                                 url)))
  }
  .rmbl_ocsp_parse(body, cert, path)
}

.rmbl_url_encode <- function(x) {
  chars <- strsplit(x, "", fixed = TRUE)[[1]]
  out <- vapply(chars, function(ch) {
    if (grepl("[A-Za-z0-9._~-]", ch)) return(ch)
    sprintf("%%%02X", as.integer(charToRaw(ch)))
  }, character(1))
  paste(out, collapse = "")
}

# OCSPResponse ::= SEQUENCE { responseStatus ENUMERATED,
#                             responseBytes [0] EXPLICIT OPTIONAL }
# The status is what says whether there is an answer at all; the answer
# is a BasicOCSPResponse whose tbsResponseData carries one
# SingleResponse per certificate asked about.
.rmbl_ocsp_parse <- function(body, cert, path) {
  d <- tryCatch(.Call(C_rmbl_der_parse, body), error = function(e) NULL)
  if (is.null(d) || !length(d$children)) {
    return(list(ok = FALSE, detail = "the OCSP answer is not DER"))
  }
  status <- .rmbl_int_of(d$children[[1]]$value)
  if (!identical(status, 0L)) {
    labels <- c("malformedRequest", "internalError", "tryLater", "",
                "sigRequired", "unauthorized")
    nm <- if (status >= 1L && status <= 6L) labels[status] else
      as.character(status)
    return(list(ok = FALSE,
                detail = sprintf("the responder answered '%s'", nm)))
  }
  # responseBytes ::= [0] EXPLICIT SEQUENCE { responseType OID,
  #                                            response OCTET STRING }
  # The BasicOCSPResponse is the CONTENTS of that octet string, which
  # is a DER document of its own -- the outer parse stops at the string,
  # so it has to be parsed again. Walking the outer tree looking for it
  # finds nothing, which is exactly what happened the first time.
  oct <- .rmbl_der_find(d, function(nd) {
    identical(nd$class, 0L) && identical(nd$tag, 4) &&
      length(nd$value) > 8L
  })
  if (is.null(oct)) {
    return(list(ok = FALSE,
                detail = "the answer carries no response bytes"))
  }
  inner_src <- oct$value
  basic <- tryCatch(.Call(C_rmbl_der_parse, inner_src),
                    error = function(e) NULL)
  if (is.null(basic) || length(basic$children) < 3L ||
      !isTRUE(basic$children[[1]]$constructed) ||
      !identical(basic$children[[3]]$tag, 3)) {
    return(list(ok = FALSE,
                detail = "no BasicOCSPResponse in the answer"))
  }
  tbs <- basic$children[[1]]
  # find the single response's certStatus: [0] good, [1] revoked,
  # [2] unknown
  single <- .rmbl_der_find(tbs, function(nd) {
    isTRUE(nd$constructed) && identical(nd$tag, 16) &&
      length(nd$children) >= 2L &&
      isTRUE(nd$children[[1]]$constructed) &&
      length(nd$children[[1]]$children) >= 4L &&
      identical(nd$children[[1]]$children[[1]]$tag, 16)
  })
  if (is.null(single)) {
    return(list(ok = FALSE, detail = "no SingleResponse in the answer"))
  }
  st <- single$children[[2]]
  state <- if (identical(st$class, 2L) && identical(st$tag, 0)) "good"
    else if (identical(st$class, 2L) && identical(st$tag, 1)) "revoked"
    else "unknown"

  # The answer is only worth anything if it is signed by someone the
  # path vouches for. An unverified "good" is worse than no check: it
  # looks like one happened.
  sig_ok <- .rmbl_ocsp_verify_sig(basic, path, inner_src)
  if (!sig_ok$ok) {
    return(list(ok = FALSE,
                detail = sprintf("the responder said '%s' but %s", state,
                                 sig_ok$detail)))
  }
  if (identical(state, "good")) {
    return(list(ok = TRUE, detail = "the responder says good, signed"))
  }
  list(ok = FALSE,
       detail = sprintf("the responder says %s, signed", state))
}

.rmbl_ocsp_verify_sig <- function(basic, path, src) {
  tbs_nd <- basic$children[[1]]
  alg <- basic$children[[2]]
  sig_bits <- basic$children[[3]]$value
  if (!length(sig_bits)) {
    return(list(ok = FALSE, detail = "it carries no signature"))
  }
  sig <- sig_bits[-1]
  oid <- if (length(alg$children)) .rmbl_oid_string(alg$children[[1]]$value)
    else NA_character_
  name <- .rmbl_x509_sigalg_name(oid)
  dalg <- if (grepl("SHA256", name)) "sha256" else
    if (grepl("SHA384", name)) "sha384" else
      if (grepl("SHA512", name)) "sha512" else NA_character_
  if (is.na(dalg)) {
    return(list(ok = FALSE,
                detail = sprintf("it is signed with %s, which is not verified here",
                                 name)))
  }
  # the bytes signed are the DER of tbsResponseData, exactly as they
  # arrived
  tbs <- .rmbl_node_bytes(tbs_nd, src)
  if (is.null(tbs)) {
    return(list(ok = FALSE,
                detail = "the signed bytes could not be isolated"))
  }
  # A responder may sign with a certificate the path issued, carried in
  # the answer; otherwise it must be one already in the path.
  candidates <- path
  embedded <- .rmbl_der_find(basic, function(nd) {
    identical(nd$class, 2L) && identical(nd$tag, 0) &&
      isTRUE(nd$constructed)
  })
  if (!is.null(embedded)) {
    for (c1 in embedded$children) {
      for (c2 in c1$children) {
        b <- .rmbl_node_bytes(c2, src)
        if (is.null(b)) next
        pc <- tryCatch(cert_parse(b), error = function(e) NULL)
        if (!is.null(pc)) candidates <- c(list(pc), candidates)
      }
    }
  }
  for (cand in candidates) {
    key <- cand$key
    if (identical(key$type, "RSA")) {
      em <- tryCatch(.Call(C_rmbl_rsa_recover, sig, key$modulus,
                           key$exponent), error = function(e) NULL)
      if (!is.null(em) && isTRUE(.rmbl_pkcs1_check(em, dalg, tbs)$ok)) {
        return(list(ok = TRUE, detail = "signed"))
      }
    } else if (identical(key$type, "EC") && !is.null(key$x)) {
      rs <- .rmbl_ecdsa_rs(sig)
      if (!is.null(rs)) {
        v <- tryCatch(.Call(C_rmbl_ecdsa_verify, key$curve, key$x, key$y,
                            rs$r, rs$s, .rmbl_ts_digest(dalg, tbs)),
                      error = function(e) FALSE)
        if (isTRUE(v)) return(list(ok = TRUE, detail = "signed"))
      }
    }
  }
  list(ok = FALSE,
       detail = "its signature does not verify under any certificate in the path")
}

# One node's complete DER, sliced out of the input it was parsed from.
# The parser reports offsets rather than copying, so the source has to
# travel with the node -- and it matters that this is the exact
# encoding, because an OCSP signature is over the bytes of
# tbsResponseData as they appeared, not over a re-encoding of them.
.rmbl_node_bytes <- function(nd, src) {
  if (is.null(nd) || is.null(src)) return(NULL)
  from <- nd$start + 1L
  to <- nd$offset + nd$length
  if (from < 1L || to > length(src) || to < from) return(NULL)
  src[from:to]
}
