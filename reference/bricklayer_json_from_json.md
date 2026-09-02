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
