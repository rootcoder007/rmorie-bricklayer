# Compare a recomputed region map against a published one

Matches two region maps on the unit identifier and compares the named
columns cell by cell.

## Usage

``` r
region_map_compare(published, observed, unit, cols = NULL)
```

## Arguments

- published:

  The region map as published.

- observed:

  The region map as recomputed.

- unit:

  Name of the unit identifier column, present in both.

- cols:

  Columns to compare. Defaults to every column the two share apart from
  `unit`.

## Value

A data frame, one row per compared column plus a `rows` row for units
present on one side only: `column`, `cells`, `mismatched` and `first`,
the first disagreement written out as text. Zero `mismatched` throughout
is the passing result.

## Details

Numeric columns are compared with
[`all.equal()`](https://rdrr.io/r/base/all.equal.html) at its default
tolerance, so a coordinate that survived a round trip through text is
not reported as a change; everything else is compared exactly after
trimming whitespace.

What this establishes is that the recomputation reproduced the published
assignment. It does NOT establish that the assignment is right: run the
same method against the same boundary file and a definitional error
reproduces perfectly. That is what
[`region_map_second_route()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_second_route.md)
is for.

## See also

[`region_map_second_route()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_second_route.md),
[`region_map_integrity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_integrity.md)

## Examples

``` r
pub <- data.frame(inst = c("North Jail", "South Jail"),
                  cd = c("3557", "3520"), stringsAsFactors = FALSE)
obs <- pub
region_map_compare(pub, obs, "inst")
#>   column cells mismatched first
#> 1   rows     2          0      
#> 2     cd     2          0      

# a changed assignment is reported with the unit that moved
obs$cd[2] <- "3521"
region_map_compare(pub, obs, "inst")
#>   column cells mismatched                                       first
#> 1   rows     2          0                                            
#> 2     cd     2          1 South Jail: published 3520, recomputed 3521
```
