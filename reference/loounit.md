# Leave-one-out estimates of a difference in differences

Re-estimates
[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md)
leaving out one treated unit at a time, to show that no single unit
drives the result.

## Usage

``` r
loounit(data, unit, time, y, trtd, covs = NULL, cl = NULL, units = NULL)
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

- units:

  Which units to leave out (default every treated unit).

## Value

A data frame of class `rmbl_loo`: `dropped`, `estimate`, `se`; attribute
`full` (the estimate with every unit).
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
histogram with the full-sample estimate and a summary.

## Examples

``` r
p <- polex()
l <- loounit(p, "district", "month", "crmrate", "reformed")
range(l$estimate)
#> [1] -3.285556 -3.186253
plot(l)
```
