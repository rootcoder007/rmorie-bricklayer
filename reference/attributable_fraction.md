# Population attributable fraction

Levin's formula (Rothman, Greenland and Lash 2008, chapter 5): \$\$PAF =
p (RR - 1) / (1 + p (RR - 1)),\$\$ the fraction of cases that would be
avoided if the exposure were removed.

## Usage

``` r
attributable_fraction(rr, exposure_prevalence)
```

## Arguments

- rr:

  Relative risk at the observed exposure level.

- exposure_prevalence:

  Proportion of the population exposed, in `[0, 1]`.

## Value

A number in `[0, 1)` for `rr >= 1`.

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
