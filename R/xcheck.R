# SPDX-License-Identifier: AGPL-3.0-or-later
#
# A second, independent verdict on a signature. The package's ML-DSA and
# SLH-DSA are its own code; OpenSSL 3.5 and later implement the same FIPS
# 204 and 205 with no code in common. When both accept a signature, a bug
# in either one alone cannot have made it pass.

#' Verify a Signature Here and Again With OpenSSL
#'
#' Checks an ML-DSA or SLH-DSA signature twice: with this package's own
#' implementation
#' ([cpsvrf()])
#' and with the `openssl` program (version 3.5
#' or later), which implements FIPS 204 and 205 independently. The
#' signature counts as cross-verified only when both accept it.
#'
#' OpenSSL is never required. When it is missing, older than 3.5, or the
#' signature is one OpenSSL cannot check (XMSS, an HMAC tag, or a
#' pre-hashed signature), its verdict is `NA` with the reason, and the
#' result says the signature was verified here only.
#'
#' @details
#' The public key is written as a standard SubjectPublicKeyInfo (the
#' NIST object identifiers for each parameter set), the message and the
#' signature as raw bytes, and `openssl pkeyutl -verify -rawin` checks
#' them, with the context string passed as `hexcontext-string`. Nothing
#' is sent anywhere: the files live in a temporary folder that is removed
#' afterwards.
#'
#' @param msg The signed message: a string or a raw vector, as given to
#'   [cpssign()].
#' @param sig A signature from [cpssign()].
#' @param key The signer's key from
#'   [fipskg()] or
#'   [fipspubkey()]; only its
#'   public half is used.
#' @param ctx The context string the signature was made with, or `NULL`.
#' @return A list of class `rmbl_xvrf`: `ok` (`TRUE` only when both
#'   implementations accept the signature), `ours` and `openssl` (each
#'   verdict; `openssl` is `NA` when it could not be asked), `agree`,
#'   `version` (OpenSSL's, or `NA`), `reason` (why OpenSSL gave no
#'   verdict, or `NA`) and `scheme`. It prints as a box that opens with
#'   the verdict.
#' @seealso
#' [cpsvrf()] for this package's verdict alone,
#' [fipskg()].
#' @export
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' key <- fipskg("ML-DSA-44")
#' sig <- cpssign("a manifest digest", key, ctx = "release")
#'
#' # Both implementations accept it (or OpenSSL is reported as absent).
#' cpsxvrf("a manifest digest", sig, fipspubkey(key), ctx = "release")
#'
#' # A changed message fails in both.
#' cpsxvrf("a manifest digest!", sig, key, ctx = "release")$ok
#' @inheritParams fipsmod
cpsxvrf <- function(msg, sig, key, ctx = NULL,
                    openssl = Sys.which("openssl")) {
  if (!inherits(sig, "bricklayer_signature")) {
    stop("`sig` must come from cpssign()", call. = FALSE)
  }
  ours <- isTRUE(cpsvrf(msg, sig, key, ctx = ctx))
  ext <- .rmbl_xvrf_openssl(msg, sig, key, ctx, openssl)
  out <- list(
    ok = ours && isTRUE(ext$ok),
    ours = ours,
    openssl = ext$ok,
    agree = !is.na(ext$ok) && identical(ours, ext$ok),
    version = ext$version,
    reason = ext$reason,
    scheme = sig$scheme
  )
  class(out) <- c("rmbl_xvrf", "list")
  out
}

#' @export
format.rmbl_xvrf <- function(x, ...) {
  head <- if (isTRUE(x$ok)) {
    "Signature: VERIFIED by both implementations"
  } else if (isTRUE(x$ours) && is.na(x$openssl)) {
    "Signature: verified here; OpenSSL gave no verdict"
  } else if (isTRUE(x$ours)) {
    "Signature: NOT VERIFIED (the implementations disagree)"
  } else {
    "Signature: NOT VERIFIED"
  }
  word <- function(v) {
    if (is.na(v)) "no verdict" else if (isTRUE(v)) "accepts" else "rejects"
  }
  ossl <- if (is.na(x$version)) "OpenSSL" else x$version
  c(
    .rmbl_rule(head),
    .rmbl_kv(list(
      Scheme = x$scheme,
      `This package` = word(x$ours),
      OpenSSL = paste0(word(x$openssl), " (", ossl, ")")
    )),
    if (!is.na(x$reason)) c("", paste0("  ", .rmbl_wrap(x$reason))),
    "",
    paste0("  ", .rmbl_wrap(.rmbl_xvrf_reading(x))),
    .rmbl_rule()
  )
}

#' @export
print.rmbl_xvrf <- .rmbl_print_box

#' What a cross-verification result means, in one or two sentences.
#' @param x A result of cpsxvrf().
#' @return A string.
#' @noRd
.rmbl_xvrf_reading <- function(x) {
  if (isTRUE(x$ok)) {
    return(paste(
      "Two implementations that share no code both accept this",
      "signature, so a bug in either one alone cannot explain it."
    ))
  }
  if (isTRUE(x$ours) && is.na(x$openssl)) {
    return(paste(
      "Only this package's implementation checked it; install OpenSSL",
      "3.5 or later for an independent second verdict."
    ))
  }
  if (isTRUE(x$ours) || isTRUE(x$openssl)) {
    return(paste(
      "The two implementations disagree. Treat the signature as",
      "unverified and report the case: one of them has a bug."
    ))
  }
  "The signature does not match this message, context and key."
}

#' OpenSSL's verdict on a FIPS 204 or 205 signature.
#' @param msg,sig,key,ctx As for cpsxvrf().
#' @param openssl Path to the openssl program, or "".
#' @return A list: `ok` (TRUE, FALSE or NA), `version`, `reason`.
#' @noRd
.rmbl_xvrf_openssl <- function(msg, sig, key, ctx, openssl) {
  pre <- .rmbl_xvrf_ready(sig, openssl)
  if (!is.null(pre$none)) {
    return(pre$none)
  }
  ver <- pre$ver
  oid <- pre$oid
  pk <- .rmbl_hex_or_null(key$public)
  sg <- .rmbl_hex_or_null(sig$signature)
  if (is.null(pk) || is.null(sg) || !identical(key$scheme, sig$scheme)) {
    return(list(ok = FALSE, version = ver$label, reason = NA_character_))
  }
  d <- tempfile("rmbl-xvrf-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  f <- file.path(d, c("pub.der", "msg", "sig"))
  writeBin(.rmbl_xvrf_spki(oid, pk), f[1L])
  writeBin(.rmbl_sign_message(msg), f[2L])
  writeBin(sg, f[3L])
  q <- function(p) {
    shQuote(p, type = if (.Platform$OS.type == "windows") "cmd" else "sh")
  }
  args <- c(
    "pkeyutl", "-verify", "-pubin", "-keyform", "DER",
    "-inkey", q(f[1L]), "-rawin", "-in", q(f[2L]), "-sigfile", q(f[3L])
  )
  cx <- .rmbl_fips_context(ctx)
  if (length(cx)) {
    args <- c(args, "-pkeyopt",
              paste0("hexcontext-string:", .rmbl_hexlify(cx)))
  }
  res <- suppressWarnings(
    system2(openssl, args, stdout = TRUE, stderr = TRUE)
  )
  st <- attr(res, "status") %||% 0L
  txt <- paste(res, collapse = " ")
  if (st == 0L && grepl("Verified Successfully", txt, fixed = TRUE)) {
    return(list(ok = TRUE, version = ver$label, reason = NA_character_))
  }
  if (grepl("signature failure|Verification failure", txt)) {
    return(list(ok = FALSE, version = ver$label, reason = NA_character_))
  }
  .rmbl_xvrf_none(paste0(ver$label, " could not check it: ",
                         substr(txt, 1L, 200L)), ver$label)
}

#' The last arc of the NIST object identifier of a FIPS 204 or 205
#' parameter set (2.16.840.1.101.3.4.3.<arc>), or NA.
#' @param scheme The parameter-set name.
#' @return An integer, or NA.
#' @noRd
.rmbl_xvrf_oid <- function(scheme) {
  arcs <- c(
    "ML-DSA-44" = 17L, "ML-DSA-65" = 18L, "ML-DSA-87" = 19L,
    "SLH-DSA-SHA2-128s" = 20L, "SLH-DSA-SHA2-128f" = 21L,
    "SLH-DSA-SHA2-192s" = 22L, "SLH-DSA-SHA2-192f" = 23L,
    "SLH-DSA-SHA2-256s" = 24L, "SLH-DSA-SHA2-256f" = 25L,
    "SLH-DSA-SHAKE-128s" = 26L, "SLH-DSA-SHAKE-128f" = 27L,
    "SLH-DSA-SHAKE-192s" = 28L, "SLH-DSA-SHAKE-192f" = 29L,
    "SLH-DSA-SHAKE-256s" = 30L, "SLH-DSA-SHAKE-256f" = 31L
  )
  if (!is.character(scheme) || length(scheme) != 1L ||
      !scheme %in% names(arcs)) {
    return(NA_integer_)
  }
  arcs[[scheme]]
}

#' A public key as DER SubjectPublicKeyInfo.
#' @param arc The last arc of its algorithm's object identifier.
#' @param pk The public key bytes.
#' @return Raw DER.
#' @noRd
.rmbl_xvrf_spki <- function(arc, pk) {
  oid <- as.raw(c(0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x03, arc))
  alg <- .bl_der(0x30, .bl_der(0x06, oid))
  .bl_der(0x30, c(alg, .bl_der(0x03, c(as.raw(0), pk))))
}

#' The version the openssl program reports.
#' @param openssl Path to the program.
#' @return A list: `number` ("3.5.9" or NA) and `label` ("OpenSSL 3.5.9").
#' @noRd
.rmbl_xvrf_version <- function(openssl) {
  v <- tryCatch(
    suppressWarnings(system2(openssl, "version", stdout = TRUE,
                             stderr = TRUE)),
    error = function(e) character()
  )
  v <- paste(v, collapse = " ")
  num <- regmatches(v, regexpr("[0-9]+\\.[0-9]+\\.[0-9]+", v))
  if (!length(num)) {
    return(list(number = NA_character_, label = NA_character_))
  }
  list(number = num, label = paste("OpenSSL", num))
}

#' OpenSSL's answer when it was not asked: no verdict, and why.
#' @param reason Why OpenSSL gave no verdict.
#' @param version Its version label, when known.
#' @return A list: `ok` (NA), `version`, `reason`.
#' @noRd
.rmbl_xvrf_none <- function(reason, version = NA_character_) {
  list(ok = NA, version = version, reason = reason)
}

#' Whether OpenSSL can be asked about a signature at all.
#' @param sig The signature.
#' @param openssl Path to the openssl program, or "".
#' @return A list: `none` (the no-verdict answer, or NULL when OpenSSL can
#'   be asked), `ver` (its version) and `oid` (the scheme's arc).
#' @noRd
.rmbl_xvrf_ready <- function(sig, openssl) {
  no <- function(...) list(none = .rmbl_xvrf_none(...))
  oid <- .rmbl_xvrf_oid(sig$scheme)
  if (is.na(oid)) {
    return(no(paste("OpenSSL has no check for", sig$scheme, "signatures.")))
  }
  ph <- sig[["prehash"]]
  if (!is.null(ph) && !identical(ph, "none")) {
    return(no("OpenSSL 3.5 checks only pure (not pre-hashed) signatures."))
  }
  if (!is.character(openssl) || length(openssl) != 1L || is.na(openssl) ||
      !nzchar(openssl)) {
    return(no("The openssl program was not found on the PATH."))
  }
  ver <- .rmbl_xvrf_version(openssl)
  if (is.na(ver$number)) {
    return(no("The openssl program did not report its version."))
  }
  if (utils::compareVersion(ver$number, "3.5.0") < 0) {
    return(no(
      paste0(ver$label, " is older than 3.5, which first added ML-DSA ",
             "and SLH-DSA."),
      ver$label
    ))
  }
  list(none = NULL, ver = ver, oid = oid)
}
