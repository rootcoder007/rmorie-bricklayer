# Apply Schema Validation, Stopping on Fatal Issues

Runs
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
and acts on the result: fatal issues raise an error via
[`stop()`](https://rdrr.io/r/base/stop.html), warning-severity issues
emit a [`warning()`](https://rdrr.io/r/base/warning.html).

## Usage

``` r
apply_schema_validation(df_raw, provenance)
```

## Arguments

- df_raw:

  The data frame to validate.

- provenance:

  A provenance list as returned by
  [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md).

## Value

Invisibly, `TRUE` if no issues were found and `FALSE` otherwise. Errors
if any fatal issue is present.

## Examples

``` r
prov <- list(schema = list(expected_columns = "id"))
apply_schema_validation(data.frame(id = 1), prov)
# A missing required column is fatal:
try(apply_schema_validation(data.frame(x = 1), prov))
#> Error : Missing required columns: id
```
