# Causal effects with cross-fitted double machine learning

[`plr_crossfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plr_crossfit.md)
estimates the average effect of a treatment on an outcome when the
treated and the untreated differ in measured ways (confounders). It fits
the partially linear model

``` math
 Y = \theta D + g(X) + \varepsilon, \qquad D = m(X) + v, 
```

by the double machine learning recipe of Chernozhukov et al. (2018): the
outcome and the treatment are each predicted from the confounders $`X`$
on folds the row was not part of (cross-fitting), and $`\theta`$ is the
regression of the outcome residuals on the treatment residuals (DML2),
with a sandwich standard error. When the effect is the same for
everyone, $`\theta`$ is the average treatment effect (ATE); otherwise it
is a variance-weighted average of the individual effects.
[`exposure_response_plr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/exposure_response_plr.md)
bootstraps the same estimator for a continuous exposure (see the
air-pollution vignette). The nuisances $`g`$ and $`m`$ are ordinary
least squares fits, so $`\theta`$ is consistent when they are linear in
the columns given; add squares, interactions or splines as columns where
they are not.

## A known effect, recovered

Confounding biases the simple comparison; the cross-fitted estimate
removes it. Here the true effect of `d` on `y` is 2, and `x1` drives
both:

``` r

set.seed(42)
n <- 2000
sim <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
sim$d <- rbinom(n, 1, plogis(1.5 * sim$x1))
sim$y <- 2 * sim$d + 3 * sim$x1 + sim$x2 + rnorm(n)
mean(sim$y[sim$d == 1]) - mean(sim$y[sim$d == 0])   # biased by x1
#> [1] 5.373073
fit <- plr_crossfit(sim, "y", "d", c("x1", "x2"))
fit$ate
#> [1] 2.039439
fit$ate + c(-1.96, 1.96) * fit$se
#> [1] 1.938179 2.140699
```

## The NSW job-training experiment, and what observational data can recover

LaLonde (1986) took the National Supported Work Demonstration, a
randomised job-training programme of the 1970s, and asked whether the
econometric methods of the day could recover its experimental effect on
1978 earnings when the randomised controls are replaced by a survey
sample (the PSID). Dehejia and Wahba (1999) kept the men with 1974
earnings: 185 treated, 260 randomised controls, and 2,490 PSID-1
comparison men. The three files are on data.rmorie.com (`rmbl login`
once), checked against the SHA-256 the manifest lists:

``` r

tr <- bricklayer_data_load("nsw_dw/treated")
ct <- bricklayer_data_load("nsw_dw/control")
ps <- bricklayer_data_load("nsw_dw/psid_controls")
```

Or, without signing in, from Rajeev Dehejia’s own pages
(whitespace-separated text):

``` r

cols <- c("treat", "age", "educ", "black", "hisp", "married", "nodegree", "re74", "re75", "re78")
nber <- function(f) {
  dest <- file.path(tempdir(), f)
  bricklayer_download(paste0("https://users.nber.org/~rdehejia/data/", f), dest)
  stats::setNames(utils::read.table(dest), cols)
}
tr <- nber("nswre74_treated.txt")
ct <- nber("nswre74_control.txt")
ps <- nber("psid_controls.txt")
```

The PSID men are older, more often married and earned about nine times
as much before the programme; the randomised controls look like the
treated:

| Mean                | age   | educ  | black | married | nodegree | re74      | re75      |
|---------------------|-------|-------|-------|---------|----------|-----------|-----------|
| Treated             | 25.82 | 10.35 | 0.84  | 0.19    | 0.71     | 2,095.57  | 1,532.06  |
| Randomised controls | 25.05 | 10.09 | 0.83  | 0.15    | 0.83     | 2,107.03  | 1,266.91  |
| PSID controls       | 34.85 | 12.12 | 0.25  | 0.87    | 0.31     | 19,428.75 | 19,063.34 |

The experimental benchmark, and the same question asked of the
observational sample:

``` r

x <- c("age", "educ", "black", "hisp", "married", "nodegree", "re74", "re75")
exp <- rbind(tr, ct)
obs <- rbind(tr, ps)
mean(tr$re78) - mean(ct$re78)                 # the experiment
mean(tr$re78) - mean(ps$re78)                 # treated against the PSID, unadjusted
plr_crossfit(exp, "re78", "treat", x)
plr_crossfit(obs, "re78", "treat", x)
plr_crossfit(obs, "re78", "treat", x, k_folds = 10, seed = 2)
```

Run on 15 October 2026 (1982 US dollars of 1978 earnings):

| Sample and estimator | Effect | Standard error | 95% interval |
|----|----|----|----|
| Experiment, difference in means | 1,794.3 |  |  |
| Experiment, [`plr_crossfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plr_crossfit.md) | 1,695.9 | 680.8 | 361.5 to 3,030.2 |
| Treated vs PSID, difference in means | -15,204.8 |  |  |
| Treated vs PSID, [`plr_crossfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plr_crossfit.md) | 618.3 | 791.1 | -932.3 to 2,168.9 |
| Treated vs PSID, [`plr_crossfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plr_crossfit.md), 10 folds, seed 2 | 748.4 | 777.5 | -775.5 to 2,272.3 |

Adjusting for the eight pre-programme covariates turns a
fifteen-thousand-dollar penalty into a small positive effect whose
interval covers the experimental one, though it sits well below it and
is far less precise. Two things limit it. The nuisances are linear, so
the large earnings gap is adjusted for only as a straight line; and the
overlap is thin: most PSID men earned more before the programme than
almost any treated man, so the comparison rests on the few who look like
them. Dehejia and Wahba show that trimming the comparison group to the
region of common support (on an estimated propensity score) brings the
observational estimate close to the experiment; with
[`plr_crossfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plr_crossfit.md),
restrict `obs` to that region before fitting. The cross-fit split moves
the estimate by about a sixth of a standard error, which is why the seed
and the number of folds are arguments.

## References

Chernozhukov, V., Chetverikov, D., Demirer, M., Duflo, E., Hansen, C.,
Newey, W. and Robins, J. (2018). Double/debiased machine learning for
treatment and structural parameters. *The Econometrics Journal* 21(1),
C1-C68.

Dehejia, R. H. and Wahba, S. (1999). Causal effects in nonexperimental
studies: reevaluating the evaluation of training programs. *Journal of
the American Statistical Association* 94(448), 1053-1062.

LaLonde, R. J. (1986). Evaluating the econometric evaluations of
training programs with experimental data. *American Economic Review*
76(4), 604-620.
