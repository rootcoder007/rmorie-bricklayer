# Compressed, base64-encoded JSON

`jsgzenc()` serialises to JSON, compresses with gzip and encodes the
result as base64, so it can be embedded in another JSON document, a
header, or a text column. `jsgzdec()` reverses all three steps.

## Usage

``` r
jsgzenc(x, raw = FALSE, ...)

jsgzdec(txt, raw = FALSE, ...)
```

## Arguments

- x:

  Object to encode.

- raw:

  Logical scalar, default `FALSE`: return (or, for the decoder, insist
  on) gzip bytes instead of base64 text.

- ...:

  For `jsgzenc()`, passed to
  [`tojs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tojs.md)
  (for example `auto_unbox` or `digits`); for `jsgzdec()`, passed to
  [`fromjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fromjs.md)
  (for example `simplifyVector`).

- txt:

  Base64 string (or raw vector of gzip bytes) from `jsgzenc()`.

## Value

`jsgzenc()` a length-1 character vector, or a raw vector when
`raw = TRUE`. `jsgzdec()` the decoded object, as
[`fromjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fromjs.md)
returns it.

## Details

JSON is highly compressible because every record repeats the key names,
so this is usually a large saving on anything record-shaped – but it is
opaque. Use it for payloads that travel, and plain
[`tojs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tojs.md)
for anything a person is meant to read or a `git diff` is meant to show.

`raw = TRUE` skips the base64 step and returns the gzip bytes, which is
what to use when writing to a file rather than embedding in text.

The bytes are a real gzip member (RFC 1952, with header bytes `1f 8b`),
readable by `gzip -d`, `zcat` and any HTTP client, not the zlib stream
that `memCompress(type = "gzip")` returns. The modification time in the
header is zero, so the same input always gives the same bytes and a
digest of the result does not depend on the clock. The base64 text uses
the standard alphabet with line breaks every 72 characters
([`jsb64enc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/b64.md)).

The decoder takes the input's own type: a raw vector is read as gzip
bytes whatever `raw` says, and text as base64. As a guard against
decompression bombs it refuses a member whose declared uncompressed size
is over 64 MiB. Errors: text given with `raw = TRUE`; text that is not
base64; bytes that are not a gzip member (under 18 bytes or not starting
`1f 8b`); a declared size over 64 MiB; a corrupt member; invalid JSON
inside.

Note that the JSON keeps data, not R types: a factor comes back as text
and attributes are lost. Compress
[`jsser()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/jsserdoc.md)
output when the object must come back exactly.

## See also

[`tojs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tojs.md),
[`jsser()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/jsserdoc.md)
for an uncompressed form that keeps types and attributes.

## Examples

``` r
x <- list(rows = data.frame(id = 1:50, value = stats::runif(50)))

enc <- jsgzenc(x)
substring(enc, 1, 40)
#> [1] "H4sIAAAAAAAA/1XSTUoEMRAF4LtkPUj9ppK+irgQ"

# Smaller than the JSON it came from, because the keys repeat.
c(json = nchar(tojs(x)), gzipb64 = nchar(enc))
#>    json gzipb64 
#>    1244     429 

# Round trips.
identical(jsgzdec(enc)$rows$id, 1:50)
#> [1] TRUE

# Raw gzip bytes, for writing to a file.
bytes <- jsgzenc(x, raw = TRUE)
class(bytes)
#> [1] "raw"
identical(jsgzdec(bytes, raw = TRUE)$rows$id, 1:50)
#> [1] TRUE

# the bytes are ordinary gzip: a file any gzip tool can read
f <- tempfile(fileext = ".json.gz")
writeBin(bytes, f)
substr(readLines(gzfile(f), warn = FALSE), 1, 40)
#> [1] "{\"rows\":[{\"id\":1,\"value\":0.28},{\"id\":2,\""

# options pass through to the JSON writer and reader
jsgzdec(jsgzenc(list(a = 1, b = "x"), auto_unbox = TRUE),
                 simplifyVector = FALSE)
#> $a
#> [1] 1
#> 
#> $b
#> [1] "x"
#> 

# text that is not a gzip member is refused
try(jsgzdec(jsb64enc("not gzip")))
#> Error : `txt` does not hold a gzip member: expected at least 18 bytes starting 1f 8b, got 8 byte(s).
```
