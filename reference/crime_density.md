# Where incidents cluster: a kernel density surface

Estimates the density of incident locations – police-reported
occurrences, calls for service, addresses of people in a program – as a
smooth surface in incidents per square kilometre, and the smallest areas
holding a given share of them (the highest-density regions). The plot
draws the surface as a heat map with those regions outlined.

## Usage

``` r
crime_density(
  lon,
  lat,
  weights = NULL,
  bandwidth = NULL,
  n_grid = 200L,
  coverage = c(0.5, 0.9),
  coords = c("lonlat", "planar")
)
```

## Arguments

- lon, lat:

  Coordinates of the incidents: longitude and latitude in degrees
  (WGS84) by default, or planar coordinates in metres with
  `coords = "planar"`. Points with a missing coordinate are dropped with
  a message; in degrees, points at exactly (0, 0), which is how several
  open-data portals publish an incident with no location, are dropped
  too.

- weights:

  Optional non-negative weight per incident. Default 1.

- bandwidth:

  Kernel standard deviation in kilometres: one value for both directions
  or two (east-west, north-south). Default: Scott's normal-reference
  rule, \\\sigma n^{-1/6}\\ for each direction.

- n_grid:

  Grid nodes per direction. Default 200.

- coverage:

  Shares of the incidents whose highest-density regions are reported and
  outlined. Default `c(0.5, 0.9)`.

- coords:

  `"lonlat"` (the default) or `"planar"`.

## Value

A list of class `rmbl_density`: `field` (incidents per square kilometre
on the grid), `x` and `y` (grid coordinates in kilometres from the
centre), `lon` and `lat` (the same grid in degrees, for `"lonlat"`),
`bandwidth`, `n`, `dropped`, `points` (the projected incidents), and
`regions`: one row per coverage share with the density `level` that
bounds it, its `area_km2`, and its share of the mapped area.

## Details

The estimate is the Gaussian product-kernel density, computed on the
grid by linear binning followed by an exact discrete convolution, which
agrees with the direct sum to within the binning error (of order the
squared grid spacing over the squared bandwidth). The grid extends three
bandwidths past the outermost incident so the surface integrates to the
total weight.

A highest-density region for share \\p\\ is the set of grid cells with
the largest densities whose estimated incidents add up to \\p\\ of the
total. Its area is the spatial counterpart of a concentration index:
when half the incidents fall in a few per cent of the mapped area, they
are concentrated. The bandwidth decides how sharp the surface is, so it
should be reported with any map; the default suits a first look, not a
definitive one.

## References

Scott, D. W. (2015). *Multivariate Density Estimation: Theory, Practice,
and Visualization*, 2nd ed. Wiley, Hoboken, NJ.

Wand, M. P. (1994). Fast computation of multivariate kernel estimators.
*Journal of Computational and Graphical Statistics*, 3(4), 433-445.

Hyndman, R. J. (1996). Computing and graphing highest density regions.
*The American Statistician*, 50(2), 120-126.

Chainey, S., Tompson, L. and Uhlig, S. (2008). The utility of hotspot
mapping for predicting spatial patterns of crime. *Security Journal*,
21(1-2), 4-28.

## See also

[`knox_test`](https://rootcoder007.github.io/rmorie-bricklayer/reference/knox_test.md),
[`plume_field`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plume_field.md)
(the same kind of surface, for an air pollutant).

## Examples

``` r
b <- read.csv(system.file("extdata", "tps_break_enter_d14_2024.csv",
                          package = "rmoriebricklayer"))
kd <- crime_density(b$lon, b$lat, n_grid = 120)
kd
#> ── Kernel density of incidents: smallest areas holding each share  
#>   508 incidents; bandwidth 0.337 km east-west, 0.412 km north-south
#>   Peak density 77.9 incidents per square kilometre
#> 
#>  incidents area_km2 share_of_mapped_area density_at_edge
#>        50%    5.506                11.9%           31.91
#>        90%   14.840                32.0%           11.26
#> ────────────────────────────────────────────────────────────────── 
plot(kd)
```
