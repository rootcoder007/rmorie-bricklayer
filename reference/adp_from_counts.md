# Person-days estimated from periodic headcounts

When only a count of people present on certain days is available – not a
record per person – the person-days over the period are the mean of
those counts scaled to the period's length. Use it with
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md)
or
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)
when the source is a daily or weekly count sheet rather than admission
and release dates.

## Usage

``` r
adp_from_counts(counts, t = 365)
```

## Arguments

- counts:

  Numeric vector of headcounts, one per day on which a count was taken;
  non-negative, no `NA` or `Inf`. The days need not be consecutive.

- t:

  Numeric scalar, the length of the period in days; must be positive.
  Default `365`.

## Value

A numeric scalar: the estimated person-days over the period,
`mean(counts) * t`. Despite the function's name this is a total of
person-days, not an average daily population; divide by `t` (or pass it
to
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md))
for the population held on an average day.

## Details

Lakner's \\X_t = (\frac{1}{C}\sum N_i) t\\ (1976, p.21). The counts need
not cover every day: counting on weekdays only is the usual case, and
the mean of the days counted stands in for the days not counted. That
substitution is an assumption, and it fails if the days counted differ
systematically from the days missed – weekday-only counting where
weekend admissions are released before Monday, for instance.

## See also

[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md)

## Examples

``` r
# Lakner (p.21): counts on 255 days summing to 34,935 imply just over
# fifty thousand detention days across the year.
adp_from_counts(rep(34935 / 255, 255))
#> [1] 50005

# weekly counts over a 31-day month, then the average daily population
pd <- adp_from_counts(c(120, 130, 125, 128), t = 31)
pd
#> [1] 3898.25
adp(pd, t = 31)
#> [1] 125.75

# a missing count must be dropped or filled first
try(adp_from_counts(c(120, NA, 125)))
#> Error : `counts` must not contain NA
```
