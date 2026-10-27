# Write a change table as delimited text, JSON or Markdown

`yoycsv()` separates fields with a comma and quotes any field that
contains one; `yoytsv()` separates with a tab and replaces any tab
inside a field, since a tab-separated field cannot contain one and
writing it would shift every column after it. `yoyjs()` writes an object
with `settings` (value, period, grouping, lag, units, minimum base,
confidence level, direction), `summary` (from
[`yoysmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoysmry.md))
and `rows`, using the package's own JSON codec. `yoymd()` writes a pipe
table meant for reading: values formatted (every numeric column
right-aligned), percentages signed and rounded, the interval as
`[lower, upper]`, notes in the last column, and the settings in an
italic line under the table.

## Usage

``` r
yoycsv(x, file, digits = NULL, na = "", meta = TRUE, comment = "#", ...)

yoytsv(x, file, digits = NULL, na = "", meta = TRUE, comment = "#", ...)

yoyjs(x, file, digits = NULL, pretty = TRUE, ...)

yoymd(x, file, digits = 1L, align = TRUE, ...)
```

## Arguments

- x:

  An `rmbl_yoy` object from
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).

- file:

  Character scalar, the output path, or `NULL` to return the text
  instead of writing it.

- digits:

  A whole number from 0 to 15, or `NULL`: decimal places for the percent
  columns. For the CSV, TSV and JSON writers `NULL`, the default, writes
  them unrounded, which is what a downstream calculation wants; give a
  number for a figure meant to be read. For `yoymd()` the default is
  `1`.

- na:

  Character scalar, how to write a missing value (CSV and TSV). The
  default empty string is what most readers expect; `"NA"` keeps R's own
  spelling.

- meta:

  Whether to lead with comment lines recording the lag, units,
  confidence level, base gate and direction. On by default, because a
  percent column means different things under different settings and the
  file is the only place a later reader can look. Markdown and JSON
  carry the same information structurally.

- comment:

  Character scalar, the comment prefix for the metadata lines; default
  `"#"`.

- ...:

  Ignored: what
  [`yoywr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoywr.md)
  passes on for its HTML and PDF writers.

- pretty:

  Logical scalar, default `TRUE`: indent the JSON.

- align:

  Logical scalar, default `TRUE`: pad the Markdown columns so the source
  table is readable unrendered.

## Value

`file`, invisibly; or, when `file` is `NULL`, the text as a character
scalar.

## Details

The CSV and TSV writers export every column of the object (the period
and grouping columns, `value`, `previous`, `change`, the percent or
percentage-point change, `flag`, the interval and `verdict`), so the
note explaining a missing or flagged figure stays with its row. Quoting
in the CSV follows RFC 4180 (a field with a comma, a quote or a line
break is quoted, quotes doubled). The metadata line names the value and
period columns, the grouping, the lag, the units, and for counts the
interval's confidence level and the base below which changes are noted.
A pipe inside a Markdown cell is escaped. An existing file is
overwritten. Errors when `x` does not come from
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md),
or `digits` is not a whole number.

## Examples

``` r
d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
y <- yoy(d, value = "n", prd = "year")

# Straight to text, for inspection.
cat(yoycsv(y, NULL))
#> # value: n; period: year; lag: 1; units: count; interval: 95% exact rate ratio
#> year,value,previous,change,pctchg,flag,pctlo,pctup,verdict
#> 2019,402,,,,no comparison period,,,
#> 2020,377,402,-25,-6.21890547263682,,-18.7301481792582,8.20024314312362,down
#> 2021,190,377,-187,-49.6021220159151,,-57.8921768223217,-39.8426144902702,down
#> 2022,268,190,78,41.0526315789474,,16.6890230584617,70.7750209773721,up
#> 2023,331,268,63,23.5074626865672,,4.81624015357676,45.6380333585367,up

# Markdown, for a report.
cat(yoymd(y, NULL))
#> | year |   n | previous | change | change % |     interval | note                 |
#> | ---- | --: | -------: | -----: | -------: | -----------: | -------------------- |
#> | 2019 | 402 |        — |      — |        — |              | no comparison period |
#> | 2020 | 377 |      402 |    -25 |    -6.2% |  [-19%, +8%] |                      |
#> | 2021 | 190 |      377 |   -187 |   -49.6% | [-58%, -40%] |                      |
#> | 2022 | 268 |      190 |     78 |   +41.1% | [+17%, +71%] |                      |
#> | 2023 | 331 |      268 |     63 |   +23.5% |  [+5%, +46%] |                      |
#> 
#> _value: n; period: year; lag: 1; units: count; interval: 95% exact rate ratio_

# JSON keeps the settings as fields rather than as comments.
substr(yoyjs(y, NULL), 1, 80)
#> [1] "{\n  \"settings\": {\n    \"value\": \"n\",\n    \"period\": \"year\",\n    \"lag\": 1,\n    \"uni"

# rounded percentages, no metadata line, and R's own NA
cat(yoytsv(y, NULL, digits = 1, meta = FALSE, na = "NA"))
#> year value   previous    change  pctchg  flag    pctlo   pctup   verdict
#> 2019 402 NA  NA  NA  no comparison period    NA  NA  NA
#> 2020 377 402 -25 -6.2    NA  -18.7   8.2 down
#> 2021 190 377 -187    -49.6   NA  -57.9   -39.8   down
#> 2022 268 190 78  41.1    NA  16.7    70.8    up
#> 2023 331 268 63  23.5    NA  4.8 45.6    up

# written to a file
f <- tempfile(fileext = ".csv")
yoycsv(y, f)
read.csv(f, comment.char = "#")[, c("year", "pctchg", "flag")]
#>   year     pctchg                 flag
#> 1 2019         NA no comparison period
#> 2 2020  -6.218905                     
#> 3 2021 -49.602122                     
#> 4 2022  41.052632                     
#> 5 2023  23.507463                     

# only yoy() results are accepted
try(yoycsv(d, NULL))
#> Error : yoycsv: `x` must be an rmbl_yoy object from yoy()
```
