# Compressed, base64-encoded JSON

`json_gzip_encode()` serialises to JSON, compresses with gzip and
encodes the result as base64, so it can be embedded in another JSON
document, a header, or a text column. `json_gzip_decode()` reverses all
three steps.

## Usage

``` r
json_gzip_encode(x, raw = FALSE, ...)

json_gzip_decode(txt, raw = FALSE, ...)
```

## Arguments

- x:

  Object to encode.

- raw:

  Return (or accept) gzip bytes instead of base64.

- ...:

  Passed to
  [`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md).

- txt:

  Base64 string (or raw vector) from `json_gzip_encode()`.

## Value

`json_gzip_encode()` a length-1 character vector, or a raw vector when
`raw = TRUE`. `json_gzip_decode()` the decoded object.

## Details

JSON is highly compressible because every record repeats the key names,
so this is usually a large saving on anything record-shaped – but it is
opaque. Use it for payloads that travel, and plain
[`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md)
for anything a person is meant to read or a `git diff` is meant to show.

`raw = TRUE` skips the base64 step and returns the gzip bytes, which is
what to use when writing to a file rather than embedding in text.

## See also

[`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md),
[`bricklayer_json_serialize()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_serialize.md)
for a lossless but uncompressed form.

## Examples

``` r
x <- list(rows = data.frame(id = 1:50, value = stats::runif(50)))

enc <- json_gzip_encode(x)
substring(enc, 1, 40)
#> [1] "eJxV00tKxUAQBdC9ZPyQ+nR9OlsRB4IOBEFQ1MEj"

# Smaller than the JSON it came from, because the keys repeat.
c(json = nchar(bricklayer_json_to_json(x)), gzip_b64 = nchar(enc))
#>     json gzip_b64 
#>     1245      417 

# Round trips.
identical(json_gzip_decode(enc)$rows$id, 1:50)
#> [1] TRUE

# Raw gzip bytes, for writing to a file.
bytes <- json_gzip_encode(x, raw = TRUE)
class(bytes)
#> [1] "raw"
identical(json_gzip_decode(bytes, raw = TRUE)$rows$id, 1:50)
#> [1] TRUE
```
