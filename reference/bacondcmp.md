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
“later vs earlier” comparisons, together with effects that grow over
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
#> ╭── Goodman-Bacon decomposition ──────────────────────────────────────────╮
#> │   Two-way estimate            -3.232                                    │
#> │   Comparisons                 9                                         │
#> │   Weight on later vs earlier  20.9%                                     │
#> │                                                                         │
#> │   By kind of comparison                                                 │
#> │   type              comparisons  weight  estimate                       │
#> │   ----------------  -----------  ------  --------                       │
#> │   treated vs never            3  0.5814    -3.048                       │
#> │   earlier vs later            3  0.2093    -3.558                       │
#> │   later vs earlier            3  0.2093    -3.414                       │
#> │                                                                         │
#> │   Each comparison (control Inf = never treated)                         │
#> │   type              treated  control  estimate   weight                 │
#> │   ----------------  -------  -------  --------  -------                 │
#> │   treated vs never       13      Inf    -3.181  0.18605                 │
#> │   treated vs never       19      Inf    -3.137  0.20930                 │
#> │   treated vs never       25      Inf    -2.817  0.18605                 │
#> │   earlier vs later       13       19    -3.650  0.04651                 │
#> │   later vs earlier       19       13    -3.624  0.06977                 │
#> │   earlier vs later       13       25    -3.506  0.09302                 │
#> │   later vs earlier       25       13    -3.332  0.09302                 │
#> │   earlier vs later       19       25    -3.568  0.06977                 │
#> │   later vs earlier       25       19    -3.261  0.04651                 │
#> │                                                                         │
#> │   The two-way estimate -3.232 is the weighted average of these 9        │
#> │   two-group comparisons. 20.9% of the weight is on comparisons that use │
#> │   already-treated units as controls; if the effect grows over time,     │
#> │   that part pulls the two-way estimate away from the true effect.       │
#> ╰─────────────────────────────────────────────────────────────────────────╯
tapply(b$weight, b$type, sum)
#> earlier vs later later vs earlier treated vs never 
#>        0.2093023        0.2093023        0.5813953 

# your own panel: eight towns over ten years, four adopting a by-law (two
# in 2019, two in 2021), with each town's population, county and income
own <- data.frame(
  town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
  year = rep(2015:2024, times = 8)
)
i <- match(own$town, unique(own$town))
own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
own$county <- rep(c("North", "South"), 4)[i]
own$income <- 50 + own$year - 2015 + cos(seq_len(80))
own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
  0.2 * own$income + sin(seq_len(80))
bacondcmp(own, "town", "year", "rate", "bylaw")
#> ╭── Goodman-Bacon decomposition ─────────────────────────────────────────╮
#> │   Two-way estimate            -4.039                                   │
#> │   Comparisons                 4                                        │
#> │   Weight on later vs earlier  7.1%                                     │
#> │                                                                        │
#> │   By kind of comparison                                                │
#> │   type              comparisons   weight  estimate                     │
#> │   ----------------  -----------  -------  --------                     │
#> │   treated vs never            2  0.85714    -4.026                     │
#> │   earlier vs later            1  0.07143    -4.136                     │
#> │   later vs earlier            1  0.07143    -4.096                     │
#> │                                                                        │
#> │   Each comparison (control Inf = never treated)                        │
#> │   type              treated  control  estimate  weight                 │
#> │   ----------------  -------  -------  --------  ------                 │
#> │   treated vs never    2,019      Inf    -4.240  0.4286                 │
#> │   treated vs never    2,021      Inf    -3.813  0.4286                 │
#> │   earlier vs later    2,019    2,021    -4.136  0.0714                 │
#> │   later vs earlier    2,021    2,019    -4.096  0.0714                 │
#> │                                                                        │
#> │   The two-way estimate -4.039 is the weighted average of these 4       │
#> │   two-group comparisons. 7.1% of the weight is on comparisons that use │
#> │   already-treated units as controls; if the effect grows over time,    │
#> │   that part pulls the two-way estimate away from the true effect.      │
#> ╰────────────────────────────────────────────────────────────────────────╯
```
