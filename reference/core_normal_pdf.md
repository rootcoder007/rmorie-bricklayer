# Normal density (C backend)

Vectorised over `x`; `mean` and `sd` are length-1.

## Usage

``` r
core_normal_pdf(x, mean = 0, sd = 1)
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
`stats::dnorm(x, mean, sd)`.

## Examples

``` r
# Standard normal density at a few quantiles.
core_normal_pdf(c(-1, 0, 1))
#> [1] 0.2419707 0.3989423 0.2419707

# Peak of the standard normal is 1/sqrt(2*pi) at x = 0.
core_normal_pdf(0)
#> [1] 0.3989423

# Shift and scale via `mean` and `sd`.
core_normal_pdf(5, mean = 5, sd = 2)       # peak of N(5, 2)
#> [1] 0.1994711
core_normal_pdf(c(0, 5, 10), mean = 5, sd = 2)
#> [1] 0.00876415 0.19947114 0.00876415

# Identical to stats::dnorm().
all.equal(core_normal_pdf(-2:2, 0, 1), stats::dnorm(-2:2, 0, 1))
#> [1] TRUE
```
