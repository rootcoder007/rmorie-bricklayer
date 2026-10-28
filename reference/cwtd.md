# Weighted mean and variance (C backend)

The weighted mean and weighted variance of a numeric vector, for data
where some observations count for more than others: an average over
areas weighted by population, or measurements weighted by how precise
each one is. Both come from the compiled core in one pass.

## Usage

``` r
cwtd(x, w)
```

## Arguments

- x:

  Numeric vector of observations.

- w:

  Numeric vector of non-negative weights, the same length as `x`. Only
  their relative sizes matter for the mean; the variance's correction
  uses them as given.

## Value

A named length-2 numeric vector: `mean` (units of `x`) and `variance`
(squared units of `x`).

## Details

The mean is \\\bar x_w = \sum_i w_i x_i / \sum_i w_i\\. The weights are
treated as RELIABILITY weights (how precisely each observation is
known), so the variance is \$\$s_w^2 = \frac{\sum_i w_i (x_i - \bar
x_w)^2} {\sum_i w_i - \sum_i w_i^2 / \sum_i w_i},\$\$ the unbiased
estimator under that reading. With every weight equal to 1 it reduces
exactly to [`stats::var()`](https://rdrr.io/r/stats/cor.html). Frequency
weights (a weight of 3 meaning three identical rows) call for the
denominator \\\sum w - 1\\ instead, and survey design weights call for a
design-based variance, so do not use this variance for those.

Refusals: `x` and `w` of different lengths
(`"must have the same length"`), any negative weight
(`"must be non-negative"`), and a character, factor or list argument
(`"must be numeric"`). All-zero weights, or an `NA` in either vector,
give `NaN` for both entries.

## See also

[`cmom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cmom.md)
for the unweighted moments,
[`cipw()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cipw.md)
for inverse-probability weights to feed in here.

## Examples

``` r
x <- c(10, 20, 30, 40)
w <- c(1, 1, 2, 4)
cwtd(x, w)
#>     mean variance 
#>  31.2500 169.0476 

# The mean agrees with base R.
all.equal(cwtd(x, w)[["mean"]], stats::weighted.mean(x, w))
#> [1] TRUE

# Equal weights recover the unweighted variance.
all.equal(cwtd(x, rep(1, 4))[["variance"]], stats::var(x))
#> [1] TRUE

# A single dominant weight pulls the mean onto that observation.
cwtd(x, c(1, 1, 1, 1000))[["mean"]]
#> [1] 39.94018

# A negative weight is refused.
try(cwtd(x, c(1, -1, 1, 1)))
#> Error : `w` must be non-negative and finite, not all zero
```
