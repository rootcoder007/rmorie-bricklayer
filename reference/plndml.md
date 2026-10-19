# Double machine learning for panels with fixed effects

The effect of a treatment (continuous or binary) on an outcome in a
unit-by-period panel, with unit and period fixed effects removed and the
confounding through covariates fitted by a machine learner, cross-fitted
by unit, with an orthogonal (Neyman) score and errors clustered by unit.

## Usage

``` r
plndml(
  data,
  unit,
  time,
  y,
  trt,
  covs,
  fe = c("unit", "time"),
  lrn = "lasso",
  basis = c("linear", "poly2"),
  folds = 5L,
  nrep = 1L,
  seed = 1L,
  cl = NULL,
  conflvl = 0.95
)
```

## Arguments

- data:

  A data frame, one row per unit and period.

- unit, time, y:

  Column names: the unit, the period (numeric, for example a year or a
  month index) and the outcome.

- trt:

  Column name of the treatment (continuous, or 0/1).

- covs:

  Column names of the time-varying covariates.

- fe:

  `c("unit", "time")` (default) or `"time"`.

- lrn:

  `"lasso"` (default), `"ridge"`, `"ols"`, or a function.

- basis:

  `"linear"` (default) or `"poly2"`.

- folds:

  Cross-fitting folds of units (default 5).

- nrep:

  Repeated sample splits (default 1).

- seed:

  Seed for the folds (default 1).

- cl:

  Column name of the clusters (default the unit), or two column names
  for two-way clustering (Cameron, Gelbach and Miller 2011): \\V_a +
  V_b - V\_{ab}\\, each term with the small-sample factor of the
  dimension with fewer clusters, and t on its \\G - 1\\ degrees of
  freedom. A composite cluster (district by month, say) is one column
  made with [`interaction()`](https://rdrr.io/r/base/interaction.html).

- conflvl:

  Confidence level (default 0.95).

## Value

A data frame of class `rmbl_dml`: `estimate`, `se`, `lower`, `upper`,
`t`, `p_value`; attributes `n`, `clusters`, `learner`, `folds`,
`repeats`, and `r2` (the out-of-fold R-squared of the two nuisance
fits).

## Details

The model is the partially linear panel model \$\$Y\_{it} = \theta
D\_{it} + g(X\_{it}) + \alpha_i + \gamma_t + \varepsilon\_{it}.\$\$
Following Clarke and Polselli (2025), the fixed effects are removed by
the within transformation (\\\tilde Y\\, \\\tilde D\\, \\\tilde X\\),
and \\\ell(\tilde X) = E(\tilde Y \mid \tilde X)\\ and \\m(\tilde X) =
E(\tilde D \mid \tilde X)\\ are fitted by the learner on \\K\\ folds of
units (all of a unit's periods in one fold, so a unit's own errors never
help predict it). With the out-of-fold residuals \\U = \tilde Y -
\hat\ell\\ and \\V = \tilde D - \hat m\\, the partialling-out estimator
is \$\$\hat\theta = \sum V U / \sum V^2,\$\$ the solution of the
Neyman-orthogonal score \\(U - \theta V) V\\ of Chernozhukov et al.
(2018). Its variance is the cluster-robust sandwich over units, \$\$\hat
V = \frac{G}{G - 1} \frac{\sum_g \big(\sum\_{i \in g} V_i (U_i -
\hat\theta V_i)\big)^2}{(\sum V^2)^2},\$\$ with t on \\G - 1\\ degrees
of freedom. Folds are drawn with `seed`; `nrep` repeated splits are
combined by the median of the estimates and of the variances plus the
squared deviations from it (Chernozhukov et al. 2018, section 3.4).

Learners, all in base R: `"lasso"` (coordinate descent, penalty by
5-fold cross-validation), `"ridge"` (penalty by generalised
cross-validation), `"ols"`, or a function returning predictions (for
example a random forest from another package), called as
`function(x_train, y_train, x_test)`. `basis = "poly2"` adds squares and
pairwise products of the covariates, built from the covariates as
observed and then demeaned, so a confounding that is a combination of
them is removed exactly. The demeaned features are what the learners
see: a covariate fixed within a unit is absorbed by the unit effect and
carries no information. A learner given only the demeaned covariates (a
random forest, say) approximates a nonlinear confounding less well; the
poly2 basis, or a basis of the user's own as further covariates, is the
remedy.

## References

Chernozhukov V, Chetverikov D, Demirer M, Duflo E, Hansen C, Newey W,
Robins J (2018). Double/debiased machine learning for treatment and
structural parameters. The Econometrics Journal 21(1):C1-C68.
[doi:10.1111/ectj.12097](https://doi.org/10.1111/ectj.12097)

Clarke PS, Polselli A (2025). Double machine learning for static panel
models with fixed effects. The Econometrics Journal 29:69-86.
[doi:10.1093/ectj/utaf011](https://doi.org/10.1093/ectj/utaf011)

## See also

[`plrcf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plrcf.md)
(one cross-section),
[`stgatt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stgatt.md)
with covariates (doubly robust difference in differences).

## Examples

``` r
p <- polex()
set.seed(9)
p$unemployment <- 6 + sin(p$month / 6) + stats::rnorm(nrow(p), 0, 0.5)
p$patrols <- 0.5 * p$unemployment + p$reformed + stats::rnorm(nrow(p))
plndml(p, "district", "month", "crmrate", "patrols",
          c("unemployment", "arrrate"), lrn = "ridge")
#> Double machine learning with fixed effects (ridge, 5 folds of units, 1 split)
#>  estimate      se   lower   upper      t   p_value
#>   -0.2957 0.05072 -0.4019 -0.1896 -5.831 1.287e-05
#> 720 observations, 20 clusters; out-of-fold R-squared: outcome -0.000, treatment 0.081
```
