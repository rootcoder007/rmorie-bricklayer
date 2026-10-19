# The Goodman-Bacon decomposition of a two-way fixed-effects estimate

Splits the two-way fixed-effects difference-in-differences estimate of a
staggered adoption into the two-group, two-period comparisons it
averages, with their weights: treated against never treated, earlier
against later treated, and later against earlier treated (the
comparisons that use already-treated units as controls).

## Usage

``` r
bacondcmp(data, unit, time, y, trtd)
```

## Arguments

- data:

  A data frame, one row per unit and period.

- unit, time, y:

  Column names: the unit, the period (numeric, for example a year or a
  month index) and the outcome.

- trtd:

  Column name of the treatment indicator (0 or 1).

## Value

A data frame of class `rmbl_bacon`: `type` (`"treated vs never"`,
`"earlier vs later"`, `"later vs earlier"`), `treated`, `control` (the
adoption periods; `Inf` for never), `estimate`, `weight`; attribute
`twfe` (the weighted sum, equal to the two-way estimate).

## Details

For a balanced panel with treatment that stays on and no covariates, the
estimate of
[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md)
is exactly \\\hat\beta = \sum\_{k} s\_{kU}\hat\beta\_{kU} + \sum\_{k \ne
l} s\_{kl}\hat\beta\_{kl}\\, with weights that sum to one and grow with
the groups' sizes \\n\\ and the variance of their treatment over time
\\\bar D(1 - \bar D)\\ (Goodman-Bacon 2021, theorem 1). Units treated
from the first period act as an already-treated group. A large weight on
"later vs earlier" comparisons, together with effects that grow over
time, is the warning sign that the two-way estimate is biased.

## References

Goodman-Bacon A (2021). Difference-in-differences with variation in
treatment timing. Journal of Econometrics 225(2):254-277.
[doi:10.1016/j.jeconom.2021.03.014](https://doi.org/10.1016/j.jeconom.2021.03.014)

## See also

[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md),
[`stgatt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stgatt.md).

## Examples

``` r
p <- polex()
b <- bacondcmp(p, "district", "month", "crmrate", "reformed")
b
#> Goodman-Bacon decomposition: two-way estimate -3.232
#>   earlier vs later   weight 0.209, average estimate -3.558
#>   later vs earlier   weight 0.209, average estimate -3.414
#>   treated vs never   weight 0.581, average estimate -3.048
tapply(b$weight, b$type, sum)
#> earlier vs later later vs earlier treated vs never 
#>        0.2093023        0.2093023        0.5813953 
```
