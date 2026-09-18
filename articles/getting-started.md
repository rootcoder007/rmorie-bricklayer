# Your first capsule: a published table, analysed and recorded

Most published administrative data arrives as a table of counts by
period and group. The questions are always the same: what changed, how
sure can we be, is there a trend, and is this release the one we had
before. This vignette answers them for one real table in twenty lines,
then records the run so someone else can repeat it.

## The table

Ontario publishes the number of distinct individuals held in restrictive
confinement each fiscal year, by age category and gender. A tidy copy of
the published figures ships with the package.

``` r

library(rmoriebricklayer)
otis <- read.csv(system.file("extdata", "otis_a01_individuals.csv",
                             package = "rmoriebricklayer"))
otis
#>           table    group year individuals
#> 1  age_category 18 to 24 2023        3507
#> 2  age_category 18 to 24 2024        2944
#> 3  age_category 18 to 24 2025        3688
#> 4  age_category 25 to 49 2023       14930
#> 5  age_category 25 to 49 2024       14445
#> 6  age_category 25 to 49 2025       18482
#> 7  age_category      50+ 2023        2344
#> 8  age_category      50+ 2024        2252
#> 9  age_category      50+ 2025        2875
#> 10       gender   Female 2023        1511
#> 11       gender   Female 2024        1924
#> 12       gender   Female 2025        2821
#> 13       gender     Male 2023       19270
#> 14       gender     Male 2024       17717
#> 15       gender     Male 2025       22224
```

## One call

``` r

a <- analyse_table(otis, value = "individuals", period = "year",
                   by = c("table", "group"))
a
#> Analysis of `individuals` by year over 3 period(s) (2023 to 2025), grouped by table x group
#>   rows 15, columns 4; no missing values
#>   change: 10 comparison(s), 9 significant after BH at 0.05
#>   trend: 0 of 5 series with Mann-Kendall p < 0.05
```

The change table carries an exact interval for every percent change and
a p-value that is exact too. Five groups are compared twice each, so the
p-values are adjusted over the scan (Benjamini-Hochberg) before any row
is called significant. A row that looks striking on its own is judged in
the company of the other nine.

``` r

a$change[, c("table", "group", "year", "value", "previous",
             "pct_change", "pct_lower", "pct_upper", "p_adjusted",
             "significant")]
#> <rmbl_yoy: no periods>
```

## What the release withheld

Published counts are often rounded. If this table had been rounded to
the nearest five, each cell could have come from any count within two
and a half of it, and the percent change inherits that. `rounding = 5`
adds the envelope and a combined interval that is the union of the
sampling interval and the envelope: the honest range for a number read
off a rounded table. Suppressed cells (`"x"`, `"<5"`) are handled the
same way through `suppression_limit`.

``` r

b <- analyse_table(otis, value = "individuals", period = "year",
                   by = c("table", "group"), rounding = 5)
b$change[!is.na(b$change$previous),
         c("group", "year", "pct_change", "pct_lower", "pct_upper",
           "combined_pct_lower", "combined_pct_upper")]
#> <rmbl_yoy: no periods>
```

## Trend

Three fiscal years is a short series. The Mann-Kendall test is exact for
it, and its smallest possible p-value with three points is one third, so
no trend can be declared from three years; the table says so instead of
hiding it. The Poisson rate ratio per year is still informative as a
description.

``` r

a$trend
#>          table    group periods first  last       tau   trend_p  slope
#> 1 age_category 18 to 24       3  3507  3688 0.3333333 1.0000000   90.5
#> 2 age_category 25 to 49       3 14930 18482 0.3333333 1.0000000 1776.0
#> 3 age_category      50+       3  2344  2875 0.3333333 1.0000000  265.5
#> 4       gender   Female       3  1511  2821 1.0000000 0.3333333  655.0
#> 5       gender     Male       3 19270 22224 0.3333333 1.0000000 1477.0
#>   rate_ratio rate_ratio_lower rate_ratio_upper
#> 1   1.027143        0.8255565         1.277953
#> 2   1.118024        0.9581424         1.304583
#> 3   1.112728        0.9511489         1.301756
#> 4   1.376319        1.2718682         1.489347
#> 5   1.077781        0.9083509         1.278813
```

## Has the data changed since last time?

Keep the previous release and pass it as `prior`; every column is
screened. Before trusting a drift verdict, ask how often the screens
fire on data that has not changed:
[`drift_calibrate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_calibrate.md)
splits one release into random halves and reports the false-alarm rate
per column.

``` r

drift_calibrate(otis, n = 10)
#> Drift screens on 10 identical re-fetches (alpha = 0.01)
#>   at least one column flagged: 0% of re-fetches
#>   no column fired on identical data
#>   per-screen alpha for a family-wise 0.01: 0.0025
```

## Stock and flow

A count of people in confinement on a day is a stock; the people who
pass through in a year are a flow. Lakner’s decomposition ties them
exactly: average daily population is person-days over the days in the
period, average length of stay is person-days over the people served,
and the identity `adp = admissions * alos / t` means a change in days
must multiply out of a change in people and a change in stay.
[`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md)
reports both sides and checks the identity.

``` r

sf <- stock_flow(days = c(21900, 23725, 20440), people = c(300, 325, 280),
                 period = c(2022, 2023, 2024), t = 365)
sf
#> ── Stock and flow over 3 periods ───────────────────────────────── 
#>  period people  days alos adp
#>    2022    300 21900   73  60
#>    2023    325 23725   73  65
#>    2024    280 20440   73  56
#> 
#>   2022 to 2024: people -6.7%, stay +0.0%, days -6.7%
#> ──────────────────────────────────────────────────────────────────
```

A population that rose while stays shortened, or fell while stays
lengthened, reads differently from one where both moved together;
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)
and
[`admissions()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/admissions.md)
give the single measures.

## Stock and flow

A count of people in confinement on a day is a stock; the people who
pass through in a year are a flow. Lakner’s decomposition ties them
exactly: average daily population is person-days over the days in the
period, average length of stay is person-days over the people served,
and the identity `adp = admissions * alos / t` means a change in days
must multiply out of a change in people and a change in stay.
[`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md)
reports both sides and checks the identity.

``` r

sf <- stock_flow(days = c(21900, 23725, 20440), people = c(300, 325, 280),
                 period = c(2022, 2023, 2024), t = 365)
sf
#> ── Stock and flow over 3 periods ───────────────────────────────── 
#>  period people  days alos adp
#>    2022    300 21900   73  60
#>    2023    325 23725   73  65
#>    2024    280 20440   73  56
#> 
#>   2022 to 2024: people -6.7%, stay +0.0%, days -6.7%
#> ──────────────────────────────────────────────────────────────────
```

A population that rose while stays shortened, or fell while stays
lengthened, reads differently from one where both moved together;
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)
and
[`admissions()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/admissions.md)
give the single measures.

## Record it

[`report_analysis()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/report_analysis.md)
writes the whole analysis as Markdown or a single HTML file, and
[`use_capsule_template()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/use_capsule_template.md)
writes a folder with the provenance file, an `analysis.R` that pins the
source bytes and runs the steps above, and a README. The template runs
as written against this table.

``` r

d <- use_capsule_template(tempfile("capsule-"), example = TRUE)
list.files(d)
#> [1] "analysis.R"           "data_provenance.json" "README.md"
cat(readLines(file.path(d, "analysis.R"))[1:12], sep = "\n")
#> # Reproducible capsule: fetch, verify, analyse, record.
#> # Run with: Rscript analysis.R
#> library(rmoriebricklayer)
#> arg <- grep("^--file=", commandArgs(), value = TRUE)
#> here <- if (length(arg)) dirname(normalizePath(sub("^--file=", "", arg[1]))) else getwd()
#> prov <- load_provenance(file.path(here, "data_provenance.json"))
#> 
#> # 1. Fetch (a local path is read directly; a URL is downloaded with a
#> #    Wayback Machine fallback) and pin the bytes.
#> src <- prov$source$url
#> local <- if (file.exists(src)) src else
#>   friendly_download(src, file.path(here, basename(src)))
```

From here, replace the source URL and the column names in
`data_provenance.json`, run `Rscript analysis.R`, and copy the SHA-256
it prints back into the provenance file. Later runs refuse to proceed if
the bytes change, and
[`manifest_recompute()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_recompute.md)
compares two runs number by number.
