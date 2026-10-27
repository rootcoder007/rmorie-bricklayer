# Frequency table for one column

Counts how often each value of a column occurs, with percentages of all
rows and of the non-missing rows, and missing values counted as their
own row. It is the first look at a categorical variable (a charge type,
a region, a response category), and the counterpart of
`janitor::tabyl()`.

## Usage

``` r
freqtbl(data, col = NULL, maxlvl = 25L, sort = TRUE)
```

## Arguments

- data:

  A data frame, or a vector.

- col:

  Column name (a string), when `data` is a data frame; ignored for a
  vector.

- maxlvl:

  Maximum value rows to return, most frequent first (default 25). The
  remainder are folded into one `"(other)"` row so the percentages still
  sum to 100.

- sort:

  Logical: sort by descending count (default `TRUE`); `FALSE` keeps the
  sorted order of the values.

## Value

A data frame of class `c("bricklayer_freq", "data.frame")` with columns
`value` (character), `n` (integer count), `pct` (numeric, percent of all
rows) and `pctvalid` (numeric, percent of non-missing rows; `NA` on the
missing row).

## Details

Two percentage columns, because both questions get asked and conflating
them is how missingness gets hidden: `pct` is the share of ALL rows,
`pctvalid` the share of rows where the value is present. When a column
is 40% missing those two differ enormously, and only the second
describes the values that are actually there.

Values are tabulated as text
([`as.character()`](https://rdrr.io/r/base/character.html)), so numbers
and factors are counted by their printed value, and factor levels that
do not occur get no row. Rows are sorted by descending count (ties in
the order [`table()`](https://rdrr.io/r/base/table.html) gives) or kept
in sorted value order with `sort = FALSE`. Beyond `maxlvl` distinct
values, the rest are folded into one `"(other)"` row so the percentages
still sum to 100. The missing row, when there is one, comes last, with
`value` `NA` and `pctvalid` `NA`. An empty input gives a table with no
rows. The print method adds a bar column.

Errors: a data frame without `col`; a `col` that is not in `data`;
`maxlvl` not one positive whole number.

## See also

[`profcols()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profcols.md)
for every column at once.

## Examples

``` r
df <- data.frame(grade = c("a", "b", "b", "c", NA, "b"),
                 stringsAsFactors = FALSE)
freqtbl(df, "grade")
#> ╭── Frequency table ──────────────────────────────────────────────────────╮
#> │   Values        6                                                       │
#> │   Levels shown  3                                                       │
#> │   Missing       1                                                       │
#> │                                                                         │
#> │   value        n    pct  pctvalid  bar                                  │
#> │   -----------  -  -----  --------  --------------------                 │
#> │   b            3  50.00        60  ####################                 │
#> │   a            1  16.70        20  #######                              │
#> │   c            1  16.70        20  #######                              │
#> │   – (missing)  1  16.70            #######                              │
#> │                                                                         │
#> │   pct is the share of all values, pctvalid the share of the non-missing │
#> │   ones; the bar is scaled to the commonest level.                       │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# The two percentage columns differ exactly by the missingness.
freqtbl(df, "grade")[, c("pct", "pctvalid")]
#> ╭── Frequency table ────────────────────────────────────────────────────╮
#> │   Rows     4                                                          │
#> │   Columns  2                                                          │
#> │                                                                       │
#> │     pct  pctvalid                                                     │
#> │   -----  --------                                                     │
#> │   50.00        60                                                     │
#> │   16.67        20                                                     │
#> │   16.67        20                                                     │
#> │   16.67                                                               │
#> │                                                                       │
#> │   Some of this result's columns are not here (a subset of it?), so it │
#> │   is shown as a plain table.                                          │
#> ╰───────────────────────────────────────────────────────────────────────╯

# A vector works directly.
freqtbl(c(1, 1, 2, 3, 3, 3))
#> ╭── Frequency table ──────────────────────────────────────────────────────╮
#> │   Values        6                                                       │
#> │   Levels shown  3                                                       │
#> │   Missing       0                                                       │
#> │                                                                         │
#> │   value  n    pct  pctvalid  bar                                        │
#> │   -----  -  -----  --------  --------------------                       │
#> │   3      3  50.00     50.00  ####################                       │
#> │   1      2  33.30     33.30  #############                              │
#> │   2      1  16.70     16.70  #######                                    │
#> │                                                                         │
#> │   pct is the share of all values, pctvalid the share of the non-missing │
#> │   ones; the bar is scaled to the commonest level.                       │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# Sorted value order rather than frequency order.
freqtbl(c("c", "a", "b", "a"), sort = FALSE)
#> ╭── Frequency table ──────────────────────────────────────────────────────╮
#> │   Values        4                                                       │
#> │   Levels shown  3                                                       │
#> │   Missing       0                                                       │
#> │                                                                         │
#> │   value  n  pct  pctvalid  bar                                          │
#> │   -----  -  ---  --------  --------------------                         │
#> │   a      2   50        50  ####################                         │
#> │   b      1   25        25  ##########                                   │
#> │   c      1   25        25  ##########                                   │
#> │                                                                         │
#> │   pct is the share of all values, pctvalid the share of the non-missing │
#> │   ones; the bar is scaled to the commonest level.                       │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# Long tails are folded so the percentages still total 100.
set.seed(1)
ft <- freqtbl(sample(letters, 500, TRUE), maxlvl = 5)
ft
#> ╭── Frequency table ──────────────────────────────────────────────────────╮
#> │   Values        500                                                     │
#> │   Levels shown  6                                                       │
#> │   Missing       0                                                       │
#> │                                                                         │
#> │   value      n     pct  pctvalid  bar                                   │
#> │   -------  ---  ------  --------  --------------------                  │
#> │   y         25   5.000     5.000  #                                     │
#> │   e         24   4.800     4.800  #                                     │
#> │   t         24   4.800     4.800  #                                     │
#> │   a         23   4.600     4.600  #                                     │
#> │   f         23   4.600     4.600  #                                     │
#> │   (other)  381  76.200    76.200  ####################                  │
#> │                                                                         │
#> │   pct is the share of all values, pctvalid the share of the non-missing │
#> │   ones; the bar is scaled to the commonest level.                       │
#> ╰─────────────────────────────────────────────────────────────────────────╯
sum(ft$pct)
#> [1] 100

# a data frame needs a column name
try(freqtbl(df))
#> Error : `col` is required when `data` is a data frame
```
