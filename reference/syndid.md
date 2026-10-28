# Synthetic difference in differences

Arkhangelsky et al.'s estimator for units adopting a policy at one date:
comparison units weighted so their pre-period path parallels the treated
units', pre-periods weighted so they predict the post-period, and the
difference in differences taken with both weights.

## Usage

``` r
syndid(data, unit, time, y, ftreat, reps = 200L, seed = NULL, conflvl = 0.95)
```

## Arguments

- data:

  A data frame, one row per unit and period.

- unit, time, y:

  Column names: the unit, the period (numeric, for example a year or a
  month index) and the outcome.

- ftreat:

  Column name of the period a unit is first treated (`NA`, 0 or `Inf`
  for a unit never treated). Treatment is taken as staying on.

- reps:

  Placebo replications (default 200).

- seed:

  Optional seed for the placebo draws.

- conflvl:

  Confidence level of the intervals reported (default 0.95).

## Value

A list of class `rmbl_synthdid`: `estimate`, `se`, `lower`, `upper`,
`unitwts`, `tmwts`, `method` (`"placebo"` or `"jackknife"`), `paths`
(treated and weighted comparison means by period).
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
paths.

## Details

With \\N_0\\ comparison units, \\N_1\\ treated, \\T_0\\ pre-periods and
\\T_1\\ post-periods, the unit weights solve \$\$\min\_{\omega_0, \omega
\in \Delta} \frac{1}{T_0}\sum\_{t \le T_0}\Big(\omega_0 + \sum_j
\omega_j Y\_{jt} - \bar Y\_{1t}\Big)^2 + \zeta^2 \\\omega\\^2,\$\$ with
\\\zeta = (N_1 T_1)^{1/4} \hat\sigma\\ and \\\hat\sigma\\ the standard
deviation of the comparison units' first differences before adoption;
the time weights solve the same problem across comparison units,
predicting each unit's post-period mean from its pre-periods, with
\\\zeta = 10^{-6}\hat\sigma\\. The estimate is \$\$\hat\tau = \Big(\bar
Y\_{1,post} - \sum_t \lambda_t \bar Y\_{1t}\Big) - \sum_j \omega_j
\Big(\bar Y\_{j,post} - \sum_t \lambda_t Y\_{jt}\Big).\$\$ The weights
are the exact solutions of these convex problems (the `synthdid` package
runs Frank-Wolfe and then sparsifies, so its estimate differs slightly).
The standard error is the placebo one when there is one treated unit
(each set of \\N_1\\ comparison units in turn treated as if adopting,
weights re-estimated), else the jackknife over units with the weights
held fixed (Arkhangelsky et al. 2021, algorithms 3 and 4).

## References

Arkhangelsky D, Athey S, Hirshberg DA, Imbens GW, Wager S (2021).
Synthetic difference-in-differences. American Economic Review
111(12):4088-4118.
[doi:10.1257/aer.20190159](https://doi.org/10.1257/aer.20190159)

## Examples

``` r
p <- polex()
p1 <- p[is.na(p$refmonth) | p$refmonth == 13, ]
syndid(p1, "district", "month", "crmrate", "refmonth", reps = 50, seed = 1)
#> ╭── Synthetic difference in differences ─────────────────────────────────╮
#> │   Estimate              -3.126                                         │
#> │   Standard error        0.2474 (jackknife)                             │
#> │   Interval              [-3.611, -2.641]                               │
#> │   Adoption              13                                             │
#> │   Comparison units      5                                              │
#> │   With weight           5                                              │
#> │   Pre-periods weighted  12                                             │
#> │                                                                        │
#> │   Unit weights                                                         │
#> │   unit  weight                                                         │
#> │   ----  ------                                                         │
#> │   D12   0.2031                                                         │
#> │   D16   0.1999                                                         │
#> │   D08   0.1998                                                         │
#> │   D20   0.1991                                                         │
#> │   D04   0.1981                                                         │
#> │                                                                        │
#> │   Weighting the comparison units and the pre-periods to match the      │
#> │   treated units, the effect is -3.126 (its interval [-3.611, -2.641]): │
#> │   the interval excludes 0, so the data distinguish it from no effect.  │
#> ╰────────────────────────────────────────────────────────────────────────╯

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
own1 <- own[is.na(own$first) | own$first == 2019, ]
syndid(own1, "town", "year", "rate", "first", reps = 50, seed = 1)
#> ╭── Synthetic difference in differences ─────────────────────────────────╮
#> │   Estimate              -4.028                                         │
#> │   Standard error        0.02014 (jackknife)                            │
#> │   Interval              [-4.067, -3.988]                               │
#> │   Adoption              2019                                           │
#> │   Comparison units      4                                              │
#> │   With weight           4                                              │
#> │   Pre-periods weighted  4                                              │
#> │                                                                        │
#> │   Unit weights                                                         │
#> │   unit  weight                                                         │
#> │   ----  ------                                                         │
#> │   G     0.2881                                                         │
#> │   F     0.2662                                                         │
#> │   E     0.2303                                                         │
#> │   H     0.2154                                                         │
#> │                                                                        │
#> │   Weighting the comparison units and the pre-periods to match the      │
#> │   treated units, the effect is -4.028 (its interval [-4.067, -3.988]): │
#> │   the interval excludes 0, so the data distinguish it from no effect.  │
#> ╰────────────────────────────────────────────────────────────────────────╯
```
