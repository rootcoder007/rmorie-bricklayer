# Period length in days, from dates

Counts the days from one date to another, both ends included, so the
result can be passed as the period length `t` to
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`admissions()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/admissions.md),
[`adp_from_counts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp_from_counts.md)
and
[`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md).
It saves getting a fiscal year, a quarter or a leap year wrong by a day.

## Usage

``` r
period_days(from, to)
```

## Arguments

- from:

  Start of the period: a single `Date`, or a single value
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html) accepts (such as
  `"2024-01-01"`). Numbers are refused.

- to:

  End of the period, inclusive, in the same forms; must not be before
  `from`.

## Value

A numeric scalar: the number of days in the period, `to - from + 1`, for
use as `t`.

## Details

Inclusive of both ends, because a period running from the 1st to the
31st is thirty-one days of exposure, not thirty. Leap years need no
special handling: the arithmetic is on dates, so 2024 comes out at 366
and 2023 at 365 without anyone choosing.

Errors when either argument is numeric, has a length other than one, is
`NA`, or when `to` precedes `from`. Text that is not a date fails inside
[`as.Date()`](https://rdrr.io/r/base/as.Date.html) with base R's own
message.

## See also

[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md)

## Examples

``` r
period_days("2024-01-01", "2024-12-31") # a leap year
#> [1] 366
period_days("2023-01-01", "2023-12-31")
#> [1] 365
period_days("2025-04-01", "2026-03-31") # a fiscal year
#> [1] 365

# a quarter as the period of an average daily population
adp(4200, t = period_days(as.Date("2025-01-01"), as.Date("2025-03-31")))
#> [1] 46.66667

# numbers are not dates, and the end cannot come first
try(period_days(1, 31))
#> Error : `from` and `to` must be dates or date strings, not numbers
try(period_days("2024-12-31", "2024-01-01"))
#> Error : `to` must not precede `from`
```
