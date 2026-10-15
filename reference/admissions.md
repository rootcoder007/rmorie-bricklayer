# Admissions implied by a population and a length of stay

Works out how many admissions a given average daily population and
average length of stay imply over a period. Published statistics often
give the population held and the average stay but not the number
admitted (or the other way round); this recovers the missing quantity
from the identity that links all three.

## Usage

``` r
admissions(adp, alos, t = 365)
```

## Arguments

- adp:

  Numeric scalar, the average daily population (people held on an
  average day); must be positive.

- alos:

  Numeric scalar, the average length of stay in days; must be positive.

- t:

  Numeric scalar, the length of the period in days; must be positive.
  Default `365`.

## Value

A numeric scalar: the implied number of admissions over the period,
\\\mathrm{adp} \times t / \mathrm{alos}\\. It is not rounded.

## Details

Rearranging the identity \\\bar{X}\_{hc} = N_a \bar{X}\_t / t\\ (Lakner
1976, p.18-20) for \\N_a\\. Useful when two of the three quantities are
published and the third is not. The identity holds exactly only in a
steady state (admissions and stays roughly constant across the period);
with a population that is growing or shrinking quickly the result is an
approximation.

Errors when any argument is not numeric, is `NA` or `Inf`, is not
positive, or has more than one value.

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

# a 90-day quarter with 40 held on average and a 12-day average stay
admissions(40, 12, t = 90)
#> [1] 300

# an average stay of zero is refused
try(admissions(25, 0))
#> Error : `alos` must be positive
```
