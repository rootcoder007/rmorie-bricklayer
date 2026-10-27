# Duplicated rows, with their groups

Returns the rows that share a combination of `cols` with at least one
other row, grouped so the duplicates sit together. The counterpart of
`janitor::get_dupes()`.

## Usage

``` r
duprows(data, cols = NULL, quiet = FALSE)
```

## Arguments

- data:

  A data frame whose rows are checked for duplicates.

- cols:

  Character vector of the columns defining a duplicate, or `NULL` (the
  default) for all of them.

- quiet:

  Logical: `TRUE` skips the boxed count of duplicate rows and groups,
  which is otherwise sent through
  [`message()`](https://rdrr.io/r/base/message.html); default `FALSE`.

## Value

A data frame: the duplicated rows (every occurrence, including the
first), ordered so each group sits together, with an integer
`dupe_count` column giving each group's size and row names reset. Zero
rows (with the same columns) when there are none.

## Details

[`ruledstn()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
tells you THAT there are duplicates, which is what a validation gate
needs. This shows you WHICH, which is what fixing them needs – and a
duplicate is usually a join that fanned out or a re-release appended
rather than replaced, both of which are visible only once the offending
rows are in front of you.

Two rows are duplicates when their values, converted to text, are equal
in every column of `cols`; two `NA`s are equal. Columns are taken by
position when `cols = NULL`, so a table with repeated column names can
still be inspected. Errors when `data` is not a data frame, a named
column does not exist, or a named column's name is shared by two
columns.

## See also

[`ruledstn()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md),
[`ruleuniq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)

## Examples

``` r
df <- data.frame(
  id = c(1, 2, 2, 3, 3, 3),
  value = c("a", "b", "b", "c", "d", "c"),
  stringsAsFactors = FALSE
)

# Duplicated on every column.
duprows(df)
#> ╭── Duplicate rows ───────────────────────────────────────────────────────────╮
#> │   Table           6 rows, 2 columns                                         │
#> │   Compared on     every column                                              │
#> │   Duplicate rows  4                                                         │
#> │   Groups          2                                                         │
#> │   Extra copies    2                                                         │
#> │                                                                             │
#> │   4 rows fall in 2 groups of identical rows: dropping the repeats would     │
#> │   remove 2.                                                                 │
#> │                                                                             │
#> │   quiet = TRUE, or suppressMessages(), silences this summary.               │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
#>   id value dupe_count
#> 1  2     b          2
#> 2  2     b          2
#> 3  3     c          2
#> 4  3     c          2

# Duplicated on the identifier alone, which catches more.
duprows(df, "id")
#> ╭── Duplicate rows ───────────────────────────────────────────────────────────╮
#> │   Table           6 rows, 2 columns                                         │
#> │   Compared on     id                                                        │
#> │   Duplicate rows  5                                                         │
#> │   Groups          2                                                         │
#> │   Extra copies    3                                                         │
#> │                                                                             │
#> │   5 rows fall in 2 groups of identical rows: dropping the repeats would     │
#> │   remove 3.                                                                 │
#> │                                                                             │
#> │   quiet = TRUE, or suppressMessages(), silences this summary.               │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
#>   id value dupe_count
#> 1  2     b          2
#> 2  2     b          2
#> 3  3     c          3
#> 4  3     d          3
#> 5  3     c          3

# No duplicates gives zero rows, not an error.
duprows(data.frame(x = 1:3))
#> ╭── Duplicate rows ─────────────────────────────────────────────╮
#> │   Table           3 rows, 1 column                            │
#> │   Compared on     every column                                │
#> │   Duplicate rows  0                                           │
#> │   Groups          0                                           │
#> │   Extra copies    0                                           │
#> │                                                               │
#> │   No two rows are the same on these columns.                  │
#> │                                                               │
#> │   quiet = TRUE, or suppressMessages(), silences this summary. │
#> ╰───────────────────────────────────────────────────────────────╯
#> [1] x          dupe_count
#> <0 rows> (or 0-length row.names)

# a column that does not exist is an error
try(duprows(df, "code"))
#> Error : no such column(s): code
```
