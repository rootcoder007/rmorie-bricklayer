# Standard deviation and Euclidean distance (C backend)

`core_sd()` is the square root of the variance computed by the shared
core; `core_dist()` is the Euclidean distance between two equal-length
vectors.

## Usage

``` r
core_sd(x, ddof = 1L)

core_dist(a, b)
```

## Arguments

- x, a, b:

  Numeric vectors (coerced with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html)).

- ddof:

  Denominator degrees of freedom. The default `1` gives the sample
  standard deviation, matching
  [`stats::sd()`](https://rdrr.io/r/stats/sd.html); `0` gives the
  population figure.

## Value

A length-1 numeric.

## Details

NA/NaN propagate – there is no `na.rm`. Call
[`stats::na.omit()`](https://rdrr.io/r/stats/na.fail.html) first if you
need NA handling.

## See also

[`core_moments()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_moments.md)
for the mean, variance, skewness and kurtosis in a single pass.

## Examples

``` r
# Sample standard deviation, matching stats::sd().
core_sd(c(2, 4, 4, 4, 5, 5, 7, 9))
#> [1] 2.13809
all.equal(core_sd(1:10), stats::sd(1:10))
#> [1] TRUE

# ddof = 0 divides by n instead of n - 1.
core_sd(1:10, ddof = 0)
#> [1] 2.872281
all.equal(core_sd(1:10, ddof = 0), sqrt(mean((1:10 - mean(1:10))^2)))
#> [1] TRUE

# Euclidean distance between two points.
core_dist(c(0, 0), c(3, 4))     # 5
#> [1] 5
core_dist(1:5, 1:5)             # 0 -- a point is zero from itself
#> [1] 0
```
