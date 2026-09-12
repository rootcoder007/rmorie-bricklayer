# Validate a Data Frame Against a Provenance Schema

Checks a raw data frame against the `schema` block of a provenance
object and returns the issues found rather than raising, so the caller
decides how to react.
[`apply_schema_validation()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/apply_schema_validation.md)
is the wrapper that turns them into errors and warnings.

## Usage

``` r
validate_schema(df_raw, provenance)
```

## Arguments

- df_raw:

  The data frame to validate.

- provenance:

  A provenance list as returned by
  [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md),
  or `list(schema = infer_schema(df))`. The `schema` block may contain:

  - `expected_columns` – required column names. A missing one is
    `"fatal"`; everything else below is a `"warning"`.

  - `structural_invariants` – `min_data_rows` and `max_data_rows`.

  - `expected_value_sets` – a named list of allowed values per column.

  - `expected_types` – a named character vector of expected classes.
    `integer`, `numeric` and `double` are treated as interchangeable,
    since a re-release legitimately widens one to another.

  - `numeric_ranges` – a named list of `c(min =, max =)` bounds.

  - `max_missing_fraction` – a named numeric of per-column ceilings on
    the share of `NA`.

  [`infer_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infer_schema.md)
  produces all six from data you already trust.

## Value

A named list of issues; each issue is a list with `severity` (`"fatal"`
or `"warning"`) and a human-readable `message`. A zero-length list means
the data frame is clean.

## Details

Every schema field is optional and is checked only when present, so a
schema written for an earlier version keeps working unchanged.

This is the STRUCTURAL check – names, types, bounds, value sets. It
cannot tell you that a column kept its name, type and range while its
distribution moved;
[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
answers that.

## See also

[`infer_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infer_schema.md)
to derive a schema,
[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
for the distributional check,
[`apply_schema_validation()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/apply_schema_validation.md)
to raise on the issues.

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

# A column that silently changed type is caught.
typed <- list(schema = list(expected_types = c(id = "integer")))
validate_schema(data.frame(id = c("1", "2")), typed)[[1]]$message
#> [1] "Column 'id' is character, expected integer"

# So is a value outside its pinned range, and excess missingness.
ranged <- list(schema = list(numeric_ranges = list(v = c(min = 0, max = 1))))
validate_schema(data.frame(v = c(0.5, 9)), ranged)[[1]]$message
#> [1] "Column 'v' has 1 value(s) outside [0, 1]"

gappy <- list(schema = list(max_missing_fraction = c(v = 0.1)))
validate_schema(data.frame(v = c(1, NA, NA, 4)), gappy)[[1]]$message
#> [1] "Column 'v' is 50.0% missing, above the expected 10.0%"

# A clean frame produces nothing.
length(validate_schema(data.frame(id = 1:3, year = 2021), prov))
#> [1] 0
```
