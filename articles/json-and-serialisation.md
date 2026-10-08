# JSON without jsonlite: parsing, encoding and exact serialisation

Manifests, provenance records and signed documents are JSON. The package
parses and writes JSON natively, in R with no parser dependency, with
jsonlite’s conventions, so a capsule has no dependency on another
package’s parser and the parser can be held to the same standard as the
cryptography.

## Encoding R objects

[`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md)
follows jsonlite’s `toJSON()` conventions (data frames as rows,
`auto_unbox`, `pretty`, `na` handling):

``` r

bricklayer_json_to_json(list(a = 1:3, b = "x"), auto_unbox = TRUE)
#> {"a":[1,2,3],"b":"x"}
bricklayer_json_to_json(data.frame(id = 1:2, v = c(1.5, NA)), pretty = TRUE)
#> [
#>   {
#>     "id": 1,
#>     "v": 1.5
#>   },
#>   {
#>     "id": 2
#>   }
#> ]
```

## Parsing JSON

[`bricklayer_json_from_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_from_json.md)
follows `fromJSON()`, with the simplification options:

``` r

txt <- '{"id":[1,2,3],"name":["a","b","c"],"ok":true}'
str(bricklayer_json_from_json(txt))
#> List of 3
#>  $ id  : int [1:3] 1 2 3
#>  $ name: chr [1:3] "a" "b" "c"
#>  $ ok  : logi TRUE
str(bricklayer_json_from_json(txt, simplifyVector = FALSE))
#> List of 3
#>  $ id  :List of 3
#>   ..$ : int 1
#>   ..$ : int 2
#>   ..$ : int 3
#>  $ name:List of 3
#>   ..$ : chr "a"
#>   ..$ : chr "b"
#>   ..$ : chr "c"
#>  $ ok  : logi TRUE
```

### A repeated key is an error

JSON permits duplicate keys and most parsers silently keep the last one,
which has been the root of several real vulnerabilities (two parsers
disagreeing about which value wins). Here a duplicate key is an error
unless you ask to keep it:

``` r

try(bricklayer_json_from_json('{"a":1,"a":2}'))
#> Error : duplicate key "a" at character 14
bricklayer_json_from_json('{"a":1,"a":2}', duplicate_keys = "keep")
#> $a
#> [1] 1
#> 
#> $a
#> [1] 2
```

### Big integers

Numbers beyond the exact range of a double are flagged, and can be
returned as text so no digit is lost:

``` r

bricklayer_json_from_json('{"id": 9007199254740993}', bigint_as_char = TRUE)
#> $id
#> [1] "9007199254740993"
```

## Exact serialisation: types and attributes included

Data JSON loses R’s structure: a factor becomes strings, a matrix
becomes nested arrays, a `Date` becomes text.
[`bricklayer_json_serialize()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_serialize.md)
writes an object *with* its type and attributes, so the round trip is
[`identical()`](https://rdrr.io/r/base/identical.html):

``` r

f <- factor(c("b", "a", "b"), levels = c("a", "b", "c"))
back <- bricklayer_json_unserialize(bricklayer_json_serialize(f))
identical(back, f)
#> [1] TRUE

m <- matrix(1:6, nrow = 2)
identical(bricklayer_json_unserialize(bricklayer_json_serialize(m)), m)
#> [1] TRUE

x <- list(a = 1:3, b = list(c = "x", d = NULL), e = TRUE)
identical(bricklayer_json_unserialize(bricklayer_json_serialize(x)), x)
#> [1] TRUE
```

Plain data JSON does not keep either, which is the trade-off:

``` r

bricklayer_json_to_json(f)
#> ["b","a","b"]
```

Doubles are rounded to `digits` by default; `I(17)` keeps them exact to
the last bit:

``` r

bricklayer_json_serialize(1 / 3)
#> {"type":"double","attributes":{},"value":[0.33333333]}
exact <- bricklayer_json_serialize(1 / 3, digits = I(17))
identical(bricklayer_json_unserialize(exact), 1 / 3)
#> [1] TRUE
```

The serialised form is text, so it can be pinned like any other:

``` r

core_sha256(bricklayer_json_serialize(m))
#> [1] "8ad8c97422a65fd2c22eb76f9ef58957b1456bdb941dac86dbe0cee57be7ac46"
```

## Compressed, base64 JSON

For embedding a table inside another document (a manifest field, a URL,
a signed record),
[`json_gzip_encode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_gzip.md)
gzips the JSON and base64-encodes the bytes:

``` r

x <- list(rows = data.frame(id = 1:50, value = round(stats::runif(50), 3)))
enc <- json_gzip_encode(x)
substring(enc, 1, 40)
#> [1] "H4sIAAAAAAAA/23UwUoEMQzG8XfpeZE0SZtmXkU8"
c(json = nchar(bricklayer_json_to_json(x)), gzip_b64 = nchar(enc))
#>     json gzip_b64 
#>     1193      393
identical(json_gzip_decode(enc)$rows$id, 1:50)
#> [1] TRUE
```

Base64 and base64url are available on their own:

``` r

bricklayer_json_base64_enc(charToRaw("manifest"))
#> [1] "bWFuaWZlc3Q="
rawToChar(bricklayer_json_base64_dec("bWFuaWZlc3Q="))
#> [1] "manifest"
```

## Why the parser is held to a security standard

Every network body, cached manifest and signature file the package reads
goes through this parser. It was reviewed for the classic parser
failures and each is tested: duplicate keys (above), string assembly
that was quadratic (250,000 escapes once took 16 minutes; it is linear
now), nesting depth, numbers that are not numbers, bytes that are not
UTF-8, and a body that is a bare URL, which is “not JSON”, never a
second fetch. The parser and the encoder are R code (see below), so they
run under R’s own memory management rather than a sanitizer; the test
suite carries the corpus of malformed inputs the review produced.
