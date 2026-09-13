# Period length in days, from dates

Period length in days, from dates

## Usage

``` r
period_days(from, to)
```

## Arguments

- from:

  Start of the period: a `Date`, or anything
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html) accepts.

- to:

  End of the period, inclusive.

## Value

The number of days in the period, for use as `t`.

## Details

Inclusive of both ends, because a period running from the 1st to the
31st is thirty-one days of exposure, not thirty. Leap years need no
special handling: the arithmetic is on dates, so 2024 comes out at 366
and 2023 at 365 without anyone choosing.

## See also

[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md)

## Examples

``` r
period_days("2024-01-01", "2024-12-31")   # a leap year
#> [1] 366
period_days("2023-01-01", "2023-12-31")
#> [1] 365
period_days("2025-04-01", "2026-03-31")   # a fiscal year
#> [1] 365
```
