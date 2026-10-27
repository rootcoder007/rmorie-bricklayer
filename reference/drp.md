# Drop empty or constant columns and rows

`drpempty()` removes rows or columns that are entirely missing.
`drpconst()` removes columns that hold a single distinct value. They are
the counterparts of the janitor functions `remove_empty()` and
`remove_constant()`. Use them after reading a spreadsheet export, which
often carries blank padding rows, empty columns and columns that repeat
one value (a year, a jurisdiction) on every row.

## Usage

``` r
drpempty(data, which = c("rows", "cols"), quiet = FALSE)

drpconst(data, naasval = FALSE, quiet = FALSE)
```

## Arguments

- data:

  A data frame whose empty rows or columns are dropped.

- which:

  `"rows"`, `"cols"`, or both (the default, `c("rows", "cols")`).

- quiet:

  Logical: `TRUE` skips the boxed summary of what was dropped (rows and
  columns before and after, the columns removed), which is otherwise
  sent through [`message()`](https://rdrr.io/r/base/message.html);
  default `FALSE`.

- naasval:

  Logical: treat `NA` as a distinct value, so a column of `NA`s plus one
  real value counts as two (default `FALSE`).

## Value

The data frame, with the offending rows or columns removed. The names of
the columns that were dropped are attached as the `"dropped"` attribute
(a character vector, empty when none); dropped rows are not listed.

## Details

A constant column carries no information and breaks anything that scales
by variance, so it is worth removing – but it is also a FINDING. A
column that was informative in the pinned capsule and is constant in a
fresh fetch means the source changed, so check
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
before deleting it and moving on.

`drpempty()` removes all-`NA` columns first, then all-`NA` rows among
the remaining columns, and resets the row names. An empty string is a
value, not missing. `drpconst()` counts the distinct non-missing values
of each column (with `naasval = TRUE`, `NA` counts as a value), so an
all-`NA` column is also dropped by default. Neither function modifies
anything in place.

Errors: `data` not a data frame (or with missing or duplicated names);
`which` other than `"rows"` and/or `"cols"`.

## See also

[`profcols()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profcols.md),
which reports `n_distinct` without removing anything.

## Examples

``` r
df <- data.frame(
  keep = c(1, 2, NA),
  allna = c(NA, NA, NA),
  constant = c(7, 7, 7),
  stringsAsFactors = FALSE
)

drpempty(df)
#> ╭── Empty rows and columns dropped ─────────────────────────────╮
#> │   Before                         3 rows, 3 columns            │
#> │   After                          3 rows, 2 columns            │
#> │   Columns dropped (all missing)  allna                        │
#> │                                                               │
#> │   1 column and 0 rows dropped.                                │
#> │                                                               │
#> │   quiet = TRUE, or suppressMessages(), silences this summary. │
#> ╰───────────────────────────────────────────────────────────────╯
#>   keep constant
#> 1    1        7
#> 2    2        7
#> 3   NA        7
attr(drpempty(df), "dropped")
#> ╭── Empty rows and columns dropped ─────────────────────────────╮
#> │   Before                         3 rows, 3 columns            │
#> │   After                          3 rows, 2 columns            │
#> │   Columns dropped (all missing)  allna                        │
#> │                                                               │
#> │   1 column and 0 rows dropped.                                │
#> │                                                               │
#> │   quiet = TRUE, or suppressMessages(), silences this summary. │
#> ╰───────────────────────────────────────────────────────────────╯
#> [1] "allna"

drpconst(df)
#> ╭── Constant columns dropped ───────────────────────────────────╮
#> │   Before                       3 rows, 3 columns              │
#> │   After                        3 rows, 1 column               │
#> │   Columns dropped (one value)  allna, constant                │
#> │                                                               │
#> │   2 columns and 0 rows dropped.                               │
#> │                                                               │
#> │   quiet = TRUE, or suppressMessages(), silences this summary. │
#> ╰───────────────────────────────────────────────────────────────╯
#>   keep
#> 1    1
#> 2    2
#> 3   NA
attr(drpconst(df), "dropped")
#> ╭── Constant columns dropped ───────────────────────────────────╮
#> │   Before                       3 rows, 3 columns              │
#> │   After                        3 rows, 1 column               │
#> │   Columns dropped (one value)  allna, constant                │
#> │                                                               │
#> │   2 columns and 0 rows dropped.                               │
#> │                                                               │
#> │   quiet = TRUE, or suppressMessages(), silences this summary. │
#> ╰───────────────────────────────────────────────────────────────╯
#> [1] "allna"    "constant"

# Rows only.
drpempty(data.frame(a = c(1, NA), b = c(2, NA)), which = "rows")
#> ╭── Empty rows and columns dropped ─────────────────────────────╮
#> │   Before                         2 rows, 2 columns            │
#> │   After                          1 row, 2 columns             │
#> │   Columns dropped (all missing)  none                         │
#> │   Rows dropped                   1                            │
#> │                                                               │
#> │   0 columns and 1 row dropped.                                │
#> │                                                               │
#> │   quiet = TRUE, or suppressMessages(), silences this summary. │
#> ╰───────────────────────────────────────────────────────────────╯
#>   a b
#> 1 1 2

# A column of NAs plus one value is constant by default, and not when
# NA is treated as a value of its own.
x <- data.frame(v = c(NA, NA, 5))
ncol(drpconst(x))
#> ╭── Constant columns dropped ───────────────────────────────────╮
#> │   Before                       3 rows, 1 column               │
#> │   After                        3 rows, 0 columns              │
#> │   Columns dropped (one value)  v                              │
#> │                                                               │
#> │   1 column and 0 rows dropped.                                │
#> │                                                               │
#> │   quiet = TRUE, or suppressMessages(), silences this summary. │
#> ╰───────────────────────────────────────────────────────────────╯
#> [1] 0
ncol(drpconst(x, naasval = TRUE))
#> ╭── Constant columns dropped ───────────────────────────────────╮
#> │   Before                       3 rows, 1 column               │
#> │   After                        3 rows, 1 column               │
#> │   Columns dropped (one value)  none                           │
#> │                                                               │
#> │   Nothing to drop: the table came back as it was.             │
#> │                                                               │
#> │   quiet = TRUE, or suppressMessages(), silences this summary. │
#> ╰───────────────────────────────────────────────────────────────╯
#> [1] 1

# only data frames
try(drpempty(c(1, NA)))
#> Error : drpempty: `data` must be a data frame
```
