# A fixed-effects Poisson or negative binomial regression for counts

The effect of a policy on counts (stops, arrests, offences) with unit
and period fixed effects, reported as an incidence rate ratio, with
cluster-robust standard errors that do not need the counts to be
Poisson.

## Usage

``` r
plnpois(
  data,
  unit,
  time,
  y,
  trtd,
  covs = NULL,
  offset = NULL,
  cl = NULL,
  family = c("poisson", "negbin"),
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

- offset:

  Optional column name of the log exposure (for example log population).

- cl:

  Column name of the clusters (default the unit), or two column names
  for two-way clustering (Cameron, Gelbach and Miller 2011): \\V_a +
  V_b - V\_{ab}\\, each term with the small-sample factor of the
  dimension with fewer clusters, and t on its \\G - 1\\ degrees of
  freedom. A composite cluster (district by month, say) is one column
  made with [`interaction()`](https://rdrr.io/r/base/interaction.html).
  Fewer than ten clusters give a warning (CR1 errors are unreliable with
  so few;
  [`wcb`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wcb.md)
  is made for that case), and so does a cluster that changes within a
  unit.

- family:

  `"poisson"` (default) or `"negbin"` (NB2, \\Var(Y) = \mu +
  \mu^2/\theta\\, with \\\theta\\ by maximum likelihood).

- conflvl:

  Confidence level of the intervals reported (default 0.95).

## Value

A data frame of class `rmbl_fe_poisson`, one row per term: `term`,
`estimate` (log scale), `se`, `rateratio`, `lower`, `upper` (of the rate
ratio), `p_value`; attributes `n`, `drounits`, `clusters`, `family`,
`theta` (`Inf` for the Poisson).

## Details

The model is \\E(Y\_{it}) = \exp(\beta T\_{it} + X\_{it}'\gamma +
\delta_i + \mu_t)\\ (times the exposure, with `offset` its log), fitted
by maximum likelihood. Units whose counts are all zero carry no
information about \\\beta\\ and are dropped first, as are periods with
no count anywhere. The Poisson likelihood with fixed effects is
consistent for \\\beta\\ whatever the dispersion (Wooldridge 1999); the
variance is the cluster-robust sandwich, with the small-sample factors
of
[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md).
The rate ratio is \\e^{\beta}\\, with interval \\e^{\hat\beta \pm
z\\se}\\.

With `family = "negbin"` the variance is \\\mu + \mu^2/\theta\\: the fit
alternates iteratively reweighted least squares at fixed \\\theta\\ with
the maximum of the profile likelihood in \\\theta\\, and the sandwich
uses the negative binomial scores with \\\theta\\ held at its estimate
(as
[`sandwich::vcovCL()`](https://zeileis.codeberg.page/sandwich/reference/vcovCL.html)
does for [`MASS::glm.nb()`](https://rdrr.io/pkg/MASS/man/glm.nb.html);
[`fixest::fenegbin()`](https://lrberge.github.io/fixest/reference/femlm.html),
which treats \\\theta\\ as a parameter of the variance too, gives
slightly larger errors). With unit dummies this is the unconditional
fixed-effects negative binomial, which behaves well as the number of
periods grows (Allison and Waterman 2002); with few periods per unit
prefer the Poisson, which is consistent whatever the dispersion.

## References

Wooldridge JM (1999). Distribution-free estimation of some nonlinear
panel data models. Journal of Econometrics 90(1):77-97.
[doi:10.1016/S0304-4076(98)00033-5](https://doi.org/10.1016/S0304-4076%2898%2900033-5)

Santos Silva JMC, Tenreyro S (2006). The log of gravity. Review of
Economics and Statistics 88(4):641-658.
[doi:10.1162/rest.88.4.641](https://doi.org/10.1162/rest.88.4.641)

Allison PD, Waterman RP (2002). Fixed-effects negative binomial
regression models. Sociological Methodology 32:247-265.
[doi:10.1111/1467-9531.00117](https://doi.org/10.1111/1467-9531.00117)

## Examples

``` r
p <- polex()
plnpois(p, "district", "month", "crimes", "reformed", offset = "logpop")
#> ╭── Fixed-effects count model ────────────────────────────────────────────╮
#> │   Model          Poisson                                                │
#> │   Fixed effects  unit and period                                        │
#> │   Observations   720                                                    │
#> │   Clusters       20                                                     │
#> │                                                                         │
#> │   term     estimate       se  rate_ratio  interval          p_value     │
#> │   -------  --------  -------  ----------  ----------------  -------     │
#> │   treated  -0.09215  0.02221      0.9120  [0.8731, 0.9525]  < 0.001     │
#> │                                                                         │
#> │   Under the policy the expected count is multiplied by 0.912 (its       │
#> │   interval [0.8731, 0.9525]): the interval excludes 1, so the data      │
#> │   distinguish it from no effect. A ratio of 0.912 is a 8.8% fall.       │
#> │                                                                         │
#> │   The estimate is on the log scale; the interval is for the rate ratio. │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# these counts are not overdispersed, so the negative binomial collapses
# to the Poisson fit and says so
plnpois(p, "district", "month", "crimes", "reformed", offset = "logpop",
           family = "negbin")
#> Warning: no overdispersion: theta is at its bound, the Poisson model fits
#> ╭── Fixed-effects count model ────────────────────────────────────────────╮
#> │   Model          negative binomial (theta 3229000)                      │
#> │   Fixed effects  unit and period                                        │
#> │   Observations   720                                                    │
#> │   Clusters       20                                                     │
#> │                                                                         │
#> │   term     estimate       se  rate_ratio  interval          p_value     │
#> │   -------  --------  -------  ----------  ----------------  -------     │
#> │   treated  -0.09215  0.02221      0.9120  [0.8731, 0.9525]  < 0.001     │
#> │                                                                         │
#> │   Under the policy the expected count is multiplied by 0.912 (its       │
#> │   interval [0.8731, 0.9525]): the interval excludes 1, so the data      │
#> │   distinguish it from no effect. A ratio of 0.912 is a 8.8% fall.       │
#> │                                                                         │
#> │   The estimate is on the log scale; the interval is for the rate ratio. │
#> ╰─────────────────────────────────────────────────────────────────────────╯

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
# counts with the population as exposure
own$crimes <- round(own$rate * own$pop / 1e4)
own$logpop <- log(own$pop)
plnpois(own, "town", "year", "crimes", "bylaw", offset = "logpop")
#> ╭── Fixed-effects count model ────────────────────────────────────────────╮
#> │   Model          Poisson                                                │
#> │   Fixed effects  unit and period                                        │
#> │   Observations   80                                                     │
#> │   Clusters       8                                                      │
#> │                                                                         │
#> │   term     estimate        se  rate_ratio  interval          p_value    │
#> │   -------  --------  --------  ----------  ----------------  -------    │
#> │   treated  -0.08385  0.005628      0.9196  [0.9095, 0.9298]  < 0.001    │
#> │                                                                         │
#> │   Under the policy the expected count is multiplied by 0.9196 (its      │
#> │   interval [0.9095, 0.9298]): the interval excludes 1, so the data      │
#> │   distinguish it from no effect. A ratio of 0.9196 is a 8.04% fall.     │
#> │                                                                         │
#> │   The estimate is on the log scale; the interval is for the rate ratio. │
#> ╰─────────────────────────────────────────────────────────────────────────╯
```
