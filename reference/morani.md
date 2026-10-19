# Global Moran's I over a neighbour list

Measures spatial autocorrelation in a variable measured on areas:
whether neighbouring areas tend to have similar values (positive I),
dissimilar values (negative I), or neither. The p-value comes from
randomly permuting the values over the areas. You must supply the
neighbour structure (a list or a weight matrix); none is invented,
because an administrative extract keyed on a region ships no geometry,
and guessing adjacency would make the answer a property of the guess.

## Usage

``` r
morani(x, nbrs, style = c("W", "B"), nperm = 9999L)
```

## Arguments

- x:

  Numeric vector, one value per area, no missing values.

- nbrs:

  Either a list with one integer vector of neighbour indices per area
  (in the order of `x`), or a square \\n \times n\\ weight matrix.

- style:

  `"W"` (the default) row-standardises the weights, so each area's
  neighbours carry a total weight of one; `"B"` leaves them as given
  (binary for a list). Row standardisation is the usual choice, and
  stops an area with many neighbours from dominating.

- nperm:

  Integer, default `9999`: the number of random permutations for the
  null distribution.

## Value

A list with `I` (the statistic), `expectation` (\\-1/(n-1)\\),
`nullmean` and `nullsd` (mean and standard deviation of the permuted
values), `z` (`(I - nullmean) / nullsd`), `p_value`, `W` (the total
weight), `n` (number of areas), `nperm` (permutations used) and `style`.

## Details

With weights \\w\_{ij}\\, total \\W = \sum\_{ij} w\_{ij}\\ and \\z_i =
x_i - \bar x\\, \$\$I = \frac{n}{W}\\\frac{\sum\_{i}\sum\_{j} w\_{ij}
z_i z_j}{\sum_i z_i^2}.\$\$ The expectation of I under the null is
\\-1/(n - 1)\\, not zero, so a small negative I is what independence
looks like in a small set of areas. The p-value comes from permuting the
values over the areas, which needs no distributional assumption – and
with a handful of regions no distributional assumption is safe. It is
two-sided around \\-1/(n - 1)\\, \\(1 + \mathrm{count}(\|I^\* - E\| \ge
\|I - E\|))/(1 + B)\\ over the \\B\\ finite permuted values, so it is
never exactly zero.

A neighbour list is binary; a weight matrix keeps its magnitudes (for
example inverse distances). Self-neighbours and the diagonal are
dropped. `style = "W"` divides each area's weights by their total. The
permutations use R's random number generator, so call
[`set.seed()`](https://rdrr.io/r/base/Random.html) first for a
reproducible p-value. The work is done in compiled code.

Errors: fewer than three areas; missing values in `x`; a constant `x`; a
neighbour index outside `1..n`; a list of the wrong length; a weight
matrix that is not \\n \times n\\, not finite, or has negative weights;
no area with any neighbour.

## References

Moran, P. A. P. (1950). Notes on continuous stochastic phenomena.
*Biometrika* 37(1/2), 17-23. Laniyonu (2017), on policing practices in
gentrifying neighbourhoods, uses the statistic as here, to establish
that areal residuals are spatially dependent.

## Examples

``` r
# Six areas in a line, each adjacent to the next.
nb <- list(2L, c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), 5L)

# A smooth gradient is strongly positively autocorrelated.
set.seed(1)
morani(c(1, 2, 3, 4, 5, 6), nb, nperm = 999L)[c("I", "p_value")]
#> $I
#> [1] 0.7142857
#> 
#> $p_value
#> [1] 0.011
#> 

# An alternating pattern is negatively autocorrelated.
set.seed(1)
morani(c(1, 6, 1, 6, 1, 6), nb, nperm = 999L)[c("I", "p_value")]
#> $I
#> [1] -1
#> 
#> $p_value
#> [1] 0.199
#> 

# And the null expectation is not zero.
-1 / (6 - 1)
#> [1] -0.2

# the same line as a binary weight matrix, unstandardised
w <- matrix(0, 6, 6)
for (i in 1:5) w[i, i + 1] <- w[i + 1, i] <- 1
set.seed(1)
morani(c(1, 2, 3, 4, 5, 6), w, style = "B", nperm = 999L)$I
#> [1] 0.6

# a constant variable has no autocorrelation to measure
try(morani(c(2, 2, 2), list(2L, c(1L, 3L), 2L)))
#> Error : `x` is constant: Moran's I is undefined (no variance to autocorrelate)
```
