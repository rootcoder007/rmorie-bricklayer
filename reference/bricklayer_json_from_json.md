# Parse JSON into R objects (jsonlite's fromJSON, natively)

Parse JSON into R objects (jsonlite's fromJSON, natively)

## Usage

``` r
bricklayer_json_from_json(
  txt,
  simplifyVector = TRUE,
  simplifyDataFrame = simplifyVector,
  simplifyMatrix = simplifyVector,
  flatten = FALSE,
  bigint_as_char = FALSE,
  simplify = NULL,
  duplicate_keys = c("error", "keep"),
  ...
)
```

## Arguments

- txt:

  JSON text, a file path, or an http(s) URL.

- simplifyVector, simplifyDataFrame, simplifyMatrix, flatten:

  as in jsonlite.

- bigint_as_char:

  integers beyond 2^53 come back as strings.

- simplify:

  legacy: `FALSE` turns every simplification off.

- duplicate_keys:

  What to do with an object that repeats a key: `"error"` (default)
  refuses the document, `"keep"` returns both values under the repeated
  name, as jsonlite does.

- ...:

  ignored, for call compatibility.

## Value

an R object.

## Examples

``` r
bricklayer_json_from_json('[{"a":1,"b":"x"},{"a":2,"b":"y"}]')
#>   a b
#> 1 1 x
#> 2 2 y
bricklayer_json_from_json('[[1,2],[3,4]]')
#>      [,1] [,2]
#> [1,]    1    2
#> [2,]    3    4
```
