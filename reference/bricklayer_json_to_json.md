# Encode an R object as JSON (jsonlite's toJSON, natively)

Every option of jsonlite's `toJSON()` with the same default and the same
bytes out: `dataframe`, `matrix`, `Date`, `POSIXt`, `factor`, `complex`,
`raw`, `null`, `na`, `auto_unbox`, `digits` (`I(n)` for significant
digits, `NA` for 15), `pretty` (TRUE = 2 spaces, or a width), `force`,
plus `rownames`, `keep_vec_names`, `json_verbatim`, `always_decimal`,
`time_format`, `UTC`, `no_dots`, `hms`.

## Usage

``` r
bricklayer_json_to_json(
  x,
  dataframe = c("rows", "columns", "values"),
  matrix = c("rowmajor", "columnmajor"),
  Date = c("ISO8601", "epoch"),
  POSIXt = c("string", "ISO8601", "epoch", "mongo"),
  factor = c("string", "integer"),
  complex = c("string", "list"),
  raw = c("base64", "hex", "mongo", "int", "js"),
  null = c("list", "null"),
  na = c("null", "string"),
  auto_unbox = FALSE,
  digits = 4,
  pretty = FALSE,
  force = FALSE,
  ...
)
```

## Arguments

- x:

  the object to encode.

- dataframe, matrix, Date, POSIXt, factor, complex, raw, null, na,
  auto_unbox, digits, pretty, force, ...:

  as in jsonlite.

## Value

a length-one character vector of class `json`.

## Examples

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
