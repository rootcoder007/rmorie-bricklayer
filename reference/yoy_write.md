# Write a change table to a file, in whatever format the name implies

Write a change table to a file, in whatever format the name implies

## Usage

``` r
yoy_write(x, file, format = "auto", ...)
```

## Arguments

- x:

  An `rmbl_yoy` object from
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).

- file:

  Output path.

- format:

  Output format. `"auto"` reads it from the file extension: `.html` /
  `.htm`, `.pdf`, `.csv`, `.tsv` / `.tab`, `.json`, `.md` / `.markdown`.

- ...:

  Passed to the format's own writer, so the colour, digit and layout
  options of
  [`yoy_html()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md)
  and
  [`yoy_pdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md)
  are available here too.

## Value

The path, invisibly.

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
#> csv 519 bytes
#> tsv 519 bytes
#> json 1553 bytes
#> md 712 bytes
#> html 4872 bytes
```
