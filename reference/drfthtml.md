# Interactive drift report as one HTML file

Writes a
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
result to a single web page for a reader who will not run R. Everything
is inside the file: the stylesheet, a short script, and the binned
summaries of each column as JSON. Nothing is fetched, so the page opens
from disk (`file://`) and looks the same later.

## Usage

``` r
drfthtml(
  x,
  file,
  title = "Drift report",
  warn = NULL,
  fail = NULL,
  open = FALSE
)
```

## Arguments

- x:

  A
  [`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
  result. Attach a provenance record as `x$provenance` (for example from
  [`loadprov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loadprov.md))
  and an
  [`mnfdiff()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfdiff.md)
  as `x$manifest` to show them; `rmbl drift --html` does both.

- file:

  The path to write.

- title:

  The page title, a string.

- warn, fail:

  The PSI bands the page opens with; `NULL` (the default) takes the
  object's `bands`.

- open:

  Logical: open the page in the browser when written (default `FALSE`).

## Value

The path `file`, invisibly.

## Details

The page shows:

- a header with the overall verdict, the count of columns per verdict,
  the row counts, when the page was written, the package version, and
  the capsule's provenance (name, source, pinned SHA-256, data date)
  when `x$provenance` holds one;

- the column table: verdict, column, type, test (KS for numbers and
  dates, chi-square homogeneity for categories), statistic, p-value,
  PSI, the change in the missing share and both sample sizes. It has a
  search box, filters by verdict and type, and sorts on any header;

- for the column chosen (click a row, or the up and down keys; `/` goes
  to the search box): both samples' summary statistics, or the ten
  largest categories; their distributions overlaid; each bin's term of
  the PSI, drawn up where the current sample has more mass and down
  where it has less; for a numeric column the first digits against
  Benford's law; and a sentence on what the verdict means;

- sliders for the warn and fail PSI bands and for alpha, which score the
  verdicts again as they move, and a button back to the object's bands;

- a manifest tab with the resources added, removed or changed, their
  digests and sizes, when `x$manifest` holds an
  [`mnfdiff()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfdiff.md);

- a history tab: pick earlier `rmbl drift --json` outputs or this page's
  JSON exports, and the PSI of each column is drawn over the runs,
  points above the fail band marked;

- exports: Markdown, JSON, each chart as SVG, and the column table
  copied as a GitHub comment.

The verdicts: `fail` when the test rejects at alpha, or the PSI is above
the fail band with both samples at least `psiminn`; `warn` when the PSI
is above the warn band; `untested` when no test applies; `ok` otherwise.
At the object's bands `fail` is
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)'s
`drifted`. Each verdict is written in words beside its symbol, the
tables have header cells, and each chart has a text label. A light or
dark theme follows the system and a button switches it. Every value is
escaped. The page holds no rows of the data, only the summaries in
`x$summ`, so its size grows with the number of columns and categories,
not of rows.

Errors: `x` not from
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md);
`file` not one path; `title` not one string; `warn` above `fail`.

## See also

[`drftapp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftapp.md)
for the same report as a Shiny app,
[plot()](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
for the same charts in base graphics.

## Examples

``` r
set.seed(5)
ref <- data.frame(value = stats::rnorm(400),
                  grade = sample(c("a", "b", "c"), 400, TRUE))
cur <- data.frame(value = stats::rnorm(400, 0.4),
                  grade = sample(c("a", "b", "c"), 400, TRUE))
d <- cpsdrft(ref, cur)
f <- file.path(tempdir(), "drift.html")
drfthtml(d, f, title = "Pinned against fetched")
file.exists(f)
#> [1] TRUE

# narrower bands open the page with more columns to look at
drfthtml(d, f, warn = 0.02, fail = 0.05)
unlink(f)
try(drfthtml(list(), f))
#> Error : drfthtml: `x` must be a bricklayer_drift object from cpsdrft()
```
