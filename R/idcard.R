# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Identity cards: a researcher's public signing key with their name and
# identifiers, signed by that key. Others pin the key by its fingerprint, given
# where they already know the researcher (a paper, an ORCID record, a talk),
# and then check the attestations, capsules and bundles it signs. No authority
# is involved and nothing is sent anywhere.

#' Make, read and verify an identity card for your signing key
#'
#' @description
#' An identity card ties your public signing key to who
#' you are: your name and, if you give them, your ORCID
#' iD, e-mail address, web page and affiliation, all
#' signed with the key itself. Publish the card (on your
#' web page, in a repository, beside a paper) and give
#' its fingerprint somewhere people already know you by
#' (the paper, your ORCID record, a talk). Anyone can
#' then check with `idcrdvrf()` that the card is intact
#' and in date, that its fingerprint is the one you gave,
#' and that an attestation or a bundle was signed by the
#' key it carries.
#'
#' `idcrd()` makes a card from a key of [fipskg()]
#' (ML-DSA or SLH-DSA) or [pqckg()] (XMSS; making the
#' card uses one of the key's signatures). `idcrdrd()`
#' reads a card written with `file`. `idcrdvrf()` checks
#' one.
#'
#' @details
#' A card is self-signed. Its signature proves that the
#' card was made by whoever holds the private key and
#' that nothing in it has changed since; it cannot prove
#' that the name on it is true. That is what the
#' fingerprint is for: a card whose fingerprint matches
#' the one you published where people know you is the key
#' you meant. The card's signature is made under its own
#' context string (or, for XMSS, over a payload naming
#' the card type), so it can never be passed off as an
#' attestation, nor an attestation as a card.
#'
#' The fingerprint is the SHA-256 digest of the scheme
#' and the public key, written as 16 groups of four
#' hexadecimal digits; compare all of it. An ORCID iD is
#' checked against its check digit (ISO 7064 MOD 11-2),
#' an e-mail address for its shape and a web page for an
#' `https://` address.
#'
#' `idcrdvrf()` records every step as a row of `checks`:
#' `card_complete`, `card_type`, `signature`, `in_date`
#' (at `at`), and `orcid` when the card has one,
#' `fingerprint` when `fpr` is given, `signed_by_card`
#' when `atst` is given. `ok` is `TRUE` only when every
#' row passed; a failed check is a row, not an error.
#'
#' Errors: `key` not a private key of [fipskg()] or
#' [pqckg()]; `name` not one non-empty string; an
#' optional field that is not one string, an ORCID iD
#' with a wrong check digit, an e-mail address or a web
#' page of the wrong shape; `days` not a positive whole
#' number; `path` not a card file.
#'
#' @param key Your private signing key, from [fipskg()]
#'   or [pqckg()].
#' @param name Your name as you want it shown, one
#'   string.
#' @param orcid,email,url,affil Optional, one string
#'   each: your ORCID iD (`"0000-0002-1825-0097"`, or its
#'   `https://orcid.org/` address), e-mail address, web
#'   page (`https://`) and affiliation.
#' @param days How many days the card is valid for, from
#'   now. Default 730.
#' @param file Optional path to write the card to, as
#'   JSON.
#' @param path The path of a card file written by
#'   `idcrd()`.
#' @param card A card, from `idcrd()` or `idcrdrd()`, or
#'   the path of one.
#' @param fpr Optional: the fingerprint you were given
#'   for this person, with or without its spaces. Without
#'   it the card is checked only against itself.
#' @param at The time to check the card's dates at: a
#'   `POSIXct` or anything `as.POSIXct()` reads, taken as
#'   UTC. Defaults to now.
#' @param atst Optional: an attestation of [cpsatst()],
#'   or a bundle of [cpsbndl()] or
#'   [cpsbndlrd()],
#'   to check
#'   was signed by the card's key. Check the attestation
#'   itself with [cpschkatst()] or
#'   [cpsbndlvrf()].
#' @return `idcrd()` and `idcrdrd()`: a list of class
#'   `rmbl_id_card` with the card's fields (`type`,
#'   `version`, `name`, `orcid`, `email`, `url`, `affil`,
#'   `scheme`, `public`, `context`, `prehash`,
#'   `issued_utc`, `expires_utc`, `signature`) and its
#'   `fingerprint`; `idcrd()` returns it invisibly when it
#'   writes `file`. `idcrdvrf()`: a list of class
#'   `rmbl_id_check` with `ok`, `checks` (a data frame with
#'   `check`, `ok` and `detail`), `fingerprint` and `card`.
#'   `print()` shows a summary.
#' @seealso [fipskg()],
#'   [pqckg()],
#'   [cpsatst()],
#'   [cpschkatst()],
#'   [cpsbndlvrf()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # once: make a key and a card, publish the card, give out the fingerprint
#' key <- fipskg("ML-DSA-44")
#' f <- tempfile(fileext = ".json")
#' idcrd(
#'   key,
#'   "Ada Lovelace",
#'   orcid = "0000-0002-1825-0097",
#'   url = "https://example.org/ada",
#'   file = f
#' )
#' card <- idcrdrd(f)
#' card
#' card$fingerprint
#'
#' # anyone, later: is this the card I was told about, and did it sign this?
#' man <- mkmnf(list(project = "demo"), env = FALSE)
#' a <- cpsatst(man, key)
#' res <- idcrdvrf(f, fpr = card$fingerprint, atst = a)
#' res$ok
#' res$checks
#'
#' # a card edited after signing fails
#' bad <- card
#' bad$name <- "Someone Else"
#' idcrdvrf(bad)$ok
#'
#' # an attestation made with another key is not the card's
#' other <- cpsatst(man, fipskg("ML-DSA-44"))
#' idcrdvrf(card, atst = other)$ok
#'
#' # an ORCID iD with a wrong check digit is refused
#' try(idcrd(key, "Ada Lovelace", orcid = "0000-0002-1825-0098"))
#' @export
idcrd <- function(
  key,
  name,
  orcid = NULL,
  email = NULL,
  url = NULL,
  affil = NULL,
  days = 730,
  file = NULL
) {
  scheme <- .bl_id_key_scheme(key)
  ids <- .bl_id_fields(name, orcid, email, url, affil)
  .bl_id_days(days)
  now <- Sys.time()
  payload <- c(
    list(type = .bl_id_type, version = 1L),
    ids,
    list(
      scheme = scheme,
      public = .rmbl_attest_public(key),
      context = .bl_id_type,
      prehash = "none",
      issued_utc = .bl_id_utc(now),
      expires_utc = .bl_id_utc(now + days * 86400)
    )
  )
  sig <- .rmbl_attest_sign(payload, key, TRUE)
  card <- .bl_id_card(c(payload, list(signature = sig)))
  if (is.null(file)) {
    return(card)
  }
  writeLines(
    .bl_id_json(card),
    .rmbl_out_file(file, "file", connection = FALSE)
  )
  invisible(card)
}

#' @rdname idcrd
#' @export
idcrdrd <- function(path) {
  path <- .rmbl_file1(path, "path")
  x <- .rmbl_json_text(
    paste(readLines(path, warn = FALSE), collapse = "\n"),
    simplifyVector = FALSE
  )
  if (!is.list(x) || !identical(x$type, .bl_id_type)) {
    stop("`path` is not an identity card (idcrd())", call. = FALSE)
  }
  .bl_id_card(x)
}

#' @rdname idcrd
#' @export
idcrdvrf <- function(card, fpr = NULL, at = Sys.time(), atst = NULL) {
  if (!inherits(card, "rmbl_id_card")) {
    card <- idcrdrd(card)
  }
  at <- .bl_id_time(at, "at")
  fields <- c(.bl_id_signed, "signature")
  absent <- setdiff(fields, names(card))
  rows <- list(
    .rmbl_attest_row(
      "card_complete",
      !length(absent),
      if (length(absent)) toString(absent) else ""
    ),
    .rmbl_attest_row(
      "card_type",
      identical(card$type, .bl_id_type) && identical(card$context, .bl_id_type),
      "an rmbl identity card, signed under its own context"
    ),
    .bl_id_sig_row(card, !length(absent)),
    .bl_id_date_row(card, at)
  )
  rows <- c(rows, .bl_id_extra_rows(card, fpr, atst))
  df <- do.call(rbind, rows)
  rownames(df) <- NULL
  out <- list(
    ok = all(df$ok),
    checks = df,
    fingerprint = .bl_id_fpr(card),
    card = card
  )
  class(out) <- c("rmbl_id_check", "list")
  out
}

#' @export
format.rmbl_id_card <- function(x, ...) {
  shown <- c(
    name = x$name,
    orcid = x$orcid,
    "e-mail" = x$email,
    web = x$url,
    affiliation = x$affil,
    key = x$scheme,
    fingerprint = x$fingerprint,
    issued = x$issued_utc,
    expires = x$expires_utc
  )
  shown <- shown[nzchar(shown)]
  c(.rmbl_rule("Identity card"), .rmbl_kv(as.list(shown)), .rmbl_rule())
}

#' @export
print.rmbl_id_card <- function(x, ...) {
  .rmbl_cat(format.rmbl_id_card(x, ...), x)
  invisible(x)
}

#' @export
format.rmbl_id_check <- function(x, ...) {
  c(
    .rmbl_rule(sprintf(
      "Identity card of %s: %s",
      x$card$name %||% "?",
      if (isTRUE(x$ok)) "verified" else "NOT verified"
    )),
    sprintf(
      "  %s %-16s %s",
      ifelse(x$checks$ok, "ok  ", "FAIL"),
      x$checks$check,
      x$checks$detail
    ),
    sprintf("  %-4s %-16s %s", "", "fingerprint", x$fingerprint),
    .rmbl_rule()
  )
}

#' @export
print.rmbl_id_check <- function(x, ...) {
  .rmbl_cat(format.rmbl_id_check(x, ...), x)
  invisible(x)
}

# The card type, also the context string its signature is made under.
.bl_id_type <- "rmbl identity card"

# The fields the signature covers, in the order they are signed.
.bl_id_signed <- c(
  "type",
  "version",
  "name",
  "orcid",
  "email",
  "url",
  "affil",
  "scheme",
  "public",
  "context",
  "prehash",
  "issued_utc",
  "expires_utc"
)

#' The scheme of a private signing key that can make a card.
#' @param key The key given to idcrd().
#' @return The scheme name, as attestations record it.
#' @noRd
.bl_id_key_scheme <- function(key) {
  if (
    !inherits(key, c("bricklayer_oqs_key", "bricklayer_signing_key")) ||
      inherits(key, c("bricklayer_oqs_public_key", "bricklayer_public_key"))
  ) {
    stop(
      "idcrd: `key` must be a private signing key from fipskg() or pqckg()",
      call. = FALSE
    )
  }
  .rmbl_attest_scheme(key)
}

#' The identity fields of a card, checked: one string each, "" when not given.
#' @param name,orcid,email,url,affil As for idcrd().
#' @return A named list of five strings.
#' @noRd
.bl_id_fields <- function(name, orcid, email, url, affil) {
  one <- function(v, what) {
    if (is.null(v)) {
      return("")
    }
    if (!is.character(v) || length(v) != 1L || is.na(v) || !nzchar(trimws(v))) {
      stop("idcrd: `", what, "` must be one non-empty string", call. = FALSE)
    }
    trimws(v)
  }
  if (is.null(name)) {
    stop("idcrd: `name` must be one non-empty string", call. = FALSE)
  }
  out <- list(
    name = one(name, "name"),
    orcid = .bl_id_orcid(one(orcid, "orcid")),
    email = one(email, "email"),
    url = one(url, "url"),
    affil = one(affil, "affil")
  )
  if (
    nzchar(out$email) &&
      !grepl("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", out$email)
  ) {
    stop("idcrd: `email` is not an e-mail address", call. = FALSE)
  }
  if (nzchar(out$url) && !grepl("^https://[^[:space:]/]+", out$url)) {
    stop("idcrd: `url` must be an https:// address", call. = FALSE)
  }
  out
}

#' An ORCID iD in its bare form, its check digit verified.
#' @param id The iD as given ("" when none), bare or as an orcid.org address.
#' @return The bare iD, or "".
#' @noRd
.bl_id_orcid <- function(id) {
  if (!nzchar(id)) {
    return("")
  }
  id <- toupper(sub("^https?://(www\\.)?orcid\\.org/", "", id))
  if (!grepl("^[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]$", id)) {
    stop(
      "idcrd: `orcid` must look like 0000-0002-1825-0097",
      call. = FALSE
    )
  }
  if (!.bl_id_orcid_ok(id)) {
    stop("idcrd: `orcid` ", id, " has a wrong check digit", call. = FALSE)
  }
  id
}

#' Whether an ORCID iD's last character is its ISO 7064 MOD 11-2 check digit.
#' @param id A bare iD of the right shape.
#' @return TRUE or FALSE.
#' @noRd
.bl_id_orcid_ok <- function(id) {
  d <- strsplit(gsub("-", "", id, fixed = TRUE), "", fixed = TRUE)[[1L]]
  total <- 0
  for (ch in d[1:15]) {
    total <- (total + as.integer(ch)) * 2
  }
  r <- (12 - total %% 11) %% 11
  identical(d[16L], if (r == 10) "X" else as.character(r))
}

#' Refuses a validity that is not a positive whole number of days.
#' @param days As for idcrd().
#' @return NULL, invisibly.
#' @noRd
.bl_id_days <- function(days) {
  ok <- is.numeric(days) &&
    length(days) == 1L &&
    is.finite(days) &&
    days >= 1 &&
    days == round(days)
  if (!ok) {
    stop("idcrd: `days` must be one positive whole number", call. = FALSE)
  }
  invisible(NULL)
}

#' A time as the cards write it.
#' @param t A POSIXct.
#' @return "YYYY-MM-DDTHH:MM:SSZ".
#' @noRd
.bl_id_utc <- function(t) {
  format(t, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

#' A time argument read as UTC.
#' @param t The value given.
#' @param what Its name, for the message.
#' @return A POSIXct.
#' @noRd
.bl_id_time <- function(t, what) {
  v <- tryCatch(as.POSIXct(t, tz = "UTC"), error = function(e) NULL)
  if (length(v) != 1L || is.na(v)) {
    stop("idcrdvrf: `", what, "` must be one time", call. = FALSE)
  }
  v
}

#' A card object from its fields, with its fingerprint.
#' @param x The card's fields, as signed or as read back from JSON.
#' @return A list of class rmbl_id_card.
#' @noRd
.bl_id_card <- function(x) {
  x$fingerprint <- NULL
  if (is.list(x$signature)) {
    class(x$signature) <- c("bricklayer_signature", "list")
  }
  x$fingerprint <- .bl_id_fpr(x)
  class(x) <- c("rmbl_id_card", "list")
  x
}

#' A card's fingerprint: SHA-256 of its scheme and public key, in 16 groups.
#' @param card The card.
#' @return The fingerprint, or "" when the card has no key.
#' @noRd
.bl_id_fpr <- function(card) {
  if (!is.character(card$public) || !is.character(card$scheme)) {
    return("")
  }
  h <- toupper(csha256(charToRaw(paste0(
    card$scheme,
    ":",
    tolower(card$public)
  ))))
  paste(substring(h, seq(1L, 61L, 4L), seq(4L, 64L, 4L)), collapse = " ")
}

#' A card as the JSON written to its file.
#' @param card The card.
#' @return One string.
#' @noRd
.bl_id_json <- function(card) {
  x <- unclass(card)
  x$fingerprint <- NULL
  x$signature <- unclass(x$signature)
  tojs(x, auto_unbox = TRUE, pretty = TRUE)
}

#' The signature row of a card check.
#' @param card The card.
#' @param complete Whether every signed field is present.
#' @return A one-row data frame.
#' @noRd
.bl_id_sig_row <- function(card, complete) {
  res <- list(ok = FALSE, detail = "the card is incomplete")
  if (complete) {
    signed <- .rmbl_attest_payload_digest(unclass(card)[.bl_id_signed])
    res <- .rmbl_attest_sig_public(card, signed)
    res$detail <- if (isTRUE(res$ok)) {
      "made by the holder of the card's key; unchanged since"
    } else if (nzchar(res$detail)) {
      res$detail
    } else {
      "the signature does not match the card: it was changed after signing"
    }
  }
  .rmbl_attest_row("signature", res$ok, res$detail)
}

#' The dates row of a card check.
#' @param card The card.
#' @param at The time checked at.
#' @return A one-row data frame.
#' @noRd
.bl_id_date_row <- function(card, at) {
  from <- tryCatch(
    .bl_id_time(card$issued_utc, "issued_utc"),
    error = function(e) NA
  )
  to <- tryCatch(
    .bl_id_time(card$expires_utc, "expires_utc"),
    error = function(e) NA
  )
  ok <- !is.na(from) && !is.na(to) && at >= from && at <= to
  .rmbl_attest_row(
    "in_date",
    ok,
    sprintf(
      "valid %s to %s; checked at %s",
      card$issued_utc %||% "?",
      card$expires_utc %||% "?",
      .bl_id_utc(at)
    )
  )
}

#' The rows a card check adds for an ORCID iD, a fingerprint and an
#' attestation.
#' @param card The card.
#' @param fpr,atst As for idcrdvrf().
#' @return A list of one-row data frames.
#' @noRd
.bl_id_extra_rows <- function(card, fpr, atst) {
  rows <- list()
  if (is.character(card$orcid) && nzchar(card$orcid)) {
    ok <- isTRUE(tryCatch(
      nzchar(.bl_id_orcid(card$orcid)),
      error = function(e) FALSE
    ))
    rows <- c(rows, list(.rmbl_attest_row("orcid", ok, card$orcid)))
  }
  if (!is.null(fpr)) {
    rows <- c(rows, list(.bl_id_fpr_row(card, fpr)))
  }
  if (!is.null(atst)) {
    rows <- c(rows, list(.bl_id_atst_row(card, atst)))
  }
  rows
}

#' The fingerprint row: the card's key is the one the person published.
#' @param card The card.
#' @param fpr The fingerprint given.
#' @return A one-row data frame.
#' @noRd
.bl_id_fpr_row <- function(card, fpr) {
  if (!is.character(fpr) || length(fpr) != 1L || is.na(fpr)) {
    stop("idcrdvrf: `fpr` must be one string", call. = FALSE)
  }
  squash <- function(s) toupper(gsub("[^0-9A-Fa-f]", "", s))
  ok <- nzchar(squash(fpr)) && identical(squash(fpr), squash(.bl_id_fpr(card)))
  .rmbl_attest_row(
    "fingerprint",
    ok,
    if (ok) {
      "the card's key is the one you were given"
    } else {
      "the card's key is NOT the one you were given"
    }
  )
}

#' The attestation row: an attestation or bundle was signed by the card's key.
#' @param card The card.
#' @param atst An attestation, or a bundle carrying one.
#' @return A one-row data frame.
#' @noRd
.bl_id_atst_row <- function(card, atst) {
  if (inherits(atst, "bricklayer_bundle") || is.list(atst$attestation)) {
    atst <- atst$attestation
  }
  if (!is.list(atst) || is.null(atst$public) || is.null(atst$scheme)) {
    stop(
      "idcrdvrf: `atst` must be an attestation (cpsatst()) or a bundle ",
      "(cpsbndl(), cpsbndlrd())",
      call. = FALSE
    )
  }
  ok <- identical(atst$scheme, card$scheme) &&
    identical(tolower(atst$public), tolower(card$public))
  .rmbl_attest_row(
    "signed_by_card",
    ok,
    if (ok) {
      "the attestation carries the card's key"
    } else {
      "the attestation was made with a different key"
    }
  )
}
