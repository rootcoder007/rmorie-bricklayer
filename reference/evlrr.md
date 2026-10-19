# How strong would an unmeasured confounder have to be

The E-value of VanderWeele and Ding (2017): the minimum strength of
association, on the risk-ratio scale, that an unmeasured confounder
would need with BOTH the exposure and the outcome to explain away an
observed risk ratio.

It answers the question a covariate list cannot: not whether the
analysis adjusted for the right things, but how much unmeasured
confounding it would take to move the result to nothing. An E-value of
1.2 says very little would be needed; an E-value of 5 says a confounder
five times more common in the exposed group AND five times more
associated with the outcome would have to have gone unnoticed.

The E-value for the confidence limit is the one to report alongside it:
a large point-estimate E-value with a limit E-value of 1 means the
interval already includes no effect, and no confounding is needed at
all.

## Usage

``` r
evlrr(rr, lo = NULL, hi = NULL, true = 1)
```

## Arguments

- rr:

  Observed risk ratio, greater than 0. Protective effects (below 1) are
  inverted first, as the measure is symmetric.

- lo, hi:

  Optional confidence limits on the same scale. The limit nearer the
  null is the one used.

- true:

  Number, default 1 (the null): the value to move the estimate to. A
  value other than 1 asks how much confounding would move the estimate
  to `true` instead of to no effect.

## Value

A named numeric vector: `evlpoint` and, when limits are given,
`evllimit`.

## Details

For a risk ratio \\RR \ge 1\\ (after dividing by `true`, and inverting a
ratio below 1), \$\$E = RR + \sqrt{RR (RR - 1)}.\$\$ For the interval,
the limit nearer the null is used: the lower limit when it is above 1,
else the reciprocal of the upper limit when it is below 1; when the
interval contains 1 the limit E-value is 1. The formula is for risk
ratios; VanderWeele and Ding (2017) give approximate conversions for
odds ratios with a common outcome and for hazard ratios, which this
function does not apply. Only the first element of each argument is
used. Errors: a ratio or limit that is not finite and positive.

## References

VanderWeele, T. J., and Ding, P. (2017). Sensitivity Analysis in
Observational Research: Introducing the E-Value. *Annals of Internal
Medicine* 167(4), 268-274.
[doi:10.7326/M16-2607](https://doi.org/10.7326/M16-2607)

## See also

[`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md)
for controls that use the data, where this uses none.

## Examples

``` r
# a risk ratio of 2 needs a confounder associated by 3.41 with both
evlrr(2)
#> evlpoint 
#> 3.414214 

# a protective effect is inverted, so 0.5 gives the same answer
evlrr(0.5)
#> evlpoint 
#> 3.414214 

# an interval that already includes the null needs nothing
evlrr(2, lo = 0.9, hi = 4.4)
#> evlpoint evllimit 
#> 3.414214 1.000000 

# and a strong result with a limit well above the null is harder to
# explain away
evlrr(3, lo = 2.1, hi = 4.3)
#> evlpoint evllimit 
#> 5.449490 3.619868 

# how much confounding would bring a risk ratio of 3 down to 1.5
evlrr(3, true = 1.5)
#> evlpoint 
#> 3.414214 

try(evlrr(-2))
#> Error : risk ratios must be finite and positive
```
