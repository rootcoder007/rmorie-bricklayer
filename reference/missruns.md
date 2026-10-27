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
missruns(data, minrun = 2L)
```

## Arguments

- data:

  A data frame, in the row order that carries meaning.

- minrun:

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
with length at least `minrun` is reported. Rows are taken in their
current order, so sort the data by time (or by download order) first. A
list column counts an element as missing only when
[`is.na()`](https://rdrr.io/r/base/NA.html) says so. Errors: `data` not
a data frame or without columns, or with duplicated or empty names;
`minrun` not a positive whole number.

## See also

[`misspat()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/misspat.md)
for which columns are missing together,
[`misssmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/misssmry.md)
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

missruns(df)
#> ╭── Runs of consecutive missing values ───────────────────────────────────╮
#> │   Runs               2                                                  │
#> │   Columns with runs  2                                                  │
#> │   Longest run        4                                                  │
#> │                                                                         │
#> │   column     start  end  length                                         │
#> │   ---------  -----  ---  ------                                         │
#> │   outage         3    6       4                                         │
#> │   scattered      7    8       2                                         │
#> │                                                                         │
#> │   Long runs of missing rows usually mean a source stopped reporting for │
#> │   a while, not values missing at random.                                │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# Isolated gaps too, by lowering the threshold.
missruns(df, minrun = 1)
#> ╭── Runs of consecutive missing values ───────────────────────────────────╮
#> │   Runs               4                                                  │
#> │   Columns with runs  2                                                  │
#> │   Longest run        4                                                  │
#> │                                                                         │
#> │   column     start  end  length                                         │
#> │   ---------  -----  ---  ------                                         │
#> │   outage         3    6       4                                         │
#> │   scattered      7    8       2                                         │
#> │   scattered      2    2       1                                         │
#> │   scattered      5    5       1                                         │
#> │                                                                         │
#> │   Long runs of missing rows usually mean a source stopped reporting for │
#> │   a while, not values missing at random.                                │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# A complete column has no runs.
missruns(data.frame(x = 1:5))
#> ╭── Runs of consecutive missing values ──╮
#> │   Runs               0                 │
#> │   Columns with runs  0                 │
#> │                                        │
#> │   (none)                               │
#> ╰────────────────────────────────────────╯

try(missruns(df, minrun = 0))
#> Error : `minrun` must be a single positive integer
```
