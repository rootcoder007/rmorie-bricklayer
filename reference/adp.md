# Average daily population

The mean number of person-days served per day over a period: a STOCK,
answering how many people are held at one time. Use it to report how
much confinement (or bed occupancy, shelter use, open caseload) a system
used over a year or any other window, from the days each person spent in
it. It is the measure capacity planning needs, because it counts beds in
use rather than people who passed through.

## Usage

``` r
adp(days, t = 365)
```

## Arguments

- days:

  Numeric vector of person-days served during the period, non-negative,
  no `NA` or `Inf`. The vector is summed, so one element per person and
  a single pre-computed total give the same result.

- t:

  Numeric scalar, the length of the period in days; must be positive.
  Default `365`. A vector of several values is refused.
  [`perdays`](https://rootcoder007.github.io/rmorie-bricklayer/reference/perdays.md)
  turns two dates into this.

## Value

A numeric scalar: person-days per day, that is the average number of
people held on any one day of the period. It has class
`c("rmbl_adp", "rmbl_measure", "numeric")` and an attribute `"lakner"`
(the total days and `t`), so it prints as a box with its inputs, formula
and caveats; arithmetic, [`round()`](https://rdrr.io/r/base/Round.html),
[`sum()`](https://rdrr.io/r/base/sum.html),
[`mean()`](https://rdrr.io/r/base/mean.html), `[`,
[`c()`](https://rdrr.io/r/base/c.html) and
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) give a plain
number.

## Details

This is Lakner's \\\bar{X}\_{hc} = \sum X_i / t\\ (1976, p.15), where
\\X_i\\ is the days served by person \\i\\ inside the period. The
denominator is TIME, which is what makes it a stock. Compare
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md),
whose denominator is people: the two are linked by \\\mathrm{ADP} = N
\times \mathrm{ALOS} / t\\ (Little's law), so
[`admits()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/admits.md)
and
[`stkflow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stkflow.md)
can move between them.

Only days served inside the period should be counted: a stay that began
before the period or ends after it contributes its days within the
window.

Errors when `days` is not numeric (text and factors are refused), is
empty, has `NA`, `Inf` or a negative value, or when `t` is not a single
positive number.

## References

Lakner, E. (1976) *A Manual of Statistical Sampling Methods for
Corrections Planners*. University of Illinois at Urbana-Champaign.

## See also

[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md),
[`stkflow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stkflow.md),
[`adpcnts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adpcnts.md)

## Examples

``` r
# Lakner's own worked example (p.15): 3,000 inmates served 13,500
# detention days in a year.
adp(13500)
#> ╭── Average daily population ──────────────────────────────────────────────╮
#> │   Average daily population  36.99 people on an average day               │
#> │   Person-days               13,500                                       │
#> │   Period                    365 days                                     │
#> │   Formula                   adp = days / t = 13,500 / 365                │
#> │                                                                          │
#> │   13,500 person-days over 365 days: 36.99 people held on an average day. │
#> │                                                                          │
#> │   Lakner (1976, p.15): a stock -- people held at once, not people who    │
#> │   passed through. Count only the days served inside the period.          │
#> │   adp = n x alos / t links it to alos() and admits(), exactly only in a  │
#> │   steady state.                                                          │
#> ╰──────────────────────────────────────────────────────────────────────────╯

# per-person days give the same total
adp(c(10, 20, 30), t = 30)
#> ╭── Average daily population ─────────────────────────────────────────────╮
#> │   Average daily population  2 people on an average day                  │
#> │   Person-days               60                                          │
#> │   Period                    30 days                                     │
#> │   Formula                   adp = days / t = 60 / 30                    │
#> │                                                                         │
#> │   60 person-days over 30 days: 2 people held on an average day.         │
#> │                                                                         │
#> │   Lakner (1976, p.15): a stock -- people held at once, not people who   │
#> │   passed through. Count only the days served inside the period.         │
#> │   adp = n x alos / t links it to alos() and admits(), exactly only in a │
#> │   steady state.                                                         │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# a leap year, with the period length taken from the dates
adp(13500, t = perdays("2024-01-01", "2024-12-31"))
#> ╭── Average daily population ──────────────────────────────────────────────╮
#> │   Average daily population  36.89 people on an average day               │
#> │   Person-days               13,500                                       │
#> │   Period                    366 days                                     │
#> │   Formula                   adp = days / t = 13,500 / 366                │
#> │                                                                          │
#> │   13,500 person-days over 366 days: 36.89 people held on an average day. │
#> │                                                                          │
#> │   Lakner (1976, p.15): a stock -- people held at once, not people who    │
#> │   passed through. Count only the days served inside the period.          │
#> │   adp = n x alos / t links it to alos() and admits(), exactly only in a  │
#> │   steady state.                                                          │
#> ╰──────────────────────────────────────────────────────────────────────────╯

# negative days are refused
try(adp(c(10, -2)))
#> Error : adp: `days` must be non-negative
```
