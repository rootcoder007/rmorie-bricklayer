# Population of the regions that contain a unit, and of those that do not

Summarises where a set of point-located units (jails, courthouses,
hospitals, police stations) sits relative to the regions of a
statistical geography: how many regions hold at least one unit, and what
share of the population lives in them. Use it to describe the footprint
of a set of facilities, not to build a per-capita rate (see Details).

## Usage

``` r
region_coverage(region, population, units)
```

## Arguments

- region:

  Region identifiers, one per region, not repeated (character, or
  anything that converts to it; surrounding spaces are trimmed).

- population:

  Population of each region, same length and order, non-negative
  numbers.

- units:

  Number of units located in each region, same length and order,
  non-negative whole numbers. Zero is the expected value for most
  regions in most geographies.

## Value

A data frame of class `c("rmbl_region_coverage", "data.frame")`, one row
per region, with the columns `region` (character), `population`
(numeric), `units` (numeric), `has_unit` (logical) and `pop_share`
(numeric, percent of the total population), ordered by units then
population, both descending. The totals are carried on the `coverage`
attribute, a list of `regions`, `with_unit`, `without_unit`, `units`,
`total_population`, `covered_population`, `uncovered_population` and
`covered_share` (percent), and printed by the print method (which shows
the first `n = 10` regions).

## Details

The share this returns is CONTEXT, not a denominator, and the
distinction is the reason the function exists rather than a bare
[`tapply()`](https://rdrr.io/r/base/tapply.html).

A region holding no unit is not an unserved population. Units serve
catchments, and a catchment is an administrative fact about where people
are sent from; a point location does not state it and cannot imply it.
Some geographies were never meant to have one unit each.

So a rate built by summing the populations of unit-holding regions pairs
a denominator covering part of the territory with a numerator drawn from
all of it. Every such rate is inflated, and inflated unevenly: a dense
region holding one unit and a sparse region holding seven distort it in
opposite directions. Where numerator and denominator must cover the same
population, the defensible figure is the whole-territory one.

The print method says this each time, because the covered share is
precisely the number a reader is tempted to divide by. With a total
population of zero the shares are `NA`.

Errors: empty, missing or repeated `region` values; arguments of
different lengths; missing or negative `population`; missing, negative
or fractional `units`.

## See also

[`region_map_integrity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_integrity.md),
[`region_map_compare()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_compare.md),
[`region_map_second_route()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_second_route.md)

## Examples

``` r
# Four regions, two of which hold a facility.
cov <- region_coverage(
  region = c("A", "B", "C", "D"),
  population = c(1200000, 800000, 450000, 90000),
  units = c(3, 0, 1, 0)
)
cov
#> ── 4 units in 2 of 4 regions ───────────────────────────────────── 
#>   those regions hold 1,650,000 of 2,540,000 residents (65.0%)
#>   2 regions hold none; 890,000 residents (35.0%) live there
#> 
#>  region population units has_unit pop_share
#>       A    1200000     3     TRUE 47.244094
#>       C     450000     1     TRUE 17.716535
#>       B     800000     0    FALSE 31.496063
#>       D      90000     0    FALSE  3.543307
#> 
#>   The covered share is context, not a denominator: units serve
#>   catchments, so a rate over these regions alone would take its
#>   numerator from the whole territory and is inflated.
#> ────────────────────────────────────────────────────────────────── 

# The covered share is reported, and is not a rate denominator.
attr(cov, "coverage")$covered_share
#> [1] 64.96063
attr(cov, "coverage")[c("with_unit", "uncovered_population")]
#> $with_unit
#> [1] 2
#> 
#> $uncovered_population
#> [1] 890000
#> 

# counting units per region from a facility list first
fac <- c("C", "A", "A", "A")
regions <- c("A", "B", "C", "D")
units <- as.vector(table(factor(fac, levels = regions)))
region_coverage(regions, c(1200000, 800000, 450000, 90000), units)$has_unit
#> [1]  TRUE  TRUE FALSE FALSE

# a region listed twice is refused
try(region_coverage(c("A", "A"), c(10, 20), c(1, 0)))
#> Error : `region` must not repeat: one row per region
```
