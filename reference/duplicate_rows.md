# Duplicated rows, with their groups

Returns the rows that share a combination of `columns` with at least one
other row, grouped so the duplicates sit together. The counterpart of
`janitor::get_dupes()`.

## Usage

``` r
duplicate_rows(data, columns = NULL)
```

## Arguments

- data:

  A data frame.

- columns:

  Columns defining a duplicate (default: all of them).

## Value

The duplicated rows, ordered by group, with a `dupe_count` column giving
each group's size. Zero rows when there are none.

## Details

[`rule_distinct_rows()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
tells you THAT there are duplicates, which is what a validation gate
needs. This shows you WHICH, which is what fixing them needs – and a
duplicate is usually a join that fanned out or a re-release appended
rather than replaced, both of which are visible only once the offending
rows are in front of you.

## See also

[`rule_distinct_rows()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md),
[`rule_unique()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)

## Examples

``` r
df <- data.frame(id = c(1, 2, 2, 3, 3, 3),
                 value = c("a", "b", "b", "c", "d", "c"),
                 stringsAsFactors = FALSE)

# Duplicated on every column.
duplicate_rows(df)
#>   id value dupe_count
#> 1  2     b          2
#> 2  2     b          2
#> 3  3     c          2
#> 4  3     c          2

# Duplicated on the identifier alone, which catches more.
duplicate_rows(df, "id")
#>   id value dupe_count
#> 1  2     b          2
#> 2  2     b          2
#> 3  3     c          3
#> 4  3     d          3
#> 5  3     c          3

# No duplicates gives zero rows, not an error.
duplicate_rows(data.frame(x = 1:3))
#> [1] x          dupe_count
#> <0 rows> (or 0-length row.names)
```
