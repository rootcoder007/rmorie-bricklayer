# Expand a banded frequency table into per-unit values

Expand a banded frequency table into per-unit values

## Usage

``` r
expand_bands(bands, counts, ..., drop_unparsed = FALSE)
```

## Arguments

- bands:

  A data frame from
  [`parse_bands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/parse_bands.md),
  or labels to parse.

- counts:

  How many units fall in each band.

- ...:

  Passed to
  [`band_values()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_values.md).

- drop_unparsed:

  A band whose label could not be parsed, yet which has a count, is an
  error by default: every statistic computed from the result would
  otherwise describe a fraction of the data in silence. `TRUE` leaves
  those units out with a warning instead.

## Value

A numeric vector with one entry per unit.

## Examples

``` r
x <- expand_bands(c("1", "2 to 5", "Greater than 5"),
                  counts = c(10, 4, 2), open_upper_cap = 12)
table(x)
#> x
#>   1 3.5   9 
#>  10   4   2 

gini(x)
#> [1] 0.452381
```
