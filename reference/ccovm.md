# Covariance matrix of a numeric matrix (C backend)

The covariance of every pair of columns of a numeric matrix or data
frame, computed by the compiled core. Covariances describe how variables
move together; the matrix is the input to principal components,
Mahalanobis distances and multivariate drift checks. Column names are
carried through to both dimensions of the result.

## Usage

``` r
ccovm(x)
```

## Arguments

- x:

  A numeric matrix, or a data frame whose columns are all numeric (rows
  = observations, columns = variables).

## Value

A symmetric `ncol(x)` by `ncol(x)` numeric matrix, with the column names
of `x` (if any) as both row and column names; entry units are the
product of the two columns' units.

## Details

Entry \\(j, k)\\ is \\\frac{1}{n - 1} \sum_i (x\_{ij} - \bar
x_j)(x\_{ik} - \bar x_k)\\, the `n - 1` denominator of
[`stats::cov()`](https://rdrr.io/r/stats/cor.html), with which it agrees
to rounding. The diagonal holds the column variances.

Missing values are not removed: an `NA` in a column makes every
covariance involving that column `NA` (pairwise or complete-case
deletion is not done; use
[`stats::cov()`](https://rdrr.io/r/stats/cor.html) with `use =` for
those). A single row gives `NaN` throughout. Refusals: a vector that is
not a matrix (`"must be a matrix or data frame"`) and a data frame with
a non-numeric column (`"every column of x must be numeric"`). Logical
and integer matrices are converted to double. The cost is \\O(n p^2)\\
for \\n\\ rows and \\p\\ columns.

## See also

[`ccorr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cstat.md)
for a single Pearson correlation,
[`cmom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cmom.md)
for one column's variance.

## Examples

``` r
X <- cbind(a = c(1, 2, 3, 4), b = c(2, 4, 7, 8), c = c(5, 3, 2, 1))
ccovm(X)
#>           a         b         c
#> a  1.666667  3.500000 -2.166667
#> b  3.500000  7.583333 -4.583333
#> c -2.166667 -4.583333  2.916667

# Agrees with stats::cov().
all.equal(ccovm(X), stats::cov(X))
#> [1] TRUE

# The diagonal is the column variances.
all.equal(diag(ccovm(X)), apply(X, 2, stats::var))
#> [1] TRUE

# Data frames are accepted.
ccovm(data.frame(u = 1:5, v = c(2, 1, 4, 3, 6)))
#>     u   v
#> u 2.5 2.5
#> v 2.5 3.7

# A plain vector is not a matrix of variables.
try(ccovm(1:5))
#> Error : `x` must be a matrix or data frame
```
