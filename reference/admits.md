# Admissions implied by a population and a length of stay

Works out how many admissions a given average daily population and
average length of stay imply over a period. Published statistics often
give the population held and the average stay but not the number
admitted (or the other way round); this recovers the missing quantity
from the identity that links all three.

## Usage

``` r
admits(adp, alos, t = 365)
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
\\\mathrm{adp} \times t / \mathrm{alos}\\. It is not rounded. It has
class `c("rmbl_admits", "rmbl_measure", "numeric")` and an attribute
`"lakner"` (`adp`, `alos` and `t`), so it prints as a box with its
inputs, formula and caveats; arithmetic,
[`round()`](https://rdrr.io/r/base/Round.html),
[`sum()`](https://rdrr.io/r/base/sum.html),
[`mean()`](https://rdrr.io/r/base/mean.html), `[`,
[`c()`](https://rdrr.io/r/base/c.html) and
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) give a plain
number.

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
[`stkflow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stkflow.md)

## Examples

``` r
# Lakner (p.20) runs this the other way: t = 365, an average daily
# population of 25 and 1,750 admissions imply a stay of 5.2 days.
alosimplied <- 25 * 365 / 1750
round(alosimplied, 1)
#> [1] 5.2

# and back again
admits(25, alosimplied)
#> ╭── Admissions implied by stock and stay ─────────────────────────────────────╮
#> │   Admissions                1,750 over the period                           │
#> │   Average daily population  25                                              │
#> │   Average stay              5.214 days                                      │
#> │   Period                    365 days                                        │
#> │   Formula                   admits = adp x t / alos = 25 x 365 / 5.214      │
#> │                                                                             │
#> │   25 held on an average day, staying 5.214 days each, imply 1,750           │
#> │   admissions over 365 days.                                                 │
#> │                                                                             │
#> │   Lakner (1976, p.18-20): adp = admissions x alos / t is exact only in      │
#> │   a steady state; with a population growing or shrinking quickly the        │
#> │   result is an approximation. It is not rounded.                            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# a 90-day quarter with 40 held on average and a 12-day average stay
admits(40, 12, t = 90)
#> ╭── Admissions implied by stock and stay ─────────────────────────────────────╮
#> │   Admissions                300 over the period                             │
#> │   Average daily population  40                                              │
#> │   Average stay              12 days                                         │
#> │   Period                    90 days                                         │
#> │   Formula                   admits = adp x t / alos = 40 x 90 / 12          │
#> │                                                                             │
#> │   40 held on an average day, staying 12 days each, imply 300 admissions     │
#> │   over 90 days.                                                             │
#> │                                                                             │
#> │   Lakner (1976, p.18-20): adp = admissions x alos / t is exact only in      │
#> │   a steady state; with a population growing or shrinking quickly the        │
#> │   result is an approximation. It is not rounded.                            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# an average stay of zero is refused
try(admits(25, 0))
#> Error : `alos` must be positive
```
