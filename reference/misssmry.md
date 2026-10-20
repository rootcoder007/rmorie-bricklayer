# Missingness in one line per question

The scalar summaries of missingness: how much of the table is missing,
how many rows are complete, and how many columns have any or only
missing values. Use it as a first look at a new extract, or to report
data completeness in a methods section;
[`misspat()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/misspat.md)
then shows which columns are missing together.

## Usage

``` r
misssmry(data)
```

## Arguments

- data:

  A data frame with at least one column.

## Value

A named numeric vector: `nrows`, `n_cols`, `n_missing` (missing cells),
`pct_missing` (percent of cells), `n_complete_rows`, `pct_complete_rows`
(percent of rows), `n_cols_any_missing` (columns with at least one
missing value) and `n_cols_all_missing` (columns with no value at all).

## Details

A cell is missing when [`is.na()`](https://rdrr.io/r/base/NA.html) is
`TRUE` (so `NaN` counts, and an empty string does not). A row is
complete when no cell in it is missing
([`stats::complete.cases()`](https://rdrr.io/r/stats/complete.cases.html)).
Percentages are of all cells and of all rows. A table with no rows gives
zeros. Columns are taken by position, so duplicate or empty column names
are fine. Errors when `data` is not a data frame or has no columns.

## See also

[`misspat()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/misspat.md)
for which columns are missing together,
[`profcols()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profcols.md)
for per-column rates.

## Examples

``` r
df <- data.frame(a = c(1, NA, 3), b = c(NA, NA, 3), c = 1:3)
misssmry(df)
#>             n_rows             n_cols          n_missing        pct_missing 
#>            3.00000            3.00000            3.00000           33.33333 
#>    n_complete_rows  pct_complete_rows n_cols_any_missing n_cols_all_missing 
#>            1.00000           33.33333            2.00000            0.00000 

# A complete table is all zeros but for its dimensions.
misssmry(data.frame(x = 1:3, y = 4:6))
#>             n_rows             n_cols          n_missing        pct_missing 
#>                  3                  2                  0                  0 
#>    n_complete_rows  pct_complete_rows n_cols_any_missing n_cols_all_missing 
#>                  3                100                  0                  0 

# a wholly empty column
ms <- misssmry(data.frame(x = 1:4, note = NA))
ms[c("pct_missing", "n_cols_all_missing")]
#>        pct_missing n_cols_all_missing 
#>                 50                  1 

# a vector is not a table
try(misssmry(c(1, NA, 3)))
#> Error : misssmry: `data` must be a data frame
```
