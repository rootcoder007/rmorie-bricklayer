# Weighted mean and variance (C backend)

The weights are treated as RELIABILITY weights (how precisely each
observation is known), so the variance carries the bias correction
\\\sum w - \sum w^2 / \sum w\\ in the denominator rather than `n - 1`.
With every weight equal to 1 it reduces exactly to
[`stats::var()`](https://rdrr.io/r/stats/cor.html).

## Usage

``` r
core_weighted(x, w)
```

## Arguments

- x:

  Numeric vector of observations.

- w:

  Numeric vector of non-negative weights, the same length as `x`.

## Value

A named length-2 numeric: `mean` and `variance`.

## Examples

``` r
x <- c(10, 20, 30, 40)
w <- c(1, 1, 2, 4)
core_weighted(x, w)
#>     mean variance 
#>  31.2500 169.0476 

# The mean agrees with base R.
all.equal(core_weighted(x, w)[["mean"]], stats::weighted.mean(x, w))
#> [1] TRUE

# Equal weights recover the unweighted variance.
all.equal(core_weighted(x, rep(1, 4))[["variance"]], stats::var(x))
#> [1] TRUE

# A single dominant weight pulls the mean onto that observation.
core_weighted(x, c(1, 1, 1, 1000))[["mean"]]
#> [1] 39.94018
```
