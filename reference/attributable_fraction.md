# Population attributable fraction

Levin's formula (Rothman, Greenland and Lash 2008, chapter 5): \$\$PAF =
p (RR - 1) / (1 + p (RR - 1)),\$\$ the fraction of cases that would be
avoided if the exposure were removed.

## Usage

``` r
attributable_fraction(
  rr,
  exposure_prevalence,
  rr_lower = NULL,
  rr_upper = NULL
)
```

## Arguments

- rr:

  Relative risk among the exposed, a single finite positive number. A
  relative risk below 1 gives a negative fraction (a protective
  exposure); 0, negative, infinite and missing values are errors.

- exposure_prevalence:

  Proportion of the population exposed, in `[0, 1]`.

- rr_lower, rr_upper:

  Optional confidence limits of `rr`; when both are given the fraction
  carries the limits that the same formula gives at them (Levin's
  formula is monotone in the relative risk, so the interval of the
  fraction is the image of the interval of the risk).

## Value

A number in `[0, 1)` for `rr >= 1`, with an attribute `ci` (`lower`,
`upper`) when the limits were given.

## References

Rothman, K. J., Greenland, S. and Lash, T. L. (2008). Modern
Epidemiology, 3rd ed., chapter 5. Levin, M. L. (1953). The occurrence of
lung cancer in man. Acta Unio Internationalis Contra Cancrum 9, 531-541.

## Examples

``` r
attributable_fraction(1.5, 0.4)
#> [1] 0.1666667
attributable_fraction(2, 1)      # everyone exposed: 1 - 1/RR
#> [1] 0.5
```
