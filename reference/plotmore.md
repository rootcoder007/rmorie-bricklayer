# Many-plot helpers: ridgelines, ECDFs, violins, hexagonal bins and concentration curves

Base-graphics plots in the house style for a numeric variable split by a
group, or two numeric variables:

- `plotrdg()`:

  a ridgeline: one kernel density per group, stacked with a small
  overlap.

- `plotecdf()`:

  the empirical distribution function of each group, overlaid.

- `plotvln()`:

  a violin per group: the mirrored density, the median as a point and
  the interquartile range as a bar.

- `plothex()`:

  the two-dimensional density of `x` and `y` in hexagonal bins, shaded
  by count.

- `plotgain()`:

  cumulative-gain (concentration) curves: the Lorenz curve of each group
  ([`lorenzc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md))
  with its Gini coefficient in the key.

Missing and non-finite values are dropped. A group of fewer than two
values draws no density.

## Usage

``` r
plotrdg(x, grp = NULL, bw = "nrd0", ..., main = NULL, col = NULL, pal = NULL)

plotecdf(x, grp = NULL, ..., main = NULL, col = NULL, pal = NULL)

plotvln(x, grp = NULL, bw = "nrd0", ..., main = NULL, col = NULL, pal = NULL)

plothex(x, y, bins = 30L, ..., main = NULL, col = NULL, pal = NULL)

plotgain(x, grp = NULL, ..., main = NULL, col = NULL, pal = NULL)
```

## Arguments

- x:

  Numeric vector.

- grp:

  Optional vector of groups, one per value of `x`.

- bw:

  Bandwidth passed to
  [`stats::density()`](https://rdrr.io/r/stats/density.html), default
  `"nrd0"`.

- ...:

  Further arguments to the first
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) call.

- main, col, pal:

  The title, colours overriding the palette, and a
  [`blpal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blpal.md)
  name.

- y:

  Numeric vector, one per value of `x` (`plothex()`).

- bins:

  Whole number, default 30: hexagons across the range of `x`.

## Value

The data drawn, invisibly: for `plotrdg()` and `plotvln()` the densities
(`grp`, `x`, `y`), for `plotvln()` with the per-group `median`, `q1` and
`q3` as an attribute `summary`, for `plotecdf()` the steps (`grp`, `x`,
`y`), for `plothex()` the hexagon centres (`x`, `y`) and `count`, for
`plotgain()` the curves (`grp`, `population`, `value`) with the Gini
coefficients as an attribute `gini`.

## Examples

``` r
set.seed(3)
x <- c(stats::rnorm(200), stats::rnorm(200, 2, 0.6))
g <- rep(c("before", "after"), each = 200)
plotrdg(x, g)

plotecdf(x, g)

plotvln(x, g)

plothex(x, x + stats::rnorm(400), bins = 20)

plotgain(stats::rexp(400), g)

try(plotrdg("a"))
#> Error : plotrdg: `x` must be a numeric vector
```
