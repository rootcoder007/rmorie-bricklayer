# Render a change table to HTML or PDF

Writes a change table from
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
to a file for people who will not run R: `yoyhtml()` to a single
self-contained web page, `yoypdf()` to a PDF. Each row shows the period,
the value, the previous value, the change and the percent change,
coloured by whether it is better or worse, with the exact interval and
any flags; the HTML page also has summary cards from
[`yoysmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoysmry.md).
Use them to hand a reviewed set of period-over-period changes to a
manager, a journalist or a court.

## Usage

``` r
yoyhtml(
  x,
  file,
  title = "Year-over-year change",
  sub = NULL,
  pal = "diverging",
  digits = 1L,
  bars = TRUE,
  intv = TRUE,
  notes = NULL,
  ...
)

yoypdf(
  x,
  file,
  title = "Year-over-year change",
  sub = NULL,
  pal = "diverging",
  digits = 1L,
  intv = TRUE,
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

  Output path (a string). `yoyhtml()` writes a single self-contained
  HTML file with no external requests; `yoypdf()` writes a PDF using R's
  own device, so neither needs a package beyond base R.

- title:

  Heading for the page (and the HTML page title or PDF title), a string;
  default `"Year-over-year change"`.

- sub:

  Optional line under the heading. Defaults to the table's own settings
  – lag, units, interval and base gate – so the reader can see what the
  percentages mean.

- pal:

  One of
  [`yoypals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoypals.md):
  `"diverging"` (the default), `"safe"` or `"mono"`.

- digits:

  Digits for the percent column, default 1.

- bars:

  Logical (HTML only): draw an in-cell bar proportional to the change,
  scaled to the largest absolute change in the table (default `TRUE`).

- intv:

  Logical: show the exact interval column for counts (default `TRUE`).

- notes:

  Optional character vector of footnotes.

- ...:

  Ignored.

- width, height:

  PDF page size in inches (default 11 by 8.5, landscape US letter).

## Value

The path `file`, invisibly.

## Details

Neither backend needs a package beyond base R. The HTML page inlines its
stylesheet, makes no external requests (no fonts, scripts or images from
the network) and escapes every value, so the file stays the artefact and
renders the same later. Rows are coloured by the table's `verdict`:
`"worse"` in the palette's bad colour, `"better"` in its good colour,
everything else (including the `"up"` and `"down"` of
`direction = "neutral"`) in its neutral grey. Labels set with
[`yoylbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoylbl.md)
replace the period. For percentage units the change is shown in points.
The page ends with the package version that wrote it.

The PDF is drawn on R's own
[`pdf()`](https://rdrr.io/r/grDevices/pdf.html) device with its standard
fonts, which cannot draw arrows or dashes, so those are written in ASCII
(`+`, `-`). Long tables are split over pages at 0.22 inch per row, with
"page i of n" labels; notes go under the last page's rows when they fit
and on pages of their own otherwise. The interval column appears only
when the table has `pctlo` and `pctup` (counts).

Both overwrite `file`. Errors: `x` not from
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md);
a `pal` not in
[`yoypals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoypals.md);
a file that cannot be written.

## Examples

``` r
d <- data.frame(year = rep(2019:2023, each = 2),
                region = rep(c("North", "South"), 5),
                n = c(31, 402, 28, 377, 12, 190, 19, 268, 24, 331))
y <- yoy(d, value = "n", prd = "year", by = "region",
         dir = "lower")

h <- file.path(tempdir(), "change.html")
yoyhtml(y, h, title = "Placements by region")
file.exists(h)
#> [1] TRUE

p <- file.path(tempdir(), "change.pdf")
yoypdf(y, p, title = "Placements by region")
file.exists(p)
#> [1] TRUE

# a colour-blind-safe palette, no bars or intervals, and a footnote
yoyhtml(y, h, pal = "safe", bars = FALSE, intv = FALSE,
         notes = "Counts below 10 are suppressed at source.")
any(grepl("suppressed", readLines(h)))
#> [1] TRUE

# portrait letter pages, with fiscal-year labels
yoypdf(yoylbl(y, fylbl), p, width = 8.5, height = 11)

# only yoy() tables can be rendered
try(yoyhtml(d, h))
#> Error : `x` must be an rmbl_yoy object from yoy()
unlink(c(h, p))
```
