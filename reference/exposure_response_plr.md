# Exposure-response estimate with a bootstrap sensitivity interval

Fits the partially linear exposure-response model with
[`plr_crossfit`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plr_crossfit.md)
(or any estimator with the same interface), then re-fits it on
`n_bootstrap` non-parametric resamples of the rows for a percentile
interval (Efron and Tibshirani 1993, chapter 13).

## Usage

``` r
exposure_response_plr(
  data,
  outcome,
  exposure,
  confounders,
  n_bootstrap = 100L,
  random_state = 42L,
  estimator = plr_crossfit
)
```

## Arguments

- data:

  A data frame.

- outcome, exposure, confounders:

  Column names.

- n_bootstrap:

  Number of resamples (default 100).

- random_state:

  Seed for the resampling.

- estimator:

  A function `(data, outcome, treatment, covariates)` returning a list
  with `ate` and `se`. The default is
  [`plr_crossfit`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plr_crossfit.md);
  rmorie's `morie_estimate_double_ml()` has the same interface.

## Value

A list with `ate`, `se_analytic`, `se_bootstrap`, `ci_lower_bs`,
`ci_upper_bs`, `n_bootstrap` and `method`.

## References

Efron, B. and Tibshirani, R. J. (1993). An Introduction to the
Bootstrap. Chapman and Hall.

## Examples

``` r
set.seed(1)
d <- data.frame(x1 = rnorm(200), x2 = rnorm(200))
d$exposure <- 20 + 2 * d$x1 + rnorm(200)
d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(200)
exposure_response_plr(d, outcome = "asthma", exposure = "exposure",
                      confounders = c("x1", "x2"), n_bootstrap = 20)$ate
#> [1] 0.2536464
```
