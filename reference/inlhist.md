# Inline histogram for a numeric vector

Draws a one-line sketch of a column's distribution, as block characters
(or ASCII where the console cannot render them). The point is density of
information: a mean and a standard deviation cannot tell you a column is
bimodal, skewed or has a gap, and this can, in the width of a table
cell.
[`profcols()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profcols.md)
shows one for every numeric column.

## Usage

``` r
inlhist(x, bins = 10L)
```

## Arguments

- x:

  Numeric vector.

- bins:

  Number of bins, and so of characters, one positive whole number
  (default 10).

## Value

A length-1 character vector of `bins` characters.

## Details

Non-finite values (`NA`, `NaN`, `Inf`) are dropped. The range of the
rest is cut into `bins` equal-width bins (as
[`graphics::hist()`](https://rdrr.io/r/graphics/hist.html) with those
breaks) and each bin's count is drawn as one of eight Unicode block
heights, scaled to the largest bin; an empty bin is a space, and a bin
with any values is at least the lowest block. When the session is not
UTF-8, or the environment variable `RMBL_ASCII_ONLY` is set, five ASCII
levels (`. : - = #`) are used instead. A column with no spread gives one
full block in the middle; no finite values give spaces.

Errors: `x` that is not numeric; `bins` that is not one positive whole
number.

## See also

[`profcols()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profcols.md),
which includes one per numeric column.

## Examples

``` r
set.seed(1)
# A symmetric distribution peaks in the middle.
inlhist(stats::rnorm(1000))
#> [1] "▁▂▄██▇▄▂▁▁"

# A skewed one leans left.
inlhist(stats::rexp(1000))
#> [1] "█▄▂▁▁▁▁▁▁▁"

# Bimodality is visible here and in no single summary number.
inlhist(c(stats::rnorm(500, -3), stats::rnorm(500, 3)))
#> [1] "▁▅█▄▁▁▃█▆▁"

# A constant column has no spread to show.
inlhist(rep(5, 10))
#> [1] "     █    "

# more bins for more detail
inlhist(stats::rexp(1000), bins = 30)
#> [1] "█▇▅▄▃▃▂▂▁▁▁▁▁▁▁▁▁▁▁▁▁ ▁ ▁  ▁ ▁"

# text is not a distribution
try(inlhist(c("a", "b")))
#> Error : `x` must be numeric, got character
```
