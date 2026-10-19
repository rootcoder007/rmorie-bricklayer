# Standard deviation and Euclidean distance (C backend)

`csdev()` returns the standard deviation of a numeric vector and
`cdistm()` the straight-line (Euclidean) distance between two vectors of
the same length. Both run in the package's compiled core, the same code
that rmorie and rmoriedata reach through `LinkingTo: rmoriebricklayer`,
so a figure computed here is the figure those packages compute. Use them
when you want the shared core's answer rather than base R's, for example
when checking a capsule's recorded summary statistics against a fresh
computation.

## Usage

``` r
csdev(x, ddof = 1L)

cdistm(a, b)
```

## Arguments

- x, a, b:

  Numeric (or logical) vectors; coerced with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html). `a` and `b`
  must have the same length.

- ddof:

  Delta degrees of freedom, a single number truncated to an integer by
  [`as.integer()`](https://rdrr.io/r/base/integer.html): the divisor is
  `n - ddof`. The default `1` gives the sample standard deviation,
  matching [`stats::sd()`](https://rdrr.io/r/stats/sd.html); `0` gives
  the population figure.

## Value

`csdev()`: a length-1 numeric, the standard deviation in the units of
`x` (`NA` when `x` holds a missing value, `NaN` when
`length(x) <= ddof`). `cdistm()`: a length-1 non-negative numeric, the
distance in the units of `a` and `b`.

## Details

`csdev()` computes \$\$s = \sqrt{\frac{1}{n - \mathrm{ddof}}
\sum\_{i=1}^n (x_i - \bar x)^2},\$\$ so `ddof = 1` is the sample
standard deviation of [`stats::sd()`](https://rdrr.io/r/stats/sd.html)
and `ddof = 0` the population figure. `cdistm()` computes \\\sqrt{\sum_i
(a_i - b_i)^2}\\.

Missing values propagate: there is no `na.rm`, and one `NA` makes the
result `NA`. Remove them first (for example with
[`stats::na.omit()`](https://rdrr.io/r/stats/na.fail.html)) when that is
what you want. A vector with no more than `ddof` values has no defined
spread and gives `NaN` (one value with the default `ddof = 1`, or an
empty vector). Two empty vectors are at distance 0.

Refusals: a character, factor, list or data-frame `x`, `a` or `b`
(`"must be numeric"`), and for `cdistm()` vectors of different lengths
(`"must have the same length"`). Logical input is accepted and counted
as 0/1. Both run in one pass over the data and allocate nothing beyond
the coerced input.

## See also

[`cmom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cmom.md)
for the mean, variance, skewness and kurtosis in a single pass;
[`cmad()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crob.md)
for a spread that one wild value cannot move.

## Examples

``` r
# Sample standard deviation, matching stats::sd().
csdev(c(2, 4, 4, 4, 5, 5, 7, 9))
#> [1] 2.13809
all.equal(csdev(1:10), stats::sd(1:10))
#> [1] TRUE

# ddof = 0 divides by n instead of n - 1.
csdev(1:10, ddof = 0)
#> [1] 2.872281
all.equal(csdev(1:10, ddof = 0), sqrt(mean((1:10 - mean(1:10))^2)))
#> [1] TRUE

# Missing values propagate; remove them first if they should be ignored.
csdev(c(3, NA, 5))
#> [1] NA
csdev(stats::na.omit(c(3, NA, 5)))
#> [1] 1.414214

# Euclidean distance between two points.
cdistm(c(0, 0), c(3, 4))     # 5
#> [1] 5
cdistm(1:5, 1:5)             # 0 -- a point is zero from itself
#> [1] 0

# Vectors of different lengths are refused rather than recycled.
try(cdistm(1:3, 1:2))
#> Error : `a` and `b` must have the same length
```
