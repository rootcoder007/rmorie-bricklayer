# Stock and flow side by side, with the decomposition

Reports the same person-days as a stock and as a flow, and says how much
of any change in the stock came from the number of people and how much
from how long they stayed.

## Usage

``` r
stock_flow(days, people, period = NULL, t = 365, exposure = NULL, per = 1e+05)
```

## Arguments

- days:

  Person-days, one element per period.

- people:

  Number of people, one element per period.

- period:

  Optional labels for the periods.

- t:

  Length of each period in days. Default 365.

- exposure:

  Optional population to express rates against, one per period; for
  example provincial residents.

- per:

  Rate denominator when `exposure` is given. Default 100000.

## Value

A data frame of class `rmbl_stock_flow`, one row per period: `people`,
`days`, `alos`, `adp`, and when `exposure` is supplied `flow_rate` and
`stock_rate`. Change columns compare each period with the first.

## Details

The decomposition is exact, because days are people times length of
stay: a change in days is \\(1+p)(1+l) - 1\\ for proportional changes
\\p\\ in people and \\l\\ in stay. The two rates can therefore carry
OPPOSITE signs, and the point of putting them in one table is that
neither can then be quoted alone.

## References

Lakner, E. (1976) *A Manual of Statistical Sampling Methods for
Corrections Planners*. University of Illinois at Urbana-Champaign.

## See also

[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)

## Examples

``` r
# Fewer people, held longer: the flow falls while the stock rises.
stock_flow(days = c(115674, 126121), people = c(12647, 9608),
           period = c("2023", "2025"),
           exposure = c(15495050, 16256538))
#> Stock and flow over 2 periods
#>  period people   days      alos      adp flow_rate stock_rate
#>    2023  12647 115674  9.146359 316.9151  81.61961   2.045267
#>    2025   9608 126121 13.126665 345.5370  59.10237   2.125526
#> 
#> 2023 to 2025: people -24.0%, stay +43.5%, days +9.0%
#>   flow rate -27.6%, stock rate +3.9%  <- opposite signs: quote both
```
