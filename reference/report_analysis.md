# Write an analysis as a Markdown or HTML report

Renders a
[`analyse_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/analyse_table.md)
result: the profile, the change table with its intervals and adjusted
p-values, the rates, the trends and the drift screen, each with one
sentence saying how to read it. The Markdown is plain enough to paste
into a notebook; the HTML is a single self-contained file.

## Usage

``` r
report_analysis(
  x,
  path = NULL,
  format = c("markdown", "html"),
  title = "Analysis of a published table",
  digits = 1L
)
```

## Arguments

- x:

  A `bricklayer_analysis`.

- path:

  Where to write. With `NULL` the text is returned invisibly and nothing
  is written.

- format:

  `"markdown"` or `"html"`; guessed from `path` when it ends in `.html`
  or `.md`.

- title:

  Report title.

- digits:

  Digits for percentages and rates.

## Value

The report text, invisibly.

## Examples

``` r
path <- system.file("extdata", "otis_a01_individuals.csv",
                    package = "rmoriebricklayer")
a <- analyse_table(read.csv(path), value = "individuals",
                   period = "year", by = c("table", "group"))
md <- report_analysis(a)
cat(substr(md, 1, 400))
#> # Analysis of a published table
#> 
#> `individuals` by `year`, grouped by `table` and `group`; 15 rows; 3 period(s) from 2023 to 2025; generated 2026-09-18 11:15.
#> 
#> ## Change between periods
#> 
#> Percent change with a 95% exact conditional-binomial interval; p-values are exact and adjusted over the 10 comparisons by BH. A row is significant when the adjusted p-value is below 0.05.
#> 
#> | table | group | year | 
```
