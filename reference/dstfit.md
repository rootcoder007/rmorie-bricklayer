# Fit and rank candidate distributions

Fits candidate distributions to one numeric variable by maximum
likelihood, ranks them by AIC, and reports for each the BIC, a
Kolmogorov-Smirnov distance, an Anderson-Darling statistic and
percentile bootstrap intervals for its parameters. A Hill estimate of
the tail index is added for positive data. Everything is base R.

## Usage

``` r
dstfit(x, fams = NULL, nboot = 200L, conflvl = 0.95, seed = 1L, k = NULL)

# S3 method for class 'rmbl_dstfit'
format(x, digits = 4L, ...)

# S3 method for class 'rmbl_dstfit'
print(x, ...)
```

## Arguments

- x:

  Numeric vector, the variable.

- fams:

  Character vector of families (see Details), or `NULL` for every family
  the data allow.

- nboot:

  Whole number, default 200: bootstrap resamples (0 for none).

- conflvl:

  Number in (0, 1), default 0.95: the bootstrap and Hill interval level.

- seed:

  Whole number, default 1: the seed of the bootstrap.

- k:

  Whole number or `NULL`: the upper order statistics of the Hill
  estimate.

- digits:

  Significant digits of the fit table's numbers.

- ...:

  For [`print()`](https://rdrr.io/r/base/print.html) and
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html): see
  [`plot.rmbl_dstfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot.rmbl_dstfit.md).

## Value

A list of class `c("rmbl_dstfit", "list")`:

- `table`:

  data frame, one row per family ranked by AIC: `rank`, `family`,
  `npar`, `loglik`, `aic`, `bic`, `ks`, `ad`, `converged` and `params`
  (the estimates as text).

- `fits`:

  named list of the estimates (named numeric vectors) of the converged
  fits.

- `boot`:

  data frame: `family`, `param`, `estimate`, `lower`, `upper` (`NA`
  without a bootstrap).

- `hill`:

  list: `k`, `alpha`, `lower`, `upper`, or `NULL` for data that are not
  all positive or fewer than ten values.

- `x`, `nmiss`, `discrete`, `conflvl`:

  the data used, the count dropped, whether the data are counts, and the
  level.

## Details

The families and their parameters: `normal` (`mean`, `sd`), `lognormal`
(`meanlog`, `sdlog`), `exponential` (rate), `gamma` (shape, rate),
`weibull` (shape, scale), `t` (location, scale, df: a location-scale
Student t), `pareto` (`xmin`, `alpha`, with `xmin` the smallest value,
its maximum likelihood estimate), `beta` (shape1, shape2) for
proportions, and for counts `poisson` (lambda), `negbin` (size, mu),
`zip` (pi, lambda) and `zinb` (pi, size, mu), the zero-inflated forms
with `pi` the share of structural zeros. The normal, lognormal,
exponential, Pareto and Poisson estimates are closed form; the negative
binomial searches its size alone (its mu estimate is the mean); the rest
are maximised by [`optim()`](https://rdrr.io/r/stats/optim.html) on a
log or logit scale, Nelder-Mead then BFGS.

With `fams = NULL` every family the data allow is fitted: for whole
numbers of 0 or more the count families; otherwise the positive families
for values above 0 (`exponential` for values of 0 or more) and `beta`
for values strictly between 0 and 1; and `normal` and `t` always. A
family named in `fams` that the data do not allow is refused. A fit that
fails (the optimiser stops at a non-finite likelihood) is a row with
`converged = FALSE` and no statistics.

AIC is \\2k - 2\ell\\ and BIC \\k \log n - 2\ell\\. The
Kolmogorov-Smirnov and Anderson-Darling statistics use the fitted
parameters, so their usual null distributions do not apply; they rank
fits, they are not tests. The bootstrap resamples the data `nboot` times
and refits; the interval is the percentile interval at `conflvl`. The
Hill estimator uses the `k` largest values (default \\\lfloor\sqrt
n\rfloor\\): \\\hat\alpha = k / \sum\_{i \le k} \log(x\_{(n-i+1)} /
x\_{(n-k)})\\, with the asymptotic interval \\\hat\alpha (1 \pm z /
\sqrt k)\\.

Missing values are dropped and counted (`nmiss`). Errors: `x` not
numeric, an infinite value, fewer than five values, all values equal, an
unknown family or one the data do not allow. The bootstrap is seeded
with `seed` for this call only; the session's random stream is left as
it was.

## References

Hill BM (1975). A simple general approach to inference about the tail of
a distribution. *Annals of Statistics* 3, 1163–1174.
[doi:10.1214/aos/1176343247](https://doi.org/10.1214/aos/1176343247)

Anderson TW, Darling DA (1954). A test of goodness of fit. *JASA* 49,
765–769.
[doi:10.1080/01621459.1954.10501232](https://doi.org/10.1080/01621459.1954.10501232)

## See also

[`plot.rmbl_dstfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot.rmbl_dstfit.md)
for the density, QQ, PP and tail plots;
[`mksyncol()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncol.md)
with `type = "fitted"` for a synthetic sample from a fit.

## Examples

``` r
set.seed(1)
x <- stats::rgamma(300, shape = 2, rate = 0.5)
f <- dstfit(x, nboot = 20)
f
#> ╭── Distribution fit ─────────────────────────────────────────────────────╮
#> │   Values           300                                                  │
#> │   Data             continuous                                           │
#> │   Families tried   7                                                    │
#> │   Best by AIC      weibull                                              │
#> │   Confidence       95%                                                  │
#> │   Hill tail index  5.66 [2.97, 8.35], from the 17 largest values        │
#> │                                                                         │
#> │   Families ranked by AIC                                                │
#> │   rank  family       npar  loglik    aic    bic       ks      ad        │
#> │   ----  -----------  ----  ------  -----  -----  -------  ------        │
#> │      1  weibull         2  -673.5  1,351  1,359  0.02543   0.197        │
#> │      2  gamma           2  -674.3  1,353  1,360  0.03906   0.509        │
#> │      3  lognormal       2  -691.7  1,387  1,395  0.07364   3.461        │
#> │      4  exponential     1  -709.4  1,421  1,424  0.14763  13.056        │
#> │      5  t               3  -711.2  1,428  1,440  0.08261   3.483        │
#> │      6  normal          2  -717.2  1,438  1,446  0.09560   4.659        │
#> │      7  pareto          2  -945.7  1,895  1,903  0.36066  73.195        │
#> │                                                                         │
#> │   Parameters                                                            │
#> │   family       params                                                   │
#> │   -----------  ----------------------------------------                 │
#> │   weibull      shape = 1.523, scale = 4.349                             │
#> │   gamma        shape = 2.0060, rate = 0.5125                            │
#> │   lognormal    meanlog = 1.095, sdlog = 0.812                           │
#> │   exponential  rate = 0.2555                                            │
#> │   t            location = 3.686, scale = 2.283, df =...                 │
#> │   normal       mean = 3.914, sd = 2.642                                 │
#> │   pareto       xmin = 0.1680, alpha = 0.3474                            │
#> │                                                                         │
#> │   weibull fits best (AIC 1351); gamma, next, is 1.56 AIC worse: the     │
#> │   data do not choose between the two.                                   │
#> │                                                                         │
#> │   The lower the AIC, the better the family fits for its number of       │
#> │   parameters; ks and ad are the Kolmogorov-Smirnov and Anderson-Darling │
#> │   distances, smaller is closer. A best fit is only the best of those    │
#> │   tried.                                                                │
#> ╰─────────────────────────────────────────────────────────────────────────╯
f$fits$gamma
#>     shape      rate 
#> 2.0061187 0.5125441 

# counts with extra zeros
n <- ifelse(stats::runif(300) < 0.3, 0, stats::rpois(300, 4))
dstfit(n, nboot = 0)$table[, c("family", "aic")]
#>    family      aic
#> 1     zip 1183.895
#> 2    zinb 1185.895
#> 3  negbin 1280.316
#> 4  normal 1382.649
#> 5       t 1384.649
#> 6 poisson 1448.838

# a family the data do not allow
try(dstfit(c(-1, 2, 3, 4, 5), fams = "gamma"))
#> Error : dstfit: `gamma` needs every value above 0
```
