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

  Confidence level (default 0.95).

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
#> Synthetic difference in differences: -3.126 (jackknife s.e. 0.2473; -3.611 to -2.641)
#> Unit weights: D12 0.203, D16 0.200, D08 0.200, D20 0.199, D04 0.198 
```
