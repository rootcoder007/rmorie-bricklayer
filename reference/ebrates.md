# Empirical Bayes rates, shrunk toward the overall experience

A small area's rate is mostly noise, so ranking areas by their raw
ratios puts the smallest areas at both ends of the table by
construction. This function borrows strength across areas: each area's
ratio of observed to expected is pulled toward the overall ratio by an
amount that depends on how little information the area carries. Use the
shrunk estimates for maps and rankings; use
[`stdinc`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdinc.md)
for each area's own evidence.

## Usage

``` r
ebrates(obs, expd, area = NULL)
```

## Arguments

- obs:

  Numeric vector of observed counts (non-negative, no `NA`).

- expd:

  Numeric vector of expected counts (positive), the same length, for
  example from
  [`expcnts`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expcnts.md).

- area:

  Optional vector of area labels, added as the first column. Default
  `NULL`.

## Value

A data frame with one row per area: `area` (when given), `observed`,
`expected`, the raw ratio `sir`, the shrunk estimate `eb`, the
`shrinkage` applied (zero means untouched, one means replaced by the
overall rate), and the fitted prior's `nu` (shape) and `alpha` (rate),
the same on every row.

## Details

The area relative risks \\\theta_a\\ are taken to come from a gamma
prior with shape \\\nu\\ and rate \\\alpha\\. Its mean is the overall
ratio \\m = \sum O_a / \sum E_a\\, and its variance is estimated by the
method of moments, \$\$s^2 = \frac{\sum_a E_a (\theta_a - m)^2}{\sum_a
E_a} - \frac{m}{\bar E},\$\$ with \\\theta_a = O_a / E_a\\ and \\\bar
E\\ the mean expected count; the subtracted term is the spread that
Poisson sampling alone would produce. Then \\\alpha = m / s^2\\, \\\nu =
m^2 / s^2\\, and the posterior mean \\(O_a + \nu)/(E_a + \alpha)\\ is
reported, with shrinkage \\\alpha / (E_a + \alpha)\\. Where the expected
count is large the data dominate and the estimate barely moves; where it
is small the prior does, which is the intended behaviour and not a
defect.

When the between-area variance estimate comes out at or below zero there
is no evidence of any real variation between areas, and every estimate
collapses to the overall rate. That is reported through `shrinkage` (all
ones) and `NA` prior parameters rather than hidden.

Errors: lengths that differ; missing, negative or infinite counts;
missing, infinite or non-positive expected counts; fewer than two areas.

## References

Clayton, D. and Kaldor, J. (1987). Empirical Bayes estimates of
age-standardized relative risks for use in disease mapping. *Biometrics*
43(3), 671-681.

Lawson, A. B. *Using R for Bayesian Spatial and Spatio-Temporal Health
Modeling*. Chapman and Hall/CRC, which cites Clayton and Kaldor as the
empirical-Bayes approximation in the development of Bayesian disease
mapping.

## See also

[`stdinc`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdinc.md),
[`fnllim`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fnllim.md)

## Examples

``` r
# Three areas, one of them tiny. The tiny area's raw ratio is
# extreme; its shrunk one is not.
ebrates(obs = c(30, 45, 2), expd = c(25, 50, 0.5),
         area = c("North", "South", "Tiny"))
#> ╭── Empirical Bayes rates ────────────────────────────────────────────────╮
#> │   Areas               3                                                 │
#> │   Overall ratio       1.02                                              │
#> │   Prior shape (nu)    26.98                                             │
#> │   Prior rate (alpha)  26.46                                             │
#> │   Method              gamma-Poisson, moments (Clayton and Kaldor 1987)  │
#> │                                                                         │
#> │   area   observed  expected    sir     eb  shrinkage                    │
#> │   -----  --------  --------  -----  -----  ---------                    │
#> │   North        30     25.00  1.200  1.107     0.5141                    │
#> │   South        45     50.00  0.900  0.941     0.3460                    │
#> │   Tiny          2      0.50  4.000  1.075     0.9815                    │
#> │                                                                         │
#> │   Each raw ratio (sir) is pulled toward the overall ratio; shrinkage is │
#> │   the share of the pull (0 untouched, 1 replaced), largest for areas    │
#> │   with small expected counts. Use eb for maps and rankings, stdinc()    │
#> │   for each area's own evidence.                                         │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# no variation beyond chance: every estimate is the overall ratio
ebrates(c(10, 11, 9), c(10, 10, 10))
#> ╭── Empirical Bayes rates ────────────────────────────────────────────────╮
#> │   Areas               3                                                 │
#> │   Overall ratio       1                                                 │
#> │   Prior shape (nu)    none                                              │
#> │   Prior rate (alpha)  none                                              │
#> │   Method              gamma-Poisson, moments (Clayton and Kaldor 1987)  │
#> │                                                                         │
#> │   observed  expected    sir  eb  shrinkage                              │
#> │   --------  --------  -----  --  ---------                              │
#> │         10        10  1.000   1          1                              │
#> │         11        10  1.100   1          1                              │
#> │          9        10  0.900   1          1                              │
#> │                                                                         │
#> │   The areas vary no more than chance would make them, so every estimate │
#> │   is the overall ratio (shrinkage 1).                                   │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# one area has nothing to borrow from
try(ebrates(5, 4))
#> Error : shrinkage borrows strength across areas, so it needs at least two
```
