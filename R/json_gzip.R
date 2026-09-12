# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Compressed JSON. A capsule manifest that embeds a data sample, or a
# provenance record carrying a schema for a wide table, is mostly
# repeated key names -- exactly what gzip removes. Base64 then makes the
# result safe to put inside another JSON document or an HTTP header.

#' Compressed, base64-encoded JSON
#'
#' `json_gzip_encode()` serialises to JSON, compresses with gzip and
#' encodes the result as base64, so it can be embedded in another JSON
#' document, a header, or a text column. `json_gzip_decode()` reverses
#' all three steps.
#'
#' JSON is highly compressible because every record repeats the key
#' names, so this is usually a large saving on anything record-shaped --
#' but it is opaque. Use it for payloads that travel, and plain
#' [bricklayer_json_to_json()] for anything a person is meant to read or
#' a `git diff` is meant to show.
#'
#' `raw = TRUE` skips the base64 step and returns the gzip bytes, which
#' is what to use when writing to a file rather than embedding in text.
#'
#' @param x Object to encode.
#' @param txt Base64 string (or raw vector) from `json_gzip_encode()`.
#' @param raw Return (or accept) gzip bytes instead of base64.
#' @param ... Passed to [bricklayer_json_to_json()].
#' @return `json_gzip_encode()` a length-1 character vector, or a raw
#'   vector when `raw = TRUE`. `json_gzip_decode()` the decoded object.
#' @seealso [bricklayer_json_to_json()],
#'   [bricklayer_json_serialize()] for a lossless but uncompressed form.
#' @examples
#' x <- list(rows = data.frame(id = 1:50, value = stats::runif(50)))
#'
#' enc <- json_gzip_encode(x)
#' substring(enc, 1, 40)
#'
#' # Smaller than the JSON it came from, because the keys repeat.
#' c(json = nchar(bricklayer_json_to_json(x)), gzip_b64 = nchar(enc))
#'
#' # Round trips.
#' identical(json_gzip_decode(enc)$rows$id, 1:50)
#'
#' # Raw gzip bytes, for writing to a file.
#' bytes <- json_gzip_encode(x, raw = TRUE)
#' class(bytes)
#' identical(json_gzip_decode(bytes, raw = TRUE)$rows$id, 1:50)
#' @name rmbl_json_gzip
#' @export
json_gzip_encode <- function(x, raw = FALSE, ...) {
  txt <- bricklayer_json_to_json(x, ...)
  bytes <- .rmbl_gzip_member(charToRaw(as.character(txt)))
  if (isTRUE(raw)) return(bytes)
  bricklayer_json_base64_enc(bytes)
}

# Wrap a deflate stream in a real gzip member (RFC 1952).
#
# memCompress(type = "gzip") does NOT produce gzip: it produces a zlib
# stream (RFC 1950), whose header is 0x78 0x9c rather than gzip's 0x1f
# 0x8b. R's own memDecompress reads both, so a round trip through this
# package looked correct while no external tool -- gzip, zcat, a browser
# decoding Content-Encoding: gzip -- could read the bytes at all.
#
# The two formats share the same deflate payload and differ only in the
# wrapper, so the zlib header (2 bytes) and its Adler-32 trailer (4
# bytes) come off and the gzip header and trailer go on. MTIME is left
# at zero so the same input always gives the same bytes: a capsule's
# digest must not depend on the clock.
.rmbl_gzip_member <- function(bytes) {
  z <- memCompress(bytes, type = "gzip")
  if (length(z) < 6L) stop("compression produced no stream", call. = FALSE)
  # a zlib stream begins with CMF/FLG, where CMF's low nibble is 8
  # (deflate); anything else is not the wrapper assumed here
  if (bitwAnd(as.integer(z[1L]), 0x0f) != 8L) {
    stop("unexpected compressed-stream header", call. = FALSE)
  }
  deflate <- z[3L:(length(z) - 4L)]
  n <- length(bytes)
  # Arithmetic, not bit operations: a CRC-32 runs up to 2^32 - 1 and R's
  # bitwAnd is signed 32-bit, so it returns NA for anything above
  # 2^31 - 1 -- which silently wrote a zero trailer for half of all
  # inputs.
  le32 <- function(v) {
    v <- as.numeric(v) %% 4294967296
    as.raw(c(v %% 256, (v %/% 256) %% 256,
             (v %/% 65536) %% 256, (v %/% 16777216) %% 256))
  }
  # CRC-32 of the UNCOMPRESSED data, and its length modulo 2^32
  hdr <- as.raw(c(0x1f, 0x8b, 0x08, 0x00,
                  0x00, 0x00, 0x00, 0x00,   # MTIME = 0, for determinism
                  0x00, 0xff))              # XFL = 0, OS = unknown
  c(hdr, deflate, le32(core_crc32(bytes)), le32(n))
}

#' @rdname rmbl_json_gzip
#' @export
json_gzip_decode <- function(txt, raw = FALSE, ...) {
  # The input's own type settles how to read it: raw is already the gzip
  # member, character is base64 around one. Trusting the flag instead
  # meant that handing back what json_gzip_encode(raw = TRUE) returned,
  # without repeating the flag, ran the bytes through as.character() and
  # a base64 decode and failed inside the inflater rather than here.
  bytes <- if (is.raw(txt)) {
    txt
  } else {
    if (isTRUE(raw)) {
      stop("`txt` must be a raw vector when `raw = TRUE`", call. = FALSE)
    }
    bricklayer_json_base64_dec(as.character(txt)[1L])
  }
  json <- rawToChar(memDecompress(bytes, type = "gzip"))
  bricklayer_json_from_json(json, ...)
}
