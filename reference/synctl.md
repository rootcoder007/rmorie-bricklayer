# Synthetic control for one treated unit

A weighted average of untreated units that tracks the treated unit
before the policy, as its counterfactual after; with the placebo test
that runs the same method on every untreated unit.

## Usage

``` r
synctl(data, unit, time, y, treunit, adopt, plac = TRUE)
```

## Arguments

- data:

  A data frame, one row per unit and period.

- unit, time, y:

  Column names: the unit, the period (numeric, for example a year or a
  month index) and the outcome.

- treunit:

  The treated unit (a value of `unit`).

- adopt:

  The first treated period.

- plac:

  Run the placebo test (default `TRUE`).

## Value

A list of class `rmbl_synth`: `weights` (a named vector over the
donors), `path` (a data frame: `time`, `treated`, `synthetic`, `gap`),
`rmspepre`, `rmsperatio`, `p_value` (`NA` without the placebo),
`placrat`. [`plot()`](https://rdrr.io/r/graphics/plot.default.html)
draws the two paths and the gap.

## Details

The weights solve \$\$\min_w \sum\_{t \< T_0} \Big(Y\_{1t} - \sum_j w_j
Y\_{jt}\Big)^2 \quad \textrm{s.t.} \quad w_j \ge 0,\\ \sum_j w_j =
1,\$\$ over the periods before adoption \\T_0\\ (accelerated projected
gradient onto the simplex; the problem is convex, so the solution is the
global one). The effect in each period is the gap \\Y\_{1t} - \sum_j w_j
Y\_{jt}\\. For inference, each untreated unit in turn is treated as if
it had adopted the policy, with the other untreated units as donors; the
ratio of root mean squared gap after to before adoption ranks the real
unit among the placebos, and \\p\\ is its rank over the number of units
(Abadie, Diamond and Hainmueller 2010).

This version matches on the pre-period outcomes only, not on separate
predictors.

## References

Abadie A, Diamond A, Hainmueller J (2010). Synthetic control methods for
comparative case studies. Journal of the American Statistical
Association 105(490):493-505.
[doi:10.1198/jasa.2009.ap08746](https://doi.org/10.1198/jasa.2009.ap08746)

## Examples

``` r
p <- polex()
p1 <- p[is.na(p$refmonth) | p$district == "D01", ]
s <- synctl(p1, "district", "month", "crmrate", treunit = "D01",
                       adopt = 13)
round(s$weights, 3)
#> D04 D08 D12 D16 D20 
#>   0   1   0   0   0 
s$p_value
#> [1] 1
plot(s)
```
