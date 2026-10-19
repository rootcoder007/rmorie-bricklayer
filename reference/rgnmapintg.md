# Internal soundness of a region map

Checks that a region map (a crosswalk from units, such as facilities, to
the statistical regions that contain them) lists each unit once, gives
every unit a region, and names only regions the reference geography
knows about. Run it on any crosswalk before tables are built on top of
it.

## Usage

``` r
rgnmapintg(map, unit, reg, regs = NULL)
```

## Arguments

- map:

  Data frame, one row per unit.

- unit:

  Name of the column holding the unit identifier (a string).

- reg:

  Name of the column holding the region identifier (a string).

- regs:

  Optional character vector of every valid region identifier, typically
  the identifier column of the population table. When supplied, region
  codes outside it are counted as failures; when `NULL` (the default)
  that check is not run and its row is absent.

## Value

A data frame with one row per check: `check` (character), `observed`
(numeric count), `expected` (numeric, always 0) and `pass` (logical).
Every check is stated so that zero is the passing value, which is what
makes the frame safe to feed straight into a manifest.

## Details

These are the failures that a comparison against published output cannot
see, because they would be present on both sides: a unit matched into
two regions, a unit matched into none, a region code that is a typo or
belongs to a neighbouring province. None of them require the geometry,
so they run with nothing installed.

The checks as computed: "units assigned more than one region" counts
rows whose (non-blank) unit identifier repeats an earlier row's, whether
or not the region differs, so an exact duplicate row also fails; "units
assigned no region" counts rows whose region is `NA` or blank; "region
codes not in the reference geography" counts non-blank region codes not
in `regs`, comparing the codes as text after trimming spaces (so
`"3506"` and `3506` match, but `"03506"` does not). Errors: `map` not a
data frame, or without the named columns.

## See also

[`rgnmapcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapcmp.md),
[`rgnmapalt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapalt.md),
[`rgncov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgncov.md)

## Examples

``` r
cw <- data.frame(
  inst = c("North Jail", "South Jail", "East Jail"),
  cd = c("3557", "3520", "3506"),
  stringsAsFactors = FALSE
)
rgnmapintg(cw, "inst", "cd", regs = c("3557", "3520", "3506"))
#>                                         check observed expected pass
#> 1         units assigned more than one region        0        0 TRUE
#> 2                    units assigned no region        0        0 TRUE
#> 3 region codes not in the reference geography        0        0 TRUE

# a region code the geography does not know fails the third check
cw$cd[3] <- "2406"
rgnmapintg(cw, "inst", "cd", regs = c("3557", "3520", "3506"))
#>                                         check observed expected  pass
#> 1         units assigned more than one region        0        0  TRUE
#> 2                    units assigned no region        0        0  TRUE
#> 3 region codes not in the reference geography        1        0 FALSE

# a unit listed twice and a unit with no region, without a reference list
cw2 <- rbind(cw, data.frame(inst = c("North Jail", "West Jail"), cd = c("3560", "")))
rgnmapintg(cw2, "inst", "cd")
#>                                 check observed expected  pass
#> 1 units assigned more than one region        1        0 FALSE
#> 2            units assigned no region        1        0 FALSE

# the columns must exist
try(rgnmapintg(cw, "institution", "cd"))
#> Error : `map` has no column `institution`
```
