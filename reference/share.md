# Share of a total, in percent

What fraction of a total each count is, with the Wilson interval.

## Usage

``` r
share(x, ...)

# S3 method for class 'data.frame'
share(x, count, by = NULL, total = NULL, conf_level = 0.95, ...)

# Default S3 method
share(x, total = NULL, conf_level = 0.95, ...)
```

## Arguments

- x:

  A data frame, or a numeric vector of counts.

- ...:

  Passed to methods.

- count:

  Column of counts: non-negative whole numbers.

- by:

  Character vector of grouping columns. Shares are computed over the
  groups, so they sum to 100 unless `total` says otherwise.

- total:

  The denominator. `NULL` (default) sums `count`, which makes the shares
  sum to 100. A number, or a column name, uses that instead – for the
  case where some of the total is not in the table.

- conf_level:

  Confidence level for the interval.

## Value

A data frame of class `rmbl_share` with the grouping columns, `count`,
`total`, `share`, `lower` and `upper`, plus a `share` attribute
recording the denominator and the confidence level.

## Details

A share and a rate are different quantities: a share's denominator is
the total of the same events, so shares over a complete grouping sum to
100. Use
[`rate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate.md)
when the denominator is a population.

The interval is Wilson's, not the textbook normal approximation. The
normal interval on a proportion is wrong in exactly the cases people
reach for it – small counts and shares near 0 or 100, where it runs past
the ends of the scale and reports a negative percentage. Wilson's stays
inside the scale and is accurate at those counts.

## See also

[`rate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate.md)
for events per population,
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
for change between periods.

## Examples

``` r
stops <- data.frame(
  division = c("North", "South", "East"),
  stops = c(412, 77, 3))

# shares of the table's own total, summing to 100
share(stops, stops, by = "division")
#> Share of 492, 95% Wilson interval
#>   division count total      share      lower     upper
#> 1     East     3   492  0.6097561  0.2075843  1.777215
#> 2    North   412   492 83.7398374 80.2200225 86.736863
#> 3    South    77   492 15.6504065 12.7074531 19.125597

# East is 0.6% of stops, and the interval does not run below zero
# the way a normal approximation would
share(stops, stops, by = "division")$lower
#> [1]  0.2075843 80.2200225 12.7074531

# a denominator from outside the table
share(stops, stops, by = "division", total = 10000)
#> Share of 10,000, 95% Wilson interval
#>   division count total share      lower      upper
#> 1     East     3 10000  0.03 0.01020322 0.08817358
#> 2    North   412 10000  4.12 3.74774662 4.52748907
#> 3    South    77 10000  0.77 0.61657440 0.96123408
```
