# Calibrate the drift screens on data known not to have drifted

[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
flags a column when a Kolmogorov-Smirnov, chi-square or
population-stability screen fires. How often that happens when nothing
has changed is the false-alarm rate of the screen on this capsule, and
it depends on the columns, their sizes and `alpha`. This estimates it by
splitting the same data at random into two halves `n` times and running
the screens on the halves, which is the null of "a re-fetch of identical
data". A capsule whose screens fire on 30% of identical re-fetches needs
a smaller `alpha` or fewer screened columns before a drift verdict means
anything.

## Usage

``` r
drift_calibrate(data, n = 50L, alpha = 0.01, seed = 1L, ...)
```

## Arguments

- data:

  The capsule's data frame.

- n:

  Number of random half-splits.

- alpha:

  Significance level passed to
  [`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md).

- seed:

  Seed for the splits.

- ...:

  Passed to
  [`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md).

## Value

A list of class `rmbl_drift_calibration`: `columns` (per column, the
share of splits on which it was flagged), `any_flag` (share of splits
with at least one flag), `alpha`, `n`, and `alpha_familywise` (the
per-screen level that would hold the family-wise false-alarm rate at
`alpha`, Bonferroni).

## Examples

``` r
set.seed(1)
d <- data.frame(a = rnorm(400), b = sample(letters[1:4], 400, TRUE))
drift_calibrate(d, n = 10)
#> Drift screens on 10 identical re-fetches (alpha = 0.01)
#>   at least one column flagged: 0% of re-fetches
#>   no column fired on identical data
#>   per-screen alpha for a family-wise 0.01: 0.005
```
