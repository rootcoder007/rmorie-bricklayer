# Difference in differences after matching on pre-treatment trajectories

Matches each treated unit to the comparison units most like it before
treatment (its outcomes in the pre-period and, optionally, covariates),
within an exact grouping if given, and estimates the difference in
differences on the matched sample with the matching weights.

## Usage

``` r
mtchdid(
  data,
  unit,
  time,
  y,
  ftreat,
  covs = NULL,
  ratio = 1L,
  exact = NULL,
  caliper = NULL,
  covm = c("pooled", "full"),
  conflvl = 0.95,
  cl = NULL
)
```

## Arguments

- data:

  A data frame, one row per unit and period.

- unit, time, y:

  Column names: the unit, the period (numeric, for example a year or a
  month index) and the outcome.

- ftreat:

  Column name of the period a unit is first treated (`NA`, 0 or `Inf`
  for a unit never treated). Treatment is taken as staying on.

- covs:

  Optional covariate columns to match on (their pre-period means).

- ratio:

  Comparison units per treated unit (default 1).

- exact:

  Optional column name: match only within its values (a region, a
  district).

- caliper:

  Optional maximum distance, in standard deviations of the distances.

- covm:

  `"pooled"` (default; the pooled within-group covariance) or `"full"`
  (the whole sample's).

- conflvl:

  Confidence level of the intervals reported (default 0.95).

- cl:

  Column name of the clusters (default the unit), or two column names
  for two-way clustering (Cameron, Gelbach and Miller 2011): \\V_a +
  V_b - V\_{ab}\\, each term with the small-sample factor of the
  dimension with fewer clusters, and t on its \\G - 1\\ degrees of
  freedom. A composite cluster (district by month, say) is one column
  made with [`interaction()`](https://rdrr.io/r/base/interaction.html).

## Value

A list of class `rmbl_matched_did`: `estimate` (a
[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md)
result), `matches` (treated unit, comparison unit, distance), `weights`
(per unit), `balance` (a
[`baltab`](https://rootcoder007.github.io/rmorie-bricklayer/reference/baltab.md)
of the matching features before and after).

## Details

Each unit is described by its outcome in each pre-period (the periods
before the first adoption) and the pre-period means of the covariates.
Distances are Mahalanobis, with the pooled within-group covariance of
those features (`covariance = "pooled"`, as `MatchIt` computes it) or
their covariance in the whole sample (`"full"`, as
[`stats::mahalanobis()`](https://rdrr.io/r/stats/mahalanobis.html) is
usually given it); each treated unit takes its `ratio` nearest
comparison units, with replacement (so the matches do not depend on the
order of the treated units), only within its `exact` group, and only
within `caliper` (in units of the distance's standard deviation) if
given. A comparison unit's weight is the sum over the treated units it
serves of \\1/\code{ratio}\\. The estimate is
[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md)
on the matched units with those weights, with errors clustered by unit;
matching on pre-period outcomes makes parallel trends more credible but
can bring in regression to the mean when the treated were chosen for an
unusual pre-period (Daw and Hatfield 2018).

## References

Daw JR, Hatfield LA (2018). Matching and regression to the mean in
difference-in-differences analysis. Health Services Research
53(6):4138-4156.
[doi:10.1111/1475-6773.12993](https://doi.org/10.1111/1475-6773.12993)

Applied with spatial nearest-facility matching within judicial
districts: Zorro Medina A (2020). The failed war on pre-trial detention:
evidence from a quasi-experimental reform.
[doi:10.2139/ssrn.3686855](https://doi.org/10.2139/ssrn.3686855)

## Examples

``` r
p <- polex()
m <- mtchdid(p, "district", "month", "crmrate", "refmonth", ratio = 2)
m$estimate
#> ╭── Difference in differences ────────────────────────────────────────────────╮
#> │   Method           fixed-effects least squares, cluster-robust (CR1) errors │
#> │   Observations     720                                                      │
#> │   Clusters         20                                                       │
#> │   Confidence       95%                                                      │
#> │   Comparison mean  26.3                                                     │
#> │   Relative effect  -11.7% of the comparison mean                            │
#> │                                                                             │
#> │   Estimates                                                                 │
#> │   term     estimate      se  95% CI                 t  p_value              │
#> │   -------  --------  ------  ----------------  ------  -------              │
#> │   treated    -3.081  0.1208  [-3.334, -2.829]  -25.51  < 0.001              │
#> │                                                                             │
#> │   The policy's effect on the outcome is -3.081 (95% interval [-3.334,       │
#> │   -2.829]): the interval excludes 0, so the data distinguish it from no     │
#> │   effect.                                                                   │
#> │                                                                             │
#> │   The comparison mean is the pre-period mean outcome of the units not       │
#> │   (yet) treated.                                                            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
m$balance
#>    feature    smdbef  smdafter
#> 1      y_1 0.6234337 0.6305205
#> 2      y_2 0.4933815 0.5333419
#> 3      y_3 0.3630111 0.4016449
#> 4      y_4 0.5185005 0.5671520
#> 5      y_5 0.5394918 0.5670062
#> 6      y_6 0.5953617 0.6497642
#> 7      y_7 0.5296771 0.5555045
#> 8      y_8 0.4786997 0.5442183
#> 9      y_9 0.6411876 0.6298522
#> 10    y_10 0.5844047 0.7157425
#> 11    y_11 0.5414501 0.5442063
#> 12    y_12 0.4630436 0.5330361

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
# each adopting town matched to one never treated on its path before 2019,
# the standard errors clustered by county
mtchdid(own, "town", "year", "rate", "first", cl = "county")$estimate
#> ╭── Difference in differences ────────────────────────────────────────────────╮
#> │   Method           fixed-effects least squares, cluster-robust (CR1) errors │
#> │   Observations     60                                                       │
#> │   Clusters         2                                                        │
#> │   Confidence       95%                                                      │
#> │   Comparison mean  46.48                                                    │
#> │   Relative effect  -8.7% of the comparison mean                             │
#> │                                                                             │
#> │   Estimates                                                                 │
#> │   term     estimate      se  95% CI                   t  p_value            │
#> │   -------  --------  ------  ------------------  ------  -------            │
#> │   treated    -4.052  0.3065  [-7.9460, -0.1577]  -13.22    0.048            │
#> │                                                                             │
#> │   The policy's effect on the outcome is -4.052 (95% interval [-7.9460,      │
#> │   -0.1577]): the interval excludes 0, so the data distinguish it from       │
#> │   no effect.                                                                │
#> │                                                                             │
#> │   The comparison mean is the pre-period mean outcome of the units not       │
#> │   (yet) treated.                                                            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```
