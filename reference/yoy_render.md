# Render a change table to HTML or PDF

Render a change table to HTML or PDF

## Usage

``` r
yoy_html(
  x,
  file,
  title = "Year-over-year change",
  subtitle = NULL,
  palette = "diverging",
  digits = 1L,
  bars = TRUE,
  interval = TRUE,
  notes = NULL,
  ...
)

yoy_pdf(
  x,
  file,
  title = "Year-over-year change",
  subtitle = NULL,
  palette = "diverging",
  digits = 1L,
  interval = TRUE,
  notes = NULL,
  width = 11,
  height = 8.5,
  ...
)
```

## Arguments

- x:

  An `rmbl_yoy` object from
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).

- file:

  Output path. `yoy_html()` writes a single self-contained HTML file
  with no external requests; `yoy_pdf()` writes a PDF using R's own
  device, so neither needs a package beyond base R.

- title:

  Heading for the page.

- subtitle:

  Optional line under the heading. Defaults to the table's own settings
  – lag, units, interval and base gate – so the reader can see what the
  percentages mean.

- palette:

  One of
  [`yoy_palettes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_palettes.md).

- digits:

  Digits for the percent column.

- bars:

  Whether to draw an in-cell bar proportional to the change, scaled to
  the largest absolute change in the table.

- interval:

  Whether to show the exact interval column for counts.

- notes:

  Optional character vector of footnotes.

- ...:

  Ignored.

- width, height:

  PDF page size in inches.

## Value

The path, invisibly.

## Examples

``` r
d <- data.frame(year = rep(2019:2023, each = 2),
                region = rep(c("North", "South"), 5),
                n = c(31, 402, 28, 377, 12, 190, 19, 268, 24, 331))
y <- yoy(d, value = "n", period = "year", by = "region",
         direction = "lower_is_better")

h <- file.path(tempdir(), "change.html")
yoy_html(y, h, title = "Placements by region")
file.exists(h)
#> [1] TRUE

p <- file.path(tempdir(), "change.pdf")
yoy_pdf(y, p, title = "Placements by region")
file.exists(p)
#> [1] TRUE

unlink(c(h, p))
```
