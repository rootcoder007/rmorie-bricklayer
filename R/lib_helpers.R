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
#' the package), the same digest comes from base R's
#' \code{tools::sha256sum()} (R 4.5.0 and later) or else from the bundle's
#' pure-R SHA-256 implementation, which reads the file 1 MB at a time (slow
#' on a large file, but in constant memory).
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
  .rmbl_sha256_path(path)
  # inside the package: the compiled SHA-256 core over the file read in chunks
  # (identical output to digest::digest(file = path, algo = "sha256")); sourced
  # standalone in a capsule bundle: base R's tools::sha256sum() (R >= 4.5.0),
  # else the pure-R FIPS 180-4 implementation from sha256_native.R, streamed
  # (a 300 MB file read whole took 2.9 GB and more than five minutes)
  if (exists("csha256", mode = "function")) {
    return(.rmbl_sha256_stream(path))
  }
  .rmbl_sha256_bndl(path)
}

#' Transliterate Text to Plain ASCII
#'
#' Converts a character vector to plain 7-bit ASCII, transliterating
#' accented or non-Latin characters to their nearest ASCII equivalent (for
#' example, an accented capital A becomes a plain \code{"A"}). Falls back to
#' dropping any character that has no transliteration. This is the
#' deterministic \code{"fallback"} used by
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
#' ligatures (sharp s to \code{"ss"}, the ae ligature to \code{"ae"}, thorn to
#' \code{"th"} and so on) and
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
  # first, from the bytes, so this does not depend on the session locale;
  # enc2utf8() does, and under a C locale it re-encodes the bytes as Latin-1
  # instead of flagging them. iconv(sub = "") kept a 5-byte form.
  inv <- !is.na(x) & !validUTF8(x)
  if (any(inv)) {
    x[inv] <- .rmbl_esc8(x[inv], drop = TRUE)
  }
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
#' @param force A single logical: `TRUE` always transliterates every
#'   element to ASCII; `FALSE` (the default) only the elements that are not
#'   valid UTF-8. Anything other than `TRUE` counts as `FALSE`.
#' @return A character vector the length of `x`: each element unchanged
#'   when it is valid UTF-8 (and `force` is not `TRUE`), otherwise its
#'   ASCII transliteration.
#' @seealso [toascii()], which does the transliteration.
#' @export
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
#' @inheritParams toascii
asciifb <- function(x, force = FALSE) {
  .rmbl_no_fn(x = x)
  x <- as.character(x)
  if (isTRUE(force)) {
    return(toascii(x))
  }
  out <- x
  # Test the bytes, not the locale's opinion of them (see toascii()).
  bad <- !is.na(x) & !validUTF8(x)
  if (any(bad)) {
    out[bad] <- toascii(x[bad])
  }
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
  path <- .rmbl_out_file(path, "path", connection = FALSE)
  # the UTF-8 bytes are written as they are: a text connection with
  # encoding = "UTF-8" re-encodes from the native locale, and in a C locale
  # that is a warning per accented string
  bytes <- tryCatch(
    charToRaw(paste0(
      paste(enc2utf8(as.character(text)), collapse = "\n"),
      "\n"
    )),
    error = function(e) NULL
  )
  if (is.null(bytes)) {
    bytes <- toascii(text)
  } # nocov -- encoding-error retry
  .rmbl_wfile(path, bytes)
  invisible(path)
}

# In-process synthetic state: mksyncsv() sets it, so a manifest
# built in the same session says synthetic whether or not the environment
# variable was set.
#' @noRd
.rmbl_synth_state <- new.env(parent = emptyenv())

#' A file's SHA-256 in a bundle, by the fastest way at hand.
#'
#' In order: an installed rmoriebricklayer (1.0.3 or later), whose
#' sha256file() is compiled; base R's tools::sha256sum() (R 4.5.0 or
#' later); the system's own tool (sha256sum on Linux, shasum on macOS,
#' certutil on Windows, or openssl); else the pure-R implementation,
#' which runs at about 17 KB a second, so only for a file of at most `cap`
#' bytes (4 MiB, about four minutes; 8 MiB took 485 s).
#' @inheritParams .bndl_write_text
#' @param base Whether tools::sha256sum() is used when R has it.
#' @param pkg The installed package's sha256file(), from .rmbl_bsha(), or
#'   NULL.
#' @param os The system tool's digest, a function of the path that returns
#'   NULL when there is none, or NULL.
#' @param cap The largest file the pure-R implementation is used for.
#' @return 64 lower-case hex digits.
#' @noRd
.rmbl_sha256_bndl <- function(
  path,
  base = exists("sha256sum", envir = asNamespace("tools"), inherits = FALSE),
  pkg = .rmbl_bsha(),
  os = function(p) .rmbl_ossha(p),
  cap = 4194304
) {
  if (is.function(pkg)) {
    return(pkg(path))
  }
  if (isTRUE(base)) {
    f <- get("sha256sum", envir = asNamespace("tools"))
    return(unname(.rmbl_lower(f(path))))
  }
  h <- if (is.function(os)) os(path)
  if (!is.null(h)) {
    return(h)
  }
  if (isTRUE(file.size(path) > cap)) {
    stop(sprintf(
      paste0(
        "%s is %.0f MB: this R has no fast SHA-256 (R 4.5.0 or later has ",
        "one, and so has the rmoriebricklayer package: ",
        "install.packages(\"rmoriebricklayer\")), and the pure-R one takes ",
        "hours on a file this size"
      ),
      basename(path), file.size(path) / 1048576
    ), call. = FALSE)
  }
  .rmbl_sha256_file(path)
}

#' The sha256file() of an installed rmoriebricklayer 1.0.3 or later, for a
#' bundle (as .rmbl_bdl() lends its bldl()).
#' @param pkg The package to look for.
#' @param own Whether this code is the package itself (then there is no
#'   other to ask, and asking it would call this again).
#' @return A function, or NULL.
#' @noRd
.rmbl_bsha <- function(
  pkg = "rmoriebricklayer",
  own = exists("csha256", mode = "function") ||
    identical(environmentName(topenv(environment())), pkg)
) {
  if (isTRUE(own)) {
    return(NULL)
  }
  ok <- requireNamespace(pkg, quietly = TRUE) &&
    utils::packageVersion(pkg) >= "1.0.3"
  if (isTRUE(ok)) getExportedValue(pkg, "sha256file") else NULL
}

#' A file's SHA-256 by the system's own tool: sha256sum (Linux), shasum
#' -a 256 (macOS, and where there is no sha256sum) or certutil (Windows).
#' @inheritParams .bndl_write_text
#' @param sys The system's name, as Sys.info() gives it.
#' @return 64 lower-case hex digits, or NULL when there is no tool or its
#'   answer is not a digest.
#' @noRd
.rmbl_ossha <- function(path, sys = Sys.info()[["sysname"]]) {
  tool <- .rmbl_shatool(sys)
  if (is.null(tool)) {
    return(NULL)
  }
  out <- tryCatch(
    suppressWarnings(system2(
      tool$cmd, c(tool$args, shQuote(path), tool$post),
      stdout = TRUE, stderr = FALSE
    )),
    error = function(e) character()
  )
  if (!is.null(attr(out, "status"))) {
    return(NULL)
  }
  .rmbl_shaout(out, if (isTRUE(tool$plain)) "" else sys)
}

#' The system tool .rmbl_ossha() runs.
#' @inheritParams .rmbl_ossha
#' @return A list (cmd, args before the path, post after it), or NULL
#'   when there is none.
#' @noRd
.rmbl_shatool <- function(sys) {
  w <- function(x) unname(Sys.which(x))
  ossl <- function() {
    p <- w("openssl")
    if (nzchar(p)) list(cmd = p, args = c("dgst", "-sha256", "-r"),
                        plain = TRUE)
  }
  if (identical(sys, "Windows")) {
    p <- w("certutil")
    return(if (nzchar(p)) {
      list(cmd = p, args = "-hashfile", post = "SHA256")
    } else {
      ossl()
    })
  }
  p <- w("sha256sum")
  if (nzchar(p) && !identical(sys, "Darwin")) {
    return(list(cmd = p, args = character()))
  }
  p <- w("shasum")
  if (nzchar(p)) list(cmd = p, args = c("-a", "256")) else ossl()
}

#' The digest in a system tool's answer, checked.
#' @param out The lines it printed.
#' @inheritParams .rmbl_ossha
#' @return 64 lower-case hex digits, or NULL.
#' @noRd
.rmbl_shaout <- function(out, sys) {
  if (identical(sys, "Windows")) {
    # certutil: a heading line, the digest (older ones space it), a status
    h <- gsub(" ", "", out[-1L], fixed = TRUE)
  } else {
    # "<digest>  <name>"; a name holding a backslash or newline starts the
    # line with a backslash
    h <- sub("^\\\\", "", sub("[ \t].*$", "", out))
  }
  h <- .rmbl_lower(grep("^[0-9A-Fa-f]{64}$", h, value = TRUE))
  if (length(h)) h[[1L]] else NULL
}

#' Refuses a path that is not one existing file.
#' @param path The path given to sha256file().
#' @return NULL, invisibly.
#' @noRd
.rmbl_sha256_path <- function(path) {
  # a name the system cannot convert (bytes that are not text, on Windows)
  # stops file.exists() itself: such a path is no file either
  ok <- is.character(path) && length(path) == 1L && !is.na(path) &&
    isTRUE(tryCatch(
      file.exists(path) && !dir.exists(path),
      error = function(e) FALSE
    ))
  if (!ok) {
    stop(
      sprintf(
        "sha256file: %s is not a file",
        if (is.character(path) && length(path) == 1L) {
          .rmbl_ctl_escape(path)
        } else {
          "`path`"
        }
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Hashes a file with SHA-256 one chunk at a time.
#'
#' The digest of a file read `chunk` bytes at a time (8 MB), so memory stays at
#' one chunk whatever the file's size; a file larger than one chunk gets a
#' byte-progress bar (drawn only after the usual lazy start, so a quick hash
#' shows nothing).
#' @param path The file to hash, read in chunks with progress when large.
#' @param chunk The number of bytes read at a time.
#' @return The digest as lower-case hex.
#' @noRd
.rmbl_sha256_stream <- function(path, chunk = 8388608L) {
  # a directory is refused by name: gzfile() on one hung (1.0.3)
  path <- .rmbl_file1(path, "path")
  size <- file.info(path)$size
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)
  pg <- if (is.finite(size) && size > chunk) {
    blprog(sprintf("sha256 %s", .rmbl_printable(basename(path))), size)
  }
  if (!is.null(pg)) {
    on.exit(pg$done(), add = TRUE)
  }
  state <- NULL
  done <- 0
  repeat {
    b <- readBin(con, "raw", n = chunk)
    if (!length(b)) {
      break
    }
    state <- .Call(C_rmbl_sha256_chunk, state, b, FALSE)
    done <- done + length(b)
    if (!is.null(pg)) {
      pg$update(
        done,
        info = sprintf("%s of %s", .bl_fmt_bytes(done), .bl_fmt_bytes(size))
      )
    }
  }
  .Call(C_rmbl_sha256_chunk, state, NULL, TRUE)
}

## ----------------- Unicode-safe text with ASCII fallback -----------------

#' Tells whether stringi is installed.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_has_stringi <- function() requireNamespace("stringi", quietly = TRUE)

#' Transliterates text to ASCII without stringi.
#'
#' Deterministic no-stringi fallback. iconv(\code{"ASCII//TRANSLIT"}) is
#' locale-dependent: under a C locale (glibc) accented characters come back as
#' \dQuote{?} -- ASCII, so the final strip keeps them. Transliterate the common
#' Latin accents by table first, then let iconv DROP (not \dQuote{?}) the rest.
#' @param x A character vector to transliterate to ASCII.
#' @return A character vector.
#' @noRd
.to_ascii_fallback <- function(x) {
  # Under a C locale UTF-8 bytes arrive unmarked and chartr() errors on
  # them; declare valid UTF-8 so translation is locale-independent.
  valid <- !is.na(x) & validUTF8(x)
  Encoding(x[valid]) <- "UTF-8"
  tab <- .to_ascii_table()
  x <- chartr(tab$from, tab$to, x)
  multi <- list(
    c("\u00df", "ss"),
    c("\u00c6", "AE"),
    c("\u00e6", "ae"),
    c("\u0152", "OE"),
    c("\u0153", "oe"),
    c("\u00de", "Th"),
    c("\u00fe", "th")
  )
  for (pair in multi) {
    x <- gsub(pair[[1L]], pair[[2L]], x, fixed = TRUE)
  }
  iconv(x, to = "ASCII", sub = "")
}

#' The Latin accents .to_ascii_fallback() transliterates one for one.
#' @return A list: \code{from}, the accented letters, and \code{to}, their
#'   ASCII letters, as chartr() takes them.
#' @noRd
.to_ascii_table <- function() {
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
  list(from = from, to = to)
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
  isf <- length(x) == 1L && !grepl("^\\s*[\\[{\"]", x, useBytes = TRUE) &&
    file.exists(x)
  # text that is also a device's name (nul, con on Windows) stays text
  txt <- if (isf && .rmbl_isreg(x)) {
    # the package's JSON documents are held to the 32 MiB its manifest reader
    # takes: readLines() of a larger one failed as "cannot allocate buffer"
    x <- .rmbl_file1(x, "path", max = 32 * 2^20)
    paste(.rmbl_json_file_lines(x), collapse = "\n")
  } else {
    x
  }
  # what came back is TEXT to parse, never a second address to fetch or a path
  # to open (fourth review: a body that was a bare URL made the package fetch
  # it) strict = TRUE (the default, and the package's own documents: provenance,
  # manifests, bundles): a repeated key is an error. strict = FALSE is for a
  # portal's metadata, read the way jsonlite reads it: a repeated key is kept
  # and a long numeric id is not a warning.
  if (isTRUE(strict)) {
    .rmbl_json_text(txt, simplifyVector = isTRUE(simplify))
  } else {
    .rmbl_json_text(
      txt,
      simplifyVector = isTRUE(simplify),
      duplicate_keys = "keep",
      bigint_warn = FALSE
    )
  }
}

#' Downloads a URL to a file.
#'
#' The compiled fetcher inside the package; the bundle fetcher
#' (.rmbl_bfetch()) when this file is sourced standalone in a capsule
#' bundle.
#' @param url The source file's URL, fetched to `dest`.
#' @param dest The destination file.
#' @param native Whether the compiled fetcher is there to use.
#' @return `dest`, invisibly.
#' @noRd
.rmbl_fetch_url <- function(
  url,
  dest,
  native = exists("blfetch", mode = "function")
) {
  if (native) {
    return(blfetch(url, dest))
  }
  .rmbl_bfetch(url, dest, cap = 16777216)
}

#' Downloads a URL in a bundle: only through the package's own downloader.
#'
#' A bundle sources the package's R files without its compiled transport.
#' Base R cannot pin the addresses it connects to, re-check a redirect the
#' server gives only to the body request, or resolve names on Windows and
#' over IPv6, so a bundle never downloads with it: when rmoriebricklayer
#' (1.0.3 or later) is installed on the reviewer's machine, its bldl()
#' downloads (addresses resolved, checked and pinned, every hop re-checked,
#' size capped); otherwise the download is refused with what to do instead.
#' @param url The URL, checked against the URL policy first.
#' @param dest The destination file.
#' @param cap The most bytes the body may have.
#' @param dl The downloader, from .rmbl_bdl(); NULL when there is none.
#' @return `dest`, invisibly.
#' @noRd
.rmbl_bfetch <- function(url, dest, cap = 2147483648, dl = .rmbl_bdl()) {
  url <- .rmbl_check_public_url(url, "url")
  if (is.null(dl)) {
    stop(.rmbl_nodl(), call. = FALSE)
  }
  dl(url, dest, quiet = TRUE, maxbytes = cap)
  invisible(dest)
}

#' The package's downloader, when a bundle can use it.
#'
#' Inside the package: bldl() itself. Sourced in a bundle: the bldl() of an
#' installed rmoriebricklayer 1.0.3 or later (older ones did not re-check
#' redirects), else NULL.
#' @param pkg The package to look for.
#' @param own Whether this code already has bldl() (inside the package).
#' @return A function, or NULL.
#' @noRd
.rmbl_bdl <- function(pkg = "rmoriebricklayer",
                      own = exists("bldl", mode = "function")) {
  if (isTRUE(own)) {
    return(get("bldl", mode = "function"))
  }
  ok <- requireNamespace(pkg, quietly = TRUE) &&
    utils::packageVersion(pkg) >= "1.0.3"
  if (isTRUE(ok)) getExportedValue(pkg, "bldl") else NULL
}

#' Why a bundle does not download, and what to do instead.
#' @return One string.
#' @noRd
.rmbl_nodl <- function() {
  paste0(
    "this bundle downloads only through the rmoriebricklayer package ",
    "(1.0.3 or later), which checks every address and redirect: install ",
    "it with install.packages(\"rmoriebricklayer\") and run this again, ",
    "or put the data file in the bundle's data/ folder (its pinned ",
    "SHA-256 is still checked)"
  )
}

#' Joins a manifest's relative file name under a directory, or refuses it.
#'
#' A manifest-derived file name joined under a directory, or NULL when it is
#' not a plain relative path that stays inside: \code{".."}, an absolute path, a
#' drive letter, a home prefix or a symlink out are refused. The provenance
#' file is attacker-authored input, and bare file.path() hashed
#' \code{"../../etc/shadow"} when asked to.
#' @param rel The relative name from the manifest.
#' @param dir The directory it must stay inside.
#' @return The joined path, or NULL.
#' @noRd
.rmbl_safe_rel <- function(rel, dir) {
  # by its bytes: a name read from JSON is marked UTF-8, and R translated it
  # to the session's encoding before looking for it (.rmbl_fspath())
  rel <- .rmbl_fspath(as.character(unlist(rel))[1L])
  dir <- .rmbl_fspath(dir)
  if (is.na(rel) || nzchar(.rmbl_relwhy(rel))) {
    return(NULL)
  }
  full <- file.path(dir, rel)
  d <- .rmbl_realpath(dir)
  f <- .rmbl_realpath(full)
  sl <- "/"
  if (!.rmbl_bstarts(f, paste0(d, sl))) {
    return(NULL)
  }
  full
}

#' Why a relative path may not be listed in a bundle, or "".
#'
#' One rule for a bundle's names, used when the bundle is made and when it
#' is checked. The check refuses a name that could reach outside the
#' folder: an empty name, an absolute path, a home (\code{~}) or drive
#' (\code{c:}) prefix, an empty, \code{.} or \code{..} part, a backslash
#' parting them as on Windows. A bundle is made only of names that verify
#' on every system (`strict`): those, and a name that is not UTF-8, holds a
#' backslash, one of \code{< > : " | ? *} or a control character, or has a
#' part that ends in a dot or a space or that Windows reserves (CON, PRN,
#' AUX, NUL, COM1 to COM9, LPT1 to LPT9, COM and LPT with a superscript
#' 1, 2 or 3, with any extension). So what is bundled verifies, and what
#' the check refuses is never signed. Letters are compared by their ASCII
#' bytes (.rmbl_lower()): with ignore.case, a Turkish locale did not take
#' "I:" for a drive letter.
#' @param rel Relative paths, their parts parted by "/".
#' @param strict TRUE when a bundle is made.
#' @return For each, the reason it is refused, or "".
#' @noRd
.rmbl_relwhy <- function(rel, strict = FALSE) {
  low <- .rmbl_lower(rel)
  g <- function(re) grepl(re, low, perl = TRUE, useBytes = TRUE)
  why <- list(
    "it is empty" = !nzchar(rel),
    "it is an absolute path" = g("^[/\\\\]"),
    "it starts with ~, a home folder" = g("^~"),
    "it starts with a drive letter" = g("^[a-z]:"),
    "it has an empty, . or .. part" = g("(^|[/\\\\])[.]{0,2}([/\\\\]|$)")
  )
  if (strict) {
    # superscript one, two and three in UTF-8
    sup <- "\\xc2\\xb9|\\xc2\\xb2|\\xc2\\xb3"
    win <- stats::setNames(list(
      g("[\\\\]"),
      g("[<>:\"|?*\001-\037]"),
      g("[. ](/|$)"),
      g(paste0("(^|/)(con|prn|aux|nul|(com|lpt)([1-9]|", sup,
               "))([.][^/]*)?(/|$)"))
    ), c(
      "it holds a backslash, which parts folders on Windows",
      "it holds < > : \" | ? * or a control character, which Windows refuses",
      "a part of it ends in a dot or a space, which Windows drops",
      paste("a part of it is a name Windows reserves (CON, PRN, AUX, NUL,",
            "COM1-9, LPT1-9, COM or LPT with a superscript 1, 2 or 3)")
    ))
    why <- c(list("it is not valid text (UTF-8)" = !validUTF8(rel)), why, win)
  }
  out <- character(length(rel))
  for (j in rev(seq_along(why))) {
    out[why[[j]]] <- names(why)[[j]]
  }
  out
}

#' Resolves a path that may not exist yet through its deepest existing ancestor.
#'
#' normalizePath() only resolves paths that exist, so a missing leaf under a
#' symlinked tempdir (macOS /var -> /private/var) would never match its resolved
#' parent. Resolve the deepest existing ancestor and re-append the rest.
#' @param p The path to resolve, which may not exist yet.
#' @return The resolved path.
#' @noRd
.rmbl_realpath <- function(p) {
  tail <- character()
  while (!file.exists(p) && dirname(p) != p) {
    tail <- c(basename(p), tail)
    p <- dirname(p)
  }
  # by its bytes: a folder name that is not UTF-8 stopped sub() in a UTF-8
  # locale ("input string 1 is invalid")
  p <- sub("/+$", "", normalizePath(p, winslash = "/", mustWork = FALSE),
           useBytes = TRUE)
  if (length(tail)) paste(c(p, tail), collapse = "/") else p
}

#' Letters A to Z made lower case by their bytes, whatever the locale.
#'
#' tolower() and ignore.case follow the locale: in a Turkish one "I" is not
#' the capital of "i". Every byte outside A to Z is kept, so text that is
#' not UTF-8 is never refused and other letters are left as they are.
#' @param x Text whose capitals are made small.
#' @return `x` with A to Z made a to z, its encoding marks and names kept.
#' @noRd
.rmbl_lower <- function(x) {
  x <- as.character(x)
  up <- !is.na(x) & grepl("[A-Z]", x, perl = TRUE, useBytes = TRUE)
  x[up] <- vapply(x[up], function(s) {
    b <- charToRaw(s)
    u <- b >= as.raw(0x41) & b <= as.raw(0x5a)
    b[u] <- as.raw(as.integer(b[u]) + 32L)
    r <- rawToChar(b)
    Encoding(r) <- Encoding(s)
    r
  }, "", USE.NAMES = FALSE)
  x
}

#' Letters a to z made upper case by their bytes, whatever the locale (in a
#' Turkish one toupper("i") is a dotted capital I).
#' @param x Text whose small letters are made capitals.
#' @return `x` with a to z made A to Z, its encoding marks and names kept.
#' @noRd
.rmbl_upper <- function(x) {
  x <- as.character(x)
  lo <- !is.na(x) & grepl("[a-z]", x, perl = TRUE, useBytes = TRUE)
  x[lo] <- vapply(x[lo], function(s) {
    b <- charToRaw(s)
    u <- b >= as.raw(0x61) & b <= as.raw(0x7a)
    b[u] <- as.raw(as.integer(b[u]) - 32L)
    r <- rawToChar(b)
    Encoding(r) <- Encoding(s)
    r
  }, "", USE.NAMES = FALSE)
  x
}

#' A regular expression made to match ASCII letters of either case by
#' itself, for perl = TRUE: ignore.case follows the locale, and in a
#' Turkish one "I" does not match "i".
#'
#' Each letter outside a class becomes a class of both cases; a letter or a
#' range of letters inside one gains the other case. What follows a
#' backslash is kept as it is, with its braces (\\p{L}, \\x{e9}), as are
#' POSIX classes ([:alpha:]).
#' @param re One regular expression.
#' @return The expression.
#' @noRd
.rmbl_ci <- function(re) {
  ch <- strsplit(re, "", fixed = TRUE, useBytes = TRUE)[[1L]]
  out <- character()
  i <- 1L
  cls <- FALSE
  while (i <= length(ch)) {
    r <- .rmbl_ci1(ch, i, cls)
    out <- c(out, r$s)
    cls <- r$cls
    i <- r$i
  }
  paste(out, collapse = "")
}

#' One step of .rmbl_ci(): the text for the characters at `i`.
#' @param ch The expression's characters.
#' @param i Where the step starts.
#' @param cls Whether `i` is inside a bracketed class.
#' @return A list: `s` (the text), `i` (where the next step starts) and
#'   `cls`.
#' @noRd
.rmbl_ci1 <- function(ch, i, cls) {
  c1 <- ch[[i]]
  if (c1 == "\\") {
    return(.rmbl_ci_esc(ch, i, cls))
  }
  if (c1 == "[" || (cls && c1 == "]")) {
    return(.rmbl_ci_br(ch, i, cls))
  }
  .rmbl_ci_let(ch, i, cls)
}

#' A backslash and what it escapes, with the braces that follow (\\p{L}),
#' kept as they are.
#' @inheritParams .rmbl_ci1
#' @return As for .rmbl_ci1().
#' @noRd
.rmbl_ci_esc <- function(ch, i, cls) {
  j <- i + 1L
  if (j + 1L <= length(ch) && ch[[j + 1L]] == "{") {
    j <- match("}", ch[-seq_len(j)], length(ch) - j) + j
  }
  list(s = paste(ch[i:min(j, length(ch))], collapse = ""), i = j + 1L,
       cls = cls)
}

#' A bracket: the start of a class (with a leading ^ and ]), its end, a
#' POSIX class inside one ([:alpha:]), or a literal bracket inside one.
#' @inheritParams .rmbl_ci1
#' @return As for .rmbl_ci1().
#' @noRd
.rmbl_ci_br <- function(ch, i, cls) {
  at <- function(k) if (k <= length(ch)) ch[[k]] else ""
  if (!cls) {
    j <- i + 1L
    j <- j + (at(j) == "^")
    j <- j + (at(j) == "]")
    return(list(s = paste(ch[i:(j - 1L)], collapse = ""), i = j, cls = TRUE))
  }
  if (ch[[i]] == "]") {
    return(list(s = "]", i = i + 1L, cls = FALSE))
  }
  if (at(i + 1L) != ":") {
    return(list(s = "[", i = i + 1L, cls = TRUE))
  }
  j <- match("]", ch[-seq_len(i)], length(ch) - i) + i
  list(s = paste(ch[i:j], collapse = ""), i = j + 1L, cls = TRUE)
}

#' A character outside a backslash and brackets: an ASCII letter (or a
#' range of them in a class) gains its other case.
#' @inheritParams .rmbl_ci1
#' @return As for .rmbl_ci1().
#' @noRd
.rmbl_ci_let <- function(ch, i, cls) {
  both <- function(x) paste0(.rmbl_lower(x), .rmbl_upper(x))
  c1 <- ch[[i]]
  r3 <- paste(ch[i:min(i + 2L, length(ch))], collapse = "")
  if (cls && grepl("^[A-Za-z]-[A-Za-z]$", r3, perl = TRUE, useBytes = TRUE)) {
    return(list(s = both(r3), i = i + 3L, cls = TRUE))
  }
  if (!grepl("^[A-Za-z]$", c1, perl = TRUE, useBytes = TRUE)) {
    return(list(s = c1, i = i + 1L, cls = cls))
  }
  list(s = if (cls) both(c1) else paste0("[", both(c1), "]"), i = i + 1L,
       cls = cls)
}

#' The tables of .rmbl_caseless(), read once from inst/unicode.
#' @return An environment: `dk`, `dv` (canonical decompositions), `fk`,
#'   `fv` (simple case folding) and `ck`, `cv` (combining classes).
#' @noRd
.rmbl_uc_tab <- function() {
  t <- .rmbl_uc
  if (is.null(t$dk)) {
    f <- system.file("unicode", "caseless.txt", package = "rmoriebricklayer")
    p <- strsplit(readLines(f), " ", fixed = TRUE)
    k <- vapply(p, `[[`, "", 1L)
    h <- function(kind, i) {
      strtoi(vapply(p[k == kind], `[[`, "", i), 16L)
    }
    t$dv <- lapply(p[k == "D"], function(x) strtoi(x[-1:-2], 16L))
    t$dk <- h("D", 2L)
    t$fk <- h("F", 2L)
    t$fv <- h("F", 3L)
    t$ck <- h("C", 2L)
    t$cv <- as.integer(vapply(p[k == "C"], `[[`, "", 3L))
  }
  t
}

.rmbl_uc <- new.env(parent = emptyenv())

#' Code points in Unicode's canonical decomposition (NFD): each decomposed
#' fully (by the table, a Hangul syllable by its arithmetic) and each run of
#' combining marks put in the order of their classes. Many strings are
#' taken at once: `id` says which string each code point belongs to, and a
#' run of marks never crosses from one string into the next.
#' @param u Code points.
#' @param t The tables (.rmbl_uc_tab()).
#' @param id The string of each code point, in rising order; one string by
#'   default.
#' @return A list: the code points `u` and their strings `id`.
#' @noRd
.rmbl_nfdv <- function(u, t, id = rep(1L, length(u))) {
  i <- match(u, t$dk)
  dec <- which(!is.na(i))
  hg <- which(u >= 0xAC00 & u <= 0xD7A3)
  s <- u[hg] - 0xAC00
  len <- rep(1L, length(u))
  len[dec] <- lengths(t$dv[i[dec]])
  len[hg] <- 2L + (s %% 28 != 0)
  at <- cumsum(len) - len + 1L
  out <- integer(sum(len))
  out[at] <- u
  out[rep(at[dec], len[dec]) + sequence(len[dec]) - 1L] <-
    as.integer(unlist(t$dv[i[dec]], use.names = FALSE))
  out[at[hg]] <- as.integer(0x1100 + s %/% 588)
  out[at[hg] + 1L] <- as.integer(0x1161 + (s %% 588) %/% 28)
  tail <- s %% 28 != 0
  out[at[hg][tail] + 2L] <- as.integer(0x11A7 + s[tail] %% 28)
  id <- rep(id, len)
  cc <- t$cv[match(out, t$ck)]
  cc[is.na(cc)] <- 0L
  o <- order(id, cumsum(cc == 0L), cc, seq_along(out))
  list(u = out[o], id = id)
}

#' A user's pattern matched whatever the case of its letters, accented ones
#' included, in any locale.
#'
#' In a UTF-8 session this is grepl(ignore.case = TRUE) as it always was.
#' Elsewhere (the C locale of a container) that engine folds the letters
#' a to z only, so text past ASCII is matched by the Perl-compatible one,
#' which folds by Unicode; text typed there arrives unmarked, and is taken
#' for UTF-8 when its bytes are valid UTF-8.
#' @param pat A regular expression.
#' @param x Character vector.
#' @param utf8 Whether the session is a UTF-8 one.
#' @return Logical vector, as grepl().
#' @noRd
.rmbl_grepl_ci <- function(pat, x, utf8 = isTRUE(l10n_info()[["UTF-8"]])) {
  if (utf8) {
    return(grepl(pat, x, ignore.case = TRUE))
  }
  mark <- function(s) {
    u <- !is.na(s) & Encoding(s) == "unknown" & validUTF8(s)
    Encoding(s[u]) <- "UTF-8"
    s
  }
  pat <- mark(pat)
  x <- mark(as.character(x))
  wide <- any(grepl("[^\\x01-\\x7f]", c(pat, x), perl = TRUE,
                    useBytes = TRUE))
  grepl(pat, x, ignore.case = TRUE, perl = wide)
}

#' Labels as they compare when case is ignored, accented capitals too, in
#' any locale: .rmbl_caseless() for valid UTF-8; in bytes that are not, the
#' letters A to Z only (tolower() stops at such a string).
#' @param x Character vector.
#' @return The keys.
#' @noRd
.rmbl_fold <- function(x) {
  x <- as.character(x)
  ok <- !is.na(x) & validUTF8(x)
  x[ok] <- .rmbl_caseless(x[ok])
  x[!ok] <- .rmbl_lower(x[!ok])
  x
}

#' Names as one system compares them when it ignores case and Unicode
#' normalisation: Unicode's canonical caseless match (NFD of the simple case
#' folding of the NFD; Unicode 15.1, section 3.13, D145).
#'
#' The tables come from the Unicode Character Database
#' (data-raw/unicode_caseless.R). Simple folding maps one character to
#' one: a sharp s is not "ss" (Windows does not take them for one name
#' either), and the Turkish dotted capital I folds to "i" with a dot above.
#' Locale plays no part.
#' @param x Valid UTF-8 names.
#' @return The keys: two names clash when their keys are equal.
#' @noRd
.rmbl_caseless <- function(x) {
  out <- .rmbl_lower(x)
  wide <- grep("[^\\x00-\\x7f]", x, perl = TRUE, useBytes = TRUE)
  if (length(wide)) {
    t <- .rmbl_uc_tab()
    # by their bytes: utf8ToInt() refuses a string marked "bytes". All the
    # names are folded in one pass: a name at a time, 100,000 names with
    # accents took 80 seconds
    cp <- lapply(x[wide], function(s) utf8ToInt(rawToChar(charToRaw(s))))
    n <- lengths(cp)
    d <- .rmbl_nfdv(as.integer(unlist(cp, use.names = FALSE)), t,
                    rep(seq_along(cp), n))
    f <- match(d$u, t$fk)
    d$u[!is.na(f)] <- t$fv[f[!is.na(f)]]
    d <- .rmbl_nfdv(d$u, t, d$id)
    key <- vapply(split(d$u, factor(d$id, levels = seq_along(cp))),
                  intToUtf8, "", USE.NAMES = FALSE)
    out[wide] <- key
  }
  out
}

#' The names of a bundle that one system would take for one name.
#'
#' Windows and macOS compare names without regard to case, and macOS
#' without regard to Unicode normalisation: of "A.txt" and "a.txt", of
#' "sub/x" and "SUB/x", or of e acute written as one character and as e
#' with a combining accent, only one can be there, and a copy of the capsule
#' fails its check. Every name and every folder above one is compared by
#' .rmbl_caseless().
#' @param files Valid UTF-8 paths, relative, parted by "/".
#' @return The sets that clash, one string each ("A.txt, a.txt"); none
#'   when there is no clash.
#' @noRd
.rmbl_clash <- function(files) {
  parts <- strsplit(files, "/", fixed = TRUE, useBytes = TRUE)
  all <- unique(unlist(lapply(parts, function(p) {
    vapply(seq_along(p), function(i) paste(p[seq_len(i)], collapse = "/"), "")
  }), use.names = FALSE))
  key <- .rmbl_caseless(all)
  hit <- key %in% key[duplicated(key)]
  # in the order of the names, whatever the locale's collation
  by <- factor(key[hit], levels = unique(key[hit]))
  vapply(split(all[hit], by), .bl_names, "", USE.NAMES = FALSE)
}

#' Checks that a URL is one the package may fetch.
#'
#' A URL the package is about to fetch, or an error in words. Resolvers
#' return whatever a CKAN record (or a MITM on a cleartext hop) says, so
#' before any transport sees it: https only (plain http needs the explicit
#' option), never file://, and never a loopback, link-local, private or
#' metadata address -- the SSRF targets.
#' @param url The URL to check; only its first element is used.
#' @param what The URL argument's name (default `url`), quoted in errors.
#' @param allow_file Whether a file:// URL is accepted.
#' @param allow_http Whether plain http is accepted.
#' @param resolve Whether the host's addresses are resolved and checked too.
#' @param allow_loopback Whether plain http on the loopback host is accepted (a
#'   local model).
#' @return `url`.
#' @noRd
.rmbl_check_public_url <- function(
  url,
  what = "url",
  allow_file = FALSE,
  allow_http = .rmbl_getopt("allowhttp", FALSE),
  resolve = FALSE,
  allow_loopback = FALSE
) {
  url <- .rmbl_valid_text(as.character(unlist(url))[1L], what)
  if (is.na(url) || !nzchar(url)) {
    stop(sprintf("%s is empty", what), call. = FALSE)
  }
  if (isTRUE(allow_file) && grepl(.rmbl_ci("^file://"), url, perl = TRUE,
      useBytes = TRUE)) {
    return(url)
  }
  if (!grepl(.rmbl_ci("^[a-z][a-z0-9+.-]*://"), url, perl = TRUE,
      useBytes = TRUE)) {
    stop(sprintf("%s has no URL scheme: '%s'", what, url), call. = FALSE)
  }
  # One implementation, in C, shared with the transport itself: the authority is
  # parsed as a URL parser does, IPv4 literals are read with inet_aton's grammar
  # (127.1, 0177.0.0.1, 2130706433, 0x7f000001), IPv6 with inet_pton, local
  # names are refused by suffix, and with `resolve` every address the name
  # resolves to is tested. The fetch layer always resolves, and pins the
  # connection to the addresses it checked. `allow_loopback` is the local-model
  # relaxation (plain http on the loopback host), an argument of this one call
  # and never an option (fourth review)
  why <- .rmbl_url_why(url, allow_http, resolve, allow_loopback)
  if (!nzchar(why)) {
    return(url)
  }
  .rmbl_url_refuse(url, what, why)
}

#' Raises the error for a refused URL, in the words of its reason.
#' @param url The refused URL, shown in the error.
#' @param what The URL argument's name, at the start of the error.
#' @param why The reason from .rmbl_url_why().
#' @return Does not return.
#' @noRd
.rmbl_url_refuse <- function(url, what, why) {
  scheme <- .rmbl_lower(sub(
    .rmbl_ci("^([a-z][a-z0-9+.-]*)://.*$"),
    "\\1",
    url, perl = TRUE))
  if (startsWith(why, "plain http") || startsWith(why, "scheme ")) {
    stop(
      sprintf(
        paste0(
          "%s must be an https:// URL, not %s:// ('%s'); ",
          "options(rmoriebricklayer.allowhttp = TRUE) admits a ",
          "trusted plain-http mirror"
        ),
        what,
        scheme,
        url
      ),
      call. = FALSE
    )
  }
  if (grepl("local|private|resolves|single-label", why)) {
    stop(
      sprintf(
        "%s points at a local or private address ('%s'): refused (%s)",
        what,
        url,
        why
      ),
      call. = FALSE
    )
  }
  stop(sprintf("%s is refused: %s ('%s')", what, why, url), call. = FALSE)
}

#' Gives the reason a URL is refused.
#'
#' The reason a URL is refused (\code{""} when it is accepted). In the package
#' the C validator answers; a lib_*.R file sourced on its own inside a capsule
#' bundle has no compiled code, so a base-R check stands in: https only, and no
#' loopback, private, link-local, metadata, numeric or single-label host (it
#' does not resolve names; the package's fetch layer does).
#' @param url The URL to check, natively when the C checker is there.
#' @param allow_http Whether plain http is accepted.
#' @param resolve Whether the host's addresses are resolved and checked too.
#' @param allow_loopback Whether plain http on the loopback host is accepted.
#' @return The reason, or \code{""} when the URL is accepted.
#' @noRd
.rmbl_url_why <- function(
  url,
  allow_http = FALSE,
  resolve = FALSE,
  allow_loopback = FALSE
) {
  if (exists("C_rmbl_url_check", inherits = TRUE)) {
    return(.Call(
      C_rmbl_url_check,
      url,
      isTRUE(allow_http),
      isTRUE(resolve),
      isTRUE(allow_loopback)
    ))
  }
  .rmbl_url_why_base(url, allow_http, allow_loopback)
}

#' Gives the reason a URL is refused, in base R.
#'
#' The stand-in for the C validator in a capsule bundle: https only, and no
#' loopback, private, link-local, metadata, numeric or single-label host.
#' @param url The URL to check in base R, without the compiled code.
#' @param allow_http Whether plain http is accepted.
#' @param allow_loopback Whether plain http on the loopback host is accepted.
#' @return The reason, or \code{""} when the URL is accepted.
#' @noRd
.rmbl_url_why_base <- function(url, allow_http, allow_loopback) {
  # self-contained: a staged bundle runs this without the rest of the package
  scheme <- .rmbl_lower(sub(
    .rmbl_ci("^([a-z][a-z0-9+.-]*)://.*$"),
    "\\1",
    url, perl = TRUE))
  if (!scheme %in% c("https", "http")) {
    return(sprintf("scheme %s is not allowed", scheme))
  }
  auth <- sub(
    "[/?#].*$",
    "",
    sub(.rmbl_ci("^[a-z][a-z0-9+.-]*://"), "", url, perl = TRUE)
  )
  host <- .rmbl_lower(sub(":[0-9]*$", "", sub("^.*@", "", auth)))
  loop <- host %in%
    c("localhost", "127.0.0.1", "[::1]") ||
    startsWith(host, "127.")
  if (
    scheme == "http" && !isTRUE(allow_http) && !(isTRUE(allow_loopback) && loop)
  ) {
    return("plain http is not allowed")
  }
  if (loop && isTRUE(allow_loopback)) {
    return("")
  }
  .rmbl_host_why(host, loop)
}

#' Gives the reason a host is refused, in base R.
#' @param host The lower-case host, without port or user.
#' @param loop Whether it is the loopback host.
#' @return The reason, or \code{""} when the host is accepted.
#' @noRd
.rmbl_host_why <- function(host, loop) {
  is_v4 <- grepl("^[0-9]+(\\.[0-9]+){3}$", host)
  private4 <- is_v4 & .rmbl_private_v4(host)
  odd <- grepl("^(0x[0-9a-f]+|[0-9]+)$", host) |
    (grepl("^[0-9.x]+$", host) & !is_v4)
  v6 <- startsWith(host, "[")
  private6 <- v6 &
    grepl(
      "^\\[(::1?|::ffff:.*|f[cd][0-9a-f]*:.*|fe[89ab][0-9a-f]*:.*)\\]$",
      host
    )
  why <- c(
    "a local or private address" = isTRUE(
      !nzchar(host) | private4 | odd | private6 | loop
    ),
    "a single-label host" = !v6 & !is_v4 & !grepl(".", host, fixed = TRUE),
    "a local name" = grepl(
      "\\.(local|localhost|internal|lan|home|corp|intranet)$",
      host
    )
  )
  if (any(why)) names(why)[which(why)[1L]] else ""
}

#' Tells whether a dotted IPv4 host falls in a private range.
#' @param host The host, four dotted numbers.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_private_v4 <- function(host) {
  v4 <- suppressWarnings(as.integer(strsplit(host, ".", fixed = TRUE)[[1L]]))
  # the private, loopback, link-local and shared (CGNAT) IPv4 ranges: the first
  # octet, then the range of the second
  ranges <- matrix(
    c(
      0,
      0,
      255,
      10,
      0,
      255,
      127,
      0,
      255,
      169,
      254,
      254,
      172,
      16,
      31,
      192,
      168,
      168,
      100,
      64,
      127
    ),
    ncol = 3L,
    byrow = TRUE
  )
  any(
    v4[1L] == ranges[, 1L] & v4[2L] >= ranges[, 2L] & v4[2L] <= ranges[, 3L]
  )
}

#' Tells whether the session's data are synthetic, by the environment or by
#' `mksyncsv()`.
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
  nzchar(v) && !.rmbl_lower(v) %in% c("0", "false", "no", "off")
}

#' Parses JSON text and nothing else.
#'
#' Parse JSON TEXT and nothing else. fromjs() also accepts a URL or a file path,
#' which is right for a user's argument and wrong for bytes a server just sent:
#' a body (or a signature file) that happens to be a bare URL would make the
#' package fetch it, and one that names a local path would open it (fourth
#' review). Every parse of network- or disk-delivered content goes through here;
#' the hygiene test enumerates the call sites.
#' @param txt The text, as character or raw.
#' @param ... Options passed to `fromjs()`.
#' @return The parsed value.
#' @noRd
.rmbl_json_text <- function(txt, ...) {
  if (is.raw(txt)) {
    txt <- rawToChar(txt)
  }
  txt <- paste(as.character(txt), collapse = "\n")
  # bytes that are not UTF-8 are refused before any regular expression sees
  # them: grepl() on them warned "unable to translate ... to a wide string"
  # (audit of 30bed8e, #17)
  if (Encoding(txt) != "latin1" && !validUTF8(txt)) {
    stop("not UTF-8 text", call. = FALSE)
  }
  # the shape of a JSON value, never of an address or a path: that is the whole
  # point of this entry (fourth review: a body that was a bare URL made the
  # package fetch it)
  shaped <- grepl(
    "^\\s*([\\[{\"]|-?[0-9]|true|false|null)",
    txt,
    useBytes = TRUE
  )
  if (!shaped) {
    stop("not JSON", call. = FALSE)
  }
  # the parser itself refuses what is not JSON, with its own reasons (a repeated
  # key, a bad escape, 100 levels), under whatever options the caller passes
  fromjs(txt, ...)
}

#' Makes fetched or file-supplied text safe to print.
#'
#' Fetched or file-supplied text made safe to print: marked as the UTF-8 it is
#' (in a C locale the parser returns it unmarked, and \[\[:cntrl:\]\] on
#' unmarked text matched the bytes 0x80-0x9F inside every multi-byte character)
#' or converted, an invalid byte becoming \dQuote{?}; then ANSI escape
#' sequences, the C0 and C1 controls and DEL, the bidirectional controls
#' (U+061C, U+200E-U+200F, U+202A-U+202E, U+2066-U+2069) and the
#' default-ignorable characters that print as nothing and hide text (U+00AD,
#' U+034F, U+115F, U+3164, U+180E, U+200B, U+2060-U+2064, U+FEFF, U+FFF9-FFFB,
#' the tag characters) are removed (review of 02a38be). Kept, because they are
#' part of how real text is written (review of e57fed5): the zero-width joiner
#' and non-joiner (Hindi and Persian words, family emoji), the variation
#' selectors (U+FE00-U+FE0F, U+180B-U+180D: the colour form of an emoji,
#' Mongolian and CJK glyph variants) and a flag tag sequence (U+1F3F4, tag
#' letters, U+E007F: the flags of Scotland and Wales). One helper for every
#' printer (the data tables, the Wayback results). `lines = TRUE` keeps newlines
#' and tabs (a model's answer, which is text to read, not a cell of a table):
#' the screen-clearing, title-setting and clipboard-writing escapes still go,
#' with every other control character (review of 29a55d8, L1).
#' @param x A character vector of fetched or file text to make printable.
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
  # an operating-system command (a title, a clipboard write) ends in BEL or ESC
  # \
  x <- gsub("(*UTF)\033\\][^\a\033]*(\a|\033\\\\)?", "", x, perl = TRUE)
  x <- gsub(
    paste0(
      "(*UTF)[",
      if (lines) "\\x{00}-\\x{08}\\x{0b}-\\x{1f}" else "\\x{00}-\\x{1f}",
      "\\x{7f}-\\x{9f}\\x{00ad}\\x{034f}\\x{061c}\\x{115f}\\x{1160}",
      "\\x{17b4}\\x{17b5}\\x{180e}\\x{180f}\\x{200b}\\x{200e}\\x{200f}\\x",
      "{2028}-\\",
      "x{202e}",
      "\\x{2060}-\\x{206f}\\x{3164}\\x{feff}\\x{ffa0}\\x{fff0}-\\x{fffb}]"
    ),
    "",
    x,
    perl = TRUE
  )
  # tag characters: kept only as a flag sequence, dropped anywhere else
  gsub(
    paste0(
      "(*UTF)(\\x{1f3f4}[\\x{e0020}-\\x{e007e}]{1,8}\\x{e007f})|[\\x{e000",
      "0}-\\x",
      "{e",
      "0fff}]"
    ),
    "\\1",
    x,
    perl = TRUE
  )
}

#' Fields joined so that no two lists of them join alike.
#'
#' Each field is written as its length in bytes, a colon and the field
#' (NA as "~"). Joining with a separator let a field that held the
#' separator stand for two fields, so different settings or questions
#' could share one digest.
#' @param x The fields (coerced to character).
#' @return One string.
#' @noRd
.rmbl_fields <- function(x) {
  # UTF-8 bytes whatever the locale (enc2utf8() alone rewrote unmarked
  # UTF-8 text in a C locale)
  x <- .rmbl_as_utf8(as.character(x))
  paste(ifelse(is.na(x), "~", paste0(nchar(x, type = "bytes"), ":", x)),
        collapse = "")
}

#' Text percent-encoded as one URL part: every reserved character, and a
#' "%" too. utils::URLencode() leaves a string that already holds a "%XX"
#' as it is (repeated = FALSE), so "x%41?y=1#z" kept its "?" and "#" and
#' "%2E%2E" reached the server as "..".
#' @param x Strings.
#' @return `x`, encoded.
#' @noRd
.rmbl_pct <- function(x) {
  vapply(x, utils::URLencode, "", reserved = TRUE, repeated = TRUE,
         USE.NAMES = FALSE)
}

#' Makes a folder, or stops in words when it cannot be made.
#' @param dir The folder to make, with any missing parents.
#' @param arg The argument that named it.
#' @return NULL, invisibly.
#' @noRd
.rmbl_mkdir <- function(dir, arg) {
  if (!dir.exists(dir)) {
    suppressWarnings(dir.create(dir, recursive = TRUE))
    if (!dir.exists(dir)) {
      stop(
        sprintf("cannot create the folder `%s` names (%s)", arg, dir),
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}

#' Writes text to a file as UTF-8 bytes, whatever the locale: writeLines()
#' alone turns each character a C locale cannot show into "<U+00E9>" text
#' (a manifest naming "\u00e9.csv" was written as "<U+00E9>.csv").
#' @param text The lines.
#' @param con A file name or connection.
#' @param sep The line end.
#' @param useBytes Ignored: the bytes are always written as they are.
#' @return NULL, invisibly.
#' @noRd
.rmbl_wlines <- function(text, con = stdout(), sep = "\n", useBytes = TRUE) {
  if (is.character(con)) {
    .rmbl_wfile(con, text, sep = sep)
    return(invisible(NULL))
  }
  writeLines(enc2utf8(as.character(text)), con, sep = sep, useBytes = TRUE)
}

#' Writes a file whole or not at all.
#'
#' Every file the package writes goes through here. The content goes to a
#' new temporary file beside `path`; every write and the close are checked
#' and the temporary is renamed over `path` only when it is complete. On a
#' failure (a full disk, a file-size limit, a folder that cannot be
#' written) the temporary is removed, a file already at `path` is left as
#' it was, and the call stops in the package's words. writeLines() straight
#' to `path` left a cut-short file under the final name, and a failure at
#' close was only a warning. Bytes and text are written by the checked
#' writer of rmbl_flock.c (written, size-checked, flushed to the disk,
#' renamed); a function writes through a connection checked here.
#' @param path The file to write.
#' @param x The content: a raw vector, text (written as UTF-8 lines), or a
#'   function of one binary connection that writes it.
#' @param sep The line end, for text.
#' @param size For a function, the number of bytes it must write, or NULL.
#' @param private Whether the file is kept owner-only (0600).
#' @param binary For a function, whether its connection is binary; text
#'   (FALSE) ends lines as the platform does, as write.csv() to a path did.
#' @return `path`, invisibly.
#' @noRd
.rmbl_wfile <- function(path, x, sep = "\n", size = NULL, private = FALSE,
                        binary = TRUE) {
  path <- path.expand(path)
  # /dev/null (NUL on Windows) is where output is sent to be discarded: it
  # is written to as it is, with no temporary beside it
  if (.rmbl_discard(path)) {
    return(.rmbl_wdiscard(path, x))
  }
  old <- .rmbl_wtarget(path)
  tmp <- tempfile(".rmbl-", tmpdir = dirname(path), fileext = ".tmp")
  on.exit(unlink(tmp), add = TRUE)
  if (!is.function(x) && !is.raw(x)) {
    x <- .rmbl_eol(
      charToRaw(paste0(enc2utf8(as.character(x)), sep, collapse = ""))
    )
  }
  why <- .rmbl_wput(tmp, path, x, size, private, binary)
  if (!is.null(why)) {
    stop(
      .rmbl_fn(),
      sprintf(
        "could not write %s (%s); %s",
        path,
        why,
        if (is.na(old)) "nothing was left there" else "the file is unchanged"
      ),
      call. = FALSE
    )
  }
  if (!private) {
    Sys.chmod(path, if (is.na(old)) "666" else old, use_umask = is.na(old))
  }
  invisible(path)
}

#' Sends output to /dev/null or NUL, where it is discarded.
#' @param path The discarding target.
#' @param x As for .rmbl_wfile(): a function is run on a connection to it.
#' @return `path`, invisibly.
#' @noRd
.rmbl_wdiscard <- function(path, x) {
  if (is.function(x)) {
    con <- file(path, "wb")
    on.exit(close(con), add = TRUE)
    x(con)
  }
  invisible(path)
}

#' Refuses a target .rmbl_wfile() cannot write, in words.
#' @param path The file to be written, expanded.
#' @return Its mode when it is a file there now, else NA.
#' @noRd
.rmbl_wtarget <- function(path) {
  kind <- .rmbl_path_kind(path)
  if (kind == "other" && !file.exists(path)) {
    kind <- "missing"
  }
  dir <- dirname(path)
  bad <- if (kind == "directory") {
    "it is a folder"
  } else if (kind == "other") {
    "it is not a regular file (a device, a pipe or a socket)"
  } else if (kind == "regular" && file.access(path, 2L) != 0L) {
    "it cannot be written to"
  } else if (!dir.exists(dir)) {
    "its folder does not exist"
  } else if (file.access(dir, 2L) != 0L) {
    "its folder cannot be written to"
  }
  if (!is.null(bad)) {
    stop(.rmbl_fn(), sprintf("cannot write %s: %s", path, bad), call. = FALSE)
  }
  if (kind == "regular") file.info(path)$mode else NA
}

#' Writes the content to the temporary and moves it over the target.
#' @param tmp The temporary beside the target.
#' @param path The target.
#' @param x Bytes, or a function of a connection.
#' @param size,private,binary As for .rmbl_wfile().
#' @return NULL, or what went wrong.
#' @noRd
.rmbl_wput <- function(tmp, path, x, size, private, binary) {
  if (is.function(x)) {
    return(.rmbl_wconn(tmp, path, x, size, private, binary))
  }
  if (exists("C_rmbl_write_file_checked")) {
    return(.Call(C_rmbl_write_file_checked, tmp, path, x))
  }
  # sourced into a bundle: no compiled code, the connection writer
  .rmbl_wconn(
    tmp,
    path,
    function(con) writeBin(x, con),
    length(x),
    private
  )
}

#' Writes a temporary file through a connection and renames it into place.
#' @param tmp The temporary file, written first.
#' @param path The file it becomes.
#' @param fill A function of the open binary connection that writes it.
#' @param size The number of bytes `fill` must write, or NULL.
#' @param private Whether the file is made owner-only before it is written.
#' @param binary Whether the connection is opened binary ("wb") or as text.
#' @return NULL, or what went wrong: a write, close or rename that failed
#'   (each a warning or an error of base R), or a short copy.
#' @noRd
.rmbl_wconn <- function(tmp, path, fill, size, private = FALSE,
                        binary = TRUE) {
  # what went wrong, kept in an environment the handlers add to
  st <- new.env(parent = emptyenv())
  st$why <- character()
  keep <- function(w) {
    st$why <- c(st$why, conditionMessage(w))
    invokeRestart("muffleWarning")
  }
  own <- .rmbl_wconn_fill(tmp, fill, private, binary, st, keep)
  if (!is.null(own)) {
    stop(own)
  }
  if (!length(st$why) && !is.null(size) &&
        !identical(file.size(tmp), as.numeric(size))) {
    st$why <- sprintf("%.0f of %.0f bytes were written", file.size(tmp), size)
  }
  if (!length(st$why) &&
        !withCallingHandlers(file.rename(tmp, path), warning = keep)) {
    st$why <- c(st$why, "the finished file could not be moved into place")
  }
  if (length(st$why)) st$why[[1L]] else NULL
}

#' Opens the temporary, runs the writer and closes it, every warning and
#' error kept in `st$why`.
#' @param tmp The temporary to open.
#' @param fill,private,binary As for .rmbl_wconn().
#' @param st The environment whose `why` collects what went wrong.
#' @param keep The warning handler that adds to `st$why`.
#' @return The package's own refusal raised by `fill` (an error with no
#'   call, as the byte cap of an inflated file is), to be raised again as it
#'   is; else NULL.
#' @noRd
.rmbl_wconn_fill <- function(tmp, fill, private, binary, st, keep) {
  st$con <- NULL
  own <- tryCatch(
    withCallingHandlers(
      {
        if (private) {
          file.create(tmp)
          Sys.chmod(tmp, "0600")
        }
        st$con <- file(tmp, if (binary) "wb" else "w")
        fill(st$con)
        done <- st$con
        st$con <- NULL
        close(done)
        NULL
      },
      warning = keep
    ),
    error = function(e) {
      st$why <- c(st$why, conditionMessage(e))
      if (is.null(conditionCall(e))) e
    }
  )
  if (!is.null(st$con)) {
    tryCatch(
      withCallingHandlers(close(st$con), warning = keep),
      error = function(e) NULL
    )
  }
  own
}

#' Adds text to the end of a file, whole or not at all.
#'
#' The old bytes and the new are written as one new file through
#' .rmbl_wfile(), so a failed write leaves the file as it was: cat(append =
#' TRUE) on a full disk left half a line and only warned. Each call rewrites
#' the file, which suits the logs it serves (a line per URL or signature).
#' @param path The log to add to.
#' @param text The text added, written as it is (no line end is added).
#' @return `path`, invisibly.
#' @noRd
.rmbl_wappend <- function(path, text) {
  old <- if (file.exists(path)) {
    path <- .rmbl_file1(path, "path")
    readBin(path, "raw", file.size(path))
  }
  new <- .rmbl_eol(charToRaw(paste(enc2utf8(as.character(text)),
                                   collapse = "")))
  .rmbl_wfile(path, c(old, new))
}

#' Copies a file the user gave, whole or not at all.
#'
#' Only a regular file is copied: a device such as /dev/zero has no end,
#' and file.copy() or file.append() from one filled the disk (17 GB in five
#' minutes) and only warned when a write failed. The copy is checked
#' against the source's size.
#' @param from The file to copy.
#' @param to The copy.
#' @param what The argument that named `from`, for the message.
#' @param date Whether the copy keeps the source's modification time.
#' @return `to`, invisibly.
#' @noRd
.rmbl_fcopy <- function(from, to, what = "data", date = FALSE) {
  from <- .rmbl_file1(from, what)
  n <- file.size(from)
  .rmbl_wfile(to, function(con) {
    inp <- file(from, "rb")
    on.exit(close(inp), add = TRUE)
    repeat {
      b <- readBin(inp, "raw", 2^23)
      if (!length(b)) {
        break
      }
      writeBin(b, con)
    }
  }, size = n)
  if (date) {
    Sys.setFileTime(to, file.mtime(from))
  }
  invisible(to)
}

#' Line ends as a text connection writes them on this platform.
#'
#' writeLines() to a path wrote text through a text connection, which on
#' Windows ends every line in CR LF. Text goes to the checked writer as
#' bytes, so the same translation is made here: a file written on Windows
#' has the bytes 1.1.0 wrote, whose digests old capsules may hold.
#' @param b The bytes, lines ended in LF.
#' @param win Whether lines end in CR LF (Windows).
#' @return The bytes.
#' @noRd
.rmbl_eol <- function(b, win = .Platform$OS.type == "windows") {
  i <- b == as.raw(10L)
  if (!win || !any(i)) {
    return(b)
  }
  r <- b[rep(seq_along(b), 1L + i)]
  r[which(i) + seq_len(sum(i)) - 1L] <- as.raw(13L)
  r
}

#' Whether a path is where output is discarded: /dev/null, or NUL on
#' Windows.
#' @param path The output path, expanded.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_discard <- function(path) {
  identical(path, "/dev/null") ||
    (.Platform$OS.type == "windows" &&
      .rmbl_upper(basename(path)) %in% c("NUL", "NUL:"))
}

#' Whether a file is the temporary of a write that was cut short.
#'
#' .rmbl_wfile() writes to ".rmbl-<hex>.tmp" beside its target and removes
#' it; a session killed in between leaves it. Such a file is no content of
#' a capsule or project: it is not bundled or packed, and a check that
#' finds it says what it is.
#' @param f File paths or names.
#' @return A logical vector.
#' @noRd
.rmbl_leftover <- function(f) {
  # by bytes: a name that is not valid text made grepl() warn
  grepl("(^|[/\\\\])[.]rmbl-[0-9a-f]+[.]tmp$", f, useBytes = TRUE)
}
