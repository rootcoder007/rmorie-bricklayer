# Average daily population

The mean number of person-days served per day over a period: a STOCK,
answering how many people are held at one time.

## Usage

``` r
adp(days, t = 365)
```

## Arguments

- days:

  Person-days served during the period. A vector is summed, so one
  element per person is the usual input.

- t:

  Length of the period in days. Default 365.

## Value

A single number: person-days per day.

## Details

This is Lakner's \\\bar{X}\_{hc} = \sum X_i / t\\ (1976, p.15). The
denominator is TIME, which is what makes it a stock. Compare
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md),
whose denominator is people.

## References

Lakner, E. (1976) *A Manual of Statistical Sampling Methods for
Corrections Planners*. University of Illinois at Urbana-Champaign.

## See also

[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md),
[`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md),
[`adp_from_counts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp_from_counts.md)

## Examples

``` r
# Lakner's own worked example (p.15): 3,000 inmates served 13,500
# detention days in a year.
adp(13500)
#> [1] 36.9863

# per-person days give the same total
adp(c(10, 20, 30), t = 30)
#> [1] 2
```
