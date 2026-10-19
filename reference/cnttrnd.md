# Trend in a count series, as a rate ratio per period

Estimates the trend in a series of counts (arrests, admissions,
incidents per year) as a rate ratio per period: 0.85 means the count
falls by 15% a year. It fits a Poisson log-linear model and, when the
counts vary more than a Poisson model allows, widens the interval. An
offset carries the denominator when the exposure varies, so the trend is
then in the rate rather than in the count.

## Usage

``` r
cnttrnd(y, x = NULL, offset = NULL, conflvl = 0.95)
```

## Arguments

- y:

  Numeric vector of counts (non-negative whole numbers), in period
  order.

- x:

  Numeric vector of periods, default `NULL` (the position). The rate
  ratio is per unit of `x`.

- offset:

  Optional numeric vector of exposures, one per period – a population, a
  number of admissions, a number of days. Positive. The trend is then in
  the rate rather than in the count.

- conflvl:

  Number in (0, 1), default 0.95: the confidence level of the rate-ratio
  interval.

## Value

A list of class `c("rmbl_count_trend", "list")` with `rateratio` (per
period), `lower`, `upper`, `p_value` (test of no trend), `logslope`
(\\\beta_1\\), `se` (its standard error, scaled when overdispersed),
`fitted` (fitted counts), `dispersion`, `overdispersed` (logical), `n`,
`data` (list of the `x` and `y` used) and `method`.

## Details

The model is \\\log \mu_t = \beta_0 + \beta_1 (x_t - \bar x) + \log
o_t\\, with \\o_t\\ the offset (1 when none), fitted by iteratively
reweighted least squares (at most 50 iterations). The rate ratio is
\\e^{\beta_1}\\, with a Wald interval \\e^{\beta_1 \pm z\\
\mathrm{se}}\\.

The dispersion is reported because a Poisson fit assumes it is one. It
is the Pearson statistic \\\sum (y - \mu)^2/\mu\\ divided by \\n - 2\\.
When it exceeds 1.5 the quasi-Poisson interval is returned instead: the
standard error is multiplied by the square root of the dispersion and
the \\t\\ distribution on \\n - 2\\ degrees of freedom replaces the
normal, and `overdispersed` is set.

Missing values are dropped. Errors: negative or fractional counts; `x`
and `y` of different lengths; infinite `x`; every count zero; an offset
of the wrong length or not positive; fewer than three periods; a
`conflvl` outside (0, 1). When the counts are zero at one end of the
series only (`c(0, 0, 5)`) the likelihood rises without bound and there
is no finite trend: a warning says so, the rate ratio is `Inf` (or 0)
and the interval and p-value are `NA`. There is a
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) method for the
result.

## References

Bilder, C. R. and Loughin, T. M. *Analysis of Categorical Data with R*,
2nd edn. Chapman and Hall/CRC, on the quasi-likelihood treatment of an
overdispersed Poisson fit: the variance is scaled by an estimated
dispersion, which widens the interval while leaving the point estimate
alone. That is the behaviour reported here through `dispersion` and
`overdispersed`.

## See also

[`trndtst`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trndtst.md),
[`ratechg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ratechg.md).

## Examples

``` r
# A count falling by about 15% a year.
set.seed(3)
y <- stats::rpois(8, lambda = 200 * 0.85^(0:7))
fit <- cnttrnd(y)
round(fit$rateratio, 3)
#> [1] 0.869
c(fit$lower, fit$upper)
#> [1] 0.8444785 0.8942357

# With a varying denominator the trend is in the rate.
cnttrnd(c(20, 25, 30), offset = c(1000, 1500, 2500))$rateratio
#> [1] 0.7708656

# Counts that swing far more than Poisson noise get the wider interval.
wild <- cnttrnd(c(10, 50, 5, 60, 8, 70))
wild$dispersion
#> [1] 26.27417
wild$method
#> [1] "quasi-Poisson (dispersion above 1.5)"

try(cnttrnd(c(1.5, 2, 3)))
#> Error : `y` must be non-negative whole numbers
```
