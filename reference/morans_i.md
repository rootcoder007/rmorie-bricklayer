# Global Moran's I over a neighbour list

Spatial autocorrelation for an areal variable, with a permutation
p-value. A neighbour list is required and is not invented: an
administrative extract keyed on a region ships no geometry, and guessing
adjacency would make the answer a property of the guess.

## Usage

``` r
morans_i(x, neighbours, style = c("W", "B"), n_perm = 9999L)
```

## Arguments

- x:

  The variable, one value per area.

- neighbours:

  Either a list with one integer vector of neighbour indices per area,
  or a square weight matrix.

- style:

  `"W"` row-standardises the weights, so each area's neighbours carry a
  total weight of one; `"B"` leaves them binary. Row standardisation is
  the usual choice, and stops an area with many neighbours from
  dominating.

- n_perm:

  Permutations for the null distribution.

## Value

A list with `I`, its expectation under the null (`-1/(n-1)`, which is
not zero), the permutation mean and standard deviation, a `z` score,
`p_value`, and `W`, the total weight.

## Details

The expectation of I under the null is `-1/(n - 1)`, not zero, so a
small negative I is what independence looks like in a small set of
areas. The p-value comes from permuting the values over the areas, which
needs no distributional assumption – and with a handful of regions no
distributional assumption is safe.

## Examples

``` r
# Six areas in a line, each adjacent to the next.
nb <- list(2L, c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), 5L)

# A smooth gradient is strongly positively autocorrelated.
set.seed(1)
morans_i(c(1, 2, 3, 4, 5, 6), nb, n_perm = 999L)[c("I", "p_value")]
#> $I
#> [1] 0.7142857
#> 
#> $p_value
#> [1] 0.011
#> 

# An alternating pattern is negatively autocorrelated.
set.seed(1)
morans_i(c(1, 6, 1, 6, 1, 6), nb, n_perm = 999L)[c("I", "p_value")]
#> $I
#> [1] -1
#> 
#> $p_value
#> [1] 0.199
#> 

# And the null expectation is not zero.
-1 / (6 - 1)
#> [1] -0.2
```
