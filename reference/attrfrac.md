# Population attributable fraction

The share of all cases in a population that is due to an exposure: the
fraction that would not occur if the exposure were removed and nothing
else changed. It combines how strongly the exposure raises risk (the
relative risk) with how common it is (the prevalence); multiplied by the
number of cases it gives the attributable cases, as
[`polbrdn`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md)
does.

## Usage

``` r
attrfrac(rr, expoprev, rrlo = NULL, rrup = NULL)
```

## Arguments

- rr:

  Relative risk among the exposed, a single finite positive number. A
  relative risk below 1 gives a negative fraction (a protective
  exposure); 0, negative, infinite and missing values are errors.

- expoprev:

  Proportion of the population exposed, in `[0, 1]`.

- rrlo, rrup:

  Optional confidence limits of `rr`; when both are given the fraction
  carries the limits that the same formula gives at them (Levin's
  formula is monotone in the relative risk, so the interval of the
  fraction is the image of the interval of the risk).

## Value

A single number, the attributable fraction: in `[0, 1)` for `rr >= 1`,
negative for a protective exposure. When the limits were given it
carries an attribute `ci`, a named numeric vector (`lower`, `upper`). It
has class `c("rmbl_attrfrac", "rmbl_measure", "numeric")`, so it prints
as a box with its inputs (kept in attribute `"lakner"`); arithmetic,
`[`, [`c()`](https://rdrr.io/r/base/c.html) and
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) give plain
numbers.

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

[`crfpm25`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crfpm25.md)
for a relative risk from a concentration,
[`polbrdn`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md)
for the attributable cases.

## Examples

``` r
attrfrac(1.5, 0.4)
#> ╭── Population attributable fraction ─────────────────────────────────────────╮
#> │   Attributable fraction  16.67%                                             │
#> │   Relative risk          1.5                                                │
#> │   Exposed                40.00%                                             │
#> │   Formula                Levin: p (RR - 1) / (1 + p (RR - 1))               │
#> │                                                                             │
#> │   About 16.7% of the cases in this population would not occur without the   │
#> │   exposure, if the relative risk is causal.                                 │
#> │                                                                             │
#> │   It holds only if the relative risk is causal and unconfounded, and        │
#> │   only for a population exposed as this one is (Rothman et al. 2008,        │
#> │   chapter 5).                                                               │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
attrfrac(2, 1)      # everyone exposed: 1 - 1/RR
#> ╭── Population attributable fraction ─────────────────────────────────────────╮
#> │   Attributable fraction  50.00%                                             │
#> │   Relative risk          2                                                  │
#> │   Exposed                100.00%                                            │
#> │   Formula                Levin: p (RR - 1) / (1 + p (RR - 1))               │
#> │                                                                             │
#> │   About 50.0% of the cases in this population would not occur without the   │
#> │   exposure, if the relative risk is causal.                                 │
#> │                                                                             │
#> │   It holds only if the relative risk is causal and unconfounded, and        │
#> │   only for a population exposed as this one is (Rothman et al. 2008,        │
#> │   chapter 5).                                                               │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# With the confidence limits of the relative risk.
paf <- attrfrac(1.08, 1, rrlo = 1.06, rrup = 1.09)
attr(paf, "ci")
#>      lower      upper 
#> 0.05660377 0.08256881 

# A protective exposure gives a negative fraction.
attrfrac(0.8, 0.5)
#> ╭── Population attributable fraction ─────────────────────────────────────────╮
#> │   Attributable fraction  -11.11%                                            │
#> │   Relative risk          0.8                                                │
#> │   Exposed                50.00%                                             │
#> │   Formula                Levin: p (RR - 1) / (1 + p (RR - 1))               │
#> │                                                                             │
#> │   The exposure is protective: without it there would be about 11.1% more    │
#> │   cases.                                                                    │
#> │                                                                             │
#> │   It holds only if the relative risk is causal and unconfounded, and        │
#> │   only for a population exposed as this one is (Rothman et al. 2008,        │
#> │   chapter 5).                                                               │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# A prevalence above 1 is refused.
try(attrfrac(1.5, 40))
#> Error : expoprev must be in [0,1]; got 40
```
