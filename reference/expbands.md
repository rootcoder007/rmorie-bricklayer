# Expand a banded frequency table into per-unit values

Turns a banded frequency table (labels and a count per band) into a
numeric vector with one value per unit, using the representative value
of each band from
[`bandvals`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandvals.md).
The result can be passed to any function that expects individual values,
such as
[`ginicoef`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md),
[`mean()`](https://rdrr.io/r/base/mean.html) or
[`quantile()`](https://rdrr.io/r/stats/quantile.html). Bands that cannot
be parsed but have units in them are an error by default, so a statistic
never describes only part of the data without saying so.

## Usage

``` r
expbands(bands, cnts, ..., drpunp = FALSE)
```

## Arguments

- bands:

  A data frame from
  [`prsbands`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prsbands.md),
  or labels to parse.

- cnts:

  Numeric vector, one non-negative count per band.

- ...:

  Further arguments to
  [`bandvals`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandvals.md):
  `rule`, `openupcap`, `openupfac` and `openloflr`.

- drpunp:

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
`drpunp = TRUE`, in which case its units are left out with a warning
that gives their number and labels.

Errors: `cnts` of the wrong length, non-numeric or negative; an
unplaceable band with units (by default); any error from
[`bandvals`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandvals.md).

## See also

[`bandvals`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandvals.md),
[`bandsens`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandsens.md)

## Examples

``` r
x <- expbands(c("1", "2 to 5", "Greater than 5"),
                  cnts = c(10, 4, 2), openupcap = 12)
table(x)
#> x
#>   1 3.5   9 
#>  10   4   2 
ginicoef(x)
#> [1] 0.452381

# the lower-bound reading of the same table
expbands(c("1", "2 to 5", "Greater than 5"), cnts = c(10, 4, 2),
             rule = "lower")
#>  [1] 1 1 1 1 1 1 1 1 1 1 2 2 2 2 6 6

# an unparseable band with units in it stops the call
try(expbands(c("1", "not stated"), cnts = c(3, 2)))
#> Error : 2 unit(s) in 1 band(s) could not be placed: 'not stated' (set drpunp = TRUE to leave them out)
```
