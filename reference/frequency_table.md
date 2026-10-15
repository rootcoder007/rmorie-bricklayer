# Frequency table for one column

Counts how often each value of a column occurs, with percentages of all
rows and of the non-missing rows, and missing values counted as their
own row. It is the first look at a categorical variable (a charge type,
a region, a response category), and the counterpart of
`janitor::tabyl()`.

## Usage

``` r
frequency_table(data, column = NULL, max_levels = 25L, sort = TRUE)
```

## Arguments

- data:

  A data frame, or a vector.

- column:

  Column name (a string), when `data` is a data frame; ignored for a
  vector.

- max_levels:

  Maximum value rows to return, most frequent first (default 25). The
  remainder are folded into one `"(other)"` row so the percentages still
  sum to 100.

- sort:

  Logical: sort by descending count (default `TRUE`); `FALSE` keeps the
  sorted order of the values.

## Value

A data frame of class `c("bricklayer_freq", "data.frame")` with columns
`value` (character), `n` (integer count), `pct` (numeric, percent of all
rows) and `pct_valid` (numeric, percent of non-missing rows; `NA` on the
missing row).

## Details

Two percentage columns, because both questions get asked and conflating
them is how missingness gets hidden: `pct` is the share of ALL rows,
`pct_valid` the share of rows where the value is present. When a column
is 40% missing those two differ enormously, and only the second
describes the values that are actually there.

Values are tabulated as text
([`as.character()`](https://rdrr.io/r/base/character.html)), so numbers
and factors are counted by their printed value, and factor levels that
do not occur get no row. Rows are sorted by descending count (ties in
the order [`table()`](https://rdrr.io/r/base/table.html) gives) or kept
in sorted value order with `sort = FALSE`. Beyond `max_levels` distinct
values, the rest are folded into one `"(other)"` row so the percentages
still sum to 100. The missing row, when there is one, comes last, with
`value` `NA` and `pct_valid` `NA`. An empty input gives a table with no
rows. The print method adds a bar column.

Errors: a data frame without `column`; a `column` that is not in `data`;
`max_levels` not one positive whole number.

## See also

[`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md)
for every column at once.

## Examples

``` r
df <- data.frame(grade = c("a", "b", "b", "c", NA, "b"),
                 stringsAsFactors = FALSE)
frequency_table(df, "grade")
#> ── Frequency table ─────────────────────────────────────────────── 
#>        value n  pct pct_valid                  bar
#>            b 3 50.0      60.0 ####################
#>            a 1 16.7      20.0              #######
#>            c 1 16.7      20.0              #######
#>  – (missing) 1 16.7         –              #######
#> ────────────────────────────────────────────────────────────────── 

# The two percentage columns differ exactly by the missingness.
frequency_table(df, "grade")[, c("pct", "pct_valid")]
#>        pct pct_valid
#> 1 50.00000        60
#> 2 16.66667        20
#> 3 16.66667        20
#> 4 16.66667        NA

# A vector works directly.
frequency_table(c(1, 1, 2, 3, 3, 3))
#> ── Frequency table ─────────────────────────────────────────────── 
#>  value n  pct pct_valid                  bar
#>      3 3 50.0      50.0 ####################
#>      1 2 33.3      33.3        #############
#>      2 1 16.7      16.7              #######
#> ────────────────────────────────────────────────────────────────── 

# Sorted value order rather than frequency order.
frequency_table(c("c", "a", "b", "a"), sort = FALSE)
#> ── Frequency table ─────────────────────────────────────────────── 
#>  value n  pct pct_valid                  bar
#>      a 2 50.0      50.0 ####################
#>      b 1 25.0      25.0           ##########
#>      c 1 25.0      25.0           ##########
#> ────────────────────────────────────────────────────────────────── 

# Long tails are folded so the percentages still total 100.
set.seed(1)
ft <- frequency_table(sample(letters, 500, TRUE), max_levels = 5)
ft
#> ── Frequency table ─────────────────────────────────────────────── 
#>    value   n  pct pct_valid                  bar
#>        y  25  5.0       5.0                    #
#>        e  24  4.8       4.8                    #
#>        t  24  4.8       4.8                    #
#>        a  23  4.6       4.6                    #
#>        f  23  4.6       4.6                    #
#>  (other) 381 76.2      76.2 ####################
#> ────────────────────────────────────────────────────────────────── 
sum(ft$pct)
#> [1] 100

# a data frame needs a column name
try(frequency_table(df))
#> Error : `column` is required when `data` is a data frame
```
