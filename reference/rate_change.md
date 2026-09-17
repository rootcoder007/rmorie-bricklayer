# Change in a rate between periods

The change in a rate from one period to the period `lag` places earlier,
with the exact conditional interval for the rate ratio.

## Usage

``` r
rate_change(x, ...)

# S3 method for class 'data.frame'
rate_change(
  x,
  count,
  population,
  period,
  by = NULL,
  lag = 1L,
  per = 1000,
  conf_level = 0.95,
  min_count = 0,
  ...
)
```

## Arguments

- x:

  A data frame.

- ...:

  Passed to methods.

- count:

  Column of counts: non-negative whole numbers.

- population:

  Column of exposure: positive.

- period:

  Column of periods. Sorted, and compared on the period value rather
  than on row position, so a missing year gives no comparison instead of
  a silent comparison against the wrong year.

- by:

  Character vector of grouping columns.

- lag:

  How many periods back to compare against. Default 1.

- per:

  The rate denominator: a positive number, or `"1k"`, `"10k"`, `"100k"`,
  `"1m"`.

- conf_level:

  Confidence level for the interval.

- min_count:

  Comparisons where the earlier count is at or below this are flagged
  and their percent change withheld, the way
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
  withholds a percent change off a tiny base.

## Value

A data frame of class `rmbl_rate_change` with the grouping columns,
`period`, `count`, `population`, `rate`, `previous_rate`, `rate_ratio`,
`pct_change`, `pct_lower`, `pct_upper` and `flag`.

## Details

This is not the percent change of two rates treated as measured numbers.
Both the counts and the denominators move between periods, and an
interval that ignores the denominators understates the uncertainty of
the change. The construction here conditions on the total of the two
counts and corrects for the ratio of the two exposures, which is
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)'s
exact conditional-binomial interval generalised to unequal denominators:
with equal populations it reduces to exactly that.

## See also

[`rate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate.md),
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
for change in a count or a measured quantity.

## Examples

``` r
d <- data.frame(
  year = rep(2021:2023, each = 2),
  division = rep(c("North", "South"), 3),
  stops = c(400, 70, 430, 66, 455, 61),
  residents = c(120000, 41000, 122000, 41500, 125000, 42000))

# North's count rose while its population rose too: the rate change
# is smaller than the count change, which is the reason to use it
rate_change(d, stops, residents, year, by = "division", per = "100k")
#> ── Change in rate per 100,000, lag 1, 95% exact conditional interval  
#>  division year count population     rate previous_rate previous_count
#>     North 2021   400     120000 333.3333            NA             NA
#>     North 2022   430     122000 352.4590      333.3333            400
#>     North 2023   455     125000 364.0000      352.4590            430
#>     South 2021    70      41000 170.7317            NA             NA
#>     South 2022    66      41500 159.0361      170.7317             70
#>     South 2023    61      42000 145.2381      159.0361             66
#>  previous_population rate_ratio pct_change  pct_lower pct_upper
#>                   NA         NA         NA         NA        NA
#>               120000  1.0573770   5.737705  -7.937165  21.46533
#>               122000  1.0327442   3.274419  -9.679876  18.10199
#>                   NA         NA         NA         NA        NA
#>                41000  0.9314974  -6.850258 -34.473784  32.29053
#>                41500  0.9132395  -8.676046 -36.596300  31.35600
#>                  flag
#>  no comparison period
#>                  <NA>
#>                  <NA>
#>  no comparison period
#>                  <NA>
#>                  <NA>
#> ────────────────────────────────────────────────────────────────── 
```
