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
