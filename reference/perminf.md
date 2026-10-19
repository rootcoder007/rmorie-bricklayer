# Permutation inference for a policy's adoption

Re-assigns the adoption dates across clusters (all the distinct
assignments when there are few, random ones otherwise), re-estimates the
difference in differences each time, and gives the share of assignments
with an effect at least as large; for several outcomes, also the
Westfall-Young stepdown p-values that hold the family-wise error rate.

## Usage

``` r
perminf(
  data,
  unit,
  time,
  y,
  ftreat,
  cl = NULL,
  stat = c("t", "estimate"),
  reps = 999L,
  seed = NULL,
  ties = c("count", "strict")
)
```

## Arguments

- data:

  A data frame, one row per unit and period.

- unit, time:

  Column names: the unit and the period (numeric).

- y:

  One outcome column, or several.

- ftreat:

  Column name of the period a unit is first treated (`NA`, 0 or `Inf`
  for a unit never treated). Treatment is taken as staying on.

- cl:

  Column name of the clusters (default the unit), or two column names
  for two-way clustering (Cameron, Gelbach and Miller 2011): \\V_a +
  V_b - V\_{ab}\\, each term with the small-sample factor of the
  dimension with fewer clusters, and t on its \\G - 1\\ degrees of
  freedom. A composite cluster (district by month, say) is one column
  made with [`interaction()`](https://rdrr.io/r/base/interaction.html).

- stat:

  `"t"` (default) or `"estimate"`.

- reps:

  The number of random assignments (default 999).

- seed:

  Optional seed.

- ties:

  `"count"` (default): an assignment whose statistic equals the observed
  one counts (the observed assignment is among those enumerated, so the
  exact p-value is at least \\1/N\\); `"strict"`: only larger ones
  count.

## Value

A data frame of class `rmbl_permutation`, one row per outcome:
`outcome`, `estimate`, `statistic`, `p_value`, `pstpdn`, `assignments`,
`exact`; attribute `null` (the matrix of permuted statistics).

## Details

The adoption period of each cluster (for example a judicial district's
stage of a reform) is shuffled among the clusters, keeping the number of
clusters adopting at each date, and
[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md)'s
estimate (`statistic = "estimate"`) or t statistic (`"t"`, the default)
is recomputed. With \\b\\ of \\R\\ random assignments at least as
extreme as observed, \\p = (b + 1)/(R + 1)\\; when every distinct
assignment is enumerated (their number is at most `reps`), \\p\\ is the
exact share. The test is Fisher's: it is valid in any sample when
adoption dates were assigned at random across clusters.

For several outcomes, the same assignments give
[`stpdnpv`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stpdnpv.md).

A placebo date is the same analysis with `ftreat` moved earlier, on the
periods before the real adoption.

## References

Fisher RA (1935). The Design of Experiments. Oliver and Boyd, Edinburgh.

Applied with the four stages of a reform permuted across districts:
Acosta, Mejia and Zorro Medina (2023), see
[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md).

## See also

[`stpdnpv`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stpdnpv.md).

## Examples

``` r
p <- polex()
perminf(p, "district", "month", c("crmrate", "arrrate"),
                      "refmonth",
                      cl = "region", reps = 199, seed = 3)
#>   outcome   estimate  statistic    p_value     pstpdn assignments exact
#> 1 crmrate -3.2316395 -19.516735 0.04166667 0.04166667          24  TRUE
#> 2 arrrate -0.2136969  -3.638159 0.12500000 0.12500000          24  TRUE
```
