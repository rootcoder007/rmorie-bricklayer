# How much a result depends on the open band's assumed cap

Recomputes a statistic across a range of assumed caps for the open top
band and reports how far the answer moves. Everything derived from
banded data carries this dependence; the only question is whether it was
measured.

## Usage

``` r
band_sensitivity(
  bands,
  counts,
  statistic = gini,
  caps = NULL,
  rule = "midpoint"
)

# S3 method for class 'rmbl_band_sensitivity'
print(x, ...)
```

## Arguments

- bands:

  A data frame from
  [`parse_bands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/parse_bands.md),
  or labels to parse.

- counts:

  How many units fall in each band.

- statistic:

  A function of a numeric vector of per-unit values. Defaults to
  [`gini()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md).

- caps:

  Caps to try for the open top band. Defaults to a geometric sweep from
  the band's lower bound to twenty times it.

- rule:

  Passed to
  [`band_values()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_values.md).

- x:

  An `rmbl_band_sensitivity` object.

- ...:

  Ignored.

## Value

A data frame of `cap` and `value`, with the span and the relative span
attached as attributes and printed by
[`print()`](https://rdrr.io/r/base/print.html).

## Examples

``` r
b <- parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
counts <- c(1200, 430, 110, 38)

s <- band_sensitivity(b, counts)
s
#> Sensitivity to the open top band's assumed cap
#> 
#>        cap     value
#>   11.55000 0.4254708
#>   15.09841 0.4346095
#>   19.73696 0.4461100
#>   25.80058 0.4604302
#>   33.72707 0.4780278
#>   44.08875 0.4993060
#>   57.63375 0.5245371
#>   75.34008 0.5537719
#>   98.48616 0.5867522
#>  128.74322 0.6228545
#>  168.29590 0.6610951
#>  220.00000 0.7002144
#> 
#> span over the caps tried: 0.2747 (53.7% of the typical value)
#> The statistic moves by more than a tenth of itself across the
#> caps tried, so it is a property of the assumption as much as
#> of the data. Report the range, not a single figure.

# A statistic that barely moves has been measured; one that swings
# has not.
band_sensitivity(b, counts, statistic = mean)
#> Sensitivity to the open top band's assumed cap
#> 
#>        cap    value
#>   11.55000 2.257283
#>   15.09841 2.295202
#>   19.73696 2.344771
#>   25.80058 2.409567
#>   33.72707 2.494271
#>   44.08875 2.604998
#>   57.63375 2.749742
#>   75.34008 2.938955
#>   98.48616 3.186298
#>  128.74322 3.509629
#>  168.29590 3.932296
#>  220.00000 4.484814
#> 
#> span over the caps tried: 2.228 (83.2% of the typical value)
#> The statistic moves by more than a tenth of itself across the
#> caps tried, so it is a property of the assumption as much as
#> of the data. Report the range, not a single figure.
```
