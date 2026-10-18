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
#' \code{capsule_attest()} signs a manifest's canonical digest and records
#' everything a verifier needs alongside it: the scheme, the public key, the
#' context string, the pre-hash, a note and the signing time.
#' \code{capsule_check_attestation()} checks the result against a manifest
#' without being told anything further. Use them to publish a capsule
#' together with proof that its manifest has not changed since you signed it.
#'
#' @details
#' What this adds over [capsule_sign()]. A bare
#' signature leaves three things implicit -- which key, which scheme, and
#' which bytes. A verifier who has to be told those out of band cannot
#' check anything they were not already given, which makes the signature a
#' formality. An attestation states them, so the check is
#' \code{capsule_check_attestation(attestation, manifest)} and nothing
#' else.
#'
#' What is signed: the payload \code{digest}
#' ([manifest_digest()] of the
#' manifest), \code{scheme}, \code{public}, \code{context} (hex for a raw
#' context), \code{prehash}, \code{note} and \code{signed_utc} is put in
#' canonical form ([manifest_canonical()]) and its
#' SHA-256 is signed with
#' [capsule_sign()]. Every field, the note and the time
#' included, is
#' therefore covered: editing any of them breaks the signature. With an XMSS
#' key from [pqc_keygen()] the scheme is \code{"xmss-sha256"}
#' and the context
#' and pre-hash are not used by the signature; signing uses up one of the
#' key's one-time indices, as every XMSS signature does.
#'
#' The check, one row each: \code{attestation_complete} (every field is
#' present), \code{manifest_digest} (the manifest's digest equals the attested
#' one), \code{key_as_expected} (only when \code{key_expected} is given) and
#' \code{signature} (the signature verifies under the attested public key).
#' \code{ok} is \code{TRUE} when every row passes.
#'
#' What it does NOT establish. That the public key belongs to whoever you
#' think it does: an attestation is only as good as the channel the key
#' arrived on, which is why \code{key_expected} exists. And that the
#' manifest is true -- only that it has not changed since it was signed.
#' [capsule_falsify()] is for the other question. No chain
#' seal is recorded;
#' to attest a run history, sign [chain_seal()] directly.
#'
#' Errors: \code{manifest} not a list; \code{key} not from
#' [fips_keygen()]
#' or [pqc_keygen()]; an invalid \code{prehash} or
#' \code{context} (from
#' [capsule_sign()]); \code{attestation} not from
#' \code{capsule_attest()}. A
#' signature that fails to verify is a failed row, not an error.
#'
#' @param manifest A manifest, as from [make_manifest()].
#' @param key A signing key from [fips_keygen()] (ML-DSA,
#'   SLH-DSA and the
#'   other standardised schemes) or [pqc_keygen()] (XMSS).
#' @param context Optional context string (or raw vector), bound into the
#'   signature for the standardised schemes; see
#'   [capsule_sign()].
#'   \code{NULL} (the default) means none.
#' @param prehash Pre-hash, as in [capsule_sign()]:
#'   \code{"none"} (the
#'   default) or a hash name such as \code{"sha256"} or \code{"sha512"}.
#' @param note Optional free text recorded in the attestation
#'   -- what the signature is meant to assert, in the signer's own words. It
#'   is covered by the signature, since it is part of the digest.
#' @param attestation An attestation from \code{capsule_attest()}.
#' @param key_expected Optional public key the attestation must carry: hex,
#'   or a key object from [fips_keygen()],
#'   [fips_public_key()] or
#'   [signing_public_key()]. Supply it when you know
#'   which key should have
#'   signed: without it the check confirms the attestation is internally
#'   consistent, which any key's holder could arrange.
#' @return \code{capsule_attest()} a list of class
#'   \code{c("bricklayer_attestation", "list")} with the character fields
#'   \code{digest}, \code{scheme}, \code{public} (hex), \code{context},
#'   \code{prehash}, \code{note} and \code{signed_utc} (ISO 8601 UTC time), and
#'   \code{signature} (a \code{bricklayer_signature} from
#'   [capsule_sign()]).
#'   \code{capsule_check_attestation()} a list of class
#'   \code{c("bricklayer_attestation_check", "list")} with \code{ok} (logical)
#'   and \code{checks}, a data frame with columns \code{check}, \code{ok} and
#'   \code{detail}, one row per check.
#' @seealso
#' [capsule_sign()],
#' [manifest_digest()],
#' [capsule_falsify()],
#' [chain_seal()].
#' @examples
#' m <- make_manifest(list(dataset = "otis", rows = 1200L),
#'   environment = FALSE
#' )
#' key <- fips_keygen("ML-DSA-65")
#' att <- capsule_attest(m, key, note = "counts as published")
#' att
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
#'   key_expected = fips_keygen("ML-DSA-65")$public
#' )$ok
#'
#' # the note is signed too: editing it breaks the signature row
#' forged <- att
#' forged$note <- "counts corrected"
#' capsule_check_attestation(forged, m)$checks[, c("check", "ok")]
#'
#' # a context string and a pre-hash
#' att2 <- capsule_attest(m, key, context = "release 2026-10", prehash = "sha512")
#' capsule_check_attestation(att2, m, key_expected = key)$ok
#'
#' # a key that is not a signing key is refused
#' try(capsule_attest(m, "not-a-key"))
#' @export
capsule_attest <- function(manifest, key, context = NULL,
                           prehash = "none", note = NULL) {
  .rmbl_no_fn(note = note, context = context)
  if (!is.list(manifest)) {
    stop("`manifest` must be a manifest from make_manifest()",
      call. = FALSE
    )
  }
  scheme <- .rmbl_attest_scheme(key)
  pub <- .rmbl_attest_public(key)
  ctx <- if (is.null(context)) {
    NULL
  } else {
    if (is.raw(context)) context else as.character(context)[1L]
  }
  # The note is inside the signed payload rather than beside it: a claim
  # that can be edited after signing is worse than no claim, because it
  # reads as if it were covered.
  payload <- list(
    digest = manifest_digest(manifest),
    scheme = scheme,
    public = pub,
    context = if (is.null(ctx)) "" else if (is.raw(ctx)) .rmbl_hexlify(ctx) else ctx,
    prehash = prehash,
    note = if (is.null(note)) "" else as.character(note)[1L],
    signed_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  signed <- .rmbl_attest_payload_digest(payload)
  sig <- if (identical(scheme, "xmss-sha256")) {
    capsule_sign(signed, key, scheme = "xmss")
  } else {
    capsule_sign(signed, key, context = if (is.null(ctx)) NULL else payload$context, prehash = prehash)
  }
  out <- c(payload, list(signature = sig))
  class(out) <- c("bricklayer_attestation", "list")
  out
}

#' @rdname capsule_attest
#' @export
capsule_check_attestation <- function(attestation, manifest,
                                      key_expected = NULL) {
  .rmbl_no_fn(key_expected = key_expected)
  checks <- list()
  note_row <- function(check, ok, detail = "") {
    checks[[length(checks) + 1L]] <<- data.frame(
      check = check, ok = isTRUE(ok), detail = as.character(detail),
      stringsAsFactors = FALSE
    )
  }
  if (!inherits(attestation, "bricklayer_attestation")) {
    stop("`attestation` must come from capsule_attest()", call. = FALSE)
  }
  needed <- c(
    "digest", "scheme", "public", "context", "prehash", "note",
    "signed_utc", "signature"
  )
  missing <- setdiff(needed, names(attestation))
  note_row(
    "attestation_complete", length(missing) == 0L,
    if (length(missing)) paste(missing, collapse = ", ") else ""
  )

  got <- tryCatch(manifest_digest(manifest), error = function(e) NA_character_)
  attested <- attestation$digest %||% "(missing)"
  note_row(
    "manifest_digest", identical(got, attestation$digest),
    if (identical(got, attestation$digest)) {
      got
    } else {
      sprintf("attested %s, manifest is %s", as.character(attested)[1L], got)
    }
  )

  if (!is.null(key_expected)) {
    # a public-key object is accepted as well as the hex it carries: for XMSS the attestation's
    # `public` is root || pub_seed, and signing_public_key() has both
    expected_hex <- if (inherits(key_expected, c("bricklayer_public_key", "bricklayer_signing_key"))) {
      paste0(key_expected$root, key_expected$pub_seed)
    } else if (inherits(key_expected, c("bricklayer_oqs_key", "bricklayer_oqs_public_key"))) {
      key_expected$public
    } else {
      as.character(key_expected)[1L]
    }
    note_row(
      "key_as_expected",
      identical(tolower(as.character(expected_hex)), tolower(as.character(attestation$public %||% ""))),
      "the attestation carries the key it was checked against"
    )
  }

  payload <- attestation[c(
    "digest", "scheme", "public", "context",
    "prehash", "note", "signed_utc"
  )]
  signed <- .rmbl_attest_payload_digest(payload)
  ok <- FALSE
  detail <- ""
  if (length(missing) == 0L) {
    key <- tryCatch(.rmbl_attest_key_from(attestation),
      error = function(e) NULL
    )
    if (is.null(key)) {
      detail <- "the attested public key is not usable for this scheme"
    } else {
      ok <- tryCatch(
        if (identical(attestation$scheme, "xmss-sha256")) {
          capsule_verify(signed, attestation$signature, key)
        } else {
          capsule_verify(signed, attestation$signature, key,
            context = if (nzchar(attestation$context)) {
              attestation$context
            } else {
              NULL
            },
            prehash = attestation$prehash
          )
        },
        error = function(e) FALSE
      )
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
  c(
    .rmbl_rule("Capsule attestation"),
    .rmbl_kv(list(
      scheme = x$scheme,
      digest = x$digest,
      context = if (nzchar(x$context)) x$context else "<none>",
      prehash = x$prehash,
      note = if (nzchar(x$note)) x$note else "<none>",
      signed = x$signed_utc,
      "public key" = sprintf(
        "%s... (%d bytes)",
        substring(x$public, 1L, 32L),
        nchar(x$public) %/% 2L
      )
    )),
    .rmbl_rule()
  )
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_attestation <- function(x, ...) {
  if (is.list(x$signature) && !is.null(x$signature$key_state)) warning(.rmbl_key_state_warning(), call. = FALSE)
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @export
format.bricklayer_attestation_check <- function(x, ...) {
  c(
    .rmbl_rule(sprintf(
      "Attestation check: %s",
      if (x$ok) "OK" else "FAILED"
    )),
    sprintf(
      "  %-22s %-5s %s", x$checks$check,
      ifelse(x$checks$ok, "ok", "FAIL"),
      substring(x$checks$detail, 1L, 44L)
    ),
    .rmbl_rule()
  )
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
    out <- list(
      root = substring(attestation$public, 1L, 64L),
      pub_seed = substring(attestation$public, 65L, 128L),
      height = sig$height, scheme = "xmss-sha256"
    )
    class(out) <- c("bricklayer_public_key", "list")
    return(out)
  }
  fips_key(attestation$scheme, attestation$public)
}
