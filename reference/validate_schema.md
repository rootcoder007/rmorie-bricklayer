# Validate a Data Frame Against a Provenance Schema

Checks a raw data frame against the `schema` block of a provenance
object: required columns, row-count bounds, and allowed categorical
value sets. Returns the issues found rather than raising, so the caller
decides how to react.

## Usage

``` r
validate_schema(df_raw, provenance)
```

## Arguments

- df_raw:

  The data frame to validate.

- provenance:

  A provenance list as returned by
  [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md).
  The `schema` block may contain `expected_columns`,
  `structural_invariants` (`min_data_rows`, `max_data_rows`), and
  `expected_value_sets` (a named list of allowed values per column).

## Value

A named list of issues; each issue is a list with `severity` (`"fatal"`
or `"warning"`) and a human-readable `message`. A zero-length list means
the data frame is clean.

## Examples

``` r
prov <- list(schema = list(
  expected_columns      = c("id", "year"),
  structural_invariants = list(min_data_rows = 1),
  expected_value_sets   = list(year = 2020:2025)
))
df <- data.frame(id = 1:3, year = c(2020, 2021, 2030))
issues <- validate_schema(df, prov)
names(issues)  # flags the out-of-set year value
#> [1] "unexpected_year"
```
