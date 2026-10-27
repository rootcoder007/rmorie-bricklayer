# Period length in days, from dates

Counts the days from one date to another, both ends included, so the
result can be passed as the period length `t` to
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`admits()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/admits.md),
[`adpcnts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adpcnts.md)
and
[`stkflow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stkflow.md).
It saves getting a fiscal year, a quarter or a leap year wrong by a day.

## Usage

``` r
perdays(from, to)
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
use as `t`. It has class `c("rmbl_perdays", "rmbl_measure", "numeric")`
and an attribute `"lakner"` (`from` and `to` as dates), so it prints as
a box; arithmetic, [`round()`](https://rdrr.io/r/base/Round.html),
[`sum()`](https://rdrr.io/r/base/sum.html),
[`mean()`](https://rdrr.io/r/base/mean.html), `[`,
[`c()`](https://rdrr.io/r/base/c.html) and
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) give a plain
number, and every `t` argument takes it as it is.

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
perdays("2024-01-01", "2024-12-31") # a leap year
#> ╭── Period length ──────────────────────────────────────────────────────╮
#> │   Length   366 days                                                   │
#> │   From     2024-01-01                                                 │
#> │   To       2024-12-31                                                 │
#> │   Formula  t = to - from + 1 (both ends counted)                      │
#> │                                                                       │
#> │   From 2024-01-01 to 2024-12-31 is 366 days.                          │
#> │   Pass it as t to adp(), admits(), adpcnts() or stkflow().            │
#> │                                                                       │
#> │   Both ends count: the 1st to the 31st is 31 days of exposure. A leap │
#> │   year comes out at 366 from the dates, without anyone choosing.      │
#> ╰───────────────────────────────────────────────────────────────────────╯
perdays("2023-01-01", "2023-12-31")
#> ╭── Period length ──────────────────────────────────────────────────────╮
#> │   Length   365 days                                                   │
#> │   From     2023-01-01                                                 │
#> │   To       2023-12-31                                                 │
#> │   Formula  t = to - from + 1 (both ends counted)                      │
#> │                                                                       │
#> │   From 2023-01-01 to 2023-12-31 is 365 days.                          │
#> │   Pass it as t to adp(), admits(), adpcnts() or stkflow().            │
#> │                                                                       │
#> │   Both ends count: the 1st to the 31st is 31 days of exposure. A leap │
#> │   year comes out at 366 from the dates, without anyone choosing.      │
#> ╰───────────────────────────────────────────────────────────────────────╯
perdays("2025-04-01", "2026-03-31") # a fiscal year
#> ╭── Period length ──────────────────────────────────────────────────────╮
#> │   Length   365 days                                                   │
#> │   From     2025-04-01                                                 │
#> │   To       2026-03-31                                                 │
#> │   Formula  t = to - from + 1 (both ends counted)                      │
#> │                                                                       │
#> │   From 2025-04-01 to 2026-03-31 is 365 days.                          │
#> │   Pass it as t to adp(), admits(), adpcnts() or stkflow().            │
#> │                                                                       │
#> │   Both ends count: the 1st to the 31st is 31 days of exposure. A leap │
#> │   year comes out at 366 from the dates, without anyone choosing.      │
#> ╰───────────────────────────────────────────────────────────────────────╯

# a quarter as the period of an average daily population
adp(4200, t = perdays(as.Date("2025-01-01"), as.Date("2025-03-31")))
#> ╭── Average daily population ─────────────────────────────────────────────╮
#> │   Average daily population  46.67 people on an average day              │
#> │   Person-days               4,200                                       │
#> │   Period                    90 days                                     │
#> │   Formula                   adp = days / t = 4,200 / 90                 │
#> │                                                                         │
#> │   4,200 person-days over 90 days: 46.67 people held on an average day.  │
#> │                                                                         │
#> │   Lakner (1976, p.15): a stock -- people held at once, not people who   │
#> │   passed through. Count only the days served inside the period.         │
#> │   adp = n x alos / t links it to alos() and admits(), exactly only in a │
#> │   steady state.                                                         │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# numbers are not dates, and the end cannot come first
try(perdays(1, 31))
#> Error : `from` and `to` must be dates or date strings, not numbers
try(perdays("2024-12-31", "2024-01-01"))
#> Error : `to` must not precede `from`
```
