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

#' Format doubles and integers the way jsonlite's num_to_char() does
#'
#' `digits` is decimal places (jsonlite default 4), `I(n)` means
#' n significant digits, `NA` means 15 significant digits. Non-finite
#' values become "NA"/"NaN"/"Inf"/"-Inf" strings, null, or NA_character_
#' (dropped later) depending on `na_as_string`.
#' @param x A double or integer vector.
#' @param digits Decimal places, `I(n)` for n significant digits, NA for 15 significant digits, NULL for full precision.
#' @param na_as_string TRUE to write non-finite values as strings, FALSE to write them as null, NA to leave them
#'   missing.
#' @param use_signif Whether `digits` counts significant digits.
#' @param always_decimal Whether a whole number is written with ".0".
#' @return A character vector, one element per value.
#' @noRd
.rmbl_json_num_to_char <- function(x, digits = 4, na_as_string = NA,
                                use_signif = FALSE, always_decimal = FALSE) {
  n <- length(x)
  out <- character(n)
  if (is.integer(x)) {
    ok <- !is.na(x)
    out[ok] <- as.character(x[ok])
    out[!ok] <- if (is.na(na_as_string)) NA_character_
                else if (na_as_string) "\"NA\"" else "null"
    return(out)
  }
  # digits = NULL is this codec's own extension: full precision (%.17g), the
  # setting the package's internal JSON round trips rely on
  if (is.null(digits)) {
    digits <- 17L
    use_signif <- TRUE
  }
  precision <- if (is.na(digits)) NA_integer_ else as.integer(digits)
  sig_digits <- if (isTRUE(use_signif) && !is.na(precision)) ceiling(min(17, precision)) else 0L
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
      out[i] <- if (is.na(na_as_string)) {
        NA_character_
      } else if (na_as_string) {
        if (is.na(val) && !is.nan(val)) "\"NA\""
        else if (is.nan(val)) "\"NaN\""
        else if (val > 0) "\"Inf\"" else "\"-Inf\""
      } else {
        "null"
      }
      next
    }
    buf <- if (is.na(precision)) {
      sprintf("%.15g", val)
    } else if (isTRUE(use_signif)) {
      if (!is.null(full17)) full17[i]
      else sprintf("%.*g", as.integer(sig_digits), val)
    } else if (precision > -1L && precision < 10L && abs(val) < 2147483647 &&
               abs(val) > 1e-5) {
      .rmbl_json_dtoa2(val, precision)
    } else {
      decimals <- ceiling(min(17, max(1, log10(abs(val))) + precision))
      sprintf("%.*g", as.integer(decimals), val)
    }
    if (isTRUE(always_decimal) && grepl("^[0-9-]+$", buf)) buf <- paste0(buf, ".0")
    out[i] <- buf
  }
  out
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
  if (neg) value <- -value
  whole <- trunc(value)
  tmp <- (value - whole) * p10
  frac <- trunc(tmp)
  diff <- tmp - frac
  if (diff > 0.5) {
    frac <- frac + 1
    if (frac >= p10) {
      frac <- 0
      whole <- whole + 1
    }
  } else if (diff == 0.5 && prec > 0L && (frac %% 2 == 1)) {
    frac <- frac + 1
    if (frac >= p10) {
      frac <- 0
      whole <- whole + 1
    }
  } else if (diff == 0.5 && prec == 0L && (whole %% 2 == 1)) {
    frac <- frac + 1
    if (frac >= p10) {
      frac <- 0
      whole <- whole + 1
    }
  }
  if (value > 2147483647) return(sprintf("%e", if (neg) -value else value))
  count <- prec
  if (prec > 0L) while (count > 0L && (frac %% 10 == 0)) {
    count <- count - 1L
    frac <- frac %/% 10
  }
  digs <- character(0)
  while (count > 0L) {
    count <- count - 1L
    digs <- c(as.character(frac %% 10), digs)
    frac <- frac %/% 10
  }
  s <- sprintf("%.0f", whole)
  if (length(digs)) s <- paste0(s, ".", paste(digs, collapse = ""))
  if (neg) s <- paste0("-", s)
  s
}

# ================================================================ strings

#' Escape a character vector as JSON string literals (jsonlite's
#' C_escape_chars)
#' @param x A character vector.
#' @return The escaped strings, each in double quotes.
#' @noRd
.rmbl_json_esc <- function(x) {
  if (!length(x)) return(character(0))
  x <- enc2utf8(x)
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
    if (any(hit)) x[hit] <- gsub(ch, sprintf("\\u%04x", cc), x[hit], fixed = TRUE, useBytes = TRUE)
  }
  paste0("\"", x, "\"")
}

# ================================================================ base64

.RMBL_JSON_B64 <- strsplit(paste0("ABCDEFGHIJKLMNOPQRSTUVWXYZ",
                               "abcdefghijklmnopqrstuvwxyz",
                               "0123456789+/"), "")[[1]]

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
#' @examples
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
  if (is.null(input)) return(NA_character_)
  if (is.character(input)) input <- charToRaw(paste(input, collapse = "\n"))
  if (!is.raw(input)) stop("`input` must be a raw vector or text", call. = FALSE)
  b <- as.integer(input)
  n <- length(b)
  if (!n) return("")
  pad <- (3L - n %% 3L) %% 3L
  b <- c(b, integer(pad))
  m <- matrix(b, nrow = 3L)
  v <- m[1L, ] * 65536L + m[2L, ] * 256L + m[3L, ]
  chars <- rbind(.RMBL_JSON_B64[v %/% 262144L %% 64L + 1L],
                 .RMBL_JSON_B64[v %/% 4096L %% 64L + 1L],
                 .RMBL_JSON_B64[v %/% 64L %% 64L + 1L],
                 .RMBL_JSON_B64[v %% 64L + 1L])
  out <- paste(as.vector(chars), collapse = "")
  if (pad) substr(out, nchar(out) - pad + 1L, nchar(out)) <- strrep("=", pad)
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
  if (is.character(input)) input <- charToRaw(paste(input, collapse = "\n"))
  if (!is.raw(input)) stop("`input` must be a raw vector or text", call. = FALSE)
  s <- rawToChar(input)
  # whitespace and padding may be dropped; anything else is not base64, and
  # deleting it would decode a corrupt body into a shorter valid-looking one
  if (grepl("[^A-Za-z0-9+/=[:space:]]", s)) {
    stop("base64 input contains characters outside the alphabet", call. = FALSE)
  }
  ch <- strsplit(gsub("[^A-Za-z0-9+/]", "", s), "")[[1]]
  if (!length(ch)) return(raw(0))
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
    w <- v[nfull * 4L + 1L] * 262144L + v[nfull * 4L + 2L] * 4096L + v[nfull * 4L + 3L] * 64L
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
  if (!is.character(input) || anyNA(input)) stop("`input` must be base64url text", call. = FALSE)
  if (any(grepl("[^A-Za-z0-9_=-]", gsub("[\r\n]", "", input)))) {
    stop("`input` is not base64url text", call. = FALSE)
  }
  if (!length(input)) return(jsb64dec(input))
  text <- paste(gsub("[\r\n]", "", chartr("-_", "+/", input)), collapse = "")
  mod <- nchar(text) %% 4L
  if (mod > 0L) text <- paste0(text, strrep("=", 4L - mod))
  jsb64dec(text)
}

# ================================================================ collapse

# jsonlite's C collapse helpers. `indent` is NA for compact output, else an
# integer with attribute indent_spaces (negative = tabs).
#' Turns the `pretty` argument into the indent the collapse helpers take.
#' @param pretty FALSE, TRUE (two spaces) or a number of spaces.
#' @return NA for compact output, else 0 with attribute `indent_spaces`.
#' @noRd
.rmbl_json_indent_init <- function(pretty) {
  if (isTRUE(pretty)) pretty <- 2L
  if (is.numeric(pretty)) {
    if (length(pretty) != 1L || is.na(pretty) || abs(pretty) >= 20) {
      stop("`pretty` must be TRUE, FALSE or one number of spaces below 20", call. = FALSE)
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
  if (length(sp)) structure(indent + abs(sp), indent_spaces = sp) else NA_integer_
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
  if (is.na(indent)) return(paste0("[", paste(x, collapse = ","), "]"))
  if (isTRUE(inner)) return(paste0("[", paste(x, collapse = ", "), "]"))
  if (!length(x)) return("[]")
  ni <- as.integer(indent)
  sp <- abs(attr(indent, "indent_spaces"))
  paste0("[\n", paste0(.rmbl_json_ws(ni + sp, indent), x, collapse = ",\n"),
         "\n", .rmbl_json_ws(ni, indent), "]")
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
  if (!length(vals)) return("{}")
  if (is.na(indent)) return(paste0("{", paste0(keys, ":", vals, collapse = ","), "}"))
  ni <- as.integer(indent)
  sp <- abs(attr(indent, "indent_spaces"))
  paste0("{\n", paste0(.rmbl_json_ws(ni + sp, indent), keys, ": ", vals, collapse = ",\n"),
         "\n", .rmbl_json_ws(ni, indent), "}")
}
#' Collapses each row of a matrix of encoded values into a JSON array.
#' @param m The matrix.
#' @param indent The indent, NA for compact output.
#' @return A character vector, one array per row.
#' @noRd
.rmbl_json_row_collapse <- function(m, indent = NA_integer_) {
  vapply(seq_len(nrow(m)), function(i) .rmbl_json_collapse(m[i, ], inner = TRUE, indent = indent),
         character(1))
}
#' Collapses each row of a matrix of encoded values into a JSON object.
#' @param keys The encoded keys, one per column.
#' @param m The matrix.
#' @param indent The indent, NA for compact output.
#' @return A character vector, one object per row.
#' @noRd
.rmbl_json_row_collapse_object <- function(keys, m, indent = NA_integer_) {
  vapply(seq_len(nrow(m)), function(i) .rmbl_json_collapse_object(keys, m[i, ], indent),
         character(1))
}
#' Makes names usable as JSON keys: an empty one becomes its position, duplicates are made unique.
#' @param nms The names.
#' @param no_dots Whether dots are replaced by underscores.
#' @return The cleaned names.
#' @noRd
.rmbl_json_cleannames <- function(nms, no_dots = FALSE) {
  nms[nms == ""] <- NA_character_
  miss <- is.na(nms)
  nms[miss] <- as.character(seq_along(nms))[miss]
  if (isTRUE(no_dots)) nms <- gsub(".", "_", nms, fixed = TRUE)
  make.unique(nms)
}

# ================================================================ encoder

#' Encodes an R object as JSON text.
#'
#' The encoder is jsonlite's asJSON generic, one branch per class, with the
#' same argument threading (na / oldna / collapse / auto_unbox / indent).
#' @param x The object.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether a vector is collapsed into one array.
#' @param na How missing values are written, or NULL for the type's default.
#' @param oldna The `na` setting passed down to nested values.
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @param is_df Whether `x` is a data frame's column list.
#' @param keep_vec_names Whether a named vector is written as an object.
#' @return The JSON text, or a character vector of encoded elements when `collapse` is FALSE.
#' @noRd
.rmbl_json_as <- function(x, o, collapse = TRUE, na = NULL, oldna = NULL,
                       auto_unbox = o$auto_unbox, indent = o$indent,
                       is_df = FALSE, keep_vec_names = o$keep_vec_names) {
  cls <- class(x)
  if (inherits(x, "scalar")) {
    y <- x
    if (length(cls) > 1L) class(y) <- cls[-1L] else y <- unclass(y)
    return(.rmbl_json_as(y, o, collapse = FALSE, na = na, oldna = oldna,
                      auto_unbox = auto_unbox, indent = indent))
  }
  if (inherits(x, "json")) {
    if (isTRUE(o$json_verbatim)) return(as.character(x))
    return(.rmbl_json_as(as.character(x), o, collapse, na, oldna, auto_unbox, indent))
  }
  if (inherits(x, "AsIs") && !is.data.frame(x)) {
    class(x) <- setdiff(cls, "AsIs")
    if (is.atomic(x) && length(x) == 1L) auto_unbox <- FALSE
    return(.rmbl_json_as(x, o, collapse, na, oldna, auto_unbox, indent))
  }
  if (is.data.frame(x))
    return(.rmbl_json_as_df(x, o, collapse, na, oldna, indent, keep_vec_names))
  if (is.factor(x)) {
    if (identical(o$factor, "integer"))
      return(.rmbl_json_as(unclass(x), o, collapse, na, oldna, auto_unbox, indent))
    xc <- as.character(x)
    if (isTRUE(keep_vec_names)) names(xc) <- names(x)
    return(.rmbl_json_as(xc, o, collapse, na, oldna, auto_unbox, indent, keep_vec_names = keep_vec_names))
  }
  if (inherits(x, "Date")) {
    out <- if (identical(o$Date, "epoch")) unclass(x) else format(x)
    o$always_decimal <- FALSE
    return(.rmbl_json_as(out, o, collapse, na, oldna, auto_unbox, indent))
  }
  if (inherits(x, "POSIXt")) {
    if (identical(o$POSIXt, "mongo")) {
      if (inherits(x, "POSIXlt")) x <- as.POSIXct(x)
      df <- data.frame("$date" = floor(unclass(x) * 1000), check.names = FALSE)
      o2 <- o
      o2$digits <- NA
      o2$always_decimal <- FALSE
      tmp <- .rmbl_json_as(df, o2, collapse = FALSE, na = na, oldna = oldna, indent = NA_integer_)
      tmp[is.na(x)] <- .rmbl_json_as(NA_character_, o, collapse = FALSE, na = na)
      return(if (isTRUE(collapse)) .rmbl_json_collapse(tmp, inner = FALSE, indent = indent) else tmp)
    }
    if (identical(o$POSIXt, "epoch")) {
      o2 <- o
      o2$always_decimal <- FALSE
      return(.rmbl_json_as(floor(unclass(as.POSIXct(x)) * 1000), o2, collapse, na, oldna, auto_unbox, indent))
    }
    fmt <- o$time_format
    if (is.null(fmt)) fmt <- if (identical(o$POSIXt, "string")) "" else if (isTRUE(o$UTC)) "%Y-%m-%dT%H:%M:%SZ" else "%Y-%m-%dT%H:%M:%S"
    s <- if (isTRUE(o$UTC)) format(x, format = fmt, tz = "UTC") else format(x, format = fmt)
    return(.rmbl_json_as(s, o, collapse, na, oldna, auto_unbox, indent))
  }
  if (inherits(x, "ts")) return(.rmbl_json_as(as.vector(x), o, collapse, na, oldna, auto_unbox, indent))
  if (inherits(x, "hms")) {
    out <- if (identical(o$hms, "secs")) as.numeric(x, units = "secs") else as.character(x)
    out[is.na(x)] <- NA
    return(.rmbl_json_as(out, o, collapse, na, oldna, auto_unbox, indent))
  }
  if (inherits(x, "blob")) {
    if (identical(o$raw, "base64")) {
      str <- vapply(x, jsb64enc, character(1))
      return(.rmbl_json_as(str, o, collapse, na, oldna, auto_unbox, indent))
    }
    return(.rmbl_json_as(unclass(as.list(x)), o, collapse, na, oldna, auto_unbox, indent))
  }
  if (is.null(x)) return(if (identical(o$null, "null")) "null" else "{}")
  # an S3 class none of the branches above know: jsonlite's ANY method tries
  # the remaining classes, then unclasses under force = TRUE, else errors
  if (!is.null(oldClass(x)) && !is.data.frame(x)) {
    if (isS4(x)) {
      if (isTRUE(o$force)) return(.rmbl_json_as(attributes(x), o, collapse, na, oldna, auto_unbox, indent))
      stop("No method asJSON S4 class: ", cls, call. = FALSE)
    }
    if (length(cls) > 1L) {
      class(x) <- cls[-1L]
      return(.rmbl_json_as(x, o, collapse, na, oldna, auto_unbox, indent))
    }
    if (isTRUE(o$force)) {
      return(.rmbl_json_as(unclass(x), o, collapse, na, oldna, auto_unbox, indent))
    }
    stop("No method asJSON S3 class: ", cls, call. = FALSE)
  }
  # base storage types (after S3 classes, the way jsonlite's S4 dispatch falls
  # through to the implicit class)
  if (is.raw(x)) return(.rmbl_json_as_raw(x, o, collapse, na, oldna, auto_unbox, indent))
  if (is.matrix(x) || (is.array(x) && length(dim(x)) >= 2L))
    return(.rmbl_json_as_array(x, o, collapse, na, oldna, auto_unbox, indent, keep_vec_names))
  if (is.list(x) || is.pairlist(x))
    return(.rmbl_json_as_list(x, o, collapse, na, oldna, auto_unbox, indent, is_df))
  if (is.character(x)) return(.rmbl_json_as_chr(x, o, collapse, na, auto_unbox, indent, keep_vec_names))
  if (is.logical(x)) return(.rmbl_json_as_lgl(x, o, collapse, na, auto_unbox, indent, keep_vec_names))
  if (is.complex(x)) return(.rmbl_json_as_cplx(x, o, collapse, na, oldna, auto_unbox, indent))
  if (is.numeric(x)) return(.rmbl_json_as_num(x, o, collapse, na, auto_unbox, indent, keep_vec_names))
  # what is left has no class attribute and is not data: an environment, a
  # symbol, a function, an external pointer
  if (isTRUE(o$force)) return(.rmbl_json_as(NULL, o))
  stop("No method asJSON S3 class: ", cls, call. = FALSE)
}

#' Encodes a numeric vector as JSON.
#' @param x The vector.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether the values are collapsed into one array.
#' @param na How missing values are written, or NULL for "string".
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @param keep_vec_names Whether a named vector is written as an object.
#' @return The JSON text, or the encoded elements.
#' @noRd
.rmbl_json_as_num <- function(x, o, collapse, na, auto_unbox, indent, keep_vec_names) {
  if (isTRUE(keep_vec_names) && length(names(x))) {
    if (!isTRUE(o$quiet_vec_names)) message("Input to asJSON(keep_vec_names=TRUE) is a named vector. In a future version of jsonlite, this option will not be supported, and named vectors will be translated into arrays instead of objects. If you want JSON object output, please use a named list instead. See ?toJSON.")
    o$always_decimal <- FALSE
    return(.rmbl_json_as(as.list(x), o, collapse, na = na, auto_unbox = TRUE, indent = NA_integer_))
  }
  na <- if (is.null(na)) "string" else .rmbl_arg(na, c("string", "null", "NA"))
  nas <- switch(na, string = TRUE, null = FALSE, "NA" = NA)
  if (!is.null(attr(x, "dim")) && length(dim(x)) < 2L) x <- c(x)
  tmp <- .rmbl_json_num_to_char(x, o$digits, nas, o$use_signif, o$always_decimal)
  if (isTRUE(auto_unbox) && length(tmp) == 1L) return(tmp)
  if (collapse) .rmbl_json_collapse(tmp, indent = indent) else tmp
}
#' Encodes a character vector as JSON.
#' @param x The vector.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether the values are collapsed into one array.
#' @param na How missing values are written, or NULL for "null".
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @param keep_vec_names Whether a named vector is written as an object.
#' @return The JSON text, or the encoded elements.
#' @noRd
.rmbl_json_as_chr <- function(x, o, collapse, na, auto_unbox, indent, keep_vec_names) {
  if (isTRUE(keep_vec_names) && length(names(x))) {
    if (!isTRUE(o$quiet_vec_names)) message("Input to asJSON(keep_vec_names=TRUE) is a named vector. In a future version of jsonlite, this option will not be supported, and named vectors will be translated into arrays instead of objects. If you want JSON object output, please use a named list instead. See ?toJSON.")
    return(.rmbl_json_as(as.list(x), o, collapse, na = na, auto_unbox = TRUE, indent = NA_integer_))
  }
  tmp <- .rmbl_json_esc(as.character(x))
  miss <- which(is.na(x))
  if (length(miss)) {
    na <- if (is.null(na)) "null" else .rmbl_arg(na, c("null", "string", "NA"))
    tmp[miss] <- if (na == "null") "null" else if (na == "string") "\"NA\"" else NA_character_
  }
  if (isTRUE(auto_unbox) && length(tmp) == 1L) return(tmp)
  if (isTRUE(collapse)) .rmbl_json_collapse(tmp, indent = indent) else tmp
}
#' Encodes a logical vector as JSON.
#' @param x The vector.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether the values are collapsed into one array.
#' @param na How missing values are written, or NULL for "null".
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @param keep_vec_names Whether a named vector is written as an object.
#' @return The JSON text, or the encoded elements.
#' @noRd
.rmbl_json_as_lgl <- function(x, o, collapse, na, auto_unbox, indent, keep_vec_names) {
  if (isTRUE(keep_vec_names) && length(names(x))) {
    if (!isTRUE(o$quiet_vec_names)) message("Input to asJSON(keep_vec_names=TRUE) is a named vector. In a future version of jsonlite, this option will not be supported, and named vectors will be translated into arrays instead of objects. If you want JSON object output, please use a named list instead. See ?toJSON.")
    return(.rmbl_json_as(as.list(x), o, collapse, na = na, auto_unbox = TRUE, indent = NA_integer_))
  }
  na <- if (is.null(na)) "null" else .rmbl_arg(na, c("null", "string", "NA"))
  tmp <- ifelse(x, "true", "false")
  if (!identical(na, "NA")) {
    miss <- which(is.na(x))
    if (length(miss)) tmp[miss] <- if (identical(na, "string")) "\"NA\"" else "null"
  }
  if (!is.character(tmp)) tmp <- as.character(tmp)
  if (isTRUE(auto_unbox) && length(tmp) == 1L) return(tmp)
  if (collapse) .rmbl_json_collapse(tmp, indent = indent) else tmp
}
#' Encodes a complex vector as JSON, as strings or as real and imaginary arrays.
#' @param x The vector.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether the values are collapsed into one array.
#' @param na How missing values are written, or NULL for "string".
#' @param oldna The `na` setting passed down to nested values.
#' @param auto_unbox Whether a length-one vector is written as a scalar.
#' @param indent The indent, NA for compact output.
#' @return The JSON text, or the encoded elements.
#' @noRd
.rmbl_json_as_cplx <- function(x, o, collapse, na, oldna, auto_unbox, indent) {
  na <- if (is.null(na)) "string" else .rmbl_arg(na, c("string", "null", "NA"))
  if (identical(o$complex, "string")) {
    mystring <- prettyNum(x = x, digits = if (is.null(o$digits)) 5 else o$digits)
    miss <- which(!is.finite(x))
    if (length(miss) && na %in% c("null", "NA")) mystring[miss] <- NA_character_
    return(.rmbl_json_as_chr(mystring, o, collapse, na, auto_unbox, indent, FALSE))
  }
  if (na == "NA") na <- oldna
  .rmbl_json_as(list(real = Re(x), imaginary = Im(x)), o, collapse, na = na, oldna = oldna,
             auto_unbox = auto_unbox, indent = indent)
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
    return(.rmbl_json_as(list(`$binary` = bricklayer_json_unbox(jsb64enc(x)),
                           `$type` = bricklayer_json_unbox(as.character(type))), o, indent = NA_integer_))
  }
  if (raw == "hex") return(.rmbl_json_as(as.character.hexmode(x), o, collapse, na, oldna, auto_unbox, indent))
  if (raw == "int") return(.rmbl_json_as(as.integer(x), o, collapse, na, oldna, auto_unbox, indent))
  if (raw == "js") {
    o$always_decimal <- FALSE
    return(paste0("(new Uint8Array(", .rmbl_json_as(as.integer(x), o, collapse = TRUE, na = NULL,
                                                  auto_unbox = FALSE, indent = NA_integer_), "))"))
  }
  .rmbl_json_as(jsb64enc(x), o, collapse, na, oldna, auto_unbox, indent)
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
.rmbl_json_as_array <- function(x, o, collapse, na, oldna, auto_unbox, indent, keep_vec_names) {
  if (identical(na, "NA")) na <- oldna
  if (length(dim(x)) < 2L)
    return(.rmbl_json_as(c(x), o, collapse, na = na, indent = .rmbl_json_indent_inc(indent)))
  columnmajor <- identical(o$matrix, "columnmajor")
  if (columnmajor && !collapse)
    return(apply(x, 1L, function(r) .rmbl_json_as(r, o, na = na, indent = .rmbl_json_indent_inc(indent))))
  m <- .rmbl_json_as(c(x), o, collapse = FALSE, na = na, auto_unbox = FALSE)
  dim(m) <- dim(x)
  tmp <- if (length(dim(x)) == 2L && !columnmajor) {
    .rmbl_json_row_collapse(m, indent = .rmbl_json_indent_inc(indent))
  } else {
    .rmbl_json_collapse_array(m, columnmajor = columnmajor, indent = indent)
  }
  if (collapse) .rmbl_json_collapse(tmp, inner = FALSE, indent = indent) else tmp
}
#' Collapses an array of encoded values into nested JSON arrays, the innermost dimension first.
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
    ind <- if (is.na(inc)) inc else structure(as.integer(inc) * i, indent_spaces = attr(inc, "indent_spaces"))
    x <- apply(x, dims, .rmbl_json_collapse, inner = FALSE, indent = ind)
  }
  x
}
#' Encodes a list as a JSON object (when named) or array, at most 100 levels deep.
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
.rmbl_json_as_list <- function(x, o, collapse, na, oldna, auto_unbox, indent, is_df) {
  # the same cap as the parser's, so what the parser reads the encoder can
  # write back; the recursion used to run into the C stack ~100 levels down
  o$depth <- (o$depth %||% 0L) + 1L
  if (o$depth > 100L) stop("nesting deeper than 100 levels", call. = FALSE)
  if (identical(na, "NA")) na <- oldna
  if (is.pairlist(x)) x <- as.vector(x, mode = "list")
  inc <- .rmbl_json_indent_inc(indent)
  tmp <- if (is_df && auto_unbox) {
    vapply(x, function(y) .rmbl_json_as(y, o, na = na, oldna = oldna, auto_unbox = is.list(y), indent = inc), character(1))
  } else {
    vapply(x, function(y) .rmbl_json_as(y, o, na = na, oldna = oldna, auto_unbox = auto_unbox, indent = inc), character(1))
  }
  if (!is.null(names(x))) {
    keys <- if (isTRUE(o$keep_empty_names)) .rmbl_json_esc(names(x))
            else .rmbl_json_esc(.rmbl_json_cleannames(names(x), o$no_dots))
    return(.rmbl_json_collapse_object(keys, unname(tmp), indent))
  }
  if (collapse) .rmbl_json_collapse(unname(tmp), inner = FALSE, indent = indent) else unname(tmp)
}
#' Encodes a data frame as JSON by rows, columns or values, as `o$dataframe` says.
#' @param x The data frame.
#' @param o The options list built by `tojs()`.
#' @param collapse Whether the rows are collapsed into one array.
#' @param na How missing values are written.
#' @param oldna The `na` setting passed down to nested values.
#' @param indent The indent, NA for compact output.
#' @param keep_vec_names Not used: a data frame's columns are never written as objects.
#' @return The JSON text, or one encoded element per row.
#' @noRd
.rmbl_json_as_df <- function(x, o, collapse, na, oldna, indent, keep_vec_names) {
  dataframe <- o$dataframe
  o$keep_vec_names <- FALSE
  has_names <- identical(length(names(x)), ncol(x))
  rn <- attr(x, "row.names")
  if (isTRUE(o$rownames) || (is.null(o$rownames) && is.character(rn) && !all(grepl("^\\d+$", rn)))) {
    if (has_names) x[["_row"]] <- rn
  }
  for (i in which(vapply(x, function(c) isTRUE(is.list(c) && !is.data.frame(c) && !is.null(names(c))), logical(1))))
    x[[i]] <- unname(x[[i]])
  for (i in which(vapply(x, inherits, logical(1), "POSIXlt"))) x[[i]] <- as.POSIXct(x[[i]])
  if (dataframe == "columns")
    return(.rmbl_json_as_list(as.list(x), o, collapse = TRUE, na = na, oldna = oldna,
                           auto_unbox = o$auto_unbox, indent = indent, is_df = TRUE))
  if (is.null(na) || !length(na) || identical(na, "NA")) oldna <- NULL else oldna <- na
  if (dataframe == "rows" && has_names) na <- if (is.null(na)) "NA" else .rmbl_arg(na, c("NA", "null", "string"))
  if (!nrow(x)) return(.rmbl_json_as(list(), o, collapse = collapse, indent = indent))
  for (i in which(vapply(x, is.raw, logical(1)))) x[[i]] <- as.character.hexmode(x[[i]])
  if (identical(o$complex, "list"))
    for (i in which(vapply(x, is.complex, logical(1))))
      x[[i]] <- data.frame(real = Re(x[[i]]), imaginary = Im(x[[i]]))
  dfnames <- .rmbl_json_esc(.rmbl_json_cleannames(names(x), o$no_dots))
  inc <- .rmbl_json_indent_inc(indent)
  cols <- lapply(x, function(col) {
    .rmbl_json_as(col, o, collapse = FALSE, na = na, oldna = oldna,
               auto_unbox = o$auto_unbox, indent = inc)
  })
  out <- matrix(unlist(cols, use.names = FALSE), nrow = nrow(x))
  tmp <- if (dataframe == "rows" && length(dfnames) == ncol(out)) {
    .rmbl_json_row_collapse_object(dfnames, out, indent = inc)
  } else {
    .rmbl_json_row_collapse(out, indent = indent)
  }
  if (isTRUE(collapse)) .rmbl_json_collapse(tmp, inner = FALSE, indent = indent) else tmp
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
#' @param matrix How a matrix is written. \code{"rowmajor"} (the default) gives an
#'   array of rows, and \code{"columnmajor"} an array of columns.
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
#'   \code{"string"} (\code{"NA"}). When not given, the per-type default of
#'   jsonlite applies (see Details).
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
#' @examples
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
#' @srrstats {G2.12} List columns are encoded element-wise; test-review-coverage.R:95 tojs(data.frame(a =
#'   I(list(1:2, 3)))).
tojs <- function(x, dataframe = c("rows", "columns", "values"),
                                 matrix = c("rowmajor", "columnmajor"),
                                 Date = c("ISO8601", "epoch"),
                                 POSIXt = c("string", "ISO8601", "epoch", "mongo"),
                                 factor = c("string", "integer"),
                                 complex = c("string", "list"),
                                 raw = c("base64", "hex", "mongo", "int", "js"),
                                 null = c("list", "null"), na = c("null", "string"),
                                 auto_unbox = FALSE, digits = 4, pretty = FALSE,
                                 force = FALSE, ...) {
  # NULL (full precision, this codec's own) and NA (15 significant digits) are documented forms
  if (!is.null(digits) && (!(is.numeric(digits) || is.logical(digits)) || length(digits) != 1L ||
                           (!is.na(digits) && !is.numeric(digits)))) {
    stop("`digits` must be one number, NA for 15 significant digits, or I(n) for n", call. = FALSE)
  }
  dots <- list(...)
  o <- list(dataframe = .rmbl_arg(dataframe), matrix = .rmbl_arg(matrix),
            Date = .rmbl_arg(Date), POSIXt = .rmbl_arg(POSIXt), factor = .rmbl_arg(factor),
            complex = .rmbl_arg(complex), raw = .rmbl_arg(raw), null = .rmbl_arg(null),
            auto_unbox = isTRUE(auto_unbox), digits = digits,
            use_signif = if (!is.null(dots$use_signif)) isTRUE(dots$use_signif) else inherits(digits, "AsIs"),
            force = isTRUE(force), indent = .rmbl_json_indent_init(pretty),
            rownames = dots$rownames, keep_vec_names = isTRUE(dots$keep_vec_names),
            json_verbatim = isTRUE(dots$json_verbatim), always_decimal = isTRUE(dots$always_decimal),
            time_format = dots$time_format, UTC = isTRUE(dots$UTC), no_dots = isTRUE(dots$no_dots),
            hms = if (is.null(dots$hms)) "string" else .rmbl_arg(dots$hms, c("string", "secs")),
            keep_empty_names = isTRUE(dots$keep_empty_names),
            quiet_vec_names = isTRUE(dots$quiet_vec_names), depth = 0L)
  na <- if (!missing(na)) .rmbl_arg(na) else NULL
  ans <- .rmbl_json_as(x, o, na = na, oldna = NULL, auto_unbox = o$auto_unbox, indent = o$indent)
  class(ans) <- "json"
  ans
}

#' Mark a value as a JSON scalar (jsonlite's unbox)
#'
#' @param x an atomic vector of length one, a one-row data.frame,
#' or a length-one POSIXt.
#' @return `x` with class `scalar`, so it is written without
#' brackets.
#' @noRd
bricklayer_json_unbox <- function(x) {
  if (is.null(x)) return(x)
  if (is.data.frame(x)) {
    if (nrow(x) == 1L) return(.rmbl_json_as_scalar(x))
    stop("Tried to unbox dataframe with ", nrow(x), " rows.", call. = FALSE)
  }
  if (length(x) == 1L && inherits(x, "POSIXt")) return(.rmbl_json_as_scalar(x))
  if (!is.atomic(x) || length(dim(x)) > 1L)
    stop("Only atomic vectors of length 1 or data frames with 1 row can be unboxed.", call. = FALSE)
  if (identical(length(x), 1L)) return(.rmbl_json_as_scalar(x))
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
#' Converts decimal text to doubles, correctly rounded where the native converter is there.
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
#' The writer's half of the same argument. sprintf("%.17g") delegates to
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
#' @param bigint_warn Whether a warning says an integer above 2^53 lost precision.
#' @param duplicate_keys "error" refuses an object with a key twice, "keep" keeps both.
#' @return The parsed value: lists, atomic scalars and NULL.
#' @noRd
.rmbl_json_parse <- function(txt, bigint_as_char = FALSE, bigint_warn = TRUE,
                             duplicate_keys = c("error", "keep")) {
  duplicate_keys <- .rmbl_arg(duplicate_keys)
  s <- paste(txt, collapse = "\n")
  # the byte-order mark is tested and removed on the BYTES, before any
  # encoding conversion: substring(s, 2L) on a string a C locale has not
  # marked as UTF-8 removed one of the mark's three bytes
  if (.rmbl_has_bom(s)) {
    warning("JSON string contains (illegal) UTF8 byte-order-mark!", call. = FALSE)
    s <- .rmbl_strip_bom(s)
  }
  # JSON is UTF-8 (RFC 8259): bytes that are not were read with base R's warnings and garbled.
  # Checked before the conversion: in a C locale enc2utf8() rewrote an invalid byte as a valid
  # escape, and the text then failed as "unexpected character" (C-locale check of 1.0.0)
  if (Encoding(s) != "latin1" && !validUTF8(s)) stop("the JSON text is not valid UTF-8", call. = FALSE)
  s <- enc2utf8(s)
  if (startsWith(s, "\x1e")) s <- substring(s, 2L)
  # the package's native path for a well-formed document (85 s for a 15 MiB reply here; CRAN stress
  # test of 0.5.14); it gives up (NULL) on whatever needs this parser's words: an error, a big integer,
  # a duplicate key, deep nesting. A staged bundle has no native code and parses here.
  fast <- .rmbl_native$json
  if (is.null(fast)) {
    fast <- exists("C_rmbl_json_fast", inherits = TRUE)
    .rmbl_native$json <- fast
  }
  if (fast) {
    r <- .Call(C_rmbl_json_fast, s, duplicate_keys == "keep", isTRUE(bigint_as_char))
    if (!is.null(r)) {
      if (!is.null(r[[2L]]) && bigint_warn) {
        warning(sprintf(paste0("integer %s exceeds 2^53 and cannot be held exactly ",
                               "in a double; pass bigint_as_char = TRUE to keep it as text"), r[[2L]]),
                call. = FALSE)
      }
      return(r[[1L]])
    }
  }
  ch <- strsplit(s, "", fixed = TRUE)[[1]]
  n <- length(ch)
  p <- new.env(parent = emptyenv())   # the cursor, the nesting depth and the big-integer flag
  p$i <- 1L
  # The code points once, and the positions the scanner jumps to (the next character that is not
  # white space, not a digit, or that ends a run of plain string text): one R call per character
  # took 85 s for a 15 MiB reply (CRAN stress test of 0.5.14).
  cp <- utf8ToInt(s)
  is_ws <- cp == 32L | cp == 9L | cp == 10L | cp == 13L
  not_ws <- as.double(which(!is_ws))   # double: findInterval() copies an integer vector each call
  is_dig <- cp >= 48L & cp <= 57L
  not_dig <- as.double(which(!is_dig))
  spec <- as.double(which(cp == 34L | cp == 92L | cp < 32L))   # a quote, a backslash or a control character
  # the first position of `v` at or after `pos`, n + 1 when there is none
  after <- function(pos, v) {
    j <- v[findInterval(pos - 1L, v, checkSorted = FALSE, checkNA = FALSE) + 1L]
    if (is.na(j)) n + 1L else as.integer(j)
  }
  p$depth <- 0L          # nesting, capped: 20,000 "[" exhausted the C stack
  p$big_warned <- FALSE  # one warning per document for integers above 2^53
  bad <- function(msg) stop(sprintf("%s at character %d", msg, p$i), call. = FALSE)
  ws <- function() if (p$i <= n && is_ws[p$i]) p$i <- after(p$i, not_ws)
  str_ <- function() {
    p$i <- p$i + 1L
    st <- p$i
    # a string with no escape (nearly every one): its text in one step
    j <- after(p$i, spec)
    if (j <= n && cp[j] == 34L) {
      p$i <- j + 1L
      return(if (j > st) paste(ch[st:(j - 1L)], collapse = "") else "")
    }
    # pieces are appended into a doubling buffer: c(parts, ...) per escape
    # was quadratic, and 532 bytes of gzip held 250,000 escapes
    q <- new.env(parent = emptyenv())
    q$parts <- character(32L)
    q$np <- 0L
    push <- function(v) {
      q$np <- q$np + 1L
      if (q$np > length(q$parts)) length(q$parts) <- 2L * length(q$parts)
      q$parts[q$np] <- v
    }
    repeat {
      p$i <- after(p$i, spec)
      if (p$i > n) bad("unterminated string")
      c0 <- ch[p$i]
      if (c0 == "\"") break
      if (c0 == "\\") {
        if (p$i > st) push(paste(ch[st:(p$i - 1L)], collapse = ""))
        p$i <- p$i + 1L
        e <- ch[p$i]
        push(switch(e, n = "\n", t = "\t", r = "\r", b = "\b", f = "\f",
                                 "\"" = "\"", "\\" = "\\", "/" = "/",
                                 u = {
                                   cp <- strtoi(paste(ch[(p$i + 1L):(p$i + 4L)], collapse = ""), 16L)
                                   if (is.na(cp)) bad("invalid \\u escape")
                                   p$i <- p$i + 4L
                                   if (cp >= 0xD800 && cp <= 0xDBFF && p$i + 6L <= n && ch[p$i + 1L] == "\\" && ch[p$i + 2L] == "u") {
                                     lo <- strtoi(paste(ch[(p$i + 3L):(p$i + 6L)], collapse = ""), 16L)
                                     if (!is.na(lo) && lo >= 0xDC00 && lo <= 0xDFFF) {
                                       p$i <- p$i + 6L
                                       cp <- 0x10000 + (cp - 0xD800) * 1024 + (lo - 0xDC00)
                                     }
                                   }
                                   if (cp == 0) bad("NUL in string")
                                   # an unpaired surrogate is not a character;
                                   # intToUtf8() turned it into the text "NA"
                                   if (cp >= 0xD800 && cp <= 0xDFFF) bad("lone surrogate escape")
                                   intToUtf8(cp)
                                 },
                                 bad("invalid escape")))
        p$i <- p$i + 1L
        st <- p$i
        next
      }
      bad("control character in string")
    }
    if (p$i > st) push(paste(ch[st:(p$i - 1L)], collapse = ""))
    p$i <- p$i + 1L
    paste(q$parts[seq_len(q$np)], collapse = "")
  }
  num_ <- function() {
    st <- p$i
    if (ch[p$i] == "-") p$i <- p$i + 1L
    if (p$i > n || !is_dig[p$i]) bad("invalid number")
    if (ch[p$i] == "0") p$i <- p$i + 1L else p$i <- after(p$i, not_dig)
    isint <- TRUE
    if (p$i <= n && ch[p$i] == ".") {
      isint <- FALSE
      p$i <- p$i + 1L
      if (p$i > n || !is_dig[p$i]) bad("invalid number")
      p$i <- after(p$i, not_dig)
    }
    if (p$i <= n && (ch[p$i] == "e" || ch[p$i] == "E")) {
      isint <- FALSE
      p$i <- p$i + 1L
      if (p$i <= n && (ch[p$i] == "+" || ch[p$i] == "-")) p$i <- p$i + 1L
      if (p$i > n || !is_dig[p$i]) bad("invalid number")
      p$i <- after(p$i, not_dig)
    }
    t0 <- paste(ch[st:(p$i - 1L)], collapse = "")
    v <- .rmbl_strtod(t0)
    if (!isint && bigint_warn && !p$big_warned && is.finite(v) && v == trunc(v) &&
        abs(v) >= 9007199254740992 && abs(v) < 18446744073709551616) {
      # "9007199254740993.0" and "9.007199254740993e15" write an integer in
      # the identifier range that the double does not hold: the digits
      # written are compared with the integer the double actually is. A
      # value beyond 2^64 (1.7976931348623157e308) is a magnitude, not an
      # identifier, and is left alone.
      written <- .rmbl_json_written_integer(t0)
      if (!is.null(written) && !identical(written, sprintf("%.0f", abs(v)))) {
        p$big_warned <- TRUE
        warning(sprintf(paste0("number %s is a whole number beyond 2^53 and cannot be held ",
                               "exactly in a double"), t0), call. = FALSE)
      }
    }
    # fewer than 16 digits cannot pass 2^53: the digit checks are skipped (they were a regex per number)
    if (isint && nchar(t0) < 16L) {
      if (v > 2147483647 || v < -2147483647) return(v)
      return(as.integer(v))
    }
    if (isint) {
      digs <- sub("^0+(?=[0-9])", "", sub("^-", "", t0), perl = TRUE)
      big <- nchar(digs) > 16L || (nchar(digs) == 16L && digs > "9007199254740992")
      # inexact: the integer written is not the integer the double holds.
      # 9007199254740994 is beyond 2^53 and exact (even); 9007199254740993
      # is not. Only the second deserves a warning.
      inexact <- big && is.finite(v) && !identical(sprintf("%.0f", abs(v)), digs)
      if (big) {
        if (bigint_as_char) return(t0)
        if (!p$big_warned && bigint_warn && inexact) {
          p$big_warned <- TRUE
          warning(sprintf(paste0("integer %s exceeds 2^53 and cannot be held exactly ",
                                 "in a double; pass bigint_as_char = TRUE to keep it as text"),
                          t0), call. = FALSE)
        }
      }
      # sixteen digits or more without a leading zero is past the integer range
    }
    v
  }
  # the depth is put back on return; an error ends the parse, so no on.exit() (a cost per value)
  value <- function() {
    p$depth <- p$depth + 1L
    if (p$depth > 100L) bad("nesting deeper than 100 levels")
    v <- value_()
    p$depth <- p$depth - 1L
    v
  }
  value_ <- function() {
    ws()
    if (p$i > n) bad("unexpected end of input")
    c0 <- ch[p$i]
    if (c0 == "{") {
      p$i <- p$i + 1L
      ws()
      keys <- character(0)
      vals <- list()
      if (p$i <= n && ch[p$i] == "}") {
        p$i <- p$i + 1L
        return(structure(list(), names = character(0)))
      }
      repeat {
        ws()
        if (p$i > n || ch[p$i] != "\"") bad("expected a string key")
        k <- str_()
        ws()
        if (p$i > n || ch[p$i] != ":") bad("expected ':'")
        p$i <- p$i + 1L
        vals[[length(vals) + 1L]] <- list(value())
        keys[[length(keys) + 1L]] <- k
        ws()
        if (p$i <= n && ch[p$i] == ",") {
          p$i <- p$i + 1L
          next
        }
        if (p$i <= n && ch[p$i] == "}") {
          p$i <- p$i + 1L
          break
        }
        bad("expected ',' or '}'")
      }
      # two values under one key let a file show a reader one digest and
      # hand `$` another (the first); refuse unless asked to keep both
      if (duplicate_keys == "error" && anyDuplicated(keys)) {
        bad(sprintf("duplicate key \"%s\"", keys[duplicated(keys)][1L]))
      }
      out <- lapply(vals, function(w) w[[1L]])
      names(out) <- keys
      return(out)
    }
    if (c0 == "[") {
      p$i <- p$i + 1L
      ws()
      vals <- list()
      if (p$i <= n && ch[p$i] == "]") {
        p$i <- p$i + 1L
        return(list())
      }
      repeat {
        vals[[length(vals) + 1L]] <- list(value())
        ws()
        if (p$i <= n && ch[p$i] == ",") {
          p$i <- p$i + 1L
          next
        }
        if (p$i <= n && ch[p$i] == "]") {
          p$i <- p$i + 1L
          break
        }
        bad("expected ',' or ']'")
      }
      return(lapply(vals, function(w) w[[1L]]))
    }
    if (c0 == "\"") return(str_())
    if (c0 == "t" && p$i + 3L <= n && identical(paste(ch[p$i:(p$i + 3L)], collapse = ""), "true")) {
      p$i <- p$i + 4L
      return(TRUE)
    }
    if (c0 == "f" && p$i + 4L <= n && identical(paste(ch[p$i:(p$i + 4L)], collapse = ""), "false")) {
      p$i <- p$i + 5L
      return(FALSE)
    }
    if (c0 == "n" && p$i + 3L <= n && identical(paste(ch[p$i:(p$i + 3L)], collapse = ""), "null")) {
      p$i <- p$i + 4L
      return(NULL)
    }
    if (c0 == "-" || is_dig[p$i]) return(num_())
    bad("unexpected character")
  }
  v <- value()
  ws()
  if (p$i <= n) bad("trailing content")
  v
}

# ================================================================ simplify

#' Says whether a value is a named list.
#' @param x The value.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_namedlist <- function(x) isTRUE(is.list(x) && !is.null(names(x)))
#' Says whether a list is a list of records: unnamed, each element a named list or NULL, at least one a list.
#' @param x The value.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_recordlist <- function(x) {
  if (!(is.list(x) && is.null(names(x)) && length(x))) return(FALSE)
  one <- FALSE
  for (el in x) {
    if (!(.rmbl_json_is_namedlist(el) || is.null(el))) return(FALSE)
    if (!one && .rmbl_json_is_namedlist(el)) one <- TRUE
  }
  one
}
#' Says whether every element of a list is NULL or an atomic value of length at most one.
#' @param x The value.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_scalarlist <- function(x) {
  if (!is.list(x)) return(FALSE)
  for (el in x) if (!(is.null(el) || (is.atomic(el) && length(el) < 2L))) return(FALSE)
  TRUE
}
#' Turns NULL elements into NA, and the strings "NA", "NaN", "Inf" and "-Inf" into their values when no other string is
#' present.
#' @param x A list.
#' @return The list.
#' @noRd
.rmbl_json_null_to_na <- function(x) {
  n <- length(x)
  if (!n) return(x)
  looks_chr <- FALSE
  for (i in seq_len(n)) {
    el <- x[[i]]
    if (is.null(el)) x[i] <- list(NA)
    else if (!looks_chr && is.character(el) && !(el[1L] %in% c("NA", "NaN", "Inf", "-Inf"))) looks_chr <- TRUE
  }
  if (looks_chr) return(x)
  for (i in seq_len(n)) {
    el <- x[[i]]
    if (is.character(el)) x[[i]] <- switch(el[1L], "NA" = NA, "NaN" = NaN, "Inf" = Inf, "-Inf" = -Inf, el)
  }
  x
}
#' Says whether a list holds date-times, NULLs and "NA" strings only, with at least one date-time.
#' @param x The value.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_datelist <- function(x) {
  if (!is.list(x) || !length(x)) return(FALSE)
  status <- FALSE
  for (el in x) {
    if (is.null(el)) next
    if (is.character(el) && length(el) && el[1L] == "NA") next
    # is.numeric() is FALSE for a POSIXct (it has an is.numeric method), so
    # the class alone decides
    if (inherits(el, "POSIXct")) status <- TRUE else return(FALSE)
  }
  status
}
#' Turns a list of scalars into a vector, keeping the date-time class.
#' @param x The list.
#' @return An atomic vector.
#' @noRd
.rmbl_json_list_to_vec <- function(x) {
  isdates <- .rmbl_json_is_datelist(x)
  out <- unlist(.rmbl_json_null_to_na(x), recursive = FALSE, use.names = FALSE)
  if (isdates && is.numeric(out)) structure(out, class = c("POSIXct", "POSIXt")) else out
}
#' Says whether every element of a vector equals the first.
#' @param x The vector.
#' @return TRUE or FALSE; FALSE for an empty vector.
#' @noRd
.rmbl_json_all_identical <- function(x) length(x) > 0L && all(x == x[1L])
#' Turns a MongoDB `$date` value (milliseconds, or ISO 8601 text) into a date-time.
#' @param x The value.
#' @return A POSIXct vector, or `x` when it is neither number nor text.
#' @noRd
.rmbl_json_parse_date <- function(x) {
  if (is.numeric(x)) return(structure(x / 1000, class = c("POSIXct", "POSIXt")))
  if (is.character(x)) {
    tz <- if (all(grepl("Z$", x))) "UTC" else ""
    return(as.POSIXct(strptime(x, format = "%Y-%m-%dT%H:%M:%OS", tz = tz)))
  }
  x
}

#' Simplifies parsed JSON into vectors, data frames and matrices, as jsonlite's simplify() does.
#' @param x The parsed value.
#' @param simplifyVector Whether arrays of scalars become vectors.
#' @param simplifyDataFrame Whether arrays of records become data frames.
#' @param simplifyMatrix Whether arrays of equal-length vectors become matrices.
#' @param simplifyDate Whether `$date` objects become date-times.
#' @param homoList Whether empty elements of a list of vectors or data frames take their siblings' type.
#' @param flatten Whether nested data frames are flattened.
#' @param columnmajor Whether matrices are read by columns.
#' @param simplifySubMatrix Whether nested arrays become matrices.
#' @return The simplified value.
#' @noRd
.rmbl_json_simplify <- function(x, simplifyVector = TRUE, simplifyDataFrame = TRUE,
                             simplifyMatrix = TRUE, simplifyDate = simplifyVector,
                             homoList = TRUE, flatten = FALSE, columnmajor = FALSE,
                             simplifySubMatrix = simplifyMatrix) {
  if (!is.list(x) || !length(x)) return(x)
  if (isTRUE(simplifyDataFrame) && .rmbl_json_is_recordlist(x)) {
    mydf <- .rmbl_json_simplify_df(x, flatten = flatten, simplifyMatrix = simplifySubMatrix)
    if (isTRUE(simplifyDate) && is.data.frame(mydf) && identical(names(mydf), "$date") &&
        (is.numeric(mydf[["$date"]]) || is.character(mydf[["$date"]])))
      return(.rmbl_json_parse_date(mydf[["$date"]]))
    return(mydf)
  }
  if (isTRUE(simplifyVector) && is.null(names(x)) && .rmbl_json_is_scalarlist(x))
    return(.rmbl_json_list_to_vec(x))
  out <- lapply(x, .rmbl_json_simplify, simplifyVector = simplifyVector,
                simplifyDataFrame = simplifyDataFrame, simplifyMatrix = simplifySubMatrix,
                columnmajor = columnmajor, flatten = flatten)
  if (isTRUE(simplifyVector) && .rmbl_json_is_scalarlist(out) && length(out) &&
      all(vapply(out, inherits, logical(1), "POSIXt")))
    return(structure(.rmbl_json_list_to_vec(out), class = c("POSIXct", "POSIXt")))
  if (isTRUE(simplifyMatrix) && isTRUE(simplifyVector) && .rmbl_json_is_matrixlist(out) &&
      all(vapply(x, .rmbl_json_is_scalarlist, logical(1)))) {
    return(if (isTRUE(columnmajor)) do.call(cbind, out) else do.call(rbind, out))
  }
  if (isTRUE(simplifyMatrix) && .rmbl_json_is_arraylist(out)) {
    if (isTRUE(columnmajor))
      return(array(do.call(cbind, out), dim = c(dim(out[[1L]]), length(out))))
    return(array(do.call(rbind, lapply(out, as.vector)), dim = c(length(out), dim(out[[1L]]))))
  }
  if (isTRUE(homoList) && is.null(names(out))) {
    isempty <- vapply(out, identical, logical(1), list())
    if (any(isempty) && !all(isempty)) {
      if (all(vapply(out[!isempty], is.data.frame, logical(1)))) {
        for (i in which(isempty)) out[[i]] <- data.frame()
        return(out)
      }
      if (all(vapply(out[!isempty], function(z) isTRUE(is.vector(z) && is.atomic(z)), logical(1)))) {
        for (i in which(isempty)) out[[i]] <- vector(mode = typeof(out[[which(!isempty)[1L]]]))
        return(out)
      }
    }
  }
  if (isTRUE(simplifyDate) && is.list(out) && identical(names(out), "$date") &&
      (is.numeric(out[["$date"]]) || is.character(out[["$date"]])))
    return(.rmbl_json_parse_date(out[["$date"]]))
  out
}
#' Says whether a list is unnamed and holds atomic vectors of one length.
#' @param x The value.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_matrixlist <- function(x) {
  isTRUE(is.list(x) && length(x) && is.null(names(x)) &&
         all(vapply(x, is.atomic, logical(1))) &&
         .rmbl_json_all_identical(vapply(x, length, integer(1))))
}
#' Says whether a list is unnamed and holds arrays of one shape.
#' @param x The value.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_json_is_arraylist <- function(x) {
  isTRUE(is.list(x) && length(x) && is.null(names(x)) &&
         all(vapply(x, is.array, logical(1))) &&
         .rmbl_json_all_identical(vapply(x, function(y) paste(dim(y), collapse = "-"), character(1))))
}
#' Turns a list of records into a data frame, as jsonlite's simplifyDataFrame() does.
#' @param recordlist The list of records.
#' @param columns The column names; when missing, every name that occurs in a record.
#' @param flatten Whether nested data frames are flattened.
#' @param simplifyMatrix Whether nested arrays become matrices.
#' @return A data frame.
#' @noRd
.rmbl_json_simplify_df <- function(recordlist, columns, flatten, simplifyMatrix) {
  if (!length(recordlist)) {
    if (!missing(columns))
      return(as.data.frame(matrix(ncol = length(columns), nrow = 0, dimnames = list(NULL, columns))))
    return(data.frame())
  }
  if (!any(vapply(recordlist, length, integer(1), USE.NAMES = FALSE)) && missing(columns))
    return(data.frame(matrix(nrow = length(recordlist), ncol = 0)))
  if (missing(columns))
    columns <- unique(unlist(lapply(recordlist, names), recursive = FALSE, use.names = FALSE))
  columnlist <- lapply(columns, function(nm) {
    lapply(recordlist, function(rec) {
      k <- match(nm, names(rec))
      if (is.na(k)) NULL else rec[[k]]
    })
  })
  columnlist <- lapply(columnlist, .rmbl_json_simplify, simplifyVector = TRUE, simplifyDataFrame = TRUE,
                       simplifyMatrix = FALSE, simplifySubMatrix = simplifyMatrix, flatten = flatten)
  lens <- vapply(columnlist, function(z) if (length(dim(z)) > 1L) nrow(z) else length(z), integer(1))
  n <- unique(lens)
  if (length(n) > 1L) stop("Elements not of equal length: ", paste(lens, collapse = " "), call. = FALSE)
  names(columnlist) <- columns
  if (isTRUE(flatten)) {
    dfcols <- vapply(columnlist, is.data.frame, logical(1))
    if (any(dfcols)) columnlist <- c(columnlist[!dfcols], do.call(c, columnlist[dfcols]))
  }
  class(columnlist) <- "data.frame"
  if ("_row" %in% names(columnlist)) {
    rn <- columnlist[["_row"]]
    columnlist["_row"] <- NULL
    if (is.double(rn)) rn <- as.integer(rn)
    rn_na <- is.na(rn)
    if (sum(rn_na) > 0L) rn[rn_na] <- paste0("NA_", seq_len(sum(rn_na)))
    if (any(duplicated(rn))) {
      warning('Duplicate names in "_row" field. Data frames must have unique row names.', call. = FALSE)
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
#' @examples
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
fromjs <- function(txt, simplifyVector = TRUE,
                                   simplifyDataFrame = simplifyVector,
                                   simplifyMatrix = simplifyVector,
                                   flatten = FALSE, bigint_as_char = FALSE,
                                   simplify = NULL,
                                   duplicate_keys = c("error", "keep"),
                                   bigint_warn = TRUE, ...) {
  if (identical(simplify, FALSE)) simplifyVector <- simplifyDataFrame <- simplifyMatrix <- FALSE
  if (!is.character(txt) && !inherits(txt, "connection"))
    stop("Argument 'txt' must be a JSON string, URL or file.", call. = FALSE)
  if (is.character(txt) && anyNA(txt)) stop("Argument 'txt' must be a JSON string, not NA.", call. = FALSE)
  if (is.character(txt) && length(txt) == 1L && nchar(txt, type = "bytes") < 2084 &&
      !bricklayer_json_validate(txt)) {
    if (grepl("^https?://", txt, useBytes = TRUE)) {
      # the same gate and the same transport as every other fetch: base R's
      # url() connected to 127.0.0.1 when asked (0.5.7 review)
      txt <- .rmbl_check_public_url(txt, "txt")
      tmp <- tempfile(fileext = ".json")
      on.exit(unlink(tmp), add = TRUE)
      res <- .bl_net(txt, .bl_http_download(txt, tmp, 60L, "Accept: application/json, text/*, */*", NULL,
                                            16777216, FALSE))  # 16 MiB is a large JSON
      if (res$status < 0) stop(sprintf("%s: %s", txt, res$error), call. = FALSE)
      if (res$status >= 400) stop(sprintf("%s answered HTTP %d", txt, res$status), call. = FALSE)
      txt <- file(tmp)
    } else if (file.exists(txt)) {
      txt <- file(txt)
    }
  }
  if (inherits(txt, "connection")) {
    con <- txt
    if (!isOpen(con)) {
      open(con, "rb")
      on.exit(close(con), add = TRUE)
    }
    txt <- readLines(con, warn = FALSE, encoding = "UTF-8")
  }
  obj <- .rmbl_json_parse(txt, bigint_as_char, bigint_warn,
                          duplicate_keys = .rmbl_arg(duplicate_keys))
  if (any(isTRUE(simplifyVector), isTRUE(simplifyDataFrame), isTRUE(simplifyMatrix)))
    return(.rmbl_json_simplify(obj, simplifyVector = simplifyVector, simplifyDataFrame = simplifyDataFrame,
                            simplifyMatrix = simplifyMatrix, flatten = flatten))
  obj
}

#' Parses JSON text without simplifying vectors by default (jsonlite's parse_json).
#'
#' @param json JSON text.
#' @param simplifyVector Whether arrays of scalars become vectors.
#' @param ... Further options of `fromjs()`.
#' @return The parsed value.
#' @noRd
bricklayer_json_parse_json <- function(json, simplifyVector = FALSE, ...) {
  fromjs(json, simplifyVector = simplifyVector, ...)
}

#' Read and write JSON files
#'
#' @param path file path.
#' @param simplifyVector as in jsonlite (
#' `FALSE` by default for files).
#' @param ... options of
#' [fromjs()] /
#' [tojs()].
#' @return `read_json`: the parsed object; `write_json`:
#' `path`, invisibly.
#' @noRd
bricklayer_json_read_json <- function(path, simplifyVector = FALSE, ...) {
  fromjs(file(path), simplifyVector = simplifyVector, ...)
}
#' Writes an R object to a file as JSON (jsonlite's write_json).
#'
#' @param x object to write.
#' @param path The file path.
#' @param ... Options of `tojs()`.
#' @return `path`, invisibly.
#' @noRd
bricklayer_json_write_json <- function(x, path, ...) {
  json <- tojs(x, ...)
  writeLines(json, path, useBytes = TRUE)
  invisible(path)
}

#' Says whether a string starts with the UTF-8 byte-order mark.
#'
#' A byte-order mark is three bytes; test and strip it on the bytes so a
#' C locale never has to translate U+FEFF to its native encoding (that
#' translation is what raised "unable to translate '<U+FEFF>...'" and
#' "invalid char string in output conversion").
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
  if (!.rmbl_has_bom(s)) return(s)
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
  if (.rmbl_has_bom(txt))
    return(structure(FALSE, err = "JSON string contains UTF8 byte-order-mark."))
  res <- tryCatch({
    .rmbl_json_parse(txt, bigint_warn = FALSE)
    TRUE
  }, error = function(e) e)
  if (isTRUE(res)) return(TRUE)
  off <- suppressWarnings(as.integer(sub(".* at character ([0-9]+)$", "\\1", conditionMessage(res))))
  structure(FALSE, offset = if (is.na(off)) NA_integer_ else off, err = conditionMessage(res))
}

# ================================================================ text tools

#' Rewrites JSON text indented or compact, as yajl's generator does.
#'
#' Tokenizer + yajl-style generator: strings are decoded and re-encoded
#' (so a "\u00e9" escape comes out as the character it names, and "\/" as
#' "/"), numbers are copied verbatim, and the beautifier follows yajl_gen
#' exactly (newline after every opener, ",\n" between items, ": " after
#' keys, final newline).
#' @param txt The JSON text; lines are joined with newlines.
#' @param pretty Whether the output is indented.
#' @param indent_string The text of one indent level.
#' @return The JSON text, of class `json`.
#' @noRd
.rmbl_json_reformat <- function(txt, pretty, indent_string = "    ") {
  s <- paste(txt, collapse = "\n")
  s <- .rmbl_strip_bom(s)
  ch <- strsplit(s, "", fixed = TRUE)[[1]]
  n <- length(ch)
  p <- new.env(parent = emptyenv())   # the cursor, the output and the state machine
  p$i <- 1L
  p$out <- character(0)
  p$depth <- 0L
  p$state <- "start"        # start | array_start | in_array | map_start | map_key | map_val | complete
  p$stack <- character(0)
  bad <- function(msg) stop(sprintf("%s at character %d", msg, p$i), call. = FALSE)
  emit <- function(t) p$out <- c(p$out, t)
  p$need_sep <- FALSE
  sep <- function() {
    if (p$state == "map_key" || p$state == "in_array") {
      if (p$need_sep) bad("expected ',' between values")
      emit(",")
      if (pretty) emit("\n")
    } else if (p$state == "map_val") {
      emit(":")
      if (pretty) emit(" ")
    }
  }
  wsp <- function() if (pretty && p$state != "map_val" && p$depth > 0L) emit(strrep(indent_string, p$depth))
  atom_done <- function() {
    p$state <- switch(p$state, start = "complete", map_start = "map_val", map_key = "map_val",
                     array_start = "in_array", map_val = "map_key", p$state)
    p$need_sep <- p$state %in% c("in_array", "map_key")
  }
  skip_ws <- function() while (p$i <= n && (ch[p$i] == " " || ch[p$i] == "\t" || ch[p$i] == "\n" || ch[p$i] == "\r")) p$i <- p$i + 1L
  read_string <- function() {
    j <- p$i + 1L
    q <- new.env(parent = emptyenv())
    q$parts <- character(32L)
    q$np <- 0L
    push <- function(v) {
      q$np <- q$np + 1L
      if (q$np > length(q$parts)) length(q$parts) <- 2L * length(q$parts)
      q$parts[q$np] <- v
    }
    st <- j
    repeat {
      if (j > n) bad("unterminated string")
      c0 <- ch[j]
      if (c0 == "\"") break
      if (c0 == "\\") {
        if (j > st) push(paste(ch[st:(j - 1L)], collapse = ""))
        j <- j + 1L
        e <- ch[j]
        if (e == "u") {
          cp <- strtoi(paste(ch[(j + 1L):(j + 4L)], collapse = ""), 16L)
          if (is.na(cp)) bad("invalid \\u escape")
          j <- j + 4L
          if (cp >= 0xD800 && cp <= 0xDBFF && j + 6L <= n && ch[j + 1L] == "\\" && ch[j + 2L] == "u") {
            lo <- strtoi(paste(ch[(j + 3L):(j + 6L)], collapse = ""), 16L)
            if (!is.na(lo) && lo >= 0xDC00 && lo <= 0xDFFF) {
              j <- j + 6L
              cp <- 0x10000 + (cp - 0xD800) * 1024 + (lo - 0xDC00)
            }
          }
          if (cp == 0) bad("NUL in string")
          if (cp >= 0xD800 && cp <= 0xDFFF) bad("lone surrogate escape")
          push(intToUtf8(cp))
        } else {
          push(switch(e, n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", "\"" = "\"", "\\" = "\\", "/" = "/", bad("invalid escape")))
        }
        j <- j + 1L
        st <- j
        next
      }
      j <- j + 1L
    }
    if (j > st) push(paste(ch[st:(j - 1L)], collapse = ""))
    p$i <- j + 1L
    paste(q$parts[seq_len(q$np)], collapse = "")
  }
  encode_string <- function(v) {
    v <- gsub("\\", "\\\\", v, fixed = TRUE)
    v <- gsub("\"", "\\\"", v, fixed = TRUE)
    v <- gsub("\n", "\\n", v, fixed = TRUE)
    v <- gsub("\r", "\\r", v, fixed = TRUE)
    v <- gsub("\t", "\\t", v, fixed = TRUE)
    v <- gsub("\b", "\\b", v, fixed = TRUE)
    v <- gsub("\f", "\\f", v, fixed = TRUE)
    v <- gsub("</", "<\\/", v, fixed = TRUE)
    for (cc in c(1:7, 11L, 14:31)) {
      c1 <- rawToChar(as.raw(cc))
      if (grepl(c1, v, fixed = TRUE, useBytes = TRUE)) v <- gsub(c1, sprintf("\\u%04X", cc), v, fixed = TRUE, useBytes = TRUE)
    }
    paste0("\"", v, "\"")
  }
  read_number <- function() {
    st <- p$i
    if (ch[p$i] == "-") p$i <- p$i + 1L
    if (p$i > n || !grepl("[0-9]", ch[p$i])) bad("invalid number")
    while (p$i <= n && grepl("[0-9.eE+-]", ch[p$i])) p$i <- p$i + 1L
    paste(ch[st:(p$i - 1L)], collapse = "")
  }
  while (TRUE) {
    skip_ws()
    if (p$i > n) break
    if (p$state == "complete") bad("trailing content")
    c0 <- ch[p$i]
    if (c0 == "{" || c0 == "[") {
      if (p$state %in% c("map_key", "map_start")) bad("keys must be strings")
      sep()
      wsp()
      p$depth <- p$depth + 1L
      p$stack <- c(p$stack, p$state)
      p$state <- if (c0 == "{") "map_start" else "array_start"
      emit(c0)
      if (pretty) emit("\n")
      p$i <- p$i + 1L
      next
    }
    if (c0 == "}" || c0 == "]") {
      if ((c0 == "}" && !(p$state %in% c("map_start", "map_key"))) || (c0 == "]" && !(p$state %in% c("array_start", "in_array")))) bad("unexpected closing bracket")
      p$depth <- p$depth - 1L
      if (pretty) emit("\n")
      p$state <- p$stack[length(p$stack)]
      p$stack <- p$stack[-length(p$stack)]
      atom_done()
      wsp()
      emit(c0)
      if (pretty && p$state == "complete") emit("\n")
      p$i <- p$i + 1L
      next
    }
    if (c0 == ",") {
      if (!(p$state %in% c("in_array", "map_key"))) bad("unexpected ','")
      p$need_sep <- FALSE
      p$i <- p$i + 1L
      skip_ws()
      if (p$i > n || ch[p$i] %in% c("]", "}")) bad("trailing comma")
      next
    }
    if (c0 == ":") {
      if (p$state != "map_val") bad("unexpected ':'")
      p$i <- p$i + 1L
      next
    }
    if (c0 == "\"") {
      v <- read_string()
      if (p$state %in% c("map_start", "map_key")) {
        # key
        if (p$state == "map_key") {
          if (p$need_sep) bad("expected ',' between members")
          emit(",")
          if (pretty) emit("\n")
        }
        wsp()
        emit(encode_string(v))
        p$state <- "map_val"
        skip_ws()
        if (p$i > n || ch[p$i] != ":") bad("expected ':'")
        next
      }
      sep()
      wsp()
      emit(encode_string(v))
      atom_done()
      if (pretty && p$state == "complete") emit("\n")
      next
    }
    if (p$state %in% c("map_key", "map_start")) bad("keys must be strings")
    if (c0 == "t" && identical(substr(s, p$i, p$i + 3L), "true")) {
      p$i <- p$i + 4L
      tok <- "true"
    } else if (c0 == "f" && identical(substr(s, p$i, p$i + 4L), "false")) {
      p$i <- p$i + 5L
      tok <- "false"
    } else if (c0 == "n" && identical(substr(s, p$i, p$i + 3L), "null")) {
      p$i <- p$i + 4L
      tok <- "null"
    } else if (c0 == "-" || grepl("[0-9]", c0)) {
      tok <- read_number()
    } else {
      bad("unexpected character")
    }
    sep()
    wsp()
    emit(tok)
    atom_done()
    if (pretty && p$state == "complete") emit("\n")
  }
  if (p$state != "complete") bad("unexpected end of input")
  # paste() drops the encoding mark; JSON is UTF-8 by definition (RFC 8259
  # section 8.1), so declare it. Declare, do not convert: enc2utf8() under a
  # C locale would re-encode the bytes as Latin-1.
  res <- paste(p$out, collapse = "")
  Encoding(res) <- "UTF-8"
  structure(res, class = "json")
}

#' Indent JSON text (jsonlite's prettify)
#'
#' @param txt JSON text.
#' @param indent spaces per level (negative = tabs).
#' @return the same JSON, indented, with a trailing newline.
#' @noRd
bricklayer_json_prettify <- function(txt, indent = 4) {
  stopifnot(is.numeric(indent))
  indent_string <- strrep(if (indent > 0) " " else "\t", as.integer(abs(indent)))
  .rmbl_json_reformat(txt, TRUE, indent_string)
}

#' Strip whitespace from JSON text (jsonlite's minify)
#'
#' @param txt JSON text.
#' @return the same JSON with no whitespace outside strings.
#' @noRd
bricklayer_json_minify <- function(txt) .rmbl_json_reformat(txt, FALSE)

#' Expand nested data.frame columns (jsonlite's flatten)
#'
#' @param x a data.frame.
#' @param recursive expand nested frames all the way down.
#' @return a data.frame whose nested columns became outer.inner columns.
#' @noRd
bricklayer_json_flatten <- function(x, recursive = TRUE) {
  stopifnot(is.data.frame(x))
  nr <- nrow(x)
  dfcols <- vapply(x, is.data.frame, logical(1))
  if (!any(dfcols)) return(x)
  x <- if (recursive) c(x[!dfcols], do.call(c, lapply(x[dfcols], bricklayer_json_flatten)))
       else c(x[!dfcols], do.call(c, x[dfcols]))
  class(x) <- "data.frame"
  row.names(x) <- if (!nr) character(0) else 1:nr
  x
}

# ================================================================ streaming

#' Stream newline-delimited JSON (jsonlite's stream_in / stream_out)
#'
#' @param con a connection (opened in binary mode if not already
#' open).
#' @param handler optional function called on each
#' simplified page.
#' @param pagesize records per page.
#' @param verbose print progress.
#' @param ... passed to the simplifier / encoder.
#' @return `stream_in`: a data.frame of all records (or nothing with a
#' handler); `stream_out`: invisible.
#' @noRd
bricklayer_json_stream_in <- function(con, handler = NULL, pagesize = 500, verbose = TRUE, ...) {
  if (!inherits(con, "connection")) stop("Argument 'con' must be a connection.", call. = FALSE)
  acc <- new.env(parent = emptyenv())
  acc$count <- 0
  acc$pages <- list()
  cb <- if (is.null(handler)) {
    function(x) {
      if (length(x)) {
        acc$count <- acc$count + length(x)
        acc$pages[[length(acc$pages) + 1L]] <- x
      }
    }
  } else {
    if (verbose) message("using a custom handler function.")
    function(x) {
      handler(.rmbl_json_post_process(x, ...))
      acc$count <- acc$count + length(x)
    }
  }
  if (!isOpen(con, "r")) {
    if (verbose) message("opening ", class(con)[1L], " input connection.")
    open(con, "rb")
    on.exit({
      if (verbose) message("closing ", class(con)[1L], " input connection.")
      close(con)
    }, add = TRUE)
  }
  repeat {
    page <- readLines(con, n = pagesize, encoding = "UTF-8")
    if (length(page)) {
      cleanpage <- Filter(nchar, page)
      cb(lapply(cleanpage, .rmbl_json_parse))
      if (verbose) cat("\r Found", acc$count, "records...")
    }
    if (length(page) < pagesize) break
  }
  if (is.null(handler)) {
    if (verbose) cat("\r Imported", acc$count, "records. Simplifying...\n")
    .rmbl_json_post_process(unlist(acc$pages, FALSE, FALSE), ...)
  } else {
    invisible()
  }
}
#' Simplifies the records read from a stream into a data frame.
#' @param x The parsed records.
#' @param simplifyVector Whether arrays of scalars become vectors.
#' @param simplifyDataFrame Whether arrays of records become data frames.
#' @param simplifyMatrix Whether arrays of equal-length vectors become matrices.
#' @param flatten Whether nested data frames are flattened.
#' @return A data frame, or the simplified list when `simplifyDataFrame` is FALSE.
#' @noRd
.rmbl_json_post_process <- function(x, simplifyVector = TRUE, simplifyDataFrame = simplifyVector,
                                 simplifyMatrix = simplifyVector, flatten = FALSE) {
  out <- .rmbl_json_simplify(x, simplifyVector = simplifyVector, simplifyDataFrame = simplifyDataFrame,
                          simplifyMatrix = simplifyMatrix, flatten = flatten)
  if (isTRUE(simplifyDataFrame)) as.data.frame(out) else out
}
#' Writes a data frame as newline-delimited JSON, one record per line.
#'
#' @param x a data.frame to write, one record per line.
#' @param prefix text prepended to every line (e.g.
#' `" "` for RFC 7464).
#' @param con The connection, opened in binary mode if not already open.
#' @param pagesize The rows encoded at a time.
#' @param verbose Whether progress is printed.
#' @param ... Options of `tojs()`.
#' @return Nothing, invisibly.
#' @noRd
bricklayer_json_stream_out <- function(x, con = stdout(), pagesize = 500, verbose = TRUE, prefix = "", ...) {
  if (!inherits(con, "connection")) stop("Argument 'con' must be a connection.", call. = FALSE)
  stopifnot(is.data.frame(x))
  if (!isOpen(con, "w")) {
    if (verbose) message("opening ", class(con)[1L], " output connection.")
    open(con, "wb")
    on.exit({
      if (verbose) message("closing ", class(con)[1L], " output connection.")
      close(con)
    }, add = TRUE)
  }
  nr <- nrow(x)
  npages <- nr %/% pagesize
  lastpage <- nr %% pagesize
  write_page <- function(page) {
    str <- .rmbl_json_page_lines(page, ...)
    if (is.character(prefix) && length(prefix) && nchar(prefix)) str <- paste0(prefix[1L], str)
    writeLines(enc2utf8(str), con = con, useBytes = TRUE)
  }
  for (i in seq_len(npages)) {
    write_page(x[(pagesize * (i - 1) + 1):(pagesize * i), , drop = FALSE])
    if (verbose) cat("\rProcessed", i * pagesize, "rows...")
  }
  if (lastpage) write_page(x[(nr - lastpage + 1):nr, , drop = FALSE])
  if (verbose) cat("\rComplete! Processed total of", nr, "rows.\n")
  invisible()
}
#' Encodes each row of a data frame as one JSON record.
#' @param page The data frame.
#' @param ... Options of `tojs()`; `pretty` is dropped.
#' @return A character vector, one record per row.
#' @noRd
.rmbl_json_page_lines <- function(page, ...) {
  dots <- list(...)
  dots$pretty <- NULL
  # each row encodes as "[{...}]"; the record is what sits inside the brackets
  rows <- vapply(seq_len(nrow(page)), function(i) {
    as.character(do.call(tojs, c(list(page[i, , drop = FALSE]), dots)))
  }, character(1))
  substr(rows, 2L, nchar(rows) - 1L)
}

#' Row-bind a list of data.frames with differing columns (jsonlite's
#' rbind_pages)
#'
#' @param pages a list of data.frames (NULL entries are
#' dropped).
#' @return one data.frame; missing columns are filled with NA.
#' @noRd
bricklayer_json_rbind_pages <- function(pages) {
  stopifnot(is.list(pages))
  pages <- Filter(Negate(is.null), pages)
  stopifnot(all(vapply(pages, is.data.frame, logical(1))))
  if (!length(pages)) return(data.frame())
  cols <- unique(unlist(lapply(pages, names)))
  filled <- lapply(pages, function(p) {
    for (nm in setdiff(cols, names(p))) p[[nm]] <- rep(NA, nrow(p))
    p[cols]
  })
  out <- do.call(rbind, c(filled, list(make.row.names = FALSE, stringsAsFactors = FALSE)))
  row.names(out) <- NULL
  out
}

# ================================================================ serialize

#' Turns an R object into the list `jsser()` writes: its type, attributes and value.
#' @param obj The object.
#' @return A list with `type`, `attributes` and `value`.
#' @noRd
.rmbl_json_pack <- function(obj) {
  mode <- typeof(obj)
  if (mode == "NULL") return(list(type = bricklayer_json_unbox("NULL")))
  if (mode == "closure") obj <- as.list(obj)
  if (mode == "environment" && isNamespace(obj)) mode <- "namespace"
  attrib <- attributes(obj)
  if (isS4(obj)) {
    mode <- "S4"
    sn <- methods::slotNames(obj)
    if (".Data" %in% sn) attrib[[".Data"]] <- obj@.Data
    attrib <- attrib[sn]
    names(attrib) <- sn
  }
  value <- switch(mode,
    environment = NULL, externalptr = NULL,
    namespace = lapply(as.list(getNamespaceInfo(obj, "spec")), bricklayer_json_unbox),
    S4 = list(class = bricklayer_json_unbox(class(obj)), package = bricklayer_json_unbox(attr(class(obj), "package"))),
    raw = bricklayer_json_unbox(jsb64enc(unclass(obj))),
    logical = as.vector(unclass(obj), mode = "logical"),
    integer = as.vector(unclass(obj), mode = "integer"),
    numeric = , double = as.vector(unclass(obj), mode = "double"),
    character = as.vector(unclass(obj), mode = "character"),
    complex = as.vector(unclass(obj), mode = "complex"),
    list = unname(lapply(unclass(obj), .rmbl_json_pack)),
    pairlist = unname(lapply(as.vector(obj, mode = "list"), .rmbl_json_pack)),
    closure = unname(lapply(obj, .rmbl_json_pack)),
    builtin = , special = bricklayer_json_unbox(jsb64enc(serialize(unclass(obj), NULL))),
    language = , name = , symbol = deparse(unclass(obj)),
    expression = deparse(obj[[1L]]),
    {
      warning("No encoding has been defined for objects with storage mode ", mode, " and will be skipped.")
      NULL
    })
  list(type = bricklayer_json_unbox(mode),
       attributes = structure(lapply(attrib, .rmbl_json_pack), names = as.character(names(attrib))),
       value = value)
}
#' Rebuilds an R object from the list `jsser()` wrote.
#' @param obj The list, as parsed.
#' @param trusted Whether code-bearing types (functions, calls, namespaces, S4 objects) may be rebuilt.
#' @return The object.
#' @noRd
.rmbl_json_unpack <- function(obj, trusted = FALSE) {
  mode <- obj$type
  if (identical(mode, "NULL")) return(NULL)
  # unserialize() on supplied bytes, parse() on supplied text,
  # getNamespace() (which runs a package's .onLoad) and an S4 initialize
  # method all execute code the JSON's author chose: untrusted JSON gets
  # data types only
  if (!isTRUE(trusted) && mode %in% c("S4", "namespace", "closure", "special",
                                      "builtin", "language", "expression")) {
    stop(sprintf(paste0("jsunser() refuses to rebuild a '%s' ",
                        "from JSON it did not write: that would run code chosen ",
                        "by the file's author. Pass trusted = TRUE only for JSON ",
                        "produced by jsser() in your own session."),
                 mode), call. = FALSE)
  }
  if (identical(mode, "S4")) {
    data <- lapply(obj$attributes, .rmbl_json_unpack, trusted = trusted)
    return(do.call(methods::new, c(Class = obj$value$class, data)))
  }
  vals <- obj$value
  newdata <- list(.Data = switch(mode,
    environment = new.env(parent = emptyenv()),
    namespace = getNamespace(obj$value$name),
    externalptr = NULL,
    raw = jsb64dec(vals),
    logical = as.logical(.rmbl_json_list_to_vec(vals)),
    integer = as.integer(.rmbl_json_list_to_vec(vals)),
    numeric = , double = as.double(.rmbl_json_list_to_vec(vals)),
    character = as.character(.rmbl_json_list_to_vec(vals)),
    complex = as.complex(.rmbl_json_list_to_vec(vals)),
    list = , pairlist = , closure = lapply(vals, .rmbl_json_unpack, trusted = trusted),
    symbol = , name = if (identical(unlist(vals), "")) quote(expr = ) else as.name(unlist(vals)),
    expression = parse(text = unlist(vals)),
    language = as.call(parse(text = unlist(vals)))[[1L]],
    special = , builtin = unserialize(jsb64dec(vals)),
    stop("Switch falling through for encode.mode: ", mode, call. = FALSE)))
  # a missing formal comes back as the empty symbol; it must not be evaluated
  if (identical(newdata[[1L]], substitute())) return(substitute())
  attrs <- lapply(obj$attributes, .rmbl_json_unpack, trusted = trusted)
  output <- do.call("structure", c(newdata, attrs), quote = TRUE)
  if (mode == "closure") {
    f <- as.function(output)
    environment(f) <- globalenv()
    return(f)
  }
  if (mode == "pairlist") return(as.pairlist(output))
  output
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
#' @examples
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
    stop("`txt` is not JSON written by jsser() (an object with a type)", call. = FALSE)
  }
  .rmbl_json_unpack(obj, trusted = isTRUE(trusted))
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
  if (is.na(e)) return(NULL)
  mp <- strsplit(mant, ".", fixed = TRUE)[[1L]]
  digits <- paste0(mp, collapse = "")
  frac <- if (length(mp) > 1L) nchar(mp[2L]) else 0L
  scale <- e - frac
  if (scale >= 0L) {
    digits <- paste0(digits, strrep("0", scale))
  } else {
    cut <- substr(digits, nchar(digits) + scale + 1L, nchar(digits))
    if (grepl("[1-9]", cut)) return(NULL)
    digits <- substr(digits, 1L, nchar(digits) + scale)
  }
  digits <- sub("^0+", "", digits)
  if (!nzchar(digits)) "0" else digits
}
