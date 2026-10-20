# Year-over-year (and period-over-period) change

Computes the change from one period to the period `lag` places before
it, matched on the period's own value rather than on row order, and
carries an exact interval for count data. Use it for the "up 12% on last
year" figures of an annual report or an open-data release: a missing
year shows as a gap instead of shifting every comparison, a percentage
is compared in percentage points, and a change off a small count comes
with an interval as wide as the count is small.

## Usage

``` r
yoy(x, ...)

# Default S3 method
yoy(x, ...)

# S3 method for class 'data.frame'
yoy(
  x,
  value,
  prd,
  by = NULL,
  lag = 1L,
  fun = NULL,
  units = c("count", "continuous", "percent"),
  minbase = NULL,
  conflvl = 0.95,
  dir = c("neutral", "higher", "lower"),
  complete = TRUE,
  ...
)

# S3 method for class 'numeric'
yoy(x, prd = seq_along(x), ...)

# S3 method for class 'integer'
yoy(x, prd = seq_along(x), ...)

# S3 method for class 'ts'
yoy(x, lag = NULL, ...)

# S3 method for class 'rmbl_yoy'
print(x, digits = 1L, palette = "diverging", color = NULL, n = 30, ...)
```

## Arguments

- x:

  An `rmbl_yoy` object returned by `yoy()`.

- ...:

  Ignored.

- value:

  For a data frame, the column holding the measure, as a string or a
  bare name.

- prd:

  For a data frame, the column holding the period (a year, a `Date`, a
  fiscal-year integer, an ordered factor). An ordered factor is compared
  by level order, one level being one period; an unordered factor or a
  character column has no order, so every row is flagged "no comparison
  period". For a numeric vector, the periods themselves.

- by:

  Optional grouping columns, as a character vector. The change is
  computed within each group.

- lag:

  How many periods back to compare with. `1` is year-over-year on annual
  data; for a `ts` the default follows the series' own frequency, so
  monthly data compares with the same month a year earlier.

- fun:

  How several rows of one period (and group) are combined into one
  value: `NULL` (the default) sums counts
  ([`sum()`](https://rdrr.io/r/base/sum.html)) and averages continuous
  values and percentages ([`mean()`](https://rdrr.io/r/base/mean.html));
  pass a function of a numeric vector returning one number to choose.

- units:

  What the measure is. `"count"` gets the exact rate-ratio interval.
  `"continuous"` gets the percent change without one, since a single
  pair of totals carries no information about its own variability.
  `"percent"` reports a percentage-POINT change and withholds the
  percent change, which for a percentage is a different quantity.

- minbase:

  Optional: previous-period values below this get a "small base" note.
  Nothing is withheld either way: every non-zero base gets its percent
  change and exact interval, which is as wide as the base is small.
  Defaults to 0 (no note); only a zero base has no percent change.

- conflvl:

  Numeric scalar in (0, 1), the confidence level for the count interval;
  default 0.95.

- dir:

  Which way is an improvement: `"higher"`, `"lower"` (segregation days,
  deaths in custody, use of force), or `"neutral"`. Affects colour and
  the `verdict` column only, never the arithmetic.

- complete:

  Logical scalar, default `TRUE`: insert the missing periods in the
  observed range so that a gap is visible as a gap instead of closing
  up.

- digits:

  Integer, default `1`. Decimal places shown in the percent (or
  percentage-point) change column. The interval column is always shown
  to whole percent.

- palette:

  Character, default `"diverging"`. One of
  [`yoypals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoypals.md);
  chooses the colours used when `color = TRUE`. An unknown name is an
  error.

- color:

  Logical or `NULL` (the default). `TRUE` wraps each row in 24-bit ANSI
  colour codes chosen from its verdict; `FALSE` prints plain text.
  `NULL` means colour only in an interactive session with the `NO_COLOR`
  environment variable unset, so output that is redirected or captured
  stays plain text.

- n:

  Integer, default `30`. Maximum number of rows printed; the number of
  rows left out is reported on a final line.

## Value

An `rmbl_yoy` object (a data frame of class
`c("rmbl_yoy", "data.frame")`) with one row per period (and group): the
period column under its own name (`period` for a vector or a `ts`), the
grouping columns, then `value`, `previous`, `change`, `pctchg` (or
`ppchg` for percentages), `flag` (character: "no comparison period", "no
data", "previous period is zero", or a small-base note when `minbase` is
set; `NA` otherwise), `pctlo` and `pctup` for counts, and `verdict`.
Attribute `"yoy"` records `value`, `period`, `by`, `lag`, `units`,
`minbase`, `conflvl`, `direction` and the display digits; the writers
([`yoywr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoywr.md))
and
[`yoysmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoysmry.md)
read it.

## Details

Rows are first combined to one per period (and group) with `fun`. With
`complete = TRUE` the periods missing from a regular grid (numbers,
`Date` or `POSIXct` with a common step) are inserted with `NA` values
and flagged "no data". Each period is then compared with the period
`lag` steps earlier in that grid: `change` is the difference, `pctchg`
\\100 (v_t / v\_{t-lag} - 1)\\ (`NA` off a zero base), and for
percentages `ppchg` is the difference in percentage points.

For counts, conditional on their sum \\n = a + b\\ the current count
\\a\\ is binomial with probability \\\rho / (1 + \rho)\\, \\\rho\\ the
rate ratio; the Clopper-Pearson interval for that probability,
transformed back, is an exact interval for the ratio, reported as
`pctlo` and `pctup` (percent change). It is the interval
[`stats::poisson.test()`](https://rdrr.io/r/stats/poisson.test.html)
gives for two counts with equal exposure. A zero base has no percent
change but still an interval (with an infinite upper end).

`verdict` is `"up"`, `"down"` or `"unchanged"` for
`direction = "neutral"`, and `"better"`, `"worse"` or `"unchanged"`
otherwise; it reads the sign of the change only and makes no claim of
significance.

Errors: `x` neither a data frame, a numeric vector nor a `ts`; `value`,
`period` or `by` naming a column that does not exist; a non-numeric or
infinite `value`; for `units = "count"`, negative or fractional values;
`lag` not a positive whole number; `conflvl` outside (0, 1); an unknown
`units` or `direction`.

## References

The exact interval for a ratio of two counts is the conditional-binomial
(Clopper-Pearson) one, which is the construction
[`stats::poisson.test`](https://rdrr.io/r/stats/poisson.test.html) uses
and which this is verified against. On the reporting conventions, the
Toronto Police Service's *Understanding Strip Searches in 2020
Methodological Report* – in the local corpus – reports year-over-year
change on exactly this kind of administrative extract, and is the shape
this function is built for.

## See also

[`yoyhtml()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoyren.md),
[`yoypdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoyren.md),
[`yoysmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoysmry.md)

## Examples

``` r
seg <- data.frame(
  EndFiscalYear = rep(2019:2023, each = 2),
  Gender = rep(c("Female", "Male"), 5),
  NumberOfPlacements = c(31, 402, 28, 377, 12, 190, 19, 268, 24, 331)
)

y <- yoy(seg,
  value = "NumberOfPlacements", prd = "EndFiscalYear",
  by = "Gender", dir = "lower"
)
y
#> Gender  EndFiscalYear  NumberOfPlacements  previous  change  change %  interval     
#> ──────  ─────────────  ──────────────────  ────────  ──────  ────────  ─────────────
#> Female  2019           31                  —         —         —       —            
#>     ↳ note: no comparison period
#> Female  2020           28                  31        -3      ▼ -9.7%   [-48%, +56%] 
#> Female  2021           12                  28        -16     ▼ -57.1%  [-80%, -13%] 
#> Female  2022           19                  12        7       ▲ +58.3%  [-27%, +258%]
#> Female  2023           24                  19        5       ▲ +26.3%  [-34%, +144%]
#> Male    2019           402                 —         —         —       —            
#>     ↳ note: no comparison period
#> Male    2020           377                 402       -25     ▼ -6.2%   [-19%, +8%]  
#> Male    2021           190                 377       -187    ▼ -49.6%  [-58%, -40%] 
#> Male    2022           268                 190       78      ▲ +41.1%  [+17%, +71%] 
#> Male    2023           331                 268       63      ▲ +23.5%  [+5%, +46%]  
#> 
#> lag 1 period · units: count · 95% exact rate-ratio interval · lower is better

# The interval is exact, so a small group does not get a confident
# percent it has not earned.
subset(as.data.frame(y), Gender == "Female")
#>   Gender EndFiscalYear value previous change     pctchg                 flag
#> 1 Female          2019    31       NA     NA         NA no comparison period
#> 2 Female          2020    28       31     -3  -9.677419                 <NA>
#> 3 Female          2021    12       28    -16 -57.142857                 <NA>
#> 4 Female          2022    19       12      7  58.333333                 <NA>
#> 5 Female          2023    24       19      5  26.315789                 <NA>
#>       pctlo     pctup verdict
#> 1        NA        NA    <NA>
#> 2 -47.79679  55.62836  better
#> 3 -80.14950 -12.97354  better
#> 4 -27.02865 257.66674   worse
#> 5 -33.67876 143.90121   worse

# A percentage is handled as percentage points, not as a percent of a
# percent.
rate <- data.frame(year = 2019:2023, share = c(4.1, 4.6, 5.2, 5.0, 5.4))
yoy(rate, value = "share", prd = "year", units = "percent")
#> year  share  previous  change  points  
#> ────  ─────  ────────  ──────  ────────
#> 2019  4.1    —         —         —     
#>     ↳ note: no comparison period
#> 2020  4.6    4.1       0.5     ▲ +0.5pp
#> 2021  5.2    4.6       0.6     ▲ +0.6pp
#> 2022  5.0    5.2       -0.2    ▼ -0.2pp
#> 2023  5.4    5.0       0.4     ▲ +0.4pp
#> 
#> lag 1 period · units: percent · percentage-point change, not percent of a percent

# a missing year stays a gap; a bare column name works too
yoy(data.frame(year = c(2019, 2021, 2022), n = c(10, 12, 15)), value = n, prd = year)
#> year  n   previous  change  change %  interval     
#> ────  ──  ────────  ──────  ────────  ─────────────
#> 2019  10  —         —         —       —            
#>     ↳ note: no comparison period
#> 2020  —   10        —         —       —            
#>     ↳ note: no data
#> 2021  12  —         —         —       —            
#>     ↳ note: no comparison period
#> 2022  15  12        3       ▲ +25.0%  [-45%, +192%]
#> 
#> lag 1 period · units: count · 95% exact rate-ratio interval

# a quarterly series compares each quarter with the same quarter a year earlier
q <- ts(c(5, 6, 7, 8, 6, 7, 9, 9), frequency = 4, start = c(2020, 1))
as.data.frame(yoy(q))[5:8, c("period", "value", "previous", "pctchg")]
#>    period value previous   pctchg
#> 5 2021.00     6        5 20.00000
#> 6 2021.25     7        6 16.66667
#> 7 2021.50     9        7 28.57143
#> 8 2021.75     9        8 12.50000

# counts must be whole numbers
try(yoy(data.frame(year = 1:3, n = c(1.5, 2, 3)), "n", "year"))
#> Error : `units = "count"` needs non-negative whole numbers; use units = "continuous" for a measured quantity
```
