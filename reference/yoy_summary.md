# Summarise a change table

Summarise a change table

## Usage

``` r
yoy_summary(object, ...)

# S3 method for class 'rmbl_yoy'
yoy_summary(object, ...)
```

## Arguments

- object:

  An `rmbl_yoy` object.

- ...:

  Ignored.

## Value

A data frame with one row per group giving the first and last period,
the total change across the span, the compound annual growth rate, and
how many periods moved each way.

## Examples

``` r
d <- data.frame(year = 2018:2023, n = c(120, 131, 98, 140, 155, 149))
yoy_summary(yoy(d, value = "n", period = "year"))
#>   from   to first last total_pct cagr_pct periods up down flat
#> 1 2018 2023   120  149  24.16667 4.424163       6  3    2    0
```
