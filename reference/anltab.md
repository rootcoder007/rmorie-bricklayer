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
anltab(
  data,
  value,
  prd,
  by = NULL,
  pop = NULL,
  prior = NULL,
  units = c("count", "continuous", "percent"),
  rnd = NULL,
  rndkind = c("nearest", "random"),
  suplim = NULL,
  dir = c("neutral", "higher", "lower"),
  per = 1000,
  conflvl = 0.95,
  alpha = 0.05,
  adjust = "BH",
  prdord = NULL
)
```

## Arguments

- data:

  A data frame in long form: one row per period and group.

- value:

  Name of the column (a string) with the published count (or measure).

- prd:

  Name of the column with the period (fiscal year, quarter, ...);
  numeric periods are used as the time axis of the trend tests. Text
  periods (`"2019/20"`, `"2021 Q3"`, `"Mar 2021"`) are ordered as
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
  reads them (see its `prd`), or as `prdord` gives.

- by:

  Optional character vector of grouping column names (institution,
  region, ...). `NULL` (the default) treats the table as one series.

- pop:

  Optional name of an exposure column for rates (`NULL`, the default,
  skips the rate step).

- prior:

  Optional data frame: the previous capsule of the same table, for the
  drift screen. `NULL` (the default) skips it.

- units:

  `"count"` (the default), `"continuous"` or `"percent"`, as in
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).

- rnd, rndkind, suplim:

  How the release rounds or suppresses cells; see
  [`pubbnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pubbnd.md).
  `rnd` is the rounding base (for example 5), `rndkind` `"nearest"` (the
  default) or `"random"`, `suplim` the threshold below which cells are
  suppressed. `NULL` when the counts are exact. Used only for counts:
  with other `units` they are ignored, with a warning.

- dir:

  Which way is an improvement, as in
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md):
  `"neutral"` (the default), `"higher"` or `"lower"`.

- per:

  Rate denominator, as in
  [`rtcalc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rtcalc.md);
  default 1000 (rates per 1,000 of `pop`).

- conflvl:

  Confidence level for every interval, default 0.95.

- alpha:

  Level for the multiple-comparison decision and the drift screens,
  default 0.05.

- adjust:

  Multiple-comparison method for
  [`scanadj()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scanadj.md).
  The default is `"BH"` (Benjamini-Hochberg).

- prdord:

  Optional character vector: the period labels in order, for text
  periods the reader does not know (see
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md));
  passed to
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md),
  [`ratechg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ratechg.md)
  and the trend tests.

## Value

A list of class `bricklayer_analysis` (with a print method that
summarises it in a few lines):

- `profile`:

  [`profcols()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profcols.md)
  of `data`.

- `missingness`:

  named numeric from
  [`misssmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/misssmry.md).

- `change`:

  the
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
  table; for counts with the added columns `p_value`, `padj` and
  `significant`, and with `env_*` and `compctlo`/`compctup` when
  publication bounds were requested.

- `rates`, `ratechg`:

  the
  [`rtcalc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rtcalc.md)
  and
  [`ratechg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ratechg.md)
  tables when `population` is given, otherwise `NULL`.

- `trend`:

  data frame with one row per group: the `by` columns, `periods`,
  `first`, `last`, `tau`, `trndp`, `slope`, `rateratio`, `rateratiolo`,
  `rateratioup`.

- `drift`:

  [`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
  result against `prior`, or `NULL`.

- `meta`:

  list of the arguments used, `nrows`, the sorted `periods`, `prior`
  (logical) and `when` (a time stamp).

## Details

The steps, in order:

1.  profile:
    [`profcols()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profcols.md)
    and
    [`misssmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/misssmry.md)
    on `data`;

2.  change:
    [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
    between consecutive periods within each `by` group. For
    `units = "count"` the exact p-values are then adjusted across all
    comparisons with
    [`scanadj()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scanadj.md),
    and, when `rnd` or `suplim` is given,
    [`yoybnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoybnd.md)
    adds the publication envelope (see
    [`pubbnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pubbnd.md)).
    For `"continuous"` and `"percent"` units neither step runs: `rnd`
    and `suplim` are then ignored, with a warning;

3.  rates (only with `pop`):
    [`rtcalc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rtcalc.md)
    per group and period, and
    [`ratechg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ratechg.md)
    between periods, adjusted with
    [`scanadj()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scanadj.md);

4.  trend: per group, the values summed within each period, then
    [`trndtst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trndtst.md)
    (Mann-Kendall tau, p-value and Theil-Sen slope) and, for counts,
    [`cnttrnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnttrnd.md)
    (Poisson rate ratio per period). A group with fewer than three
    periods gets `NA`; a test that fails gets `NA` rather than an error;

5.  drift (only with `prior`):
    [`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
    of `data` against `prior`.

Nothing is written and nothing is fetched; a progress bar for the trend
step is drawn on stderr unless `options(morie.quiet = TRUE)`. Errors:
`data` or `prior` not a data frame; a named column not in `data`; an
invalid `units`, `dir` or `rndkind`; a `conflvl` outside (0, 1); and any
error of the functions called (for example negative counts in
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)).

## See also

[`rptanl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rptanl.md)
writes the result as a Markdown or HTML report.

## Examples

``` r
path <- system.file("extdata", "otis_a01_individuals.csv",
                    package = "rmoriebricklayer")
otis <- read.csv(path)
a <- anltab(otis, value = "individuals", prd = "year",
                   by = c("table", "group"))
a
#> ╭── Analysis of a published table ────────────────────────────────────────╮
#> │   Value       `individuals`                                             │
#> │   Period      year                                                      │
#> │   Periods     3 (2023 to 2025)                                          │
#> │   Grouped by  table x group                                             │
#> │   Rows        15                                                        │
#> │   Columns     4                                                         │
#> │   Missing     no missing values                                         │
#> │   Changes     10 comparison(s), 9 significant after BH at 0.05          │
#> │   Trend       0 of 5 series with Mann-Kendall p < 0.05                  │
#> │                                                                         │
#> │   Changes are between consecutive periods with exact or interval tests, │
#> │   adjusted for the number of comparisons; rptanl() writes the full      │
#> │   tables as a report, and x$change, x$rates and x$trend hold them.      │
#> │                                                                         │
#> │   Run 2026-10-28 10:59                                                  │
#> ╰─────────────────────────────────────────────────────────────────────────╯
a$change[, c("table", "group", "year", "pctchg", "padj")]
#>           table    group year     pctchg          padj
#> 1  age_category 18 to 24 2023         NA            NA
#> 2  age_category 18 to 24 2024 -16.053607  3.164937e-12
#> 3  age_category 18 to 24 2025  25.271739  1.664477e-19
#> 4  age_category 25 to 49 2023         NA            NA
#> 5  age_category 25 to 49 2024  -3.248493  5.269786e-03
#> 6  age_category 25 to 49 2025  27.947387 3.609584e-109
#> 7  age_category      50+ 2023         NA            NA
#> 8  age_category      50+ 2024  -3.924915  1.794906e-01
#> 9  age_category      50+ 2025  27.664298  6.794641e-18
#> 10       gender   Female 2023         NA            NA
#> 11       gender   Female 2024  27.332892  2.786935e-12
#> 12       gender   Female 2025  46.621622  2.223495e-38
#> 13       gender     Male 2023         NA            NA
#> 14       gender     Male 2024  -8.059159  1.161620e-15
#> 15       gender     Male 2025  25.438844 8.427443e-112
a$trend[, c("group", "tau", "trndp", "rateratio")]
#>      group       tau     trndp rateratio
#> 1 18 to 24 0.3333333 1.0000000  1.027143
#> 2 25 to 49 0.3333333 1.0000000  1.118024
#> 3      50+ 0.3333333 1.0000000  1.112728
#> 4   Female 1.0000000 0.3333333  1.376319
#> 5     Male 0.3333333 1.0000000  1.077781

# counts published rounded to base 5: the intervals widen
b <- anltab(otis, value = "individuals", prd = "year",
                   by = c("table", "group"), rnd = 5)
b$change[1:3, c("group", "year", "pctlo", "compctlo")]
#>      group year     pctlo  compctlo
#> 1 18 to 24 2023        NA        NA
#> 2 18 to 24 2024 -20.09432 -20.09432
#> 3 18 to 24 2025  19.31564  19.31564

# rates with an exposure column
d <- data.frame(year = rep(2019:2022, 2), site = rep(c("A", "B"), each = 4),
                n = c(10, 12, 15, 9, 30, 28, 35, 40),
                pop = rep(c(1000, 2000), each = 4))
r <- anltab(d, "n", "year", by = "site", pop = "pop", per = 1000)
r$ratechg[, c("site", "year", "rate", "rateratio", "padj")]
#> ╭── Change in rate ─────────────────────────────────────────────────────╮
#> │   Rows     8                                                          │
#> │   Columns  5                                                          │
#> │                                                                       │
#> │   site  year   rate  rateratio   padj                                 │
#> │   ----  ----  -----  ---------  -----                                 │
#> │   A     2019  10.00                                                   │
#> │   A     2020  12.00      1.200  0.896                                 │
#> │   A     2021  15.00      1.250  0.896                                 │
#> │   A     2022   9.00      0.600  0.896                                 │
#> │   B     2019  15.00                                                   │
#> │   B     2020  14.00      0.933  0.896                                 │
#> │   B     2021  17.50      1.250  0.896                                 │
#> │   B     2022  20.00      1.143  0.896                                 │
#> │                                                                       │
#> │   Some of this result's columns are not here (a subset of it?), so it │
#> │   is shown as a plain table.                                          │
#> ╰───────────────────────────────────────────────────────────────────────╯

# a column that is not in the data is an error
try(anltab(otis, value = "count", prd = "year"))
#> Error : anltab: column `count` not found in `data`
```
