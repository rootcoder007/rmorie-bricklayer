# Population attributable fraction

The share of all cases in a population that is due to an exposure: the
fraction that would not occur if the exposure were removed and nothing
else changed. It combines how strongly the exposure raises risk (the
relative risk) with how common it is (the prevalence); multiplied by the
number of cases it gives the attributable cases, as
[`pollution_burden`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pollution_burden.md)
does.

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

A single number, the attributable fraction: in `[0, 1)` for `rr >= 1`,
negative for a protective exposure. When the limits were given it
carries an attribute `ci`, a named numeric vector (`lower`, `upper`).

## Details

Levin's formula (Levin 1953; Rothman, Greenland and Lash 2008, chapter
5): \$\$PAF = p (RR - 1) / (1 + p (RR - 1)),\$\$ with \\p\\ the
proportion exposed. With everyone exposed it is \\1 - 1/RR\\. It assumes
the relative risk is causal and unconfounded and that removing the
exposure changes nothing else. A relative risk below 1 gives a negative
fraction (the exposure protects).

When both confidence limits of the RR are given, the fraction's limits
are the formula applied to them: the formula increases with the RR, so
the interval of the fraction is the image of the interval of the risk.
Refusals: an `rr` or limit that is not a single finite positive number
(logical values included), a prevalence outside \\\[0, 1\]\\, only one
of the two limits, or limits that do not enclose `rr`.

## References

Rothman, K. J., Greenland, S. and Lash, T. L. (2008). Modern
Epidemiology, 3rd ed., chapter 5. Levin, M. L. (1953). The occurrence of
lung cancer in man. Acta Unio Internationalis Contra Cancrum 9, 531-541.

## See also

[`crf_pm25`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crf_pm25.md)
for a relative risk from a concentration,
[`pollution_burden`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pollution_burden.md)
for the attributable cases.

## Examples

``` r
attributable_fraction(1.5, 0.4)
#> [1] 0.1666667
attributable_fraction(2, 1)      # everyone exposed: 1 - 1/RR
#> [1] 0.5

# With the confidence limits of the relative risk.
paf <- attributable_fraction(1.08, 1, rr_lower = 1.06, rr_upper = 1.09)
attr(paf, "ci")
#>      lower      upper 
#> 0.05660377 0.08256881 

# A protective exposure gives a negative fraction.
attributable_fraction(0.8, 0.5)
#> [1] -0.1111111

# A prevalence above 1 is refused.
try(attributable_fraction(1.5, 40))
#> Error : exposure_prevalence must be in [0,1]; got 40
```
