# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Compressed JSON. A capsule manifest that embeds a data sample, or a
# provenance record carrying a schema for a wide table, is mostly
# repeated key names -- exactly what gzip removes. Base64 then makes the
# result safe to put inside another JSON document or an HTTP header.

#' Compressed, base64-encoded JSON
#'
#' `jsgzenc()` serialises to JSON, compresses with gzip and
#' encodes the result as base64, so it can be embedded in another JSON
#' document, a header, or a text column. `jsgzdec()` reverses
#' all three steps.
#'
#' JSON is highly compressible because every record repeats the key names,
#' so this is usually a large saving on anything record-shaped -- but it is
#' opaque. Use it for payloads that travel, and plain
#' [tojs()] for
#' anything a person is meant to read or a `git diff` is meant to
#' show.
#'
#' `raw = TRUE` skips the base64 step and returns the gzip bytes,
#' which is what to use when writing to a file rather than embedding in
#' text.
#'
#' The bytes are a real gzip member (RFC 1952, with header bytes `1f 8b`),
#' readable by `gzip -d`, `zcat` and any HTTP client, not the zlib stream
#' that `memCompress(type = "gzip")` returns. The modification time in the
#' header is zero, so the same input always gives the same bytes and a digest
#' of the result does not depend on the clock. The base64 text uses the
#' standard alphabet with line breaks every 72 characters
#' ([jsb64enc()]).
#'
#' The decoder takes the input's own type: a raw vector is read as gzip
#' bytes whatever `raw` says, and text as base64. As a guard against
#' decompression bombs it refuses a member whose declared uncompressed size
#' is over 64 MiB. Errors: text given with `raw = TRUE`; text that is not
#' base64; bytes that are not a gzip member (under 18 bytes or not starting
#' `1f 8b`); a declared size over 64 MiB; a corrupt member; invalid JSON
#' inside.
#'
#' Note that the JSON keeps data, not R types: a factor comes back as text and
#' attributes are lost. Compress
#' [jsser()] output when the
#' object must come back exactly.
#'
#' @param x Object to encode.
#' @param txt Base64 string (or raw vector of gzip bytes) from
#' `jsgzenc()`.
#' @param raw Logical scalar, default `FALSE`: return (or, for the decoder,
#' insist on) gzip bytes instead of base64 text.
#' @param ... For `jsgzenc()`, passed to
#'   [tojs()]
#' (for example `auto_unbox` or `digits`); for `jsgzdec()`,
#' passed
#' to [fromjs()] (for example
#' `simplifyVector`).
#' @return `jsgzenc()` a length-1 character vector, or a raw
#' vector when `raw = TRUE`. `jsgzdec()` the decoded
#' object, as [fromjs()]
#' returns it.
#' @seealso
#' [tojs()],
#' [jsser()]
#' for an uncompressed form that keeps types and attributes.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' x <- list(rows = data.frame(id = 1:50, value = stats::runif(50)))
#'
#' enc <- jsgzenc(x)
#' substring(enc, 1, 40)
#'
#' # Smaller than the JSON it came from, because the keys repeat.
#' c(json = nchar(tojs(x)), gzipb64 = nchar(enc))
#'
#' # Round trips.
#' identical(jsgzdec(enc)$rows$id, 1:50)
#'
#' # Raw gzip bytes, for writing to a file.
#' bytes <- jsgzenc(x, raw = TRUE)
#' class(bytes)
#' identical(jsgzdec(bytes, raw = TRUE)$rows$id, 1:50)
#'
#' # the bytes are ordinary gzip: a file any gzip tool can read
#' f <- tempfile(fileext = ".json.gz")
#' writeBin(bytes, f)
#' substr(readLines(gzfile(f), warn = FALSE), 1, 40)
#'
#' # options pass through to the JSON writer and reader
#' jsgzdec(jsgzenc(list(a = 1, b = "x"), auto_unbox = TRUE),
#'                  simplifyVector = FALSE)
#'
#' # text that is not a gzip member is refused
#' try(jsgzdec(jsb64enc("not gzip")))
#' @name jsgz
#' @export
jsgzenc <- function(x, raw = FALSE, ...) {
  txt <- tojs(x, ...)
  bytes <- .rmbl_gzip_member(charToRaw(as.character(txt)))
  if (isTRUE(raw)) {
    return(bytes)
  }
  jsb64enc(bytes)
}

#' Wrap a deflate stream in a real gzip member (RFC 1952).
#'
#' memCompress(type = \code{"gzip"}) does NOT produce gzip: it produces a zlib
#' stream (RFC 1950), whose header is 0x78 0x9c rather than gzip's 0x1f
#' 0x8b. R's own memDecompress reads both, so a round trip through this
#' package looked correct while no external tool -- gzip, zcat, a browser
#' decoding Content-Encoding: gzip -- could read the bytes at all.
#'
#' The two formats share the same deflate payload and differ only in the
#' wrapper, so the zlib header (2 bytes) and its Adler-32 trailer (4
#' bytes) come off and the gzip header and trailer go on. MTIME is left
#' at zero so the same input always gives the same bytes: a capsule's
#' digest must not depend on the clock.
#' @param bytes The raw bytes to compress.
#' @return A raw vector holding one gzip member with MTIME zero.
#' @noRd
.rmbl_gzip_member <- function(bytes) {
  # memCompress(type = "gzip") returns a zlib stream (CMF/FLG header, deflate
  # body, Adler-32 trailer), never fewer than six bytes
  z <- memCompress(bytes, type = "gzip")
  deflate <- z[3L:(length(z) - 4L)]
  n <- length(bytes)
  # Arithmetic, not bit operations: a CRC-32 runs up to 2^32 - 1 and R's
  # bitwAnd is signed 32-bit, so it returns NA for anything above
  # 2^31 - 1 -- which silently wrote a zero trailer for half of all
  # inputs.
  le32 <- function(v) {
    v <- as.numeric(v) %% 4294967296
    as.raw(c(
      v %% 256,
      (v %/% 256) %% 256,
      (v %/% 65536) %% 256,
      (v %/% 16777216) %% 256
    ))
  }
  # CRC-32 of the UNCOMPRESSED data, and its length modulo 2^32
  hdr <- as.raw(c(
    0x1f,
    0x8b,
    0x08,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00, # MTIME = 0, for determinism
    0x00,
    0xff
  )) # XFL = 0, OS = unknown
  c(hdr, deflate, le32(ccrc32(bytes)), le32(n))
}

#' @rdname jsgz
#' @export
jsgzdec <- function(txt, raw = FALSE, ...) {
  .rmbl_no_fn(txt = txt)
  # The input's own type settles how to read it: raw is already the gzip
  # member, character is base64 around one. Trusting the flag instead
  # meant that handing back what jsgzenc(raw = TRUE) returned,
  # without repeating the flag, ran the bytes through as.character() and
  # a base64 decode and failed inside the inflater rather than here.
  bytes <- if (is.raw(txt)) {
    txt
  } else {
    if (isTRUE(raw)) {
      stop("`txt` must be a raw vector when `raw = TRUE`", call. = FALSE)
    }
    jsb64dec(as.character(txt)[1L])
  }
  # A gzip member is at least 18 bytes (10 of header, 8 of trailer) and
  # starts 1f 8b; R's own memDecompress() would return garbage on a short
  # zlib-framed input and, in R 4.6, dumps core on an empty one.
  if (
    length(bytes) < 18L ||
      bytes[1L] != as.raw(0x1f) ||
      bytes[2L] != as.raw(0x8b)
  ) {
    stop(
      "`txt` does not hold a gzip member: expected at least 18 bytes ",
      "starting 1f 8b, got ",
      length(bytes),
      " byte(s).",
      call. = FALSE
    )
  }
  # The trailer's ISIZE (uncompressed length mod 2^32) is a free pre-check
  # against a decompression bomb from an untrusted field (gzip reaches
  # ~1000:1); zlib itself verifies the trailer while inflating.
  nb <- length(bytes)
  isize <- sum(as.numeric(as.integer(bytes[(nb - 3L):nb])) * 256^(0:3))
  if (isize > 64 * 1024^2) {
    stop(
      sprintf(
        paste0(
          "`txt` declares %.0f uncompressed bytes (gzip ISIZE); ",
          "refusing to inflate more than 64 MiB"
        ),
        isize
      ),
      call. = FALSE
    )
  }
  json <- rawToChar(memDecompress(bytes, type = "gzip"))
  fromjs(json, ...)
}
