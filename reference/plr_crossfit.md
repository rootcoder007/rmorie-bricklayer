# Cross-fitted partially linear regression (double machine learning)

The partially linear model \\Y = \theta D + g(X) + U\\, \\D = m(X) + V\\
of Chernozhukov et al. (2018, section 4.2), estimated by the DML2
cross-fitting recipe: the sample is split into `k_folds` folds; for each
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
[`exposure_response_plr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/exposure_response_plr.md)
through `estimator`.

## Usage

``` r
plr_crossfit(data, outcome, treatment, covariates, k_folds = 5L, seed = 1L)
```

## Arguments

- data:

  A data frame.

- outcome, treatment:

  Column names of the outcome and the (continuous) treatment or
  exposure.

- covariates:

  Column names of the confounders.

- k_folds:

  Number of cross-fitting folds (default 5).

- seed:

  Seed of the fold assignment.

## Value

A list with `ate` (the estimate of \\\theta\\), `se`, `n`, `k_folds` and
`method`.

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
plr_crossfit(d, "asthma", "exposure", c("x1", "x2"))$ate
#> [1] 0.2536464
```
