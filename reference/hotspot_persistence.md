# Hot spots and how long they last

Counts incidents in square cells of side `cell` (kilometres for
longitude and latitude, map units otherwise) for each period and
reports, per period: the incidents, the cells with any, the share of the
ever-active cells that holds half the incidents, the hot cells (the
`top` share of the ever-active cells with the most incidents, with the
cells tied at the cut included unless the tie would more than double the
hot set) and their share of the incidents, and the Jaccard overlap of
the hot set with the previous period's (shared hot cells over cells hot
in either). Per cell: the incidents in all, and in how many periods it
was hot.

## Usage

``` r
hotspot_persistence(
  lon,
  lat,
  period,
  cell = 0.25,
  top = 0.05,
  coords = c("lonlat", "planar")
)
```

## Arguments

- lon, lat:

  Incident coordinates: longitude and latitude in degrees, or planar
  coordinates with `coords = "planar"`.

- period:

  The period of each incident (a year, a month, a date); periods are
  taken in sorted order.

- cell:

  Side of a grid cell: kilometres for longitude and latitude, map units
  otherwise.

- top:

  Share of the ever-active cells counted as hot in each period.

- coords:

  `"lonlat"` or `"planar"`.

## Value

An object of class `rmbl_hotspot`: `periods` (one row per period;
`tied_in` counts the cells made hot only by a tie with the k-th busiest,
`tied_out` the tied cells left out when the tie would have made more
than twice `k` cells hot, which printing says), `cells` (one row per
ever-active cell, with its centre in the input's units), and the
settings. Points at (0, 0), the raw exports' "no location", are dropped,
and longitudes across the antimeridian are taken on one side of it.

## Details

The ever-active cells (a cell with at least one incident in some period)
are the base for the shares, so the empty land and water inside a city's
bounding box do not dilute the concentration.

## Examples

``` r
b <- read.csv(system.file("extdata", "tps_break_enter_d14_2024.csv",
                          package = "rmoriebricklayer"))
b <- b[!is.na(b$lon), ]
q <- quarters(as.Date(b$occ_date))
h <- hotspot_persistence(b$lon, b$lat, q, cell = 0.3)
h$periods
#>   period incidents active_cells cells_for_half share_for_half hot_cells tied_in
#> 1     Q1       128           77             22      0.1582734        11       4
#> 2     Q2       133           74             22      0.1582734         7       0
#> 3     Q3       112           70             19      0.1366906         7       0
#> 4     Q4       135           72             23      0.1654676         4       0
#>   tied_out hot_share jaccard_previous
#> 1        0 0.3281250               NA
#> 2        0 0.2255639        0.2857143
#> 3        0 0.2678571        0.1666667
#> 4       12 0.1333333        0.1000000
plot(h)
```
