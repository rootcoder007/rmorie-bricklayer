# Check a crosswalk against an independently derived assignment

Compares the region each unit was assigned with the region a DIFFERENT
method assigns it, and marks the disagreements that are already known
and explained.

## Usage

``` r
crosswalk_second_route(crosswalk, unit, region, route, known = character())
```

## Arguments

- crosswalk:

  Data frame, one row per unit.

- unit:

  Name of the unit identifier column.

- region:

  Name of the assigned region column.

- route:

  Named character vector, or a data frame with the same two column
  names, giving the second method's assignment. Units it does not cover
  are skipped rather than counted as disagreements.

- known:

  Units whose disagreement is expected and documented – the cases the
  second route is known to get wrong.

## Value

A data frame of disagreements: `unit`, `primary`, `second` and `known`.
`sum(!x$known)` is the number of unexplained disagreements and zero is
the passing value; `nrow(x)` should equal the number of documented
cases, because a documented case that stops disagreeing means the second
route changed underneath the documentation.

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

## See also

[`crosswalk_compare()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crosswalk_compare.md),
[`crosswalk_integrity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crosswalk_integrity.md)

## Examples

``` r
cw <- data.frame(inst = c("North Jail", "South Jail", "Hill Jail"),
                 cd = c("3557", "3520", "3506"),
                 stringsAsFactors = FALSE)

# a name-based route that is known to mis-place one unit
route <- c("North Jail" = "3557", "South Jail" = "3520",
           "Hill Jail" = "3519")
crosswalk_second_route(cw, "inst", "cd", route, known = "Hill Jail")
#>        unit primary second known
#> 1 Hill Jail    3506   3519  TRUE

# an undocumented disagreement is what the check is for
route["South Jail"] <- "3521"
d <- crosswalk_second_route(cw, "inst", "cd", route, known = "Hill Jail")
sum(!d$known)
#> [1] 1
```
