# Empirical Bayes rates, shrunk toward the overall experience

A small area's rate is mostly noise, so ranking areas by their raw rates
puts the smallest areas at both ends of the table by construction. This
borrows strength across areas: each rate is pulled toward the overall
one by an amount that depends on how little information the area
carries.

## Usage

``` r
eb_rates(observed, expected, area = NULL)
```

## Arguments

- observed:

  Observed counts.

- expected:

  Expected counts.

- area:

  Optional labels.

## Value

A data frame with the raw `sir`, the shrunk `eb`, the `shrinkage`
applied (zero means untouched, one means replaced by the overall rate),
and the fitted prior's `nu` and `alpha`.

## Details

The Clayton-Kaldor construction: the area-specific relative risks are
taken to come from a gamma prior, whose two parameters are estimated
from the observed and expected counts by the method of moments, and the
posterior mean `(O + nu) / (E + alpha)` is reported. Where the expected
count is large the data dominate and the estimate barely moves; where it
is small the prior does, which is the intended behaviour and not a
defect.

When the between-area variance estimate comes out at or below zero there
is no evidence of any real variation between areas, and every estimate
collapses to the overall rate. That is reported through `shrinkage`
rather than hidden.

## References

Clayton, D. and Kaldor, J. (1987). Empirical Bayes estimates of
age-standardized relative risks for use in disease mapping. *Biometrics*
43(3), 671-681.

Lawson, A. B. *Using R for Bayesian Spatial and Spatio-Temporal Health
Modeling*. Chapman and Hall/CRC, which cites Clayton and Kaldor as the
empirical-Bayes approximation in the development of Bayesian disease
mapping.

## See also

[`sir()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sir.md),
[`funnel_limits()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/funnel_limits.md)

## Examples

``` r
# Three areas, one of them tiny. The tiny area's raw ratio is
# extreme; its shrunk one is not.
eb_rates(observed = c(30, 45, 2), expected = c(25, 50, 0.5),
         area = c("North", "South", "Tiny"))
#>    area observed expected sir        eb shrinkage       nu    alpha
#> 1 North       30     25.0 1.2 1.1073869 0.5141392 26.98066 26.45506
#> 2 South       45     50.0 0.9 0.9414767 0.3460211 26.98066 26.45506
#> 3  Tiny        2      0.5 4.0 1.0751472 0.9814506 26.98066 26.45506
```
