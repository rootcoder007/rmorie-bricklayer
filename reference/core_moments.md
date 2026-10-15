# Mean, variance, skewness and kurtosis (C backend)

The four standard descriptive moments of a numeric vector – where it is
centred, how spread out it is, whether it leans to one side and how
heavy its tails are – in one call to the compiled core. These are the
four numbers a data description or a drift check usually reports
together.

## Usage

``` r
core_moments(x)
```

## Arguments

- x:

  Numeric (or logical) vector; coerced with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html).

## Value

A named length-4 numeric vector: `mean` (units of `x`), `variance`
(squared units of `x`, `n - 1` denominator), `skewness` and `kurtosis`
(both unitless; kurtosis as excess over the normal's 3).

## Details

The mean is base R's (an extended-precision sum followed by a corrective
pass); the deviations from it are then divided by their largest
magnitude before any power is taken, and the scale is restored at the
end. That avoids both the cancellation of the textbook "sum of squares
minus square of sum" formula and overflow of fourth powers for values
beyond about \\10^{77}\\. It reads the data three times (mean, largest
deviation, moments), in \\O(n)\\ time. The variance uses the `n - 1`
denominator, matching
[`stats::var()`](https://rdrr.io/r/stats/cor.html). The shape statistics
use the *sample moment* definitions \$\$g_1 = m_3 / m_2^{3/2}, \qquad
g_2 = m_4 / m_2^2 - 3,\$\$ with \\m_k = n^{-1} \sum_i (x_i - \bar
x)^k\\, so kurtosis is reported as EXCESS kurtosis: a normal sample sits
near zero, not near three. These are the uncorrected moment ratios (type
1 in the classification of Joanes and Gill, 1998), not the bias-adjusted
versions some software reports.

Edge cases are `NaN`, never an error: an empty vector gives four `NaN`;
one value gives its mean and `NaN` for the rest; `skewness` needs at
least 3 values and `kurtosis` at least 4; any `NA` or `NaN` in `x` makes
every entry `NaN`. A constant vector has variance 0 and `NaN` shape
statistics. A character, factor or list `x` is refused
(`"must be numeric"`).

## References

Joanes DN, Gill CA (1998). Comparing measures of sample skewness and
kurtosis. *Journal of the Royal Statistical Society: Series D (The
Statistician)* 47(1), 183–189.
[doi:10.1111/1467-9884.00122](https://doi.org/10.1111/1467-9884.00122)

## See also

[`core_sd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_spread.md),
[`core_quantile()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_robust.md)
and
[`core_mad()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_robust.md)
for robust alternatives that one extreme value cannot move.

## Examples

``` r
core_moments(c(2, 4, 4, 4, 5, 5, 7, 9))
#>      mean  variance  skewness  kurtosis 
#>  5.000000  4.571429  0.656250 -0.218750 

# The first two entries agree with base R.
m <- core_moments(1:10)
all.equal(m[["mean"]], mean(1:10))
#> [1] TRUE
all.equal(m[["variance"]], stats::var(1:10))
#> [1] TRUE

# A symmetric sample has no skew; excess kurtosis is near 0 for normal
# data and positive for a heavy-tailed sample.
core_moments(c(-2, -1, 0, 1, 2))[["skewness"]]
#> [1] 0
core_moments(c(rep(0, 20), -8, 8))[["kurtosis"]] > 0
#> [1] TRUE

# Too short to define a shape statistic: NaN rather than a guess.
core_moments(c(1, 2))
#>     mean variance skewness kurtosis 
#>      1.5      0.5      NaN      NaN 
```
