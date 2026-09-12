# SPDX-License-Identifier: AGPL-3.0-or-later
#
# X.509 certificates: parsing, signature verification, and path
# validation.
#
# This is what turns "this key said so" into "a key you decided to
# trust vouches for the key that said so". The parts that matter, and
# each is a way a lax verifier gets fooled:
#
#   * the chain must actually chain -- each certificate's issuer name
#     equal to the next one's subject, and its signature verifying
#     under the next one's key;
#   * every certificate must be within its validity window AT THE TIME
#     IN QUESTION, which for a timestamp is the time the token asserts,
#     not the time the check is run;
#   * an intermediate must be a CA, or any leaf could sign for any
#     other name;
#   * the leaf must be allowed to do the job -- timeStamping, for a
#     timestamp token -- or a certificate issued for something else
#     entirely would serve;
#   * revocation, where a list is available.
#
# What is NOT done: name constraints, policy mapping, and fetching CRLs
# or OCSP over the network. A CRL has to be handed in.

#' Parse an X.509 certificate
#'
#' Reads the fields a verifier needs: who issued it, who it is for, when it
#' is valid, what key it carries, and what that key is allowed to do.
#'
#' @param certificate DER or PEM, as a raw vector or a
#' path.
#' @return A list of class `bricklayer_certificate`.
#' @seealso
#' [cert_chain_verify()],
#' [timestamp_verify()].
#' @examples
#' # Certificates come from outside the package, so there is nothing to
#' # parse offline; this is the shape of the call.
#' \dontrun{
#' cert <- cert_parse("tsa.crt")
#' cert$subject
#' cert$not_after
#' cert$extended_key_usage
#' }
#' @export
cert_parse <- function(certificate) {
  der <- .rmbl_as_bytes(certificate, "certificate")
  top <- .Call(C_rmbl_der_parse, der)
  if (length(top$children) < 3L) {
    stop("not an X.509 certificate", call. = FALSE)
  }
  tbs <- top$children[[1]]
  sig_alg <- .rmbl_oid_string(tbs_alg_oid(top$children[[2]]))
  sig_bits <- top$children[[3]]$value
  if (!length(sig_bits)) stop("the certificate has no signature",
                              call. = FALSE)
  sig <- sig_bits[-1]                       # drop the unused-bits octet

  k <- tbs$children
  # an explicit [0] version shifts every following field along by one
  off <- if (length(k) && identical(k[[1]]$class, 2L) &&
             identical(k[[1]]$tag, 0)) 1L else 0L
  version <- if (off == 1L) {
    as.integer(k[[1]]$children[[1]]$value[1]) + 1L
  } else {
    1L
  }
  serial <- .rmbl_hexlify(k[[off + 1L]]$value)
  issuer <- .rmbl_x509_name(k[[off + 3L]])
  validity <- k[[off + 4L]]$children
  subject <- .rmbl_x509_name(k[[off + 5L]])
  spki <- k[[off + 6L]]

  exts <- .rmbl_x509_extensions(k)
  out <- list(
    version = version,
    serial = serial,
    issuer = issuer,
    subject = subject,
    not_before = .rmbl_x509_time(validity[[1]]),
    not_after = .rmbl_x509_time(validity[[2]]),
    signature_algorithm = .rmbl_x509_sigalg_name(sig_alg),
    signature_oid = sig_alg,
    signature = sig,
    tbs = der[(tbs$start + 1L):(tbs$offset + tbs$length)],
    key = .rmbl_x509_key(spki),
    is_ca = exts$is_ca,
    key_usage = exts$key_usage,
    extended_key_usage = exts$eku,
    self_signed = identical(issuer, subject),
    der = der
  )
  class(out) <- c("bricklayer_certificate", "list")
  out
}

tbs_alg_oid <- function(alg) {
  if (!length(alg$children)) return(raw(0))
  alg$children[[1]]$value
}

#' @export
format.bricklayer_certificate <- function(x, ...) {
  c(.rmbl_rule("X.509 certificate"),
    .rmbl_kv(list(subject = x$subject,
                  issuer = x$issuer,
                  serial = substring(x$serial, 1L, 32L),
                  "valid from" = format(x$not_before, tz = "UTC"),
                  "valid to" = format(x$not_after, tz = "UTC"),
                  key = sprintf("%s %d bits", x$key$type, x$key$bits),
                  signature = x$signature_algorithm,
                  "is a CA" = x$is_ca,
                  "key usage" = paste(x$extended_key_usage,
                                      collapse = ", "))),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_certificate <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' Verify a certificate chain
#'
#' Builds the path from a leaf certificate to a trust anchor you supply,
#' verifying each signature, each validity window, and the constraints that
#' stop a certificate being used for something it was not issued for.
#'
#' `at_time` is the point the validity windows are checked against,
#' and it matters which one you pass. For a timestamp token the right
#' answer is the time the token asserts: a token signed in 2020 by a
#' certificate that expired in 2021 was validly signed, and checking it
#' against today would reject it for no good reason. For a signature you
#' are being asked to rely on now, pass now.
#'
#' @param leaf The certificate to validate, from
#' [cert_parse()] or anything
#' [cert_parse()] accepts.
#' @param trust A list of trust anchors -- the certificates
#' you have decided to believe. A chain that does not reach one of these
#' fails.
#' @param intermediates Optional further certificates
#' to build the path through. They are not trusted by being supplied; they
#' still have to verify.
#' @param at_time The time to check validity windows at.
#' Defaults to now.
#' @param purpose Optional extended key usage the leaf must
#' carry, as a name ( `"timeStamping"`, `"codeSigning"`, ...) or
#' an OID.
#' @param crls Optional list of CRLs, as raw or paths, to check
#' the chain against.
#' @return A list of class `bricklayer_chain_check`: `ok`, the
#' `path` that was built, and a `checks` data frame.
#' @seealso
#' [cert_parse()],
#' [timestamp_verify()].
#' @examples
#' \dontrun{
#' res <- cert_chain_verify("tsa.crt", trust = "ca.crt",
#'                          purpose = "timeStamping")
#' res$ok
#' res$checks
#' }
#' @export
cert_chain_verify <- function(leaf, trust, intermediates = list(),
                              at_time = Sys.time(), purpose = NULL,
                              crls = list()) {
  as_cert <- function(x) {
    if (inherits(x, "bricklayer_certificate")) x else cert_parse(x)
  }
  as_list <- function(x) {
    if (is.null(x)) return(list())
    if (inherits(x, "bricklayer_certificate") || is.raw(x) ||
        (is.character(x) && length(x) == 1L)) list(x) else as.list(x)
  }
  leaf <- as_cert(leaf)
  trust <- lapply(as_list(trust), as_cert)
  intermediates <- lapply(as_list(intermediates), as_cert)
  crls <- as_list(crls)
  if (!length(trust)) {
    stop("`trust` must name at least one anchor; a chain that reaches ",
         "nothing you have decided to believe proves nothing",
         call. = FALSE)
  }
  at_time <- as.POSIXct(at_time, tz = "UTC")

  checks <- list()
  note_row <- function(check, ok, detail = "") {
    checks[[length(checks) + 1L]] <<- data.frame(
      check = check, ok = isTRUE(ok), detail = as.character(detail),
      stringsAsFactors = FALSE)
  }

  # Build the path: follow issuer names up through the intermediates
  # until an anchor is reached. A depth cap because a cycle among
  # supplied certificates would otherwise loop.
  path <- list(leaf)
  pool <- c(intermediates, trust)
  cur <- leaf
  anchor <- NULL
  for (depth in seq_len(10L)) {
    hit <- Filter(function(c) identical(c$subject, cur$issuer), trust)
    if (length(hit)) { anchor <- hit[[1]]; break }
    nxt <- Filter(function(c) identical(c$subject, cur$issuer) &&
                    !identical(c$der, cur$der), pool)
    if (!length(nxt)) break
    path[[length(path) + 1L]] <- nxt[[1]]
    cur <- nxt[[1]]
  }
  note_row("path_to_anchor", !is.null(anchor),
           if (is.null(anchor))
             sprintf("no trust anchor issued '%s'", cur$issuer)
           else sprintf("anchored at '%s'", anchor$subject))
  if (!is.null(anchor)) path[[length(path) + 1L]] <- anchor

  # every link: issuer name, signature, validity, and CA-ness
  for (i in seq_along(path)) {
    cert <- path[[i]]
    tag <- sprintf("[%d] %s", i, substring(cert$subject, 1L, 24L))
    within <- at_time >= cert$not_before && at_time <= cert$not_after
    note_row(paste("validity", tag), within,
             sprintf("%s to %s, checked at %s",
                     format(cert$not_before, "%Y-%m-%d", tz = "UTC"),
                     format(cert$not_after, "%Y-%m-%d", tz = "UTC"),
                     format(at_time, "%Y-%m-%d", tz = "UTC")))
    if (i > 1L) {
      # An issuer must be a CA. Without this any leaf certificate could
      # sign a certificate for any name at all.
      note_row(paste("is a CA", tag), isTRUE(cert$is_ca),
               if (isTRUE(cert$is_ca)) "basicConstraints says CA" else
                 "basicConstraints does not permit issuing")
    }
    if (i < length(path)) {
      issuer <- path[[i + 1L]]
      v <- .rmbl_cert_verify_sig(cert, issuer)
      note_row(paste("signature", tag), v$ok, v$detail)
    }
  }
  # a self-signed anchor is expected to be self-signed, and nothing
  # above it vouches for it -- that is what makes it an anchor
  if (!is.null(anchor)) {
    note_row("anchor_self_signed", TRUE,
             if (isTRUE(anchor$self_signed))
               "the anchor is self-signed, as an anchor is"
             else "the anchor was supplied as trusted, not derived")
  }

  if (!is.null(purpose)) {
    want <- .rmbl_eku_oid(purpose)
    have <- leaf$extended_key_usage
    ok <- length(have) == 0L || want %in% .rmbl_eku_oid(have)
    note_row("purpose", ok && length(have) > 0L,
             if (length(have) == 0L)
               "the leaf states no extended key usage at all"
             else sprintf("leaf permits: %s", paste(have, collapse = ", ")))
  }

  if (length(crls)) {
    rv <- .rmbl_crl_check(path, crls, at_time)
    for (i in seq_len(nrow(rv))) {
      note_row(rv$check[i], rv$ok[i], rv$detail[i])
    }
  }

  df <- do.call(rbind, checks)
  rownames(df) <- NULL
  out <- list(ok = all(df$ok), path = path, checks = df,
              at_time = at_time)
  class(out) <- c("bricklayer_chain_check", "list")
  out
}

#' @export
format.bricklayer_chain_check <- function(x, ...) {
  c(.rmbl_rule(sprintf("Certificate chain: %s",
                       if (x$ok) "verified" else "NOT verified")),
    sprintf("  %d certificate(s), validity checked at %s",
            length(x$path), format(x$at_time, "%Y-%m-%d %H:%M:%S UTC",
                                   tz = "UTC")),
    .rmbl_rule(),
    sprintf("  %-34s %-5s %s", substring(x$checks$check, 1L, 34L),
            ifelse(x$checks$ok, "ok", "FAIL"),
            substring(x$checks$detail, 1L, 34L)),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_chain_check <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

# ---------------------------------------------------------------- #
# The pieces
# ---------------------------------------------------------------- #

# A distinguished name, rendered the way a person reads it. Only the
# attributes anyone looks at are named; the rest keep their OIDs, which
# is honest about what was in the certificate.
.rmbl_x509_name <- function(nd) {
  short <- c("2.5.4.3" = "CN", "2.5.4.6" = "C", "2.5.4.7" = "L",
             "2.5.4.8" = "ST", "2.5.4.10" = "O", "2.5.4.11" = "OU",
             "1.2.840.113549.1.9.1" = "emailAddress")
  parts <- character(0)
  for (rdn in nd$children) {
    for (atv in rdn$children) {
      if (length(atv$children) < 2L) next
      oid <- .rmbl_oid_string(atv$children[[1]]$value)
      nm <- if (oid %in% names(short)) short[[oid]] else oid
      val <- tryCatch(rawToChar(atv$children[[2]]$value),
                      error = function(e) "")
      parts <- c(parts, sprintf("%s=%s", nm, val))
    }
  }
  paste(parts, collapse = ", ")
}

# UTCTime is two-digit years, with the 1950 pivot RFC 5280 mandates;
# GeneralizedTime is four. Getting the pivot wrong puts a 2049
# certificate in 1949.
.rmbl_x509_time <- function(nd) {
  s <- tryCatch(rawToChar(nd$value), error = function(e) "")
  s <- sub("Z$", "", s)
  if (identical(nd$tag, 23)) {
    yy <- as.integer(substring(s, 1L, 2L))
    century <- if (yy >= 50L) "19" else "20"
    s <- paste0(century, s)
  }
  as.POSIXct(strptime(substring(s, 1L, 14L), "%Y%m%d%H%M%S", tz = "UTC"),
             tz = "UTC")
}

.rmbl_x509_extensions <- function(k) {
  out <- list(is_ca = FALSE, key_usage = character(0), eku = character(0))
  ext <- NULL
  for (nd in k) {
    if (identical(nd$class, 2L) && identical(nd$tag, 3)) ext <- nd
  }
  if (is.null(ext) || !length(ext$children)) return(out)
  for (e in ext$children[[1]]$children) {
    if (length(e$children) < 2L) next
    oid <- .rmbl_oid_string(e$children[[1]]$value)
    val <- e$children[[length(e$children)]]$value
    inner <- tryCatch(.Call(C_rmbl_der_parse, val), error = function(z) NULL)
    if (is.null(inner)) next
    if (identical(oid, "2.5.29.19")) {
      # basicConstraints: SEQUENCE { cA BOOLEAN DEFAULT FALSE, ... }
      kids <- inner$children
      out$is_ca <- length(kids) >= 1L && identical(kids[[1]]$tag, 1) &&
        length(kids[[1]]$value) >= 1L && kids[[1]]$value[1] != as.raw(0)
    } else if (identical(oid, "2.5.29.37")) {
      out$eku <- vapply(inner$children,
                        function(z) .rmbl_oid_string(z$value),
                        character(1))
    } else if (identical(oid, "2.5.29.15")) {
      out$key_usage <- .rmbl_key_usage_bits(inner$value)
    }
  }
  out
}

.rmbl_key_usage_bits <- function(v) {
  if (length(v) < 2L) return(character(0))
  names9 <- c("digitalSignature", "nonRepudiation", "keyEncipherment",
              "dataEncipherment", "keyAgreement", "keyCertSign",
              "cRLSign", "encipherOnly", "decipherOnly")
  bits <- character(0)
  body <- v[-1]
  for (i in seq_along(names9)) {
    byte <- (i - 1L) %/% 8L + 1L
    if (byte > length(body)) break
    bit <- 7L - ((i - 1L) %% 8L)
    if (bitwAnd(as.integer(body[byte]), bitwShiftL(1L, bit)) != 0L) {
      bits <- c(bits, names9[i])
    }
  }
  bits
}

.rmbl_eku_oid <- function(x) {
  map <- c(timeStamping = "1.3.6.1.5.5.7.3.8",
           codeSigning = "1.3.6.1.5.5.7.3.3",
           serverAuth = "1.3.6.1.5.5.7.3.1",
           clientAuth = "1.3.6.1.5.5.7.3.2",
           emailProtection = "1.3.6.1.5.5.7.3.4",
           OCSPSigning = "1.3.6.1.5.5.7.3.9",
           anyExtendedKeyUsage = "2.5.29.37.0")
  vapply(as.character(x), function(v) {
    if (v %in% names(map)) map[[v]] else v
  }, character(1), USE.NAMES = FALSE)
}

.rmbl_x509_sigalg_name <- function(oid) {
  switch(oid,
         "1.2.840.113549.1.1.11" = "RSA-SHA256",
         "1.2.840.113549.1.1.12" = "RSA-SHA384",
         "1.2.840.113549.1.1.13" = "RSA-SHA512",
         "1.2.840.113549.1.1.5"  = "RSA-SHA1",
         "1.2.840.10045.4.3.2"   = "ECDSA-SHA256",
         "1.2.840.10045.4.3.3"   = "ECDSA-SHA384",
         "1.2.840.10045.4.3.4"   = "ECDSA-SHA512",
         oid)
}

# The public key, whichever kind it is.
.rmbl_x509_key <- function(spki) {
  alg <- spki$children[[1]]
  oid <- .rmbl_oid_string(alg$children[[1]]$value)
  bits <- spki$children[[2]]$value
  inner <- if (length(bits) > 1L) bits[-1] else raw(0)
  if (identical(oid, "1.2.840.113549.1.1.1")) {
    rsa <- tryCatch(.Call(C_rmbl_der_parse, inner), error = function(e) NULL)
    if (is.null(rsa) || length(rsa$children) < 2L) {
      return(list(type = "unknown", bits = 0L))
    }
    strip <- function(v) {
      while (length(v) > 1L && v[1] == as.raw(0)) v <- v[-1]
      v
    }
    m <- strip(rsa$children[[1]]$value)
    list(type = "RSA", bits = 8L * length(m), modulus = m,
         exponent = strip(rsa$children[[2]]$value))
  } else if (identical(oid, "1.2.840.10045.2.1")) {
    curve <- if (length(alg$children) >= 2L)
      .rmbl_oid_string(alg$children[[2]]$value) else NA_character_
    nm <- switch(curve,
                 "1.2.840.10045.3.1.7" = "P-256",
                 "1.3.132.0.34" = "P-384",
                 "1.3.132.0.35" = "P-521",
                 NA_character_)
    if (is.na(nm) || !length(inner) || inner[1] != as.raw(0x04)) {
      # a compressed point would need decompression, which is not done
      return(list(type = "EC", bits = 0L, curve = curve))
    }
    n <- (length(inner) - 1L) %/% 2L
    list(type = "EC", bits = 8L * n, curve = nm,
         x = inner[2:(1L + n)], y = inner[(2L + n):(1L + 2L * n)])
  } else {
    list(type = oid, bits = 0L)
  }
}

# One certificate's signature, under its issuer's key.
.rmbl_cert_verify_sig <- function(cert, issuer) {
  name <- cert$signature_algorithm
  key <- issuer$key
  dalg <- if (grepl("SHA256", name)) "sha256" else
    if (grepl("SHA384", name)) "sha384" else
      if (grepl("SHA512", name)) "sha512" else NA_character_
  if (is.na(dalg)) {
    return(list(ok = FALSE,
                detail = sprintf("%s is not verified here", name)))
  }
  if (startsWith(name, "RSA")) {
    if (!identical(key$type, "RSA")) {
      return(list(ok = FALSE,
                  detail = "the issuer's key is not an RSA key"))
    }
    em <- tryCatch(.Call(C_rmbl_rsa_recover, cert$signature, key$modulus,
                         key$exponent),
                   error = function(e) NULL)
    if (is.null(em)) {
      return(list(ok = FALSE, detail = "the RSA operation failed"))
    }
    r <- .rmbl_pkcs1_check(em, dalg, cert$tbs)
    return(list(ok = r$ok, detail = paste(name, r$detail)))
  }
  if (startsWith(name, "ECDSA")) {
    if (!identical(key$type, "EC") || is.null(key$x)) {
      return(list(ok = FALSE,
                  detail = "the issuer's key is not a usable EC key"))
    }
    rs <- .rmbl_ecdsa_rs(cert$signature)
    if (is.null(rs)) {
      return(list(ok = FALSE, detail = "the ECDSA signature is malformed"))
    }
    dig <- .rmbl_ts_digest(dalg, cert$tbs)
    ok <- tryCatch(.Call(C_rmbl_ecdsa_verify, key$curve, key$x, key$y,
                         rs$r, rs$s, dig),
                   error = function(e) FALSE)
    return(list(ok = isTRUE(ok), detail = sprintf("%s on %s", name,
                                                  key$curve)))
  }
  list(ok = FALSE, detail = sprintf("%s is not verified here", name))
}

# An ECDSA signature is SEQUENCE { INTEGER r, INTEGER s }.
.rmbl_ecdsa_rs <- function(sig) {
  d <- tryCatch(.Call(C_rmbl_der_parse, sig), error = function(e) NULL)
  if (is.null(d) || length(d$children) < 2L) return(NULL)
  strip <- function(v) {
    while (length(v) > 1L && v[1] == as.raw(0)) v <- v[-1]
    v
  }
  list(r = strip(d$children[[1]]$value), s = strip(d$children[[2]]$value))
}

# Revocation, against a CRL that was handed in. Nothing is fetched.
.rmbl_crl_check <- function(path, crls, at_time) {
  rows <- list()
  add <- function(check, ok, detail) {
    rows[[length(rows) + 1L]] <<- data.frame(
      check = check, ok = ok, detail = detail, stringsAsFactors = FALSE)
  }
  revoked <- character(0)
  for (cr in crls) {
    der <- tryCatch(.rmbl_as_bytes(cr, "crl"), error = function(e) NULL)
    if (is.null(der)) next
    d <- tryCatch(.Call(C_rmbl_der_parse, der), error = function(e) NULL)
    if (is.null(d) || !length(d$children)) next
    tbs <- d$children[[1]]$children
    # TBSCertList: version?, signature, issuer, thisUpdate, nextUpdate?,
    # revokedCertificates?  The revoked list is the first SEQUENCE OF
    # whose members open with an INTEGER serial and a time.
    for (nd in tbs) {
      if (!isTRUE(nd$constructed) || !identical(nd$tag, 16)) next
      kids <- nd$children
      looks <- length(kids) > 0L && isTRUE(kids[[1]]$constructed) &&
        length(kids[[1]]$children) >= 2L &&
        identical(kids[[1]]$children[[1]]$tag, 2)
      if (!looks) next
      for (entry in kids) {
        revoked <- c(revoked,
                     .rmbl_hexlify(entry$children[[1]]$value))
      }
    }
  }
  if (!length(revoked)) {
    add("revocation", TRUE, "the CRLs supplied list nothing revoked")
    return(do.call(rbind, rows))
  }
  for (i in seq_along(path)) {
    cert <- path[[i]]
    hit <- tolower(cert$serial) %in% tolower(revoked)
    add(sprintf("revocation [%d]", i), !hit,
        if (hit) sprintf("serial %s is on a CRL", cert$serial)
        else "not listed")
  }
  do.call(rbind, rows)
}
