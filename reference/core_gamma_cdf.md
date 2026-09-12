# Regularized incomplete gamma function (C backend)

The lower regularized incomplete gamma function \\P(a, x)\\, which is
the CDF of a Gamma distribution with shape `a` and unit rate. Exposed
because it is the building block of the chi-square tail used by
[`drift_chisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_chisq.md)
and
[`benford_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/benford_test.md).

## Usage

``` r
core_gamma_cdf(shape, x)
```

## Arguments

- shape:

  Shape parameter \\a\\ (length-1, \> 0).

- x:

  Numeric vector of quantiles (\>= 0).

## Value

A numeric vector the length of `x`, each entry in \\ \[0, 1\].

\[0, 1\]: R:0,%201%5C

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
```
