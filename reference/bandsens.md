# How much a result depends on the open band's assumed cap

Recomputes a statistic of banded data (by default the Gini coefficient)
for a range of assumed caps on the open top band, and reports how far
the answer moves. Every statistic computed from banded data depends on
where the open band is assumed to end; this function measures that
dependence, so you can report a range instead of a single figure when
the dependence is large.

## Usage

``` r
bandsens(bands, cnts, stat = ginicoef, caps = NULL, rule = "midpoint")

# S3 method for class 'rmbl_band_sensitivity'
format(x, digits = 4L, ...)

# S3 method for class 'rmbl_band_sensitivity'
print(x, ...)
```

## Arguments

- bands:

  A data frame from
  [`prsbands`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prsbands.md),
  or labels to parse.

- cnts:

  Numeric vector, one per band: how many units fall in each band.
  Non-integer counts are truncated by
  [`rep()`](https://rdrr.io/r/base/rep.html).

- stat:

  A function that takes a numeric vector of per-unit values and returns
  one number. Default
  [`ginicoef`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md).

- caps:

  Numeric vector of caps to try, in the units of the labels. Default
  `NULL`: the geometric sweep described in Details. Values are sorted
  and de-duplicated.

- rule:

  Character, default `"midpoint"`: the placement rule passed to
  [`bandvals`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandvals.md).

- x:

  An `rmbl_band_sensitivity` object.

- digits:

  Significant digits of the printed numbers.

- ...:

  Further arguments to print(); the band table ignores them.

## Value

A data frame of class `c("rmbl_band_sensitivity", "data.frame")` with
numeric columns `cap` and `value`, and attributes `span`, `relspan` and
`base` (the lower bound \\b\\ of the open band).

## Details

Let \\b\\ be the smallest lower bound among the open top bands. The
default caps are 12 points spaced evenly on the log scale from \\1.05
b\\ to \\20 b\\. For each cap \\c\\,
[`bandvals`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandvals.md)`(bands, rule, openupcap = c)`
gives one value per band, each value is repeated `cnts` times, and
`stat` is applied to the result. A statistic that errors or does not
return a single number gives `NA`; warnings are suppressed.

The span is \\\max - \min\\ over the finite values and the relative span
is the span divided by the median absolute value (`NA` when any value is
zero). The print method adds a note when the relative span exceeds 0.1.

Errors: `cnts` not numeric or of a different length from the bands; no
open top band.

## Examples

``` r
b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
counts <- c(1200, 430, 110, 38)

s <- bandsens(b, counts)
s
#> ╭── Sensitivity to the open top band's assumed cap ───────────────────────╮
#> │   Open band starts at         11                                        │
#> │   Caps tried                  12                                        │
#> │   Span over the caps          0.2747                                    │
#> │   Share of the typical value  53.7%                                     │
#> │                                                                         │
#> │      cap   value                                                        │
#> │   ------  ------                                                        │
#> │    11.55  0.4255                                                        │
#> │    15.10  0.4346                                                        │
#> │    19.74  0.4461                                                        │
#> │    25.80  0.4604                                                        │
#> │    33.73  0.4780                                                        │
#> │    44.09  0.4993                                                        │
#> │    57.63  0.5245                                                        │
#> │    75.34  0.5538                                                        │
#> │    98.49  0.5868                                                        │
#> │   128.74  0.6229                                                        │
#> │   168.30  0.6611                                                        │
#> │   220.00  0.7002                                                        │
#> │                                                                         │
#> │   span over the caps tried: 0.2747 (53.7% of the typical value). The    │
#> │   statistic moves by more than a tenth of itself across the caps tried, │
#> │   so it is a property of the assumption as much as of the data. Report  │
#> │   the range, not a single figure.                                       │
#> ╰─────────────────────────────────────────────────────────────────────────╯
attr(s, "relspan")
#> [1] 0.5366908

# A statistic that barely moves has been measured; one that swings
# has not.
bandsens(b, counts, stat = mean, caps = c(12, 20, 50))
#> ╭── Sensitivity to the open top band's assumed cap ───────────────────────╮
#> │   Open band starts at         11                                        │
#> │   Caps tried                  3                                         │
#> │   Span over the caps          0.4061                                    │
#> │   Share of the typical value  17.3%                                     │
#> │                                                                         │
#> │   cap  value                                                            │
#> │   ---  -----                                                            │
#> │    12  2.262                                                            │
#> │    20  2.348                                                            │
#> │    50  2.668                                                            │
#> │                                                                         │
#> │   span over the caps tried: 0.4061 (17.3% of the typical value). The    │
#> │   statistic moves by more than a tenth of itself across the caps tried, │
#> │   so it is a property of the assumption as much as of the data. Report  │
#> │   the range, not a single figure.                                       │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# nothing to vary without an open band
try(bandsens(c("1", "2 to 5"), c(10, 4)))
#> Error : no open upper band, so there is nothing to be sensitive to
```
