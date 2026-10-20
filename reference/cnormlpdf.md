# Normal log-density (C backend)

The logarithm of the normal (Gaussian) density at each value of `x`,
computed directly from the formula rather than as `log(dnorm(x))`. Use
it for log-likelihoods: summing log-densities is how a normal model is
scored, and computing them directly keeps the sum finite far into the
tails, where the density itself underflows to zero and its logarithm
would be `-Inf`.

## Usage

``` r
cnormlpdf(x, mean = 0, sd = 1)
```

## Arguments

- x:

  Numeric vector of quantiles (the observed values).

- mean:

  The distribution's mean, a single number in the units of `x` (default
  0).

- sd:

  The distribution's standard deviation, a single positive number in the
  units of `x` (default 1).

## Value

A numeric vector the length of `x`: the natural-log density at each
value (in log units per unit of `x`). Equivalent to
`stats::dnorm(x, mean, sd, log = TRUE)`.

## Details

Each value is \$\$\log \phi(x; \mu, \sigma) = -\log \sigma - \tfrac12
\log(2\pi) - \frac{(x - \mu)^2}{2\sigma^2},\$\$ evaluated by the shared
core, and agrees with `stats::dnorm(x, mean, sd, log = TRUE)` to
rounding.

`mean` and `sd` are single numbers: a vector of either is refused, so
this is not vectorised over the parameters the way
[`stats::dnorm()`](https://rdrr.io/r/stats/Normal.html) is. A non-finite
`mean`, and an `sd` that is not a positive finite number, are errors, as
in
[`cnormpdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnormpdf.md);
a missing `x` gives `NA`. A character, factor or list `x` is refused
(`"must be numeric"`).

## See also

[`cmom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cmom.md)
for estimating `mean` and `sd` from data.

## Examples

``` r
cnormlpdf(c(-1, 0, 1))
#> [1] -1.4189385 -0.9189385 -1.4189385

# Identical to stats::dnorm(log = TRUE).
all.equal(cnormlpdf(-2:2, 0.3, 1.7),
          stats::dnorm(-2:2, 0.3, 1.7, log = TRUE))
#> [1] TRUE

# Still finite where the density itself underflows to zero.
stats::dnorm(50)                  # 0
#> [1] 0
cnormlpdf(50)            # about -1251
#> [1] -1250.919

# A log-likelihood: the sum of the log-densities of a sample.
y <- c(4.8, 5.1, 5.6, 4.9, 5.3)
sum(cnormlpdf(y, mean = mean(y), sd = stats::sd(y)))
#> [1] -0.9121269

# A standard deviation of zero has no density, and the parameters are
# single numbers.
try(cnormlpdf(1, sd = 0))
#> Error : cnormlpdf: `sd` must be a single positive number
try(cnormlpdf(1, mean = c(0, 1)))
#> Error : cnormlpdf: `mean` must be a single finite number
try(cnormlpdf("1"))
#> Error : cnormlpdf: `x` must be numeric, got character
```
