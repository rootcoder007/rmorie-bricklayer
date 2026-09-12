# Inline histogram for a numeric vector

A one-line sketch of a column's distribution, as block characters (or
ASCII where the console cannot render them). The point is density of
information: a mean and a standard deviation cannot tell you a column is
bimodal, and this can, in the width of a table cell.

## Usage

``` r
inline_hist(x, bins = 10L)
```

## Arguments

- x:

  Numeric vector.

- bins:

  Number of bins (default 10).

## Value

A length-1 character vector of `bins` characters.

## See also

[`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md),
which includes one per numeric column.

## Examples

``` r
set.seed(1)
# A symmetric distribution peaks in the middle.
inline_hist(stats::rnorm(1000))
#> [1] "▁▂▄██▇▄▂▁▁"

# A skewed one leans left.
inline_hist(stats::rexp(1000))
#> [1] "█▄▂▁▁▁▁▁▁▁"

# Bimodality is visible here and in no single summary number.
inline_hist(c(stats::rnorm(500, -3), stats::rnorm(500, 3)))
#> [1] "▁▅█▄▁▁▃█▆▁"

# A constant column has no spread to show.
inline_hist(rep(5, 10))
#> [1] "     █    "
```
