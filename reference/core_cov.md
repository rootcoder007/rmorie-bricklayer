# Covariance matrix of a numeric matrix (C backend)

Column covariances with the `n - 1` denominator, matching
[`stats::cov()`](https://rdrr.io/r/stats/cor.html). Column names are
carried through to both dimensions of the result.

## Usage

``` r
core_cov(x)
```

## Arguments

- x:

  A numeric matrix or data frame of numeric columns (rows =
  observations, columns = variables).

## Value

A symmetric `ncol(x)` by `ncol(x)` numeric matrix.

## Examples

``` r
X <- cbind(a = c(1, 2, 3, 4), b = c(2, 4, 7, 8), c = c(5, 3, 2, 1))
core_cov(X)
#>           a         b         c
#> a  1.666667  3.500000 -2.166667
#> b  3.500000  7.583333 -4.583333
#> c -2.166667 -4.583333  2.916667

# Agrees with stats::cov().
all.equal(core_cov(X), stats::cov(X))
#> [1] TRUE

# The diagonal is the column variances.
all.equal(diag(core_cov(X)), apply(X, 2, stats::var))
#> [1] TRUE

# Data frames are accepted.
core_cov(data.frame(u = 1:5, v = c(2, 1, 4, 3, 6)))
#>     u   v
#> u 2.5 2.5
#> v 2.5 3.7
```
