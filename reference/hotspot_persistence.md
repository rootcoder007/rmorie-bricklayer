# Hot spots and how long they last

Counts incidents (break-ins, shootings, calls for service) in square
grid cells for each period, measures how concentrated they are, picks
out the hot cells of each period and says how much the hot set of one
period overlaps the next. A hot spot that persists is a place problem;
one that moves from period to period is not, and the two call for
different responses.

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

  The period of each incident (a year, a month, a date, a label such as
  `"Q1"`); periods are taken in sorted order.

- cell:

  Side of a grid cell: kilometres for longitude and latitude, map units
  otherwise; one positive number, default 0.25.

- top:

  Share of the ever-active cells counted as hot in each period, in (0,
  1\]; default 0.05 (the busiest 5%).

- coords:

  `"lonlat"` (the default, degrees) or `"planar"` (projected
  coordinates, such as metres in a UTM zone).

## Value

An object of class `rmbl_hotspot`, a list:

- `periods`:

  data frame, one row per period: `period` (character), `incidents`,
  `active_cells`, `cells_for_half` (fewest cells holding half the
  incidents), `share_for_half` (that number over the ever-active cells),
  `hot_cells`, `tied_in` (the cells made hot only by a tie with the k-th
  busiest), `tied_out` (the tied cells left out when the tie would have
  made more than twice `k` cells hot, which printing says), `hot_share`
  (share of the incidents in hot cells) and `jaccard_previous` (`NA` for
  the first period). Shares are proportions in \\\[0, 1\]\\.

- `cells`:

  data frame, one row per ever-active cell: `x`, `y` (its centre in the
  input's units), `incidents` and `periods_hot`.

- `cell`, `top`, `coords`:

  the settings.

- `n_cells`, `hot_k`:

  the number of ever-active cells and \\k\\.

## Details

Counts incidents in square cells of side `cell` (kilometres for
longitude and latitude, map units otherwise) for each period and
reports, per period: the incidents, the cells with any, the share of the
ever-active cells that holds half the incidents (the law of crime
concentration: a small share of places holds half the incidents), the
hot cells (the `top` share of the ever-active cells with the most
incidents, with the cells tied at the cut included unless the tie would
more than double the hot set) and their share of the incidents, and the
Jaccard overlap of the hot set with the previous period's (shared hot
cells over cells hot in either). Per cell: the incidents in all, and in
how many periods it was hot.

The ever-active cells (a cell with at least one incident in some period)
are the base for the shares, so the empty land and water inside a city's
bounding box do not dilute the concentration. The number of hot cells
per period is \\k = \max(1, \lceil top \times n\_{cells} \rceil)\\.

Longitude and latitude are projected onto a flat map through the median
point (equirectangular, Earth radius 6371.0088 km), which is accurate
for a city or region; a warning is given when the incidents span more
than 2000 km. The grid starts at the smallest projected coordinate.
Points at (0, 0), the raw exports' "no location", are dropped with a
message, as are incidents with a non-finite coordinate or a missing
period; longitudes across the antimeridian are taken on one side of it.
When a tie empties a period's hot set, its overlap with the neighbouring
periods is `NA`, not 0. The plot method draws the concentration, the
overlap and a map of the cells.

Errors: `lon`, `lat` and `period` of different lengths; `cell` not one
positive number; `top` not in (0, 1\]; coordinates outside the degree
ranges with `coords = "lonlat"`; fewer than two usable incidents.

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


# the cells hot in every quarter
subset(h$cells, periods_hot == 4)
#> [1] x           y           incidents   periods_hot
#> <0 rows> (or 0-length row.names)

# larger cells and a wider hot set
h2 <- hotspot_persistence(b$lon, b$lat, q, cell = 0.5, top = 0.1)
h2$periods[, c("period", "hot_cells", "hot_share", "jaccard_previous")]
#>   period hot_cells hot_share jaccard_previous
#> 1     Q1        11 0.4687500               NA
#> 2     Q2        14 0.5187970        0.3157895
#> 3     Q3         9 0.4196429        0.3529412
#> 4     Q4         7 0.3407407        0.3333333

# planar coordinates, here in kilometres
set.seed(3)
hotspot_persistence(stats::runif(200, 0, 10), stats::runif(200, 0, 10),
                    rep(2023:2024, 100), cell = 2, top = 0.2, coords = "planar")
#> Hot spots: 25 active cells of side 2 units over 2 periods; hot = busiest 5 (20%)
#>  period incidents active_cells cells_for_half share_for_half hot_cells tied_in
#>    2023       100           25              9          36.0%         4       0
#>    2024       100           24              9          36.0%         5       0
#>  tied_out hot_share jaccard_previous
#>         8     26.0%                 
#>         0     33.0%             0.12
#> Cells hot in at least half the periods: 8
#> Note: cells tied with the busiest 5 were left out of the hot set (period 2023: 8 cells tied); the counts are too even (or the cells too small) to single out hot spots

# a share of zero hot cells is refused
try(hotspot_persistence(b$lon, b$lat, q, top = 0))
#> Error : `top` must be a share in (0, 1]
```
