# Write a capsule report as Markdown

Renders a
[`capsule_report()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_report.md)
as Markdown, so the assessment can travel with the capsule instead of
living in a console someone has since closed. The document renders on
GitHub, in R Markdown and Quarto, and in any Markdown viewer, and reads
well as plain text.

## Usage

``` r
report_markdown(report, path = NULL, title = "Capsule report")
```

## Arguments

- report:

  A `bricklayer_report` from
  [`capsule_report()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_report.md).

- path:

  Optional character scalar, the file to write. Without one (`NULL`, the
  default) the lines are returned.

- title:

  Character scalar, the heading for the document; default
  `"Capsule report"`.

## Value

A character vector of Markdown lines; returned visibly when `path` is
`NULL`, invisibly when written to a file.

## Details

The document has a level-one heading (`title`), the verdict in one
sentence, a two-column table of rows, columns, missing cells, complete
rows and the full data digest (with the Merkle root and the signature
result when the report has them), a "Findings" table of severity, check,
subject and detail (left out when there is none), and a closing caveat
that no finding is proof of correctness. The text of the findings is
written as it is: a `|` in a column name would break the table. An
existing file at `path` is overwritten. Errors when `report` does not
come from
[`capsule_report()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_report.md).

## See also

[`capsule_report()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_report.md)

## Examples

``` r
set.seed(1)
df <- data.frame(v = stats::rnorm(100), g = rep("x", 100),
                 stringsAsFactors = FALSE)
r <- capsule_report(df)

md <- report_markdown(r)
cat(head(md, 8), sep = "\n")
#> # Capsule report
#> 
#> Notes only -- worth a look, nothing blocking.
#> 
#> | | |
#> |---|---|
#> | rows | 100 |
#> | columns | 2 |

# Written beside the capsule it describes.
p <- tempfile(fileext = ".md")
report_markdown(r, p)
file.exists(p)
#> [1] TRUE
unlink(p)

# a report with findings, under its own title
r2 <- capsule_report(transform(df, v = ifelse(seq_along(v) <= 60, NA, v)))
md2 <- report_markdown(r2, title = "Extract of 2024-03-01")
md2[1]
#> [1] "# Extract of 2024-03-01"
md2[grep("^## Findings", md2) + 0:4]
#> [1] "## Findings"                                          
#> [2] ""                                                     
#> [3] "| severity | check | subject | detail |"              
#> [4] "|---|---|---|---|"                                    
#> [5] "| warn | missing | v | over half the values missing |"

# only a capsule_report() result is accepted
try(report_markdown(list(verdict = "clean")))
#> Error : `report` must come from capsule_report()
```
