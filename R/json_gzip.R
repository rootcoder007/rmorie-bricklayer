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
  bytes <- memCompress(charToRaw(as.character(txt)), type = "gzip")
  if (isTRUE(raw)) return(bytes)
  bricklayer_json_base64_enc(bytes)
}

#' @rdname rmbl_json_gzip
#' @export
json_gzip_decode <- function(txt, raw = FALSE, ...) {
  bytes <- if (isTRUE(raw)) {
    if (!is.raw(txt)) stop("`txt` must be a raw vector when `raw = TRUE`",
                           call. = FALSE)
    txt
  } else {
    bricklayer_json_base64_dec(as.character(txt)[1L])
  }
  json <- rawToChar(memDecompress(bytes, type = "gzip"))
  bricklayer_json_from_json(json, ...)
}
