# Average length of stay

The mean number of person-days served per person: the FLOW side of the
same person-days. Use it to say how long a typical admission lasts, and
together with
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md)
to tell whether a change in the population held came from more people or
from longer stays. For the full distribution of stays (median, spread,
interval) use
[`stay_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stay_summary.md).

## Usage

``` r
alos(days, n)
```

## Arguments

- days:

  Numeric vector of person-days served during the period, non-negative,
  no `NA` or `Inf`; the vector is summed.

- n:

  Numeric scalar, the number of people; must be positive. A vector of
  several values is refused. For an unbiased average this should be the
  people both admitted AND released within the period, because anyone
  still held has an unfinished stay.

## Value

A numeric scalar: days per person, \\\sum X_i / n\\.

## Details

Lakner's \\\bar{X}\_t = \sum X_i / N'\\ (1976, p.16), with a caveat
worth repeating (p.16-17): the period must be longer than the longest
stay people actually serve, or the average is biased DOWNWARD, since the
longest stays are the ones that fail to finish inside the window. For
short-stay facilities a year is comfortable; for long sentences it is
not, and the period has to be set from the records.

Errors when `days` is not numeric, is empty, or has `NA`, `Inf` or
negative values, and when `n` is not a single positive number.

## References

Lakner, E. (1976) *A Manual of Statistical Sampling Methods for
Corrections Planners*. University of Illinois at Urbana-Champaign.

## See also

[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md)

## Examples

``` r
# Lakner (p.17): 2,700 inmates admitted and released served 12,150
# detention days between them.
alos(12150, 2700)
#> [1] 4.5

# from one value per released person
stays <- c(2, 5, 1, 30, 4, 7)
alos(stays, length(stays))
#> [1] 8.166667

# zero people cannot have an average stay
try(alos(12150, 0))
#> Error : `n` must be positive
```
