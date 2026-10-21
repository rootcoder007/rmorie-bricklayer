# Calibrate the drift screens on data known not to have drifted

[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
flags a column when a Kolmogorov-Smirnov, chi-square or
population-stability screen fires. How often that happens when nothing
has changed is the false-alarm rate of the screen on this capsule, and
it depends on the columns, their sizes and `alpha`. This estimates it by
splitting the same data at random into two halves `n` times and running
the screens on the halves, which is the null of “a re-fetch of identical
data”. A capsule whose screens fire on 30 percent of identical
re-fetches needs a smaller `alpha` or fewer screened columns before a
drift verdict means anything.

## Usage

``` r
drftcal(data, n = 50L, alpha = 0.01, seed = 1L, ...)
```

## Arguments

- data:

  The capsule's data frame.

- n:

  Whole number, default 50: the number of random half-splits.

- alpha:

  Number in (0, 1), default 0.01: the significance level passed to
  [`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md).

- seed:

  Integer or `NULL`, default 1: the seed for the splits.

- ...:

  Further arguments to
  [`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md),
  such as `psithr`, `psiminn`, `bins` or `idelvls`.

## Value

A list of class `rmbl_drift_calibration`: `columns` (a data frame of
`column` and `falsealarmrate`, the share of splits on which it was
flagged), `anyflag` (share of splits with at least one flag), `alpha`,
`n`, and `alphafam` (`alpha` divided by the number of columns: the
Bonferroni per-screen level that would hold the family-wise false-alarm
rate at `alpha`). The print method lists the columns that fired.

## Details

Each split draws `floor(nrow(data) / 2)` rows at random as the reference
and uses the rest as the current table, then runs
[`cpsdrft`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
on the pair. A column's false-alarm rate is the share of splits on which
it was flagged; `anyflag` is the share of splits on which any column
was. Each half has half the rows of the real data, so the rates describe
a comparison at that size: smaller samples make the p-value screens less
sensitive, and the PSI screen only counts once both halves reach
`psiminn` rows.

The splits are drawn under `seed` and the caller's random number stream
is restored afterwards (`seed = NULL` uses and advances the current
stream instead). Run time is about `n` times one
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
call; a progress bar is shown in an interactive session.

Errors: `data` not a data frame with at least four rows; `n` not a whole
number of at least 1; any error from
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md).

## See also

[`cpsdrft`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md),
[`scanadj`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scanadj.md).

## Examples

``` r
set.seed(1)
d <- data.frame(a = rnorm(400), b = sample(letters[1:4], 400, TRUE))
drftcal(d, n = 10)
#> Drift screens on 10 identical re-fetches (alpha = 0.01)
#>   at least one column flagged: 0% of re-fetches
#>   no column fired on identical data
#>   per-screen alpha for a family-wise 0.01: 0.005

# a stricter level, and the per-column rates
cal <- drftcal(d, n = 10, alpha = 0.001)
cal$columns
#>   column falsealarmrate
#> a      a              0
#> b      b              0

try(drftcal(d[1:3, ]))
#> Error : `data` must be a data frame with at least four rows
```
