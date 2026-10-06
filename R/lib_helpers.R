# SPDX-License-Identifier: AGPL-3.0-or-later
## lib_helpers.R -- SHA256 file-digest helper (package API).

## ----------------- SHA256 (compiled core, no digest) -----------------

#' Compute a File's SHA256 Digest
#'
#' Returns the SHA256 digest of a file as a lowercase hex string, computed
#' by the package's own compiled SHA-256 core (or, when the file is sourced
#' standalone inside a capsule bundle, by the pure-R FIPS 180-4
#' implementation it ships). Used to record and verify data provenance.
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
  if (!is.character(path) || length(path) != 1L || is.na(path) || !file.exists(path) || dir.exists(path)) {
    stop(sprintf("sha256_file: %s is not a file", if (is.character(path) && length(path) == 1L) path else "`path`"),
         call. = FALSE)
  }
  bytes <- readBin(path, "raw", n = file.info(path)$size)
  # inside the package: the compiled SHA-256 core (identical output to
  # digest::digest(file = path, algo = "sha256")); sourced standalone in a
  # capsule bundle: the pure-R FIPS 180-4 implementation from sha256_native.R
  if (exists("core_sha256", mode = "function")) return(core_sha256(bytes))
  .rmbl_sha256_hex(bytes)
}

## ----------------- Unicode-safe text with ASCII fallback -----------------

#' Transliterate Text to Plain ASCII
#'
#' Converts a character vector to plain 7-bit ASCII, transliterating
#' accented or non-Latin characters to their nearest ASCII equivalent (for
#' example, an accented capital A becomes a plain "A"). Falls back to
#' dropping any character that has no transliteration. This is the
#' deterministic "fallback" used by
#' [ascii_fallback()].
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
  # Bytes that are not valid UTF-8 at all (a mislabelled file) are dropped
  # first. validUTF8() and an explicit UTF-8 -> UTF-8 iconv() both work on
  # the bytes, so this does not depend on the session locale; enc2utf8()
  # does, and under a C locale it re-encodes the bytes as Latin-1 instead
  # of flagging them.
  inv <- !is.na(x) & !validUTF8(x)
  if (any(inv)) x[inv] <- iconv(x[inv], "UTF-8", "UTF-8", sub = "")
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
#' Returns `x` unchanged when it is valid, well-formed text (so
#' legitimate UTF-8 such as an accented name is preserved), and only
#' transliterates to plain ASCII via [to_ascii()]
#' when the text is not valid UTF-8 (an encoding error) or when
#' `force = TRUE` (for ASCII-only destinations such as a package
#' `DESCRIPTION`) . This lets author and supervisor names keep their
#' accents wherever UTF-8 is supported while degrading gracefully instead
#' of erroring where it is not.
#'
#' @param x A character vector.
#' @param force Logical; always transliterate to ASCII
#' (default `FALSE`) .
#' @return A character vector: `x` where it can be represented, ASCII
#' otherwise.
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
  # Test the bytes, not the locale's opinion of them (see to_ascii()).
  bad <- !is.na(x) & !validUTF8(x)
  if (any(bad)) out[bad] <- to_ascii(x[bad])
  out
}

#' Write Text as UTF-8, Falling Back to ASCII on an Encoding Error
#'
#' Writes `text` to `path` as UTF-8. If the write raises an
#' encoding error (for example a destination or locale that cannot
#' represent the characters), it retries with an ASCII transliteration
#' produced by [to_ascii()] so capsule generation
#' never fails on a non-ASCII name.
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
  path <- .rmbl_string1(path, "path")
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
  # strict = TRUE (the default, and the package's own documents: provenance,
  # manifests, bundles): a repeated key is an error. strict = FALSE is for a
  # portal's metadata, read the way jsonlite reads it: a repeated key is
  # kept and a long numeric id is not a warning.
  if (isTRUE(strict)) {
    bricklayer_json_from_json(txt, simplifyVector = isTRUE(simplify))
  } else {
    bricklayer_json_from_json(txt, simplifyVector = isTRUE(simplify),
                              duplicate_keys = "keep", bigint_warn = FALSE)
  }
}

# The compiled fetcher inside the package; plain download.file when this
# file is sourced standalone in a capsule bundle.
#' @noRd
.rmbl_fetch_url <- function(url, dest,
                            native = exists("bricklayer_fetch",
                                            mode = "function")) {
  if (native) return(bricklayer_fetch(url, dest))
  utils::download.file(url, dest, mode = "wb", quiet = TRUE)
  invisible(dest)
}


# A manifest-derived file name joined under a directory, or NULL when it is
# not a plain relative path that stays inside: "..", an absolute path, a
# drive letter, a home prefix or a symlink out are refused. The provenance
# file is attacker-authored input, and bare file.path() hashed
# "../../etc/shadow" when asked to.
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

# normalizePath() only resolves paths that exist, so a missing leaf under a
# symlinked tempdir (macOS /var -> /private/var) would never match its
# resolved parent. Resolve the deepest existing ancestor and re-append the rest.
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

# A URL the package is about to fetch, or an error in words. Resolvers
# return whatever a CKAN record (or a MITM on a cleartext hop) says, so
# before any transport sees it: https only (plain http needs the explicit
# option), never file://, and never a loopback, link-local, private or
# metadata address -- the SSRF targets.
#' @noRd
.rmbl_check_public_url <- function(url, what = "url", allow_file = FALSE,
                                   allow_http = getOption("rmoriebricklayer.allow_http", FALSE),
                                   resolve = FALSE) {
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
  why <- .Call(C_rmbl_url_check, url, isTRUE(allow_http), isTRUE(resolve))
  if (!nzchar(why)) return(url)
  scheme <- tolower(sub("^([a-z][a-z0-9+.-]*)://.*$", "\\1", url, ignore.case = TRUE))
  if (startsWith(why, "plain http") || startsWith(why, "scheme ")) {
    stop(sprintf(paste0("%s must be an https:// URL, not %s:// ('%s'); ",
                        "options(rmoriebricklayer.allow_http = TRUE) admits a ",
                        "trusted plain-http mirror"), what, scheme, url),
         call. = FALSE)
  }
  if (grepl("local|private|resolves", why)) {
    stop(sprintf("%s points at a local or private address ('%s'): refused (%s)",
                 what, url, why), call. = FALSE)
  }
  stop(sprintf("%s is refused: %s ('%s')", what, why, url), call. = FALSE)
}

# TRUE when `host` (a bare host, with or without brackets) is one the
# validator refuses: a loopback, private, link-local, metadata or local
# name in any spelling. Kept for callers that classify hosts directly.
#' @noRd
.rmbl_private_host <- function(host) {
  host <- as.character(host)[1L]
  if (is.na(host) || !nzchar(host)) return(TRUE)
  h <- if (grepl(":", host, fixed = TRUE) && !startsWith(host, "[")) paste0("[", host, "]") else host
  nzchar(.Call(C_rmbl_url_check, paste0("https://", h, "/"), FALSE, FALSE))
}

# In-process synthetic state: make_synthetic_csv() sets it, so a manifest
# built in the same session says synthetic whether or not the environment
# variable was set.
#' @noRd
.rmbl_synth_state <- new.env(parent = emptyenv())

#' @noRd
.rmbl_synthetic_flag <- function() {
  .rmbl_synthetic_env() || isTRUE(.rmbl_synth_state$made)
}

# The package, not the analysis script, owns the synthetic flag: set by
# the reference pipeline for its subprocess, read wherever a manifest is
# built or written.
#' @noRd
.rmbl_synthetic_env <- function() {
  v <- trimws(Sys.getenv("BRICKLAYER_SYNTHETIC", unset = ""))
  nzchar(v) && !tolower(v) %in% c("0", "false", "no", "off")
}
