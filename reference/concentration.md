# Concentration of a total across units

Measures how unevenly a total is spread across units: whether a few
people account for most of the placements, or a few regions for most of
the days. `ginicoef()` gives the Gini coefficient, `lorenzc()` the
points of the Lorenz curve (for plotting, for example with
[`plotlrnz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotlrnz.md)),
and `topshr()` the share of the total held by the largest units (“the
top 1% of people account for 20% of the days”). The three are computed
in compiled code from the same sorted values.

## Usage

``` r
ginicoef(x, na.rm = TRUE)

lorenzc(x, na.rm = TRUE)

topshr(x, fracs = c(0.01, 0.05, 0.1, 0.25), na.rm = TRUE)
```

## Arguments

- x:

  Numeric vector of non-negative values, one per unit (for example the
  days or the count of placements of each person). `NA` values are
  dropped; `Inf`, negative values and non-numeric input are errors.

- na.rm:

  Logical. Missing values are dropped whatever its value; the argument
  exists so the call reads the same as base R's. Default `TRUE`.

- fracs:

  Numeric vector of fractions of the units, each in `[0, 1]`: for each
  one the share of the total held by that fraction of units, taking the
  largest units first. Default `c(0.01, 0.05, 0.1, 0.25)`.

## Value

`ginicoef()`: a numeric scalar in `[0, 1 - 1/n]`. `lorenzc()`: a data
frame with numeric columns `population` (cumulative share of units, from
0 to 1) and `value` (cumulative share of the total, units in ascending
order), `n + 1` rows including the origin. `topshr()`: a data frame with
columns `fraction` (the requested fraction of units), `units` (how many
of the largest units that fraction is) and `share` (the share of the
total those units hold). It has class
`c("rmbl_gini", "rmbl_measure", "numeric")`, so it prints as a box with
its inputs (kept in attribute `"lakner"`); arithmetic, `[`,
[`c()`](https://rdrr.io/r/base/c.html) and
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) give plain
numbers.

## Details

Gini is the mean absolute difference between pairs of units over twice
the mean, \\G = \sum_i \sum_j \|x_i - x_j\| / (2 n^2 \bar{x})\\, which
is also twice the area between the Lorenz curve and the diagonal. Zero
is a perfectly even spread; the maximum for `n` units is `1 - 1/n`, not
1, so a Gini near 1 requires many units as well as an uneven spread.

A Gini computed from banded or rounded data inherits that coarsening:
compare with
[`bandsens()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandsens.md)
when the values are bands. For a tail that a few units dominate,
[`hilltlidx()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hilltlidx.md)
says whether the largest values follow a power law.

Errors: `x` not numeric, with `Inf` or a negative value, or with no
non-missing value; `ginicoef()` when every value is zero (the Gini of a
zero total is undefined); `topshr()` when `fractions` is not numeric, is
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

[`hilltlidx()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hilltlidx.md),
[`bandsens()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandsens.md)

## Examples

``` r
# Ten units holding one each: no concentration.
ginicoef(rep(1, 10))
#> ╭── Gini coefficient ─────────────────────────────────────────────────────────╮
#> │   Gini coefficient  0                                                       │
#> │   Units             10                                                      │
#> │   Total             10                                                      │
#> │   Largest unit      1 (10.0% of the total)                                  │
#> │   Most for n units  0.9                                                     │
#> │                                                                             │
#> │   A Gini of 0: the total is close to equal shares.                          │
#> │   That is 0% of the way from equal shares (0) to one unit holding all of    │
#> │   it (0.9 for 10 units).                                                    │
#> │                                                                             │
#> │   0 when every unit holds the same, 1 - 1/n when one unit holds it all;     │
#> │   doubling every value leaves it unchanged. It says how unequal, not        │
#> │   which units: topshr() and lorenzc() show where the total sits.            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# One unit holding everything: the maximum for ten units.
ginicoef(c(rep(0, 9), 1))
#> ╭── Gini coefficient ─────────────────────────────────────────────────────────╮
#> │   Gini coefficient  0.9                                                     │
#> │   Units             10                                                      │
#> │   Total             1                                                       │
#> │   Largest unit      1 (100.0% of the total)                                 │
#> │   Most for n units  0.9                                                     │
#> │                                                                             │
#> │   A Gini of 0.9: the total is very highly concentrated.                     │
#> │   That is 100% of the way from equal shares (0) to one unit holding all of  │
#> │   it (0.9 for 10 units).                                                    │
#> │                                                                             │
#> │   0 when every unit holds the same, 1 - 1/n when one unit holds it all;     │
#> │   doubling every value leaves it unchanged. It says how unequal, not        │
#> │   which units: topshr() and lorenzc() show where the total sits.            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
1 - 1 / 10
#> [1] 0.9

placements <- c(rep(1, 1200), rep(3, 430), rep(8, 110), rep(20, 38))
ginicoef(placements)
#> ╭── Gini coefficient ─────────────────────────────────────────────────────────╮
#> │   Gini coefficient  0.4612                                                  │
#> │   Units             1,778                                                   │
#> │   Total             4,130                                                   │
#> │   Largest unit      20 (0.5% of the total)                                  │
#> │   Most for n units  0.9994                                                  │
#> │                                                                             │
#> │   A Gini of 0.4612: the total is highly concentrated.                       │
#> │   That is 46% of the way from equal shares (0) to one unit holding all of   │
#> │   it (0.9994 for 1,778 units).                                              │
#> │                                                                             │
#> │   0 when every unit holds the same, 1 - 1/n when one unit holds it all;     │
#> │   doubling every value leaves it unchanged. It says how unequal, not        │
#> │   which units: topshr() and lorenzc() show where the total sits.            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# What the most frequent few account for.
topshr(placements, c(0.01, 0.05, 0.1))
#> ╭── Top shares of a total ────────────────────────────────────────────────╮
#> │   Fractions  3                                                          │
#> │                                                                         │
#> │   top  units  share                                                     │
#> │   ---  -----  ------                                                    │
#> │   1%      18  8.717%                                                    │
#> │   5%      89  28.28%                                                    │
#> │   10%    178  41.89%                                                    │
#> │                                                                         │
#> │   The top 1% of units (18 of them) hold 8.717% of the total; with equal │
#> │   shares they would hold 1%.                                            │
#> ╰─────────────────────────────────────────────────────────────────────────╯

head(lorenzc(placements))
#>     population        value
#> 1 0.0000000000 0.0000000000
#> 2 0.0005624297 0.0002421308
#> 3 0.0011248594 0.0004842615
#> 4 0.0016872891 0.0007263923
#> 5 0.0022497188 0.0009685230
#> 6 0.0028121485 0.0012106538

# missing values are dropped
ginicoef(c(1, NA, 3))
#> ╭── Gini coefficient ─────────────────────────────────────────────────────────╮
#> │   Gini coefficient  0.25                                                    │
#> │   Units             2                                                       │
#> │   Total             4                                                       │
#> │   Largest unit      3 (75.0% of the total)                                  │
#> │   Most for n units  0.5                                                     │
#> │                                                                             │
#> │   A Gini of 0.25: the total is moderately concentrated.                     │
#> │   That is 50% of the way from equal shares (0) to one unit holding all of   │
#> │   it (0.5 for 2 units).                                                     │
#> │                                                                             │
#> │   0 when every unit holds the same, 1 - 1/n when one unit holds it all;     │
#> │   doubling every value leaves it unchanged. It says how unequal, not        │
#> │   which units: topshr() and lorenzc() show where the total sits.            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# a zero total has no Gini coefficient
try(ginicoef(c(0, 0, 0)))
#> Error : every value is zero: the Gini coefficient of a zero total is undefined
```
