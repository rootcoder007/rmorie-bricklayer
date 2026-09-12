# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Attestation: binding a signature to WHICH capsule, under WHICH key,
# in a form a third party can check.
#
# capsule_sign() signs a string. That is enough to prove the string was
# signed, and not enough for a verifier who was handed a directory: they
# still have to be told which scheme, which public key, and what string
# was supposed to have been signed. Everything a verifier needs has to
# travel with the capsule, or the signature proves nothing to anyone but
# the person who already knew the answer.

#' Attest a capsule, binding a signature to what it covers
#'
#' Signs a manifest's canonical digest and records everything a verifier
#' needs alongside it: the scheme, the public key, the context string, the
#' digest that was signed, and the manifest's seal if it came from a chain.
#' [capsule_check_attestation()]
#' checks the result against a manifest without being told anything
#' further.
#'
#' What this adds over [capsule_sign()]. A bare
#' signature leaves three things implicit -- which key, which scheme, and
#' which bytes. A verifier who has to be told those out of band cannot
#' check anything they were not already given, which makes the signature a
#' formality. An attestation states them, so the check is
#' `capsule_check_attestation(attestation, manifest)` and nothing
#' else.
#'
#' What it does NOT establish. That the public key belongs to whoever you
#' think it does: an attestation is only as good as the channel the key
#' arrived on. And that the manifest is true -- only that it has not
#' changed since it was signed.
#' [capsule_falsify()] is for the other
#' question.
#'
#' @param manifest A manifest, as from
#' [make_manifest()].
#' @param key A signing key from
#' [fips_keygen()] or
#' [pqc_keygen()].
#' @param context Optional context string, bound into the
#' signature for the standardised schemes; see
#' [capsule_sign()].
#' @param prehash Pre-hash, as in
#' [capsule_sign()].
#' @param note Optional free text recorded in the attestation
#' -- what the signature is meant to assert, in the signer's own words. It
#' is covered by the signature, since it is part of the digest.
#' @param attestation An attestation from
#' `capsule_attest()`.
#' @param key_expected Optional public key hex the
#' attestation must carry. Supply it when you know which key should have
#' signed: without it the check confirms the attestation is internally
#' consistent, which any key's holder could arrange.
#' @return `capsule_attest()` a list of class
#' `bricklayer_attestation`; `capsule_check_attestation()` a list
#' with `ok` and a `checks` data frame, one row per check.
#' @seealso
#' [capsule_sign()],
#' [manifest_digest()],
#' [capsule_falsify()],
#' [chain_seal()].
#' @examples
#' m <- make_manifest(list(dataset = "otis", rows = 1200L),
#'                    environment = FALSE)
#' key <- fips_keygen("ML-DSA-65")
#' att <- capsule_attest(m, key, note = "counts as published")
#'
#' # a verifier needs the attestation and the manifest, nothing else
#' res <- capsule_check_attestation(att, m)
#' res$ok
#' res$checks
#'
#' # any change to the manifest breaks it
#' m2 <- m
#' m2$meta$rows <- 1201L
#' capsule_check_attestation(att, m2)$ok
#'
#' # and so does presenting a different key
#' capsule_check_attestation(att, m,
#'   key_expected = fips_keygen("ML-DSA-65")$public)$ok
#' @export
capsule_attest <- function(manifest, key, context = NULL,
                           prehash = "none", note = NULL) {
  if (!is.list(manifest)) {
    stop("`manifest` must be a manifest from make_manifest()",
         call. = FALSE)
  }
  scheme <- .rmbl_attest_scheme(key)
  pub <- .rmbl_attest_public(key)
  ctx <- if (is.null(context)) NULL else {
    if (is.raw(context)) context else as.character(context)[1L]
  }
  # The note is inside the signed payload rather than beside it: a claim
  # that can be edited after signing is worse than no claim, because it
  # reads as if it were covered.
  payload <- list(
    digest = manifest_digest(manifest),
    scheme = scheme,
    public = pub,
    context = if (is.null(ctx)) "" else
      if (is.raw(ctx)) .rmbl_hexlify(ctx) else ctx,
    prehash = prehash,
    note = if (is.null(note)) "" else as.character(note)[1L],
    signed_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  signed <- .rmbl_attest_payload_digest(payload)
  sig <- if (identical(scheme, "xmss-sha256")) {
    capsule_sign(signed, key, scheme = "xmss")
  } else {
    capsule_sign(signed, key, context = context, prehash = prehash)
  }
  out <- c(payload, list(signature = sig))
  class(out) <- c("bricklayer_attestation", "list")
  out
}

#' @rdname capsule_attest
#' @export
capsule_check_attestation <- function(attestation, manifest,
                                      key_expected = NULL) {
  checks <- list()
  note_row <- function(check, ok, detail = "") {
    checks[[length(checks) + 1L]] <<- data.frame(
      check = check, ok = isTRUE(ok), detail = as.character(detail),
      stringsAsFactors = FALSE)
  }
  if (!inherits(attestation, "bricklayer_attestation")) {
    stop("`attestation` must come from capsule_attest()", call. = FALSE)
  }
  needed <- c("digest", "scheme", "public", "context", "prehash", "note",
              "signed_utc", "signature")
  missing <- setdiff(needed, names(attestation))
  note_row("attestation_complete", length(missing) == 0L,
           if (length(missing)) paste(missing, collapse = ", ") else "")

  got <- tryCatch(manifest_digest(manifest), error = function(e) NA_character_)
  note_row("manifest_digest", identical(got, attestation$digest),
           if (identical(got, attestation$digest)) got else
             sprintf("attested %s, manifest is %s", attestation$digest,
                     got))

  if (!is.null(key_expected)) {
    note_row("key_as_expected",
             identical(tolower(as.character(key_expected)[1L]),
                       tolower(attestation$public)),
             "the attestation carries the key it was checked against")
  }

  payload <- attestation[c("digest", "scheme", "public", "context",
                           "prehash", "note", "signed_utc")]
  signed <- .rmbl_attest_payload_digest(payload)
  ok <- FALSE
  detail <- ""
  if (length(missing) == 0L) {
    key <- tryCatch(.rmbl_attest_key_from(attestation),
                    error = function(e) NULL)
    if (is.null(key)) {
      detail <- "the attested public key is not usable for this scheme"
    } else {
      ok <- tryCatch(
        if (identical(attestation$scheme, "xmss-sha256")) {
          capsule_verify(signed, attestation$signature, key)
        } else {
          capsule_verify(signed, attestation$signature, key,
                         context = if (nzchar(attestation$context))
                           attestation$context else NULL,
                         prehash = attestation$prehash)
        },
        error = function(e) FALSE)
    }
  }
  note_row("signature", ok, detail)

  df <- do.call(rbind, checks)
  rownames(df) <- NULL
  out <- list(ok = all(df$ok), checks = df)
  class(out) <- c("bricklayer_attestation_check", "list")
  out
}

#' @export
format.bricklayer_attestation <- function(x, ...) {
  c(.rmbl_rule("Capsule attestation"),
    .rmbl_kv(list(scheme = x$scheme,
                  digest = x$digest,
                  context = if (nzchar(x$context)) x$context else "<none>",
                  prehash = x$prehash,
                  note = if (nzchar(x$note)) x$note else "<none>",
                  signed = x$signed_utc,
                  "public key" = sprintf("%s... (%d bytes)",
                                         substring(x$public, 1L, 32L),
                                         nchar(x$public) %/% 2L))),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_attestation <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @export
format.bricklayer_attestation_check <- function(x, ...) {
  c(.rmbl_rule(sprintf("Attestation check: %s",
                       if (x$ok) "OK" else "FAILED")),
    sprintf("  %-22s %-5s %s", x$checks$check,
            ifelse(x$checks$ok, "ok", "FAIL"),
            substring(x$checks$detail, 1L, 44L)),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_attestation_check <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

# The payload is signed through its own canonical digest, so the
# signature does not depend on the order the fields were assembled in --
# the same reason manifest_digest() exists.
.rmbl_attest_payload_digest <- function(payload) {
  core_sha256(charToRaw(manifest_canonical(payload)))
}

.rmbl_attest_scheme <- function(key) {
  if (inherits(key, c("bricklayer_oqs_key", "bricklayer_oqs_public_key"))) {
    return(key$scheme)
  }
  if (inherits(key, c("bricklayer_signing_key", "bricklayer_public_key"))) {
    return("xmss-sha256")
  }
  stop("`key` must come from fips_keygen() or pqc_keygen()", call. = FALSE)
}

.rmbl_attest_public <- function(key) {
  if (inherits(key, c("bricklayer_oqs_key", "bricklayer_oqs_public_key"))) {
    return(key$public)
  }
  # An XMSS public key is the root plus the public seed: both are needed
  # to verify, so both have to be recorded.
  paste0(key$root, key$pub_seed)
}

.rmbl_attest_key_from <- function(attestation) {
  if (identical(attestation$scheme, "xmss-sha256")) {
    n <- nchar(attestation$public)
    if (n != 128L) stop("an XMSS public key is 64 bytes", call. = FALSE)
    sig <- attestation$signature
    out <- list(root = substring(attestation$public, 1L, 64L),
                pub_seed = substring(attestation$public, 65L, 128L),
                height = sig$height, scheme = "xmss-sha256")
    class(out) <- c("bricklayer_public_key", "list")
    return(out)
  }
  fips_key(attestation$scheme, attestation$public)
}
