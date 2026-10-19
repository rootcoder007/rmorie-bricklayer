# Power and minimum detectable effect of a difference-in-differences design

Simulates the design on real untreated data: assigns adoption at random
to units (or clusters) as the study would, adds an effect of known size,
estimates
[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md),
and counts rejections; so the serial correlation and the clustering of
the real data are carried, as formula-based power calculations do not.

## Usage

``` r
plnpwr(
  data,
  unit,
  time,
  y,
  ntrt,
  adopt,
  eff = NULL,
  cl = NULL,
  reps = 200L,
  alpha = 0.05,
  power = 0.8,
  seed = NULL
)
```

## Arguments

- data:

  A data frame, one row per unit and period.

- unit, time, y:

  Column names: the unit, the period (numeric, for example a year or a
  month index) and the outcome.

- ntrt:

  Units (or clusters) to treat in each replication.

- adopt:

  Adoption periods to draw from.

- eff:

  Effect sizes to try (default a grid from 0 to two standard deviations
  of the outcome).

- cl:

  Column name of the clusters (default the unit), or two column names
  for two-way clustering (Cameron, Gelbach and Miller 2011): \\V_a +
  V_b - V\_{ab}\\, each term with the small-sample factor of the
  dimension with fewer clusters, and t on its \\G - 1\\ degrees of
  freedom. A composite cluster (district by month, say) is one column
  made with [`interaction()`](https://rdrr.io/r/base/interaction.html).

- reps:

  Replications per effect size (default 200).

- alpha:

  Test level (default 0.05).

- power:

  For the minimum detectable effect (default 0.8).

- seed:

  Optional seed.

## Value

A data frame of class `rmbl_power`: `effect`, `power`; attributes `mde`
and `size` (the rejection rate at effect 0).

## Details

In each replication, `ntrt` units (or clusters, with `cl`) are drawn at
random and given adoption dates drawn from `adopt`; `effect` is added to
their outcomes from adoption on; the cluster-robust t test of
[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md)
at level `alpha` is counted as a rejection. With `effect = 0` the
rejection rate is the test's actual size on these data, which should be
near `alpha`: a larger one means the errors are understated (too few
clusters, say), and the power figures are then optimistic too. The
minimum detectable effect is where the power curve crosses `power`, by
linear interpolation (Burlig, Preonas and Woerman 2020).

## References

Burlig F, Preonas L, Woerman M (2020). Panel data and experimental
design. Journal of Development Economics 144:102458.
[doi:10.1016/j.jdeveco.2020.102458](https://doi.org/10.1016/j.jdeveco.2020.102458)

## Examples

``` r
p <- polex()
pre <- p[p$month <= 12, ]
pw <- plnpwr(pre, "district", "month", "crmrate", ntrt = 10, adopt = 7:10,
                  eff = c(0, 1, 2, 3), reps = 30, seed = 1)
pw
#>  effect  power
#>       0 0.0333
#>       1 0.9333
#>       2 1.0000
#>       3 1.0000
#> Size (rejections with no effect): 0.033 at alpha 0.050
#> Minimum detectable effect at this power: 0.8519
plot(pw)
```
