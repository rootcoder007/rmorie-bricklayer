# SPDX-License-Identifier: AGPL-3.0-or-later
## lib_helpers.R -- SHA256 file-digest helper (package API).

## ----------------- SHA256 (uses digest pkg) -----------------

#' Compute a File's SHA256 Digest
#'
#' Returns the SHA256 digest of a file as a lowercase hex string, using
#' the digest package. Used to record and verify data provenance.
#'
#' @param path Path to the file to hash.
#' @return The SHA256 digest as a character string.
#' @export
sha256_file <- function(path) {
  if (!requireNamespace("digest", quietly = TRUE))
    stop("The 'digest' package is required for SHA256 verification.")
  digest::digest(file = path, algo = "sha256")
}

## ----------------- Unicode-safe text with ASCII fallback -----------------

#' Transliterate Text to Plain ASCII
#'
#' Converts a character vector to plain 7-bit ASCII, transliterating
#' accented or non-Latin characters to their nearest ASCII equivalent
#' (for example, an accented capital A becomes a plain "A"). Falls back to dropping
#' any character that has no transliteration. This is the deterministic
#' "fallback" used by [ascii_fallback()].
#'
#' @param x A character vector.
#' @return A character vector containing only ASCII characters.
#' @export
#' @examples
#' to_ascii("Prof. \u00c1ngela Zorro Medina")  # "Prof. Angela Zorro Medina"
to_ascii <- function(x) {
  x <- as.character(x)
  if (requireNamespace("stringi", quietly = TRUE)) {
    # Best + platform-independent: romanize any script to Latin, then fold
    # Latin accents to ASCII. Handles far more than Latin accents
    # (e.g. Cyrillic, Greek), not just names like "Angela".
    out <- stringi::stri_trans_general(x, "Any-Latin; Latin-ASCII")
  } else {
    # Fallback: iconv. //TRANSLIT is good on glibc; on BSD it can leave
    # artifacts, which the final strip below removes.
    out <- iconv(x, to = "ASCII//TRANSLIT")
    na <- is.na(out)
    if (any(na)) out[na] <- iconv(x[na], to = "ASCII", sub = "")
  }
  out[is.na(out)] <- ""
  # Guarantee pure 7-bit ASCII regardless of path.
  gsub("[^ -~]", "", out)
}

#' Use Text As-Is, Falling Back to ASCII When It Cannot Be Represented
#'
#' Returns `x` unchanged when it is valid, well-formed text (so legitimate
#' UTF-8 such as an accented name is preserved), and only transliterates to
#' plain ASCII via [to_ascii()] when the text is not valid UTF-8 (an
#' encoding error) or when `force = TRUE` (for ASCII-only destinations such
#' as a package `DESCRIPTION`). This lets author and supervisor names keep
#' their accents wherever UTF-8 is supported while degrading gracefully
#' instead of erroring where it is not.
#'
#' @param x A character vector.
#' @param force Logical; always transliterate to ASCII (default `FALSE`).
#' @return A character vector: `x` where it can be represented, ASCII otherwise.
#' @export
#' @examples
#' ascii_fallback("\u00c1ngela")            # accented name kept (UTF-8)
#' ascii_fallback("\u00c1ngela", force = TRUE) # "Angela"
ascii_fallback <- function(x, force = FALSE) {
  x <- as.character(x)
  if (isTRUE(force)) return(to_ascii(x))
  out <- x
  bad <- !validUTF8(enc2utf8(x)) & !is.na(x)
  if (any(bad)) out[bad] <- to_ascii(x[bad])
  out
}

#' Write Text as UTF-8, Falling Back to ASCII on an Encoding Error
#'
#' Writes `text` to `path` as UTF-8. If the write raises an encoding error
#' (for example a destination or locale that cannot represent the
#' characters), it retries with an ASCII transliteration produced by
#' [to_ascii()] so bundle generation never fails on a non-ASCII name.
#'
#' @param text A character vector of lines to write.
#' @param path Destination file path.
#' @return Invisibly, `path`.
#' @export
write_text_fallback <- function(text, path) {
  ok <- tryCatch({
    con <- file(path, open = "w", encoding = "UTF-8")
    on.exit(close(con), add = TRUE)
    writeLines(enc2utf8(as.character(text)), con, useBytes = TRUE)
    TRUE
  }, error = function(e) FALSE)
  if (!ok) writeLines(to_ascii(text), path)
  invisible(path)
}
