# How strong would an unmeasured confounder have to be

The E-value of VanderWeele and Ding (2017): the minimum strength of
association, on the risk-ratio scale, that an unmeasured confounder
would need with BOTH the exposure and the outcome to explain away an
observed risk ratio.

## Usage

``` r
evalue_rr(rr, lo = NULL, hi = NULL, true = 1)
```

## Arguments

- rr:

  Observed risk ratio, greater than 0. Protective effects (below 1) are
  inverted first, as the measure is symmetric.

- lo, hi:

  Optional confidence limits on the same scale. The limit nearer the
  null is the one used.

- true:

  The value to move the estimate to. Defaults to 1, the null.

## Value

A named numeric vector: `evalue_point` and, when limits are given,
`evalue_limit`.

## Details

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

## References

VanderWeele, T. J., and Ding, P. (2017). Sensitivity Analysis in
Observational Research: Introducing the E-Value. *Annals of Internal
Medicine* 167(4), 268-274.
[doi:10.7326/M16-2607](https://doi.org/10.7326/M16-2607)

## See also

[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md)
for controls that use the data, where this uses none.

## Examples

``` r
# a risk ratio of 2 needs a confounder associated by 3.41 with both
evalue_rr(2)
#> evalue_point 
#>     3.414214 

# a protective effect is inverted, so 0.5 gives the same answer
evalue_rr(0.5)
#> evalue_point 
#>     3.414214 

# an interval that already includes the null needs nothing
evalue_rr(2, lo = 0.9, hi = 4.4)
#> evalue_point evalue_limit 
#>     3.414214     1.000000 

# and a strong result with a limit well above the null is harder to
# explain away
evalue_rr(3, lo = 2.1, hi = 4.3)
#> evalue_point evalue_limit 
#>     5.449490     3.619868 
```
