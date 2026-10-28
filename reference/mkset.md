# Combine Results into One Report

Puts several results together: printed, a box of contents and then every
result's own box, all at the console's width; written to a file, one
self-contained HTML page (each result's box and, when it has one, its
plot), Markdown ready for a GitHub comment or a paper, or plain text.

## Usage

``` r
mkset(..., title = "Analysis results", file = NULL, plots = TRUE)
```

## Arguments

- ...:

  The results. A name gives a result its heading
  (`"Change by year" = anltab(...)`); an unnamed one is headed by its
  box's own title. One unnamed plain list is read as the list of
  results.

- title:

  The report's heading, default `"Analysis results"`.

- file:

  `NULL` (default) to print, or a file to write: the extension picks the
  format (`.html` or `.htm`, `.md`, `.txt`). An existing file is
  replaced.

- plots:

  In HTML, draw each result's plot, default `TRUE`.

## Value

An object of class `rmbl_set`: a list with `title` and `items` (the
results, named by their headings). It prints as the report. With `file`,
it is returned invisibly with the written file's path in attribute
`"path"`.

## Details

Any object this package returns can go in, and any other R object that
prints (a model, a data frame): each is shown as it prints. A
year-over-year table from
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
becomes a real table in HTML and Markdown.

In a file the boxes are drawn 80 characters wide and without colour, so
the report looks the same whatever console made it. HTML draws each
result's [`plot()`](https://rdrr.io/r/graphics/plot.default.html) under
its box (`plots = FALSE` leaves them out); a plot that fails is left out
and the box is kept. The page needs no network and nothing installed to
open.

Errors: no results; a `file` that does not end in `.html`, `.htm`, `.md`
or `.txt`; a `title` that is not one string; `plots` that is not `TRUE`
or `FALSE`.

## See also

[`rptanl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rptanl.md)
for the report of one
[`anltab()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/anltab.md)
analysis;
[`rmblapp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmblapp.md),
whose dashboard gathers results the same way.

## Examples

``` r
x <- c(3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5)
d <- data.frame(year = rep(2020:2023, 2), grp = rep(c("a", "b"), each = 4),
                n = c(5, 7, 9, 11, 4, 6, 8, 7), pop = 1000)
s <- mkset(
  "How unequal" = ginicoef(x),
  "Rates by group" = rtcalc(d, "n", "pop", by = "grp"),
  title = "My study"
)
s
#> ╭── My study ─────────────────────────────────────────────────────────────────╮
#> │   Results  2                                                                │
#> │                                                                             │
#> │   No  Result          Class                                                 │
#> │   --  --------------  ---------                                             │
#> │    1  How unequal     rmbl_gini                                             │
#> │    2  Rates by group  rmbl_rate                                             │
#> │                                                                             │
#> │   Each result follows under its number. mkset(..., file = ) writes them as  │
#> │   one HTML page (.html), Markdown (.md) or text (.txt).                     │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
#> 
#> 1. How unequal
#> 
#> ╭── Gini coefficient ─────────────────────────────────────────────────────────╮
#> │   Gini coefficient  0.3099                                                  │
#> │   Units             11                                                      │
#> │   Total             44                                                      │
#> │   Largest unit      9 (20.5% of the total)                                  │
#> │   Most for n units  0.9091                                                  │
#> │                                                                             │
#> │   A Gini of 0.3099: the total is moderately concentrated.                   │
#> │   That is 34% of the way from equal shares (0) to one unit holding all of   │
#> │   it (0.9091 for 11 units).                                                 │
#> │                                                                             │
#> │   0 when every unit holds the same, 1 - 1/n when one unit holds it all;     │
#> │   doubling every value leaves it unchanged. It says how unequal, not        │
#> │   which units: topshr() and lorenzc() show where the total sits.            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
#> 
#> 2. Rates by group
#> 
#> ╭── Rate per 1,000 ───────────────────────────────────────────────────────╮
#> │   Count       n                                                         │
#> │   Population  pop                                                       │
#> │   Groups      grp                                                       │
#> │   Rows        2                                                         │
#> │   Interval    95% exact Poisson                                         │
#> │                                                                         │
#> │   grp  count  population   rate  95% CI                                 │
#> │   ---  -----  ----------  -----  ---------------                        │
#> │   a       32       4,000  8.000  [5.472, 11.294]                        │
#> │   b       25       4,000  6.250  [4.045, 9.226]                         │
#> │                                                                         │
#> │   Highest rate: a (8); lowest: b (6.25). Their intervals overlap, which │
#> │   alone does not mean they are the same: the difference has its own,    │
#> │   narrower interval (svycmp() for survey domains).                      │
#> │                                                                         │
#> │   Each rate is the count over the population times the base; the exact  │
#> │   Poisson interval stays honest for small counts, where a normal one    │
#> │   does not.                                                             │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# one page, one Markdown file, one text file
mkset(s$items, title = "My study", file = file.path(tempdir(), "r.html"))
mkset(s$items, title = "My study", file = file.path(tempdir(), "r.md"))
mkset(s$items, title = "My study", file = file.path(tempdir(), "r.txt"))

# the extension picks the format
try(mkset(ginicoef(x), file = file.path(tempdir(), "r.pdf")))
#> Error : mkset: `file` must end in .html, .md or .txt, not .pdf
```
