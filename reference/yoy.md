# Year-over-year (and period-over-period) change

Computes the change from one period to the period `lag` places before
it, matched on the period's own value rather than on row order, and
carries an exact interval for count data.

## Usage

``` r
yoy(x, ...)

# S3 method for class 'data.frame'
yoy(
  x,
  value,
  period,
  by = NULL,
  lag = 1L,
  fun = sum,
  units = c("count", "continuous", "percent"),
  min_base = NULL,
  conf_level = 0.95,
  direction = c("neutral", "higher_is_better", "lower_is_better"),
  complete = TRUE,
  ...
)

# S3 method for class 'numeric'
yoy(x, period = seq_along(x), ...)

# S3 method for class 'integer'
yoy(x, period = seq_along(x), ...)

# S3 method for class 'ts'
yoy(x, lag = NULL, ...)

# S3 method for class 'rmbl_yoy'
print(x, digits = 1L, palette = "diverging", color = NULL, n = 30L, ...)
```

## Arguments

- x:

  An `rmbl_yoy` object.

- ...:

  Ignored.

- value:

  For a data frame, the column holding the measure, as a string or a
  bare name.

- period:

  For a data frame, the column holding the period (a year, a `Date`, a
  fiscal-year integer, an ordered factor). For a numeric vector, the
  periods themselves.

- by:

  Optional grouping columns, as a character vector. The change is
  computed within each group.

- lag:

  How many periods back to compare with. `1` is year-over-year on annual
  data; for a `ts` the default follows the series' own frequency, so
  monthly data compares with the same month a year earlier.

- fun:

  Aggregation applied to `value` within a period and group, when there
  is more than one row. Default
  [`sum()`](https://rdrr.io/r/base/sum.html), which is what a count
  needs.

- units:

  What the measure is. `"count"` gets the exact rate-ratio interval.
  `"continuous"` gets the percent change without one, since a single
  pair of totals carries no information about its own variability.
  `"percent"` reports a percentage-POINT change and withholds the
  percent change, which for a percentage is a different quantity.

- min_base:

  Smallest previous-period value for which a percent change is reported.
  Below it the percent is `NA` and the reason is recorded, rather than a
  large number that describes the denominator. Defaults to 20 for counts
  and to no gate otherwise.

- conf_level:

  Confidence level for the count interval.

- direction:

  Which way is an improvement: `"higher_is_better"`, `"lower_is_better"`
  (segregation days, deaths in custody, use of force), or `"neutral"`.
  Affects colour and the `verdict` column only, never the arithmetic.

- complete:

  Whether to insert the missing periods in the observed range so that a
  gap is visible as a gap instead of closing up.

- digits:

  Digits for the percent column.

- palette:

  One of
  [`yoy_palettes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_palettes.md).

- color:

  Whether to emit ANSI colour. Defaults to colour only when writing to a
  terminal that has it, so a redirected or captured output stays plain
  text.

- n:

  Maximum rows to print.

## Value

An `rmbl_yoy` object: a data frame with one row per period (and group),
and columns `period`, `value`, `previous`, `change`, `pct_change` (or
`pp_change` for percentages), `pct_lower` and `pct_upper` for counts,
`verdict`, and `flag` recording why a percent was withheld.

## See also

[`yoy_html()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md),
[`yoy_pdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md),
[`yoy_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_summary.md)

## Examples

``` r
seg <- data.frame(
  EndFiscalYear = rep(2019:2023, each = 2),
  Gender = rep(c("Female", "Male"), 5),
  Number_Of_Placements = c(31, 402, 28, 377, 12, 190, 19, 268, 24, 331)
)

y <- yoy(seg, value = "Number_Of_Placements", period = "EndFiscalYear",
         by = "Gender", direction = "lower_is_better")
y
#> Gender  EndFiscalYear  Number_Of_Placements  previous  change  change %  interval    
#> ──────  ─────────────  ────────────────────  ────────  ──────  ────────  ────────────
#> Female  2019           31                    —         —         —       —           
#>     ↳ percent withheld: no comparison period
#> Female  2020           28                    31        -3      ▼ -9.7%   [-48%, +56%]
#> Female  2021           12                    28        -16     ▼ -57.1%  [-80%, -13%]
#> Female  2022           19                    12        7         —       —           
#>     ↳ percent withheld: base below 20
#> Female  2023           24                    19        5         —       —           
#>     ↳ percent withheld: base below 20
#> Male    2019           402                   —         —         —       —           
#>     ↳ percent withheld: no comparison period
#> Male    2020           377                   402       -25     ▼ -6.2%   [-19%, +8%] 
#> Male    2021           190                   377       -187    ▼ -49.6%  [-58%, -40%]
#> Male    2022           268                   190       78      ▲ +41.1%  [+17%, +71%]
#> Male    2023           331                   268       63      ▲ +23.5%  [+5%, +46%] 
#> 
#> lag 1 period · units: count · 95% exact rate-ratio interval · percent withheld below a base of 20 · lower is better

# The interval is exact, so a small group does not get a confident
# percent it has not earned.
subset(as.data.frame(y), Gender == "Female")
#>   Gender EndFiscalYear value previous change pct_change                 flag
#> 1 Female          2019    31       NA     NA         NA no comparison period
#> 2 Female          2020    28       31     -3  -9.677419                 <NA>
#> 3 Female          2021    12       28    -16 -57.142857                 <NA>
#> 4 Female          2022    19       12      7         NA        base below 20
#> 5 Female          2023    24       19      5         NA        base below 20
#>   pct_lower pct_upper verdict
#> 1        NA        NA    <NA>
#> 2 -47.79679  55.62836  better
#> 3 -80.14950 -12.97354  better
#> 4        NA        NA   worse
#> 5        NA        NA   worse

# A percentage is handled as percentage points, not as a percent of a
# percent.
rate <- data.frame(year = 2019:2023, share = c(4.1, 4.6, 5.2, 5.0, 5.4))
yoy(rate, value = "share", period = "year", units = "percent")
#> year  share  previous  change  points  
#> ────  ─────  ────────  ──────  ────────
#> 2019  4.1    —         —         —     
#>     ↳ percent withheld: no comparison period
#> 2020  4.6    4.1       0.5     ▲ +0.5pp
#> 2021  5.2    4.6       0.6     ▲ +0.6pp
#> 2022  5.0    5.2       -0.2    ▼ -0.2pp
#> 2023  5.4    5.0       0.4     ▲ +0.4pp
#> 
#> lag 1 period · units: percent · percentage-point change, not percent of a percent
```
