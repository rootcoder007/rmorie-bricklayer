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
  Fewer than ten clusters give a warning (CR1 errors are unreliable with
  so few;
  [`wcb`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wcb.md)
  is made for that case), and so does a cluster that changes within a
  unit.

- stat:

  `"t"` (default) or `"estimate"`.

- reps:

  The number of random assignments (default 999).

- seed:

  Optional seed for the random assignments, or NULL for none.

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
#> ╭── Permutation inference ───────────────────────────────────────────────╮
#> │   Method       randomisation inference on the adoption dates           │
#> │   Assignments  24                                                      │
#> │   Draws        every assignment (exact)                                │
#> │   Outcomes     2                                                       │
#> │                                                                        │
#> │   outcome  estimate  statistic  p_value  stepdown_p                    │
#> │   -------  --------  ---------  -------  ----------                    │
#> │   crmrate    -3.232     -19.52    0.042       0.042                    │
#> │   arrrate    -0.214      -3.64    0.125       0.125                    │
#> │                                                                        │
#> │   The p-value is the share of reassigned adoption dates that give a    │
#> │   statistic at least as extreme as the one observed; it needs no model │
#> │   of the errors. The stepdown p-values (Westfall and Young) hold for   │
#> │   all the outcomes tested together.                                    │
#> ╰────────────────────────────────────────────────────────────────────────╯

# your own panel: eight towns over ten years, four adopting a by-law (two
# in 2019, two in 2021), with each town's population, county and income
own <- data.frame(
  town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
  year = rep(2015:2024, times = 8)
)
i <- match(own$town, unique(own$town))
own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
own$county <- rep(c("North", "South"), 4)[i]
own$income <- 50 + own$year - 2015 + cos(seq_len(80))
own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
  0.2 * own$income + sin(seq_len(80))
# every assignment of the two adoption dates to the eight towns
perminf(own, "town", "year", "rate", "first", reps = 99, seed = 1)
#> ╭── Permutation inference ───────────────────────────────────────────────╮
#> │   Method       randomisation inference on the adoption dates           │
#> │   Assignments  99                                                      │
#> │   Draws        random draws                                            │
#> │   Outcomes     1                                                       │
#> │                                                                        │
#> │   outcome  estimate  statistic  p_value  stepdown_p                    │
#> │   -------  --------  ---------  -------  ----------                    │
#> │   rate       -4.039     -16.86    0.010       0.010                    │
#> │                                                                        │
#> │   The p-value is the share of reassigned adoption dates that give a    │
#> │   statistic at least as extreme as the one observed; it needs no model │
#> │   of the errors.                                                       │
#> ╰────────────────────────────────────────────────────────────────────────╯
```
