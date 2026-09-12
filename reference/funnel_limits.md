# Funnel-plot control limits

The limits within which an area's ratio would fall, given its expected
count, if it were no different from the overall experience. A funnel
plot is the alternative to a league table: it shows directly that a
small area's ratio can wander far from one without meaning anything.

## Usage

``` r
funnel_limits(expected, target = 1, levels = c(0.95, 0.998))
```

## Arguments

- expected:

  Expected counts to compute limits at.

- target:

  The ratio the limits are centred on. One is the overall experience.

- levels:

  Two-sided coverage levels for the limit pairs.

## Value

A data frame of `expected`, `level`, `lower` and `upper` on the ratio
scale.

## Details

The limits are exact Poisson quantiles divided by the expected count, so
they are the discrete counterpart of the usual normal funnel and stay
correct at the small expected counts where the normal version goes below
zero.

## References

*Advanced Statistics in Criminology and Criminal Justice* discusses the
funnel plot as the display of the relationship between an estimate and
the sample size behind it.

Lawson, A. B. *Using R for Bayesian Spatial and Spatio-Temporal Health
Modeling*. Chapman and Hall/CRC, on the Poisson counts these limits are
built from.

## See also

[`sir()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sir.md),
[`eb_rates()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/eb_rates.md)

## Examples

``` r
# The funnel narrows as the expected count grows, which is the whole
# point: a ratio of 2 means nothing at an expected count of 2 and a
# great deal at an expected count of 200.
funnel_limits(c(2, 20, 200))
#>   expected level lower upper
#> 1        2 0.950 0.000 2.500
#> 2       20 0.950 0.600 1.450
#> 3      200 0.950 0.865 1.140
#> 4        2 0.998 0.000 4.000
#> 5       20 0.998 0.400 1.750
#> 6      200 0.998 0.790 1.225
```
