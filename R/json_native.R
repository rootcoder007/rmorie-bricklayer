# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Native JSON codec: jsonlite's complete mapping (toJSON/fromJSON with every
# option, prettify/minify/validate, serializeJSON, base64, ndjson streaming),
# pure base R. Ported from the rmorie arm's jsonlt module (same author, same
# licence); a parity test pins it byte-for-byte to jsonlite whenever that
# package is installed. Public surface here: fromjs() and
# tojs(); the rest is internal to the capsule layer.

# jsonlt -- jsonlite's JSON mapping, implemented natively in base R.
#
# This is the complete public surface of jsonlite 2.0.0 (toJSON / fromJSON
# with every option, read_json / write_json / parse_json, prettify / minify /
# validate, flatten, unbox, serializeJSON / unserializeJSON, base64,
# stream_in / stream_out, rbind_pages), written so that the bytes match:
# the encoder reproduces jsonlite's asJSON dispatch and its C helpers
# (num_to_char / modp_dtoa2, escape_chars, collapse_*), the simplifier
# reproduces simplify() / simplifyDataFrame() / null_to_na(), and the text
# tools reproduce yajl's generator. A parity harness runs every option over
# a corpus of R objects against jsonlite itself and asserts identical
# output; the codec exists so nothing in the package needs jsonlite at run
# time.
#
# Reference
#   Ooms, J. (2014) "The jsonlite Package: A Practical and Consistent
#     Mapping Between JSON Data and R Objects." arXiv:1403.2805.
#   Bray, T. (ed.) (2017) "The JavaScript Object Notation (JSON) Data
#     Interchange Format." RFC 8259.
#   jsonlite 2.0.0 sources (R/ and src/), the executable specification.

# ================================================================ numbers

#' Base64 encoding
#'
#' Encodes and decodes base64, in both the standard alphabet and the
#' URL-safe variant. Computed in R with no dependency, so a capsule can
#' embed binary content in a text manifest wherever this package runs.
#'
#' `jsb64enc()` breaks its output into 72-character
#' lines (a newline after each complete block of 54 input bytes), matching
#' jsonlite's encoder byte for byte; the decoder ignores line breaks, other
#' white space and \code{=} padding, so either form round trips. Any other
#' character outside the alphabet is an error rather than being skipped,
#' because skipping it would decode a corrupted body into a shorter
#' valid-looking one.
#'
#' The URL-safe variant substitutes `-` and `_` for `+` and
#' `/` and drops the `=` padding, which is what makes it safe in
#' a URL path, a query string or a filename.
#'
#' Base64 is an ENCODING, not encryption or a digest: it hides nothing and
#' anyone can reverse it. Use [csha256()] to
#' pin content and [chmac()] to
#' authenticate it.
#'
#' Errors: an encoder given anything but a raw vector, a character vector or
#' \code{NULL}; \code{jsb64dec()} given anything but text or
#' raw bytes, or text with a character outside the standard alphabet;
#' \code{jsb64udec()} given anything but character text
#' (raw bytes are refused), \code{NA}, or a character outside the URL-safe
#' alphabet.
#'
#' @param input For the encoders, a raw vector, or a character vector
#' (its elements are joined with newlines and encoded as UTF-8 bytes), or
#' \code{NULL}. For \code{jsb64dec()}, base64 text (a
#' character vector, joined with newlines) or its raw bytes. For
#' \code{jsb64udec()}, URL-safe base64 text, with or
#' without \code{=} padding.
#' @return The encoders return a character scalar (\code{""} for empty input,
#' \code{NA_character_} for \code{NULL}); the decoders return a raw vector
#' (use \code{rawToChar()} for text).
#' @seealso
#' [jsgzenc()], which composes this
#' with gzip.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Round trip through the standard alphabet.
#' b <- jsb64enc("hello capsule")
#' b
#' rawToChar(jsb64dec(b))
#'
#' # Raw input works the same way.
#' jsb64enc(charToRaw("abc"))
#' jsb64dec(jsb64enc(charToRaw("abc")))
#'
#' # Padding appears when the length is not a multiple of three.
#' jsb64enc("a")
#' jsb64enc("ab")
#' jsb64enc("abc")
#'
#' # The URL-safe variant has no "+", "/" or "=" to escape.
#' jsb64uenc(as.raw(c(255, 224, 63)))
#' jsb64enc(as.raw(c(255, 224, 63)))
#' jsb64udec(
#'   jsb64uenc("path/safe?yes")
#' )
#'
#' # Long input is wrapped, and the decoder ignores the breaks.
#' long <- jsb64enc(strrep("x", 200))
#' grepl("\n", long)
#' rawToChar(jsb64dec(long)) == strrep("x", 200)
#'
#' # A character outside the alphabet is refused, not skipped.
#' try(jsb64dec("ab$c"))
#' @name b64
#' @export
jsb64enc <- function(input) {
  if (is.null(input)) {
    return(NA_character_)
  }
  if (is.character(input)) {
    input <- charToRaw(paste(input, collapse = "\n"))
  }
  if (!is.raw(input)) {
    stop("jsb64enc: `input` must be a raw vector or text", call. = FALSE)
  }
  b <- as.integer(input)
  n <- length(b)
  if (!n) {
    return("")
  }
  pad <- (3L - n %% 3L) %% 3L
  b <- c(b, integer(pad))
  m <- matrix(b, nrow = 3L)
  v <- m[1L, ] * 65536L + m[2L, ] * 256L + m[3L, ]
  chars <- rbind(
    .RMBL_JSON_B64[v %/% 262144L %% 64L + 1L],
    .RMBL_JSON_B64[v %/% 4096L %% 64L + 1L],
    .RMBL_JSON_B64[v %/% 64L %% 64L + 1L],
    .RMBL_JSON_B64[v %% 64L + 1L]
  )
  out <- paste(as.vector(chars), collapse = "")
  if (pad) {
    substr(out, nchar(out) - pad + 1L, nchar(out)) <- strrep("=", pad)
  }
  # jsonlite's encoder breaks lines every 72 characters, and the break
  # TERMINATES each complete input block rather than separating two
  # lines. The block is 54 INPUT bytes, which is what 72 output
  # characters encode, and that distinction is visible: 52, 53 and 54
  # bytes all produce 72 characters, but only 54 bytes fills a block and
  # so only 54 bytes gets the newline. Wrapping on the output length
  # instead differs from jsonlite by one byte at those lengths, and a
  # digest comparison reads that as drift.
  if (n >= 54L) {
    starts <- seq(1L, nchar(out), by = 72L)
    pieces <- substring(out, starts, pmin(starts + 71L, nchar(out)))
    full <- seq_along(pieces) * 54L <= n
    out <- paste0(pieces, ifelse(full, "\n", ""), collapse = "")
  }
  out
}

#' @rdname b64
#' @export
jsb64dec <- function(input) {
  # NA was pasted in and decoded as the text "NA"
  if (is.character(input) && anyNA(input)) {
    stop("jsb64dec: `input` must not be NA", call. = FALSE)
  }
  if (is.character(input)) {
    input <- charToRaw(paste(input, collapse = "\n"))
  }
  if (!is.raw(input)) {
    stop("jsb64dec: `input` must be a raw vector or text", call. = FALSE)
  }
  s <- rawToChar(input)
  # whitespace and padding may be dropped; anything else is not base64, and
  # deleting it would decode a corrupt body into a shorter valid-looking one
  if (grepl("[^A-Za-z0-9+/=[:space:]]", s)) {
    stop("base64 input contains characters outside the alphabet", call. = FALSE)
  }
  .rmbl_b64_padding(s)
  ch <- strsplit(gsub("[^A-Za-z0-9+/]", "", s), "", fixed = TRUE)[[1]]
  if (!length(ch)) {
    return(raw(0))
  }
  v <- match(ch, .RMBL_JSON_B64) - 1L
  nfull <- length(v) %/% 4L
  rem <- length(v) %% 4L
  out <- integer(0)
  if (nfull) {
    m <- matrix(v[seq_len(nfull * 4L)], nrow = 4L)
    w <- m[1L, ] * 262144L + m[2L, ] * 4096L + m[3L, ] * 64L + m[4L, ]
    out <- as.vector(rbind(w %/% 65536L, w %/% 256L %% 256L, w %% 256L))
  }
  if (rem == 2L) {
    w <- v[nfull * 4L + 1L] * 262144L + v[nfull * 4L + 2L] * 4096L
    out <- c(out, w %/% 65536L)
  } else if (rem == 3L) {
    w <- v[nfull * 4L + 1L] *
      262144L +
      v[nfull * 4L + 2L] * 4096L +
      v[nfull * 4L + 3L] * 64L
    out <- c(out, w %/% 65536L, w %/% 256L %% 256L)
  }
  as.raw(out)
}

#' @rdname b64
#' @export
jsb64uenc <- function(input) {
  sub("=+$", "", chartr("+/", "-_", jsb64enc(input)))
}

#' @rdname b64
#' @export
jsb64udec <- function(input) {
  input <- .rmbl_text_input(input, "input", allow_raw = FALSE)
  if (!is.character(input) || anyNA(input)) {
    stop("`input` must be base64url text", call. = FALSE)
  }
  if (any(grepl("[^A-Za-z0-9_=-]", gsub("[\r\n]", "", input)))) {
    stop("`input` is not base64url text", call. = FALSE)
  }
  if (!length(input)) {
    return(jsb64dec(input))
  }
  text <- paste(gsub("[\r\n]", "", chartr("-_", "+/", input)), collapse = "")
  mod <- nchar(text) %% 4L
  if (mod > 0L) {
    text <- paste0(text, strrep("=", 4L - mod))
  }
  jsb64dec(text)
}

#' Encode an R object as JSON (jsonlite's toJSON, natively)
#'
#' Converts R data (vectors, lists, data frames, matrices, dates, factors)
#' to JSON text, with the same options, the same defaults and the same bytes
#' out as jsonlite's \code{toJSON()}, but computed by this package's own
#' code, so manifests, provenance records and capsules can be written where
#' jsonlite is not installed and their digests stay the same either way. Use
#' it to write data for an API or a person; use
#' [jsser()]
#' when the JSON must rebuild the exact R object (classes, factor levels,
#' attributes).
#'
#' @details
#' Atomic vectors become arrays, so a single value is \code{[1]} unless
#' \code{auto_unbox = TRUE}. Named lists become objects and unnamed lists
#' arrays. Missing values follow jsonlite: with \code{na} not given, a
#' missing number is written as the string \code{"NA"} and a missing string
#' or logical as \code{null}; in a data frame by rows a missing value is
#' left out of its record.
#'
#' Further options of \code{toJSON()} are taken through \code{...}:
#' \code{rownames}, \code{keep_vec_names}, \code{json_verbatim},
#' \code{always_decimal}, \code{time_format}, \code{UTC}, \code{no_dots},
#' \code{hms} (\code{"string"} or \code{"secs"}), and two of this package's
#' own: \code{keep_empty_names} (an empty-string key is written as
#' \code{""} rather than replaced by its position) and
#' \code{quiet_vec_names} (no message when \code{keep_vec_names} is used).
#' [mnfcanon()] uses both.
#'
#' Errors: an option value not among its choices (the message lists them);
#' an object with no JSON form (a function, a symbol) unless
#' \code{force = TRUE}.
#'
#' @param x The object to encode.
#' @param dataframe How a data frame is written: \code{"rows"} (the default,
#'   an array of records), \code{"columns"} (an object of column arrays) or
#'   \code{"values"} (an array of row arrays, without names).
#' @param matrix How a matrix is written. \code{"rowmajor"} (the default) gives
#'   an array of rows, and \code{"columnmajor"} an array of columns.
#' @param Date How a \code{Date} is written: \code{"ISO8601"} (the default,
#'   \code{"2024-01-02"}) or \code{"epoch"} (days since 1970-01-01).
#' @param POSIXt How a date-time is written: \code{"string"} (the default,
#'   \code{"2024-01-02 03:04:05"}), \code{"ISO8601"}
#'   (\code{"2024-01-02T03:04:05"}), \code{"epoch"} (milliseconds since
#'   1970) or \code{"mongo"} (\code{{"$date": ms}}).
#' @param factor How a factor is written: \code{"string"} (the default, its
#'   labels) or \code{"integer"} (its codes).
#' @param complex How a complex number is written: \code{"string"} (the
#'   default, \code{"1+2i"}) or \code{"list"} (an object of \code{real} and
#'   \code{imaginary} arrays).
#' @param raw How a raw vector is written: \code{"base64"} (the default, one
#'   string), \code{"hex"}, \code{"mongo"}, \code{"int"} or \code{"js"}.
#' @param null How \code{NULL} inside a list is written: \code{"list"} (the
#'   default, \code{{}}; a round trip gives an empty list) or \code{"null"}
#'   (a JSON \code{null}).
#'   [jsser()] round-trips
#'   \code{NULL} exactly.
#' @param na How missing values are written: \code{"null"} or
#'   \code{"string"} (\code{"NA"}). When \code{NULL} (the default), the
#'   per-type default of jsonlite applies (see Details).
#' @param auto_unbox Logical scalar, default \code{FALSE}: write length-one
#'   vectors as scalars (\code{1}) rather than arrays (\code{[1]}).
#' @param digits Numeric scalar, default \code{4}: decimal places kept for
#'   doubles. \code{I(n)} means \code{n} significant digits (\code{I(17)}
#'   writes every double exactly) and \code{NA} means 15 significant digits.
#' @param pretty \code{FALSE} (the default) for compact output, \code{TRUE}
#'   to indent by two spaces, or a number of spaces.
#' @param force Logical scalar, default \code{FALSE}: write objects that have
#'   no JSON form (as \code{{}}) instead of failing.
#' @param ... Further options of jsonlite's \code{toJSON()} and of this
#'   package (see Details).
#' @return A character scalar of class \code{json}, the JSON text.
#' @seealso [fromjs()] for the
#'   reverse,
#'   [jsser()] for an exact
#'   round trip.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' tojs(list(a = 1:3, b = "x"), auto_unbox = TRUE)
#' tojs(data.frame(id = 1:2, v = c(1.5, NA)), pretty = TRUE)
#'
#' # a data frame by columns, and a date-time in ISO 8601
#' df <- data.frame(id = 1:2, v = c(1.5, NA))
#' tojs(df, dataframe = "columns", na = "null")
#' tojs(as.POSIXct("2024-01-02 03:04:05", tz = "UTC"), POSIXt = "ISO8601")
#'
#' # digits: decimal places by default, significant digits with I()
#' tojs(pi)
#' tojs(pi, digits = I(17))
#'
#' # a choice that does not exist is refused
#' try(tojs(df, dataframe = "table"))
#' @export
#' @srrstats {G2.12} List columns are encoded element-wise;
#'   test-review-coverage.R:95 tojs(data.frame(a = I(list(1:2, 3)))).
tojs <- function(
  x,
  dataframe = c("rows", "columns", "values"),
  matrix = c("rowmajor", "columnmajor"),
  Date = c("ISO8601", "epoch"),
  POSIXt = c("string", "ISO8601", "epoch", "mongo"),
  factor = c("string", "integer"),
  complex = c("string", "list"),
  raw = c("base64", "hex", "mongo", "int", "js"),
  null = c("list", "null"),
  na = NULL,
  auto_unbox = FALSE,
  digits = 4,
  pretty = FALSE,
  force = FALSE,
  ...
) {
  .rmbl_json_check_digits(digits)
  dots <- list(...)
  o <- list(
    dataframe = .rmbl_arg(dataframe),
    matrix = .rmbl_arg(matrix),
    Date = .rmbl_arg(Date),
    POSIXt = .rmbl_arg(POSIXt),
    factor = .rmbl_arg(factor),
    complex = .rmbl_arg(complex),
    raw = .rmbl_arg(raw),
    null = .rmbl_arg(null),
    auto_unbox = isTRUE(auto_unbox),
    digits = digits,
    use_signif = .rmbl_json_use_signif(dots$use_signif, digits),
    force = isTRUE(force),
    indent = .rmbl_json_indent_init(pretty),
    rownames = dots$rownames,
    keep_vec_names = isTRUE(dots$keep_vec_names),
    json_verbatim = isTRUE(dots$json_verbatim),
    always_decimal = isTRUE(dots$always_decimal),
    time_format = dots$time_format,
    UTC = isTRUE(dots$UTC),
    no_dots = isTRUE(dots$no_dots),
    hms = if (is.null(dots$hms)) {
      "string"
    } else {
      .rmbl_arg(dots$hms, c("string", "secs"))
    },
    keep_empty_names = isTRUE(dots$keep_empty_names),
    quiet_vec_names = isTRUE(dots$quiet_vec_names),
    depth = 0L
  )
  if (!is.null(na)) {
    na <- .rmbl_arg(na, c("null", "string"))
  }
  ans <- .rmbl_json_as(
    x,
    o,
    na = na,
    oldna = NULL,
    auto_unbox = o$auto_unbox,
    indent = o$indent
  )
  class(ans) <- "json"
  ans
}

#' Parse JSON into R objects (jsonlite's fromJSON, natively)
#'
#' Reads JSON text, a JSON file or a JSON address on the web into R objects,
#' with the same simplification rules as jsonlite's \code{fromJSON()}: an
#' array of numbers becomes a numeric vector, an array of records a data
#' frame, an array of equal-length arrays a matrix. The parser is this
#' package's own, so it works without jsonlite, and it is stricter in two
#' places that matter for provenance records: a repeated key is an error by
#' default, and a whole number too large for a double is flagged.
#'
#' @details
#' A single string shorter than 2,084 bytes that is not valid JSON is taken
#' as a location: an \code{http(s)} address is fetched (a public \code{https}
#' host only, redirects re-checked, 60 second timeout, body capped at 16
#' MiB), otherwise an existing file is read. Anything else is parsed as JSON
#' text; a character vector is joined with newlines. A connection is read to
#' its end (and closed when this call opened it).
#'
#' Without simplification (\code{simplifyVector = FALSE}) objects become named
#' lists, arrays unnamed lists, \code{null} \code{NULL}, and numbers integer
#' or double. Whole numbers beyond \eqn{2^{53}} cannot be held exactly in a
#' double: they are read as doubles with a warning, or kept as text with
#' \code{bigint_as_char = TRUE}.
#'
#' Errors: \code{txt} not character or a connection; invalid JSON (the message
#' gives the character offset); a repeated key under
#' \code{duplicate_keys = "error"}; an address that is not a public
#' \code{https} host, that cannot be reached or that answers with an HTTP
#' error.
#'
#' @param txt JSON text (a character vector, joined with newlines), a file
#' path, an \code{http(s)} URL, or a connection. A URL goes through
#' the same check and the same transport as every other fetch in the
#' package (public https host, redirects re-checked, body capped).
#' @param simplifyVector Logical scalar, default \code{TRUE}: turn arrays of
#' scalars into atomic vectors.
#' @param simplifyDataFrame Logical scalar, default \code{simplifyVector}: turn
#' arrays of records into data frames.
#' @param simplifyMatrix Logical scalar, default \code{simplifyVector}: turn
#' arrays of equal-length arrays into matrices.
#' @param flatten Logical scalar, default \code{FALSE}. \code{TRUE} expands
#' nested data frame columns into columns named \code{outer.inner}.
#' @param duplicate_keys What to do with an object that repeats a key:
#' \code{"error"} (default) refuses the document, \code{"keep"} returns both
#' values under the repeated name, as jsonlite does.
#' @param bigint_warn Logical scalar, default \code{TRUE}: warn (once per
#'   document) when a whole number beyond 2^53 is read into a double; the
#'   package's own readers of API payloads turn this off, since long numeric
#'   identifiers are routine there.
#' @param bigint_as_char Logical scalar, default \code{FALSE}: integers beyond
#' 2^53 come back as strings.
#' @param simplify Legacy, default \code{NULL}: \code{FALSE} turns every
#' simplification off.
#' @param ... Ignored, for call compatibility with jsonlite.
#' @return An R object: a list, an atomic vector, a data frame, a matrix or
#' \code{NULL}, depending on the JSON and the simplification options.
#' @seealso [tojs()] for the
#'   reverse.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' fromjs('[{"a":1,"b":"x"},{"a":2,"b":"y"}]')
#' fromjs('[[1,2],[3,4]]')
#'
#' # no simplification: nested lists exactly as in the document
#' str(fromjs('{"a": [1, 2], "b": {"c": null}}', simplifyVector = FALSE))
#'
#' # from a file
#' f <- tempfile(fileext = ".json")
#' writeLines('[{"a":1},{"a":2,"b":"x"}]', f)
#' fromjs(f)
#'
#' # a large identifier kept exactly, as text
#' fromjs('[12345678901234567890]', bigint_as_char = TRUE)
#'
#' # a repeated key is refused unless asked for
#' try(fromjs('{"a": 1, "a": 2}'))
#' fromjs('{"a": 1, "a": 2}', duplicate_keys = "keep")
#' @export
fromjs <- function(
  txt,
  simplifyVector = TRUE,
  simplifyDataFrame = simplifyVector,
  simplifyMatrix = simplifyVector,
  flatten = FALSE,
  bigint_as_char = FALSE,
  simplify = NULL,
  duplicate_keys = c("error", "keep"),
  bigint_warn = TRUE,
  ...
) {
  if (identical(simplify, FALSE)) {
    simplifyVector <- simplifyDataFrame <- simplifyMatrix <- FALSE
  }
  # flags: simplifyVector = "yes" turned simplification off without a word
  .rmbl_flag1(simplifyVector, "simplifyVector")
  .rmbl_flag1(simplifyDataFrame, "simplifyDataFrame")
  .rmbl_flag1(simplifyMatrix, "simplifyMatrix")
  txt <- .rmbl_json_read_input(txt)
  obj <- .rmbl_json_parse(
    txt,
    bigint_as_char,
    bigint_warn,
    duplicate_keys = .rmbl_arg(duplicate_keys)
  )
  if (
    any(
      isTRUE(simplifyVector),
      isTRUE(simplifyDataFrame),
      isTRUE(simplifyMatrix)
    )
  ) {
    return(.rmbl_json_simplify(
      obj,
      simplifyVector = simplifyVector,
      simplifyDataFrame = simplifyDataFrame,
      simplifyMatrix = simplifyMatrix,
      flatten = flatten
    ))
  }
  obj
}

#' JSON serialisation of an R object, type and attributes included
#'
#' Writes an R object to JSON with its type and attributes alongside the
#' value, so the round trip returns THE SAME OBJECT rather than something
#' that merely prints the same. The counterpart of jsonlite's
#' `serializeJSON()` / `unserializeJSON()`, computed by this
#' package's own codec with no jsonlite dependency.
#'
#' Use this, not
#' [tojs()],
#' whenever the JSON has to reconstruct the object faithfully.
#' `tojs()` writes the DATA -- which is what an API
#' or a human wants, and which loses factor levels, matrix dimensions,
#' classes and every other attribute. These two keep them, at the cost of
#' JSON no other tool will understand.
#'
#' @param x Object to serialise.
#' @param digits Decimal digits retained for doubles (default
#' 8, the jsonlite default, so `1/3` is written as `0.33333333`).
#' `digits = I(17)` writes every double exactly (17 significant digits),
#' which makes the round trip `identical()` for doubles too; `NA`
#' means 15 significant digits, as in jsonlite, and is not exact.
#' A complex value with only one `NA` part comes back as `NA`, as it
#' does in jsonlite.
#' @param pretty Logical scalar, default \code{FALSE}: indent the output.
#' @param txt Character scalar: JSON produced by
#' `jsser()`.
#' @param trusted `FALSE` (default) rebuilds data types only (vectors,
#' lists, factors, matrices, data frames, environments, symbols) and
#' refuses functions, calls, expressions, namespaces and S4 objects:
#' rebuilding those runs code the JSON's author chose, through
#' `unserialize()`, `parse()`, `getNamespace()` or an `initialize`
#' method. Set `TRUE` only for JSON your own session produced.
#' @return `jsser()` returns a length-1 character
#' vector of class `json`; `jsunser()`
#' returns the original object.
#' @seealso
#' [tojs()] for
#' plain data JSON, [csha256()] for
#' fingerprinting the result.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # A factor survives the round trip with its levels intact.
#' f <- factor(c("b", "a", "b"), levels = c("a", "b", "c"))
#' back <- jsunser(jsser(f))
#' identical(back, f)
#'
#' # So does a matrix, with its dimensions.
#' m <- matrix(1:6, nrow = 2)
#' identical(jsunser(jsser(m)), m)
#'
#' # Plain data JSON does not keep either, which is the trade-off.
#' tojs(f)
#'
#' # Nested lists, names and NULLs round trip too.
#' x <- list(a = 1:3, b = list(c = "x", d = NULL), e = TRUE)
#' identical(jsunser(jsser(x)), x)
#'
#' # Doubles are rounded to `digits`; I(17) keeps them exact.
#' jsser(1/3)
#' exact <- jsser(1/3, digits = I(17))
#' identical(jsunser(exact), 1/3)
#'
#' # The serialised form is JSON, so it can be pinned like any other text.
#' nchar(csha256(jsser(m)))
#'
#' # A function is refused unless the JSON is trusted.
#' try(jsunser(jsser(function(x) x + 1)))
#' @name jsserdoc
#' @export
jsser <- function(x, digits = 8, pretty = FALSE) {
  .rmbl_flag1(pretty, "pretty")
  tojs(.rmbl_json_pack(x), digits = digits, pretty = pretty)
}

#' @rdname jsserdoc
#' @export
jsunser <- function(txt, trusted = FALSE) {
  if (!is.character(txt) || length(txt) != 1L || is.na(txt)) {
    stop("`txt` must be one string of JSON from jsser()", call. = FALSE)
  }
  obj <- .rmbl_json_parse(txt)
  if (!is.list(obj) || is.null(names(obj))) {
    stop(
      "`txt` is not JSON written by jsser() (an object with a type)",
      call. = FALSE
    )
  }
  .rmbl_json_unpack(obj, trusted = .rmbl_flag1(trusted, "trusted"))
}

#' Format doubles and integers the way jsonlite's num_to_char() does
#'
#' `digits` is decimal places (jsonlite default 4), `I(n)` means n significant
#' digits, `NA` means 15 significant digits. Non-finite values become
#' \code{"NA"}/\code{"NaN"}/\code{"Inf"}/\code{"-Inf"} strings, null, or
#' NA_character_ (dropped later) depending on `na_as_string`.
#' @param x A double or integer vector.
#' @param digits Decimal places, `I(n)` for n significant digits, NA for 15
#'   significant digits, NULL for full precision.
#' @param na_as_string TRUE to write non-finite values as strings, FALSE to
#'   write them as null, NA to leave them missing.
#' @param use_signif Whether `digits` counts significant digits.
#' @param always_decimal Whether a whole number is written with \code{".0"}.
#' @return A character vector, one element per value.
#' @noRd
.rmbl_json_num_to_char <- function(
  x,
  digits = 4,
  na_as_string = NA,
  use_signif = FALSE,
  always_decimal = FALSE
) {
  if (is.integer(x)) {
    return(.rmbl_json_int_to_char(x, na_as_string))
  }
  n <- length(x)
  out <- character(n)
  # digits = NULL is this codec's own extension: full precision (%.17g), the
  # setting the package's internal JSON round trips rely on
  if (is.null(digits)) {
    digits <- 17L
    use_signif <- TRUE
  }
  precision <- if (is.na(digits)) NA_integer_ else as.integer(digits)
  sig_digits <- if (isTRUE(use_signif) && !is.na(precision)) {
    ceiling(min(17, precision))
  } else {
    0L
  }
  # Seventeen significant digits is the round-trip setting, and its
  # digits come from this package rather than from the platform. One
  # call for the whole vector; the loop below only picks entries out.
  full17 <- if (isTRUE(use_signif) && !is.na(precision) && sig_digits == 17L) {
    .rmbl_dtoa17(x)
  } else {
    NULL
  }
  for (i in seq_len(n)) {
    val <- x[i]
    if (!is.finite(val)) {
      out[i] <- .rmbl_json_nonfinite(val, na_as_string)
      next
    }
    buf <- if (!is.null(full17)) {
      full17[i]
    } else {
      .rmbl_json_num1(val, precision, use_signif, sig_digits)
    }
    if (isTRUE(always_decimal) && grepl("^[0-9-]+$", buf)) {
      buf <- paste0(buf, ".0")
    }
    out[i] <- buf
  }
  out
}

#' Format an integer vector the way jsonlite's num_to_char() does
#'
#' @param x An integer vector.
#' @param na_as_string TRUE for \code{"NA"} strings, FALSE for null, NA to
#'   leave them missing.
#' @return A character vector, one element per value.
#' @noRd
.rmbl_json_int_to_char <- function(x, na_as_string) {
  out <- character(length(x))
  ok <- !is.na(x)
  out[ok] <- as.character(x[ok])
  out[!ok] <- if (is.na(na_as_string)) {
    NA_character_
  } else if (na_as_string) {
    "\"NA\""
  } else {
    "null"
  }
  out
}

#' A number that is not finite, as JSON: NA, null, or the string
#' "NA"/"NaN"/"Inf"/"-Inf".
#' @param val The number.
#' @param na_as_string NA (an R NA), TRUE (a string) or FALSE (null).
#' @return The text.
#' @noRd
.rmbl_json_nonfinite <- function(val, na_as_string) {
  if (is.na(na_as_string)) {
    return(NA_character_)
  }
  if (!na_as_string) {
    return("null")
  }
  if (is.na(val) && !is.nan(val)) {
    return("\"NA\"")
  }
  if (is.nan(val)) {
    return("\"NaN\"")
  }
  if (val > 0) "\"Inf\"" else "\"-Inf\""
}

#' One finite number as JSON text, at the precision asked for.
#' @param val The number.
#' @param precision The digits (NA: 15 significant).
#' @param use_signif Whether the digits are significant ones.
#' @param sig_digits The significant digits.
#' @return The text.
#' @noRd
.rmbl_json_num1 <- function(val, precision, use_signif, sig_digits) {
  if (is.na(precision)) {
    return(sprintf("%.15g", val))
  }
  if (isTRUE(use_signif)) {
    return(sprintf("%.*g", as.integer(sig_digits), val))
  }
  if (
    precision > -1L &&
      precision < 10L &&
      abs(val) < 2147483647 &&
      abs(val) > 1e-5
  ) {
    return(.rmbl_json_dtoa2(val, precision))
  }
  decimals <- ceiling(min(17, max(1, log10(abs(val))) + precision))
  sprintf("%.*g", as.integer(decimals), val)
}

#' Formats a number with fixed decimal digits as jsonlite's modp_dtoa2() does.
#'
#' modp_dtoa2(): fixed decimal digits, trailing zeros removed, with its own
#' rounding rule (round half to odd-frac / half-up on rollover). Reproduced
#' step by step so the last digit matches jsonlite's.
#' @param value The number.
#' @param prec The number of decimal places, from 0 to 9.
#' @return One string.
#' @noRd
.rmbl_json_dtoa2 <- function(value, prec) {
  prec <- max(0L, min(9L, as.integer(prec)))
  p10 <- 10^prec
  neg <- value < 0
  if (neg) {
    value <- -value
  }
  whole <- trunc(value)
  tmp <- (value - whole) * p10
  frac <- trunc(tmp)
  diff <- tmp - frac
  # rounded half to even: above a half up, a half up when the last kept digit
  # (of the fraction, or of the whole part with no decimals) is odd
  up <- diff > 0.5 ||
    (diff == 0.5 && prec > 0L && (frac %% 2 == 1)) ||
    (diff == 0.5 && prec == 0L && (whole %% 2 == 1))
  if (up) {
    frac <- frac + 1
    if (frac >= p10) {
      frac <- 0
      whole <- whole + 1
    }
  }
  if (value > 2147483647) {
    return(sprintf("%e", if (neg) -value else value))
  }
  digs <- .rmbl_json_frac_digits(frac, prec)
  s <- sprintf("%.0f", whole)
  if (length(digs)) {
    s <- paste0(s, ".", paste(digs, collapse = ""))
  }
  if (neg) {
    s <- paste0("-", s)
  }
  s
}

#' The digits of a rounded fraction, trailing zeros dropped.
#' @param frac The fraction, as a whole number of 10^-prec.
#' @param prec The decimals.
#' @return The digits, most significant first.
#' @noRd
.rmbl_json_frac_digits <- function(frac, prec) {
  count <- prec
  if (prec > 0L) {
    while (count > 0L && (frac %% 10 == 0)) {
      count <- count - 1L
      frac <- frac %/% 10
    }
  }
  digs <- character(0)
  while (count > 0L) {
    count <- count - 1L
    digs <- c(as.character(frac %% 10), digs)
    frac <- frac %/% 10
  }
  digs
}

# ================================================================ strings

#' Converts strings to UTF-8 without depending on the session locale.
#'
#' A string of unknown encoding whose bytes are valid UTF-8 is marked as
#' UTF-8; everything else goes through enc2utf8(). enc2utf8() alone treats
#' unknown text as the native encoding, and in a C locale that rewrote every
#' non-ASCII letter as "<e9>"-style escapes, so a bundle note read or written
#' in C did not match the digest it was signed under.
#' @param x A character vector.
#' @return \code{x} in UTF-8.
#' @noRd
.rmbl_as_utf8 <- function(x) {
  unk <- Encoding(x) == "unknown" & !is.na(x) & validUTF8(x)
  if (any(unk)) {
    Encoding(x)[unk] <- "UTF-8"
  }
  if (any(!unk)) {
    x[!unk] <- enc2utf8(x[!unk])
  }
  x
}

#' Escape a character vector as JSON string literals (jsonlite's
#' C_escape_chars)
#' @param x The strings to escape for JSON.
#' @return The escaped strings, each in double quotes.
#' @noRd
.rmbl_json_esc <- function(x) {
  if (!length(x)) {
    return(character(0))
  }
  x <- .rmbl_as_utf8(x)
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  x <- gsub("\n", "\\n", x, fixed = TRUE)
  x <- gsub("\r", "\\r", x, fixed = TRUE)
  x <- gsub("\t", "\\t", x, fixed = TRUE)
  x <- gsub("\b", "\\b", x, fixed = TRUE)
  x <- gsub("\f", "\\f", x, fixed = TRUE)
  x <- gsub("</", "<\\/", x, fixed = TRUE)
  for (cc in c(1:7, 11L, 14:31)) {
    ch <- rawToChar(as.raw(cc))
    hit <- grepl(ch, x, fixed = TRUE, useBytes = TRUE)
    if (any(hit)) {
      x[hit] <- gsub(
        ch,
        sprintf("\\u%04x", cc),
        x[hit],
        fixed = TRUE,
        useBytes = TRUE
      )
    }
  }
  paste0("\"", x, "\"")
}

# ================================================================ base64

.RMBL_JSON_B64 <- strsplit(
  paste0(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    "abcdefghijklmnopqrstuvwxyz",
    "0123456789+/"
  ),
  "",
  fixed = TRUE
)[[1]]


# ================================================================ collapse

# jsonlite's C collapse helpers. `indent` is NA for compact output, else an
# integer with attribute indent_spaces (negative = tabs).
#' Turns the `pretty` argument into the indent the collapse helpers take.
#' @param pretty FALSE, TRUE (two spaces) or a number of spaces.
#' @return NA for compact output, else 0 with attribute `indent_spaces`.
#' @noRd
.rmbl_json_indent_init <- function(pretty) {
  if (isTRUE(pretty)) {
    pretty <- 2L
  }
  # "yes" or NA wrote compact output without a word
  if (!is.numeric(pretty) && !identical(pretty, FALSE)) {
    pretty <- NA_real_
  }
  if (is.numeric(pretty)) {
    if (length(pretty) != 1L || is.na(pretty) || abs(pretty) >= 20) {
      stop(
        "`pretty` must be TRUE, FALSE or one number of spaces below 20",
        call. = FALSE
      )
    }
    structure(0L, indent_spaces = as.integer(pretty))
  } else {
    NA_integer_
  }
}
#' Moves an indent one level deeper.
#' @param indent The indent from `.rmbl_json_indent_init()`.
#' @return The deeper indent, or NA for compact output.
#' @noRd
.rmbl_json_indent_inc <- function(indent) {
  sp <- attr(indent, "indent_spaces")
  if (length(sp)) {
    structure(indent + abs(sp), indent_spaces = sp)
  } else {
    NA_integer_
  }
}
#' Makes the white space of an indent.
#' @param n The number of spaces (or tabs).
#' @param indent The indent, whose sign says spaces or tabs.
#' @return One string.
#' @noRd
.rmbl_json_ws <- function(n, indent) {
  sp <- attr(indent, "indent_spaces")
  strrep(if (length(sp) && sp < 0) "\t" else " ", n)
}
#' Joins encoded values into a JSON array.
#' @param x The encoded values.
#' @param inner Whether the array holds scalars and stays on one line.
#' @param indent The indent, NA for compact output.
#' @return One string.
#' @noRd
.rmbl_json_collapse <- function(x, inner = TRUE, indent = NA_integer_) {
  if (is.na(indent)) {
    return(paste0("[", paste(x, collapse = ","), "]"))
  }
  if (isTRUE(inner)) {
    return(paste0("[", toString(x), "]"))
  }
  if (!length(x)) {
    return("[]")
  }
  ni <- as.integer(indent)
  sp <- abs(attr(indent, "indent_spaces"))
  paste0(
    "[\n",
    paste0(.rmbl_json_ws(ni + sp, indent), x, collapse = ",\n"),
    "\n",
    .rmbl_json_ws(ni, indent),
    "]"
  )
}
#' Joins encoded keys and values into a JSON object, leaving out missing values.
#' @param keys The encoded keys.
#' @param vals The encoded values.
#' @param indent The indent, NA for compact output.
#' @return One string.
#' @noRd
.rmbl_json_collapse_object <- function(keys, vals, indent = NA_integer_) {
  keep <- !is.na(vals)
  keys <- keys[keep]
  vals <- vals[keep]
  if (!length(vals)) {
    return("{}")
  }
  if (is.na(indent)) {
    return(paste0("{", paste0(keys, ":", vals, collapse = ","), "}"))
  }
  ni <- as.integer(indent)
  sp <- abs(attr(indent, "indent_spaces"))
  paste0(
    "{\n",
    paste0(.rmbl_json_ws(ni + sp, indent), keys, ": ", vals, collapse = ",\n"),
    "\n",
    .rmbl_json_ws(ni, indent),
    "}"
  )
}
#' Collapses each row of a matrix of encoded values into a JSON array.
#' @param m The matrix.
#' @param indent The indent, NA for compact output.
#' @return A character vector, one array per row.
#' @noRd
.rmbl_json_row_collapse <- function(m, indent = NA_integer_) {
  vapply(
    seq_len(nrow(m)),
    function(i) .rmbl_json_collapse(m[i, ], inner = TRUE, indent = indent),
    character(1)
  )
}
#' Collapses each row of a matrix of encoded values into a JSON object.
#' @param keys The encoded keys, one per column.
#' @param m The matrix.
#' @param indent The indent, NA for compact output.
#' @return A character vector, one object per row.
#' @noRd
.rmbl_json_row_collapse_object <- function(keys, m, indent = NA_integer_) {
  vapply(
    seq_len(nrow(m)),
    function(i) .rmbl_json_collapse_object(keys, m[i, ], indent),
    character(1)
  )
}
#' Makes names usable as JSON keys: an empty one becomes its position,
#' duplicates are made unique.
#' @param nms The names.
#' @param no_dots Whether dots are replaced by underscores.
#' @return The cleaned names.
#' @noRd
.rmbl_json_cleannames <- function(nms, no_dots = FALSE) {
  nms[nms == ""] <- NA_character_
  miss <- is.na(nms)
  nms[miss] <- as.character(seq_along(nms))[miss]
  if (isTRUE(no_dots)) {
    nms <- gsub(".", "_", nms, fixed = TRUE)
  }
  make.unique(nms)
}

# ================================================================ encoder

#' Encodes an R object as JSON text.
#'
#' The encoder is jsonlite's asJSON generic, one branch per class, with the
#' same argument threading (na / oldna / collapse / auto_unbox / indent).
#' @param x The R object to encode as JSON.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether a vector is collapsed into one array.
#' @param na How missing values are written, or NULL for the type's default.
#' @param oldna The `na` setting passed down to nested values.
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @param is_df Whether `x` is a data frame's column list.
#' @param keep_vec_names Whether a named vector is written as an object.
#' @return The JSON text, or a character vector of encoded elements when
#'   `collapse` is FALSE.
#' @noRd
.rmbl_json_as <- function(
  x,
  o,
  collapse = TRUE,
  na = NULL,
  oldna = NULL,
  auto_unbox = o$auto_unbox,
  indent = o$indent,
  is_df = FALSE,
  keep_vec_names = o$keep_vec_names
) {
  if (
    inherits(x, c("scalar", "json")) ||
      (inherits(x, "AsIs") && !is.data.frame(x))
  ) {
    return(.rmbl_json_as_wrapped(x, o, collapse, na, oldna, auto_unbox, indent))
  }
  if (is.data.frame(x)) {
    return(.rmbl_json_as_df(x, o, collapse, na, oldna, indent, keep_vec_names))
  }
  if (is.factor(x) || inherits(x, c("Date", "POSIXt", "ts", "hms", "blob"))) {
    return(.rmbl_json_as_special(
      x,
      o,
      collapse,
      na,
      oldna,
      auto_unbox,
      indent,
      keep_vec_names
    ))
  }
  if (is.null(x)) {
    return(if (identical(o$null, "null")) "null" else "{}")
  }
  # an S3 class none of the branches above know: jsonlite's ANY method tries
  # the remaining classes, then unclasses under force = TRUE, else errors
  if (!is.null(oldClass(x)) && !is.data.frame(x)) {
    return(.rmbl_json_as_other(x, o, collapse, na, oldna, auto_unbox, indent))
  }
  .rmbl_json_as_base(
    x,
    o,
    collapse,
    na,
    oldna,
    auto_unbox,
    indent,
    is_df,
    keep_vec_names
  )
}

#' Objects wrapped by unbox(), json() or I() as JSON.
#'
#' A scalar drops its marker and is written unboxed, json text is written
#' verbatim (or as a string), and an AsIs length-one vector stays an array.
#' @param x,o,collapse,na,oldna,auto_unbox,indent As for .rmbl_json_as().
#' @return The JSON text (or pieces when not collapsed).
#' @noRd
.rmbl_json_as_wrapped <- function(
  x,
  o,
  collapse,
  na,
  oldna,
  auto_unbox,
  indent
) {
  cls <- class(x)
  if (inherits(x, "scalar")) {
    y <- x
    if (length(cls) > 1L) {
      class(y) <- cls[-1L]
    } else {
      y <- unclass(y)
    }
    return(.rmbl_json_as(
      y,
      o,
      collapse = FALSE,
      na = na,
      oldna = oldna,
      auto_unbox = auto_unbox,
      indent = indent
    ))
  }
  if (inherits(x, "json")) {
    if (isTRUE(o$json_verbatim)) {
      return(as.character(x))
    }
    return(.rmbl_json_as(
      as.character(x),
      o,
      collapse,
      na,
      oldna,
      auto_unbox,
      indent
    ))
  }
  class(x) <- setdiff(cls, "AsIs")
  if (is.atomic(x) && length(x) == 1L) {
    auto_unbox <- FALSE
  }
  .rmbl_json_as(x, o, collapse, na, oldna, auto_unbox, indent)
}

#' Factors, dates, date-times, time series, times of day and blobs as JSON.
#' @param x,o,collapse,na,oldna,auto_unbox,indent,keep_vec_names As for
#'   .rmbl_json_as().
#' @return The JSON text (or pieces when not collapsed).
#' @noRd
.rmbl_json_as_special <- function(
  x,
  o,
  collapse,
  na,
  oldna,
  auto_unbox,
  indent,
  keep_vec_names
) {
  if (is.factor(x)) {
    return(.rmbl_json_as_factor(
      x,
      o,
      collapse,
      na,
      oldna,
      auto_unbox,
      indent,
      keep_vec_names
    ))
  }
  if (inherits(x, "Date")) {
    out <- if (identical(o$Date, "epoch")) unclass(x) else format(x)
    o$always_decimal <- FALSE
    return(.rmbl_json_as(out, o, collapse, na, oldna, auto_unbox, indent))
  }
  if (inherits(x, "POSIXt")) {
    return(.rmbl_json_as_posix(x, o, collapse, na, oldna, auto_unbox, indent))
  }
  if (inherits(x, "ts")) {
    return(.rmbl_json_as(
      as.vector(x),
      o,
      collapse,
      na,
      oldna,
      auto_unbox,
      indent
    ))
  }
  if (inherits(x, "hms")) {
    out <- if (identical(o$hms, "secs")) {
      as.numeric(x, units = "secs")
    } else {
      as.character(x)
    }
    out[is.na(x)] <- NA
    return(.rmbl_json_as(out, o, collapse, na, oldna, auto_unbox, indent))
  }
  if (inherits(x, "blob")) {
    return(.rmbl_json_as_blob(x, o, collapse, na, oldna, auto_unbox, indent))
  }
  stop("not a special class", call. = FALSE)
}

#' A blob as JSON: base64 strings, or its raw vectors as a list.
#' @param x,o,collapse,na,oldna,auto_unbox,indent As for .rmbl_json_as().
#' @return The JSON text (or pieces when not collapsed).
#' @noRd
.rmbl_json_as_blob <- function(x, o, collapse, na, oldna, auto_unbox, indent) {
  if (identical(o$raw, "base64")) {
    str <- vapply(x, jsb64enc, character(1))
    return(.rmbl_json_as(str, o, collapse, na, oldna, auto_unbox, indent))
  }
  .rmbl_json_as(
    unclass(as.list(x)),
    o,
    collapse,
    na,
    oldna,
    auto_unbox,
    indent
  )
}

#' A factor as JSON: its codes, or its labels.
#' @param x,o,collapse,na,oldna,auto_unbox,indent,keep_vec_names As for
#'   .rmbl_json_as().
#' @return The JSON text (or pieces when not collapsed).
#' @noRd
.rmbl_json_as_factor <- function(
  x,
  o,
  collapse,
  na,
  oldna,
  auto_unbox,
  indent,
  keep_vec_names
) {
  if (identical(o$factor, "integer")) {
    return(.rmbl_json_as(
      unclass(x),
      o,
      collapse,
      na,
      oldna,
      auto_unbox,
      indent
    ))
  }
  xc <- as.character(x)
  if (isTRUE(keep_vec_names)) {
    names(xc) <- names(x)
  }
  .rmbl_json_as(
    xc,
    o,
    collapse,
    na,
    oldna,
    auto_unbox,
    indent,
    keep_vec_names = keep_vec_names
  )
}

#' Date-times as JSON: mongo objects, epoch milliseconds or formatted text.
#' @param x,o,collapse,na,oldna,auto_unbox,indent As for .rmbl_json_as().
#' @return The JSON text (or pieces when not collapsed).
#' @noRd
.rmbl_json_as_posix <- function(x, o, collapse, na, oldna, auto_unbox, indent) {
  if (identical(o$POSIXt, "mongo")) {
    return(.rmbl_json_as_mongo_date(x, o, collapse, na, oldna, indent))
  }
  if (identical(o$POSIXt, "epoch")) {
    o2 <- o
    o2$always_decimal <- FALSE
    return(.rmbl_json_as(
      floor(unclass(as.POSIXct(x)) * 1000),
      o2,
      collapse,
      na,
      oldna,
      auto_unbox,
      indent
    ))
  }
  fmt <- o$time_format
  if (is.null(fmt)) {
    fmt <- if (identical(o$POSIXt, "string")) {
      ""
    } else if (isTRUE(o$UTC)) {
      "%Y-%m-%dT%H:%M:%SZ"
    } else {
      "%Y-%m-%dT%H:%M:%S"
    }
  }
  s <- if (isTRUE(o$UTC)) {
    format(x, format = fmt, tz = "UTC")
  } else {
    format(x, format = fmt)
  }
  .rmbl_json_as(s, o, collapse, na, oldna, auto_unbox, indent)
}

#' Date-times as mongo `{"$date": <epoch ms>}` objects.
#' @param x,o,collapse,na,oldna,indent As for .rmbl_json_as().
#' @return The JSON text (or pieces when not collapsed).
#' @noRd
.rmbl_json_as_mongo_date <- function(x, o, collapse, na, oldna, indent) {
  if (inherits(x, "POSIXlt")) {
    x <- as.POSIXct(x)
  }
  df <- data.frame("$date" = floor(unclass(x) * 1000), check.names = FALSE)
  o2 <- o
  o2$digits <- NA
  o2$always_decimal <- FALSE
  tmp <- .rmbl_json_as(
    df,
    o2,
    collapse = FALSE,
    na = na,
    oldna = oldna,
    indent = NA_integer_
  )
  tmp[is.na(x)] <- .rmbl_json_as(
    NA_character_,
    o,
    collapse = FALSE,
    na = na
  )
  if (isTRUE(collapse)) {
    .rmbl_json_collapse(tmp, inner = FALSE, indent = indent)
  } else {
    tmp
  }
}

#' An object of an S3 or S4 class no other branch knows: jsonlite's ANY method
#' tries the remaining classes, then unclasses under force = TRUE, else errors.
#' @param x,o,collapse,na,oldna,auto_unbox,indent As for .rmbl_json_as().
#' @return The JSON text (or pieces when not collapsed).
#' @noRd
.rmbl_json_as_other <- function(x, o, collapse, na, oldna, auto_unbox, indent) {
  cls <- class(x)
  if (isS4(x)) {
    if (isTRUE(o$force)) {
      return(.rmbl_json_as(
        attributes(x),
        o,
        collapse,
        na,
        oldna,
        auto_unbox,
        indent
      ))
    }
    stop("No method asJSON S4 class: ", cls, call. = FALSE)
  }
  if (length(cls) > 1L) {
    class(x) <- cls[-1L]
    return(.rmbl_json_as(x, o, collapse, na, oldna, auto_unbox, indent))
  }
  if (isTRUE(o$force)) {
    return(.rmbl_json_as(
      unclass(x),
      o,
      collapse,
      na,
      oldna,
      auto_unbox,
      indent
    ))
  }
  stop("No method asJSON S3 class: ", cls, call. = FALSE)
}

#' Base storage types as JSON (after S3 classes, the way jsonlite's S4
#' dispatch falls through to the implicit class).
#' @param x,o,collapse,na,oldna,auto_unbox,indent,is_df,keep_vec_names As for
#'   .rmbl_json_as().
#' @return The JSON text (or pieces when not collapsed).
#' @noRd
.rmbl_json_as_base <- function(
  x,
  o,
  collapse,
  na,
  oldna,
  auto_unbox,
  indent,
  is_df,
  keep_vec_names
) {
  if (is.raw(x)) {
    return(.rmbl_json_as_raw(x, o, collapse, na, oldna, auto_unbox, indent))
  }
  if (is.matrix(x) || (is.array(x) && length(dim(x)) >= 2L)) {
    return(.rmbl_json_as_array(
      x,
      o,
      collapse,
      na,
      oldna,
      auto_unbox,
      indent,
      keep_vec_names
    ))
  }
  if (is.list(x) || is.pairlist(x)) {
    return(.rmbl_json_as_list(
      x,
      o,
      collapse,
      na,
      oldna,
      auto_unbox,
      indent,
      is_df
    ))
  }
  .rmbl_json_as_atomic(
    x,
    o,
    collapse,
    na,
    oldna,
    auto_unbox,
    indent,
    keep_vec_names
  )
}

#' Character, logical, complex and numeric vectors as JSON; anything else
#' (an environment, a symbol, a function) is null under force = TRUE.
#' @param x,o,collapse,na,oldna,auto_unbox,indent,keep_vec_names As for
#'   .rmbl_json_as().
#' @return The JSON text (or pieces when not collapsed).
#' @noRd
.rmbl_json_as_atomic <- function(
  x,
  o,
  collapse,
  na,
  oldna,
  auto_unbox,
  indent,
  keep_vec_names
) {
  if (is.character(x)) {
    return(.rmbl_json_as_chr(
      x,
      o,
      collapse,
      na,
      auto_unbox,
      indent,
      keep_vec_names
    ))
  }
  if (is.logical(x)) {
    return(.rmbl_json_as_lgl(
      x,
      o,
      collapse,
      na,
      auto_unbox,
      indent,
      keep_vec_names
    ))
  }
  if (is.complex(x)) {
    return(.rmbl_json_as_cplx(x, o, collapse, na, oldna, auto_unbox, indent))
  }
  if (is.numeric(x)) {
    return(.rmbl_json_as_num(
      x,
      o,
      collapse,
      na,
      auto_unbox,
      indent,
      keep_vec_names
    ))
  }
  # what is left has no class attribute and is not data: an environment, a
  # symbol, a function, an external pointer
  if (isTRUE(o$force)) {
    return(.rmbl_json_as(NULL, o))
  }
  stop("No method asJSON S3 class: ", class(x), call. = FALSE)
}

#' A data frame's columns prepared for JSON: the row names as `_row` when
#' asked, named list columns unnamed, POSIXlt as POSIXct.
#' @param x The data frame to prepare for encoding.
#' @param o The encoding options, such as `rownames`.
#' @param has_names Whether every column is named.
#' @return The data frame.
#' @noRd
.rmbl_json_df_prepare <- function(x, o, has_names) {
  rn <- attr(x, "row.names")
  if (
    isTRUE(o$rownames) ||
      (is.null(o$rownames) && is.character(rn) && !all(grepl("^\\d+$", rn)))
  ) {
    if (has_names) x[["_row"]] <- rn
  }
  for (i in which(vapply(
    x,
    function(c) isTRUE(is.list(c) && !is.data.frame(c) && !is.null(names(c))),
    logical(1)
  ))) {
    x[[i]] <- unname(x[[i]])
  }
  for (i in which(vapply(x, inherits, logical(1), "POSIXlt"))) {
    x[[i]] <- as.POSIXct(x[[i]])
  }
  x
}

#' Raw columns as hex, and complex ones as real and imaginary parts when asked.
#' @param x The data frame whose raw and complex columns are encoded.
#' @param o The encoding options, such as `complex`.
#' @return The data frame.
#' @noRd
.rmbl_json_df_encode <- function(x, o) {
  for (i in which(vapply(x, is.raw, logical(1)))) {
    x[[i]] <- as.character.hexmode(x[[i]])
  }
  if (identical(o$complex, "list")) {
    for (i in which(vapply(x, is.complex, logical(1)))) {
      x[[i]] <- data.frame(real = Re(x[[i]]), imaginary = Im(x[[i]]))
    }
  }
  x
}

#' Encodes a numeric vector as JSON.
#' @param x The vector.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether the values are collapsed into one array.
#' @param na How missing values are written, or NULL for \code{"string"}.
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @param keep_vec_names Whether a named vector is written as an object.
#' @return The JSON text, or the encoded elements.
#' @noRd
.rmbl_json_as_num <- function(
  x,
  o,
  collapse,
  na,
  auto_unbox,
  indent,
  keep_vec_names
) {
  if (isTRUE(keep_vec_names) && length(names(x))) {
    if (!isTRUE(o$quiet_vec_names)) {
      message(
        "Input to asJSON(keep_vec_names=TRUE) is a named vector. In a ",
        "future version of jsonlite, this option will not be supported, ",
        "and named vectors will be translated into arrays instead of ",
        "objects. If you want JSON object output, please use a named ",
        "list instead. See ?toJSON."
      )
    }
    o$always_decimal <- FALSE
    return(.rmbl_json_as(
      as.list(x),
      o,
      collapse,
      na = na,
      auto_unbox = TRUE,
      indent = NA_integer_
    ))
  }
  na <- if (is.null(na)) "string" else .rmbl_arg(na, c("string", "null", "NA"))
  nas <- switch(na, string = TRUE, null = FALSE, "NA" = NA)
  if (!is.null(attr(x, "dim")) && length(dim(x)) < 2L) {
    x <- c(x)
  }
  tmp <- .rmbl_json_num_to_char(
    x,
    o$digits,
    nas,
    o$use_signif,
    o$always_decimal
  )
  if (isTRUE(auto_unbox) && length(tmp) == 1L) {
    return(tmp)
  }
  if (collapse) .rmbl_json_collapse(tmp, indent = indent) else tmp
}
#' Encodes a character vector as JSON.
#' @param x The vector.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether the values are collapsed into one array.
#' @param na How missing values are written, or NULL for \code{"null"}.
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @param keep_vec_names Whether a named vector is written as an object.
#' @return The JSON text, or the encoded elements.
#' @noRd
.rmbl_json_as_chr <- function(
  x,
  o,
  collapse,
  na,
  auto_unbox,
  indent,
  keep_vec_names
) {
  if (isTRUE(keep_vec_names) && length(names(x))) {
    if (!isTRUE(o$quiet_vec_names)) {
      message(
        "Input to asJSON(keep_vec_names=TRUE) is a named vector. In a ",
        "future version of jsonlite, this option will not be supported, ",
        "and named vectors will be translated into arrays instead of ",
        "objects. If you want JSON object output, please use a named ",
        "list instead. See ?toJSON."
      )
    }
    return(.rmbl_json_as(
      as.list(x),
      o,
      collapse,
      na = na,
      auto_unbox = TRUE,
      indent = NA_integer_
    ))
  }
  tmp <- .rmbl_json_esc(as.character(x))
  miss <- which(is.na(x))
  if (length(miss)) {
    na <- if (is.null(na)) "null" else .rmbl_arg(na, c("null", "string", "NA"))
    tmp[miss] <- if (na == "null") {
      "null"
    } else if (na == "string") {
      "\"NA\""
    } else {
      NA_character_
    }
  }
  if (isTRUE(auto_unbox) && length(tmp) == 1L) {
    return(tmp)
  }
  if (isTRUE(collapse)) .rmbl_json_collapse(tmp, indent = indent) else tmp
}
#' Encodes a logical vector as JSON.
#' @param x The vector.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether the values are collapsed into one array.
#' @param na How missing values are written, or NULL for \code{"null"}.
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @param keep_vec_names Whether a named vector is written as an object.
#' @return The JSON text, or the encoded elements.
#' @noRd
.rmbl_json_as_lgl <- function(
  x,
  o,
  collapse,
  na,
  auto_unbox,
  indent,
  keep_vec_names
) {
  if (isTRUE(keep_vec_names) && length(names(x))) {
    if (!isTRUE(o$quiet_vec_names)) {
      message(
        "Input to asJSON(keep_vec_names=TRUE) is a named vector. In a ",
        "future version of jsonlite, this option will not be supported, ",
        "and named vectors will be translated into arrays instead of ",
        "objects. If you want JSON object output, please use a named ",
        "list instead. See ?toJSON."
      )
    }
    return(.rmbl_json_as(
      as.list(x),
      o,
      collapse,
      na = na,
      auto_unbox = TRUE,
      indent = NA_integer_
    ))
  }
  na <- if (is.null(na)) "null" else .rmbl_arg(na, c("null", "string", "NA"))
  tmp <- ifelse(x, "true", "false")
  if (!identical(na, "NA")) {
    miss <- which(is.na(x))
    if (length(miss)) {
      tmp[miss] <- if (identical(na, "string")) "\"NA\"" else "null"
    }
  }
  if (!is.character(tmp)) {
    tmp <- as.character(tmp)
  }
  if (isTRUE(auto_unbox) && length(tmp) == 1L) {
    return(tmp)
  }
  if (collapse) .rmbl_json_collapse(tmp, indent = indent) else tmp
}
#' Encodes a complex vector as JSON, as strings or as real and imaginary arrays.
#' @param x The vector.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether the values are collapsed into one array.
#' @param na How missing values are written, or NULL for \code{"string"}.
#' @param oldna The `na` setting passed down to nested values.
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @return The JSON text, or the encoded elements.
#' @noRd
.rmbl_json_as_cplx <- function(x, o, collapse, na, oldna, auto_unbox, indent) {
  na <- if (is.null(na)) "string" else .rmbl_arg(na, c("string", "null", "NA"))
  if (identical(o$complex, "string")) {
    mystring <- prettyNum(
      x = x,
      digits = if (is.null(o$digits)) 5 else o$digits
    )
    miss <- which(!is.finite(x))
    if (length(miss) && na %in% c("null", "NA")) {
      mystring[miss] <- NA_character_
    }
    return(.rmbl_json_as_chr(
      mystring,
      o,
      collapse,
      na,
      auto_unbox,
      indent,
      FALSE
    ))
  }
  if (na == "NA") {
    na <- oldna
  }
  .rmbl_json_as(
    list(real = Re(x), imaginary = Im(x)),
    o,
    collapse,
    na = na,
    oldna = oldna,
    auto_unbox = auto_unbox,
    indent = indent
  )
}
#' Encodes a raw vector as JSON in the form `o$raw` names.
#' @param x The vector.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether the values are collapsed into one array.
#' @param na How missing values are written.
#' @param oldna The `na` setting passed down to nested values.
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @return The JSON text.
#' @noRd
.rmbl_json_as_raw <- function(x, o, collapse, na, oldna, auto_unbox, indent) {
  raw <- o$raw
  if (raw == "mongo") {
    type <- if (length(attr(x, "type"))) attr(x, "type") else 5
    return(.rmbl_json_as(
      list(
        `$binary` = bricklayer_json_unbox(jsb64enc(x)),
        `$type` = bricklayer_json_unbox(as.character(type))
      ),
      o,
      indent = NA_integer_
    ))
  }
  if (raw == "hex") {
    return(.rmbl_json_as(
      as.character.hexmode(x),
      o,
      collapse,
      na,
      oldna,
      auto_unbox,
      indent
    ))
  }
  if (raw == "int") {
    return(.rmbl_json_as(
      as.integer(x),
      o,
      collapse,
      na,
      oldna,
      auto_unbox,
      indent
    ))
  }
  if (raw == "js") {
    return(.rmbl_json_as_raw_js(x, o))
  }
  .rmbl_json_as(jsb64enc(x), o, collapse, na, oldna, auto_unbox, indent)
}

#' A raw vector as a JavaScript `new Uint8Array([...])` expression.
#' @param x The raw vector.
#' @param o The options list built by `tojs()`.
#' @return The JavaScript text.
#' @noRd
.rmbl_json_as_raw_js <- function(x, o) {
  o$always_decimal <- FALSE
  paste0(
    "(new Uint8Array(",
    .rmbl_json_as(
      as.integer(x),
      o,
      collapse = TRUE,
      na = NULL,
      auto_unbox = FALSE,
      indent = NA_integer_
    ),
    "))"
  )
}
#' Encodes a matrix or array as nested JSON arrays.
#' @param x The matrix or array.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether the rows are collapsed into one array.
#' @param na How missing values are written.
#' @param oldna The `na` setting passed down to nested values.
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @param keep_vec_names Whether a named vector is written as an object.
#' @return The JSON text, or one encoded element per row.
#' @noRd
.rmbl_json_as_array <- function(
  x,
  o,
  collapse,
  na,
  oldna,
  auto_unbox,
  indent,
  keep_vec_names
) {
  if (identical(na, "NA")) {
    na <- oldna
  }
  if (length(dim(x)) < 2L) {
    return(.rmbl_json_as(
      c(x),
      o,
      collapse,
      na = na,
      indent = .rmbl_json_indent_inc(indent)
    ))
  }
  columnmajor <- identical(o$matrix, "columnmajor")
  if (columnmajor && !collapse) {
    return(apply(x, 1L, function(r) {
      .rmbl_json_as(r, o, na = na, indent = .rmbl_json_indent_inc(indent))
    }))
  }
  m <- .rmbl_json_as(c(x), o, collapse = FALSE, na = na, auto_unbox = FALSE)
  dim(m) <- dim(x)
  tmp <- if (length(dim(x)) == 2L && !columnmajor) {
    .rmbl_json_row_collapse(m, indent = .rmbl_json_indent_inc(indent))
  } else {
    .rmbl_json_collapse_array(m, columnmajor = columnmajor, indent = indent)
  }
  if (collapse) {
    .rmbl_json_collapse(tmp, inner = FALSE, indent = indent)
  } else {
    tmp
  }
}
#' Collapses an array of encoded values into nested JSON arrays, the innermost
#' dimension first.
#' @param x The array of encoded values.
#' @param columnmajor Whether the array is written by columns.
#' @param indent The indent, NA for compact output.
#' @return An array of encoded values with the last dimension left.
#' @noRd
.rmbl_json_collapse_array <- function(x, columnmajor = FALSE, indent) {
  n <- length(dim(x))
  dims <- 1:(n - 1) + as.numeric(columnmajor)
  x <- apply(x, dims, .rmbl_json_collapse, inner = TRUE, indent = indent)
  for (i in rev(seq_along(dim(x)))[-1]) {
    dims <- 1:(length(dim(x)) - 1) + as.numeric(columnmajor)
    inc <- .rmbl_json_indent_inc(indent)
    ind <- if (is.na(inc)) {
      inc
    } else {
      structure(as.integer(inc) * i, indent_spaces = attr(inc, "indent_spaces"))
    }
    x <- apply(x, dims, .rmbl_json_collapse, inner = FALSE, indent = ind)
  }
  x
}
#' Encodes a list as a JSON object (when named) or array, at most 100 levels
#' deep.
#' @param x The list or pairlist.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether an unnamed list is collapsed into one array.
#' @param na How missing values are written.
#' @param oldna The `na` setting passed down to nested values.
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @param is_df Whether `x` is a data frame's column list.
#' @return The JSON text, or the encoded elements.
#' @noRd
.rmbl_json_as_list <- function(
  x,
  o,
  collapse,
  na,
  oldna,
  auto_unbox,
  indent,
  is_df
) {
  # the same cap as the parser's, so what the parser reads the encoder can
  # write back; the recursion used to run into the C stack ~100 levels down
  o$depth <- (o$depth %||% 0L) + 1L
  if (o$depth > 100L) {
    stop("nesting deeper than 100 levels", call. = FALSE)
  }
  if (identical(na, "NA")) {
    na <- oldna
  }
  if (is.pairlist(x)) {
    x <- as.vector(x, mode = "list")
  }
  inc <- .rmbl_json_indent_inc(indent)
  # a data frame's columns under auto_unbox unbox only their list cells
  unbox_lists <- if (is_df && auto_unbox) TRUE else FALSE
  tmp <- vapply(
    x,
    function(y) {
      .rmbl_json_as(
        y,
        o,
        na = na,
        oldna = oldna,
        auto_unbox = if (unbox_lists) is.list(y) else auto_unbox,
        indent = inc
      )
    },
    character(1)
  )
  if (!is.null(names(x))) {
    keys <- if (isTRUE(o$keep_empty_names)) {
      .rmbl_json_esc(names(x))
    } else {
      .rmbl_json_esc(.rmbl_json_cleannames(names(x), o$no_dots))
    }
    return(.rmbl_json_collapse_object(keys, unname(tmp), indent))
  }
  if (collapse) {
    .rmbl_json_collapse(unname(tmp), inner = FALSE, indent = indent)
  } else {
    unname(tmp)
  }
}
#' Encodes a data frame as JSON by rows, columns or values, as `o$dataframe`
#' says.
#' @param x The data frame to encode.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether the rows are collapsed into one array.
#' @param na How missing values are written.
#' @param oldna The `na` setting passed down to nested values.
#' @param indent The indent, NA for compact output.
#' @param keep_vec_names Not used: a data frame's columns are never written as
#'   objects.
#' @return The JSON text, or one encoded element per row.
#' @noRd
.rmbl_json_as_df <- function(
  x,
  o,
  collapse,
  na,
  oldna,
  indent,
  keep_vec_names
) {
  dataframe <- o$dataframe
  o$keep_vec_names <- FALSE
  has_names <- identical(length(names(x)), ncol(x))
  x <- .rmbl_json_df_prepare(x, o, has_names)
  if (dataframe == "columns") {
    return(.rmbl_json_as_list(
      as.list(x),
      o,
      collapse = TRUE,
      na = na,
      oldna = oldna,
      auto_unbox = o$auto_unbox,
      indent = indent,
      is_df = TRUE
    ))
  }
  if (is.null(na) || !length(na) || identical(na, "NA")) {
    oldna <- NULL
  } else {
    oldna <- na
  }
  if (dataframe == "rows" && has_names) {
    na <- if (is.null(na)) "NA" else .rmbl_arg(na, c("NA", "null", "string"))
  }
  if (!nrow(x)) {
    return(.rmbl_json_as(list(), o, collapse = collapse, indent = indent))
  }
  x <- .rmbl_json_df_encode(x, o)
  dfnames <- .rmbl_json_esc(.rmbl_json_cleannames(names(x), o$no_dots))
  inc <- .rmbl_json_indent_inc(indent)
  out <- .rmbl_json_df_cells(x, o, na, oldna, inc)
  tmp <- if (dataframe == "rows" && length(dfnames) == ncol(out)) {
    .rmbl_json_row_collapse_object(dfnames, out, indent = inc)
  } else {
    .rmbl_json_row_collapse(out, indent = indent)
  }
  if (isTRUE(collapse)) {
    .rmbl_json_collapse(tmp, inner = FALSE, indent = indent)
  } else {
    tmp
  }
}

#' Encodes every cell of a data frame, one column at a time.
#' @param x The data frame, its columns already prepared.
#' @param o The options list built by `tojs()`.
#' @param na How missing values are written.
#' @param oldna The `na` setting passed down to nested values.
#' @param inc The indent one level in.
#' @return A character matrix of encoded cells, one row per data frame row.
#' @noRd
.rmbl_json_df_cells <- function(x, o, na, oldna, inc) {
  cols <- lapply(
    x,
    .rmbl_json_as,
    o,
    collapse = FALSE,
    na = na,
    oldna = oldna,
    auto_unbox = o$auto_unbox,
    indent = inc
  )
  matrix(unlist(cols, use.names = FALSE), nrow = nrow(x))
}


#' Whether tojs() counts `digits` as significant digits.
#' @param use_signif The `use_signif` option, or NULL.
#' @param digits The `digits` argument.
#' @return TRUE or FALSE: the option when given, else whether `digits` is
#'   wrapped in I().
#' @noRd
.rmbl_json_use_signif <- function(use_signif, digits) {
  if (!is.null(use_signif)) {
    isTRUE(use_signif)
  } else {
    inherits(digits, "AsIs")
  }
}

#' Checks the `digits` argument of tojs().
#'
#' NULL (full precision, this codec's own) and NA (15 significant digits) are
#' documented forms; anything else must be one number.
#' @param digits The `digits` argument.
#' @return NULL, invisibly; an error when `digits` is not usable.
#' @noRd
.rmbl_json_check_digits <- function(digits) {
  if (
    !is.null(digits) &&
      (!(is.numeric(digits) || is.logical(digits)) ||
        length(digits) != 1L ||
        (!is.na(digits) && !is.numeric(digits)))
  ) {
    stop(
      "`digits` must be one number, NA for 15 significant digits, or ",
      "I(n) for n",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Mark a value as a JSON scalar (jsonlite's unbox)
#'
#' @param x an atomic vector of length one, a one-row data.frame,
#' or a length-one POSIXt.
#' @return `x` with class `scalar`, so it is written without
#' brackets.
#' @noRd
bricklayer_json_unbox <- function(x) {
  if (is.null(x)) {
    return(x)
  }
  if (is.data.frame(x)) {
    if (nrow(x) == 1L) {
      return(.rmbl_json_as_scalar(x))
    }
    stop("Tried to unbox dataframe with ", nrow(x), " rows.", call. = FALSE)
  }
  if (length(x) == 1L && inherits(x, "POSIXt")) {
    return(.rmbl_json_as_scalar(x))
  }
  if (!is.atomic(x) || length(dim(x)) > 1L) {
    stop(
      "Only atomic vectors of length 1 or data frames with 1 row can be ",
      "unboxed.",
      call. = FALSE
    )
  }
  if (identical(length(x), 1L)) {
    return(.rmbl_json_as_scalar(x))
  }
  stop("Tried to unbox a vector of length ", length(x), call. = FALSE)
}
#' Adds the class `scalar`, so the value is written without brackets.
#' @param obj The value.
#' @return `obj` with class `scalar` first.
#' @noRd
.rmbl_json_as_scalar <- function(obj) {
  class(obj) <- c("scalar", class(obj))
  obj
}

# Decimal to double, correctly rounded, independent of the platform's
# C library.
#
# A capsule bundle vendors this file and sources it on its own, with
# nothing but R 4.0+ available and no compiled library to call into --
# that is the point of a bundle a recipient can run without installing
# anything. There the registered symbol does not exist, and calling it
# is what broke the bundle: "object 'C_rmbl_strtod' not found". So the
# native converter is used when it is there and R's own reader when it
# is not, decided once and remembered rather than per number.
#
# The fallback is the platform's strtod, which is not correctly rounded
# at the extreme ends of the double range on every platform -- that is
# the defect the native converter exists to fix. It is the right
# trade here and nowhere else: a bundle reads configuration numbers and
# CSV columns, and read.csv goes through the same reader regardless, so
# the fallback cannot be worse than the rest of the bundle's arithmetic.
# Inside the installed package the native path is always taken.
.rmbl_native <- new.env(parent = emptyenv())
#' Converts decimal text to doubles, correctly rounded where the native
#' converter is there.
#' @param x The decimal text.
#' @return A double vector.
#' @noRd
.rmbl_strtod <- function(x) {
  have <- .rmbl_native$strtod
  if (is.null(have)) {
    have <- exists("C_rmbl_strtod", inherits = TRUE)
    .rmbl_native$strtod <- have
  }
  if (have) .Call(C_rmbl_strtod, as.character(x)) else as.numeric(x)
}

#' Writes doubles with seventeen significant digits.
#'
#' The writer's half of the same argument. sprintf(\dQuote{%.17g}) delegates to
#' the platform, and on Windows aarch64 the platform is wrong: it renders
#' the largest double one ulp low, so the text reads back as a different
#' number. Seventeen digits are the package's round-trip guarantee, so
#' the digits are generated by exact integer arithmetic instead. Where no
#' compiled library is present -- a vendored bundle -- fall back to the
#' platform and let the caller's round-trip check stand.
#' @param x A double vector.
#' @return A character vector.
#' @noRd
.rmbl_dtoa17 <- function(x) {
  have <- .rmbl_native$dtoa17
  if (is.null(have)) {
    have <- exists("C_rmbl_dtoa17", inherits = TRUE)
    .rmbl_native$dtoa17 <- have
  }
  if (have) .Call(C_rmbl_dtoa17, as.double(x)) else sprintf("%.17g", x)
}

# ================================================================ parser

#' Parses JSON text into R values, without simplifying.
#'
#' A yajl-equivalent parser: one pass over the text with a byte cursor.
#' Numbers follow yajl_tree: no '.'/'e' -> integer (double above 2^31-1,
#' character above 2^53 when bigint_as_char); otherwise a decimal.
#'
#' The decimal is converted by this package rather than by the platform.
#' Seventeen significant digits recover any double exactly, but only
#' through a reader that rounds correctly, and not every platform's
#' does -- on macOS arm64 the C library reads the correct decimal for
#' the largest double as infinity, and loses low bits above about 1e100.
#' A manifest written on one machine would then read back as a different
#' number on another, which for a format meant to be checked elsewhere
#' is a bug rather than a caveat. See src/rmbl_strtod.cpp.
#' @param txt The JSON text; lines are joined with newlines.
#' @param bigint_as_char Whether an integer above 2^53 is returned as text.
#' @param bigint_warn Whether a warning says an integer above 2^53 lost
#'   precision.
#' @param duplicate_keys \code{"error"} refuses an object with a key twice,
#' \code{"keep"} keeps both.
#' @return The parsed value: lists, atomic scalars and NULL.
#' @noRd
.rmbl_json_parse <- function(
  txt,
  bigint_as_char = FALSE,
  bigint_warn = TRUE,
  duplicate_keys = c("error", "keep")
) {
  duplicate_keys <- .rmbl_arg(duplicate_keys)
  s <- .rmbl_json_parse_text(txt)
  r <- .rmbl_json_parse_fast(s, duplicate_keys, bigint_as_char, bigint_warn)
  if (!is.null(r)) {
    return(r[[1L]])
  }
  P <- .rmbl_jp_state(s, bigint_as_char, bigint_warn, duplicate_keys)
  v <- .rmbl_jp_value(P)
  .rmbl_jp_ws(P)
  if (P$i <= P$n) {
    .rmbl_jp_bad(P, "trailing content")
  }
  v
}

#' Joins JSON text into one UTF-8 string for the parser.
#'
#' Converts latin1 lines, drops a byte-order mark (with jsonlite's warning)
#' and a leading record separator, and refuses bytes that are not UTF-8.
#' @param txt The JSON text; lines are joined with newlines.
#' @return One UTF-8 string.
#' @noRd
.rmbl_json_parse_text <- function(txt) {
  # latin1 text is converted before paste(): in a C locale paste() wrote its
  # accented letters as "<e9>", and the parser read that text as the data (audit
  # of 30bed8e, #17)
  lat <- if (is.character(txt)) Encoding(txt) == "latin1" else FALSE
  if (any(lat)) {
    txt[lat] <- iconv(txt[lat], "latin1", "UTF-8")
  }
  s <- paste(txt, collapse = "\n")
  # the byte-order mark is tested and removed on the BYTES, before any
  # encoding conversion: substring(s, 2L) on a string a C locale has not
  # marked as UTF-8 removed one of the mark's three bytes
  if (.rmbl_has_bom(s)) {
    warning(
      "JSON string contains (illegal) UTF8 byte-order-mark!",
      call. = FALSE
    )
    s <- .rmbl_strip_bom(s)
  }
  # JSON is UTF-8 (RFC 8259): bytes that are not were read with base R's
  # warnings and garbled. Checked before the conversion: in a C locale
  # enc2utf8() rewrote an invalid byte as a valid escape, and the text then
  # failed as "unexpected character" (C-locale check of 1.0.0)
  if (Encoding(s) != "latin1" && !validUTF8(s)) {
    stop("the JSON text is not valid UTF-8", call. = FALSE)
  }
  s <- .rmbl_as_utf8(s)
  if (startsWith(s, "\x1e")) {
    s <- substring(s, 2L)
  }
  s
}

#' Parses JSON text with the package's compiled parser, when it is loaded.
#' @param s One UTF-8 string from .rmbl_json_parse_text().
#' @param duplicate_keys \code{"error"} or \code{"keep"}.
#' @param bigint_as_char,bigint_warn As for .rmbl_json_parse().
#' @return A list whose first element is the parsed value, or NULL when the
#'   compiled parser is absent or gives the text back to the R parser.
#' @noRd
.rmbl_json_parse_fast <- function(
  s,
  duplicate_keys,
  bigint_as_char,
  bigint_warn
) {
  # the package's native path for a well-formed document (85 s for a 15 MiB
  # reply here; CRAN stress test of 0.5.14); it gives up (NULL) on whatever
  # needs this parser's words: an error, a big integer, a duplicate key, deep
  # nesting. A staged bundle has no native code and parses here.
  fast <- .rmbl_native$json
  if (is.null(fast)) {
    fast <- exists("C_rmbl_json_fast", inherits = TRUE)
    .rmbl_native$json <- fast
  }
  if (fast) {
    r <- .Call(
      C_rmbl_json_fast,
      s,
      duplicate_keys == "keep",
      isTRUE(bigint_as_char)
    )
    if (!is.null(r)) {
      if (!is.null(r[[2L]]) && bigint_warn) {
        warning(
          sprintf(
            paste0(
              "integer %s exceeds 2^53 and cannot be held exactly ",
              "in a double; pass bigint_as_char = TRUE to keep it as text"
            ),
            r[[2L]]
          ),
          call. = FALSE
        )
      }
      return(r)
    }
  }
  NULL
}

#' The state of one parse by the R JSON parser: the text, the cursor, the
#' nesting depth and the big-integer flag.
#'
#' The code points once, and the positions the scanner jumps to (the next
#' character that is not white space, not a digit, or that ends a run of plain
#' string text): one R call per character took 85 s for a 15 MiB reply (CRAN
#' stress test of 0.5.14).
#' @param s The text, UTF-8.
#' @param bigint_as_char,bigint_warn,duplicate_keys As for .rmbl_json_parse().
#' @return An environment.
#' @noRd
.rmbl_jp_state <- function(s, bigint_as_char, bigint_warn, duplicate_keys) {
  P <- new.env(parent = emptyenv())
  P$ch <- strsplit(s, "", fixed = TRUE)[[1]]
  P$n <- length(P$ch)
  P$i <- 1L
  cp <- utf8ToInt(s)
  P$cp <- cp
  P$is_ws <- cp == 32L | cp == 9L | cp == 10L | cp == 13L
  # double: findInterval() copies an integer vector each call
  P$not_ws <- as.double(which(!P$is_ws))
  P$is_dig <- cp >= 48L & cp <= 57L
  P$not_dig <- as.double(which(!P$is_dig))
  # a quote, a backslash or a control character
  P$spec <- as.double(which(cp == 34L | cp == 92L | cp < 32L))
  P$depth <- 0L # nesting, capped: 20,000 "[" exhausted the C stack
  P$big_warned <- FALSE # one warning per document for integers above 2^53
  P$bigint_as_char <- bigint_as_char
  P$bigint_warn <- bigint_warn
  P$duplicate_keys <- duplicate_keys
  P
}

#' The first position of `v` at or after `pos`, n + 1 when there is none.
#' @param P The parse state.
#' @param pos A position.
#' @param v Sorted positions.
#' @return A position.
#' @noRd
.rmbl_jp_after <- function(P, pos, v) {
  j <- v[findInterval(pos - 1L, v, checkSorted = FALSE, checkNA = FALSE) + 1L]
  if (is.na(j)) P$n + 1L else as.integer(j)
}

#' Stops the parse with the position it reached.
#' @param P The parse state.
#' @param msg What is wrong, reported with the character position.
#' @noRd
.rmbl_jp_bad <- function(P, msg) {
  stop(.rmbl_fn(), sprintf("%s at character %d", msg, P$i), call. = FALSE)
}

#' Skips white space.
#' @param P The parse state.
#' @noRd
.rmbl_jp_ws <- function(P) {
  if (P$i <= P$n && P$is_ws[P$i]) P$i <- .rmbl_jp_after(P, P$i, P$not_ws)
}

#' Reads a string; the cursor is on its opening quote.
#' @param P The parse state.
#' @return The string.
#' @noRd
.rmbl_jp_str <- function(P) {
  ch <- P$ch
  n <- P$n
  P$i <- P$i + 1L
  st <- P$i
  # a string with no escape (nearly every one): its text in one step
  j <- .rmbl_jp_after(P, P$i, P$spec)
  if (j <= n && P$cp[j] == 34L) {
    P$i <- j + 1L
    return(if (j > st) paste(ch[st:(j - 1L)], collapse = "") else "")
  }
  # pieces are appended into a doubling buffer: c(parts, ...) per escape
  # was quadratic, and 532 bytes of gzip held 250,000 escapes
  q <- new.env(parent = emptyenv())
  q$parts <- character(32L)
  q$np <- 0L
  push <- function(v) {
    q$np <- q$np + 1L
    if (q$np > length(q$parts)) {
      length(q$parts) <- 2L * length(q$parts)
    }
    q$parts[q$np] <- v
  }
  repeat {
    P$i <- .rmbl_jp_after(P, P$i, P$spec)
    if (P$i > n) {
      .rmbl_jp_bad(P, "unterminated string")
    }
    c0 <- ch[P$i]
    if (c0 == "\"") {
      break
    }
    if (c0 == "\\") {
      if (P$i > st) {
        push(paste(ch[st:(P$i - 1L)], collapse = ""))
      }
      P$i <- P$i + 1L
      push(.rmbl_jp_escape(P))
      P$i <- P$i + 1L
      st <- P$i
      next
    }
    .rmbl_jp_bad(P, "control character in string")
  }
  if (P$i > st) {
    push(paste(ch[st:(P$i - 1L)], collapse = ""))
  }
  P$i <- P$i + 1L
  paste(q$parts[seq_len(q$np)], collapse = "")
}

#' The text of one escape; the cursor is on the character after the backslash,
#' and is left on the escape's last character.
#' @param P The parse state.
#' @return The text.
#' @noRd
.rmbl_jp_escape <- function(P) {
  switch(
    P$ch[P$i],
    n = "\n",
    t = "\t",
    r = "\r",
    b = "\b",
    f = "\f",
    "\"" = "\"",
    "\\" = "\\",
    "/" = "/",
    u = .rmbl_jp_uescape(P),
    .rmbl_jp_bad(P, "invalid escape")
  )
}

#' A \\u escape, with the low half of a surrogate pair when one follows.
#' @param P The parse state; the cursor is on the u.
#' @return The character.
#' @noRd
.rmbl_jp_uescape <- function(P) {
  ch <- P$ch
  code <- .rmbl_json_hex4(ch[(P$i + 1L):(P$i + 4L)])
  if (is.na(code)) {
    .rmbl_jp_bad(P, "invalid \\u escape")
  }
  P$i <- P$i + 4L
  if (
    code >= 0xD800 &&
      code <= 0xDBFF &&
      P$i + 6L <= P$n &&
      ch[P$i + 1L] == "\\" &&
      ch[P$i + 2L] == "u"
  ) {
    lo <- .rmbl_json_hex4(ch[(P$i + 3L):(P$i + 6L)])
    if (!is.na(lo) && lo >= 0xDC00 && lo <= 0xDFFF) {
      P$i <- P$i + 6L
      code <- 0x10000 + (code - 0xD800) * 1024 + (lo - 0xDC00)
    }
  }
  if (code == 0) {
    .rmbl_jp_bad(P, "NUL in string")
  }
  # an unpaired surrogate is not a character;
  # intToUtf8() turned it into the text "NA"
  if (code >= 0xD800 && code <= 0xDFFF) {
    .rmbl_jp_bad(P, "lone surrogate escape")
  }
  intToUtf8(code)
}

#' Reads a number's sign and integer digits.
#' @param P The parse state.
#' @noRd
.rmbl_jp_int_part <- function(P) {
  if (P$ch[P$i] == "-") {
    P$i <- P$i + 1L
  }
  if (P$i > P$n || !P$is_dig[P$i]) {
    .rmbl_jp_bad(P, "invalid number")
  }
  if (P$ch[P$i] == "0") {
    P$i <- P$i + 1L
  } else {
    P$i <- .rmbl_jp_after(P, P$i, P$not_dig)
  }
  invisible(NULL)
}

#' Reads a number's fraction and exponent, when it has them.
#' @param P The parse state.
#' @return TRUE when it had either (it is then not an integer).
#' @noRd
.rmbl_jp_frac_part <- function(P) {
  ch <- P$ch
  n <- P$n
  had <- FALSE
  if (P$i <= n && ch[P$i] == ".") {
    had <- TRUE
    P$i <- P$i + 1L
    if (P$i > n || !P$is_dig[P$i]) {
      .rmbl_jp_bad(P, "invalid number")
    }
    P$i <- .rmbl_jp_after(P, P$i, P$not_dig)
  }
  if (P$i <= n && (ch[P$i] == "e" || ch[P$i] == "E")) {
    had <- TRUE
    P$i <- P$i + 1L
    if (P$i <= n && (ch[P$i] == "+" || ch[P$i] == "-")) {
      P$i <- P$i + 1L
    }
    if (P$i > n || !P$is_dig[P$i]) {
      .rmbl_jp_bad(P, "invalid number")
    }
    P$i <- .rmbl_jp_after(P, P$i, P$not_dig)
  }
  had
}

#' Reads a number; the cursor is on its first character.
#' @param P The parse state.
#' @return An integer, a double, or (a big integer kept as text) a string.
#' @noRd
.rmbl_jp_num <- function(P) {
  st <- P$i
  .rmbl_jp_int_part(P)
  isint <- !.rmbl_jp_frac_part(P)
  t0 <- paste(P$ch[st:(P$i - 1L)], collapse = "")
  v <- .rmbl_strtod(t0)
  if (!isint) {
    .rmbl_jp_check_whole(P, t0, v)
    return(v)
  }
  # fewer than 16 digits cannot pass 2^53: the digit checks are skipped (they
  # were a regex per number)
  if (nchar(t0) < 16L) {
    if (v > 2147483647 || v < -2147483647) {
      return(v)
    }
    return(as.integer(v))
  }
  .rmbl_jp_long_int(P, t0, v)
}

#' A number written with a fraction or an exponent that is a whole number in
#' the identifier range.
#'
#' "9007199254740993.0" and "9.007199254740993e15" write an integer in the
#' identifier range that the double does not hold: the digits written are
#' compared with the integer the double actually is. A value beyond 2^64
#' (1.7976931348623157e308) is a magnitude, not an identifier, and is left
#' alone.
#' @param P The parse state.
#' @param t0 The number as written.
#' @param v Its value.
#' @noRd
.rmbl_jp_check_whole <- function(P, t0, v) {
  if (
    P$bigint_warn &&
      !P$big_warned &&
      is.finite(v) &&
      v == trunc(v) &&
      abs(v) >= 9007199254740992 &&
      abs(v) < 18446744073709551616
  ) {
    written <- .rmbl_json_written_integer(t0)
    if (!is.null(written) && !identical(written, sprintf("%.0f", abs(v)))) {
      P$big_warned <- TRUE
      warning(
        sprintf(
          paste0(
            "number %s is a whole number beyond 2^53 and cannot be held ",
            "exactly in a double"
          ),
          t0
        ),
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}

#' An integer of 16 digits or more.
#' @param P The parse state.
#' @param t0 The integer as written.
#' @param v Its value as a double.
#' @return The double, or the text when big integers are kept as text.
#' @noRd
.rmbl_jp_long_int <- function(P, t0, v) {
  digs <- sub("^0+(?=[0-9])", "", sub("^-", "", t0), perl = TRUE)
  big <- nchar(digs) > 16L ||
    (nchar(digs) == 16L && digs > "9007199254740992")
  # inexact: the integer written is not the integer the double holds.
  # 9007199254740994 is beyond 2^53 and exact (even); 9007199254740993
  # is not. Only the second deserves a warning.
  inexact <- big &&
    is.finite(v) &&
    !identical(sprintf("%.0f", abs(v)), digs)
  if (big) {
    if (P$bigint_as_char) {
      return(t0)
    }
    if (!P$big_warned && P$bigint_warn && inexact) {
      P$big_warned <- TRUE
      warning(
        sprintf(
          paste0(
            "integer %s exceeds 2^53 and cannot be held exactly ",
            "in a double; pass bigint_as_char = TRUE to keep it as text"
          ),
          t0
        ),
        call. = FALSE
      )
    }
  }
  # sixteen digits or more without a leading zero is past the integer range
  v
}

#' Reads a value, one level deeper; the depth is put back on return. An error
#' ends the parse, so no exit handler (a cost per value).
#' @param P The parse state.
#' @return The value.
#' @noRd
.rmbl_jp_value <- function(P) {
  P$depth <- P$depth + 1L
  if (P$depth > 100L) {
    .rmbl_jp_bad(P, "nesting deeper than 100 levels")
  }
  v <- .rmbl_jp_value_(P)
  P$depth <- P$depth - 1L
  v
}

#' Reads a value at the cursor.
#' @param P The parse state.
#' @return The value.
#' @noRd
.rmbl_jp_value_ <- function(P) {
  .rmbl_jp_ws(P)
  if (P$i > P$n) {
    .rmbl_jp_bad(P, "unexpected end of input")
  }
  c0 <- P$ch[P$i]
  if (c0 == "{") {
    return(.rmbl_jp_object(P))
  }
  if (c0 == "[") {
    return(.rmbl_jp_array(P))
  }
  if (c0 == "\"") {
    return(.rmbl_jp_str(P))
  }
  if (c0 %in% c("t", "f", "n")) {
    for (lit in list(
      list("true", TRUE),
      list("false", FALSE),
      list("null", NULL)
    )) {
      w <- nchar(lit[[1L]])
      if (
        c0 == substr(lit[[1L]], 1L, 1L) &&
          P$i + w - 1L <= P$n &&
          identical(
            paste(P$ch[P$i:(P$i + w - 1L)], collapse = ""),
            lit[[1L]]
          )
      ) {
        P$i <- P$i + w
        return(lit[[2L]])
      }
    }
  }
  if (c0 == "-" || P$is_dig[P$i]) {
    return(.rmbl_jp_num(P))
  }
  .rmbl_jp_bad(P, "unexpected character")
}

#' Reads an object; the cursor is on its opening brace.
#' @param P The parse state.
#' @return A named list.
#' @noRd
.rmbl_jp_object <- function(P) {
  ch <- P$ch
  n <- P$n
  P$i <- P$i + 1L
  .rmbl_jp_ws(P)
  keys <- character(0)
  vals <- list()
  if (P$i <= n && ch[P$i] == "}") {
    P$i <- P$i + 1L
    return(structure(list(), names = character(0)))
  }
  repeat {
    .rmbl_jp_ws(P)
    if (P$i > n || ch[P$i] != "\"") {
      .rmbl_jp_bad(P, "expected a string key")
    }
    k <- .rmbl_jp_str(P)
    .rmbl_jp_ws(P)
    if (P$i > n || ch[P$i] != ":") {
      .rmbl_jp_bad(P, "expected ':'")
    }
    P$i <- P$i + 1L
    vals[[length(vals) + 1L]] <- list(.rmbl_jp_value(P))
    keys[[length(keys) + 1L]] <- k
    .rmbl_jp_ws(P)
    if (P$i <= n && ch[P$i] == ",") {
      P$i <- P$i + 1L
      next
    }
    if (P$i <= n && ch[P$i] == "}") {
      P$i <- P$i + 1L
      break
    }
    .rmbl_jp_bad(P, "expected ',' or '}'")
  }
  # two values under one key let a file show a reader one digest and
  # hand `$` another (the first); refuse unless asked to keep both
  if (P$duplicate_keys == "error" && anyDuplicated(keys)) {
    .rmbl_jp_bad(
      P,
      sprintf("duplicate key \"%s\"", keys[duplicated(keys)][1L])
    )
  }
  out <- lapply(vals, function(w) w[[1L]])
  names(out) <- keys
  out
}

#' Reads an array; the cursor is on its opening bracket.
#' @param P The parse state.
#' @return A list.
#' @noRd
.rmbl_jp_array <- function(P) {
  ch <- P$ch
  n <- P$n
  P$i <- P$i + 1L
  .rmbl_jp_ws(P)
  vals <- list()
  if (P$i <= n && ch[P$i] == "]") {
    P$i <- P$i + 1L
    return(list())
  }
  repeat {
    vals[[length(vals) + 1L]] <- list(.rmbl_jp_value(P))
    .rmbl_jp_ws(P)
    if (P$i <= n && ch[P$i] == ",") {
      P$i <- P$i + 1L
      next
    }
    if (P$i <= n && ch[P$i] == "]") {
      P$i <- P$i + 1L
      break
    }
    .rmbl_jp_bad(P, "expected ',' or ']'")
  }
  lapply(vals, function(w) w[[1L]])
}

#' The code point of a u escape's four characters, or NA unless they are four
#' hex digits.
#'
#' strtoi() alone took a space, a sign or \code{"0x"}: the escape \dQuote{u 041}
#' read as \code{"A"}, and \code{"u-041"} as NA, which became the key
#' \code{"NA"} (audit of 30bed8e, #12).
#' @param h The four characters, one per element.
#' @return An integer, or NA.
#' @noRd
.rmbl_json_hex4 <- function(h) {
  h <- paste(h, collapse = "")
  if (grepl("^[0-9A-Fa-f]{4}$", h)) strtoi(h, 16L) else NA_integer_
}

# ================================================================ simplify

#' Says whether a list is a list of records: unnamed, each element a named list
#' or NULL, at least one a list.
#' @param x The parsed value, tested for a list of records.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_recordlist <- function(x) {
  if (!(is.list(x) && is.null(names(x)) && length(x))) {
    return(FALSE)
  }
  # vectorised, with primitives only: a closure per element made fromjs() on
  # 20,000 sparse records eight times slower than jsonlite (audit of 30bed8e,
  # #17)
  named <- vapply(x, is.list, NA) & !vapply(lapply(x, names), is.null, NA)
  all(named | vapply(x, is.null, NA)) && any(named)
}
#' Says whether every element of a list is NULL or an atomic value of length at
#' most one.
#' @param x The parsed value, tested for a list of scalars.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_scalarlist <- function(x) {
  if (!is.list(x)) {
    return(FALSE)
  }
  all(vapply(x, is.null, NA) | (vapply(x, is.atomic, NA) & lengths(x) < 2L))
}
#' Turns NULL elements into NA, and the strings \code{"NA"}, \code{"NaN"},
#' \code{"Inf"} and \code{"-Inf"} into their values when no other string is
#' present.
#' @param x The parsed list whose NULLs become NA.
#' @return The list.
#' @noRd
.rmbl_json_null_to_na <- function(x) {
  if (!length(x)) {
    return(x)
  }
  x[vapply(x, is.null, NA)] <- list(NA)
  chr <- which(vapply(x, is.character, NA))
  if (!length(chr)) {
    return(x)
  }
  first <- vapply(x[chr], function(el) el[1L], "")
  special <- c("NA", "NaN", "Inf", "-Inf")
  if (!all(first %in% special)) {
    return(x)
  }
  x[chr] <- list(NA, NaN, Inf, -Inf)[match(first, special)]
  x
}
#' Says whether a list holds date-times, NULLs and \code{"NA"} strings only,
#' with at least one date-time.
#' @param x The parsed value, tested for a list of dates.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_datelist <- function(x) {
  if (!is.list(x) || !length(x)) {
    return(FALSE)
  }
  status <- FALSE
  for (el in x) {
    if (is.null(el)) {
      next
    }
    if (is.character(el) && length(el) && el[1L] == "NA") {
      next
    }
    # is.numeric() is FALSE for a POSIXct (it has an is.numeric method), so
    # the class alone decides
    if (inherits(el, "POSIXct")) status <- TRUE else return(FALSE)
  }
  status
}
#' Turns a list of scalars into a vector, keeping the date-time class.
#' @param x The parsed list to simplify to a vector.
#' @return An atomic vector.
#' @noRd
.rmbl_json_list_to_vec <- function(x) {
  isdates <- .rmbl_json_is_datelist(x)
  out <- unlist(.rmbl_json_null_to_na(x), recursive = FALSE, use.names = FALSE)
  if (isdates && is.numeric(out)) {
    structure(out, class = c("POSIXct", "POSIXt"))
  } else {
    out
  }
}
#' Says whether every element of a vector equals the first.
#' @param x The vector.
#' @return TRUE or FALSE; FALSE for an empty vector.
#' @noRd
.rmbl_json_all_identical <- function(x) length(x) > 0L && all(x == x[1L])
#' Turns a MongoDB `$date` value (milliseconds, or ISO 8601 text) into a
#' date-time.
#' @param x The parsed date: milliseconds, or an ISO 8601 string.
#' @return A POSIXct vector, or `x` when it is neither number nor text.
#' @noRd
.rmbl_json_parse_date <- function(x) {
  if (is.numeric(x)) {
    return(structure(x / 1000, class = c("POSIXct", "POSIXt")))
  }
  if (is.character(x)) {
    tz <- if (all(grepl("Z$", x))) "UTC" else ""
    return(as.POSIXct(strptime(x, format = "%Y-%m-%dT%H:%M:%OS", tz = tz)))
  }
  x
}

#' Simplifies parsed JSON into vectors, data frames and matrices, as jsonlite's
#' simplify() does.
#' @param x The parsed value.
#' @param simplifyVector Whether arrays of scalars become vectors.
#' @param simplifyDataFrame Whether arrays of records become data frames.
#' @param simplifyMatrix Whether arrays of equal-length vectors become matrices.
#' @param simplifyDate Whether `$date` objects become date-times.
#' @param homoList Whether empty elements of a list of vectors or data frames
#'   take their siblings' type.
#' @param flatten Whether nested data frames are flattened.
#' @param columnmajor Whether matrices are read by columns.
#' @param simplifySubMatrix Whether nested arrays become matrices.
#' @return The simplified value.
#' @noRd
.rmbl_json_simplify <- function(
  x,
  simplifyVector = TRUE,
  simplifyDataFrame = TRUE,
  simplifyMatrix = TRUE,
  simplifyDate = simplifyVector,
  homoList = TRUE,
  flatten = FALSE,
  columnmajor = FALSE,
  simplifySubMatrix = simplifyMatrix
) {
  if (!is.list(x) || !length(x)) {
    return(x)
  }
  if (isTRUE(simplifyDataFrame) && .rmbl_json_is_recordlist(x)) {
    return(.rmbl_json_simplify_records(
      x,
      simplifyDate,
      flatten,
      simplifySubMatrix
    ))
  }
  if (
    isTRUE(simplifyVector) && is.null(names(x)) && .rmbl_json_is_scalarlist(x)
  ) {
    return(.rmbl_json_list_to_vec(x))
  }
  out <- lapply(
    x,
    .rmbl_json_simplify,
    simplifyVector = simplifyVector,
    simplifyDataFrame = simplifyDataFrame,
    simplifyMatrix = simplifySubMatrix,
    columnmajor = columnmajor,
    flatten = flatten
  )
  if (isTRUE(simplifyVector) && .rmbl_json_all_posix(out)) {
    return(structure(
      .rmbl_json_list_to_vec(out),
      class = c("POSIXct", "POSIXt")
    ))
  }
  m <- .rmbl_json_simplify_matrix(
    x,
    out,
    simplifyMatrix,
    simplifyVector,
    columnmajor
  )
  if (!is.null(m)) {
    return(m)
  }
  .rmbl_json_simplify_rest(out, homoList, simplifyDate)
}

#' The last steps of .rmbl_json_simplify(): empty elements filled among
#' like ones, and a mongo date.
#' @param out The simplified elements.
#' @param homoList,simplifyDate As for .rmbl_json_simplify().
#' @return The simplified value.
#' @noRd
.rmbl_json_simplify_rest <- function(out, homoList, simplifyDate) {
  if (isTRUE(homoList) && is.null(names(out))) {
    filled <- .rmbl_json_fill_empty(out)
    if (!is.null(filled)) {
      return(filled)
    }
  }
  if (isTRUE(simplifyDate) && is.list(out) && .rmbl_json_is_date(out)) {
    return(.rmbl_json_parse_date(out[["$date"]]))
  }
  out
}

#' A list of records as a data frame, or a mongo date.
#' @param x The records.
#' @param simplifyDate,flatten,simplifySubMatrix As for
#'   .rmbl_json_simplify().
#' @return The data frame, or the dates.
#' @noRd
.rmbl_json_simplify_records <- function(
  x,
  simplifyDate,
  flatten,
  simplifySubMatrix
) {
  mydf <- .rmbl_json_simplify_df(
    x,
    flatten = flatten,
    simplifyMatrix = simplifySubMatrix
  )
  if (isTRUE(simplifyDate) && is.data.frame(mydf) && .rmbl_json_is_date(mydf)) {
    return(.rmbl_json_parse_date(mydf[["$date"]]))
  }
  mydf
}

#' Whether every element of a simplified list is one date-time.
#' @param out The elements.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_all_posix <- function(out) {
  .rmbl_json_is_scalarlist(out) &&
    length(out) &&
    all(vapply(out, inherits, logical(1), "POSIXt"))
}

#' Whether a simplified value is a mongo date: one field, "$date", of numbers
#' or text.
#' @param z A list or data frame.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_date <- function(z) {
  identical(names(z), "$date") &&
    (is.numeric(z[["$date"]]) || is.character(z[["$date"]]))
}

#' A list of simplified elements as a matrix or an array, when it is one.
#' @param x The list before simplification.
#' @param out Its simplified elements.
#' @param simplifyMatrix,simplifyVector,columnmajor As for
#'   .rmbl_json_simplify().
#' @return The matrix or array, or NULL.
#' @noRd
.rmbl_json_simplify_matrix <- function(
  x,
  out,
  simplifyMatrix,
  simplifyVector,
  columnmajor
) {
  if (
    isTRUE(simplifyMatrix) &&
      isTRUE(simplifyVector) &&
      .rmbl_json_is_matrixlist(out) &&
      all(vapply(x, .rmbl_json_is_scalarlist, logical(1)))
  ) {
    return(
      if (isTRUE(columnmajor)) do.call(cbind, out) else do.call(rbind, out)
    )
  }
  if (isTRUE(simplifyMatrix) && .rmbl_json_is_arraylist(out)) {
    if (isTRUE(columnmajor)) {
      return(array(do.call(cbind, out), dim = c(dim(out[[1L]]), length(out))))
    }
    return(array(
      do.call(rbind, lapply(out, as.vector)),
      dim = c(length(out), dim(out[[1L]]))
    ))
  }
  NULL
}

#' An unnamed list whose empty elements stand among data frames, or among
#' atomic vectors: each empty element becomes an empty value of their kind.
#' @param out The simplified elements.
#' @return The list with its empty elements filled, or NULL when it is not
#'   such a list.
#' @noRd
.rmbl_json_fill_empty <- function(out) {
  isempty <- vapply(out, identical, logical(1), list())
  if (!any(isempty) || all(isempty)) {
    return(NULL)
  }
  if (all(vapply(out[!isempty], is.data.frame, logical(1)))) {
    for (i in which(isempty)) {
      out[[i]] <- data.frame()
    }
    return(out)
  }
  if (
    all(vapply(
      out[!isempty],
      function(z) isTRUE(is.vector(z) && is.atomic(z)),
      logical(1)
    ))
  ) {
    for (i in which(isempty)) {
      out[[i]] <- vector(mode = typeof(out[[which(!isempty)[1L]]]))
    }
    return(out)
  }
  NULL
}
#' Says whether a list is unnamed and holds atomic vectors of one length.
#' @param x The parsed value, tested for a list of equal-length vectors.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_matrixlist <- function(x) {
  isTRUE(
    is.list(x) &&
      length(x) &&
      is.null(names(x)) &&
      all(vapply(x, is.atomic, logical(1))) &&
      .rmbl_json_all_identical(vapply(x, length, integer(1)))
  )
}
#' Says whether a list is unnamed and holds arrays of one shape.
#' @param x The parsed value, tested for a list of arrays.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_arraylist <- function(x) {
  isTRUE(
    is.list(x) &&
      length(x) &&
      is.null(names(x)) &&
      all(vapply(x, is.array, logical(1))) &&
      .rmbl_json_all_identical(vapply(
        x,
        function(y) paste(dim(y), collapse = "-"),
        character(1)
      ))
  )
}
#' Turns a list of records into a data frame, as jsonlite's simplifyDataFrame()
#' does.
#' @param recordlist The list of records.
#' @param columns The column names; when NULL (the default), every name that
#'   occurs in a record.
#' @param flatten Whether nested data frames are flattened.
#' @param simplifyMatrix Whether nested arrays become matrices.
#' @return A data frame.
#' @noRd
.rmbl_json_simplify_df <- function(
  recordlist,
  columns = NULL,
  flatten,
  simplifyMatrix
) {
  empty <- .rmbl_json_simplify_df_empty(recordlist, columns)
  if (!is.null(empty)) {
    return(empty)
  }
  if (is.null(columns)) {
    columns <- unique(unlist(
      lapply(recordlist, names),
      recursive = FALSE,
      use.names = FALSE
    ))
  }
  columnlist <- .rmbl_json_df_columns(
    recordlist,
    columns,
    flatten,
    simplifyMatrix
  )
  lens <- vapply(
    columnlist,
    function(z) if (length(dim(z)) > 1L) nrow(z) else length(z),
    integer(1)
  )
  n <- unique(lens)
  if (length(n) > 1L) {
    stop(
      "Elements not of equal length: ",
      paste(lens, collapse = " "),
      call. = FALSE
    )
  }
  names(columnlist) <- columns
  if (isTRUE(flatten)) {
    dfcols <- vapply(columnlist, is.data.frame, logical(1))
    if (any(dfcols)) {
      columnlist <- c(columnlist[!dfcols], do.call(c, columnlist[dfcols]))
    }
  }
  class(columnlist) <- "data.frame"
  .rmbl_json_df_rownames(columnlist, n)
}

#' The data frame for a list of records with no values, as
#' simplifyDataFrame() makes it.
#' @param recordlist The list of records.
#' @param columns The column names, or NULL.
#' @return A data frame with no rows or no columns, or NULL when the records
#'   hold values.
#' @noRd
.rmbl_json_simplify_df_empty <- function(recordlist, columns) {
  if (!length(recordlist)) {
    if (!is.null(columns)) {
      return(as.data.frame(matrix(
        ncol = length(columns),
        nrow = 0,
        dimnames = list(NULL, columns)
      )))
    }
    return(data.frame())
  }
  if (
    !any(vapply(recordlist, length, integer(1), USE.NAMES = FALSE)) &&
      is.null(columns)
  ) {
    return(data.frame(matrix(nrow = length(recordlist), ncol = 0)))
  }
  NULL
}

#' The columns of a list of records, each simplified.
#' @param recordlist The list of records.
#' @param columns The column names.
#' @param flatten,simplifyMatrix As for .rmbl_json_simplify_df().
#' @return A list of columns, one per name in `columns`.
#' @noRd
.rmbl_json_df_columns <- function(
  recordlist,
  columns,
  flatten,
  simplifyMatrix
) {
  # each column from the records' values laid end to end, the first value of a
  # repeated key: a match() per record and column was the hot loop on sparse
  # records (audit of 30bed8e, #17)
  keys <- lapply(recordlist, names)
  rid <- rep.int(seq_along(recordlist), lengths(keys))
  keys <- unlist(keys, use.names = FALSE)
  vals <- unlist(recordlist, recursive = FALSE, use.names = FALSE)
  lapply(columns, function(nm) {
    at <- which(keys == nm)
    at <- at[!duplicated(rid[at])]
    pv <- vals[at]
    # a column of scalars and nulls (the usual case) is a vector at once, its
    # missing cells NA: what .rmbl_json_simplify() makes of it, without a call
    # per cell. "NA", "Inf" and the like go the long way, which decides whether
    # they are numbers.
    len <- lengths(pv)
    one <- len == 1L
    u <- if (all(len <= 1L) && all(vapply(pv[!one], is.null, NA))) {
      unlist(pv[one], recursive = FALSE, use.names = FALSE)
    }
    if (
      is.atomic(u) &&
        !(is.character(u) && any(u %in% c("NA", "NaN", "Inf", "-Inf")))
    ) {
      col <- rep(NA, length(recordlist))
      col[rid[at][one]] <- u
      return(col)
    }
    col <- vector("list", length(recordlist))
    col[rid[at]] <- pv
    .rmbl_json_simplify(
      col,
      simplifyVector = TRUE,
      simplifyDataFrame = TRUE,
      simplifyMatrix = FALSE,
      simplifySubMatrix = simplifyMatrix,
      flatten = flatten
    )
  })
}

#' Sets a simplified data frame's row names, from its `_row` column when it
#' has one.
#' @param columnlist The data frame.
#' @param n The number of rows of `columnlist`.
#' @return The data frame, `_row` removed.
#' @noRd
.rmbl_json_df_rownames <- function(columnlist, n) {
  if ("_row" %in% names(columnlist)) {
    rn <- columnlist[["_row"]]
    columnlist["_row"] <- NULL
    if (is.double(rn)) {
      rn <- as.integer(rn)
    }
    rn_na <- is.na(rn)
    if (sum(rn_na) > 0L) {
      rn[rn_na] <- paste0("NA_", seq_len(sum(rn_na)))
    }
    if (anyDuplicated(rn) > 0L) {
      warning(
        'Duplicate names in "_row" field. Data frames must have unique ',
        'row names.',
        call. = FALSE
      )
      if (is.character(rn)) {
        row.names(columnlist) <- make.unique(rn)
      } else {
        row.names(columnlist) <- seq_len(n)
      }
    } else {
      row.names(columnlist) <- rn
    }
  } else {
    row.names(columnlist) <- seq_len(n)
  }
  columnlist
}


#' The JSON text fromjs() was given: a string as it is, or the lines of a
#' file, a connection or a URL.
#' @param txt A JSON string, a file path, a URL or a connection.
#' @return A character vector of JSON text.
#' @noRd
.rmbl_json_read_input <- function(txt) {
  if (!is.character(txt) && !inherits(txt, "connection")) {
    stop("Argument 'txt' must be a JSON string, URL or file.", call. = FALSE)
  }
  if (is.character(txt) && anyNA(txt)) {
    stop("Argument 'txt' must be a JSON string, not NA.", call. = FALSE)
  }
  if (.rmbl_json_is_location(txt)) {
    if (grepl("^https?://", txt, useBytes = TRUE)) {
      return(.rmbl_json_fetch_url(txt))
    }
    if (file.exists(txt)) {
      txt <- file(txt)
    }
  }
  if (inherits(txt, "connection")) {
    return(.rmbl_json_read_con(txt))
  }
  txt
}

#' Whether a string could be a file path or URL rather than JSON text.
#' @param txt The `txt` argument of fromjs().
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_location <- function(txt) {
  is.character(txt) &&
    length(txt) == 1L &&
    nchar(txt, type = "bytes") < 2084 &&
    !bricklayer_json_validate(txt)
}

#' Reads every line of a connection, opening (and then closing) it when it
#' is not open.
#' @param con The connection to read the JSON text from.
#' @return A character vector, one element per line.
#' @noRd
.rmbl_json_read_con <- function(con) {
  if (!isOpen(con)) {
    open(con, "rb")
    on.exit(close(con), add = TRUE)
  }
  readLines(con, warn = FALSE, encoding = "UTF-8")
}

#' Downloads a JSON document through the package's checked transport.
#' @param txt The URL.
#' @return A character vector, one element per line of the reply.
#' @noRd
.rmbl_json_fetch_url <- function(txt) {
  # the same gate and the same transport as every other fetch: base R's
  # url() connected to 127.0.0.1 when asked (0.5.7 review)
  txt <- .rmbl_check_public_url(txt, "txt")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  res <- .bl_net(
    txt,
    .bl_http_download(
      txt,
      tmp,
      60L,
      "Accept: application/json, text/*, */*",
      NULL,
      16777216,
      FALSE
    )
  ) # 16 MiB is a large JSON
  if (res$status < 0) {
    stop(sprintf("fromjs: %s: %s", txt, res$error), call. = FALSE)
  }
  if (res$status >= 400) {
    stop(
      sprintf("fromjs: %s answered HTTP %d", txt, res$status),
      call. = FALSE
    )
  }
  .rmbl_json_read_con(file(tmp))
}

#' Says whether a string starts with the UTF-8 byte-order mark.
#'
#' A byte-order mark is three bytes; test and strip it on the bytes so a
#' C locale never has to translate U+FEFF to its native encoding (that
#' translation is what raised \dQuote{unable to translate '<U+FEFF>...'} and
#' \dQuote{invalid char string in output conversion}).
#' @param s One string.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_has_bom <- function(s) {
  r <- charToRaw(s)
  length(r) >= 3L && identical(r[1:3], as.raw(c(0xef, 0xbb, 0xbf)))
}
#' Removes a UTF-8 byte-order mark from the start of a string.
#' @param s One string.
#' @return The string without the mark, marked UTF-8.
#' @noRd
.rmbl_strip_bom <- function(s) {
  if (!.rmbl_has_bom(s)) {
    return(s)
  }
  out <- rawToChar(charToRaw(s)[-(1:3)])
  Encoding(out) <- "UTF-8"
  out
}

#' Validate JSON text
#'
#' @param txt character; lines are joined with newlines.
#' @return `TRUE`, or `FALSE` with attributes `err` and
#' `offset`.
#' @noRd
bricklayer_json_validate <- function(txt) {
  stopifnot(is.character(txt))
  txt <- paste(txt, collapse = "\n")
  if (.rmbl_has_bom(txt)) {
    return(structure(FALSE, err = "JSON string contains UTF8 byte-order-mark."))
  }
  res <- tryCatch(
    {
      .rmbl_json_parse(txt, bigint_warn = FALSE)
      TRUE
    },
    error = function(e) e
  )
  if (isTRUE(res)) {
    return(TRUE)
  }
  off <- suppressWarnings(as.integer(sub(
    ".* at character ([0-9]+)$",
    "\\1",
    conditionMessage(res)
  )))
  structure(
    FALSE,
    offset = if (is.na(off)) NA_integer_ else off,
    err = conditionMessage(res)
  )
}

# ================================================================ text tools

# ================================================================ streaming

# ================================================================ serialize

#' Turns an R object into the list `jsser()` writes: its type, attributes and
#' value.
#' @param obj The object.
#' @return A list with `type`, `attributes` and `value`.
#' @noRd
.rmbl_json_pack <- function(obj) {
  mode <- typeof(obj)
  if (mode == "NULL") {
    return(list(type = bricklayer_json_unbox("NULL")))
  }
  if (mode == "closure") {
    obj <- as.list(obj)
  }
  if (mode == "environment" && isNamespace(obj)) {
    mode <- "namespace"
  }
  attrib <- attributes(obj)
  if (isS4(obj)) {
    mode <- "S4"
    sn <- methods::slotNames(obj)
    if (".Data" %in% sn) {
      attrib[[".Data"]] <- obj@.Data
    }
    attrib <- attrib[sn]
    names(attrib) <- sn
  }
  value <- .rmbl_json_pack_value(obj, mode)
  list(
    type = bricklayer_json_unbox(mode),
    attributes = structure(
      lapply(attrib, .rmbl_json_pack),
      names = as.character(names(attrib))
    ),
    value = value
  )
}
#' The `value` part of the list `jsser()` writes, by storage mode.
#' @param obj The object.
#' @param mode Its storage mode, or "namespace" / "S4".
#' @return The encoded value, or NULL for a mode with no value.
#' @noRd
.rmbl_json_pack_value <- function(obj, mode) {
  switch(
    mode,
    environment = NULL,
    externalptr = NULL,
    namespace = lapply(
      as.list(getNamespaceInfo(obj, "spec")),
      bricklayer_json_unbox
    ),
    S4 = list(
      class = bricklayer_json_unbox(class(obj)),
      package = bricklayer_json_unbox(attr(class(obj), "package"))
    ),
    raw = bricklayer_json_unbox(jsb64enc(unclass(obj))),
    logical = as.vector(unclass(obj), mode = "logical"),
    integer = as.vector(unclass(obj), mode = "integer"),
    numeric = ,
    double = as.vector(unclass(obj), mode = "double"),
    character = as.vector(unclass(obj), mode = "character"),
    complex = as.vector(unclass(obj), mode = "complex"),
    list = unname(lapply(unclass(obj), .rmbl_json_pack)),
    pairlist = unname(lapply(as.vector(obj, mode = "list"), .rmbl_json_pack)),
    closure = unname(lapply(obj, .rmbl_json_pack)),
    builtin = ,
    special = bricklayer_json_unbox(jsb64enc(serialize(unclass(obj), NULL))),
    language = ,
    name = ,
    symbol = deparse(unclass(obj)),
    expression = deparse(obj[[1L]]),
    {
      warning(
        "No encoding has been defined for objects with storage mode ",
        mode,
        " and will be skipped."
      )
      NULL
    }
  )
}
#' Rebuilds an R object from the list `jsser()` wrote.
#' @param obj The list, as parsed.
#' @param trusted Whether code-bearing types (functions, calls, namespaces, S4
#'   objects) may be rebuilt.
#' @return The object.
#' @noRd
.rmbl_json_unpack <- function(obj, trusted = FALSE) {
  mode <- obj$type
  if (identical(mode, "NULL")) {
    return(NULL)
  }
  .rmbl_json_unpack_guard(mode, trusted)
  if (identical(mode, "S4")) {
    data <- lapply(obj$attributes, .rmbl_json_unpack, trusted = trusted)
    return(do.call(methods::new, c(Class = obj$value$class, data)))
  }
  newdata <- .rmbl_json_unpack_data(obj, mode, trusted)
  # a missing formal comes back as the empty symbol; it must not be evaluated
  if (identical(newdata[[1L]], substitute())) {
    return(substitute())
  }
  attrs <- lapply(obj$attributes, .rmbl_json_unpack, trusted = trusted)
  output <- do.call("structure", c(newdata, attrs), quote = TRUE)
  if (mode == "closure") {
    f <- as.function(output)
    environment(f) <- globalenv()
    return(f)
  }
  if (mode == "pairlist") {
    return(as.pairlist(output))
  }
  output
}

#' Refuses the code-bearing types of the list `jsser()` wrote unless the JSON
#' is trusted.
#' @param mode The type the JSON names.
#' @param trusted Whether code-bearing types may be rebuilt.
#' @return NULL, invisibly; an error for a refused type.
#' @noRd
.rmbl_json_unpack_guard <- function(mode, trusted) {
  # unserialize() on supplied bytes, parse() on supplied text,
  # getNamespace() (which runs a package's .onLoad) and an S4 initialize
  # method all execute code the JSON's author chose: untrusted JSON gets
  # data types only
  if (
    !isTRUE(trusted) &&
      mode %in%
        c(
          "S4",
          "namespace",
          "closure",
          "special",
          "builtin",
          "language",
          "expression"
        )
  ) {
    stop(
      sprintf(
        paste0(
          "jsunser() refuses to rebuild a '%s' ",
          "from JSON it did not write: that would run code chosen ",
          "by the file's author. Pass trusted = TRUE only for JSON ",
          "produced by jsser() in your own session."
        ),
        mode
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' The `.Data` of an object rebuilt from the list `jsser()` wrote.
#' @param obj The list, as parsed.
#' @param mode The type it names.
#' @param trusted As for .rmbl_json_unpack().
#' @return A list of one element, `.Data`.
#' @noRd
.rmbl_json_unpack_data <- function(obj, mode, trusted) {
  vals <- obj$value
  list(
    .Data = switch(
      mode,
      environment = new.env(parent = emptyenv()),
      namespace = getNamespace(obj$value$name),
      externalptr = NULL,
      raw = jsb64dec(vals),
      logical = as.logical(.rmbl_json_list_to_vec(vals)),
      integer = as.integer(.rmbl_json_list_to_vec(vals)),
      numeric = ,
      double = as.double(.rmbl_json_list_to_vec(vals)),
      character = as.character(.rmbl_json_list_to_vec(vals)),
      complex = as.complex(.rmbl_json_list_to_vec(vals)),
      list = ,
      pairlist = ,
      closure = lapply(vals, .rmbl_json_unpack, trusted = trusted),
      symbol = ,
      name = if (identical(unlist(vals), "")) {
        quote(expr = )
      } else {
        as.name(unlist(vals))
      },
      expression = parse(text = unlist(vals)),
      language = as.call(parse(text = unlist(vals)))[[1L]],
      special = ,
      builtin = unserialize(jsb64dec(vals)),
      stop("Switch falling through for encode.mode: ", mode, call. = FALSE)
    )
  )
}


#' Writes the integer a decimal literal stands for.
#'
#' The integer a decimal literal writes, as a digit string with no leading
#' zeros; NULL when the literal has a non-zero fractional part.
#' @param t0 The literal, as text.
#' @return A digit string, or NULL.
#' @noRd
.rmbl_json_written_integer <- function(t0) {
  t <- sub("^[-+]", "", t0)
  parts <- strsplit(t, "[eE]")[[1L]]
  mant <- parts[1L]
  e <- if (length(parts) > 1L) suppressWarnings(as.integer(parts[2L])) else 0L
  if (is.na(e)) {
    return(NULL)
  }
  mp <- strsplit(mant, ".", fixed = TRUE)[[1L]]
  digits <- paste(mp, collapse = "")
  frac <- if (length(mp) > 1L) nchar(mp[2L]) else 0L
  scale <- e - frac
  if (scale >= 0L) {
    digits <- paste0(digits, strrep("0", scale))
  } else {
    cut <- substr(digits, nchar(digits) + scale + 1L, nchar(digits))
    if (grepl("[1-9]", cut)) {
      return(NULL)
    }
    digits <- substr(digits, 1L, nchar(digits) + scale)
  }
  digits <- sub("^0+", "", digits)
  if (nzchar(digits)) digits else "0"
}

#' Refuses `=` padding anywhere but the end of base64 text.
#'
#' Padding ends an encoding; inside the text it means two encodings were joined
#' (\code{c("YQ==", "Yg==")}) and decoding across it gives bytes neither holds.
#' @param s The base64 text, one string.
#' @return NULL, invisibly.
#' @noRd
.rmbl_b64_padding <- function(s) {
  s <- gsub("[[:space:]]", "", s)
  if (grepl("=[^=]", s) || grepl("===", s, fixed = TRUE)) {
    stop(
      "jsb64dec: `input` has `=` padding before its end; decode each ",
      "encoding on its own",
      call. = FALSE
    )
  }
  invisible(NULL)
}
