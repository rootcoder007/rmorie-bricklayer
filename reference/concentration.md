# Concentration of a total across units

Measures how unevenly a total is spread across units: whether a few
people account for most of the placements, or a few regions for most of
the days. `gini()` gives the Gini coefficient, `lorenz()` the points of
the Lorenz curve (for plotting, for example with
[`plot_lorenz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot_lorenz.md)),
and `top_share()` the share of the total held by the largest units ("the
top 1% of people account for 20% of the days"). The three are computed
in compiled code from the same sorted values.

## Usage

``` r
gini(x, na.rm = TRUE)

lorenz(x, na.rm = TRUE)

top_share(x, fractions = c(0.01, 0.05, 0.1, 0.25), na.rm = TRUE)
```

## Arguments

- x:

  Numeric vector of non-negative values, one per unit (for example the
  days or the count of placements of each person). `NA` values are
  dropped; `Inf`, negative values and non-numeric input are errors.

- na.rm:

  Logical. Missing values are dropped whatever its value; the argument
  exists so the call reads the same as base R's. Default `TRUE`.

- fractions:

  Numeric vector of fractions of the units, each in `[0, 1]`: for each
  one the share of the total held by that fraction of units, taking the
  largest units first. Default `c(0.01, 0.05, 0.1, 0.25)`.

## Value

`gini()`: a numeric scalar in `[0, 1 - 1/n]`. `lorenz()`: a data frame
with numeric columns `population` (cumulative share of units, from 0
to 1) and `value` (cumulative share of the total, units in ascending
order), `n + 1` rows including the origin. `top_share()`: a data frame
with columns `fraction` (the requested fraction of units), `units` (how
many of the largest units that fraction is) and `share` (the share of
the total those units hold).

## Details

Gini is the mean absolute difference between pairs of units over twice
the mean, \\G = \sum_i \sum_j \|x_i - x_j\| / (2 n^2 \bar{x})\\, which
is also twice the area between the Lorenz curve and the diagonal. Zero
is a perfectly even spread; the maximum for `n` units is `1 - 1/n`, not
1, so a Gini near 1 requires many units as well as an uneven spread.

A Gini computed from banded or rounded data inherits that coarsening:
compare with
[`band_sensitivity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md)
when the values are bands. For a tail that a few units dominate,
[`hill_tail_index()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hill_tail_index.md)
says whether the largest values follow a power law.

Errors: `x` not numeric, with `Inf` or a negative value, or with no
non-missing value; `gini()` when every value is zero (the Gini of a zero
total is undefined); `top_share()` when `fractions` is not numeric, is
empty, has `NA` or lies outside `[0, 1]`.

## References

Hedderich, J. and Sachs, L. (2020). *Applied Statistics: Methods Using
R*. Springer-Verlag, Berlin Heidelberg. Section 3.14, p. 117, gives the
construction used here: the units are placed at equal intervals on the
horizontal axis and the cumulated, ascendingly ordered shares of the
total on the vertical one, so that the curve is the diagonal exactly
when p percent of the units account for p percent of the total, and sags
further the greater the concentration.

## See also

[`hill_tail_index()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hill_tail_index.md),
[`band_sensitivity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md)

## Examples

``` r
# Ten units holding one each: no concentration.
gini(rep(1, 10))
#> [1] 0

# One unit holding everything: the maximum for ten units.
gini(c(rep(0, 9), 1))
#> [1] 0.9
1 - 1 / 10
#> [1] 0.9

placements <- c(rep(1, 1200), rep(3, 430), rep(8, 110), rep(20, 38))
gini(placements)
#> [1] 0.461225

# What the most frequent few account for.
top_share(placements, c(0.01, 0.05, 0.1))
#>   fraction units      share
#> 1     0.01    18 0.08716707
#> 2     0.05    89 0.28280872
#> 3     0.10   178 0.41888620

head(lorenz(placements))
#>     population        value
#> 1 0.0000000000 0.0000000000
#> 2 0.0005624297 0.0002421308
#> 3 0.0011248594 0.0004842615
#> 4 0.0016872891 0.0007263923
#> 5 0.0022497188 0.0009685230
#> 6 0.0028121485 0.0012106538

# missing values are dropped
gini(c(1, NA, 3))
#> [1] 0.25

# a zero total has no Gini coefficient
try(gini(c(0, 0, 0)))
#> Error : every value is zero: the Gini coefficient of a zero total is undefined
```
