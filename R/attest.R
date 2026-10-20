# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Attestation: binding a signature to WHICH capsule, under WHICH key,
# in a form a third party can check.
#
# cpssign() signs a string. That is enough to prove the string was
# signed, and not enough for a verifier who was handed a directory: they
# still have to be told which scheme, which public key, and what string
# was supposed to have been signed. Everything a verifier needs has to
# travel with the capsule, or the signature proves nothing to anyone but
# the person who already knew the answer.

#' Attest a capsule, binding a signature to what it covers
#'
#' \code{cpsatst()} signs a manifest's canonical digest and records
#' everything a verifier needs alongside it: the scheme, the public key, the
#' context string, the pre-hash, a note and the time of signing.
#' \code{cpschkatst()} checks the result against a manifest
#' without being told anything further. Use them to publish a capsule
#' together with proof that its manifest has not changed since you signed it.
#'
#' @details
#' What this adds over [cpssign()]. A bare
#' signature leaves three things implicit -- which key, which scheme, and
#' which bytes. A verifier who has to be told those out of band cannot
#' check anything they were not already given, which makes the signature a
#' formality. An attestation states them, so the check is
#' \code{cpschkatst(attestation, manifest)} and nothing
#' else.
#'
#' What is signed: the payload \code{digest}
#' ([mnfdgst()] of the
#' manifest), \code{scheme}, \code{public}, \code{ctx} (hex for a raw
#' context), \code{prehash}, \code{note} and \code{signed_utc} is put in
#' canonical form ([mnfcanon()]) and its
#' SHA-256 is signed with
#' [cpssign()]. Every field, the note and the time
#' included, is
#' therefore covered: editing any of them breaks the signature. With an XMSS
#' key from [pqckg()] the scheme is \code{"xmss-sha256"}
#' and the context
#' and pre-hash are not used by the signature; signing uses up one of the
#' key's one-time indices, as every XMSS signature does.
#'
#' The check, one row each: \code{attestation_complete} (every field is
#' present), \code{mnfdgst} (the manifest's digest equals the attested
#' one), \code{key_as_expected} (only when \code{keyexp} is given) and
#' \code{signature} (the signature verifies under the attested public key).
#' \code{ok} is \code{TRUE} when every row passes.
#'
#' What it does NOT establish. That the public key belongs to whoever you
#' think it does: an attestation is only as good as the channel the key
#' arrived on, which is why \code{keyexp} exists. And that the
#' manifest is true -- only that it has not changed since it was signed.
#' [cpsfals()] is for the other question. No chain
#' seal is recorded;
#' to attest a run history, sign [chnseal()] directly.
#'
#' Errors: \code{man} not a list; \code{key} not from
#' [fipskg()]
#' or [pqckg()]; an invalid \code{prehash} or
#' \code{ctx} (from
#' [cpssign()]); \code{attestation} not from
#' \code{cpsatst()}. A
#' signature that fails to verify is a failed row, not an error.
#'
#' @param man A manifest, as from [mkmnf()].
#' @param key A signing key from [fipskg()] (ML-DSA,
#'   SLH-DSA and the
#'   other standardised schemes) or [pqckg()] (XMSS).
#' @param ctx Optional context string (or raw vector), bound into the
#'   signature for the standardised schemes; see
#'   [cpssign()].
#'   \code{NULL} (the default) means none.
#' @param prehash Pre-hash, as in [cpssign()]. It is \code{"none"} (the
#'   default) or a hash name such as \code{"sha256"} or \code{"sha512"}.
#' @param note Optional free text recorded in the attestation
#'   -- what the signature is meant to assert, in the signer's own words. It
#'   is covered by the signature, since it is part of the digest.
#' @param attest An attestation from \code{cpsatst()}.
#' @param keyexp Optional public key the attestation must carry, as hex
#'   or as a key object from [fipskg()],
#'   [fipspubkey()] or
#'   [signpubkey()]. Supply it when you know
#'   which key should have
#'   signed: without it the check confirms the attestation is internally
#'   consistent, which any key's holder could arrange.
#' @return \code{cpsatst()} a list of class \code{bricklayer_attestation} with the
#'   character fields
#'   \code{digest}, \code{scheme}, \code{public} (hex), \code{context},
#'   \code{prehash}, \code{note} and \code{signed_utc} (ISO 8601 UTC time), and
#'   \code{signature} (a \code{bricklayer_signature} from
#'   [cpssign()]).
#'
#'   \code{cpschkatst()} a list of class \code{bricklayer_attestation_check}
#'   with \code{ok} (logical)
#'   and \code{checks}, a data frame with columns \code{check}, \code{ok} and
#'   \code{detail}, one row per check.
#' @seealso
#' [cpssign()],
#' [mnfdgst()],
#' [cpsfals()],
#' [chnseal()].
#' @examples
#' m <- mkmnf(list(dataset = "otis", rows = 1200L),
#'   env = FALSE
#' )
#' key <- fipskg("ML-DSA-65")
#' att <- cpsatst(m, key, note = "counts as published")
#' att
#'
#' # a verifier needs the attestation and the manifest, nothing else
#' res <- cpschkatst(att, m)
#' res$ok
#' res$checks
#'
#' # any change to the manifest breaks it
#' m2 <- m
#' m2$meta$rows <- 1201L
#' cpschkatst(att, m2)$ok
#'
#' # and so does presenting a different key
#' cpschkatst(att, m,
#'   keyexp = fipskg("ML-DSA-65")$public
#' )$ok
#'
#' # the note is signed too: editing it breaks the signature row
#' forged <- att
#' forged$note <- "counts corrected"
#' cpschkatst(forged, m)$checks[, c("check", "ok")]
#'
#' # a context string and a pre-hash
#' att2 <- cpsatst(m, key, ctx = "release 2026-10", prehash = "sha512")
#' cpschkatst(att2, m, keyexp = key)$ok
#'
#' # a key that is not a signing key is refused
#' try(cpsatst(m, "not-a-key"))
#' @export
cpsatst <- function(man, key, ctx = NULL,
                           prehash = "none", note = NULL) {
  .rmbl_no_fn(note = note, context = ctx)
  if (!is.list(man)) {
    stop("`man` must be a manifest from mkmnf()",
      call. = FALSE
    )
  }
  scheme <- .rmbl_attest_scheme(key)
  pub <- .rmbl_attest_public(key)
  .ctx <- if (is.null(ctx)) {
    NULL
  } else {
    if (is.raw(ctx)) ctx else as.character(ctx)[1L]
  }
  # The note is inside the signed payload rather than beside it: a claim
  # that can be edited after signing is worse than no claim, because it
  # reads as if it were covered.
  payload <- list(
    digest = mnfdgst(man),
    scheme = scheme,
    public = pub,
    context = if (is.null(.ctx)) "" else if (is.raw(.ctx)) .rmbl_hexlify(.ctx) else .ctx,
    prehash = prehash,
    note = if (is.null(note)) "" else as.character(note)[1L],
    signed_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  signed <- .rmbl_attest_payload_digest(payload)
  sig <- if (identical(scheme, "xmss-sha256")) {
    cpssign(signed, key, scheme = "xmss")
  } else {
    cpssign(signed, key, ctx = if (is.null(.ctx)) NULL else payload$context, prehash = prehash)
  }
  out <- c(payload, list(signature = sig))
  class(out) <- c("bricklayer_attestation", "list")
  out
}

#' @rdname cpsatst
#' @export
cpschkatst <- function(attest, man,
                                      keyexp = NULL) {
  .rmbl_no_fn(key_expected = keyexp)
  acc <- new.env(parent = emptyenv())
  acc$checks <- list()
  note_row <- function(check, ok, detail = "") {
    acc$checks[[length(acc$checks) + 1L]] <- data.frame(
      check = check, ok = isTRUE(ok), detail = as.character(detail),
      stringsAsFactors = FALSE
    )
  }
  if (!inherits(attest, "bricklayer_attestation")) {
    stop("`attest` must come from cpsatst()", call. = FALSE)
  }
  needed <- c(
    "digest", "scheme", "public", "context", "prehash", "note",
    "signed_utc", "signature"
  )
  missing <- setdiff(needed, names(attest))
  note_row(
    "attestation_complete", length(missing) == 0L,
    if (length(missing)) paste(missing, collapse = ", ") else ""
  )

  got <- tryCatch(mnfdgst(man), error = function(e) NA_character_)
  attested <- attest$digest %||% "(missing)"
  note_row(
    "manifest_digest", identical(got, attest$digest),
    if (identical(got, attest$digest)) {
      got
    } else {
      sprintf("attested %s, manifest is %s", as.character(attested)[1L], got)
    }
  )

  if (!is.null(keyexp)) {
    # a public-key object is accepted as well as the hex it carries: for XMSS the attestation's
    # `public` is root || pubseed, and signpubkey() has both
    expected_hex <- if (inherits(keyexp, c("bricklayer_public_key", "bricklayer_signing_key"))) {
      paste0(keyexp$root, .rmbl_xkey(keyexp, "pubseed"))
    } else if (inherits(keyexp, c("bricklayer_oqs_key", "bricklayer_oqs_public_key"))) {
      keyexp$public
    } else {
      as.character(keyexp)[1L]
    }
    key_ok <- identical(tolower(as.character(expected_hex)), tolower(as.character(attest$public %||% "")))
    note_row(
      "key_as_expected", key_ok,
      if (key_ok) "the attestation carries the expected key" else
        "the attestation carries a different key from the one expected"
    )
  }

  payload <- attest[c(
    "digest", "scheme", "public", "context",
    "prehash", "note", "signed_utc"
  )]
  signed <- .rmbl_attest_payload_digest(payload)
  ok <- FALSE
  detail <- ""
  if (length(missing) == 0L) {
    key <- tryCatch(.rmbl_attest_key_from(attest),
      error = function(e) NULL
    )
    if (is.null(key)) {
      detail <- "the attested public key is not usable for this scheme"
    } else {
      ok <- tryCatch(
        if (identical(attest$scheme, "xmss-sha256")) {
          cpsvrf(signed, attest$signature, key)
        } else {
          cpsvrf(signed, attest$signature, key,
            ctx = if (nzchar(attest$context)) {
              attest$context
            } else {
              NULL
            },
            prehash = attest$prehash
          )
        },
        error = function(e) FALSE
      )
    }
  }
  note_row("signature", ok, detail)

  df <- do.call(rbind, acc$checks)
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

#' @rdname printmeth
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

#' @rdname printmeth
#' @export
print.bricklayer_attestation_check <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' Hashes an attestation payload through its canonical digest.
#'
#' The payload is signed through its own canonical digest, so the
#' signature does not depend on the order the fields were assembled in --
#' the same reason mnfdgst() exists.
#' @param payload The attestation fields, as a list.
#' @return The SHA-256 digest of the canonical payload.
#' @noRd
.rmbl_attest_payload_digest <- function(payload) {
  csha256(charToRaw(mnfcanon(payload)))
}

#' Names the signature scheme of a signing or public key.
#' @param key A key from fipskg() or pqckg(), private or public.
#' @return The scheme name, such as "xmss-sha256".
#' @noRd
.rmbl_attest_scheme <- function(key) {
  if (inherits(key, c("bricklayer_oqs_key", "bricklayer_oqs_public_key"))) {
    return(key$scheme)
  }
  if (inherits(key, c("bricklayer_signing_key", "bricklayer_public_key"))) {
    return("xmss-sha256")
  }
  stop("`key` must come from fipskg() or pqckg()", call. = FALSE)
}

#' Returns the public key text an attestation records for a key.
#' @param key A key from fipskg() or pqckg(), private or public.
#' @return The public key as hex text; for XMSS the root followed by the public seed.
#' @noRd
.rmbl_attest_public <- function(key) {
  if (inherits(key, c("bricklayer_oqs_key", "bricklayer_oqs_public_key"))) {
    return(key$public)
  }
  # An XMSS public key is the root plus the public seed: both are needed
  # to verify, so both have to be recorded.
  paste0(key$root, .rmbl_xkey(key, "pubseed"))
}

#' Rebuilds the public key recorded in an attestation.
#' @param attestation An attestation, with its scheme, public key and signature.
#' @return A public key object that the scheme can verify with.
#' @noRd
.rmbl_attest_key_from <- function(attestation) {
  if (identical(attestation$scheme, "xmss-sha256")) {
    n <- nchar(attestation$public)
    if (n != 128L) stop("an XMSS public key is 64 bytes", call. = FALSE)
    sig <- attestation$signature
    out <- list(
      root = substring(attestation$public, 1L, 64L),
      pubseed = substring(attestation$public, 65L, 128L),
      height = sig$height, scheme = "xmss-sha256"
    )
    class(out) <- c("bricklayer_public_key", "list")
    return(out)
  }
  fipskey(attestation$scheme, attestation$public)
}
