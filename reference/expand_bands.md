# Expand a banded frequency table into per-unit values

Turns a banded frequency table (labels and a count per band) into a
numeric vector with one value per unit, using the representative value
of each band from
[`band_values`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_values.md).
The result can be passed to any function that expects individual values,
such as
[`gini`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md),
[`mean()`](https://rdrr.io/r/base/mean.html) or
[`quantile()`](https://rdrr.io/r/stats/quantile.html). Bands that cannot
be parsed but have units in them are an error by default, so a statistic
never describes only part of the data without saying so.

## Usage

``` r
expand_bands(bands, counts, ..., drop_unparsed = FALSE)
```

## Arguments

- bands:

  A data frame from
  [`parse_bands`](https://rootcoder007.github.io/rmorie-bricklayer/reference/parse_bands.md),
  or labels to parse.

- counts:

  Numeric vector, one non-negative count per band.

- ...:

  Further arguments to
  [`band_values`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_values.md):
  `rule`, `open_upper_cap`, `open_upper_factor` and `open_lower_floor`.

- drop_unparsed:

  Logical, default `FALSE`. `FALSE` makes a band whose label could not
  be parsed, yet which has a count, an error; `TRUE` leaves those units
  out with a warning instead.

## Value

A numeric vector with one entry per unit (length `sum(round(counts))`
over the placed bands).

## Details

Each band's value is repeated `round(counts)` times, in band order.
Bands with an `NA` count are skipped. A band with an `NA` value
(unparsed label) and a positive count is an error unless
`drop_unparsed = TRUE`, in which case its units are left out with a
warning that gives their number and labels.

Errors: `counts` of the wrong length, non-numeric or negative; an
unplaceable band with units (by default); any error from
[`band_values`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_values.md).

## See also

[`band_values`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_values.md),
[`band_sensitivity`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md)

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

# the lower-bound reading of the same table
expand_bands(c("1", "2 to 5", "Greater than 5"), counts = c(10, 4, 2),
             rule = "lower")
#>  [1] 1 1 1 1 1 1 1 1 1 1 2 2 2 2 6 6

# an unparseable band with units in it stops the call
try(expand_bands(c("1", "not stated"), counts = c(3, 2)))
#> Error : 2 unit(s) in 1 band(s) could not be placed: 'not stated' (set drop_unparsed = TRUE to leave them out)
```
