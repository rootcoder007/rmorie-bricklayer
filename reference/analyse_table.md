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

  Name of the column (a string) with the published count (or measure).

- period:

  Name of the column with the period (fiscal year, quarter, ...);
  numeric periods are used as the time axis of the trend tests.

- by:

  Optional character vector of grouping column names (institution,
  region, ...). `NULL` (the default) treats the table as one series.

- population:

  Optional name of an exposure column for rates (`NULL`, the default,
  skips the rate step).

- prior:

  Optional data frame: the previous capsule of the same table, for the
  drift screen. `NULL` (the default) skips it.

- units:

  `"count"` (the default), `"continuous"` or `"percent"`, as in
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).

- rounding, rounding_kind, suppression_limit:

  How the release rounds or suppresses cells; see
  [`published_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/published_bounds.md).
  `rounding` is the rounding base (for example 5), `rounding_kind`
  `"nearest"` (the default) or `"random"`, `suppression_limit` the
  threshold below which cells are suppressed. `NULL` when the counts are
  exact. Used only for counts: with other `units` they are ignored, with
  a warning.

- direction:

  Which way is an improvement, as in
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md):
  `"neutral"` (the default), `"higher_is_better"` or
  `"lower_is_better"`.

- per:

  Rate denominator, as in
  [`rate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate.md);
  default 1000 (rates per 1,000 of `population`).

- conf_level:

  Confidence level for every interval, default 0.95.

- alpha:

  Level for the multiple-comparison decision and the drift screens,
  default 0.05.

- adjust:

  Multiple-comparison method for
  [`scan_adjust()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scan_adjust.md),
  default `"BH"` (Benjamini-Hochberg).

## Value

A list of class `bricklayer_analysis` (with a print method that
summarises it in a few lines):

- `profile`:

  [`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md)
  of `data`.

- `missingness`:

  named numeric from
  [`missingness_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_summary.md).

- `change`:

  the
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
  table; for counts with the added columns `p_value`, `p_adjusted` and
  `significant`, and with `env_*` and
  `combined_pct_lower`/`combined_pct_upper` when publication bounds were
  requested.

- `rates`, `rate_change`:

  the
  [`rate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate.md)
  and
  [`rate_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate_change.md)
  tables when `population` is given, otherwise `NULL`.

- `trend`:

  data frame with one row per group: the `by` columns, `periods`,
  `first`, `last`, `tau`, `trend_p`, `slope`, `rate_ratio`,
  `rate_ratio_lower`, `rate_ratio_upper`.

- `drift`:

  [`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
  result against `prior`, or `NULL`.

- `meta`:

  list of the arguments used, `n_rows`, the sorted `periods`, `prior`
  (logical) and `when` (a time stamp).

## Details

The steps, in order:

1.  profile:
    [`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md)
    and
    [`missingness_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_summary.md)
    on `data`;

2.  change:
    [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
    between consecutive periods within each `by` group. For
    `units = "count"` the exact p-values are then adjusted across all
    comparisons with
    [`scan_adjust()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scan_adjust.md),
    and, when `rounding` or `suppression_limit` is given,
    [`yoy_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_bounds.md)
    adds the publication envelope (see
    [`published_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/published_bounds.md)).
    For `"continuous"` and `"percent"` units neither step runs:
    `rounding` and `suppression_limit` are then ignored, with a warning;

3.  rates (only with `population`):
    [`rate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate.md)
    per group and period, and
    [`rate_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate_change.md)
    between periods, adjusted with
    [`scan_adjust()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scan_adjust.md);

4.  trend: per group, the values summed within each period, then
    [`trend_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trend_test.md)
    (Mann-Kendall tau, p-value and Theil-Sen slope) and, for counts,
    [`count_trend()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/count_trend.md)
    (Poisson rate ratio per period). A group with fewer than three
    periods gets `NA`; a test that fails gets `NA` rather than an error;

5.  drift (only with `prior`):
    [`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
    of `data` against `prior`.

Nothing is written and nothing is fetched; a progress bar for the trend
step is drawn on stderr unless `options(morie.quiet = TRUE)`. Errors:
`data` or `prior` not a data frame; a named column not in `data`; an
invalid `units`, `direction` or `rounding_kind`; a `conf_level` outside
(0, 1); and any error of the functions called (for example negative
counts in
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)).

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
a$trend[, c("group", "tau", "trend_p", "rate_ratio")]
#>      group       tau   trend_p rate_ratio
#> 1 18 to 24 0.3333333 1.0000000   1.027143
#> 2 25 to 49 0.3333333 1.0000000   1.118024
#> 3      50+ 0.3333333 1.0000000   1.112728
#> 4   Female 1.0000000 0.3333333   1.376319
#> 5     Male 0.3333333 1.0000000   1.077781

# counts published rounded to base 5: the intervals widen
b <- analyse_table(otis, value = "individuals", period = "year",
                   by = c("table", "group"), rounding = 5)
b$change[1:3, c("group", "year", "pct_lower", "combined_pct_lower")]
#> <rmbl_yoy: no periods>

# rates with an exposure column
d <- data.frame(year = rep(2019:2022, 2), site = rep(c("A", "B"), each = 4),
                n = c(10, 12, 15, 9, 30, 28, 35, 40),
                pop = rep(c(1000, 2000), each = 4))
r <- analyse_table(d, "n", "year", by = "site", population = "pop", per = 1000)
r$rate_change[, c("site", "year", "rate", "rate_ratio", "p_adjusted")]
#> ──  ────────────────────────────────────────────────────────────── 
#>  site year rate rate_ratio p_adjusted
#>     A 2019 10.0         NA         NA
#>     A 2020 12.0  1.2000000  0.8956832
#>     A 2021 15.0  1.2500000  0.8956832
#>     A 2022  9.0  0.6000000  0.8956832
#>     B 2019 15.0         NA         NA
#>     B 2020 14.0  0.9333333  0.8956832
#>     B 2021 17.5  1.2500000  0.8956832
#>     B 2022 20.0  1.1428571  0.8956832
#> ────────────────────────────────────────────────────────────────── 

# a column that is not in the data is an error
try(analyse_table(otis, value = "count", period = "year"))
#> Error : column `count` not found in `data`
```
