# Lossless JSON serialisation of an R object

Writes an R object to JSON with its type and attributes alongside the
value, so the round trip returns THE SAME OBJECT rather than something
that merely prints the same. The counterpart of jsonlite's
`serializeJSON()`/`unserializeJSON()`, computed by this package's own
codec with no jsonlite dependency.

## Usage

``` r
bricklayer_json_serialize(x, digits = 8, pretty = FALSE)

bricklayer_json_unserialize(txt)
```

## Arguments

- x:

  Object to serialise.

- digits:

  Decimal digits retained for doubles (default 8, the jsonlite default).
  Raise it where full precision matters.

- pretty:

  Indent the output.

- txt:

  JSON produced by `bricklayer_json_serialize()`.

## Value

`bricklayer_json_serialize()` returns a length-1 character vector of
class `json`; `bricklayer_json_unserialize()` returns the original
object.

## Details

Use this, not
[`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md),
whenever the JSON has to reconstruct the object faithfully.
[`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md)
writes the DATA – which is what an API or a human wants, and which loses
factor levels, matrix dimensions, classes and every other attribute.
These two keep them, at the cost of JSON no other tool will understand.

## See also

[`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md)
for plain data JSON,
[`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md)
for fingerprinting the result.

## Examples

``` r
# A factor survives the round trip with its levels intact.
f <- factor(c("b", "a", "b"), levels = c("a", "b", "c"))
back <- bricklayer_json_unserialize(bricklayer_json_serialize(f))
identical(back, f)
#> [1] TRUE

# So does a matrix, with its dimensions.
m <- matrix(1:6, nrow = 2)
identical(bricklayer_json_unserialize(bricklayer_json_serialize(m)), m)
#> [1] TRUE

# Plain data JSON does not keep either, which is the trade-off.
bricklayer_json_to_json(f)
#> ["b","a","b"] 

# Nested lists, names and NULLs round trip too.
x <- list(a = 1:3, b = list(c = "x", d = NULL), e = TRUE)
identical(bricklayer_json_unserialize(bricklayer_json_serialize(x)), x)
#> [1] TRUE

# The serialised form is JSON, so it can be pinned like any other text.
nchar(core_sha256(bricklayer_json_serialize(m)))
#> [1] 64
```
