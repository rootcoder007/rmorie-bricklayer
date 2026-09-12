# Missingness in one line per question

The scalar summaries of missingness: how much of the table is missing,
how many rows are complete, and how many columns are wholly present.

## Usage

``` r
missingness_summary(data)
```

## Arguments

- data:

  A data frame.

## Value

A named numeric vector: `n_rows`, `n_cols`, `n_missing`, `pct_missing`,
`n_complete_rows`, `pct_complete_rows`, `n_cols_any_missing`,
`n_cols_all_missing`.

## See also

[`missingness_pattern()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_pattern.md)
for which columns are missing together,
[`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md)
for per-column rates.

## Examples

``` r
df <- data.frame(a = c(1, NA, 3), b = c(NA, NA, 3), c = 1:3)
missingness_summary(df)
#>             n_rows             n_cols          n_missing        pct_missing 
#>            3.00000            3.00000            3.00000           33.33333 
#>    n_complete_rows  pct_complete_rows n_cols_any_missing n_cols_all_missing 
#>            1.00000           33.33333            2.00000            0.00000 

# A complete table is all zeros but for its dimensions.
missingness_summary(data.frame(x = 1:3, y = 4:6))
#>             n_rows             n_cols          n_missing        pct_missing 
#>                  3                  2                  0                  0 
#>    n_complete_rows  pct_complete_rows n_cols_any_missing n_cols_all_missing 
#>                  3                100                  0                  0 
```
