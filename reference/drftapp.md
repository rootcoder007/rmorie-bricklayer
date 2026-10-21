# Drift report as a Shiny app

The report of
[`drfthtml()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drfthtml.md)
as a Shiny app, for working through a drift result rather than handing
it on. `drftapp(x)` opens on a
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
result; `drftapp()` with no result opens on two file inputs, the
reference and the current CSV, and compares them when both are uploaded.
It needs the shiny package, which is suggested, not required.

## Usage

``` r
drftapp(
  x = NULL,
  ref = NULL,
  cur = NULL,
  hist = NULL,
  warn = NULL,
  fail = NULL
)
```

## Arguments

- x:

  A
  [`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
  result, or `NULL` (the default) to upload two CSV files in the app.

- ref, cur:

  Optional: the two data frames `x` was computed from, for the rerun
  panel.

- hist:

  Optional: a directory of earlier drift JSON files, for the history
  tab.

- warn, fail:

  The PSI bands the page opens with; `NULL` (the default) takes the
  object's `bands`.

## Value

A Shiny app object (class `shiny.appobj`).

## Details

The app has the column table (verdicts under the bands), the PSI per
column, the fingerprint, and for the chosen column its summary, the
distributions, the ECDFs, the quantile shift, the first digits and a
sentence on the verdict, as
[`drfthtml()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drfthtml.md)
has, and a history heatmap with `hist`; the warn and fail bands and
alpha are sliders, with a reset to the object's bands. Beyond the page
it has: “what would clear this”, the PSI of the column with its `k`
largest bins left out and the rest renormalized; with `ref` and `cur`
(or uploaded CSV files), a rerun of
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
on chosen columns with another number of bins; with `hist`, the PSI of
each column over the runs in that directory (`rmbl drift --json` outputs
or JSON exports of the page); a manifest tab when `x$manifest` holds an
[`mnfdiff()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfdiff.md);
and downloads of the HTML report, Markdown and JSON. Uploaded files are
read with the package's own CSV reader (the one
[`dload()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dmnf.md)
uses). `rmbl drift PATH --app` opens the app on the first capsule whose
source moved.

The function builds the app and returns it; printing it, or
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html), runs it.

Errors: `x` neither `NULL` nor from
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md);
shiny not installed; only one of `ref` and `cur`, or either not a data
frame; `hist` not a directory or holding no drift JSON; `warn` above
`fail`.

## See also

[`drfthtml()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drfthtml.md)
for a file to hand on.

## Examples

``` r
set.seed(5)
ref <- data.frame(value = stats::rnorm(400),
                  grade = sample(c("a", "b", "c"), 400, TRUE))
cur <- data.frame(value = stats::rnorm(400, 0.4),
                  grade = sample(c("a", "b", "c"), 400, TRUE))
d <- cpsdrft(ref, cur)
if (FALSE) { # interactive()
if (requireNamespace("shiny", quietly = TRUE)) {
  # drftapp() alone opens on two CSV files to upload
  print(drftapp(d, ref = ref, cur = cur))
}
}
```
