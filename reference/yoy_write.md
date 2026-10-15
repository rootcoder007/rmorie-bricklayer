# Write a change table to a file, in whatever format the name implies

Writes a period-over-period table from
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
in the format the file name implies, so one call serves a web page, a
PDF for a report, a CSV for a spreadsheet, JSON for a program or
Markdown for a README. Every format is written from the same object,
with each row's note attached, so the number a reader sees and the
number a pipeline reads are the same.

## Usage

``` r
yoy_write(x, file, format = "auto", ...)
```

## Arguments

- x:

  An `rmbl_yoy` object from
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).

- file:

  Character scalar, the output path.

- format:

  Character scalar, the output format: `"auto"` (the default) reads it
  from the file extension; otherwise one of `"html"`, `"pdf"`, `"csv"`,
  `"tsv"`, `"json"` or `"markdown"` (case-insensitive).

- ...:

  Passed to the format's own writer, so the colour, digit and layout
  options of
  [`yoy_html()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md)
  and
  [`yoy_pdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md)
  are available here too.

## Value

`file`, invisibly (as returned by the chosen writer).

## Details

The extension is matched case-insensitively: `.html` and `.htm` go to
[`yoy_html()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md),
`.pdf` to
[`yoy_pdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md),
`.csv` to
[`yoy_csv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md),
`.tsv` and `.tab` to
[`yoy_tsv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md),
`.json` to
[`yoy_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md),
`.md` and `.markdown` to
[`yoy_markdown()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md).
An existing file is overwritten. Errors when `x` does not come from
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md),
when the format cannot be read from the extension (pass `format`), or
when `format` is not one of the names below; and whatever error the
chosen writer raises.

## See also

[`yoy_html()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md),
[`yoy_pdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md),
[`yoy_csv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md)

## Examples

``` r
d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
y <- yoy(d, value = "n", period = "year")

for (ext in c("csv", "tsv", "json", "md", "html")) {
  f <- file.path(tempdir(), paste0("change.", ext))
  yoy_write(y, f)
  cat(ext, file.size(f), "bytes\n")
  unlink(f)
}
#> csv 482 bytes
#> tsv 482 bytes
#> json 1552 bytes
#> md 675 bytes
#> html 4828 bytes

# an extension that names no format: say which one
f <- file.path(tempdir(), "change.txt")
yoy_write(y, f, format = "csv", digits = 1)
readLines(f, n = 3)
#> [1] "# value: n; period: year; lag: 1; units: count; interval: 95% exact rate ratio"
#> [2] "year,value,previous,change,pct_change,flag,pct_lower,pct_upper,verdict"        
#> [3] "2019,402,,,,no comparison period,,,"                                           
unlink(f)
try(yoy_write(y, file.path(tempdir(), "change.xlsx")))
#> Error : cannot tell the format from "change.xlsx"; pass format = explicitly
```
