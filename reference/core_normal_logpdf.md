# Normal log-density (C backend)

The logarithm of the normal density, computed directly rather than as
`log(dnorm(x))`, so it stays finite far into the tails where the density
itself underflows to zero.

## Usage

``` r
core_normal_logpdf(x, mean = 0, sd = 1)
```

## Arguments

- x:

  Numeric vector of quantiles.

- mean:

  Distribution mean (length-1, default 0).

- sd:

  Distribution standard deviation (length-1, default 1, \> 0).

## Value

A numeric vector the length of `x`. Equivalent to
`stats::dnorm(x, mean, sd, log = TRUE)`.

## Examples

``` r
core_normal_logpdf(c(-1, 0, 1))
#> [1] -1.4189385 -0.9189385 -1.4189385

# Identical to stats::dnorm(log = TRUE).
all.equal(core_normal_logpdf(-2:2, 0.3, 1.7),
          stats::dnorm(-2:2, 0.3, 1.7, log = TRUE))
#> [1] TRUE

# Still finite where the density itself underflows to zero.
stats::dnorm(50)                  # 0
#> [1] 0
core_normal_logpdf(50)            # about -1251
#> [1] -1250.919
```
