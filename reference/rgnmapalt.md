# Check a region map against an independently derived assignment

Compares the region each unit was assigned with the region a DIFFERENT
method assigns it, and marks the disagreements that are already known
and explained. Use it to catch errors in the method that built the map,
which re-running that same method can never find.

## Usage

``` r
rgnmapalt(map, unit, reg, route, known = character())
```

## Arguments

- map:

  Data frame, one row per unit.

- unit:

  Name of the unit identifier column (a string).

- reg:

  Name of the assigned region column (a string).

- route:

  Named character vector (names are units, values regions), or a data
  frame with the same two column names as `map`, giving the second
  method's assignment. Units it does not cover, and entries that are
  `NA` or blank, are skipped rather than counted as disagreements.

- known:

  Character vector of units whose disagreement is expected and
  documented – the cases the second route is known to get wrong. Default
  none.

## Value

A data frame of disagreements, sorted with unexplained ones first, with
the columns `unit`, `primary` (the map's region), `second` (the route's
region), all character, and `known` (logical). `sum(!x$known)` is the
number of unexplained disagreements and zero is the passing value;
`nrow(x)` should equal the number of documented cases, because a
documented case that stops disagreeing means the second route changed
underneath the documentation.

## Details

This is the only check here that can catch an error in the original
method, because it does not use that method. Recomputing point in
polygon against the same boundary file proves the pipeline is
deterministic; deriving the region a second way – from a name, a postal
geography, an administrative lookup – can disagree, and a disagreement
is information either way round.

The `known` argument exists because a second route usually has
understood weaknesses: a place name that is a community rather than a
municipality, an amalgamated city, a township absorbed into a neighbour.
Listing them keeps the check sharp instead of loosening the tolerance
until everything passes, and listing them by NAME means an unexpected
disagreement cannot hide inside an allowance.

Units and regions are compared as text with spaces trimmed. Errors:
`map` not a data frame or without the named columns; a `route` vector
without names; a `route` data frame without the two columns.

## See also

[`rgnmapcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapcmp.md),
[`rgnmapintg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapintg.md)

## Examples

``` r
cw <- data.frame(
  inst = c("North Jail", "South Jail", "Hill Jail"),
  cd = c("3557", "3520", "3506"),
  stringsAsFactors = FALSE
)

# a name-based route that is known to mis-place one unit
route <- c(
  "North Jail" = "3557",
  "South Jail" = "3520",
  "Hill Jail" = "3519"
)
rgnmapalt(cw, "inst", "cd", route, known = "Hill Jail")
#>        unit primary second known
#> 1 Hill Jail    3506   3519  TRUE

# an undocumented disagreement is what the check is for
route["South Jail"] <- "3521"
d <- rgnmapalt(cw, "inst", "cd", route, known = "Hill Jail")
sum(!d$known)
#> [1] 1

# the route as a data frame with the same column names
routedf <- data.frame(
  inst = c("North Jail", "Hill Jail"),
  cd = c("3557", "3506")
)
nrow(rgnmapalt(cw, "inst", "cd", routedf))
#> [1] 0

# an unnamed vector cannot be matched to units
try(rgnmapalt(cw, "inst", "cd", c("3557", "3520")))
#> Error : `route` must be named by unit, or be a data frame
```
