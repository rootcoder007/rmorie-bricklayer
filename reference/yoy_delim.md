# Write a change table as delimited text, JSON or Markdown

`yoy_csv()` separates fields with a comma and quotes any field that
contains one; `yoy_tsv()` separates with a tab and replaces any tab
inside a field, since a tab-separated field cannot contain one and
writing it would shift every column after it.

## Usage

``` r
yoy_csv(x, file, digits = NULL, na = "", metadata = TRUE, comment = "#", ...)

yoy_tsv(x, file, digits = NULL, na = "", metadata = TRUE, comment = "#", ...)

yoy_json(x, file, digits = NULL, pretty = TRUE, ...)

yoy_markdown(x, file, digits = 1L, align = TRUE, ...)
```

## Arguments

- x:

  An `rmbl_yoy` object from
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).

- file:

  Output path, or `NULL` to return the text instead of writing it.

- digits:

  Digits for the percent columns. `NULL`, the default, writes them
  unrounded, which is what a downstream calculation wants; give a number
  for a figure meant to be read.

- na:

  How to write a missing value. The default empty string is what most
  readers expect; `"NA"` keeps R's own spelling.

- metadata:

  Whether to lead with comment lines recording the lag, units,
  confidence level, base gate and direction. On by default, because a
  percent column means different things under different settings and the
  file is the only place a later reader can look. Markdown and JSON
  carry the same information structurally.

- comment:

  Comment prefix for the metadata lines.

- ...:

  Ignored.

- pretty:

  Whether to indent the JSON.

- align:

  Whether to pad the Markdown columns so the source table is readable
  unrendered.

## Value

The path, invisibly; or the text, when `file` is `NULL`.

## Examples

``` r
d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
y <- yoy(d, value = "n", period = "year")

# Straight to text, for inspection.
cat(yoy_csv(y, NULL))
#> # value: n; period: year; lag: 1; units: count; interval: 95% exact rate ratio; percent withheld below a base of 20
#> year,value,previous,change,pct_change,flag,pct_lower,pct_upper,verdict
#> 2019,402,,,,no comparison period,,,
#> 2020,377,402,-25,-6.21890547263682,,-18.7301481792582,8.20024314312362,down
#> 2021,190,377,-187,-49.6021220159151,,-57.8921768223217,-39.8426144902702,down
#> 2022,268,190,78,41.0526315789474,,16.6890230584617,70.7750209773721,up
#> 2023,331,268,63,23.5074626865672,,4.81624015357676,45.6380333585367,up

# Markdown, for a report.
cat(yoy_markdown(y, NULL))
#> | year | n   | previous | change | change % |     interval | note                 |
#> | ---- | --- | -------- | -----: | -------: | -----------: | -------------------- |
#> | 2019 | 402 | —        |      — |        — |              | no comparison period |
#> | 2020 | 377 | 402      |    -25 |    -6.2% |  [-19%, +8%] |                      |
#> | 2021 | 190 | 377      |   -187 |   -49.6% | [-58%, -40%] |                      |
#> | 2022 | 268 | 190      |     78 |   +41.1% | [+17%, +71%] |                      |
#> | 2023 | 331 | 268      |     63 |   +23.5% |  [+5%, +46%] |                      |
#> 
#> _value: n; period: year; lag: 1; units: count; interval: 95% exact rate ratio; percent withheld below a base of 20_

# JSON keeps the settings as fields rather than as comments.
substr(yoy_json(y, NULL), 1, 80)
#> [1] "{\n  \"settings\": {\n    \"value\": \"n\",\n    \"period\": \"year\",\n    \"lag\": 1,\n    \"uni"
```
