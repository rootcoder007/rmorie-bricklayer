# Stock and flow side by side, with the decomposition

Reports the same person-days as a stock and as a flow, and says how much
of any change in the stock came from the number of people and how much
from how long they stayed. Use it whenever a report compares periods:
the count of people (a flow) and the population held (a stock) can move
in opposite directions when the length of stay changes, and a table with
only one of them implies the wrong direction for the other.

## Usage

``` r
stock_flow(
  days,
  people,
  period = NULL,
  t = 365,
  exposure = NULL,
  per = 1e+05,
  baseline = c("first", "previous")
)
```

## Arguments

- days:

  Numeric vector of person-days, one element per period; non-negative,
  no `NA` or `Inf`.

- people:

  Numeric vector of the number of people (admissions or persons served),
  one element per period, the same length as `days`; positive.

- period:

  Optional labels for the periods (any vector, converted to character),
  one per period. Default `NULL` labels them `1, 2, ...`.

- t:

  Numeric, the length of each period in days: one value for all periods,
  or one per period; positive. Default `365`.
  [`period_days()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/period_days.md)
  turns dates into this.

- exposure:

  Optional numeric population to express rates against, one value or one
  per period, positive; for example provincial residents. Default `NULL`
  (no rate columns).

- per:

  Numeric scalar, the rate base when `exposure` is given: rates are per
  `per` residents. Default `100000`.

- baseline:

  Character scalar, what the change columns compare against: `"first"`
  (the default) measures every period against the first, which is what a
  report on a whole window wants; `"previous"` measures each period
  against the one before it, which is what a series wants (the first
  row's changes are then `NA`).

## Value

A data frame of class `c("rmbl_stock_flow", "data.frame")`, one row per
period, with columns `period` (character), `people`, `days`, `alos`
(days per person), `adp` (days divided by `t`); when `exposure` is given
also `exposure`, `flow_rate` (people per `per` residents) and
`stock_rate` (`adp` per `per` residents). Then the percentage changes
against the baseline: `people_change`, `alos_change`, `days_change`,
`adp_change`, and with `exposure` also `flow_rate_change` and
`stock_rate_change`. Attribute `"stock_flow"` is a list with `t` (the
period lengths), `baseline` and `per` (`NA` without `exposure`). The
print method shows the levels and a footer with the change from the
baseline to the last period, flagging rates with opposite signs.

## Details

The decomposition is exact, because days are people times length of
stay: a change in days is \\(1+p)(1+l) - 1\\ for proportional changes
\\p\\ in people and \\l\\ in stay. The two rates can therefore carry
OPPOSITE signs, and the point of putting them in one table is that
neither can then be quoted alone.

Changes are percentages: \\100 (v_i / v_b - 1)\\ with \\b\\ the baseline
row. Errors when `days` and `people` differ in length, when `exposure`
has a length other than 1 or the number of periods, when `t` has a
length other than 1 or the number of periods, when `period` has a length
other than the number of periods, when `per` has more than one value,
when any input has `NA`, `Inf`, text, or a value that is negative
(`days`) or not positive (the others), and when `baseline` is not one of
the two choices.

## References

Lakner, E. (1976) *A Manual of Statistical Sampling Methods for
Corrections Planners*. University of Illinois at Urbana-Champaign.

## See also

[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)

## Examples

``` r
# Fewer people, held longer: the flow falls while the stock rises.
stock_flow(
  days = c(115674, 126121), people = c(12647, 9608),
  period = c("2023", "2025"),
  exposure = c(15495050, 16256538)
)
#> ── Stock and flow over 2 periods ───────────────────────────────── 
#>  period people   days      alos      adp flow_rate stock_rate
#>    2023  12647 115674  9.146359 316.9151  81.61961   2.045267
#>    2025   9608 126121 13.126665 345.5370  59.10237   2.125526
#> 
#>   2023 to 2025: people -24.0%, stay +43.5%, days +9.0%
#>   flow rate -27.6%, stock rate +3.9%  <- opposite signs: quote both
#> ────────────────────────────────────────────────────────────────── 

# a series of three years against the previous year, with leap-year lengths
sf <- stock_flow(
  days = c(100200, 104000, 99000), people = c(9800, 9500, 9900),
  period = 2023:2025, t = c(365, 366, 365), baseline = "previous"
)
as.data.frame(sf)[, c("period", "alos", "adp", "people_change", "adp_change")]
#>   period     alos      adp people_change adp_change
#> 1   2023 10.22449 274.5205            NA         NA
#> 2   2024 10.94737 284.1530     -3.061224   3.508829
#> 3   2025 10.00000 271.2329      4.210526  -4.546891

# days and people must line up period by period
try(stock_flow(days = c(100, 120), people = c(10, 12, 14)))
#> Error : `days` and `people` must be the same length
```
