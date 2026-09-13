# Average length of stay

The mean number of person-days served per person: the FLOW side of the
same person-days.

## Usage

``` r
alos(days, n)
```

## Arguments

- days:

  Person-days served during the period, summed.

- n:

  Number of people. For an unbiased average this should be the people
  both admitted AND released within the period, because anyone still
  held has an unfinished stay.

## Value

A single number: days per person.

## Details

Lakner's \\\bar{X}\_t = \sum X_i / N'\\ (1976, p.16), with a caveat
worth repeating (p.16-17): the period must be longer than the longest
stay people actually serve, or the average is biased DOWNWARD, since the
longest stays are the ones that fail to finish inside the window. For
short-stay facilities a year is comfortable; for long sentences it is
not, and the period has to be set from the records.

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
```
