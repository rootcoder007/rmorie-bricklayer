# Internal soundness of a crosswalk

Checks that a crosswalk assigns exactly one region to every unit and
that every region it names is one the reference geography knows about.

## Usage

``` r
crosswalk_integrity(crosswalk, unit, region, regions = NULL)
```

## Arguments

- crosswalk:

  Data frame, one row per unit.

- unit:

  Name of the column holding the unit identifier.

- region:

  Name of the column holding the region identifier.

- regions:

  Optional character vector of every valid region identifier, typically
  the identifier column of the population table. When supplied, region
  codes outside it are counted as failures.

## Value

A data frame with one row per check: `check`, `observed`, `expected` and
`pass`. Every check is stated so that zero is the passing value, which
is what makes the frame safe to feed straight into a manifest.

## Details

These are the failures that a comparison against published output cannot
see, because they would be present on both sides: a unit matched into
two regions, a unit matched into none, a region code that is a typo or
belongs to a neighbouring province. None of them require the geometry,
so they run with nothing installed.

## See also

[`crosswalk_compare()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crosswalk_compare.md),
[`crosswalk_second_route()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crosswalk_second_route.md),
[`region_coverage()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_coverage.md)

## Examples

``` r
cw <- data.frame(inst = c("North Jail", "South Jail", "East Jail"),
                 cd = c("3557", "3520", "3506"),
                 stringsAsFactors = FALSE)
crosswalk_integrity(cw, "inst", "cd", regions = c("3557", "3520", "3506"))
#>                                         check observed expected pass
#> 1         units assigned more than one region        0        0 TRUE
#> 2                    units assigned no region        0        0 TRUE
#> 3 region codes not in the reference geography        0        0 TRUE

# a region code the geography does not know fails the third check
cw$cd[3] <- "2406"
crosswalk_integrity(cw, "inst", "cd", regions = c("3557", "3520", "3506"))
#>                                         check observed expected  pass
#> 1         units assigned more than one region        0        0  TRUE
#> 2                    units assigned no region        0        0  TRUE
#> 3 region codes not in the reference geography        1        0 FALSE
```
