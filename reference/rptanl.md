# Write an analysis as a Markdown or HTML report

Renders an
[`anltab()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/anltab.md)
result as a report: the change table with its intervals and adjusted
p-values, the rates, the trends, the drift screen and the column
profile, each with one sentence saying how to read it. The Markdown is
plain enough to paste into a notebook or a pull request; the HTML is a
single self-contained file with no external resources, suitable for
e-mailing to a reviewer.

## Usage

``` r
rptanl(
  x,
  path = NULL,
  format = NULL,
  title = "Analysis of a published table",
  digits = 1L
)
```

## Arguments

- x:

  A `bricklayer_analysis` from
  [`anltab()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/anltab.md).

- path:

  Where to write, a file path. With `NULL` (the default) the text is
  returned invisibly and nothing is written.

- format:

  `"markdown"` or `"html"`. With `NULL` (the default), a `path` ending
  in `.html` or `.htm` gives HTML and anything else, or no `path`, gives
  Markdown.

- title:

  Report title, a string; the top heading and, for HTML, the page title.

- digits:

  Number of decimals for percentages and rates, default 1.

## Value

The report text (a length-1 character string, Markdown or a full HTML
document), invisibly.

## Details

Sections appear in this order: a header line (value, period, groups,
rows, period range and the time of the analysis), “Change between
periods”, “Rates per ...” (when there were rates), “Trend over the
series”, “Drift against the prior capsule” (when a prior was given) and
“What is in the table” (with “Missing values” when any are missing).
Tables use pipe syntax; numbers are rounded to `digits` decimals, whole
numbers of 10,000 and above get thousands separators, logicals are
written yes/no and `NA` is blank. When the values are percentages the
change is reported in percentage points. The HTML is produced by a small
built-in converter (headings, paragraphs, tables and inline code, with
the text escaped). The file is written as UTF-8 and overwritten if it
exists.

Errors: `x` not from
[`anltab()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/anltab.md);
an invalid `format`.

## Examples

``` r
path <- system.file("extdata", "otis_a01_individuals.csv",
                    package = "rmoriebricklayer")
a <- anltab(read.csv(path), value = "individuals",
                   prd = "year", by = c("table", "group"))
md <- rptanl(a)
cat(substr(md, 1, 400))
#> # Analysis of a published table
#> 
#> `individuals` by `year`, grouped by `table` and `group`; 15 rows; 3 period(s) from 2023 to 2025; generated 2026-10-27 20:14.
#> 
#> ## Change between periods
#> 
#> Percent change with a 95% exact conditional-binomial interval; p-values are exact and adjusted over the 10 comparisons by BH. A row is significant when the adjusted p-value is below 0.05.
#> 
#> | table | group | year | 

# HTML, chosen from the file extension
out <- tempfile(fileext = ".html")
rptanl(a, out, title = "OTIS A01: individuals in custody", digits = 2)
readLines(out, n = 3)
#> [1] "<!DOCTYPE html>"                                 
#> [2] "<html lang=\"en\"><head><meta charset=\"utf-8\">"
#> [3] "<title>OTIS A01: individuals in custody</title>" 

# only an anltab() result can be reported
try(rptanl(read.csv(path)))
#> Error : `x` must come from anltab()
unlink(out)
```
