# Person-days estimated from periodic headcounts

When only a count of people present on certain days is available – not a
record per person – the person-days over the period are the mean of
those counts scaled to the period's length.

## Usage

``` r
adp_from_counts(counts, t = 365)
```

## Arguments

- counts:

  Headcounts, one per day on which a count was taken.

- t:

  Length of the period in days. Default 365.

## Value

Estimated person-days over the period.

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
```
