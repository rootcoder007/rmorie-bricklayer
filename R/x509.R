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
#'   \itemize{
#'     \item \code{version} (integer) and \code{serial} (hex);
#'     \item \code{issuer} and \code{subject} (distinguished names as text);
#'     \item \code{not_before} and \code{not_after} (\code{POSIXct}, UTC);
#'     \item \code{signature_algorithm} (a name such as \code{"ECDSA-SHA256"})
#'       and \code{signature_oid};
#'     \item \code{signature} and \code{tbs} (raw; the signed part);
#'     \item \code{key} (a list: \code{type} \code{"RSA"} or \code{"EC"},
#'       \code{bits}, and the key values, with \code{curve} for EC);
#'     \item \code{is_ca} and \code{path_len};
#'     \item \code{key_usage} and \code{extended_key_usage} (character; EKU as
#'       OIDs);
#'     \item \code{subject_rdns}, \code{issuer_rdns}, \code{san} and
#'       \code{name_constraints};
#'     \item the policy fields \code{policies}, \code{policy_mappings} and
#'       \code{require_explicit_policy};
#'     \item the policy fields \code{inhibit_policy_mapping} and \code{inhibit_any_policy};
#'     \item \code{self_signed} (logical: issuer equals subject);
#'     \item \code{der} (the bytes).
#'   }
#'   \code{print()} shows a summary.
#' @seealso
#' [certchnvrf()],
#' [tsvrf()].
#' @examples
#' # A small test chain shipped as hexadecimal DER: a self-signed P-256 root
#' # and a leaf it issued (a throwaway test authority; trust it for nothing).
#' roothex <- paste0(
#'   "308201973082013ca003020102021452157dfd900c163c5027372ed4090b9d11748286300a06",
#'   "082a8648ce3d040302302931123010060355040a0c09726d626c207465737431133011060355",
#'   "04030c0a454332353620526f6f74301e170d3236313030323038343334315a170d3336303932",
#'   "393038343334315a302931123010060355040a0c09726d626c20746573743113301106035504",
#'   "030c0a454332353620526f6f743059301306072a8648ce3d020106082a8648ce3d0301070342",
#'   "0004624ad2e98f4566cd8f003a188f822875fa4760ed894507e8a4130a08fcb59280e958aa6c",
#'   "e6147989d155ce20d1a6d94fe109d3d2f2bc13d1394cea3520197fdda3423040300f0603551d",
#'   "130101ff040530030101ff300e0603551d0f0101ff040403020106301d0603551d0e04160414",
#'   "2ef598166f5b9e6bb65d3252cf127b2c992348ae300a06082a8648ce3d040302034900304602",
#'   "21009cd3d7968f65630677b3c7437cae5187021d553c756820d34b6a8a1240e7efb7022100a3",
#'   "c37f0a8e1f38a5263b14414e6f916962bbd36bcbaca40b07d371352de745c0")
#' leafhex <- paste0(
#'   "308201ae30820154a00302010202142fa99d48ead4c033c568837b2288f9e9bf137068300a06",
#'   "082a8648ce3d040302302931123010060355040a0c09726d626c207465737431133011060355",
#'   "04030c0a454332353620526f6f74301e170d3236313030323038343334315a170d3331313030",
#'   "313038343334315a302931123010060355040a0c09726d626c20746573743113301106035504",
#'   "030c0a4543323536204c6561663059301306072a8648ce3d020106082a8648ce3d0301070342",
#'   "00045f0ad14e657dedf3f6cc18530f9d905823b6e9f492ecc0eb1989c9ad8a11a859ebb7681a",
#'   "e5b1f579974e3c6709e824245608c448da6fe248ebf67bf727d598f4a35a305830090603551d",
#'   "1304023000300b0603551d0f040403020780301d0603551d0e04160414b1d22b6dd5987f0dfa",
#'   "0ff3a5d0140351d752e0fb301f0603551d230418301680142ef598166f5b9e6bb65d3252cf12",
#'   "7b2c992348ae300a06082a8648ce3d0403020348003045022100bc9d6ec452554adb8f33e4ac",
#'   "53d5e29620fc19528074153028ce849d98c8c15202205c841de357dbad5042daba7fb4af3724",
#'   "78d684f648e6ef23c68a3d764894c8fc")
#' hex2raw <- function(h) {
#'   as.raw(strtoi(substring(h, seq(1, nchar(h), 2), seq(2, nchar(h), 2)), 16L))
#' }
#' root <- certprs(hex2raw(roothex))
#' root
#' leaf <- certprs(hex2raw(leafhex))
#' leaf$subject
#' leaf$key$curve
#' c(leaf$not_before, leaf$not_after)
#'
#' # the same certificate from a PEM file
#' pem <- tempfile(fileext = ".pem")
#' writeLines(c("-----BEGIN CERTIFICATE-----",
#'              strsplit(jsb64enc(hex2raw(roothex)), "\n")[[1]],
#'              "-----END CERTIFICATE-----"), pem)
#' certprs(pem)$self_signed
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
  sig_bits <- top$children[[3]]$value
  if (!length(sig_bits)) {
    stop("the certificate has no signature",
      call. = FALSE
    )
  }
  sig <- sig_bits[-1] # drop the unused-bits octet

  k <- tbs$children
  # an explicit [0] version shifts every following field along by one
  off <- if (length(k) && identical(k[[1]]$class, 2L) &&
    identical(k[[1]]$tag, 0)) {
    1L
  } else {
    0L
  }
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

#' A small non-negative INTEGER's value.
#' @param v The INTEGER's content bytes.
#' @return The value as an integer, NA for no bytes.
#' @noRd
.rmbl_int_of <- function(v) {
  if (!length(v)) {
    return(NA_integer_)
  }
  r <- 0L
  for (b in as.integer(v)) r <- r * 256L + b
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

#' @export
format.bricklayer_certificate <- function(x, ...) {
  c(
    .rmbl_rule("X.509 certificate"),
    .rmbl_kv(list(
      subject = x$subject,
      issuer = x$issuer,
      serial = substring(x$serial, 1L, 32L),
      "valid from" = format(x$not_before, tz = "UTC"),
      "valid to" = format(x$not_after, tz = "UTC"),
      key = sprintf("%s %d bits", x$key$type, x$key$bits),
      signature = x$signature_algorithm,
      "is a CA" = x$is_ca,
      "key usage" = paste(x$extended_key_usage,
        collapse = ", "
      )
    )),
    .rmbl_rule()
  )
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_certificate
print.bricklayer_certificate <- .rmbl_print_via_format

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
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' # A small test chain shipped as hexadecimal DER: a self-signed P-256 root
#' # and a leaf it issued (a throwaway test authority; trust it for nothing).
#' roothex <- paste0(
#'   "308201973082013ca003020102021452157dfd900c163c5027372ed4090b9d11748286300a06",
#'   "082a8648ce3d040302302931123010060355040a0c09726d626c207465737431133011060355",
#'   "04030c0a454332353620526f6f74301e170d3236313030323038343334315a170d3336303932",
#'   "393038343334315a302931123010060355040a0c09726d626c20746573743113301106035504",
#'   "030c0a454332353620526f6f743059301306072a8648ce3d020106082a8648ce3d0301070342",
#'   "0004624ad2e98f4566cd8f003a188f822875fa4760ed894507e8a4130a08fcb59280e958aa6c",
#'   "e6147989d155ce20d1a6d94fe109d3d2f2bc13d1394cea3520197fdda3423040300f0603551d",
#'   "130101ff040530030101ff300e0603551d0f0101ff040403020106301d0603551d0e04160414",
#'   "2ef598166f5b9e6bb65d3252cf127b2c992348ae300a06082a8648ce3d040302034900304602",
#'   "21009cd3d7968f65630677b3c7437cae5187021d553c756820d34b6a8a1240e7efb7022100a3",
#'   "c37f0a8e1f38a5263b14414e6f916962bbd36bcbaca40b07d371352de745c0")
#' leafhex <- paste0(
#'   "308201ae30820154a00302010202142fa99d48ead4c033c568837b2288f9e9bf137068300a06",
#'   "082a8648ce3d040302302931123010060355040a0c09726d626c207465737431133011060355",
#'   "04030c0a454332353620526f6f74301e170d3236313030323038343334315a170d3331313030",
#'   "313038343334315a302931123010060355040a0c09726d626c20746573743113301106035504",
#'   "030c0a4543323536204c6561663059301306072a8648ce3d020106082a8648ce3d0301070342",
#'   "00045f0ad14e657dedf3f6cc18530f9d905823b6e9f492ecc0eb1989c9ad8a11a859ebb7681a",
#'   "e5b1f579974e3c6709e824245608c448da6fe248ebf67bf727d598f4a35a305830090603551d",
#'   "1304023000300b0603551d0f040403020780301d0603551d0e04160414b1d22b6dd5987f0dfa",
#'   "0ff3a5d0140351d752e0fb301f0603551d230418301680142ef598166f5b9e6bb65d3252cf12",
#'   "7b2c992348ae300a06082a8648ce3d0403020348003045022100bc9d6ec452554adb8f33e4ac",
#'   "53d5e29620fc19528074153028ce849d98c8c15202205c841de357dbad5042daba7fb4af3724",
#'   "78d684f648e6ef23c68a3d764894c8fc")
#' hex2raw <- function(h) {
#'   as.raw(strtoi(substring(h, seq(1, nchar(h), 2), seq(2, nchar(h), 2)), 16L))
#' }
#' root <- certprs(hex2raw(roothex))
#' leaf <- certprs(hex2raw(leafhex))
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
#' r <- certchnvrf(leaf, trust = root, attm = leaf$not_before + 86400,
#'                        purp = "timeStamping")
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
certchnvrf <- function(leaf, trust, inter = list(),
                              attm = Sys.time(), purp = NULL,
                              crls = list(), pols = NULL,
                              rvk = c(
                                "supplied", "fetch",
                                "none"
                              )) {
  .rmbl_no_fn(purpose = purp, policies = pols)
  if (!(inherits(attm, c("POSIXt", "Date")) || (is.numeric(attm) && !is.object(attm))) ||
        length(attm) != 1L || is.na(attm) || !is.finite(as.numeric(attm))) {
    stop("`attm` must be a single date-time (POSIXct)", call. = FALSE)
  }
  as_cert <- function(x) {
    if (inherits(x, "bricklayer_certificate")) x else certprs(x)
  }
  as_list <- function(x) {
    if (is.null(x)) {
      return(list())
    }
    if (inherits(x, "bricklayer_certificate") || is.raw(x) ||
      (is.character(x) && length(x) == 1L)) {
      list(x)
    } else {
      as.list(x)
    }
  }
  leaf <- as_cert(leaf)
  trust <- lapply(as_list(trust), as_cert)
  inter <- lapply(as_list(inter), as_cert)
  crls <- as_list(crls)
  if (!length(trust)) {
    stop("`trust` must name at least one anchor; a chain that reaches ",
      "nothing you have decided to believe proves nothing",
      call. = FALSE
    )
  }
  attm <- as.POSIXct(attm, tz = "UTC")
  rvk <- .rmbl_arg(rvk)

  acc <- new.env(parent = emptyenv())
  acc$checks <- list()
  note_row <- function(check, ok, detail = "") {
    acc$checks[[length(acc$checks) + 1L]] <- data.frame(
      check = check, ok = isTRUE(ok), detail = as.character(detail),
      stringsAsFactors = FALSE
    )
  }

  # Build the path: follow issuer names up through the intermediates
  # until an anchor is reached. A depth cap because a cycle among
  # supplied certificates would otherwise loop.
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
    nxt <- Filter(function(c) {
      identical(c$subject, cur$issuer) &&
        !identical(c$der, cur$der)
    }, pool)
    if (!length(nxt)) break
    path[[length(path) + 1L]] <- nxt[[1]]
    cur <- nxt[[1]]
  }
  note_row(
    "path_to_anchor", !is.null(anchor),
    if (is.null(anchor)) {
      sprintf("no trust anchor issued '%s'", cur$issuer)
    } else {
      sprintf("anchored at '%s'", anchor$subject)
    }
  )
  if (!is.null(anchor)) path[[length(path) + 1L]] <- anchor

  # every link: issuer name, signature, validity, and CA-ness
  for (i in seq_along(path)) {
    cert <- path[[i]]
    tag <- sprintf("[%d] %s", i, substring(cert$subject, 1L, 24L))
    within <- attm >= cert$not_before && attm <= cert$not_after
    note_row(
      paste("validity", tag), within,
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
      note_row(
        paste("is a CA", tag), isTRUE(cert$is_ca),
        if (isTRUE(cert$is_ca)) {
          "basicConstraints says CA"
        } else {
          "basicConstraints does not permit issuing"
        }
      )
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
    note_row(
      "anchor_self_signed", TRUE,
      if (isTRUE(anchor$self_signed)) {
        "the anchor is self-signed, as an anchor is"
      } else {
        "the anchor was supplied as trusted, not derived"
      }
    )
  }

  # Name constraints. Each CA in the path constrains everything below
  # it, so the check runs for every pair, not only for the leaf: a CA
  # constrained to one name space must not be able to issue an
  # intermediate that escapes it.
  if (length(path) > 1L) {
    for (up in seq(2L, length(path))) {
      nc <- path[[up]]$name_constraints
      if (is.null(nc)) next
      for (down in seq_len(up - 1L)) {
        probs <- .rmbl_nc_check_one(path[[down]], nc)
        note_row(
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

  # pathLenConstraint: how many CAs a CA permits beneath it. Counted in
  # non-self-issued intermediates, as RFC 5280 counts them.
  if (length(path) > 2L) {
    for (up in seq(2L, length(path))) {
      pl <- .rmbl_na_int(path[[up]]$path_len)
      if (is.na(pl)) next
      below <- up - 2L
      note_row(
        sprintf("path length [%d]", up), below <= pl,
        sprintf(
          "permits %d intermediate(s) below it, path has %d",
          pl, below
        )
      )
    }
  }

  pol <- .rmbl_policy_tree(path, initial = if (is.null(pols)) {
    kAnyPolicy
  } else {
    pols
  })
  if (!is.null(pols) || isTRUE(pol$explicit_required)) {
    note_row(
      "certificate policies", pol$ok,
      if (pol$ok) {
        sprintf(
          "acceptable: %s",
          paste(utils::head(pol$authorities_constrained_to, 4L),
            collapse = ", "
          )
        )
      } else {
        paste(c(
          "no acceptable policy survives the path",
          pol$notes
        ), collapse = "; ")
      }
    )
  }

  if (!is.null(purp)) {
    want <- .rmbl_eku_oid(purp)
    have <- leaf$extended_key_usage
    ok <- length(have) == 0L || want %in% .rmbl_eku_oid(have)
    note_row(
      "purpose", ok && length(have) > 0L,
      if (length(have) == 0L) {
        "the leaf states no extended key usage at all"
      } else {
        sprintf("leaf permits: %s", paste(have, collapse = ", "))
      }
    )
  }

  if (identical(rvk, "fetch")) {
    # Fetching is opt-in and never the default. A verifier that reaches
    # out during a check stops working offline, and tells whoever runs
    # the responder which certificates are being checked and when.
    fetched <- .rmbl_revocation_fetch(path)
    crls <- c(crls, fetched$crls)
    for (i in seq_along(fetched$notes)) {
      note_row(names(fetched$notes)[i], fetched$ok[i], fetched$notes[[i]])
    }
  }
  if (length(crls) && !identical(rvk, "none")) {
    rv <- .rmbl_crl_check(path, crls, attm)
    for (i in seq_len(nrow(rv))) {
      note_row(rv$check[i], rv$ok[i], rv$detail[i])
    }
  }

  df <- do.call(rbind, acc$checks)
  rownames(df) <- NULL
  out <- list(
    ok = all(df$ok), path = path, checks = df,
    at_time = attm, policies = pol
  )
  class(out) <- c("bricklayer_certpath_check", "list")
  out
}

#' @export
format.bricklayer_certpath_check <- function(x, ...) {
  c(
    .rmbl_rule(sprintf(
      "Certificate chain: %s",
      if (x$ok) "verified" else "NOT verified"
    )),
    sprintf(
      "  %d certificate(s), validity checked at %s",
      length(x$path), format(x$at_time, "%Y-%m-%d %H:%M:%S UTC",
        tz = "UTC"
      )
    ),
    .rmbl_rule(),
    sprintf(
      "  %-34s %-5s %s", substring(x$checks$check, 1L, 34L),
      ifelse(x$checks$ok, "ok", "FAIL"),
      substring(x$checks$detail, 1L, 34L)
    ),
    .rmbl_rule()
  )
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_certpath_check
print.bricklayer_certpath_check <- .rmbl_print_via_format

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
    "2.5.4.3" = "CN", "2.5.4.6" = "C", "2.5.4.7" = "L",
    "2.5.4.8" = "ST", "2.5.4.10" = "O", "2.5.4.11" = "OU",
    "1.2.840.113549.1.9.1" = "emailAddress"
  )
  parts <- character(0)
  for (rdn in nd$children) {
    for (atv in rdn$children) {
      if (length(atv$children) < 2L) next
      oid <- .rmbl_oid_string(atv$children[[1]]$value)
      nm <- if (oid %in% names(short)) short[[oid]] else oid
      val <- tryCatch(rawToChar(atv$children[[2]]$value),
        error = function(e) ""
      )
      parts <- c(parts, sprintf("%s=%s", nm, val))
    }
  }
  paste(parts, collapse = ", ")
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
  as.POSIXct(strptime(substring(s, 1L, 14L), "%Y%m%d%H%M%S", tz = "UTC"),
    tz = "UTC"
  )
}

#' Reads the certificate extensions that path validation uses.
#' @param k The children of the TBSCertificate node.
#' @return A list with the CA flag, path length, key usage, extended key usage, subject alternative names, name
#'   constraints, policies, policy mappings and the policy constraint counters.
#' @noRd
.rmbl_x509_extensions <- function(k) {
  out <- list(
    is_ca = FALSE, path_len = NA_integer_,
    key_usage = character(0), eku = character(0),
    san = list(), name_constraints = NULL,
    policies = character(0), policy_mappings = NULL,
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
      # pathLenConstraint, when present, caps how many CAs may appear
      # below this one
      for (kk in kids) {
        if (identical(kk$tag, 2)) out$path_len <- .rmbl_int_of(kk$value)
      }
    } else if (identical(oid, "2.5.29.37")) {
      out$eku <- vapply(
        inner$children,
        function(z) .rmbl_oid_string(z$value),
        character(1)
      )
    } else if (identical(oid, "2.5.29.15")) {
      out$key_usage <- .rmbl_key_usage_bits(inner$value)
    } else if (identical(oid, "2.5.29.17")) {
      out$san <- .rmbl_general_names(inner)
    } else if (identical(oid, "2.5.29.30")) {
      out$name_constraints <- .rmbl_name_constraints(val)
    } else if (identical(oid, "2.5.29.32")) {
      # certificatePolicies: SEQUENCE OF PolicyInformation, whose first
      # field is the identifier. Qualifiers are not processed.
      out$policies <- unlist(lapply(inner$children, function(pi) {
        if (!length(pi$children)) {
          return(NULL)
        }
        .rmbl_oid_string(pi$children[[1]]$value)
      }))
      if (is.null(out$policies)) out$policies <- character(0)
    } else if (identical(oid, "2.5.29.33")) {
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
    } else if (identical(oid, "2.5.29.36")) {
      for (pc in inner$children) {
        if (!identical(pc$class, 2L)) next
        v <- .rmbl_int_of(pc$value)
        if (identical(pc$tag, 0)) out$require_explicit_policy <- v
        if (identical(pc$tag, 1)) out$inhibit_policy_mapping <- v
      }
    } else if (identical(oid, "2.5.29.54")) {
      out$inhibit_any_policy <- .rmbl_int_of(inner$value)
    }
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
    "digitalSignature", "nonRepudiation", "keyEncipherment",
    "dataEncipherment", "keyAgreement", "keyCertSign",
    "cRLSign", "encipherOnly", "decipherOnly"
  )
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
  vapply(as.character(x), function(v) {
    if (v %in% names(map)) map[[v]] else v
  }, character(1), USE.NAMES = FALSE)
}

#' Names a signature algorithm OID.
#' @param oid The OID as a dotted string.
#' @return A name such as `"RSA-SHA256"`, or the OID when it is not known.
#' @noRd
.rmbl_x509_sigalg_name <- function(oid) {
  switch(oid,
    "1.2.840.113549.1.1.11" = "RSA-SHA256",
    "1.2.840.113549.1.1.12" = "RSA-SHA384",
    "1.2.840.113549.1.1.13" = "RSA-SHA512",
    "1.2.840.113549.1.1.5"  = "RSA-SHA1",
    "1.2.840.10045.4.3.2"   = "ECDSA-SHA256",
    "1.2.840.10045.4.3.3"   = "ECDSA-SHA384",
    "1.2.840.10045.4.3.4"   = "ECDSA-SHA512",
    oid
  )
}

#' The public key, whichever kind it is.
#' @param spki The parsed SubjectPublicKeyInfo node.
#' @return A list with `type` and `bits`, plus the modulus and exponent of an RSA key or the curve and point of an EC
#'   key.
#' @noRd
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
    list(
      type = "RSA", bits = 8L * length(m), modulus = m,
      exponent = strip(rsa$children[[2]]$value)
    )
  } else if (identical(oid, "1.2.840.10045.2.1")) {
    curve <- if (length(alg$children) >= 2L) {
      .rmbl_oid_string(alg$children[[2]]$value)
    } else {
      NA_character_
    }
    nm <- switch(curve,
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
      type = "EC", bits = 8L * n, curve = nm,
      x = inner[2:(1L + n)], y = inner[(2L + n):(1L + 2L * n)]
    )
  } else {
    list(type = oid, bits = 0L)
  }
}

#' One certificate's signature, under its issuer's key.
#' @param cert The parsed certificate.
#' @param issuer The parsed issuer certificate.
#' @return A list with `ok` and `detail`.
#' @noRd
.rmbl_cert_verify_sig <- function(cert, issuer) {
  name <- cert$signature_algorithm
  key <- issuer$key
  dalg <- if (grepl("SHA256", name)) {
    "sha256"
  } else if (grepl("SHA384", name)) {
    "sha384"
  } else if (grepl("SHA512", name)) {
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
    if (!identical(key$type, "RSA")) {
      return(list(
        ok = FALSE,
        detail = "the issuer's key is not an RSA key"
      ))
    }
    em <- tryCatch(
      .Call(
        C_rmbl_rsa_recover, cert$signature, key$modulus,
        key$exponent
      ),
      error = function(e) NULL
    )
    if (is.null(em)) {
      return(list(ok = FALSE, detail = "the RSA operation failed"))
    }
    r <- .rmbl_pkcs1_check(em, dalg, cert$tbs)
    return(list(ok = r$ok, detail = paste(name, r$detail)))
  }
  if (startsWith(name, "ECDSA")) {
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
        C_rmbl_ecdsa_verify, key$curve, key$x, key$y,
        rs$r, rs$s, dig
      ),
      error = function(e) FALSE
    )
    return(list(ok = isTRUE(ok), detail = sprintf(
      "%s on %s", name,
      key$curve
    )))
  }
  list(ok = FALSE, detail = sprintf("%s is not verified here", name))
}

#' An ECDSA signature is SEQUENCE { INTEGER r, INTEGER s }.
#' @param sig The DER signature bytes.
#' @return A list with raw `r` and `s`, or NULL when the encoding is not canonical.
#' @noRd
.rmbl_ecdsa_rs <- function(sig) {
  d <- tryCatch(.Call(C_rmbl_der_parse, sig), error = function(e) NULL)
  # ECDSA-Sig-Value ::= SEQUENCE { r INTEGER, s INTEGER } and nothing else:
  # an extra element, a different tag or a non-canonical INTEGER (a
  # superfluous leading zero, or a negative value) is not a signature,
  # however its r and s read. Wycheproof's malleability vectors are the
  # test for exactly these.
  if (is.null(d) || d$class != 0L || !isTRUE(d$constructed) || d$tag != 16 ||
      length(d$children) != 2L) {
    return(NULL)
  }
  int_value <- function(nd) {
    v <- nd$value
    if (nd$class != 0L || isTRUE(nd$constructed) || nd$tag != 2 ||
        length(v) == 0L) {
      return(NULL)
    }
    if (as.integer(v[1]) >= 0x80L) return(NULL)                 # negative
    if (length(v) > 1L && v[1] == as.raw(0) && as.integer(v[2]) < 0x80L) {
      return(NULL)                                               # padded
    }
    if (length(v) > 1L && v[1] == as.raw(0)) v <- v[-1]
    v
  }
  r <- int_value(d$children[[1]])
  s <- int_value(d$children[[2]])
  if (is.null(r) || is.null(s)) return(NULL)
  list(r = r, s = s)
}

#' Revocation, against a CRL that was handed in. Nothing is fetched.
#' @param path The parsed certificates of the path.
#' @param crls The CRLs, as DER bytes or PEM text.
#' @param at_time The time of the check.
#' @return A data frame with `check`, `ok` and `detail`, one row per certificate.
#' @noRd
.rmbl_crl_check <- function(path, crls, at_time) {
  acc <- new.env(parent = emptyenv())
  acc$rows <- list()
  add <- function(check, ok, detail) {
    acc$rows[[length(acc$rows) + 1L]] <- data.frame(
      check = check, ok = ok, detail = detail, stringsAsFactors = FALSE
    )
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
        revoked <- c(
          revoked,
          .rmbl_hexlify(entry$children[[1]]$value)
        )
      }
    }
  }
  if (!length(revoked)) {
    add("revocation", TRUE, "the CRLs supplied list nothing revoked")
    return(do.call(rbind, acc$rows))
  }
  for (i in seq_along(path)) {
    cert <- path[[i]]
    hit <- tolower(cert$serial) %in% tolower(revoked)
    add(
      sprintf("revocation [%d]", i), !hit,
      if (hit) {
        sprintf("serial %s is on a CRL", cert$serial)
      } else {
        "not listed"
      }
    )
  }
  do.call(rbind, acc$rows)
}
