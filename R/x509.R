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
#   * name constraints -- a CA limited to one name space must not be
#     able to issue outside it, directly or through an intermediate;
#   * the path length a CA permits beneath it;
#   * certificate policies, with mapping and the explicit-policy,
#     inhibit-mapping and inhibit-anyPolicy constraints;
#   * revocation, from CRLs handed in or -- on request -- fetched.
#
# What is NOT done: policy qualifier processing. A user notice attached
# to a policy is parsed past rather than surfaced.

#' Parse an X.509 certificate
#'
#' Reads the fields a verifier needs: who issued it, who it is for, when it
#' is valid, what key it carries, and what that key is allowed to do. Use it
#' to inspect the certificate of a timestamping authority or a signer before
#' you decide to trust it, or as the first step of
#' [certchnvrf()]. The
#' DER decoder is the package's own; no system library or network is used.
#'
#' @details
#' The certificate is decoded as DER (RFC 5280 section 4.1); a file whose
#' text contains a \code{-----BEGIN} line is read as PEM and its base64 body
#' decoded first (only the first certificate in the file is used). Version
#' 1 certificates, without the explicit version field, are accepted.
#' Extensions read: basic constraints, key usage, extended key usage, subject
#' alternative name, name constraints, certificate policies, policy mappings
#' and policy constraints, and inhibit any-policy. The signature is not
#' checked here: that needs the issuer's key, which
#' [certchnvrf()]
#' supplies.
#'
#' Errors: \code{cert} neither a raw vector nor the path of an
#' existing file (a directory is refused); bytes that are not well-formed DER
#' or carry trailing bytes; a DER structure that is not a certificate or has
#' no signature.
#'
#' @param cert The certificate, DER or PEM: a raw vector of DER bytes,
#'   or the path of a \code{.der}, \code{.crt}, \code{.cer} or \code{.pem}
#'   file.
#' @return A list of class \code{bricklayer_certificate} with these elements:
#'   \itemize{ \item \code{version} (integer) and \code{serial} (hex); \item
#'   \code{issuer} and \code{subject} (distinguished names as text); \item
#'   \code{not_before} and \code{not_after} (\code{POSIXct}, UTC); \item
#'   \code{signature_algorithm} (a name such as \code{"ECDSA-SHA256"}) and
#'   \code{signature_oid}; \item \code{signature} and \code{tbs} (raw; the
#'   signed part); \item \code{key} (a list: \code{type} \code{"RSA"} or
#'   \code{"EC"}, \code{bits}, and the key values, with \code{curve} for EC);
#'   \item \code{is_ca} and \code{path_len}; \item \code{key_usage} and
#'   \code{extended_key_usage} (character; EKU as OIDs); \item
#'   \code{subject_rdns}, \code{issuer_rdns}, \code{san} and
#'   \code{name_constraints}; \item the policy fields \code{policies},
#'   \code{policy_mappings} and \code{require_explicit_policy}; \item the policy
#'   fields \code{inhibit_policy_mapping} and \code{inhibit_any_policy}; \item
#'   \code{self_signed} (logical: issuer equals subject); \item \code{der} (the
#'   bytes). } \code{print()} shows a summary.
#' @seealso
#' [certchnvrf()],
#' [tsvrf()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Pass the certificate file you were given (.der, .crt, .cer or .pem), for
#' # example the one a timestamping authority publishes, or raw DER bytes.
#' # Here: a small test chain shipped with the package, a self-signed P-256
#' # root and a leaf it issued (a throwaway test authority; trust it for
#' # nothing).
#' x509 <- function(f) {
#'   system.file("extdata", "x509", f, package = "rmoriebricklayer")
#' }
#' root <- certprs(x509("test-root.der"))
#' root
#' leaf <- certprs(x509("test-leaf.der"))
#' leaf$subject
#' leaf$key$curve
#' c(leaf$not_before, leaf$not_after)
#'
#' # the same root as PEM, the text form most authorities hand out
#' certprs(x509("test-root.pem"))$self_signed
#'
#' # raw DER bytes work too
#' f <- x509("test-leaf.der")
#' der <- readBin(f, "raw", file.size(f))
#' identical(certprs(der)$serial, leaf$serial)
#'
#' # bytes that are not a certificate
#' try(certprs(charToRaw("not a certificate")))
#' @export
certprs <- function(cert) {
  der <- .rmbl_as_bytes(cert, "cert")
  top <- .Call(C_rmbl_der_parse, der)
  if (length(top$children) < 3L) {
    stop("not an X.509 certificate", call. = FALSE)
  }
  tbs <- top$children[[1]]
  sig_alg <- .rmbl_oid_string(tbs_alg_oid(top$children[[2]]))
  sig <- .rmbl_x509_sig_bits(top$children[[3]]$value)
  k <- tbs$children
  vo <- .rmbl_x509_version(k)
  off <- vo$off
  version <- vo$version
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
    path_len = exts$path_len,
    key_usage = exts$key_usage,
    extended_key_usage = exts$eku,
    subject_rdns = .rmbl_x509_rdns(k[[off + 5L]]),
    issuer_rdns = .rmbl_x509_rdns(k[[off + 3L]]),
    san = exts$san,
    name_constraints = exts$name_constraints,
    policies = exts$policies,
    policy_mappings = exts$policy_mappings,
    require_explicit_policy = exts$require_explicit_policy,
    inhibit_policy_mapping = exts$inhibit_policy_mapping,
    inhibit_any_policy = exts$inhibit_any_policy,
    self_signed = identical(issuer, subject),
    der = der
  )
  class(out) <- c("bricklayer_certificate", "list")
  out
}

#' @export
format.bricklayer_certificate <- function(x, ...) {
  .rmbl_stat_block(
    "X.509 certificate",
    facts = list(
      Subject = x$subject,
      Issuer = x$issuer,
      Serial = substring(x$serial, 1L, 32L),
      `Valid from` = format(x$not_before, tz = "UTC"),
      `Valid to` = format(x$not_after, tz = "UTC"),
      Key = sprintf("%s %d bits", x$key$type, x$key$bits),
      Signature = x$signature_algorithm,
      `Is a CA` = x$is_ca,
      `Self-signed` = x$self_signed,
      `Key usage` = if (length(x$key_usage)) {
        toString(x$key_usage)
      } else {
        "none stated"
      },
      `Extended key usage` = if (length(x$extended_key_usage)) {
        toString(x$extended_key_usage)
      } else {
        "none stated"
      },
      `Alternative names` = if (length(x$san)) length(x$san)
    ),
    reading = .rmbl_cert_reading(x, Sys.time()),
    notes = paste(
      "What the certificate says about itself. Nothing here is checked:",
      "certchnvrf() verifies it against trust anchors you choose."
    )
  )
}

#' Verify a certificate chain
#'
#' Builds the path from a leaf certificate to a trust anchor you supply,
#' verifying each signature, each validity window, and the constraints that
#' stop a certificate being used for something it was not issued for.
#'
#' `attm` is the point the validity windows are checked against,
#' and it matters which one you pass. For a timestamp token the right
#' answer is the time the token asserts: a token signed in 2020 by a
#' certificate that expired in 2021 was validly signed, and checking it
#' against today would reject it for no good reason. For a signature you
#' are being asked to rely on now, pass now.
#'
#' @param leaf The certificate to validate, from
#' [certprs()] or anything
#' [certprs()] accepts.
#' @param trust A list of trust anchors -- the certificates
#' you have decided to believe. A chain that does not reach one of these
#' fails.
#' @param inter Optional further certificates
#' to build the path through. They are not trusted by being supplied; they
#' still have to verify.
#' @param attm The time to check validity windows at: a \code{POSIXct} or
#' anything \code{as.POSIXct()} reads, taken as UTC. Defaults to now.
#' @param purp Optional extended key usage the leaf must
#' carry, as a name (\code{"timeStamping"}, \code{"codeSigning"}, ...) or
#' an OID. Default \code{NULL}: no purpose is required.
#' @param crls Optional list of CRLs, as raw DER or paths, to check
#' the chain against. Default \code{list()}.
#' @param pols Optional character vector of acceptable certificate
#' policy OIDs; default \code{NULL}.
#' Supplied, the path must yield at least one of them after policy mapping
#' and the constraints in RFC 5280 section 6.1; omitted, policies are
#' processed but only reported as a failure when a certificate in the path
#' requires an explicit policy.
#' @param rvk `"supplied"` (the default)
#' checks only the CRLs given in `crls`. `"fetch"` additionally
#' retrieves CRLs from the distribution points in the certificates and
#' queries OCSP responders
#' -- which makes verification depend on the network and discloses to
#' the responder which certificates are being checked, so it is never the
#' default. `"none"` skips revocation entirely.
#' @details
#' The path is built by following issuer names from the leaf through the
#' intermediates until a certificate in \code{trust} is reached, at most ten
#' steps (a cycle among supplied certificates cannot loop). Then every link is
#' checked: the validity window at \code{attm}, the signature under the
#' issuer's key (RSA PKCS#1 v1.5 with SHA-1, SHA-256, SHA-384 or SHA-512;
#' ECDSA with SHA-256, SHA-384 or SHA-512 on P-256, P-384 and P-521), that
#' every issuer is a CA with a path length that allows the chain, name
#' constraints, the policy rules of RFC 5280 section 6.1, the requested
#' \code{purp} (extended key usage of the leaf), that the anchor is
#' self-signed, and revocation as \code{rvk} says. Each
#' check is one row of \code{checks}; \code{ok} is \code{TRUE} only when every
#' row passed. A failed check is a row, not an error.
#'
#' Errors: \code{trust} empty; a certificate that [certprs()]
#' cannot read;
#' an unknown \code{rvk}. With \code{revocation = "fetch"} the network
#' is used (distribution points and OCSP responders named in the
#' certificates); otherwise nothing is fetched.
#'
#' @return A list of class \code{bricklayer_certpath_check}: \code{ok}
#' (logical, the verdict), \code{path} (the list of certificates from the
#' leaf to the anchor, as built), \code{checks} (a data frame with
#' \code{check}, logical \code{ok} and \code{detail}, one row per check),
#' \code{attm} (the time used) and \code{policies} (the outcome of policy
#' processing). \code{print()} shows the verdict and the checks.
#' @seealso
#' [certprs()],
#' [tsvrf()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # The test chain shipped with the package: a self-signed P-256 root and a
#' # leaf it issued (a throwaway test authority; trust it for nothing). With
#' # your own certificates, pass their files (or certprs() results).
#' x509 <- function(f) {
#'   system.file("extdata", "x509", f, package = "rmoriebricklayer")
#' }
#' root <- certprs(x509("test-root.der"))
#' leaf <- certprs(x509("test-leaf.der"))
#'
#' # the leaf chains to the root, checked a day after it was issued
#' res <- certchnvrf(leaf, trust = root, attm = leaf$not_before + 86400)
#' res$ok
#' res$checks[, c("check", "ok")]
#'
#' # after the leaf expired, the same chain fails on validity
#' certchnvrf(leaf, trust = root, attm = leaf$not_after + 86400)$ok
#'
#' # a purpose the leaf was not issued for
#' r <- certchnvrf(
#'   leaf,
#'   trust = root,
#'   attm = leaf$not_before + 86400,
#'   purp = "timeStamping"
#' )
#' r$checks[!r$checks$ok, ]
#'
#' # a chain must end at something you trust
#' try(certchnvrf(leaf, trust = list()))
#'
#' @examplesIf interactive()
#' # with revocation looked up on the network
#' certchnvrf("tsa.crt", trust = "ca.crt", purp = "timeStamping",
#'                   rvk = "fetch")
#' @export
certchnvrf <- function(
  leaf,
  trust,
  inter = list(),
  attm = Sys.time(),
  purp = NULL,
  crls = list(),
  pols = NULL,
  rvk = c(
    "supplied",
    "fetch",
    "none"
  )
) {
  .rmbl_no_fn(purp = purp, pols = pols)
  .cv_check_time(attm)
  leaf <- .cv_as_cert(leaf)
  trust <- lapply(.cv_as_list(trust), .cv_as_cert)
  inter <- lapply(.cv_as_list(inter), .cv_as_cert)
  crls <- .cv_as_list(crls)
  if (!length(trust)) {
    stop(
      "`trust` must name at least one anchor; a chain that reaches ",
      "nothing you have decided to believe proves nothing",
      call. = FALSE
    )
  }
  attm <- as.POSIXct(attm, tz = "UTC")
  rvk <- .rmbl_arg(rvk)

  acc <- new.env(parent = emptyenv())
  acc$checks <- list()
  path <- .cv_build_path(acc, leaf, inter, trust)
  .cv_links(acc, path, attm)
  attr(path, "anchor") <- NULL
  .cv_name_constraints(acc, path)
  .cv_path_len(acc, path)
  pol <- .cv_policies(acc, path, pols)
  if (!is.null(purp)) {
    .cv_purpose(acc, leaf, purp)
  }
  .cv_revocation(acc, path, crls, rvk, attm)

  df <- do.call(rbind, acc$checks)
  rownames(df) <- NULL
  out <- list(
    ok = all(df$ok),
    path = path,
    checks = df,
    at_time = attm,
    policies = pol
  )
  class(out) <- c("bricklayer_certpath_check", "list")
  out
}

#' @export
format.bricklayer_certpath_check <- function(x, ...) {
  .rmbl_stat_block(
    sprintf(
      "Certificate chain: %s",
      if (isTRUE(x$ok)) "verified" else "NOT verified"
    ),
    facts = list(
      Certificates = length(x$path),
      `Checked at` = format(x$at_time, "%Y-%m-%d %H:%M:%S UTC", tz = "UTC")
    ),
    reading = .rmbl_check_reading(
      x$ok,
      "the path reaches a trust anchor and every certificate on it was valid",
      "the certificate cannot be relied on for this use at this time"
    ),
    notes = .rmbl_check_lines(x$checks)
  )
}

#' A small non-negative INTEGER's value.
#' @param v The INTEGER's content bytes.
#' @return The value as an integer, NA for no bytes.
#' @noRd
.rmbl_int_of <- function(v) {
  if (!length(v)) {
    return(NA_integer_)
  }
  r <- 0L
  for (b in as.integer(v)) {
    r <- r * 256L + b
  }
  r
}

#' Returns the OID bytes of an AlgorithmIdentifier.
#' @param alg The parsed AlgorithmIdentifier node.
#' @return A raw vector, empty when the node has no children.
#' @noRd
tbs_alg_oid <- function(alg) {
  if (!length(alg$children)) {
    return(raw(0))
  }
  alg$children[[1]]$value
}

#' certchnvrf()'s `attm`, checked: one date-time.
#' @param attm As for certchnvrf().
#' @noRd
.cv_check_time <- function(attm) {
  if (
    !(inherits(attm, c("POSIXt", "Date")) ||
      (is.numeric(attm) && !is.object(attm))) ||
      length(attm) != 1L ||
      is.na(attm) ||
      !is.finite(as.numeric(attm))
  ) {
    stop("`attm` must be a single date-time (POSIXct)", call. = FALSE)
  }
  invisible(NULL)
}

#' A certificate: one already parsed, or parsed now.
#' @param x A certificate, its DER bytes or its PEM text.
#' @return The parsed certificate.
#' @noRd
.cv_as_cert <- function(x) {
  if (inherits(x, "bricklayer_certificate")) x else certprs(x)
}

#' One certificate (or CRL) or several, as a list.
#' @param x NULL, one, or a list.
#' @return A list.
#' @noRd
.cv_as_list <- function(x) {
  if (is.null(x)) {
    return(list())
  }
  if (
    inherits(x, "bricklayer_certificate") ||
      is.raw(x) ||
      (is.character(x) && length(x) == 1L)
  ) {
    list(x)
  } else {
    as.list(x)
  }
}

#' Builds the path: follow issuer names up through the intermediates until an
#' anchor is reached. A depth cap because a cycle among supplied certificates
#' would otherwise loop.
#' @param acc The checks so far, extended by the path building.
#' @param leaf,inter,trust The leaf, the intermediates and the anchors.
#' @return The path, leaf first, ending at the anchor when one was reached.
#' @noRd
.cv_build_path <- function(acc, leaf, inter, trust) {
  path <- list(leaf)
  pool <- c(inter, trust)
  cur <- leaf
  anchor <- NULL
  for (depth in seq_len(10L)) {
    hit <- Filter(function(c) identical(c$subject, cur$issuer), trust)
    if (length(hit)) {
      anchor <- hit[[1]]
      break
    }
    nxt <- Filter(
      function(c) {
        identical(c$subject, cur$issuer) &&
          !identical(c$der, cur$der)
      },
      pool
    )
    if (!length(nxt)) {
      break
    }
    path[[length(path) + 1L]] <- nxt[[1]]
    cur <- nxt[[1]]
  }
  .vc_note(
    acc,
    "path_to_anchor",
    !is.null(anchor),
    if (is.null(anchor)) {
      sprintf("no trust anchor issued '%s'", cur$issuer)
    } else {
      sprintf("anchored at '%s'", anchor$subject)
    }
  )
  if (!is.null(anchor)) {
    path[[length(path) + 1L]] <- anchor
  }
  attr(path, "anchor") <- anchor
  path
}

#' Every link of the path: issuer name, signature, validity, and CA-ness; then
#' the anchor.
#' @param acc The checks so far, extended by the signature links.
#' @param path The path.
#' @param attm The time checked at.
#' @noRd
.cv_links <- function(acc, path, attm) {
  for (i in seq_along(path)) {
    cert <- path[[i]]
    tag <- sprintf("[%d] %s", i, substring(cert$subject, 1L, 24L))
    within <- attm >= cert$not_before && attm <= cert$not_after
    .vc_note(
      acc,
      paste("validity", tag),
      within,
      sprintf(
        "%s to %s, checked at %s",
        format(cert$not_before, "%Y-%m-%d", tz = "UTC"),
        format(cert$not_after, "%Y-%m-%d", tz = "UTC"),
        format(attm, "%Y-%m-%d", tz = "UTC")
      )
    )
    if (i > 1L) {
      # An issuer must be a CA. Without this any leaf certificate could
      # sign a certificate for any name at all.
      .vc_note(
        acc,
        paste("is a CA", tag),
        isTRUE(cert$is_ca),
        if (isTRUE(cert$is_ca)) {
          "basicConstraints says CA"
        } else {
          "basicConstraints does not permit issuing"
        }
      )
    }
    if (i < length(path)) {
      v <- .rmbl_cert_verify_sig(cert, path[[i + 1L]])
      .vc_note(acc, paste("signature", tag), v$ok, v$detail)
    }
  }
  .cv_anchor_note(acc, path)
}

#' Notes the chain's anchor, which nothing above vouches for.
#' @param acc The accumulator of check rows.
#' @param path The certificate path, with its `anchor` attribute.
#' @return NULL, invisibly.
#' @noRd
.cv_anchor_note <- function(acc, path) {
  # a self-signed anchor is expected to be self-signed, and nothing
  # above it vouches for it -- that is what makes it an anchor
  anchor <- attr(path, "anchor")
  if (!is.null(anchor)) {
    .vc_note(
      acc,
      "anchor_self_signed",
      TRUE,
      if (isTRUE(anchor$self_signed)) {
        "the anchor is self-signed, as an anchor is"
      } else {
        "the anchor was supplied as trusted, not derived"
      }
    )
  }
  invisible(NULL)
}

#' certchnvrf()'s policy tree, with its check row when one is asked for.
#' @param acc The accumulator of check rows.
#' @param path The certificate path whose policies are checked.
#' @param pols As for certchnvrf().
#' @return The policy tree.
#' @noRd
.cv_policies <- function(acc, path, pols) {
  pol <- .rmbl_policy_tree(
    path,
    initial = if (is.null(pols)) {
      kAnyPolicy
    } else {
      pols
    }
  )
  if (!is.null(pols) || isTRUE(pol$explicit_required)) {
    .cv_policy_row(acc, pol)
  }
  pol
}

#' Name constraints. Each CA in the path constrains everything below it, so the
#' check runs for every pair, not only for the leaf: a CA constrained to one
#' name space must not be able to issue an intermediate that escapes it.
#' @param acc The checks so far, extended by the name constraints.
#' @param path The path.
#' @noRd
.cv_name_constraints <- function(acc, path) {
  if (length(path) <= 1L) {
    return(invisible(NULL))
  }
  for (up in seq(2L, length(path))) {
    nc <- path[[up]]$name_constraints
    if (is.null(nc)) {
      next
    }
    for (down in seq_len(up - 1L)) {
      probs <- .rmbl_nc_check_one(path[[down]], nc)
      .vc_note(
        acc,
        sprintf("name constraints [%d under %d]", down, up),
        length(probs) == 0L,
        if (length(probs)) {
          paste(probs, collapse = "; ")
        } else {
          "within the permitted name space"
        }
      )
    }
  }
}

#' pathLenConstraint: how many CAs a CA permits beneath it. Counted in
#' non-self-issued intermediates, as RFC 5280 counts them.
#' @param acc The checks so far, extended by the path length check.
#' @param path The path.
#' @noRd
.cv_path_len <- function(acc, path) {
  if (length(path) <= 2L) {
    return(invisible(NULL))
  }
  for (up in seq(2L, length(path))) {
    pl <- .rmbl_na_int(path[[up]]$path_len)
    if (is.na(pl)) {
      next
    }
    below <- up - 2L
    .vc_note(
      acc,
      sprintf("path length [%d]", up),
      below <= pl,
      sprintf(
        "permits %d intermediate(s) below it, path has %d",
        pl,
        below
      )
    )
  }
}

#' The certificate-policies row.
#' @param acc The checks so far, extended by the policy row.
#' @param pol The policy tree's result.
#' @noRd
.cv_policy_row <- function(acc, pol) {
  .vc_note(
    acc,
    "certificate policies",
    pol$ok,
    if (pol$ok) {
      sprintf(
        "acceptable: %s",
        toString(utils::head(pol$authorities_constrained_to, 4L))
      )
    } else {
      paste(
        c(
          "no acceptable policy survives the path",
          pol$notes
        ),
        collapse = "; "
      )
    }
  )
}

#' The leaf's extended key usage against the purpose asked for.
#' @param acc The checks so far, extended by the purpose check.
#' @param leaf The leaf.
#' @param purp As for certchnvrf().
#' @noRd
.cv_purpose <- function(acc, leaf, purp) {
  want <- .rmbl_eku_oid(purp)
  have <- leaf$extended_key_usage
  ok <- length(have) == 0L || want %in% .rmbl_eku_oid(have)
  .vc_note(
    acc,
    "purpose",
    ok && length(have) > 0L,
    if (length(have) == 0L) {
      "the leaf states no extended key usage at all"
    } else {
      sprintf("leaf permits: %s", toString(have))
    }
  )
}

#' Revocation: the CRLs supplied, and with rvk = "fetch" the ones the
#' certificates point to.
#'
#' Fetching is opt-in and never the default. A verifier that reaches out during
#' a check stops working offline, and tells whoever runs the responder which
#' certificates are being checked and when.
#' @param acc The checks so far, extended by the revocation checks.
#' @param path The path.
#' @param crls,rvk,attm As for certchnvrf().
#' @noRd
.cv_revocation <- function(acc, path, crls, rvk, attm) {
  if (identical(rvk, "fetch")) {
    fetched <- .rmbl_revocation_fetch(path)
    crls <- c(crls, fetched$crls)
    for (i in seq_along(fetched$notes)) {
      .vc_note(acc, names(fetched$notes)[i], fetched$ok[i], fetched$notes[[i]])
    }
  }
  if (length(crls) && !identical(rvk, "none")) {
    rv <- .rmbl_crl_check(path, crls, attm)
    for (i in seq_len(nrow(rv))) {
      .vc_note(acc, rv$check[i], rv$ok[i], rv$detail[i])
    }
  }
}

# ---------------------------------------------------------------- #
# The pieces
# ---------------------------------------------------------------- #

#' Renders a distinguished name as text.
#'
#' A distinguished name, rendered the way a person reads it. Only the
#' attributes anyone looks at are named; the rest keep their OIDs, which
#' is honest about what was in the certificate.
#' @param nd The parsed Name node.
#' @return One string such as `"CN=..., O=..."`.
#' @noRd
.rmbl_x509_name <- function(nd) {
  short <- c(
    "2.5.4.3" = "CN",
    "2.5.4.6" = "C",
    "2.5.4.7" = "L",
    "2.5.4.8" = "ST",
    "2.5.4.10" = "O",
    "2.5.4.11" = "OU",
    "1.2.840.113549.1.9.1" = "emailAddress"
  )
  parts <- character(0)
  for (rdn in nd$children) {
    for (atv in rdn$children) {
      if (length(atv$children) < 2L) {
        next
      }
      oid <- .rmbl_oid_string(atv$children[[1]]$value)
      nm <- if (oid %in% names(short)) short[[oid]] else oid
      val <- tryCatch(rawToChar(atv$children[[2]]$value), error = function(e) {
        ""
      })
      parts <- c(parts, sprintf("%s=%s", nm, val))
    }
  }
  toString(parts)
}

#' Reads a UTCTime or GeneralizedTime.
#'
#' UTCTime is two-digit years, with the 1950 pivot RFC 5280 mandates;
#' GeneralizedTime is four. Getting the pivot wrong puts a 2049
#' certificate in 1949.
#' @param nd The parsed time node.
#' @return A POSIXct time in UTC.
#' @noRd
.rmbl_x509_time <- function(nd) {
  s <- tryCatch(rawToChar(nd$value), error = function(e) "")
  s <- sub("Z$", "", s)
  if (identical(nd$tag, 23)) {
    yy <- as.integer(substring(s, 1L, 2L))
    century <- if (yy >= 50L) "19" else "20"
    s <- paste0(century, s)
  }
  as.POSIXct(
    strptime(substring(s, 1L, 14L), "%Y%m%d%H%M%S", tz = "UTC"),
    tz = "UTC"
  )
}

#' Reads the certificate extensions that path validation uses.
#' @param k The children of the TBSCertificate node.
#' @return A list with the CA flag, path length, key usage, extended key usage,
#'   subject alternative names, name constraints, policies, policy mappings and
#'   the policy constraint counters.
#' @noRd
.rmbl_x509_extensions <- function(k) {
  out <- list(
    is_ca = FALSE,
    path_len = NA_integer_,
    key_usage = character(0),
    eku = character(0),
    san = list(),
    name_constraints = NULL,
    policies = character(0),
    policy_mappings = NULL,
    require_explicit_policy = NA_integer_,
    inhibit_policy_mapping = NA_integer_,
    inhibit_any_policy = NA_integer_
  )
  ext <- NULL
  for (nd in k) {
    if (identical(nd$class, 2L) && identical(nd$tag, 3)) ext <- nd
  }
  if (is.null(ext) || !length(ext$children)) {
    return(out)
  }
  handlers <- .rmbl_x509_ext_handlers()
  for (e in ext$children[[1]]$children) {
    if (length(e$children) < 2L) {
      next
    }
    oid <- .rmbl_oid_string(e$children[[1]]$value)
    val <- e$children[[length(e$children)]]$value
    inner <- tryCatch(.Call(C_rmbl_der_parse, val), error = function(z) NULL)
    if (is.null(inner)) {
      next
    }
    h <- handlers[[oid]]
    if (!is.null(h)) {
      out <- h(out, inner, val)
    }
  }
  out
}

#' The certificate extensions read, by OID: each handler takes the fields read
#' so far, the parsed extension value and its bytes, and returns the fields.
#' @return A named list of functions.
#' @noRd
.rmbl_x509_ext_handlers <- function() {
  list(
    # basicConstraints: SEQUENCE { cA BOOLEAN DEFAULT FALSE, ... }
    "2.5.29.19" = function(out, inner, val) {
      kids <- inner$children
      out$is_ca <- length(kids) >= 1L &&
        identical(kids[[1]]$tag, 1) &&
        length(kids[[1]]$value) >= 1L &&
        kids[[1]]$value[1] != as.raw(0)
      # pathLenConstraint, when present, caps how many CAs may appear
      # below this one
      for (kk in kids) {
        if (identical(kk$tag, 2)) out$path_len <- .rmbl_int_of(kk$value)
      }
      out
    },
    "2.5.29.37" = function(out, inner, val) {
      out$eku <- vapply(
        inner$children,
        function(z) .rmbl_oid_string(z$value),
        character(1)
      )
      out
    },
    "2.5.29.15" = function(out, inner, val) {
      out$key_usage <- .rmbl_key_usage_bits(inner$value)
      out
    },
    "2.5.29.17" = function(out, inner, val) {
      out$san <- .rmbl_general_names(inner)
      out
    },
    "2.5.29.30" = function(out, inner, val) {
      out$name_constraints <- .rmbl_name_constraints(val)
      out
    },
    "2.5.29.32" = .rmbl_ext_policies,
    "2.5.29.33" = .rmbl_ext_policy_mappings,
    "2.5.29.36" = .rmbl_ext_policy_constraints,
    "2.5.29.54" = function(out, inner, val) {
      out$inhibit_any_policy <- .rmbl_int_of(inner$value)
      out
    }
  )
}

#' certificatePolicies: SEQUENCE OF PolicyInformation, whose first field is the
#' identifier. Qualifiers are not processed.
#' @param out The fields read so far.
#' @param inner The parsed extension value.
#' @param val Its bytes.
#' @return The fields.
#' @noRd
.rmbl_ext_policies <- function(out, inner, val) {
  out$policies <- unlist(lapply(inner$children, function(pi) {
    if (!length(pi$children)) {
      return(NULL)
    }
    .rmbl_oid_string(pi$children[[1]]$value)
  }))
  if (is.null(out$policies)) {
    out$policies <- character(0)
  }
  out
}

#' policyMappings: issuer and subject domain policies.
#' @param out,inner,val As for .rmbl_ext_policies().
#' @return The fields.
#' @noRd
.rmbl_ext_policy_mappings <- function(out, inner, val) {
  out$policy_mappings <- lapply(inner$children, function(m) {
    if (length(m$children) < 2L) {
      return(NULL)
    }
    list(
      issuer = .rmbl_oid_string(m$children[[1]]$value),
      subject = .rmbl_oid_string(m$children[[2]]$value)
    )
  })
  out$policy_mappings <- Filter(Negate(is.null), out$policy_mappings)
  out
}

#' policyConstraints: requireExplicitPolicy [0] and inhibitPolicyMapping [1].
#' @param out,inner,val As for .rmbl_ext_policies().
#' @return The fields.
#' @noRd
.rmbl_ext_policy_constraints <- function(out, inner, val) {
  for (pc in inner$children) {
    if (!identical(pc$class, 2L)) {
      next
    }
    v <- .rmbl_int_of(pc$value)
    if (identical(pc$tag, 0)) {
      out$require_explicit_policy <- v
    }
    if (identical(pc$tag, 1)) out$inhibit_policy_mapping <- v
  }
  out
}

#' Names the bits set in a keyUsage BIT STRING.
#' @param v The BIT STRING's content bytes, unused-bits byte first.
#' @return A character vector of key usage names.
#' @noRd
.rmbl_key_usage_bits <- function(v) {
  if (length(v) < 2L) {
    return(character(0))
  }
  names9 <- c(
    "digitalSignature",
    "nonRepudiation",
    "keyEncipherment",
    "dataEncipherment",
    "keyAgreement",
    "keyCertSign",
    "cRLSign",
    "encipherOnly",
    "decipherOnly"
  )
  bits <- character(0)
  body <- v[-1]
  for (i in seq_along(names9)) {
    byte <- (i - 1L) %/% 8L + 1L
    if (byte > length(body)) {
      break
    }
    bit <- 7L - ((i - 1L) %% 8L)
    if (bitwAnd(as.integer(body[byte]), bitwShiftL(1L, bit)) != 0L) {
      bits <- c(bits, names9[i])
    }
  }
  bits
}

#' Maps extended key usage names to their OIDs.
#' @param x Names such as `"codeSigning"` or OIDs.
#' @return A character vector of OIDs; anything unknown is kept as given.
#' @noRd
.rmbl_eku_oid <- function(x) {
  map <- c(
    timeStamping = "1.3.6.1.5.5.7.3.8",
    codeSigning = "1.3.6.1.5.5.7.3.3",
    serverAuth = "1.3.6.1.5.5.7.3.1",
    clientAuth = "1.3.6.1.5.5.7.3.2",
    emailProtection = "1.3.6.1.5.5.7.3.4",
    OCSPSigning = "1.3.6.1.5.5.7.3.9",
    anyExtendedKeyUsage = "2.5.29.37.0"
  )
  vapply(
    as.character(x),
    function(v) {
      if (v %in% names(map)) map[[v]] else v
    },
    character(1),
    USE.NAMES = FALSE
  )
}

#' Names a signature algorithm OID.
#' @param oid The OID as a dotted string.
#' @return A name such as `"RSA-SHA256"`, or the OID when it is not known.
#' @noRd
.rmbl_x509_sigalg_name <- function(oid) {
  switch(
    oid,
    "1.2.840.113549.1.1.11" = "RSA-SHA256",
    "1.2.840.113549.1.1.12" = "RSA-SHA384",
    "1.2.840.113549.1.1.13" = "RSA-SHA512",
    "1.2.840.113549.1.1.5" = "RSA-SHA1",
    "1.2.840.10045.4.3.2" = "ECDSA-SHA256",
    "1.2.840.10045.4.3.3" = "ECDSA-SHA384",
    "1.2.840.10045.4.3.4" = "ECDSA-SHA512",
    oid
  )
}

#' The public key, whichever kind it is.
#' @param spki The parsed SubjectPublicKeyInfo node.
#' @return A list with `type` and `bits`, plus the modulus and exponent of an
#'   RSA key or the curve and point of an EC key.
#' @noRd
.rmbl_x509_key <- function(spki) {
  alg <- spki$children[[1]]
  oid <- .rmbl_oid_string(alg$children[[1]]$value)
  bits <- spki$children[[2]]$value
  inner <- if (length(bits) > 1L) bits[-1] else raw(0)
  if (identical(oid, "1.2.840.113549.1.1.1")) {
    .rmbl_x509_rsa_key(inner)
  } else if (identical(oid, "1.2.840.10045.2.1")) {
    .rmbl_x509_ec_key(alg, inner)
  } else {
    list(type = oid, bits = 0L)
  }
}

#' An RSA public key from a SubjectPublicKeyInfo's key bytes.
#' @param inner The key bytes (the BIT STRING without its unused-bits octet).
#' @return A list: type, bits, modulus and exponent.
#' @noRd
.rmbl_x509_rsa_key <- function(inner) {
  rsa <- tryCatch(.Call(C_rmbl_der_parse, inner), error = function(e) NULL)
  if (is.null(rsa) || length(rsa$children) < 2L) {
    return(list(type = "unknown", bits = 0L))
  }
  strip <- function(v) {
    while (length(v) > 1L && v[1] == as.raw(0)) {
      v <- v[-1]
    }
    v
  }
  m <- strip(rsa$children[[1]]$value)
  list(
    type = "RSA",
    bits = 8L * length(m),
    modulus = m,
    exponent = strip(rsa$children[[2]]$value)
  )
}

#' An EC public key from a SubjectPublicKeyInfo.
#' @param alg The AlgorithmIdentifier node (it names the curve).
#' @param inner The key bytes (the BIT STRING without its unused-bits octet).
#' @return A list: type, bits, curve and, for an uncompressed point, x and y.
#' @noRd
.rmbl_x509_ec_key <- function(alg, inner) {
  curve <- if (length(alg$children) >= 2L) {
    .rmbl_oid_string(alg$children[[2]]$value)
  } else {
    NA_character_
  }
  nm <- switch(
    curve,
    "1.2.840.10045.3.1.7" = "P-256",
    "1.3.132.0.34" = "P-384",
    "1.3.132.0.35" = "P-521",
    NA_character_
  )
  if (is.na(nm) || !length(inner) || inner[1] != as.raw(0x04)) {
    # a compressed point would need decompression, which is not done
    return(list(type = "EC", bits = 0L, curve = curve))
  }
  n <- (length(inner) - 1L) %/% 2L
  list(
    type = "EC",
    bits = 8L * n,
    curve = nm,
    x = inner[2:(1L + n)],
    y = inner[(2L + n):(1L + 2L * n)]
  )
}

#' A certificate's signature bytes, without the unused-bits octet.
#' @param sig_bits The BIT STRING's content.
#' @return The signature as raw bytes.
#' @noRd
.rmbl_x509_sig_bits <- function(sig_bits) {
  if (!length(sig_bits)) {
    stop("the certificate has no signature", call. = FALSE)
  }
  sig_bits[-1] # drop the unused-bits octet
}

#' A TBSCertificate's version and the offset it gives the later fields.
#' @param k The TBSCertificate's children.
#' @return A list: off (0 or 1) and version.
#' @noRd
.rmbl_x509_version <- function(k) {
  # an explicit [0] version shifts every following field along by one
  off <- if (
    length(k) && identical(k[[1]]$class, 2L) && identical(k[[1]]$tag, 0)
  ) {
    1L
  } else {
    0L
  }
  version <- if (off == 1L) {
    as.integer(k[[1]]$children[[1]]$value[1]) + 1L
  } else {
    1L
  }
  list(off = off, version = version)
}

#' One certificate's signature, under its issuer's key.
#' @param cert The parsed certificate.
#' @param issuer The parsed issuer certificate.
#' @return A list with `ok` and `detail`.
#' @noRd
.rmbl_cert_verify_sig <- function(cert, issuer) {
  name <- cert$signature_algorithm
  key <- issuer$key
  dalg <- if (grepl("SHA256", name, fixed = TRUE)) {
    "sha256"
  } else if (grepl("SHA384", name, fixed = TRUE)) {
    "sha384"
  } else if (grepl("SHA512", name, fixed = TRUE)) {
    "sha512"
  } else {
    NA_character_
  }
  if (is.na(dalg)) {
    return(list(
      ok = FALSE,
      detail = sprintf("%s is not verified here", name)
    ))
  }
  if (startsWith(name, "RSA")) {
    return(.rmbl_cert_verify_rsa(cert, key, name, dalg))
  }
  if (startsWith(name, "ECDSA")) {
    return(.rmbl_cert_verify_ecdsa(cert, key, name, dalg))
  }
  list(ok = FALSE, detail = sprintf("%s is not verified here", name))
}

#' One certificate's RSA signature, under its issuer's key.
#' @param cert The parsed certificate.
#' @param key The issuer's parsed key.
#' @param name The signature algorithm's name.
#' @param dalg The digest algorithm of the RSA signature.
#' @return A list with `ok` and `detail`.
#' @noRd
.rmbl_cert_verify_rsa <- function(cert, key, name, dalg) {
  if (!identical(key$type, "RSA")) {
    return(list(
      ok = FALSE,
      detail = "the issuer's key is not an RSA key"
    ))
  }
  em <- tryCatch(
    .Call(
      C_rmbl_rsa_recover,
      cert$signature,
      key$modulus,
      key$exponent
    ),
    error = function(e) NULL
  )
  if (is.null(em)) {
    return(list(ok = FALSE, detail = "the RSA operation failed"))
  }
  r <- .rmbl_pkcs1_check(em, dalg, cert$tbs)
  list(ok = r$ok, detail = paste(name, r$detail))
}

#' One certificate's ECDSA signature, under its issuer's key.
#' @param cert The parsed certificate.
#' @param key The issuer's parsed key.
#' @param name The signature algorithm's name.
#' @param dalg The digest algorithm of the ECDSA signature.
#' @return A list with `ok` and `detail`.
#' @noRd
.rmbl_cert_verify_ecdsa <- function(cert, key, name, dalg) {
  if (!identical(key$type, "EC") || is.null(key$x)) {
    return(list(
      ok = FALSE,
      detail = "the issuer's key is not a usable EC key"
    ))
  }
  rs <- .rmbl_ecdsa_rs(cert$signature)
  if (is.null(rs)) {
    return(list(ok = FALSE, detail = "the ECDSA signature is malformed"))
  }
  dig <- .rmbl_ts_digest(dalg, cert$tbs)
  ok <- tryCatch(
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
    ok = isTRUE(ok),
    detail = sprintf(
      "%s on %s",
      name,
      key$curve
    )
  )
}

#' An ECDSA signature is SEQUENCE { INTEGER r, INTEGER s }.
#' @param sig The DER signature bytes.
#' @return A list with raw `r` and `s`, or NULL when the encoding is not
#'   canonical.
#' @noRd
.rmbl_ecdsa_rs <- function(sig) {
  d <- tryCatch(.Call(C_rmbl_der_parse, sig), error = function(e) NULL)
  # ECDSA-Sig-Value ::= SEQUENCE { r INTEGER, s INTEGER } and nothing else:
  # an extra element, a different tag or a non-canonical INTEGER (a
  # superfluous leading zero, or a negative value) is not a signature,
  # however its r and s read. Wycheproof's malleability vectors are the
  # test for exactly these.
  if (
    is.null(d) ||
      d$class != 0L ||
      !isTRUE(d$constructed) ||
      d$tag != 16 ||
      length(d$children) != 2L
  ) {
    return(NULL)
  }
  r <- .rmbl_der_uint(d$children[[1]])
  s <- .rmbl_der_uint(d$children[[2]])
  if (is.null(r) || is.null(s)) {
    return(NULL)
  }
  list(r = r, s = s)
}

#' A canonical non-negative DER INTEGER's magnitude bytes.
#' @param nd The parsed node.
#' @return The bytes without the sign byte, or NULL when it is not a canonical
#'   non-negative INTEGER.
#' @noRd
.rmbl_der_uint <- function(nd) {
  v <- nd$value
  if (
    nd$class != 0L || isTRUE(nd$constructed) || nd$tag != 2 || length(v) == 0L
  ) {
    return(NULL)
  }
  if (as.integer(v[1]) >= 0x80L) {
    return(NULL)
  } # negative
  if (length(v) > 1L && v[1] == as.raw(0) && as.integer(v[2]) < 0x80L) {
    return(NULL) # padded
  }
  if (length(v) > 1L && v[1] == as.raw(0)) {
    v <- v[-1]
  }
  v
}

#' Revocation, against a CRL that was handed in. Nothing is fetched.
#' @param path The parsed certificates of the path.
#' @param crls The CRLs, as DER bytes or PEM text.
#' @param at_time The time of the check.
#' @return A data frame with `check`, `ok` and `detail`, one row per
#'   certificate.
#' @noRd
.rmbl_crl_check <- function(path, crls, at_time) {
  acc <- new.env(parent = emptyenv())
  acc$rows <- list()
  add <- function(check, ok, detail) {
    acc$rows[[length(acc$rows) + 1L]] <- data.frame(
      check = check,
      ok = ok,
      detail = detail,
      stringsAsFactors = FALSE
    )
  }
  revoked <- unlist(lapply(crls, .rmbl_crl_serials))
  if (is.null(revoked)) {
    revoked <- character(0)
  }
  if (!length(revoked)) {
    add("revocation", TRUE, "the CRLs supplied list nothing revoked")
    return(do.call(rbind, acc$rows))
  }
  for (i in seq_along(path)) {
    cert <- path[[i]]
    hit <- tolower(cert$serial) %in% tolower(revoked)
    add(
      sprintf("revocation [%d]", i),
      !hit,
      if (hit) {
        sprintf("serial %s is on a CRL", cert$serial)
      } else {
        "not listed"
      }
    )
  }
  do.call(rbind, acc$rows)
}

#' The serial numbers one CRL lists as revoked.
#'
#' TBSCertList: version?, signature, issuer, thisUpdate, nextUpdate?,
#' revokedCertificates?  The revoked list is the first SEQUENCE OF whose members
#' open with an INTEGER serial and a time.
#' @param cr The CRL (bytes or PEM text).
#' @return The serials in hex (none when the CRL does not parse).
#' @noRd
.rmbl_crl_serials <- function(cr) {
  der <- tryCatch(.rmbl_as_bytes(cr, "crl"), error = function(e) NULL)
  if (is.null(der)) {
    return(character(0))
  }
  d <- tryCatch(.Call(C_rmbl_der_parse, der), error = function(e) NULL)
  if (is.null(d) || !length(d$children)) {
    return(character(0))
  }
  revoked <- character(0)
  for (nd in d$children[[1]]$children) {
    if (!isTRUE(nd$constructed) || !identical(nd$tag, 16)) {
      next
    }
    kids <- nd$children
    looks <- length(kids) > 0L &&
      isTRUE(kids[[1]]$constructed) &&
      length(kids[[1]]$children) >= 2L &&
      identical(kids[[1]]$children[[1]]$tag, 2)
    if (!looks) {
      next
    }
    for (entry in kids) {
      revoked <- c(revoked, .rmbl_hexlify(entry$children[[1]]$value))
    }
  }
  revoked
}
