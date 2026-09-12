# Write a capsule report as Markdown

Renders a
[`capsule_report()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_report.md)
as Markdown, so the assessment can travel with the capsule instead of
living in a console someone has since closed.

## Usage

``` r
report_markdown(report, path = NULL, title = "Capsule report")
```

## Arguments

- report:

  A `bricklayer_report`.

- path:

  Optional file to write. Without one the lines are returned.

- title:

  Heading for the document.

## Value

The Markdown lines, invisibly when written to a file.

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
```
