# Mean, variance, skewness and kurtosis in one pass (C backend)

A single streaming pass (Welford's recurrence, extended to the third and
fourth central moments) over `x`. One pass matters for capsule members
large enough that reading the column twice is the expensive part.

## Usage

``` r
core_moments(x)
```

## Arguments

- x:

  Numeric vector (coerced with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html)).

## Value

A named length-4 numeric: `mean`, `variance`, `skewness`, `kurtosis`.
`skewness` needs at least 3 observations and `kurtosis` at least 4; both
are `NaN` below that, as is everything if `x` contains NA/NaN.

## Details

The variance uses the `n - 1` denominator, matching
[`stats::var()`](https://rdrr.io/r/stats/cor.html). The shape statistics
use the *sample moment* definitions \\m_3 / m_2^{3/2}\\ and \\m_4 /
m_2^2 - 3\\, with \\m_k\\ the k-th central moment divided by `n` – so
kurtosis is reported as EXCESS kurtosis and a normal sample sits near
zero, not near three.

## References

Welford BP (1962). Note on a method for calculating corrected sums of
squares and products. *Technometrics* 4(3), 419–420.
[doi:10.1080/00401706.1962.10490022](https://doi.org/10.1080/00401706.1962.10490022)

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
