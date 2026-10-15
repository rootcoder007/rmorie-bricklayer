# Regularized incomplete gamma function (C backend)

The lower regularized incomplete gamma function \\P(a, x)\\, which is
the CDF of a Gamma distribution with shape `a` and unit rate. Exposed
because it is the building block of the chi-square tail used by
[`drift_chisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_chisq.md)
and
[`benford_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/benford_test.md):
the p-value of a chi-square statistic \\q\\ on \\k\\ degrees of freedom
is \\1 - P(k/2, q/2)\\.

## Usage

``` r
core_gamma_cdf(shape, x)
```

## Arguments

- shape:

  Shape parameter \\a\\, a single positive number.

- x:

  Numeric vector of quantiles.

## Value

A numeric vector the length of `x`, each entry a probability in \\\[0,
1\]\\.

## Details

\$\$P(a, x) = \frac{1}{\Gamma(a)} \int_0^x t^{a-1} e^{-t} \\ dt,\$\$
evaluated by the shared core (a series for small \\x\\, a continued
fraction otherwise, the standard pairing), and agreeing with
`stats::pgamma(x, shape)` to rounding. For a gamma distribution with
rate \\r\\, pass `x * r`.

`shape` must be a single positive number
(`"shape must be a single positive number"`). A negative `x` gives 0, a
missing `x` gives `NA`, and `Inf` gives 1, as in
[`stats::pgamma()`](https://rdrr.io/r/stats/GammaDist.html).

## See also

[`stats::pgamma()`](https://rdrr.io/r/stats/GammaDist.html), the base R
equivalent.

## Examples

``` r
core_gamma_cdf(3.5, c(0.5, 1, 4, 12))
#> [1] 0.005171463 0.040159631 0.667406097 0.998860649

# Identical to the unit-rate gamma CDF.
all.equal(core_gamma_cdf(3.5, c(0.5, 1, 4, 12)),
          stats::pgamma(c(0.5, 1, 4, 12), shape = 3.5))
#> [1] TRUE

# Shape 1 is the exponential distribution.
all.equal(core_gamma_cdf(1, c(0.5, 2)), stats::pexp(c(0.5, 2)))
#> [1] TRUE

# A chi-square tail on k degrees of freedom is 1 - P(k/2, q/2).
1 - core_gamma_cdf(2 / 2, 5.99 / 2)      # about 0.05 on 2 df
#> [1] 0.05003663

# The shape must be positive.
try(core_gamma_cdf(0, 1))
#> Error : `shape` must be a single positive number
```
