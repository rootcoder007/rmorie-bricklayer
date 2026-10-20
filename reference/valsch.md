# Validate a Data Frame Against a Provenance Schema

Checks a data frame against the `schema` block of a provenance record:
required columns, row-count bounds, column types, numeric ranges,
missingness and allowed category values. It returns the problems it
finds instead of stopping, so the caller can log them, show them, or
pass the same schema to
[`schval()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schval.md),
the wrapper that turns them into errors and warnings. Use it each time a
file is re-downloaded, to catch a re-release that renamed, retyped or
recoded a column.

## Usage

``` r
valsch(dfraw, prov)
```

## Arguments

- dfraw:

  The data frame to validate.

- prov:

  A provenance list as returned by
  [`loadprov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loadprov.md),
  or `list(schema = infsch(df))`. The `schema` block may contain:

  - `expected_columns` – required column names (character). A missing
    one is `"fatal"`; everything else below is a `"warning"`.

  - `structural_invariants` – a list with `min_data_rows` and
    `max_data_rows` (numbers of rows).

  - `expected_value_sets` – a named list of allowed values per column.

  - `expected_types` – a named character vector of expected classes.
    `integer`, `numeric` and `double` are treated as interchangeable,
    since a re-release legitimately widens one to another.

  - `numeric_ranges` – a named list of `c(min =, max =)` bounds.

  - `max_missing_fraction` – a named numeric of per-column ceilings on
    the share of `NA`, between 0 and 1.

  [`infsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infsch.md)
  produces all six from data you already trust.

## Value

A named list of issues; each issue is a list with `severity` (`"fatal"`
or `"warning"`) and a human-readable `message`. The names are those
listed in Details. A zero-length list means the data frame is clean.

## Details

Every schema field is optional and is checked only when present, so a
schema written for an earlier version keeps working unchanged.

This is the STRUCTURAL check – names, types, bounds, value sets. It
cannot tell you that a column kept its name, type and range while its
distribution moved;
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
answers that. Rules that are particular to a data set (an age must be
non-negative, two dates must be ordered) belong in
[`rul()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rul.md)
and
[`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md).

The checks, and the name of the issue each one adds:

- a missing `expected_columns` entry: `missing_columns`, `"fatal"`;

- fewer than `min_data_rows` rows: `row_count_low`;

- more than `max_data_rows` rows: `row_count_high`;

- a column whose class differs from `expected_types`: `type_<col>`.
  `integer`, `numeric` and `double` are one family, and so are
  `character` and `factor`;

- non-missing values outside `numeric_ranges` (inclusive bounds;
  non-numeric columns are skipped): `range_<col>`;

- a share of `NA` above `max_missing_fraction`: `missing_<col>`;

- values not in `expected_value_sets`: `unexpected_<col>`.

A column that a check names but the data lack is skipped by that check.
Only the `expected_columns` check reports such a column. All of these
are `"warning"` except `missing_columns`.

The schema itself is checked too. An empty schema
([`list()`](https://rdrr.io/r/base/list.html)) gives one `schema_empty`
warning. An unknown field name within three edits of a known one
(`expected_colums`) is `"fatal"`, because it would otherwise be ignored
silently; any other unknown name is a warning. An unknown structural
invariant one edit, or one swap of neighbouring letters, away from
`min_data_rows` or `max_data_rows` is fatal; other invariant names are
left alone. `expected_dtypes` is accepted as another name for
`expected_types`, and `synthetic_recipe` is a known field that is not
checked here.

Errors: `dfraw` that is not a data frame; a `schema` that is not a list.
A `prov` that is `NULL` or has no `schema` returns an empty list (use
[`schval()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schval.md)
to make that an error).

## See also

[`infsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infsch.md)
to derive a schema,
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
for the distributional check,
[`schval()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schval.md)
to raise on the issues.

## Examples

``` r
prov <- list(schema = list(
  expected_columns      = c("id", "year"),
  structural_invariants = list(min_data_rows = 1),
  expected_value_sets   = list(year = 2020:2025)
))
df <- data.frame(id = 1:3, year = c(2020, 2021, 2030))
issues <- valsch(df, prov)
names(issues) # flags the out-of-set year value
#> [1] "unexpected_year"

# A column that silently changed type is caught.
typed <- list(schema = list(expected_types = c(id = "integer")))
valsch(data.frame(id = c("1", "2")), typed)[[1]]$message
#> [1] "Column 'id' is character, expected integer"

# So is a value outside its pinned range, and excess missingness.
ranged <- list(schema = list(numeric_ranges = list(v = c(min = 0, max = 1))))
valsch(data.frame(v = c(0.5, 9)), ranged)[[1]]$message
#> [1] "Column 'v' has 1 value(s) outside [0, 1]"

gappy <- list(schema = list(max_missing_fraction = c(v = 0.1)))
valsch(data.frame(v = c(1, NA, NA, 4)), gappy)[[1]]$message
#> [1] "Column 'v' is 50.0% missing, above the expected 10.0%"

# A clean frame produces nothing.
length(valsch(data.frame(id = 1:3, year = 2021), prov))
#> [1] 0

# a misspelt schema field is fatal rather than silently ignored
valsch(df, list(schema = list(expcol = "id")))[[1]]
#> $severity
#> [1] "warning"
#> 
#> $message
#> [1] "schema field 'expcol' is not one valsch() uses: it was not checked"
#> 

# a schema inferred from trusted data, checked against a new release
sch <- infsch(data.frame(id = 1:3, year = 2020:2022))
names(valsch(data.frame(id = 1:2), list(schema = sch)))
#> [1] "missing_columns"

# the data must be a data frame
try(valsch(list(id = 1), prov))
#> Error : valsch: `dfraw` must be a data frame
```
