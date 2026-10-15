# Drop empty or constant columns and rows

`drop_empty()` removes rows or columns that are entirely missing.
`drop_constant()` removes columns that hold a single distinct value. The
counterparts of `janitor::remove_empty()` and
`janitor::remove_constant()`. Use them after reading a spreadsheet
export, which often carries blank padding rows, empty columns and
columns that repeat one value (a year, a jurisdiction) on every row.

## Usage

``` r
drop_empty(data, which = c("rows", "cols"))

drop_constant(data, na_as_value = FALSE)
```

## Arguments

- data:

  A data frame.

- which:

  `"rows"`, `"cols"`, or both (the default, `c("rows", "cols")`).

- na_as_value:

  Logical: treat `NA` as a distinct value, so a column of `NA`s plus one
  real value counts as two (default `FALSE`).

## Value

The data frame, with the offending rows or columns removed. The names of
the columns that were dropped are attached as the `"dropped"` attribute
(a character vector, empty when none); dropped rows are not listed.

## Details

A constant column carries no information and breaks anything that scales
by variance, so it is worth removing – but it is also a FINDING. A
column that was informative in the pinned capsule and is constant in a
fresh fetch means the source changed, so check
[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
before deleting it and moving on.

`drop_empty()` removes all-`NA` columns first, then all-`NA` rows among
the remaining columns, and resets the row names. An empty string is a
value, not missing. `drop_constant()` counts the distinct non-missing
values of each column (with `na_as_value = TRUE`, `NA` counts as a
value), so an all-`NA` column is also dropped by default. Neither
function modifies anything in place.

Errors: `data` not a data frame (or with missing or duplicated names);
`which` other than `"rows"` and/or `"cols"`.

## See also

[`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md),
which reports `n_distinct` without removing anything.

## Examples

``` r
df <- data.frame(
  keep = c(1, 2, NA),
  all_na = c(NA, NA, NA),
  constant = c(7, 7, 7),
  stringsAsFactors = FALSE
)

drop_empty(df)
#>   keep constant
#> 1    1        7
#> 2    2        7
#> 3   NA        7
attr(drop_empty(df), "dropped")
#> [1] "all_na"

drop_constant(df)
#>   keep
#> 1    1
#> 2    2
#> 3   NA
attr(drop_constant(df), "dropped")
#> [1] "all_na"   "constant"

# Rows only.
drop_empty(data.frame(a = c(1, NA), b = c(2, NA)), which = "rows")
#>   a b
#> 1 1 2

# A column of NAs plus one value is constant by default, and not when
# NA is treated as a value of its own.
x <- data.frame(v = c(NA, NA, 5))
ncol(drop_constant(x))
#> [1] 0
ncol(drop_constant(x, na_as_value = TRUE))
#> [1] 1

# only data frames
try(drop_empty(c(1, NA)))
#> Error : `data` must be a data frame
```
