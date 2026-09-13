# Admissions implied by a population and a length of stay

Admissions implied by a population and a length of stay

## Usage

``` r
admissions(adp, alos, t = 365)
```

## Arguments

- adp:

  Average daily population.

- alos:

  Average length of stay in days.

- t:

  Length of the period in days. Default 365.

## Value

The implied number of admissions.

## Details

Rearranging the identity \\\bar{X}\_{hc} = N_a \bar{X}\_t / t\\ (Lakner
1976, p.18-20) for \\N_a\\. Useful when two of the three quantities are
published and the third is not.

## See also

[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md),
[`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md)

## Examples

``` r
# Lakner (p.20) runs this the other way: t = 365, an average daily
# population of 25 and 1,750 admissions imply a stay of 5.2 days.
alos_implied <- 25 * 365 / 1750
round(alos_implied, 1)
#> [1] 5.2

# and back again
admissions(25, alos_implied)
#> [1] 1750
```
