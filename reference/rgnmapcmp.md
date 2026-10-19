# Compare a recomputed region map against a published one

Matches two region maps on the unit identifier and compares the named
columns cell by cell, reporting for each column how many cells disagree
and the first disagreement. Use it to confirm that a region map rebuilt
from the boundary file (for example with
[`rgnmappts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmappts.md))
reproduces the one that was published or pinned.

## Usage

``` r
rgnmapcmp(pub, obs, unit, cols = NULL)
```

## Arguments

- pub:

  The region map as published (a data frame).

- obs:

  The region map as recomputed (a data frame).

- unit:

  Name of the unit identifier column, present in both.

- cols:

  Character vector of columns to compare. `NULL` (the default) compares
  every column the two share apart from `unit`.

## Value

A data frame, one row per compared column plus a first `"rows"` row for
units present on one side only, with columns `column` (character),
`cells` (integer: for `"rows"` the number of distinct units on either
side, otherwise the number of shared units compared), `mismatched`
(integer) and `first` (character, the first disagreement written out as
text, `""` when none). Zero `mismatched` throughout is the passing
result.

## Details

Units are matched by their identifier as text with spaces trimmed; when
an identifier repeats, its first row is used. Numeric columns are
compared with [`all.equal()`](https://rdrr.io/r/base/all.equal.html) at
its default tolerance (relative \\1.5 \times 10^{-8}\\), so a coordinate
that survived a round trip through text is not reported as a change;
everything else is compared exactly as text after trimming whitespace.
Two missing values agree; a missing value against a present one
disagrees.

What this establishes is that the recomputation reproduced the published
assignment. It does NOT establish that the assignment is right: run the
same method against the same boundary file and a definitional error
reproduces perfectly. That is what
[`rgnmapalt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapalt.md)
is for.

Errors: either input not a data frame or without `unit`; a column in
`cols` that is not in both.

## See also

[`rgnmapalt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapalt.md),
[`rgnmapintg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapintg.md)

## Examples

``` r
pub <- data.frame(
  inst = c("North Jail", "South Jail"),
  cd = c("3557", "3520"), stringsAsFactors = FALSE
)
obs <- pub
rgnmapcmp(pub, obs, "inst")
#>   column cells mismatched first
#> 1   rows     2          0      
#> 2     cd     2          0      

# a changed assignment is reported with the unit that moved
obs$cd[2] <- "3521"
rgnmapcmp(pub, obs, "inst")
#>   column cells mismatched                                       first
#> 1   rows     2          0                                            
#> 2     cd     2          1 South Jail: published 3520, recomputed 3521

# a unit on one side only, and a coordinate that only moved by rounding noise
pub$lat <- c(44.39, 43.65)
obs2 <- data.frame(inst = c("North Jail", "Hill Jail"), cd = c("3557", "3506"),
                   lat = c(44.39 + 1e-12, 45.1))
rgnmapcmp(pub, obs2, "inst", cols = c("cd", "lat"))
#>   column cells mismatched                      first
#> 1   rows     3          2 published only: South Jail
#> 2     cd     1          0                           
#> 3    lat     1          0                           

# a compared column must be in both maps
try(rgnmapcmp(pub, obs, "inst", cols = "lat"))
#> Error : both frames need the compared columns; missing: lat
```
