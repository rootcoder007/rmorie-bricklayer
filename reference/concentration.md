# Concentration of a total across units

Concentration of a total across units

## Usage

``` r
gini(x, na.rm = TRUE)

lorenz(x, na.rm = TRUE)

top_share(x, fractions = c(0.01, 0.05, 0.1, 0.25), na.rm = TRUE)
```

## Arguments

- x:

  Non-negative values, one per unit.

- na.rm:

  Whether to drop missing values. They are dropped either way; this
  argument exists so the call reads the same as base R's.

- fractions:

  Fractions of the units, largest first, to report the share of.

## Value

`gini()` a single number in `[0, 1]`, `NA` when the total is zero.
`lorenz()` a data frame of cumulative population and value shares,
including the origin. `top_share()` a data frame of the requested
fractions, the share each holds, and how many units that was.

## Details

Gini is the mean absolute difference between pairs of units over twice
the mean, which is also twice the area between the Lorenz curve and the
diagonal. Zero is a perfectly even spread; the maximum for `n` units is
`1 - 1/n`, not 1, so a Gini near 1 requires many units as well as an
uneven spread.

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
```
