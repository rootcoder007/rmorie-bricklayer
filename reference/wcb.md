# The wild cluster bootstrap for a difference in differences with few clusters

A p-value and confidence interval for the treatment effect of
[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md)
that stay accurate when there are few clusters (a policy assigned to a
handful of districts or states), where the cluster-robust t test
over-rejects.

## Usage

``` r
wcb(
  data,
  unit,
  time,
  y,
  trtd,
  covs = NULL,
  cl = NULL,
  reps = 9999L,
  wtype = c("rademacher", "webb"),
  seed = NULL,
  ties = c("count", "strict"),
  conflvl = 0.95
)
```

## Arguments

- data:

  A data frame, one row per unit and period.

- unit, time, y:

  Column names: the unit, the period (numeric, for example a year or a
  month index) and the outcome.

- trtd:

  Column name of the treatment indicator (0 or 1).

- covs:

  Optional column names of time-varying controls.

- cl:

  Column name of the clusters (default the unit), or two column names
  for two-way clustering (Cameron, Gelbach and Miller 2011): \\V_a +
  V_b - V\_{ab}\\, each term with the small-sample factor of the
  dimension with fewer clusters, and t on its \\G - 1\\ degrees of
  freedom. A composite cluster (district by month, say) is one column
  made with [`interaction()`](https://rdrr.io/r/base/interaction.html).

- reps:

  Bootstrap replications (default 9999).

- wtype:

  `"rademacher"` (default) or `"webb"`.

- seed:

  Optional seed.

- ties:

  `"count"` (default) or `"strict"`: whether a bootstrap \\\|t^\*\|\\
  equal to \\\|t\|\\ counts against the null.

- conflvl:

  Confidence level (default 0.95).

## Value

A data frame of class `rmbl_wild`: `estimate`, `t`, `p_value`, `lower`,
`upper`, `clusters`, `draws`, `enumerated`.

## Details

This is the restricted wild cluster bootstrap (WCR) of Cameron, Gelbach
and Miller (2008). The model is fitted with the null \\\beta = \beta_0\\
imposed; each bootstrap outcome is the restricted fit plus its residuals
multiplied, cluster by cluster, by a random sign (Rademacher) or by one
of Webb's six values; the cluster-robust t statistic is recomputed each
time. The p-value is the share of bootstrap \\\|t^\*\|\\ at least
\\\|t\|\\. With `ties = "count"` (the default) a draw that equals
\\\|t\|\\ counts: the sign patterns that reproduce the data are among
the draws, as the observed assignment is in a permutation test, and the
test is exact at its level. With `"strict"` only draws above \\\|t\|\\
count, as `fwildclusterboot` does; under full enumeration this gives a
smaller p-value (the two sign patterns that reproduce \\\|t\|\\ are left
out). With Rademacher weights and \\2^G \le\\ `reps` every sign pattern
is enumerated (as `fwildclusterboot` does); with very few clusters
(under about 12) Webb's weights, which have more distinct values, are
better. The interval collects the \\\beta_0\\ not rejected at \\1 -\\
`conflvl`, found by bisection with the same draws; it is unbounded when
no value can be rejected (with Rademacher weights and \\G\\ clusters the
smallest attainable p-value is \\2/2^G\\, so four clusters can never
reject at 5\\ the method).

## References

Cameron AC, Gelbach JB, Miller DL (2008). Bootstrap-based improvements
for inference with clustered errors. Review of Economics and Statistics
90(3):414-427.
[doi:10.1162/rest.90.3.414](https://doi.org/10.1162/rest.90.3.414)

Webb MD (2023). Reworking wild bootstrap-based inference for clustered
errors. Canadian Journal of Economics 56(3):839-858.
[doi:10.1111/caje.12661](https://doi.org/10.1111/caje.12661)

Roodman D, Nielsen MO, MacKinnon JG, Webb MD (2019). Fast and wild:
bootstrap inference in Stata using boottest. The Stata Journal
19(1):4-60.
[doi:10.1177/1536867X19830877](https://doi.org/10.1177/1536867X19830877)

## Examples

``` r
p <- polex()
# the reform was assigned to four regions: four clusters
wcb(p, "district", "month", "crmrate", "reformed",
                       cl = "region", wtype = "webb", reps = 299,
                       seed = 1)
#>   estimate         t p_value     lower     upper clusters draws enumerated
#> 1 -3.23164 -19.51674       0 -4.071902 -1.967923        4   299      FALSE
```
