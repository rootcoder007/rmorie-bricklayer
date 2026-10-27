# Difference in differences with two-way fixed effects

The effect of a policy on a unit-by-period panel (municipalities by
month, blocks by quarter, courts by year), from a regression of the
outcome on the treatment indicator with unit and period fixed effects,
and standard errors clustered by unit or by any coarser grouping.

## Usage

``` r
plndid(
  data,
  unit,
  time,
  y,
  trtd,
  covs = NULL,
  cl = NULL,
  fe = c("unit", "time"),
  w = NULL,
  comb = NULL,
  conflvl = 0.95
)
```

## Arguments

- data:

  A data frame, one row per unit and period.

- unit, time, y:

  Column names: the unit, the period (numeric, for example a year or a
  month index) and the outcome.

- trtd:

  Column name of the treatment indicator (0 or 1).

- covs:

  Optional column names of time-varying controls.

- cl:

  Column name of the clusters (default the unit), or two column names
  for two-way clustering (Cameron, Gelbach and Miller 2011): \\V_a +
  V_b - V\_{ab}\\, each term with the small-sample factor of the
  dimension with fewer clusters, and t on its \\G - 1\\ degrees of
  freedom. A composite cluster (district by month, say) is one column
  made with [`interaction()`](https://rdrr.io/r/base/interaction.html).

- fe:

  `c("unit", "time")` (default) or `"time"`.

- w:

  Optional column name of non-negative weights, such as population or
  matching weights, for weighted least squares with weighted
  within-means.

- comb:

  Optional linear combination of the terms, named by them, reported with
  its delta-method standard error as the attribute `combined`. For a
  phase-in model with an exposure term \\E\_{it} = \min(t - G_i, K)\\,
  `comb = c(treated = 1, exposure = 12)` is the effect after twelve
  periods, with its error, and as a percentage of the comparison units'
  pre-period mean (that mean taken as fixed).

- conflvl:

  Confidence level of the intervals reported (default 0.95).

## Value

A data frame of class `rmbl_did`, one row per term (the treatment first,
then the covariates): `term`, `estimate`, `se`, `lower`, `upper`, `t`,
`p_value`. Attributes: `n`, `clusters`, `ctlmean` (the pre-period mean
of the comparison units), `releff` (the estimate over it), `vcov`, and
with `comb` also `combined`.

## Details

The model is \$\$Y\_{it} = \beta T\_{it} + X\_{it}'\gamma + \delta_i +
\mu_t + \varepsilon\_{it},\$\$ fitted by ordinary least squares after
the within transformation (alternating projections, so an unbalanced
panel is fine). The variance is the one-way cluster-robust CR1
estimator, \$\$\hat V = \frac{G}{G - 1}\frac{N - 1}{N - K} (\tilde
X'\tilde X)^{-1} \Big(\sum_g \tilde X_g'\hat u_g \hat u_g'\tilde
X_g\Big) (\tilde X'\tilde X)^{-1},\$\$ with \\K\\ counting the
regressors and the fixed effects not nested in the clusters, and tests
and intervals use Student's t on \\G - 1\\ degrees of freedom. These are
the conventions of Stata's `reghdfe` and R's `fixest`.

The relative effect is \\\hat\beta\\ over the mean outcome of the units
never treated (or not yet treated) in the periods before the first
treatment, the way an effect on a rate is usually reported (“a 12%
fall”).

With `fe = "time"` the unit effects are left out, and the model is the
cross-section with period effects of a comparison between kinds of units
(for example blocks in dynastic and in other wards).

When treatment starts at different times, this estimator weights
earlier-treated units as controls for later ones, and can be biased if
the effect changes over time: see
[`bacondcmp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bacondcmp.md)
for the weights and
[`stgatt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stgatt.md)
for estimators that avoid them.

## References

Bertrand M, Duflo E, Mullainathan S (2004). How much should we trust
differences-in-differences estimates? Quarterly Journal of Economics
119(1):249-275.
[doi:10.1162/003355304772839588](https://doi.org/10.1162/003355304772839588)

Cameron AC, Gelbach JB, Miller DL (2011). Robust inference with multiway
clustering. Journal of Business and Economic Statistics 29(2):238-249.
[doi:10.1198/jbes.2010.07136](https://doi.org/10.1198/jbes.2010.07136)

Cameron AC, Miller DL (2015). A practitioner's guide to cluster-robust
inference. Journal of Human Resources 50(2):317-372.
[doi:10.3368/jhr.50.2.317](https://doi.org/10.3368/jhr.50.2.317)

Applied to a staggered criminal-procedure reform, municipality by month:
Acosta C, Mejia D, Zorro Medina A (2023). On the tension between due
process protection and public safety: the case of an extensive
procedural reform in Colombia.
[doi:10.2139/ssrn.4585682](https://doi.org/10.2139/ssrn.4585682)

## See also

[`evstudy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md),
[`stgatt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stgatt.md),
[`perminf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/perminf.md),
[`plnpois`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plnpois.md).

## Examples

``` r
p <- polex()
plndid(p, "district", "month", "crmrate", "reformed")
#> ╭── Difference in differences ────────────────────────────────────────────────╮
#> │   Method           fixed-effects least squares, cluster-robust (CR1) errors │
#> │   Observations     720                                                      │
#> │   Clusters         20                                                       │
#> │   Confidence       95%                                                      │
#> │   Comparison mean  26.52                                                    │
#> │   Relative effect  -12.2% of the comparison mean                            │
#> │                                                                             │
#> │   Estimates                                                                 │
#> │   term     estimate      se  95% CI                 t  p_value              │
#> │   -------  --------  ------  ----------------  ------  -------              │
#> │   treated    -3.232  0.1164  [-3.475, -2.988]  -27.76  < 0.001              │
#> │                                                                             │
#> │   The policy's effect on the outcome is -3.232 (95% interval [-3.475,       │
#> │   -2.988]): the interval excludes 0, so the data distinguish it from no     │
#> │   effect.                                                                   │
#> │                                                                             │
#> │   The comparison mean is the pre-period mean outcome of the units not       │
#> │   (yet) treated.                                                            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
# clustered by region instead of district
plndid(p, "district", "month", "crmrate", "reformed", cl = "region")
#> ╭── Difference in differences ────────────────────────────────────────────────╮
#> │   Method           fixed-effects least squares, cluster-robust (CR1) errors │
#> │   Observations     720                                                      │
#> │   Clusters         4                                                        │
#> │   Confidence       95%                                                      │
#> │   Comparison mean  26.52                                                    │
#> │   Relative effect  -12.2% of the comparison mean                            │
#> │                                                                             │
#> │   Estimates                                                                 │
#> │   term     estimate      se  95% CI                 t  p_value              │
#> │   -------  --------  ------  ----------------  ------  -------              │
#> │   treated    -3.232  0.1656  [-3.759, -2.705]  -19.52  < 0.001              │
#> │                                                                             │
#> │   The policy's effect on the outcome is -3.232 (95% interval [-3.759,       │
#> │   -2.705]): the interval excludes 0, so the data distinguish it from no     │
#> │   effect.                                                                   │
#> │                                                                             │
#> │   The comparison mean is the pre-period mean outcome of the units not       │
#> │   (yet) treated.                                                            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

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
# the effect of the by-law, with income as a control, clustered by town
# (the default), weighted by population
plndid(own, "town", "year", "rate", "bylaw", covs = "income", w = "pop")
#> ╭── Difference in differences ────────────────────────────────────────────────╮
#> │   Method           fixed-effects least squares, cluster-robust (CR1) errors │
#> │   Observations     80                                                       │
#> │   Clusters         8                                                        │
#> │   Confidence       95%                                                      │
#> │   Comparison mean  47.43                                                    │
#> │   Relative effect  -8.3% of the comparison mean                             │
#> │                                                                             │
#> │   Estimates                                                                 │
#> │   term     estimate      se  95% CI                 t  p_value              │
#> │   -------  --------  ------  ----------------  ------  -------              │
#> │   treated    -3.914  0.1702  [-4.316, -3.511]  -22.99  < 0.001              │
#> │   income      0.227  0.0367  [0.140, 0.313]      6.17  < 0.001              │
#> │                                                                             │
#> │   The policy's effect on the outcome is -3.914 (95% interval [-4.316,       │
#> │   -3.511]): the interval excludes 0, so the data distinguish it from no     │
#> │   effect.                                                                   │
#> │                                                                             │
#> │   The comparison mean is the pre-period mean outcome of the units not       │
#> │   (yet) treated.                                                            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```
