# Recompute a region map by point in polygon

Assigns each point (a facility's longitude and latitude) to the polygon
of a boundary file that contains it, and carries the polygon's
identifier and name columns onto the result. Requires the `sf` package
and a boundary file; returns `NULL` when either is absent, so a
verification script can record the check as unavailable instead of
failing for a missing optional dependency.

## Usage

``` r
rgnmappts(x, y, unit, bounds, fields, crs = 4326)
```

## Arguments

- x, y:

  Longitude and latitude of each point (numeric vectors, no `NA`), in
  the coordinate reference system `crs`.

- unit:

  Identifier for each point, same length (character, no missing or empty
  values).

- bounds:

  Path to a boundary file `sf` can read (a shapefile, GeoPackage,
  GeoJSON, ...).

- fields:

  Character vector of columns of the boundary file to carry onto the
  result.

- crs:

  Coordinate reference system the points are in, anything
  [`sf::st_crs()`](https://r-spatial.github.io/sf/reference/st_crs.html)
  accepts. Default `4326`, that is WGS84, which is what published
  latitude and longitude columns almost always are.

## Value

A data frame: `unit`, the requested `fields` (factors converted to
character; `NA` for a point in no polygon, the first polygon's values
for a point in several), and `nreg` (integer), the number of polygons
that contained the point. Any value of `nreg` other than 1 is a failure
– zero means the point fell outside the geography, more than one means
the boundaries overlap – so it is returned rather than silently
resolved. `NULL` if `sf` is not installed or `boundaries` does not
exist.

## Details

The points are projected onto the boundary file's own coordinate
reference system before matching, never the other way round: a
cartographic boundary file is published in a projection chosen for the
country it covers, and reprojecting the polygons to compare them against
unprojected points moves the edges. Containment is
[`sf::st_within()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html),
so a point exactly on a shared edge is in neither polygon. The whole
boundary file is read into memory with
[`sf::st_read()`](https://r-spatial.github.io/sf/reference/st_read.html);
national files can take some seconds.

Point in polygon is preferred to matching place names against
subdivision names whenever both are available. Names fail on exactly the
cases that matter and fail quietly: a facility in a community rather
than an incorporated municipality, a city amalgamated into a larger one,
a township absorbed by a neighbour. The geometry has no opinion about
any of that.

Use
[`rgnmapalt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapalt.md)
to check this result against the name route, with those cases named, and
[`rgnmapcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapcmp.md)
to compare it with a published map.

Errors (when `sf` and the file are present): missing or empty `unit`;
`x`, `y` and `unit` of different lengths; missing coordinates; a field
the boundary file does not have.

## See also

[`rgnmapcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapcmp.md),
[`rgnmapalt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapalt.md)

## Examples

``` r
# Two square regions as a small GeoJSON boundary file.
gj <- tempfile(fileext = ".geojson")
writeLines(paste0(
  '{"type":"FeatureCollection","features":[',
  '{"type":"Feature","properties":{"CDUID":"A","CDNAME":"West"},"geometry":',
  '{"type":"Polygon","coordinates":[[[-80,43],[-79,43],[-79,44],[-80,44],[-80,43]]]}},',
  '{"type":"Feature","properties":{"CDUID":"B","CDNAME":"East"},"geometry":',
  '{"type":"Polygon","coordinates":[[[-79,43],[-78,43],[-78,44],[-79,44],[-79,43]]]}}]}'
), gj)

if (requireNamespace("sf", quietly = TRUE)) {
  obs <- rgnmappts(
    x = c(-79.5, -78.5, -70), y = c(43.5, 43.5, 43.5),
    unit = c("North Jail", "South Jail", "Far Jail"),
    bounds = gj, fields = c("CDUID", "CDNAME")
  )
  print(obs)
  # the point outside both regions is reported, not dropped
  obs$unit[obs$nreg != 1]

  # a field the file does not have is an error
  print(try(rgnmappts(-79.5, 43.5, "North Jail", gj, fields = "PRUID")))
}
#>         unit CDUID CDNAME nreg
#> 1 North Jail     A   West    1
#> 2 South Jail     B   East    1
#> 3   Far Jail  <NA>   <NA>    0
#> Error : boundary file has no column(s): PRUID
#> [1] "Error : boundary file has no column(s): PRUID\n"
#> attr(,"class")
#> [1] "try-error"
#> attr(,"condition")
#> <simpleError: boundary file has no column(s): PRUID>

# no boundary file: NULL, so a script can record the check as unavailable
rgnmappts(-79.5, 43.5, "North Jail",
                       bounds = file.path(tempdir(), "missing.shp"), fields = "CDUID")
#> NULL
unlink(gj)
```
