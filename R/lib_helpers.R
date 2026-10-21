# SPDX-License-Identifier: AGPL-3.0-or-later
## lib_helpers.R -- SHA256 file-digest helper (package API).

## ----------------- SHA256 (compiled core, no digest) -----------------

#' Compute a File's SHA256 Digest
#'
#' Returns the SHA-256 digest of a file as a lowercase hex string. A
#' digest is a 64-character fingerprint of the file's exact bytes: any
#' change to the file, even one byte, gives a different digest, so
#' recording it when data are downloaded and checking it later shows
#' whether the file used in an analysis is the one that was recorded. The
#' package uses it to record and verify data provenance in capsules and
#' manifests.
#'
#' @details
#' The digest is SHA-256 as specified in FIPS 180-4 (National Institute of
#' Standards and Technology, 2015), computed by the package's own compiled
#' core; it is identical to `digest::digest(file = path, algo = "sha256")`
#' and to the `sha256sum` command-line tool. The file is read in binary
#' mode, 8 MB at a time, so memory use stays at one chunk whatever the
#' file's size, and line endings or encodings are never altered. A file
#' larger than one chunk shows a byte-progress bar on stderr after 0.75 s
#' when a person is watching (an interactive session, or
#' `options(morie.progress = TRUE)`); `options(morie.quiet = TRUE)` silences
#' it. Hashing runs at roughly 100 MB a second or faster.
#'
#' When this file is sourced on its own inside a capsule bundle (outside
#' the package), the same digest comes from the bundle's pure-R SHA-256
#' implementation, which reads the whole file at once.
#'
#' Refusals: anything other than a single string naming an existing
#' regular file -- a missing path, a directory, `NA`, a number or a vector
#' of several paths -- stops with `"sha256file: <path> is not a file"`.
#'
#' @param path A single string: the path of the file to hash (`~` is
#'   expanded as usual by R's file functions).
#' @return A single string of 64 lowercase hexadecimal characters, the
#'   SHA-256 digest of the file's bytes.
#' @references National Institute of Standards and Technology (2015).
#'   Secure Hash Standard (SHS). FIPS PUB 180-4.
#'   \doi{10.6028/NIST.FIPS.180-4}
#' @seealso [csha256()] for the digest of a string or raw
#'   vector held
#'   in memory.
#' @examples
#' f <- tempfile()
#' writeLines("hello capsule", f)
#' sha256file(f)
#'
#' # Deterministic: the same bytes always yield the same digest.
#' identical(sha256file(f), sha256file(f))
#'
#' # Any change to the file changes the digest (tamper-evidence).
#' before <- sha256file(f)
#' writeLines("hello capsule (edited)", f)
#' after <- sha256file(f)
#' before == after      # FALSE
#'
#' # Provenance pin: record a digest, verify it later.
#' pinned <- sha256file(f)
#' stopifnot(sha256file(f) == pinned)
#'
#' # An empty file has the well-known empty-input digest.
#' e <- tempfile()
#' file.create(e)
#' sha256file(e)
#'
#' # The file's bytes and the same bytes in memory hash alike.
#' identical(sha256file(f), csha256(readBin(f, "raw", file.size(f))))
#'
#' # A directory or a missing file is refused.
#' try(sha256file(tempdir()))
#' @export
sha256file <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !file.exists(path) || dir.exists(path)) {
    stop(sprintf("sha256file: %s is not a file", if (is.character(path) && length(path) == 1L) path else "`path`"),
         call. = FALSE)
  }
  # inside the package: the compiled SHA-256 core over the file read in chunks (identical output
  # to digest::digest(file = path, algo = "sha256")); sourced standalone in a capsule bundle: the
  # pure-R FIPS 180-4 implementation from sha256_native.R, over the whole file at once
  if (exists("csha256", mode = "function")) return(.rmbl_sha256_stream(path))
  .rmbl_sha256_hex(readBin(path, "raw", n = file.info(path)$size))
}

#' Hashes a file with SHA-256 one chunk at a time.
#'
#' The digest of a file read `chunk` bytes at a time (8 MB), so memory stays at one chunk whatever
#' the file's size; a file larger than one chunk gets a byte-progress bar (drawn only after the
#' usual lazy start, so a quick hash shows nothing).
#' @param path The file.
#' @param chunk The number of bytes read at a time.
#' @return The digest as lower-case hex.
#' @noRd
.rmbl_sha256_stream <- function(path, chunk = 8388608L) {
  size <- file.info(path)$size
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)
  pg <- if (is.finite(size) && size > chunk) {
    blprog(sprintf("sha256 %s", .rmbl_printable(basename(path))), size)
  }
  if (!is.null(pg)) on.exit(pg$done(), add = TRUE)
  state <- NULL
  done <- 0
  repeat {
    b <- readBin(con, "raw", n = chunk)
    if (!length(b)) break
    state <- .Call(C_rmbl_sha256_chunk, state, b, FALSE)
    done <- done + length(b)
    if (!is.null(pg)) pg$update(done, info = sprintf("%s of %s", .bl_fmt_bytes(done), .bl_fmt_bytes(size)))
  }
  .Call(C_rmbl_sha256_chunk, state, NULL, TRUE)
}

## ----------------- Unicode-safe text with ASCII fallback -----------------

#' Tells whether stringi is installed.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_has_stringi <- function() requireNamespace("stringi", quietly = TRUE)

#' Transliterate Text to Plain ASCII
#'
#' Converts a character vector to plain 7-bit ASCII, transliterating
#' accented or non-Latin characters to their nearest ASCII equivalent (for
#' example, an accented capital A becomes a plain "A"). Falls back to
#' dropping any character that has no transliteration. This is the
#' deterministic "fallback" used by
#' [asciifb()]. Use it for destinations that accept
#' only ASCII --
#' a package `DESCRIPTION`, a file name, a legacy system -- so a name
#' written with an accented letter arrives with the plain letter rather
#' than as an encoding error or a question mark.
#'
#' @details
#' Bytes that are not valid UTF-8 at all (a mislabelled file) are dropped
#' first. Then, when the \pkg{stringi} package is installed, the ICU
#' transform `"Any-Latin; Latin-ASCII"` romanises any script and folds
#' accents (Cyrillic, Greek and Chinese become Latin letters). Without
#' \pkg{stringi}, a fixed table folds the common Latin accents and
#' ligatures (sharp s to "ss", the ae ligature to "ae", thorn to "th" and so on) and
#' every other non-ASCII character is dropped, so non-Latin scripts
#' disappear rather than being romanised. Either way the result is then
#' stripped of anything outside the printable ASCII range (space to
#' tilde), so control characters such as newlines and tabs are removed
#' too. The result never depends on the session's locale.
#'
#' A missing value becomes `""`; non-character input is converted with
#' [as.character()] first (so numbers pass through as their
#' digits).
#'
#' @param x A character vector (other types are converted with
#'   [as.character()]).
#' @return A character vector the length of `x`, containing only printable
#'   ASCII characters (bytes 32 to 126); `NA` elements become `""`.
#' @seealso [asciifb()] to transliterate only when
#'   needed,
#'   [wrtxtfb()] to write text with an
#'   ASCII retry.
#' @export
#' @examples
#' # Latin accents fold to their nearest ASCII letter.
#' toascii("Prof. \u00c1ngela Zorro Medina")  # "Prof. Angela Zorro Medina"
#'
#' # Vectorised over the input.
#' toascii(c("Se\u00e1n", "Zo\u00eb", "na\u00efve"))
#'
#' # Non-Latin scripts are romanised when stringi is available.
#' if (requireNamespace("stringi", quietly = TRUE))
#'   toascii("\u041c\u043e\u0441\u043a\u0432\u0430")  # "Moskva" (Cyrillic)
#'
#' # Either way the result is guaranteed pure 7-bit ASCII (never "?").
#' all(charToRaw(toascii("caf\u00e9")) < 128)
#'
#' # Missing values become empty strings; line breaks are removed.
#' toascii(c(NA, "two\nlines"))
toascii <- function(x) {
  .rmbl_no_fn(x = x)
  x <- as.character(x)
  # Bytes that are not valid UTF-8 at all (a mislabelled file) are dropped
  # first. validUTF8() and an explicit UTF-8 -> UTF-8 iconv() both work on
  # the bytes, so this does not depend on the session locale; enc2utf8()
  # does, and under a C locale it re-encodes the bytes as Latin-1 instead
  # of flagging them.
  inv <- !is.na(x) & !validUTF8(x)
  if (any(inv)) x[inv] <- iconv(x[inv], "UTF-8", "UTF-8", sub = "")
  if (.rmbl_has_stringi()) {
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

#' Transliterates text to ASCII without stringi.
#'
#' Deterministic no-stringi fallback. iconv("ASCII//TRANSLIT") is
#' locale-dependent: under a C locale (glibc) accented characters come back
#' as "?" -- ASCII, so the final strip keeps them. Transliterate the common
#' Latin accents by table first, then let iconv DROP (not "?") the rest.
#' @param x A character vector.
#' @return A character vector.
#' @noRd
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
#' Returns `x` unchanged when it is valid, well-formed text (so
#' legitimate UTF-8 such as an accented name is preserved), and only
#' transliterates to plain ASCII via [toascii()]
#' when the text is not valid UTF-8 (an encoding error) or when
#' `force = TRUE` (for ASCII-only destinations such as a package
#' `DESCRIPTION`) . This lets author and supervisor names keep their
#' accents wherever UTF-8 is supported while degrading gracefully instead
#' of erroring where it is not.
#'
#' @details
#' Each element is tested on its bytes with [validUTF8()], so the
#' outcome
#' does not depend on the session locale. Valid elements (including plain
#' ASCII and properly encoded accented text) are returned unchanged;
#' invalid ones go through [toascii()], which drops the bytes
#' that are
#' not UTF-8 and transliterates the rest. With `force = TRUE` every
#' element goes through [toascii()]. A missing value is kept as
#' `NA`
#' unless `force = TRUE`, when it becomes `""`.
#'
#' @param x A character vector (other types are converted with
#'   [as.character()]).
#' @param force A single logical: `TRUE` always transliterates every
#'   element to ASCII; `FALSE` (the default) only the elements that are not
#'   valid UTF-8. Anything other than `TRUE` counts as `FALSE`.
#' @return A character vector the length of `x`: each element unchanged
#'   when it is valid UTF-8 (and `force` is not `TRUE`), otherwise its
#'   ASCII transliteration.
#' @seealso [toascii()], which does the transliteration.
#' @export
#' @examples
#' # By default valid UTF-8 is preserved (accents kept where supported).
#' asciifb("\u00c1ngela")               # "\u00c1ngela"
#'
#' # force = TRUE always transliterates (for ASCII-only destinations
#' # such as a package DESCRIPTION).
#' asciifb("\u00c1ngela", force = TRUE)  # "Angela"
#'
#' # Plain ASCII is returned unchanged either way.
#' asciifb("plain name")
#'
#' # Vectorised; each element handled independently.
#' asciifb(c("caf\u00e9", "resume"), force = TRUE)
#'
#' # Bytes that are not UTF-8 (a Latin-1 file read as UTF-8) are repaired.
#' bad <- rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xe9)))
#' validUTF8(bad)
#' asciifb(bad)
asciifb <- function(x, force = FALSE) {
  .rmbl_no_fn(x = x)
  x <- as.character(x)
  if (isTRUE(force)) return(toascii(x))
  out <- x
  # Test the bytes, not the locale's opinion of them (see toascii()).
  bad <- !is.na(x) & !validUTF8(x)
  if (any(bad)) out[bad] <- toascii(x[bad])
  out
}

#' Write Text as UTF-8, Falling Back to ASCII on an Encoding Error
#'
#' Writes `text` to `path` as UTF-8, one element per line. If the write
#' fails (for example a destination or locale that cannot represent the
#' characters), it retries with an ASCII transliteration produced by
#' [toascii()], so capsule generation never fails on a non-ASCII
#' name.
#' Use it to write generated text files (README, citation, script) whose
#' content may include names with accents.
#'
#' @details
#' The lines are joined with `"\n"`, a final newline is added, and the
#' UTF-8 bytes are written through a binary connection, so the bytes on
#' disk are UTF-8 whatever the session locale (a text connection would
#' re-encode from the native locale) and line endings are `"\n"` on every
#' platform. An existing file is overwritten. A missing element is written
#' as the two letters `NA`, and an empty `text` writes a file holding a
#' single newline.
#'
#' The ASCII retry is taken on any error from the first write, not only on
#' an encoding error; if the retry also fails (a directory that does not
#' exist, a read-only location), that error reaches the caller. A `path`
#' that is not a single non-empty string is refused before anything is
#' written (`"path must be a single non-empty string"`).
#'
#' @param text A character vector of lines to write;
#'   [as.character()] converts any other type.
#' @param path The destination file, a single non-empty string. Its
#'   directory must exist.
#' @return Invisibly, `path`.
#' @seealso [toascii()] for the retry's transliteration.
#' @examples
#' p <- wrtxtfb(c("line one", "line two"),
#'                          tempfile(fileext = ".txt"))
#' readLines(p)
#'
#' # Accented names are written as UTF-8 bytes, whatever the locale.
#' q <- wrtxtfb("Author: \u00c1ngela Zorro Medina", tempfile())
#' readLines(q, encoding = "UTF-8")
#' readBin(q, "raw", 20)
#'
#' # The path must be one string.
#' try(wrtxtfb("x", c("a.txt", "b.txt")))
#' @export
wrtxtfb <- function(text, path) {
  .rmbl_no_fn(text = text)
  path <- .rmbl_string1(path, "path")
  ok <- tryCatch({
    # the UTF-8 bytes go to a binary connection: a text connection with
    # encoding = "UTF-8" re-encodes from the native locale, and in a C
    # locale that is a warning per accented string
    con <- file(path, open = "wb")
    on.exit(close(con), add = TRUE)
    writeBin(charToRaw(paste0(paste(enc2utf8(as.character(text)), collapse = "\n"), "\n")), con)
    TRUE
  }, error = function(e) FALSE)
  if (!ok) writeLines(toascii(text), path) # nocov -- encoding-error retry
  invisible(path)
}

#' Reads JSON from a local path, a URL or text.
#'
#' Read JSON from a local path or an http(s) URL with the native codec.
#' URLs go through the compiled fetch core (with its Wayback fallback);
#' `simplify = FALSE` returns plain nested lists (jsonlite's
#' simplifyVector = FALSE), `simplify = TRUE` gives jsonlite's default
#' simplification. Errors propagate so callers' tryCatch() still applies.
#' @param x A path, an https URL, or JSON text.
#' @param simplify Whether to simplify as jsonlite does by default.
#' @param strict Whether a repeated key is an error.
#' @return The parsed value.
#' @noRd
.rmbl_read_json <- function(x, simplify = TRUE, strict = TRUE) {
  if (length(x) == 1L && grepl("^https?://", x)) {
    .rmbl_check_public_url(x, "url")
    dest <- tempfile(fileext = ".json")
    on.exit(unlink(dest), add = TRUE)
    .rmbl_fetch_url(x, dest)
    x <- dest
  }
  txt <- if (length(x) == 1L && !grepl("^\\s*[\\[{\"]", x) && file.exists(x))
    paste(readLines(x, warn = FALSE, encoding = "UTF-8"), collapse = "\n") else x
  # what came back is TEXT to parse, never a second address to fetch or a path to
  # open (fourth review: a body that was a bare URL made the package fetch it)
  # strict = TRUE (the default, and the package's own documents: provenance,
  # manifests, bundles): a repeated key is an error. strict = FALSE is for a
  # portal's metadata, read the way jsonlite reads it: a repeated key is
  # kept and a long numeric id is not a warning.
  if (isTRUE(strict)) {
    .rmbl_json_text(txt, simplifyVector = isTRUE(simplify))
  } else {
    .rmbl_json_text(txt, simplifyVector = isTRUE(simplify),
                              duplicate_keys = "keep", bigint_warn = FALSE)
  }
}

#' Downloads a URL to a file.
#'
#' The compiled fetcher inside the package; plain download.file when this
#' file is sourced standalone in a capsule bundle.
#' @param url The URL.
#' @param dest The destination file.
#' @param native Whether the compiled fetcher is there to use.
#' @return `dest`, invisibly.
#' @noRd
.rmbl_fetch_url <- function(url, dest,
                            native = exists("blfetch",
                                            mode = "function")) {
  if (native) return(blfetch(url, dest))
  utils::download.file(url, dest, mode = "wb", quiet = TRUE)
  invisible(dest)
}


#' Joins a manifest's relative file name under a directory, or refuses it.
#'
#' A manifest-derived file name joined under a directory, or NULL when it is
#' not a plain relative path that stays inside: "..", an absolute path, a
#' drive letter, a home prefix or a symlink out are refused. The provenance
#' file is attacker-authored input, and bare file.path() hashed
#' "../../etc/shadow" when asked to.
#' @param rel The relative name from the manifest.
#' @param dir The directory it must stay inside.
#' @return The joined path, or NULL.
#' @noRd
.rmbl_safe_rel <- function(rel, dir) {
  rel <- as.character(unlist(rel))[1L]
  if (is.na(rel) || !nzchar(rel)) return(NULL)
  if (grepl("^([/\\\\]|~|[A-Za-z]:)", rel)) return(NULL)
  parts <- strsplit(gsub("\\\\", "/", rel), "/", fixed = TRUE)[[1L]]
  if (any(parts %in% c("", ".", ".."))) return(NULL)
  full <- file.path(dir, rel)
  d <- .rmbl_realpath(dir)
  f <- .rmbl_realpath(full)
  if (!startsWith(f, paste0(d, "/"))) return(NULL)
  full
}

#' Resolves a path that may not exist yet through its deepest existing ancestor.
#'
#' normalizePath() only resolves paths that exist, so a missing leaf under a
#' symlinked tempdir (macOS /var -> /private/var) would never match its
#' resolved parent. Resolve the deepest existing ancestor and re-append the rest.
#' @param p The path.
#' @return The resolved path.
#' @noRd
.rmbl_realpath <- function(p) {
  tail <- character()
  while (!file.exists(p) && dirname(p) != p) {
    tail <- c(basename(p), tail)
    p <- dirname(p)
  }
  p <- sub("/+$", "", normalizePath(p, winslash = "/", mustWork = FALSE))
  if (length(tail)) paste(c(p, tail), collapse = "/") else p
}

#' Checks that a URL is one the package may fetch.
#'
#' A URL the package is about to fetch, or an error in words. Resolvers
#' return whatever a CKAN record (or a MITM on a cleartext hop) says, so
#' before any transport sees it: https only (plain http needs the explicit
#' option), never file://, and never a loopback, link-local, private or
#' metadata address -- the SSRF targets.
#' @param url The URL.
#' @param what The argument's name, used in the error message.
#' @param allow_file Whether a file:// URL is accepted.
#' @param allow_http Whether plain http is accepted.
#' @param resolve Whether the host's addresses are resolved and checked too.
#' @param allow_loopback Whether plain http on the loopback host is accepted (a local model).
#' @return `url`.
#' @noRd
.rmbl_check_public_url <- function(url, what = "url", allow_file = FALSE,
                                   allow_http = .rmbl_getopt("allowhttp", FALSE),
                                   resolve = FALSE, allow_loopback = FALSE) {
  url <- as.character(unlist(url))[1L]
  if (is.na(url) || !nzchar(url)) stop(sprintf("%s is empty", what), call. = FALSE)
  if (isTRUE(allow_file) && grepl("^file://", url, ignore.case = TRUE)) return(url)
  if (!grepl("^[a-z][a-z0-9+.-]*://", url, ignore.case = TRUE)) {
    stop(sprintf("%s has no URL scheme: '%s'", what, url), call. = FALSE)
  }
  # One implementation, in C, shared with the transport itself: the
  # authority is parsed as a URL parser does, IPv4 literals are read with
  # inet_aton's grammar (127.1, 0177.0.0.1, 2130706433, 0x7f000001), IPv6
  # with inet_pton, local names are refused by suffix, and with `resolve`
  # every address the name resolves to is tested. The fetch layer always
  # resolves, and pins the connection to the addresses it checked.
  # `allow_loopback` is the local-model relaxation (plain http on the loopback host), an
  # argument of this one call and never an option (fourth review)
  why <- .rmbl_url_why(url, allow_http, resolve, allow_loopback)
  if (!nzchar(why)) return(url)
  scheme <- tolower(sub("^([a-z][a-z0-9+.-]*)://.*$", "\\1", url, ignore.case = TRUE))
  if (startsWith(why, "plain http") || startsWith(why, "scheme ")) {
    stop(sprintf(paste0("%s must be an https:// URL, not %s:// ('%s'); ",
                        "options(rmoriebricklayer.allowhttp = TRUE) admits a ",
                        "trusted plain-http mirror"), what, scheme, url),
         call. = FALSE)
  }
  if (grepl("local|private|resolves|single-label", why)) {
    stop(sprintf("%s points at a local or private address ('%s'): refused (%s)",
                 what, url, why), call. = FALSE)
  }
  stop(sprintf("%s is refused: %s ('%s')", what, why, url), call. = FALSE)
}

#' Gives the reason a URL is refused.
#'
#' The reason a URL is refused ("" when it is accepted). In the package the C validator answers;
#' a lib_*.R file sourced on its own inside a capsule bundle has no compiled code, so a base-R
#' check stands in: https only, and no loopback, private, link-local, metadata, numeric or
#' single-label host (it does not resolve names; the package's fetch layer does).
#' @param url The URL.
#' @param allow_http Whether plain http is accepted.
#' @param resolve Whether the host's addresses are resolved and checked too.
#' @param allow_loopback Whether plain http on the loopback host is accepted.
#' @return The reason, or "" when the URL is accepted.
#' @noRd
.rmbl_url_why <- function(url, allow_http = FALSE, resolve = FALSE, allow_loopback = FALSE) {
  if (exists("C_rmbl_url_check", inherits = TRUE)) {
    return(.Call(C_rmbl_url_check, url, isTRUE(allow_http), isTRUE(resolve), isTRUE(allow_loopback)))
  }
  scheme <- tolower(sub("^([a-z][a-z0-9+.-]*)://.*$", "\\1", url, ignore.case = TRUE))
  if (!scheme %in% c("https", "http")) return(sprintf("scheme %s is not allowed", scheme))
  auth <- sub("[/?#].*$", "", sub("^[a-z][a-z0-9+.-]*://", "", url, ignore.case = TRUE))
  host <- tolower(sub(":[0-9]*$", "", sub("^.*@", "", auth)))
  loop <- host %in% c("localhost", "127.0.0.1", "[::1]") || startsWith(host, "127.")
  if (scheme == "http" && !isTRUE(allow_http) && !(isTRUE(allow_loopback) && loop)) {
    return("plain http is not allowed")
  }
  if (loop && isTRUE(allow_loopback)) return("")
  v4 <- suppressWarnings(as.integer(strsplit(host, ".", fixed = TRUE)[[1L]]))
  is_v4 <- grepl("^[0-9]+(\\.[0-9]+){3}$", host)
  private4 <- is_v4 && (v4[1L] %in% c(0L, 10L, 127L) || (v4[1L] == 169L && v4[2L] == 254L) ||
    (v4[1L] == 172L && v4[2L] >= 16L && v4[2L] <= 31L) || (v4[1L] == 192L && v4[2L] == 168L) ||
    (v4[1L] == 100L && v4[2L] >= 64L && v4[2L] <= 127L))
  odd <- grepl("^(0x[0-9a-f]+|[0-9]+)$", host) || (grepl("^[0-9.x]+$", host) && !is_v4)
  v6 <- startsWith(host, "[")
  private6 <- v6 && grepl("^\\[(::1?|::ffff:.*|f[cd][0-9a-f]*:.*|fe[89ab][0-9a-f]*:.*)\\]$", host)
  if (!nzchar(host) || private4 || odd || private6 || loop) return("a local or private address")
  if (!v6 && !is_v4 && !grepl(".", host, fixed = TRUE)) return("a single-label host")
  if (grepl("\\.(local|localhost|internal|lan|home|corp|intranet)$", host)) return("a local name")
  ""
}

# In-process synthetic state: mksyncsv() sets it, so a manifest
# built in the same session says synthetic whether or not the environment
# variable was set.
#' @noRd
.rmbl_synth_state <- new.env(parent = emptyenv())

#' Tells whether the session's data are synthetic, by the environment or by `mksyncsv()`.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_synthetic_flag <- function() {
  .rmbl_synthetic_env() || isTRUE(.rmbl_synth_state$made)
}

#' Tells whether the BRICKLAYER_SYNTHETIC variable marks the run as synthetic.
#'
#' The package, not the analysis script, owns the synthetic flag: set by
#' the reference pipeline for its subprocess, read wherever a manifest is
#' built or written.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_synthetic_env <- function() {
  v <- trimws(Sys.getenv("BRICKLAYER_SYNTHETIC", unset = ""))
  nzchar(v) && !tolower(v) %in% c("0", "false", "no", "off")
}


#' Parses JSON text and nothing else.
#'
#' Parse JSON TEXT and nothing else. fromjs() also accepts a
#' URL or a file path, which is right for a user's argument and wrong for bytes a
#' server just sent: a body (or a signature file) that happens to be a bare URL
#' would make the package fetch it, and one that names a local path would open
#' it (fourth review). Every parse of network- or disk-delivered content goes
#' through here; the hygiene test enumerates the call sites.
#' @param txt The text, as character or raw.
#' @param ... Options passed to `fromjs()`.
#' @return The parsed value.
#' @noRd
.rmbl_json_text <- function(txt, ...) {
  if (is.raw(txt)) txt <- rawToChar(txt)
  txt <- paste(as.character(txt), collapse = "\n")
  # bytes that are not UTF-8 are refused before any regular expression sees them: grepl() on them
  # warned "unable to translate ... to a wide string" (audit of 30bed8e, #17)
  if (Encoding(txt) != "latin1" && !validUTF8(txt)) stop("not UTF-8 text", call. = FALSE)
  # the shape of a JSON value, never of an address or a path: that is the whole point
  # of this entry (fourth review: a body that was a bare URL made the package fetch it)
  shaped <- grepl("^\\s*([\\[{\"]|-?[0-9]|true|false|null)", txt, useBytes = TRUE)
  if (!shaped) stop("not JSON", call. = FALSE)
  # the parser itself refuses what is not JSON, with its own reasons (a repeated key, a
  # bad escape, 100 levels), under whatever options the caller passes
  fromjs(txt, ...)
}

#' Makes fetched or file-supplied text safe to print.
#'
#' Fetched or file-supplied text made safe to print: marked as the UTF-8 it is (in a C locale the
#' parser returns it unmarked, and \[\[:cntrl:\]\] on unmarked text matched the bytes 0x80-0x9F inside
#' every multi-byte character) or converted, an invalid byte becoming "?"; then ANSI escape
#' sequences, the C0 and C1 controls and DEL, the bidirectional controls (U+061C, U+200E-U+200F,
#' U+202A-U+202E, U+2066-U+2069) and the default-ignorable characters that print as nothing and hide
#' text (U+00AD, U+034F, U+115F, U+3164, U+180E, U+200B, U+2060-U+2064, U+FEFF, U+FFF9-FFFB, the
#' tag characters) are removed (review of 02a38be). Kept, because they are part of how real text is
#' written (review of e57fed5): the zero-width joiner and non-joiner (Hindi and Persian words,
#' family emoji), the variation selectors (U+FE00-U+FE0F, U+180B-U+180D: the colour form of an
#' emoji, Mongolian and CJK glyph variants) and a flag tag sequence (U+1F3F4, tag letters, U+E007F:
#' the flags of Scotland and Wales). One helper for every printer (the data tables, the Wayback
#' results).
#' `lines = TRUE` keeps newlines and tabs (a model's answer, which is text to read, not a cell of a
#' table): the screen-clearing, title-setting and clipboard-writing escapes still go, with every
#' other control character (review of 29a55d8, L1).
#' @param x A character vector.
#' @param lines Whether newlines and tabs are kept.
#' @return A character vector.
#' @noRd
.rmbl_printable <- function(x, lines = FALSE) {
  x <- as.character(x)
  u <- !is.na(x) & Encoding(x) == "unknown" & validUTF8(x)
  v <- x[u]
  Encoding(v) <- "UTF-8"
  x[u] <- v
  o <- !is.na(x) & !u & Encoding(x) != "UTF-8"
  x[o] <- iconv(x[o], "", "UTF-8", sub = "?")
  x <- gsub("(*UTF)\033\\[[0-9;?]*[ -/]*[@-~]", "", x, perl = TRUE)
  # an operating-system command (a title, a clipboard write) ends in BEL or ESC \
  x <- gsub("(*UTF)\033\\][^\a\033]*(\a|\033\\\\)?", "", x, perl = TRUE)
  x <- gsub(paste0("(*UTF)[", if (lines) "\\x{00}-\\x{08}\\x{0b}-\\x{1f}" else "\\x{00}-\\x{1f}",
                   "\\x{7f}-\\x{9f}\\x{00ad}\\x{034f}\\x{061c}\\x{115f}\\x{1160}",
                   "\\x{17b4}\\x{17b5}\\x{180e}\\x{180f}\\x{200b}\\x{200e}\\x{200f}\\x{2028}-\\x{202e}",
                   "\\x{2060}-\\x{206f}\\x{3164}\\x{feff}\\x{ffa0}\\x{fff0}-\\x{fffb}]"), "", x, perl = TRUE)
  # tag characters: kept only as a flag sequence, dropped anywhere else
  gsub("(*UTF)(\\x{1f3f4}[\\x{e0020}-\\x{e007e}]{1,8}\\x{e007f})|[\\x{e0000}-\\x{e0fff}]", "\\1", x, perl = TRUE)
}
