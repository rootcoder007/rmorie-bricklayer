# Encode an R object as JSON (jsonlite's toJSON, natively)

Converts R data (vectors, lists, data frames, matrices, dates, factors)
to JSON text, with the same options, the same defaults and the same
bytes out as jsonlite's `toJSON()`, but computed by this package's own
code, so manifests, provenance records and capsules can be written where
jsonlite is not installed and their digests stay the same either way.
Use it to write data for an API or a person; use
[`jsser()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/jsserdoc.md)
when the JSON must rebuild the exact R object (classes, factor levels,
attributes).

## Usage

``` r
tojs(
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
)
```

## Arguments

- x:

  The object to encode.

- dataframe:

  How a data frame is written: `"rows"` (the default, an array of
  records), `"columns"` (an object of column arrays) or `"values"` (an
  array of row arrays, without names).

- matrix:

  How a matrix is written. `"rowmajor"` (the default) gives an array of
  rows, and `"columnmajor"` an array of columns.

- Date:

  How a `Date` is written: `"ISO8601"` (the default, `"2024-01-02"`) or
  `"epoch"` (days since 1970-01-01).

- POSIXt:

  How a date-time is written: `"string"` (the default,
  `"2024-01-02 03:04:05"`), `"ISO8601"` (`"2024-01-02T03:04:05"`),
  `"epoch"` (milliseconds since 1970) or `"mongo"` (`{"$date": ms}`).

- factor:

  How a factor is written: `"string"` (the default, its labels) or
  `"integer"` (its codes).

- complex:

  How a complex number is written: `"string"` (the default, `"1+2i"`) or
  `"list"` (an object of `real` and `imaginary` arrays).

- raw:

  How a raw vector is written: `"base64"` (the default, one string),
  `"hex"`, `"mongo"`, `"int"` or `"js"`.

- null:

  How `NULL` inside a list is written: `"list"` (the default,
  [`{}`](https://rdrr.io/r/base/Paren.html); a round trip gives an empty
  list) or `"null"` (a JSON `null`).
  [`jsser()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/jsserdoc.md)
  round-trips `NULL` exactly.

- na:

  How missing values are written: `"null"` or `"string"` (`"NA"`). When
  `NULL` (the default), the per-type default of jsonlite applies (see
  Details).

- auto_unbox:

  Logical scalar, default `FALSE`: write length-one vectors as scalars
  (`1`) rather than arrays (`[1]`).

- digits:

  Numeric scalar, default `4`: decimal places kept for doubles. `I(n)`
  means `n` significant digits (`I(17)` writes every double exactly) and
  `NA` means 15 significant digits.

- pretty:

  `FALSE` (the default) for compact output, `TRUE` to indent by two
  spaces, or a number of spaces.

- force:

  Logical scalar, default `FALSE`: write objects that have no JSON form
  (as [`{}`](https://rdrr.io/r/base/Paren.html)) instead of failing.

- ...:

  Further options of jsonlite's `toJSON()` and of this package (see
  Details).

## Value

A character scalar of class `json`, the JSON text.

## Details

Atomic vectors become arrays, so a single value is `[1]` unless
`auto_unbox = TRUE`. Named lists become objects and unnamed lists
arrays. Missing values follow jsonlite: with `na` not given, a missing
number is written as the string `"NA"` and a missing string or logical
as `null`; in a data frame by rows a missing value is left out of its
record.

Further options of `toJSON()` are taken through `...`: `rownames`,
`keep_vec_names`, `json_verbatim`, `always_decimal`, `time_format`,
`UTC`, `no_dots`, `hms` (`"string"` or `"secs"`), and two of this
package's own: `keep_empty_names` (an empty-string key is written as
`""` rather than replaced by its position) and `quiet_vec_names` (no
message when `keep_vec_names` is used).
[`mnfcanon()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md)
uses both.

Errors: an option value not among its choices (the message lists them);
an object with no JSON form (a function, a symbol) unless
`force = TRUE`.

## See also

[`fromjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fromjs.md)
for the reverse,
[`jsser()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/jsserdoc.md)
for an exact round trip.

## Examples

``` r
tojs(list(a = 1:3, b = "x"), auto_unbox = TRUE)
#> {"a":[1,2,3],"b":"x"} 
tojs(data.frame(id = 1:2, v = c(1.5, NA)), pretty = TRUE)
#> [
#>   {
#>     "id": 1,
#>     "v": 1.5
#>   },
#>   {
#>     "id": 2
#>   }
#> ] 

# a data frame by columns, and a date-time in ISO 8601
df <- data.frame(id = 1:2, v = c(1.5, NA))
tojs(df, dataframe = "columns", na = "null")
#> {"id":[1,2],"v":[1.5,null]} 
tojs(as.POSIXct("2024-01-02 03:04:05", tz = "UTC"), POSIXt = "ISO8601")
#> ["2024-01-02T03:04:05"] 

# digits: decimal places by default, significant digits with I()
tojs(pi)
#> [3.1416] 
tojs(pi, digits = I(17))
#> [3.1415926535897931] 

# a choice that does not exist is refused
try(tojs(df, dataframe = "table"))
#> Error : tojs: `dataframe` must be one of "rows", "columns", "values", not "table"
```
