# Cross-fitted partially linear regression (double machine learning)

Estimates the effect of a continuous exposure (or treatment) on an
outcome after adjusting for confounders, by the double machine learning
recipe: the part of the outcome and of the exposure that the confounders
predict is removed with models fitted on other folds of the data, and
the effect is the slope of what is left. It answers questions such as
“how much does asthma incidence rise per microgram of NO2, holding
income and age structure fixed?”.

## Usage

``` r
plrcf(data, y, trt, covs, kfol = 5L, seed = 1L)
```

## Arguments

- data:

  A data frame with one row per unit.

- y, trt:

  Column names (single strings) of the outcome and of the continuous
  treatment or exposure; both numeric.

- covs:

  Column names of the confounders (one or more strings), numeric. Code a
  categorical confounder as indicator columns first.

- kfol:

  Number of cross-fitting folds, a whole number of at least 2 (default
  5).

- seed:

  Seed of the fold assignment (default 1), so the estimate is
  reproducible.

## Value

A list of class `c("rmbl_plr", "list")` (its print method shows it as a
box) with `ate` (the estimate of \\\theta\\: the change in the outcome
per unit of the treatment), `se` (its sandwich standard error), `n`
(complete rows used), `kfol` and `method` (a string naming the
estimator).

## Details

The partially linear model \\Y = \theta D + g(X) + U\\, \\D = m(X) + V\\
of Chernozhukov et al. (2018, section 4.2), estimated by the DML2
cross-fitting recipe: the sample is split into `kfol` folds; for each
fold the nuisances \\m\\ and \\g\\ are fitted on the other folds and
predicted on it; \\\hat\theta\\ is the slope of the out-of-fold outcome
residuals on the out-of-fold treatment residuals, \$\$\hat\theta =
\sum_i \hat V_i \hat U_i / \sum_i \hat V_i^2,\$\$ with the sandwich
standard error \\\sqrt{\sum_i \hat V_i^2 (\hat U_i - \hat\theta \hat
V_i)^2} / \sum_i \hat V_i^2\\. The nuisances here are ordinary least
squares on the covariates, which is the right learner when the
confounding is approximately linear and keeps the estimator fully
deterministic given `seed`; rmorie's `morie_estimate_double_ml()` offers
richer learners and can be passed to
[`exprspplr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/exprspplr.md)
through `estimator`.

Each fold's two least-squares fits are computed from the normal
equations of the covariates centred and scaled by their full-sample
moments (the same column space, so the same fitted values as
[`lm.fit`](https://rdrr.io/r/stats/lmfit.html)), solved by Cholesky; a
fold whose cross-product is poorly conditioned (reciprocal condition
number below 1e-5: collinear covariates or a constant column) uses
[`lm.fit`](https://rdrr.io/r/stats/lmfit.html) instead, whose pivoting
drops the redundant columns (their coefficients count as 0). An n =
20000 fit takes a few milliseconds. A bar on stderr shows the folds when
the work is slow enough to need one (see
[`blprog`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blprog.md)).

Rows with a missing value in any of the named columns are dropped first
(`n` reports the rows used). The folds are a random permutation of
`rep_len(1:kfol, n)` drawn with `seed`; R's own random stream is
restored afterwards. Refusals: a column name that is not a single string
(several for `covs`) or is not in `data`; a non-numeric column (a factor
is not a code); `kfol` that is not a whole number of at least 2; fewer
than `2 * kfol` complete rows; and a treatment with no variation left
after the covariates are partialled out.

## References

Chernozhukov, V., Chetverikov, D., Demirer, M., Duflo, E., Hansen, C.,
Newey, W. and Robins, J. (2018). Double/debiased machine learning for
treatment and structural parameters. The Econometrics Journal 21(1),
C1-C68.

## Examples

``` r
set.seed(1)
d <- data.frame(x1 = rnorm(200), x2 = rnorm(200))
d$exposure <- 20 + 2 * d$x1 + rnorm(200)
d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(200)
fit <- plrcf(d, "asthma", "exposure", c("x1", "x2"))
fit$ate
#> [1] 0.2536464

# A 95 percent normal confidence interval from the standard error.
fit$ate + c(-1.96, 1.96) * fit$se
#> [1] 0.1156209 0.3916718

# The fold split changes the estimate a little; ten folds instead of five.
plrcf(d, "asthma", "exposure", c("x1", "x2"), kfol = 10, seed = 2)$ate
#> [1] 0.2676102

# A text column is refused rather than read as codes.
d$region <- sample(c("north", "south"), 200, replace = TRUE)
try(plrcf(d, "asthma", "exposure", c("x1", "region")))
#> Error : column `region` must be numeric (a factor or character column is not a code)
```
