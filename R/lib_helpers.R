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
  # first. validUTF8() and an explicit UTF-8 -> UTF-8 iconv() both work on
  # the bytes, so this does not depend on the session locale; enc2utf8()
  # does, and under a C locale it re-encodes the bytes as Latin-1 instead
  # of flagging them.
  inv <- !is.na(x) & !validUTF8(x)
  if (any(inv)) {
    x[inv] <- iconv(x[inv], "UTF-8", "UTF-8", sub = "")
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
  ok <- tryCatch(
    {
      # the UTF-8 bytes go to a binary connection: a text connection with
      # encoding = "UTF-8" re-encodes from the native locale, and in a C
      # locale that is a warning per accented string
      con <- file(path, open = "wb")
      on.exit(close(con), add = TRUE)
      writeBin(
        charToRaw(paste0(
          paste(enc2utf8(as.character(text)), collapse = "\n"),
          "\n"
        )),
        con
      )
      TRUE
    },
    error = function(e) FALSE
  )
  if (!ok) {
    writeLines(toascii(text), path)
  } # nocov -- encoding-error retry
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
    return(unname(tolower(f(path))))
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
  h <- tolower(grep("^[0-9A-Fa-f]{64}$", h, value = TRUE))
  if (length(h)) h[[1L]] else NULL
}

#' Refuses a path that is not one existing file.
#' @param path The path given to sha256file().
#' @return NULL, invisibly.
#' @noRd
.rmbl_sha256_path <- function(path) {
  if (
    !is.character(path) ||
      length(path) != 1L ||
      is.na(path) ||
      !file.exists(path) ||
      dir.exists(path)
  ) {
    stop(
      sprintf(
        "sha256file: %s is not a file",
        if (is.character(path) && length(path) == 1L) path else "`path`"
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
  txt <- if (length(x) == 1L && !grepl("^\\s*[\\[{\"]", x) && file.exists(x)) {
    paste(readLines(x, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
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
  rel <- as.character(unlist(rel))[1L]
  if (is.na(rel) || !nzchar(rel)) {
    return(NULL)
  }
  if (grepl("^([/\\\\]|~|[A-Za-z]:)", rel)) {
    return(NULL)
  }
  parts <- strsplit(gsub("\\", "/", rel, fixed = TRUE), "/", fixed = TRUE)[[1L]]
  if (any(parts %in% c("", ".", ".."))) {
    return(NULL)
  }
  full <- file.path(dir, rel)
  d <- .rmbl_realpath(dir)
  f <- .rmbl_realpath(full)
  if (!startsWith(f, paste0(d, "/"))) {
    return(NULL)
  }
  full
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
  url <- as.character(unlist(url))[1L]
  if (is.na(url) || !nzchar(url)) {
    stop(sprintf("%s is empty", what), call. = FALSE)
  }
  if (isTRUE(allow_file) && grepl("^file://", url, ignore.case = TRUE)) {
    return(url)
  }
  if (!grepl("^[a-z][a-z0-9+.-]*://", url, ignore.case = TRUE)) {
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
  scheme <- tolower(sub(
    "^([a-z][a-z0-9+.-]*)://.*$",
    "\\1",
    url,
    ignore.case = TRUE
  ))
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
  scheme <- tolower(sub(
    "^([a-z][a-z0-9+.-]*)://.*$",
    "\\1",
    url,
    ignore.case = TRUE
  ))
  if (!scheme %in% c("https", "http")) {
    return(sprintf("scheme %s is not allowed", scheme))
  }
  auth <- sub(
    "[/?#].*$",
    "",
    sub("^[a-z][a-z0-9+.-]*://", "", url, ignore.case = TRUE)
  )
  host <- tolower(sub(":[0-9]*$", "", sub("^.*@", "", auth)))
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
  nzchar(v) && !tolower(v) %in% c("0", "false", "no", "off")
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
  x <- enc2utf8(as.character(x))
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
