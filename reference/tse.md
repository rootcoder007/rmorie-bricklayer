# How far parallel trends can fail before an effect disappears

Bounds on the effects of an
[`evstudy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md)
when the trend after adoption may depart from parallel by up to \\\bar
M\\ times the largest departure seen before it (Rambachan and Roth's
relative magnitudes), with a conservative interval and the `"breakdown"`
\\\bar M\\ at which the interval first includes zero.

## Usage

``` r
tse(
  x,
  mbar = c(0, 0.5, 1, 1.5, 2),
  target = "average",
  draws = 5000L,
  seed = NULL,
  conflvl = 0.95
)
```

## Arguments

- x:

  An
  [`evstudy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md)
  result with one lead at least.

- mbar:

  The values of \\\bar M\\ (default 0, 0.5, 1, 1.5, 2).

- target:

  `"average"` (the mean of the post-period effects, default) or an event
  time.

- draws:

  Normal draws for the interval (default 5000).

- seed:

  Optional seed for the bootstrap draws.

- conflvl:

  Confidence level of the robust interval, a number strictly between 0
  and 1 (default 0.95: the 2.5\\ drawn bounds).

## Value

A data frame of class `rmbl_sensitivity`: `mbar`, `lowerbnd`, `upbound`
(the identified set at the estimates), `lower`, `upper` (the interval);
attribute `breakdown` (the smallest \\\bar M\\ whose interval includes
0, found by bisection; `Inf` if none up to 10).

## Details

Let \\\delta_e\\ be the bias of the event-time coefficient \\\beta_e\\,
with \\\delta\_{-1} = 0\\ at the reference period and the pre-period
biases identified by the leads. The relative-magnitudes restriction is
\\\|\delta\_{e+1} - \delta_e\| \le \bar M D\\, with \\D = \max\_{s \< 0}
\|\delta\_{s+1} - \delta_s\|\\ the largest change between consecutive
pre-periods. The bias at post-period \\e \ge 0\\ is then at most \\(e +
1)\bar M D\\ in absolute value, so the identified set for the effect
\\\tau_e\\ is \\\beta_e \pm (e + 1)\bar M D\\, and for the average
post-period effect the average of those. The interval draws
\\(\beta^\*)\\ from the normal distribution of the estimates (with the
event study's cluster-robust covariance), computes the bounds for each,
and takes the \\\alpha/2\\ quantile of the lower bound and the \\1 -
\alpha/2\\ quantile of the upper: by Bonferroni it covers the identified
set, and so the effect, with probability at least `conflvl`. It is
conservative; Rambachan and Roth's conditional and hybrid intervals (the
`HonestDiD` package) are shorter.

## References

Rambachan A, Roth J (2023). A more credible approach to parallel trends.
Review of Economic Studies 90(5):2555-2591.
[doi:10.1093/restud/rdad018](https://doi.org/10.1093/restud/rdad018)

## Examples

``` r
p <- polex()
es <- evstudy(p, "district", "month", "crmrate", "refmonth",
                  leads = 3, lags = 4)
tse(es, seed = 1)
#> ╭── Sensitivity to parallel trends ──────────────────────────────────────╮
#> │   Method                 relative magnitudes (Rambachan and Roth)      │
#> │   Target                 average post-period effect                    │
#> │   Breakdown              Mbar = 0.6214                                 │
#> │   Robust interval level  95%                                           │
#> │                                                                        │
#> │    mbar  identified_set    robust_interval                             │
#> │   -----  ----------------  ----------------                            │
#> │   0.000  [-3.166, -3.166]  [-3.916, -2.400]                            │
#> │   0.500  [-3.865, -2.467]  [-4.980, -0.479]                            │
#> │   1.000  [-4.565, -1.768]  [-6.788, 1.519]                             │
#> │   1.500  [-5.264, -1.069]  [-8.811, 3.532]                             │
#> │   2.000  [-5.963, -0.370]  [-10.842, 5.572]                            │
#> │                                                                        │
#> │   The negative effect stays clear of zero while the trend after        │
#> │   adoption departs from parallel by up to 0.621 times the largest      │
#> │   departure before it. A departure as large as the pre-period's (Mbar  │
#> │   1) is enough to lose it: the conclusion leans on parallel trends.    │
#> │                                                                        │
#> │   Mbar bounds how far the trend after adoption may depart from         │
#> │   parallel, as a multiple of the largest departure seen before it; the │
#> │   effect is distinguishable from zero until the robust interval first  │
#> │   includes 0, at the breakdown value.                                  │
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
es <- evstudy(own, "town", "year", "rate", "first", leads = 3, lags = 3)
# a 90 percent robust interval
tse(es, seed = 1, conflvl = 0.9)
#> ╭── Sensitivity to parallel trends ──────────────────────────────────────╮
#> │   Method                 relative magnitudes (Rambachan and Roth)      │
#> │   Target                 average post-period effect                    │
#> │   Breakdown              Mbar = 0.9629                                 │
#> │   Robust interval level  90%                                           │
#> │                                                                        │
#> │    mbar  identified_set    robust_interval                             │
#> │   -----  ----------------  ----------------                            │
#> │   0.000  [-4.016, -4.016]  [-5.236, -2.802]                            │
#> │   0.500  [-4.052, -3.979]  [-6.637, -1.345]                            │
#> │   1.000  [-4.089, -3.943]  [-8.056, 0.108]                             │
#> │   1.500  [-4.125, -3.907]  [-9.506, 1.600]                             │
#> │   2.000  [-4.162, -3.870]  [-11.020, 3.300]                            │
#> │                                                                        │
#> │   The negative effect stays clear of zero while the trend after        │
#> │   adoption departs from parallel by up to 0.963 times the largest      │
#> │   departure before it. A departure as large as the pre-period's (Mbar  │
#> │   1) is enough to lose it: the conclusion leans on parallel trends.    │
#> │                                                                        │
#> │   Mbar bounds how far the trend after adoption may depart from         │
#> │   parallel, as a multiple of the largest departure seen before it; the │
#> │   effect is distinguishable from zero until the robust interval first  │
#> │   includes 0, at the breakdown value.                                  │
#> ╰────────────────────────────────────────────────────────────────────────╯
```
