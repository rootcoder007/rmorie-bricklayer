# Runs of consecutive missing values

Finds the maximal stretches of consecutive `NA` in each column, with
where each begins and how long it is.

## Usage

``` r
missing_runs(data, min_run = 2L)
```

## Arguments

- data:

  A data frame.

- min_run:

  Report only runs at least this long (default 2, since a run of 1 is an
  isolated gap).

## Value

A data frame of class `bricklayer_runs` with `column`, `start`, `end`
and `length`, longest first. Zero rows when there are no qualifying
runs.

## Details

Row order carries meaning in a capsule far more often than people allow
for – a time series, an ordered export, a paginated download – and a
long unbroken run of missingness means something different from the same
count scattered about. A run says an instrument was down, a page failed
to fetch, or a period was never collected; scattered gaps say individual
records failed. The rate cannot distinguish them.

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
```
