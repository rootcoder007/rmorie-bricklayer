# Recompute a region map by point in polygon

Assigns each point to the polygon that contains it. Requires the `sf`
package and a boundary file; returns `NULL` when either is absent, so a
verification script can record the check as unavailable instead of
failing for a missing optional dependency.

## Usage

``` r
region_map_from_points(x, y, unit, boundaries, fields, crs = 4326)
```

## Arguments

- x, y:

  Longitude and latitude of each point.

- unit:

  Identifier for each point, same length.

- boundaries:

  Path to a boundary file `sf` can read.

- fields:

  Columns of the boundary file to carry onto the result.

- crs:

  Coordinate reference system the points are in. Default `4326`, that is
  WGS84, which is what published latitude and longitude columns almost
  always are.

## Value

A data frame: `unit`, the requested `fields`, and `n_regions`, the
number of polygons that contained the point. Any value of `n_regions`
other than 1 is a failure – zero means the point fell outside the
geography, more than one means the boundaries overlap – so it is
returned rather than silently resolved. `NULL` if `sf` is not installed
or `boundaries` does not exist.

## Details

The points are projected onto the boundary file's own coordinate
reference system before matching, never the other way round: a
cartographic boundary file is published in a projection chosen for the
country it covers, and reprojecting the polygons to compare them against
unprojected points moves the edges.

Point in polygon is preferred to matching place names against
subdivision names whenever both are available. Names fail on exactly the
cases that matter and fail quietly: a facility in a community rather
than an incorporated municipality, a city amalgamated into a larger one,
a township absorbed by a neighbour. The geometry has no opinion about
any of that.

Use
[`region_map_second_route()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_second_route.md)
to check this result against the name route, with those cases named.

## See also

[`region_map_compare()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_compare.md),
[`region_map_second_route()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_second_route.md)

## Examples

``` r
# Needs sf and a boundary file, so this is the shape of the call
# rather than a run of it.
if (FALSE) { # \dontrun{
obs <- region_map_from_points(
  x = inst$Longitude, y = inst$Latitude, unit = inst$Institution,
  boundaries = "lcd_000b21a_e.shp", fields = c("CDUID", "CDNAME"))
stopifnot(all(obs$n_regions == 1))
} # }
```
