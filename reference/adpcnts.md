# Person-days estimated from periodic headcounts

When only a count of people present on certain days is available – not a
record per person – the person-days over the period are the mean of
those counts scaled to the period's length. Use it with
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md)
or
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)
when the source is a daily or weekly count sheet rather than admission
and release dates.

## Usage

``` r
adpcnts(cnts, t = 365)
```

## Arguments

- cnts:

  Numeric vector of headcounts, one per day on which a count was taken;
  non-negative, no `NA` or `Inf`. The days need not be consecutive.

- t:

  Numeric scalar, the length of the period in days; must be positive.
  Default `365`.

## Value

A numeric scalar: the estimated person-days over the period,
`mean(counts) * t`. Despite the function's name this is a total of
person-days, not an average daily population; divide by `t` (or pass it
to
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md))
for the population held on an average day. It has class
`c("rmbl_adpcnts", "rmbl_measure", "numeric")` and an attribute
`"lakner"` (the number of counts, their mean and `t`), so it prints as a
box with its inputs, formula and caveats; arithmetic,
[`round()`](https://rdrr.io/r/base/Round.html),
[`sum()`](https://rdrr.io/r/base/sum.html),
[`mean()`](https://rdrr.io/r/base/mean.html), `[`,
[`c()`](https://rdrr.io/r/base/c.html) and
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) give a plain
number, and
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md)
takes it as `days`.

## Details

Lakner's \\X_t = (\frac{1}{C}\sum N_i) t\\ (1976, p.21). The counts need
not cover every day: counting on weekdays only is the usual case, and
the mean of the days counted stands in for the days not counted. That
substitution is an assumption, and it fails if the days counted differ
systematically from the days missed – weekday-only counting where
weekend admissions are released before Monday, for instance.

## See also

[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md)

## Examples

``` r
# Lakner (p.21): counts on 255 days summing to 34,935 imply just over
# fifty thousand detention days across the year.
adpcnts(rep(34935 / 255, 255))
#> ╭── Person-days from headcounts ──────────────────────────────────────────────╮
#> │   Person-days  50,005 over the period                                       │
#> │   Headcounts   255 days counted                                             │
#> │   Mean count   137 people                                                   │
#> │   Period       365 days                                                     │
#> │   Formula      days = mean(counts) x t = 137 x 365                          │
#> │                                                                             │
#> │   Counts on 255 days average 137 people: about 50,005 person-days in 365    │
#> │   days.                                                                     │
#> │                                                                             │
#> │   Lakner (1976, p.21): the mean of the days counted stands in for the       │
#> │   days not counted, which fails if they differ systematically (weekday      │
#> │   counts where weekend admissions leave before Monday).                     │
#> │   A total of person-days, not a population: adp(x, t) divides by t.         │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# weekly counts over a 31-day month, then the average daily population
pd <- adpcnts(c(120, 130, 125, 128), t = 31)
pd
#> ╭── Person-days from headcounts ──────────────────────────────────────────────╮
#> │   Person-days  3898 over the period                                         │
#> │   Headcounts   4 days counted                                               │
#> │   Mean count   125.8 people                                                 │
#> │   Period       31 days                                                      │
#> │   Formula      days = mean(counts) x t = 125.8 x 31                         │
#> │                                                                             │
#> │   Counts on 4 days average 125.8 people: about 3898 person-days in 31 days. │
#> │                                                                             │
#> │   Lakner (1976, p.21): the mean of the days counted stands in for the       │
#> │   days not counted, which fails if they differ systematically (weekday      │
#> │   counts where weekend admissions leave before Monday).                     │
#> │   A total of person-days, not a population: adp(x, t) divides by t.         │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
adp(pd, t = 31)
#> ╭── Average daily population ─────────────────────────────────────────────╮
#> │   Average daily population  125.8 people on an average day              │
#> │   Person-days               3898                                        │
#> │   Period                    31 days                                     │
#> │   Formula                   adp = days / t = 3898 / 31                  │
#> │                                                                         │
#> │   3898 person-days over 31 days: 125.8 people held on an average day.   │
#> │                                                                         │
#> │   Lakner (1976, p.15): a stock -- people held at once, not people who   │
#> │   passed through. Count only the days served inside the period.         │
#> │   adp = n x alos / t links it to alos() and admits(), exactly only in a │
#> │   steady state.                                                         │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# a missing count must be dropped or filled first
try(adpcnts(c(120, NA, 125)))
#> Error : `cnts` must not contain NA
```
