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
  NumberOfPlacements = c(31, 402, 28, 377, 12, 190, 19, 268, 24, 331),
  stringsAsFactors = FALSE
)
```

Segregation placements rising is bad news, so the direction is declared.
That affects colour and the verdict column, never the arithmetic.

``` r

y <- yoy(seg,
  value = NumberOfPlacements,
  prd = EndFiscalYear,
  by = "Gender",
  dir = "lower"
)
y
#> ╭── Change in NumberOfPlacements by EndFiscalYear ────────────────────────────╮
#> │   Rows    10                                                                │
#> │   Change  in percent                                                        │
#> │   Better  lower values                                                      │
#> │   Groups  2 (by Gender)                                                     │
#> │                                                                             │
#> │   Gender  EndFiscalYear  NumberOfPlacements previous change change %        │
#> │                          interval                                           │
#> │   ──────  ─────────────  ────────────────── ──────── ────── ────────        │
#> │                          ─────────────                                      │
#> │   Female  2019           31 — — — —                                         │
#> │                                                                             │
#> │   Female  2020           28 31 -3 ▼ -9.7% [-48%, +56%]                      │
#> │                                                                             │
#> │   Female  2021           12 28 -16 ▼ -57.1% [-80%, -13%]                    │
#> │                                                                             │
#> │   Female  2022           19 12 7 ▲ +58.3% [-27%, +258%]                     │
#> │                                                                             │
#> │   Female  2023           24 19 5 ▲ +26.3% [-34%, +144%]                     │
#> │                                                                             │
#> │   Male    2019           402 — — — —                                        │
#> │                                                                             │
#> │   Male    2020           377 402 -25 ▼ -6.2% [-19%, +8%]                    │
#> │                                                                             │
#> │   Male    2021           190 377 -187 ▼ -49.6% [-58%, -40%]                 │
#> │                                                                             │
#> │   Male    2022           268 190 78 ▲ +41.1% [+17%, +71%]                   │
#> │                                                                             │
#> │   Male    2023           331 268 63 ▲ +23.5% [+5%, +46%]                    │
#> │                                                                             │
#> │                                                                             │
#> │   Note: the first period of each group has nothing to compare with, so it   │
#> │   shows no change.                                                          │
#> │                                                                             │
#> │   lag 1 period                                                              │
#> │   units: count                                                              │
#> │   95% exact rate-ratio interval                                             │
#> │   lower is better                                                           │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
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
yoy(gap, value = n, prd = year)
#> ╭── Change in n by year ──────────────────────────────────────────────────────╮
#> │   Rows    5                                                                 │
#> │   Change  in percent                                                        │
#> │   Better  not set (direction neutral): the colour shows no verdict          │
#> │                                                                             │
#> │   year  n    previous  change  change %  interval                           │
#> │   ────  ───  ────────  ──────  ────────  ────────────                       │
#> │   2019  100  —         —         —       —                                  │
#> │   2020  120  100       20      ▲ +20.0%  [-9%, +58%]                        │
#> │   2021  —    120       —         —       —                                  │
#> │     ↳ note: no data                                                         │
#> │   2022  140  —         —         —       —                                  │
#> │   2023  150  140       10      ▲ +7.1%   [-15%, +36%]                       │
#> │                                                                             │
#> │   Note: the first period has nothing to compare with, so it shows no        │
#> │   change.                                                                   │
#> │                                                                             │
#> │   lag 1 period                                                              │
#> │   units: count                                                              │
#> │   95% exact rate-ratio interval                                             │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```

2021 appears as a row with no value, and 2022 has no comparison period
rather than a quietly three-year one.

## The second failure: a percent off a small base

Two placements becoming twenty is a 900% rise, and the same rise off a
base of two is far less certain than off a base of two hundred. The
percent is still the right number; what changes is its interval:

``` r

tiny <- data.frame(year = 2019:2021, n = c(2, 20, 25))
as.data.frame(yoy(tiny, value = n, prd = year))[, c("year", "pctchg",
                                                     "pctlo", "pctup")]
#>   year pctchg    pctlo     pctup
#> 1 2019     NA       NA        NA
#> 2 2020    900 142.9205 8724.1205
#> 3 2021     25 -33.3407  137.3319
```

Every non-zero base gets its percent and exact interval, however small
the base or the change. Set `minbase` to add a note to small-base rows;
nothing is withheld either way:

``` r

as.data.frame(yoy(tiny, value = n, prd = year, minbase = 20))$flag
#> [1] "no comparison period"  "small base (below 20)" NA
```

## The third failure: a percent of a percent

If a rate moves from 4% to 5% that is one percentage point. Calling it
25% answers a different question:

``` r

rate <- data.frame(year = 2019:2023, share = c(4.1, 4.6, 5.2, 5.0, 5.4))
yoy(rate, value = share, prd = year, units = "percent")
#> ╭── Change in share by year ──────────────────────────────────────────────────╮
#> │   Rows    5                                                                 │
#> │   Change  in percentage points                                              │
#> │   Better  not set (direction neutral): the colour shows no verdict          │
#> │                                                                             │
#> │   year  share  previous  change  points                                     │
#> │   ────  ─────  ────────  ──────  ────────                                   │
#> │   2019  4.1    —         —         —                                        │
#> │   2020  4.6    4.1       0.5     ▲ +0.5pp                                   │
#> │   2021  5.2    4.6       0.6     ▲ +0.6pp                                   │
#> │   2022  5.0    5.2       -0.2    ▼ -0.2pp                                   │
#> │   2023  5.4    5.0       0.4     ▲ +0.4pp                                   │
#> │                                                                             │
#> │   Note: the first period has nothing to compare with, so it shows no        │
#> │   change.                                                                   │
#> │                                                                             │
#> │   lag 1 period                                                              │
#> │   units: percent                                                            │
#> │   percentage-point change, not percent of a percent                         │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```

The column is named `points`, and no count interval is offered, because
these are not counts.

## Seasonal series

A monthly series compares with the same month a year earlier. The lag
follows the series’ own frequency, so January is never put against
December:

``` r

m <- stats::ts(c(10:21, 20:31), start = c(2021, 1), frequency = 12)
head(as.data.frame(yoy(m, minbase = 0))[12:14, c("period", "value",
                                                  "previous", "change")], 3)
#>      period value previous change
#> 12 2021.917    21       NA     NA
#> 13 2022.000    20       10     10
#> 14 2022.083    21       11     10
```

## Across the span

``` r

yoysmry(y)
#> ╭── Year-over-year summary ───────────────────────────────────────────────╮
#> │   Series  2                                                             │
#> │                                                                         │
#> │   Gender  from  to    first  last  totalpct  cagrpct  periods  up  down │
#> │   ------  ----  ----  -----  ----  --------  -------  -------  --  ---- │
#> │   Female  2019  2023     31    24    -22.58   -6.198        5   2     2 │
#> │   Male    2019  2023    402   331    -17.66   -4.742        5   2     2 │
#> │                                                                         │
#> │   Gender  flat                                                          │
#> │   ------  ----                                                          │
#> │   Female     0                                                          │
#> │   Male       0                                                          │
#> │                                                                         │
#> │   totalpct is the change from the first period to the last and cagrpct  │
#> │   the compound rate per step; up, down and flat count the changes from  │
#> │   one period to the next.                                               │
#> ╰─────────────────────────────────────────────────────────────────────────╯
```

`cagrpct` is the compound rate per period: applying it across the span
returns `totalpct` exactly.

## Rates, when the denominator moves too

[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
compares counts. A count is not comparable across places of different
size, or across years whose populations differ, and the fix is a rate –
but a rate is not made trustworthy by being a rate.

``` r

stops <- data.frame(
  division = c("North", "South", "East"),
  stops = c(412, 77, 3),
  residents = c(120000, 41000, 9500),
  stringsAsFactors = FALSE)

rtcalc(stops, stops, residents, by = "division", per = "100k")
#> ╭── Rate per 100,000 ─────────────────────────────────────────────────────╮
#> │   Count       stops                                                     │
#> │   Population  residents                                                 │
#> │   Groups      division                                                  │
#> │   Rows        3                                                         │
#> │   Interval    95% exact Poisson                                         │
#> │                                                                         │
#> │   division  count  population   rate  95% CI                            │
#> │   --------  -----  ----------  -----  --------------                    │
#> │   East          3       9,500   31.6  [6.5, 92.3]                       │
#> │   North       412     120,000  343.3  [311.0, 378.1]                    │
#> │   South        77      41,000  187.8  [148.2, 234.7]                    │
#> │                                                                         │
#> │   Highest rate: North (343.3); lowest: East (31.58). Their intervals do │
#> │   not overlap: the gap is more than sampling error.                     │
#> │                                                                         │
#> │   Each rate is the count over the population times the base; the exact  │
#> │   Poisson interval stays honest for small counts, where a normal one    │
#> │   does not.                                                             │
#> ╰─────────────────────────────────────────────────────────────────────────╯
```

East’s interval is wider than its own estimate. That is the honest
reading of three events, and it is the reason the interval is printed
beside the rate rather than left to the reader to imagine. The interval
is the exact Poisson one, so a count of zero has a lower limit of
exactly zero instead of a negative rate.

A share is a different quantity. Its denominator is the total of the
same events, not a population, so shares over a complete grouping sum to
100:

``` r

shrs(stops, stops, by = "division")
#> ╭── Share ───────────────────────────────────────────────────────────────╮
#> │   Count     stops                                                      │
#> │   Total     492                                                        │
#> │   Groups    division                                                   │
#> │   Interval  95% Wilson                                                 │
#> │                                                                        │
#> │   division  count  total  share  95% CI                                │
#> │   --------  -----  -----  -----  --------------                        │
#> │   East          3    492   0.61  [0.21, 1.78]                          │
#> │   North       412    492  83.74  [80.22, 86.74]                        │
#> │   South        77    492  15.65  [12.71, 19.13]                        │
#> │                                                                        │
#> │   Highest share: North (83.74); lowest: East (0.6098). Their intervals │
#> │   do not overlap: the gap is more than sampling error.                 │
#> │                                                                        │
#> │   Each share is the count as a percentage of the total, with a Wilson  │
#> │   interval, which stays inside 0 to 100 for small counts.              │
#> ╰────────────────────────────────────────────────────────────────────────╯
```

“40% of stops” and “40 stops per 1,000 residents” are different claims,
and a table that labels one as the other is wrong however carefully the
arithmetic was done. That is why these are separate functions.

For the change in a rate, both the counts and the denominators move:

``` r

d <- data.frame(
  year = rep(2021:2023, each = 2),
  division = rep(c("North", "South"), 3),
  stops = c(400, 70, 430, 66, 455, 61),
  residents = c(120000, 41000, 122000, 41500, 125000, 42000),
  stringsAsFactors = FALSE)

ratechg(d, stops, residents, year, by = "division", per = "100k")
#> ╭── Change in rate per 100,000 ───────────────────────────────────────────╮
#> │   Count       stops                                                     │
#> │   Population  residents                                                 │
#> │   Period      year                                                      │
#> │   Groups      division                                                  │
#> │   Lag         1                                                         │
#> │   Interval    95% exact conditional, on the % change                    │
#> │                                                                         │
#> │   division  year  count  population   rate  precnt   prepop  prerate    │
#> │   --------  ----  -----  ----------  -----  ------  -------  -------    │
#> │   North     2021    400     120,000  333.3                              │
#> │   North     2022    430     122,000  352.5     400  120,000    333.3    │
#> │   North     2023    455     125,000  364.0     430  122,000    352.5    │
#> │   South     2021     70      41,000  170.7                              │
#> │   South     2022     66      41,500  159.0      70   41,000    170.7    │
#> │   South     2023     61      42,000  145.2      66   41,500    159.0    │
#> │                                                                         │
#> │   division  rateratio  pctchg  pct_interval     flag                    │
#> │   --------  ---------  ------  ---------------  ----                    │
#> │   North                                         [1]                     │
#> │   North        1.0574   5.738  [-7.94, 21.47]                           │
#> │   North        1.0327   3.274  [-9.68, 18.10]                           │
#> │   South                                         [1]                     │
#> │   South        0.9315  -6.850  [-34.47, 32.29]                          │
#> │   South        0.9132  -8.676  [-36.60, 31.36]                          │
#> │                                                                         │
#> │   Not distinguishable from 0 (interval includes it): North 2022         │
#> │   (+5.7%), North 2023 (+3.3%), South 2022 (-6.9%) and South 2023        │
#> │   (-8.7%).                                                              │
#> │                                                                         │
#> │   [1] no comparison period                                              │
#> │   pctchg is the percentage change in the rate from the period `lag`     │
#> │   before; an interval that includes 0 means the change could be chance. │
#> ╰─────────────────────────────────────────────────────────────────────────╯
```

North’s count rose, and so did its population, so the rate change is
smaller than the count change – which is the whole reason to look at the
rate. The interval conditions on the two counts and corrects for the
ratio of the two exposures; with equal populations it reduces to exactly
the conditional-binomial interval
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
uses above.

## Output

The same object writes to six formats. The format follows the file name.

``` r

dir <- tempdir()
for (ext in c("csv", "tsv", "json", "md", "html", "pdf")) {
  f <- file.path(dir, paste0("placements.", ext))
  yoywr(y, f, title = "Placements by gender")
  cat(sprintf("%-5s %6d bytes\n", ext, file.size(f)))
}
#> csv      952 bytes
#> tsv      952 bytes
#> json    3233 bytes
#> md      1575 bytes
#> html    6754 bytes
#> pdf     5092 bytes
```

The delimited writers lead with the settings as comments, and carry the
`flag` column, so a row’s note (a zero base, a missing period) travels
with it:

``` r

cat(yoycsv(y, NULL, digits = 1L))
#> # value: NumberOfPlacements; period: EndFiscalYear; by: Gender; lag: 1; units: count; interval: 95% exact rate ratio; direction: lower is better
#> Gender,EndFiscalYear,value,previous,change,pctchg,flag,pctlo,pctup,verdict
#> Female,2019,31,,,,no comparison period,,,
#> Female,2020,28,31,-3,-9.7,,-47.8,55.6,better
#> Female,2021,12,28,-16,-57.1,,-80.1,-13,better
#> Female,2022,19,12,7,58.3,,-27,257.7,worse
#> Female,2023,24,19,5,26.3,,-33.7,143.9,worse
#> Male,2019,402,,,,no comparison period,,,
#> Male,2020,377,402,-25,-6.2,,-18.7,8.2,better
#> Male,2021,190,377,-187,-49.6,,-57.9,-39.8,better
#> Male,2022,268,190,78,41.1,,16.7,70.8,worse
#> Male,2023,331,268,63,23.5,,4.8,45.6,worse
```

Markdown, for a report:

``` r

cat(yoymd(yoy(gap, value = n, prd = year), NULL))
#> | year |   n | previous | change | change % |     interval | note                 |
#> | ---- | --: | -------: | -----: | -------: | -----------: | -------------------- |
#> | 2019 | 100 |        — |      — |        — |              | no comparison period |
#> | 2020 | 120 |      100 |     20 |   +20.0% |  [-9%, +58%] |                      |
#> | 2021 |   — |      120 |      — |        — |              | no data              |
#> | 2022 | 140 |        — |      — |        — |              | no comparison period |
#> | 2023 | 150 |      140 |     10 |    +7.1% | [-15%, +36%] |                      |
#> 
#> _value: n; period: year; lag: 1; units: count; interval: 95% exact rate ratio_
```

The HTML is a single self-contained file: it makes no network request,
so the page renders later exactly as it rendered when the capsule was
sealed. It defines its palette as custom properties and carries a dark
variant. The PDF is drawn on R’s own device and paginates rather than
truncating, so neither needs a package beyond base R.

``` r

yoypals()
#> [1] "diverging" "safe"      "mono"
```

`"safe"` is a blue/orange pair that survives both common forms of colour
blindness; `"mono"` emits no colour at all, for print.

## Indigenous examples

Change between survey cycles in percentage points, here the share of
adults rating their mental health very good or excellent, 2015/2018 to
2019/2022, from the bundled health indicators:

``` r

hi <- indiex("health")
m <- hi[hi$age == "Total, 18 years and over" &
          hi$indicator == "Perceived mental health, very good or excellent", ]
# yoy() steps through consecutive periods: number the two survey cycles 1 and 2
m$cycle <- match(m$period, c("2015/2018", "2019/2022"))
for (g in unique(m$group)) {
  s <- m[m$group == g, ]
  print(as.data.frame(yoy(s, value = estimate, prd = cycle, units = "percent"))[
    2, c("value", "previous", "ppchg", "verdict")])
}
#>   value previous ppchg verdict
#> 2  45.8     59.8   -14    down
#>   value previous ppchg verdict
#> 2  52.8       61  -8.2    down
#>   value previous ppchg verdict
#> 2  47.8     49.1  -1.3    down
#>   value previous ppchg verdict
#> 2  61.5     70.6  -9.1    down
```

## The change in a picture

[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
year-over-year result: each year’s change with its interval.

``` r

plot(y)
```

![](yoy_files/figure-html/yoy-yoy-plot-1.png)
