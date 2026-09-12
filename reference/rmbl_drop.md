# Drop empty or constant columns and rows

`drop_empty()` removes rows or columns that are entirely missing.
`drop_constant()` removes columns that hold a single distinct value. The
counterparts of `janitor::remove_empty()` and
`janitor::remove_constant()`.

## Usage

``` r
drop_empty(data, which = c("rows", "cols"))

drop_constant(data, na_as_value = FALSE)
```

## Arguments

- data:

  A data frame.

- which:

  `"rows"`, `"cols"`, or both (the default).

- na_as_value:

  Treat `NA` as a distinct value, so a column of `NA`s plus one real
  value counts as two (default `FALSE`).

## Value

The data frame, with the offending rows or columns removed. The names of
what was dropped are attached as the `"dropped"` attribute.

## Details

A constant column carries no information and breaks anything that scales
by variance, so it is worth removing – but it is also a FINDING. A
column that was informative in the pinned capsule and is constant in a
fresh fetch means the source changed, so check
[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
before deleting it and moving on.

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
```
