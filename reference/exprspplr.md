# Exposure-response estimate with a bootstrap sensitivity interval

Fits the partially linear exposure-response model with
[`plrcf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plrcf.md)
(or any estimator with the same interface), then re-fits it on `nboot`
non-parametric resamples of the rows for a percentile interval (Efron
and Tibshirani 1993, chapter 13). The bootstrap interval does not lean
on the estimator's own standard error, so it is a check on it: when the
two disagree, the analytic one should not be trusted alone.

## Usage

``` r
exprspplr(data, y, expo, confs, nboot = 100L, rstate = 42L, estr = plrcf)
```

## Arguments

- data:

  A data frame with one row per unit.

- y, expo, confs:

  Column names: the outcome and the exposure (single strings) and the
  confounders (one or more strings).

- nboot:

  Number of resamples, a non-negative whole number (default 100); at
  least 10 must succeed.

- rstate:

  Seed for the resampling (default 42).

- estr:

  A function `(data, outcome, treatment, covariates)` returning a list
  with `ate` and `se`. The default is
  [`plrcf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plrcf.md);
  rmorie's `morie_estimate_double_ml()` has the same interface.

## Value

A list with `ate` (the full-sample estimate), `seana` (the estimator's
standard error), `seboot` (the standard deviation of the replicates),
`cilobs` and `ciupbs` (the 95% percentile interval), `nboot` (the number
of successful resamples) and `method` (the estimator's method with
`" + percentile bootstrap"`).

## Details

Each resample draws `nrow(data)` rows with replacement and calls
`estr(resample, outcome, exposure, confounders)`; a resample on which
the estimator fails is skipped, and the run stops if fewer than 10
succeed. The interval is the 2.5% and 97.5% type-7 quantiles of the
replicate estimates, and `seboot` their standard deviation. Resampling
uses `rstate` and restores R's own random stream afterwards. The cost is
`nboot + 1` estimator calls; with
[`plrcf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plrcf.md)
at n = 20000 and 100 resamples that is a few seconds. A progress bar on
stderr follows the resamples when a person is watching
(`options(morie.progress = TRUE)` outside an interactive session;
`options(morie.quiet = TRUE)` silences it).

Refusals: column names that are not strings, an `nboot` that is not a
single non-negative whole number, an estimator that is not a function,
and the estimator's own errors on the full sample.

## References

Efron, B. and Tibshirani, R. J. (1993). An Introduction to the
Bootstrap. Chapman and Hall.

## See also

[`cbootmean`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cbootmean.md)
for a bootstrap of a mean.

## Examples

``` r
set.seed(1)
d <- data.frame(x1 = rnorm(200), x2 = rnorm(200))
d$exposure <- 20 + 2 * d$x1 + rnorm(200)
d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(200)
r <- exprspplr(d, y = "asthma", expo = "exposure",
                           confs = c("x1", "x2"), nboot = 20)
r$ate
#> [1] 0.2536464
c(r$cilobs, r$ciupbs)
#> [1] 0.1365177 0.3476568

# Any estimator with the same interface: here an ordinary regression.
ols <- function(data, outcome, treatment, covariates) {
  f <- stats::reformulate(c(treatment, covariates), outcome)
  cf <- summary(stats::lm(f, data = data))$coefficients
  list(ate = cf[treatment, 1], se = cf[treatment, 2], method = "OLS")
}
exprspplr(d, "asthma", "exposure", c("x1", "x2"),
                      nboot = 20, estr = ols)$method
#> [1] "OLS + percentile bootstrap"

# Fewer than 10 resamples cannot give an interval.
try(exprspplr(d, "asthma", "exposure", c("x1", "x2"), nboot = 5))
#> Error : Only 5 successful bootstrap fits; need >=10. Inspect the model's convergence on your resamples.
```
