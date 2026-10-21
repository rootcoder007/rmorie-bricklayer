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
  seed = NULL
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

  Optional seed.

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
#> Sensitivity of the average post-period effect to departures from parallel trends (relative magnitudes)
#>  mbar lowerbnd upbound   lower  upper
#>   0.0   -3.166 -3.1662  -3.916 -2.400
#>   0.5   -3.865 -2.4671  -4.980 -0.479
#>   1.0   -4.565 -1.7679  -6.788  1.519
#>   1.5   -5.264 -1.0687  -8.811  3.532
#>   2.0   -5.963 -0.3696 -10.842  5.572
#> Breakdown: the interval first includes 0 at Mbar = 0.6213523
```
