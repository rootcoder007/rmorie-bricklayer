# Runs of consecutive missing values

Finds the maximal stretches of consecutive `NA` in each column, with
where each begins and how long it is.

Row order carries meaning in a capsule far more often than people allow
for – a time series, an ordered export, a paginated download – and a
long unbroken run of missingness means something different from the same
count scattered about. A run says an instrument was down, a page failed
to fetch, or a period was never collected; scattered gaps say individual
records failed. The rate cannot distinguish them.

## Usage

``` r
missing_runs(data, min_run = 2L)
```

## Arguments

- data:

  A data frame, in the row order that carries meaning.

- min_run:

  Whole number, default 2: report only runs at least this long (a run of
  1 is an isolated gap).

## Value

A data frame of class `bricklayer_runs` with `column` (character),
`start` and `end` (integer row numbers, inclusive) and `length`
(integer), longest first and then by column name. Zero rows when there
are no qualifying runs.

## Details

Each column's missingness indicator `is.na(x)` is run-length encoded
with [`rle()`](https://rdrr.io/r/base/rle.html); every run of `TRUE`
with length at least `min_run` is reported. Rows are taken in their
current order, so sort the data by time (or by download order) first. A
list column counts an element as missing only when
[`is.na()`](https://rdrr.io/r/base/NA.html) says so. Errors: `data` not
a data frame or without columns, or with duplicated or empty names;
`min_run` not a positive whole number.

## See also

[`missingness_pattern()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_pattern.md)
for which columns are missing together,
[`missingness_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_summary.md)
for the rates.

## Examples

``` r
# One long outage and two isolated gaps, with the same total count.
df <- data.frame(
  outage = c(1, 2, NA, NA, NA, NA, 7, 8),
  scattered = c(1, NA, 3, 4, NA, 6, NA, NA)
)
sum(is.na(df$outage)) == sum(is.na(df$scattered))
#> [1] TRUE

missing_runs(df)
#> ── Runs of consecutive missing values ──────────────────────────── 
#>     column start end length
#>     outage     3   6      4
#>  scattered     7   8      2
#> ────────────────────────────────────────────────────────────────── 

# Isolated gaps too, by lowering the threshold.
missing_runs(df, min_run = 1)
#> ── Runs of consecutive missing values ──────────────────────────── 
#>     column start end length
#>     outage     3   6      4
#>  scattered     7   8      2
#>  scattered     2   2      1
#>  scattered     5   5      1
#> ────────────────────────────────────────────────────────────────── 

# A complete column has no runs.
missing_runs(data.frame(x = 1:5))
#> ── Runs of consecutive missing values ──────────────────────────── 
#>   (none)
#> ────────────────────────────────────────────────────────────────── 

try(missing_runs(df, min_run = 0))
#> Error : `min_run` must be a single positive integer
```
