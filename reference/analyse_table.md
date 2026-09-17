# Analyse a published administrative table in one call

The questions asked of a published table are always the same: what is in
it, what changed between periods and how sure can one be, what the rates
are if there is an exposure, whether a short series trends, and whether
this release differs from the one held before. Each has a function in
this package; this runs them together, with the pieces a reviewer needs
and that are easy to forget on a deadline: exact intervals on every
change, multiple-comparison adjustment over the groups scanned, the
envelope that rounding and suppression in the release imply, and a drift
screen against the prior capsule.

## Usage

``` r
analyse_table(
  data,
  value,
  period,
  by = NULL,
  population = NULL,
  prior = NULL,
  units = c("count", "continuous", "percent"),
  rounding = NULL,
  rounding_kind = c("nearest", "random"),
  suppression_limit = NULL,
  direction = c("neutral", "higher_is_better", "lower_is_better"),
  per = 1000,
  conf_level = 0.95,
  alpha = 0.05,
  adjust = "BH"
)
```

## Arguments

- data:

  A data frame in long form: one row per period and group.

- value:

  Column with the published count (or measure).

- period:

  Column with the period (fiscal year, quarter, ...).

- by:

  Optional grouping columns (institution, region, ...).

- population:

  Optional exposure column for rates.

- prior:

  Optional data frame: the previous capsule of the same table, for the
  drift screen.

- units:

  `"count"`, `"continuous"` or `"percent"`, as in
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).

- rounding, rounding_kind, suppression_limit:

  How the release rounds or suppresses cells; see
  [`published_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/published_bounds.md).
  `NULL` when the counts are exact.

- direction:

  Which way is an improvement, as in
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).

- per:

  Rate denominator, as in
  [`rate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate.md).

- conf_level:

  Confidence level for every interval.

- alpha:

  Level for the multiple-comparison decision and the drift screens.

- adjust:

  Multiple-comparison method for
  [`scan_adjust()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scan_adjust.md).

## Value

A list of class `bricklayer_analysis` with `profile`
([`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md)),
`missingness`
([`missingness_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_summary.md)),
`change`
([`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
with p-values, adjustment and, if `rounding` or `suppression_limit` was
given, publication bounds), `rates` and `rate_change` (when `population`
is given), `trend` (one row per group with
[`trend_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trend_test.md)
and, for counts,
[`count_trend()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/count_trend.md)),
`drift`
([`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
against `prior`), and `meta`.

## See also

[`report_analysis()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/report_analysis.md)
writes the result as a Markdown or HTML report.

## Examples

``` r
path <- system.file("extdata", "otis_a01_individuals.csv",
                    package = "rmoriebricklayer")
otis <- read.csv(path)
a <- analyse_table(otis, value = "individuals", period = "year",
                   by = c("table", "group"))
a
#> Analysis of `individuals` by year over 3 period(s) (2023 to 2025), grouped by table x group
#>   rows 15, columns 4; no missing values
#>   change: 10 comparison(s), 9 significant after BH at 0.05
#>   trend: 0 of 5 series with Mann-Kendall p < 0.05
a$change[, c("table", "group", "year", "pct_change", "p_adjusted")]
#> <rmbl_yoy: no periods>
```
