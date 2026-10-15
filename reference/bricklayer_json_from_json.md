# Parse JSON into R objects (jsonlite's fromJSON, natively)

Reads JSON text, a JSON file or a JSON address on the web into R
objects, with the same simplification rules as jsonlite's `fromJSON()`:
an array of numbers becomes a numeric vector, an array of records a data
frame, an array of equal-length arrays a matrix. The parser is this
package's own, so it works without jsonlite, and it is stricter in two
places that matter for provenance records: a repeated key is an error by
default, and a whole number too large for a double is flagged.

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
  bigint_warn = TRUE,
  ...
)
```

## Arguments

- txt:

  JSON text (a character vector, joined with newlines), a file path, an
  `http(s)` URL, or a connection. A URL goes through the same check and
  the same transport as every other fetch in the package (public https
  host, redirects re-checked, body capped).

- simplifyVector:

  Logical scalar, default `TRUE`: turn arrays of scalars into atomic
  vectors.

- simplifyDataFrame:

  Logical scalar, default `simplifyVector`: turn arrays of records into
  data frames.

- simplifyMatrix:

  Logical scalar, default `simplifyVector`: turn arrays of equal-length
  arrays into matrices.

- flatten:

  Logical scalar, default `FALSE`: expand nested data frame columns into
  `outer.inner` columns.

- bigint_as_char:

  Logical scalar, default `FALSE`: integers beyond 2^53 come back as
  strings.

- simplify:

  Legacy, default `NULL`: `FALSE` turns every simplification off.

- duplicate_keys:

  What to do with an object that repeats a key: `"error"` (default)
  refuses the document, `"keep"` returns both values under the repeated
  name, as jsonlite does.

- bigint_warn:

  Logical scalar, default `TRUE`: warn (once per document) when a whole
  number beyond 2^53 is read into a double; the package's own readers of
  API payloads turn this off, since long numeric identifiers are routine
  there.

- ...:

  Ignored, for call compatibility with jsonlite.

## Value

An R object: a list, an atomic vector, a data frame, a matrix or `NULL`,
depending on the JSON and the simplification options.

## Details

A single string shorter than 2,084 bytes that is not valid JSON is taken
as a location: an `http(s)` address is fetched (a public `https` host
only, redirects re-checked, 60 second timeout, body capped at 16 MiB),
otherwise an existing file is read. Anything else is parsed as JSON
text; a character vector is joined with newlines. A connection is read
to its end (and closed when this call opened it).

Without simplification (`simplifyVector = FALSE`) objects become named
lists, arrays unnamed lists, `null` `NULL`, and numbers integer or
double. Whole numbers beyond \\2^{53}\\ cannot be held exactly in a
double: they are read as doubles with a warning, or kept as text with
`bigint_as_char = TRUE`.

Errors: `txt` not character or a connection; invalid JSON (the message
gives the character offset); a repeated key under
`duplicate_keys = "error"`; an address that is not a public `https`
host, that cannot be reached or that answers with an HTTP error.

## See also

[`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md)
for the reverse.

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

# no simplification: nested lists exactly as in the document
str(bricklayer_json_from_json('{"a": [1, 2], "b": {"c": null}}', simplifyVector = FALSE))
#> List of 2
#>  $ a:List of 2
#>   ..$ : int 1
#>   ..$ : int 2
#>  $ b:List of 1
#>   ..$ c: NULL

# from a file
f <- tempfile(fileext = ".json")
writeLines('[{"a":1},{"a":2,"b":"x"}]', f)
bricklayer_json_from_json(f)
#>   a    b
#> 1 1 <NA>
#> 2 2    x

# a large identifier kept exactly, as text
bricklayer_json_from_json('[12345678901234567890]', bigint_as_char = TRUE)
#> [1] "12345678901234567890"

# a repeated key is refused unless asked for
try(bricklayer_json_from_json('{"a": 1, "a": 2}'))
#> Error : duplicate key "a" at character 17
bricklayer_json_from_json('{"a": 1, "a": 2}', duplicate_keys = "keep")
#> $a
#> [1] 1
#> 
#> $a
#> [1] 2
#> 
```
