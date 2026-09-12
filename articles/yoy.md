# Year-over-year change, and the three ways it goes wrong

A year-over-year percent change is the most-quoted number in open-data
reporting and the least qualified.
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
computes it, and refuses to compute it in the three cases where the
figure would describe something other than the data.

## The data

Ontario’s inmate data is published one row per placement, by fiscal year
and by group. A realistic shape:

``` r

seg <- data.frame(
  EndFiscalYear = rep(2019:2023, each = 2),
  Gender = rep(c("Female", "Male"), 5),
  Number_Of_Placements = c(31, 402, 28, 377, 12, 190, 19, 268, 24, 331)
)
```

Segregation placements rising is bad news, so the direction is declared.
That affects colour and the verdict column, never the arithmetic.

``` r

y <- yoy(seg,
  value = Number_Of_Placements,
  period = EndFiscalYear,
  by = "Gender",
  direction = "lower_is_better"
)
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
```

The interval is exact. Conditional on the two periods’ total, the
current count is binomial, so the ratio of the two has a Clopper-Pearson
interval, which is the same construction
[`stats::poisson.test()`](https://rdrr.io/r/stats/poisson.test.html)
uses:

``` r

stats::poisson.test(c(331, 268), c(1, 1))$conf.int
#> [1] 1.048162 1.456380
#> attr(,"conf.level")
#> [1] 0.95
```

## The first failure: matching on row order

With a year missing, comparing row *i* with row *i - 1* compares 2023
with 2021 and labels it a one-year change. Matching on the period’s own
value cannot do that:

``` r

gap <- data.frame(year = c(2019, 2020, 2022, 2023), n = c(100, 120, 140, 150))
yoy(gap, value = n, period = year)
#> year  n    previous  change  change %  interval    
#> ────  ───  ────────  ──────  ────────  ────────────
#> 2019  100  —         —         —       —           
#>     ↳ percent withheld: no comparison period
#> 2020  120  100       20      ▲ +20.0%  [-9%, +58%] 
#> 2021  —    120       —         —       —           
#> 2022  140  —         —         —       —           
#>     ↳ percent withheld: no comparison period
#> 2023  150  140       10      ▲ +7.1%   [-15%, +36%]
#> 
#> lag 1 period · units: count · 95% exact rate-ratio interval · percent withheld below a base of 20
```

2021 appears as a row with no value, and 2022 has no comparison period
rather than a quietly three-year one.

## The second failure: a percent off a small base

Two placements becoming twenty is a 900% rise and also nothing at all.
The number describes how small the denominator was:

``` r

tiny <- data.frame(year = 2019:2021, n = c(2, 20, 25))
yoy(tiny, value = n, period = year)
#> year  n   previous  change  change %  interval     
#> ────  ──  ────────  ──────  ────────  ─────────────
#> 2019  2   —         —         —       —            
#>     ↳ percent withheld: no comparison period
#> 2020  20  2         18        —       —            
#>     ↳ percent withheld: base below 20
#> 2021  25  20        5       ▲ +25.0%  [-33%, +137%]
#> 
#> lag 1 period · units: count · 95% exact rate-ratio interval · percent withheld below a base of 20
```

The change of `+18` is still reported, and so is the direction: those
are facts. Only the percent is withheld, with the reason attached. Lower
the gate if the small base is the point:

``` r

as.data.frame(yoy(tiny, value = n, period = year, min_base = 0))$pct_change
#> [1]  NA 900  25
```

## The third failure: a percent of a percent

If a rate moves from 4% to 5% that is one percentage point. Calling it
25% answers a different question:

``` r

rate <- data.frame(year = 2019:2023, share = c(4.1, 4.6, 5.2, 5.0, 5.4))
yoy(rate, value = share, period = year, units = "percent")
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

The column is named `points`, and no count interval is offered, because
these are not counts.

## Seasonal series

A monthly series compares with the same month a year earlier. The lag
follows the series’ own frequency, so January is never put against
December:

``` r

m <- stats::ts(c(10:21, 20:31), start = c(2021, 1), frequency = 12)
head(as.data.frame(yoy(m, min_base = 0))[12:14, c("period", "value",
                                                  "previous", "change")], 3)
#>      period value previous change
#> 12 2021.917    21       NA     NA
#> 13 2022.000    20       10     10
#> 14 2022.083    21       11     10
```

## Across the span

``` r

yoy_summary(y)
#>   Gender from   to first last total_pct  cagr_pct periods up down flat
#> 1 Female 2019 2023    31   24 -22.58065 -6.197938       5  0    2    0
#> 2   Male 2019 2023   402  331 -17.66169 -4.742214       5  2    2    0
```

`cagr_pct` is the compound rate per period: applying it across the span
returns `total_pct` exactly.

## Output

The same object writes to six formats. The format follows the file name.

``` r

dir <- tempdir()
for (ext in c("csv", "tsv", "json", "md", "html", "pdf")) {
  f <- file.path(dir, paste0("placements.", ext))
  yoy_write(y, f, title = "Placements by gender")
  cat(sprintf("%-5s %6d bytes\n", ext, file.size(f)))
}
#> csv      931 bytes
#> tsv      931 bytes
#> json    3374 bytes
#> md      1630 bytes
#> html    6852 bytes
#> pdf     5104 bytes
```

The delimited writers lead with the settings as comments, and carry the
`flag` column, so a withheld percentage stays marked as withheld
wherever it lands:

``` r

cat(yoy_csv(y, NULL, digits = 1L))
#> # value: Number_Of_Placements; period: EndFiscalYear; by: Gender; lag: 1; units: count; interval: 95% exact rate ratio; percent withheld below a base of 20; direction: lower is better
#> Gender,EndFiscalYear,value,previous,change,pct_change,flag,pct_lower,pct_upper,verdict
#> Female,2019,31,,,,no comparison period,,,
#> Female,2020,28,31,-3,-9.7,,-47.8,55.6,better
#> Female,2021,12,28,-16,-57.1,,-80.1,-13,better
#> Female,2022,19,12,7,,base below 20,,,worse
#> Female,2023,24,19,5,,base below 20,,,worse
#> Male,2019,402,,,,no comparison period,,,
#> Male,2020,377,402,-25,-6.2,,-18.7,8.2,better
#> Male,2021,190,377,-187,-49.6,,-57.9,-39.8,better
#> Male,2022,268,190,78,41.1,,16.7,70.8,worse
#> Male,2023,331,268,63,23.5,,4.8,45.6,worse
```

Markdown, for a report:

``` r

cat(yoy_markdown(yoy(gap, value = n, period = year), NULL))
#> | year | n   | previous | change | change % |     interval | note                 |
#> | ---- | --- | -------- | -----: | -------: | -----------: | -------------------- |
#> | 2019 | 100 | —        |      — |        — |              | no comparison period |
#> | 2020 | 120 | 100      |     20 |   +20.0% |  [-9%, +58%] |                      |
#> | 2021 | —   | 120      |      — |        — |              |                      |
#> | 2022 | 140 | —        |      — |        — |              | no comparison period |
#> | 2023 | 150 | 140      |     10 |    +7.1% | [-15%, +36%] |                      |
#> 
#> _value: n; period: year; lag: 1; units: count; interval: 95% exact rate ratio; percent withheld below a base of 20_
```

The HTML is a single self-contained file: it makes no network request,
so the page renders later exactly as it rendered when the capsule was
sealed. It defines its palette as custom properties and carries a dark
variant. The PDF is drawn on R’s own device and paginates rather than
truncating, so neither needs a package beyond base R.

``` r

yoy_palettes()
#> [1] "diverging" "safe"      "mono"
```

`"safe"` is a blue/orange pair that survives both common forms of colour
blindness; `"mono"` emits no colour at all, for print.
