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
#' @examples
#' f <- tempfile()
#' writeLines("hello capsule", f)
#' sha256_file(f)
#'
#' # Deterministic: the same bytes always yield the same digest.
#' identical(sha256_file(f), sha256_file(f))
#'
#' # Any change to the file changes the digest (tamper-evidence).
#' before <- sha256_file(f)
#' writeLines("hello capsule (edited)", f)
#' after <- sha256_file(f)
#' before == after      # FALSE
#'
#' # Provenance pin: record a digest, verify it later.
#' pinned <- sha256_file(f)
#' stopifnot(sha256_file(f) == pinned)
#' @export
sha256_file <- function(path) {
  # the compiled SHA-256 core over the file bytes; identical output to
  # digest::digest(file = path, algo = "sha256")
  core_sha256(readBin(path, "raw", n = file.info(path)$size))
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
#' # Latin accents fold to their nearest ASCII letter.
#' to_ascii("Prof. \u00c1ngela Zorro Medina")  # "Prof. Angela Zorro Medina"
#'
#' # Vectorised over the input.
#' to_ascii(c("Se\u00e1n", "Zo\u00eb", "na\u00efve"))
#'
#' # Non-Latin scripts are romanised when stringi is available.
#' if (requireNamespace("stringi", quietly = TRUE))
#'   to_ascii("\u041c\u043e\u0441\u043a\u0432\u0430")  # "Moskva" (Cyrillic)
#'
#' # Either way the result is guaranteed pure 7-bit ASCII (never "?").
#' all(charToRaw(to_ascii("caf\u00e9")) < 128)
to_ascii <- function(x) {
  x <- as.character(x)
  if (requireNamespace("stringi", quietly = TRUE)) {
    # Best + platform-independent: romanize any script to Latin, then fold
    # Latin accents to ASCII. Handles far more than Latin accents
    # (e.g. Cyrillic, Greek), not just names like "Angela".
    out <- stringi::stri_trans_general(x, "Any-Latin; Latin-ASCII")
  } else {
    out <- .to_ascii_fallback(x)
  }
  out[is.na(out)] <- ""
  # Guarantee pure 7-bit ASCII regardless of path.
  gsub("[^ -~]", "", out)
}

# Deterministic no-stringi fallback. iconv("ASCII//TRANSLIT") is
# locale-dependent: under a C locale (glibc) accented characters come back
# as "?" -- ASCII, so the final strip keeps them. Transliterate the common
# Latin accents by table first, then let iconv DROP (not "?") the rest.
.to_ascii_fallback <- function(x) {
  # Under a C locale UTF-8 bytes arrive unmarked and chartr() errors on
  # them; declare valid UTF-8 so translation is locale-independent.
  valid <- !is.na(x) & validUTF8(x)
  Encoding(x[valid]) <- "UTF-8"
  from <- paste0(
    "\u00c0\u00c1\u00c2\u00c3\u00c4\u00c5\u00c7",
    "\u00c8\u00c9\u00ca\u00cb\u00cc\u00cd\u00ce\u00cf",
    "\u00d0\u00d1\u00d2\u00d3\u00d4\u00d5\u00d6\u00d8",
    "\u00d9\u00da\u00db\u00dc\u00dd",
    "\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5\u00e7",
    "\u00e8\u00e9\u00ea\u00eb\u00ec\u00ed\u00ee\u00ef",
    "\u00f0\u00f1\u00f2\u00f3\u00f4\u00f5\u00f6\u00f8",
    "\u00f9\u00fa\u00fb\u00fc\u00fd\u00ff",
    "\u0100\u0101\u0104\u0105\u0106\u0107\u010c\u010d",
    "\u010e\u010f\u0110\u0111\u0112\u0113\u0118\u0119",
    "\u011a\u011b\u011e\u011f\u0130\u0131\u0141\u0142",
    "\u0143\u0144\u0147\u0148\u014c\u014d\u0150\u0151",
    "\u0158\u0159\u015a\u015b\u015e\u015f\u0160\u0161",
    "\u0164\u0165\u016a\u016b\u016e\u016f\u0170\u0171",
    "\u0179\u017a\u017b\u017c\u017d\u017e"
  )
  to <- paste0(
    "AAAAAAC",
    "EEEEIIII",
    "DNOOOOOO",
    "UUUUY",
    "aaaaaac",
    "eeeeiiii",
    "dnoooooo",
    "uuuuyy",
    "AaAaCcCc",
    "DdDdEeEe",
    "EeGgIiLl",
    "NnNnOoOo",
    "RrSsSsSs",
    "TtUuUuUu",
    "ZzZzZz"
  )
  x <- chartr(from, to, x)
  multi <- list(
    c("\u00df", "ss"), c("\u00c6", "AE"), c("\u00e6", "ae"),
    c("\u0152", "OE"), c("\u0153", "oe"), c("\u00de", "Th"),
    c("\u00fe", "th")
  )
  for (pair in multi) {
    x <- gsub(pair[[1L]], pair[[2L]], x, fixed = TRUE)
  }
  iconv(x, to = "ASCII", sub = "")
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
#' # By default valid UTF-8 is preserved (accents kept where supported).
#' ascii_fallback("\u00c1ngela")               # "\u00c1ngela"
#'
#' # force = TRUE always transliterates (for ASCII-only destinations
#' # such as a package DESCRIPTION).
#' ascii_fallback("\u00c1ngela", force = TRUE)  # "Angela"
#'
#' # Plain ASCII is returned unchanged either way.
#' ascii_fallback("plain name")
#'
#' # Vectorised; each element handled independently.
#' ascii_fallback(c("caf\u00e9", "resume"), force = TRUE)
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
#' [to_ascii()] so capsule generation never fails on a non-ASCII name.
#'
#' @param text A character vector of lines to write.
#' @param path Destination file path.
#' @return Invisibly, `path`.
#' @examples
#' p <- write_text_fallback(c("line one", "line two"),
#'                          tempfile(fileext = ".txt"))
#' readLines(p)
#' @export
write_text_fallback <- function(text, path) {
  ok <- tryCatch({
    con <- file(path, open = "w", encoding = "UTF-8")
    on.exit(close(con), add = TRUE)
    writeLines(enc2utf8(as.character(text)), con, useBytes = TRUE)
    TRUE
  }, error = function(e) FALSE)
  if (!ok) writeLines(to_ascii(text), path) # nocov -- encoding-error retry
  invisible(path)
}

# Read JSON from a local path or an http(s) URL with the native codec.
# URLs go through the compiled fetch core (with its Wayback fallback);
# `simplify = FALSE` returns plain nested lists (jsonlite's
# simplifyVector = FALSE), `simplify = TRUE` gives jsonlite's default
# simplification. Errors propagate so callers' tryCatch() still applies.
#' @noRd
.rmbl_read_json <- function(x, simplify = TRUE) {
  if (length(x) == 1L && grepl("^https?://", x)) {
    dest <- tempfile(fileext = ".json")
    on.exit(unlink(dest), add = TRUE)
    bricklayer_fetch(x, dest)
    x <- dest
  }
  txt <- if (length(x) == 1L && !grepl("^\\s*[\\[{\"]", x) && file.exists(x))
    paste(readLines(x, warn = FALSE, encoding = "UTF-8"), collapse = "\n") else x
  bricklayer_json_from_json(txt, simplifyVector = isTRUE(simplify))
}
