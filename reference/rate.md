# Event rates per unit of population

Counts divided by exposure and scaled to a denominator, with the exact
Poisson interval that says how much of the result is signal.

## Usage

``` r
rate(x, ...)

# S3 method for class 'data.frame'
rate(
  x,
  count,
  population,
  by = NULL,
  per = 1000,
  conf_level = 0.95,
  min_count = 0,
  ...
)

# Default S3 method
rate(x, population, per = 1000, conf_level = 0.95, min_count = 0, ...)
```

## Arguments

- x:

  A data frame, or a numeric vector of counts.

- ...:

  Passed to methods.

- count:

  Column of counts: non-negative whole numbers.

- population:

  Column of exposure: positive. Person-years, stops, residents –
  whatever the events were at risk of happening to.

- by:

  Character vector of grouping columns. The rate is computed within each
  group.

- per:

  The rate denominator: a positive number, or `"1k"`, `"10k"`, `"100k"`,
  `"1m"`. Default 1000.

- conf_level:

  Confidence level for the interval.

- min_count:

  Counts at or below this are flagged as too small to report, with the
  rate still computed. Default 0, which flags nothing; published
  guidance often uses 5 or 10.

## Value

A data frame of class `rmbl_rate` with the grouping columns, `count`,
`population`, `rate`, `lower`, `upper` and `flag`, plus a `rate`
attribute recording the denominator and the confidence level.

## Details

A count is not comparable across areas of different size or years of
different population; a rate is. What a rate does not do is become
reliable just because it is a rate: three events in a small area gives a
rate with an interval several times its own width, and the interval here
is the one that says so. It is the exact Poisson interval, computed
through the gamma relation, so a count of zero has a lower limit of
exactly zero rather than a negative number.

`per` takes a number, or one of `"1k"`, `"10k"`, `"100k"`, `"1m"`,
because a denominator mistyped by a factor of ten is invisible once it
reaches a table.

## See also

[`share()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/share.md)
for a percentage of a total,
[`rate_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate_change.md)
for the change in a rate between periods,
[`sir()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sir.md)
for a rate compared against an expected count rather than a population.

## Examples

``` r
stops <- data.frame(
  division = c("North", "South", "East"),
  stops = c(412, 77, 3),
  residents = c(120000, 41000, 9500))

# per 1,000 residents, the default
rate(stops, stops, residents, by = "division")
#> ── Rate per 1,000, 95% exact Poisson interval ──────────────────── 
#>  division count population      rate      lower     upper flag
#>      East     3       9500 0.3157895 0.06512338 0.9228708 <NA>
#>     North   412     120000 3.4333333 3.10977110 3.7814142 <NA>
#>     South    77      41000 1.8780488 1.48212673 2.3472387 <NA>
#> ────────────────────────────────────────────────────────────────── 

# the denominator published guidance usually asks for
rate(stops, stops, residents, by = "division", per = "100k")
#> ── Rate per 100,000, 95% exact Poisson interval ────────────────── 
#>  division count population      rate      lower     upper flag
#>      East     3       9500  31.57895   6.512338  92.28708 <NA>
#>     North   412     120000 343.33333 310.977110 378.14142 <NA>
#>     South    77      41000 187.80488 148.212673 234.72387 <NA>
#> ────────────────────────────────────────────────────────────────── 

# East's three events: the interval is wider than the estimate, and
# flagging it is the point of min_count
rate(stops, stops, residents, by = "division", per = "100k",
     min_count = 5)
#> ── Rate per 100,000, 95% exact Poisson interval ────────────────── 
#>  division count population      rate      lower     upper                flag
#>      East     3       9500  31.57895   6.512338  92.28708 count at or below 5
#>     North   412     120000 343.33333 310.977110 378.14142                <NA>
#>     South    77      41000 187.80488 148.212673 234.72387                <NA>
#> ────────────────────────────────────────────────────────────────── 

# vectors work too, for a single figure
rate(3, 9500, per = "100k")
#> ── Rate per 100,000, 95% exact Poisson interval ────────────────── 
#>  count population     rate    lower    upper flag
#>      3       9500 31.57895 6.512338 92.28708 <NA>
#> ────────────────────────────────────────────────────────────────── 
```
