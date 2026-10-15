# Which columns are missing together

Counts the distinct PATTERNS of missingness across rows – which
combination of columns is missing in each row – rather than the
per-column rates
[`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md)
reports. Use it before deciding how to handle gaps (drop rows, impute,
model separately), because the right choice depends on whether columns
are missing together.

## Usage

``` r
missingness_pattern(data, max_patterns = 20L)
```

## Arguments

- data:

  A data frame.

- max_patterns:

  Maximum patterns to return, most frequent first, one positive whole
  number (default 20).

## Value

A data frame of class `c("bricklayer_missingness", "data.frame")`, one
row per pattern: `pattern` (character, `.` for present and `X` for
missing, in column order), `n_rows` (integer), `pct_rows` (numeric,
percent of all rows), `n_missing` (integer, columns missing in that
pattern) and `columns` (character, their names comma-separated, `""` for
the complete pattern). Carries the column order as the `"columns"`
attribute.

## Details

The distinction decides what to do about the gaps. Two columns each 30%
missing at random need different handling from two columns 30% missing
in THE SAME rows – the second is one structural gap (a join that failed,
a form section nobody filled in) and often means those rows should be
dropped or modelled separately, while the first does not. A per-column
rate cannot tell the two apart; this can.

Each row is coded as a string with one character per column, `X` where
[`is.na()`](https://rdrr.io/r/base/NA.html) is true and `.` otherwise,
and the codes are tabulated. Patterns are sorted by descending frequency
and the first `max_patterns` kept, so `pct_rows` may not sum to 100 when
patterns are cut. A frame with no rows gives an empty table. The work is
one pass over the rows; very wide frames give long codes.

Errors: `data` not a data frame, without columns, or with missing or
duplicated names; `max_patterns` not one positive whole number.

## See also

[`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md)
for per-column rates.

## Examples

``` r
# Two columns missing in the SAME rows: one structural gap.
structural <- data.frame(
  id = 1:10,
  a = c(rep(NA, 3), 4:10),
  b = c(rep(NA, 3), 4:10)
)
missingness_pattern(structural)
#> ── Missingness patterns ────────────────────────────────────────── 
#>   columns, in pattern order: id, a, b
#> 
#>  pattern n_rows pct_rows n_missing columns
#>      ...      7     70.0         0        
#>      .XX      3     30.0         2    a, b
#> ────────────────────────────────────────────────────────────────── 

# The same per-column rates, but missing independently.
scattered <- data.frame(
  id = 1:10,
  a = c(rep(NA, 3), 4:10),
  b = c(1:7, rep(NA, 3))
)
missingness_pattern(scattered)
#> ── Missingness patterns ────────────────────────────────────────── 
#>   columns, in pattern order: id, a, b
#> 
#>  pattern n_rows pct_rows n_missing columns
#>      ...      4     40.0         0        
#>      ..X      3     30.0         1       b
#>      .X.      3     30.0         1       a
#> ────────────────────────────────────────────────────────────────── 

# A complete frame has exactly one pattern.
missingness_pattern(data.frame(x = 1:3, y = 4:6))
#> ── Missingness patterns ────────────────────────────────────────── 
#>   columns, in pattern order: x, y
#> 
#>  pattern n_rows pct_rows n_missing columns
#>       ..      3    100.0         0        
#> ────────────────────────────────────────────────────────────────── 

# keep only the most common pattern
missingness_pattern(scattered, max_patterns = 1)
#> ── Missingness patterns ────────────────────────────────────────── 
#>   columns, in pattern order: id, a, b
#> 
#>  pattern n_rows pct_rows n_missing columns
#>      ...      4     40.0         0        
#> ────────────────────────────────────────────────────────────────── 

# a frame without columns has no patterns
try(missingness_pattern(data.frame()))
#> Error : `data` has no columns
```
