# Base64 encoding

Encodes and decodes base64, in both the standard alphabet and the
URL-safe variant. Computed in R with no dependency, so a capsule can
embed binary content in a text manifest wherever this package runs.

## Usage

``` r
bricklayer_json_base64_enc(input)

bricklayer_json_base64_dec(input)

bricklayer_json_base64url_enc(input)

bricklayer_json_base64url_dec(input)
```

## Arguments

- input:

  For the encoders, a raw vector, or a character vector (its elements
  are joined with newlines and encoded as UTF-8 bytes), or `NULL`. For
  `bricklayer_json_base64_dec()`, base64 text (a character vector,
  joined with newlines) or its raw bytes. For
  `bricklayer_json_base64url_dec()`, URL-safe base64 text, with or
  without `=` padding.

## Value

The encoders return a character scalar (`""` for empty input,
`NA_character_` for `NULL`); the decoders return a raw vector (use
[`rawToChar()`](https://rdrr.io/r/base/rawConversion.html) for text).

## Details

`bricklayer_json_base64_enc()` breaks its output into 72-character lines
(a newline after each complete block of 54 input bytes), matching
jsonlite's encoder byte for byte; the decoder ignores line breaks, other
white space and `=` padding, so either form round trips. Any other
character outside the alphabet is an error rather than being skipped,
because skipping it would decode a corrupted body into a shorter
valid-looking one.

The URL-safe variant substitutes `-` and `_` for `+` and `/` and drops
the `=` padding, which is what makes it safe in a URL path, a query
string or a filename.

Base64 is an ENCODING, not encryption or a digest: it hides nothing and
anyone can reverse it. Use
[`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md)
to pin content and
[`core_hmac_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_keyed_digest.md)
to authenticate it.

Errors: an encoder given anything but a raw vector, a character vector
or `NULL`; `bricklayer_json_base64_dec()` given anything but text or raw
bytes, or text with a character outside the standard alphabet;
`bricklayer_json_base64url_dec()` given anything but character text (raw
bytes are refused), `NA`, or a character outside the URL-safe alphabet.

## See also

[`json_gzip_encode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_gzip.md),
which composes this with gzip.

## Examples

``` r
# Round trip through the standard alphabet.
b <- bricklayer_json_base64_enc("hello capsule")
b
#> [1] "aGVsbG8gY2Fwc3VsZQ=="
rawToChar(bricklayer_json_base64_dec(b))
#> [1] "hello capsule"

# Raw input works the same way.
bricklayer_json_base64_enc(charToRaw("abc"))
#> [1] "YWJj"
bricklayer_json_base64_dec(bricklayer_json_base64_enc(charToRaw("abc")))
#> [1] 61 62 63

# Padding appears when the length is not a multiple of three.
bricklayer_json_base64_enc("a")
#> [1] "YQ=="
bricklayer_json_base64_enc("ab")
#> [1] "YWI="
bricklayer_json_base64_enc("abc")
#> [1] "YWJj"

# The URL-safe variant has no "+", "/" or "=" to escape.
bricklayer_json_base64url_enc(as.raw(c(255, 224, 63)))
#> [1] "_-A_"
bricklayer_json_base64_enc(as.raw(c(255, 224, 63)))
#> [1] "/+A/"
bricklayer_json_base64url_dec(
  bricklayer_json_base64url_enc("path/safe?yes")
)
#>  [1] 70 61 74 68 2f 73 61 66 65 3f 79 65 73

# Long input is wrapped, and the decoder ignores the breaks.
long <- bricklayer_json_base64_enc(strrep("x", 200))
grepl("\n", long)
#> [1] TRUE
rawToChar(bricklayer_json_base64_dec(long)) == strrep("x", 200)
#> [1] TRUE

# A character outside the alphabet is refused, not skipped.
try(bricklayer_json_base64_dec("ab$c"))
#> Error : base64 input contains characters outside the alphabet
```
