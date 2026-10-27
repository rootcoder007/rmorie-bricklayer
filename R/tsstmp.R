# SPDX-License-Identifier: AGPL-3.0-or-later
#
# A public timestamp for anything a study commits to before it sees its
# data: an allocation list's commitment, the declared outcomes, a manifest.
# A signature says who signed and that nothing changed since; only a third
# party's timestamp says the commitment already existed on a given date.

#' Get a Public Timestamp for a Commitment
#'
#' Asks an RFC 3161 time-stamping authority to sign the SHA-256 of `data`
#' together with the current time, then checks the token it returns with
#' [tsvrf()].
#' Anyone holding the same bytes, the token and the authority's
#' certificate can later prove the bytes existed at that time, without
#' trusting the person who asked.
#'
#' Use it on anything that has to be fixed before the data are seen: the
#' commitment of a randomisation list from [ralloc()] (pass the list
#' itself), the file of declared outcomes, a manifest or a capsule. Only
#' the 32-byte SHA-256 leaves the machine; the data never do.
#'
#' @details
#' The request carries a random 8-byte nonce from the operating system's
#' generator and asks for the authority's certificate in the reply, so the
#' token can be checked offline later. The default authority,
#' `"https://freetsa.org/tsr"`, is free and needs no account; any RFC 3161
#' service can be named instead, and an institution's own is better where
#' there is one. Pass `cert` and `trust` to
#' [tsvrf()]
#' when re-checking a
#' saved token to tie it to a certificate you trust.
#'
#' @param data What to timestamp: a raw vector, the path of an existing
#'   file, or a list from [ralloc()] (its commitment is stamped).
#' @param tsa The time-stamping authority's URL.
#' @param file Optional path to save the token to (a `.tsr` file). An
#'   existing file is not overwritten.
#' @param timeout Seconds to wait for the authority.
#' @param trust Trust anchors for the authority's certificate, passed to
#'   [tsvrf()]: for the default authority, its root certificate from
#'   <https://freetsa.org/files/cacert.pem>. Without one the token's
#'   signature is still checked, but the result is not VERIFIED, because
#'   nothing vouches for the certificate that made it.
#' @return The [tsvrf()] result for the new token (class
#'   `bricklayer_timestamp`, printed as a box with the time it asserts),
#'   with three more elements: `token` (the raw token), `tsa` and `file`
#'   (the path it was saved to, or `NA`). An authority that does not answer
#'   is an error.
#' @references Adams, C., Cain, P., Pinkas, D., and Zuccherato, R. (2001).
#'   Internet X.509 Public Key Infrastructure Time-Stamp Protocol (TSP).
#'   RFC 3161.
#' @seealso
#' [tsvrf()] to check a saved token,
#' [ralloc()],
#' [prrgdecl()].
#' @export
#' @examplesIf interactive()
#' # Fix a trial's allocation before enrolment, then stamp its commitment.
#' a <- ralloc(40, seed = "a demonstration only")
#' ts <- tsstmp(a, file = file.path(tempdir(), "allocation.tsr"))
#' ts$time
#'
#' # Years later, anyone re-checks the saved token against the commitment.
#' tsvrf(ts$file, charToRaw(attr(a, "alloc")$digest))
tsstmp <- function(data, tsa = "https://freetsa.org/tsr", file = NULL,
                   timeout = 60, trust = NULL) {
  bytes <- .rmbl_tsstmp_bytes(data)
  a <- .rmbl_tsstmp_args(tsa, timeout, file)
  digest <- .bl_hex_raw(csha256(bytes))
  nonce <- c(as.raw(0x01), rndbytes(7L))
  res <- .bl_tsa_post(a$tsa, .bl_tsq(digest, nonce), as.integer(a$timeout))
  if (!identical(res$status, 200L) || !length(res$body)) {
    stop(
      "the time-stamping authority did not answer (",
      if (nzchar(res$error %||% "")) res$error else paste("HTTP", res$status),
      "): nothing was stamped",
      call. = FALSE
    )
  }
  token <- res$body
  if (!is.null(a$file)) {
    writeBin(token, a$file)
  }
  out <- tsvrf(token, bytes, trust = trust)
  out$token <- token
  out$tsa <- a$tsa
  out$file <- if (is.null(a$file)) NA_character_ else a$file
  out
}

#' The bytes tsstmp() stamps: an allocation list's commitment, or the data.
#' @param data As for tsstmp().
#' @return A raw vector.
#' @noRd
.rmbl_tsstmp_bytes <- function(data) {
  if (!inherits(data, "rmbl_alloc")) {
    return(.rmbl_as_bytes(data, "data"))
  }
  d <- attr(data, "alloc")$digest
  if (!is.character(d) || length(d) != 1L || !nzchar(d)) {
    stop("this allocation list has no commitment to stamp", call. = FALSE)
  }
  charToRaw(d)
}

#' Checks tsstmp()'s authority, timeout and output file.
#' @param tsa,timeout,file As for tsstmp().
#' @return A list: `tsa`, `timeout` and `file`.
#' @noRd
.rmbl_tsstmp_args <- function(tsa, timeout, file) {
  tsa <- .rmbl_string1(tsa, "tsa")
  if (!grepl("^https?://", tsa)) {
    stop("`tsa` must be an http(s) URL", call. = FALSE)
  }
  timeout <- .rmbl_num(timeout, "timeout")
  if (length(timeout) != 1L || is.na(timeout) || timeout <= 0) {
    stop("`timeout` must be a positive number of seconds", call. = FALSE)
  }
  if (!is.null(file)) {
    file <- .rmbl_string1(file, "file")
    if (file.exists(file)) {
      stop("`file` already exists; it is not overwritten: ", file,
           call. = FALSE)
    }
  }
  list(tsa = tsa, timeout = timeout, file = file)
}
