# Population of the regions that contain a unit, and of those that do not

Summarises where a set of point-located units sits relative to the
regions of a statistical geography: how many regions hold at least one
unit, and what share of the population lives in them.

## Usage

``` r
region_coverage(region, population, units)
```

## Arguments

- region:

  Region identifiers, one per region, not repeated.

- population:

  Population of each region, same length and order.

- units:

  Number of units located in each region. Zero is the expected value for
  most regions in most geographies.

## Value

A data frame of class `rmbl_region_coverage`, one row per region, with
the columns `region`, `population`, `units`, `has_unit` and `pop_share`,
ordered by units then population. The totals are carried on the
`coverage` attribute and printed by the print method.

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
precisely the number a reader is tempted to divide by.

## See also

[`crosswalk_integrity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crosswalk_integrity.md),
[`crosswalk_compare()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crosswalk_compare.md),
[`crosswalk_second_route()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crosswalk_second_route.md)

## Examples

``` r
# Four regions, two of which hold a facility.
cov <- region_coverage(region = c("A", "B", "C", "D"),
                       population = c(1200000, 800000, 450000, 90000),
                       units = c(3, 0, 1, 0))
cov
#> 4 units in 2 of 4 regions
#>   those regions hold 1,650,000 of 2,540,000 residents (65.0%)
#>   2 regions hold none; 890,000 residents (35.0%) live there
#> 
#>  region population units has_unit pop_share
#>       A    1200000     3     TRUE 47.244094
#>       C     450000     1     TRUE 17.716535
#>       B     800000     0    FALSE 31.496063
#>       D      90000     0    FALSE  3.543307
#> 
#> The covered share is context, not a denominator: units serve 
#> catchments, so a rate over these regions alone would take its 
#> numerator from the whole territory and is inflated.

# The covered share is reported, and is not a rate denominator.
attr(cov, "coverage")$covered_share
#> [1] 64.96063
```
