# A Gaussian-plume concentration field on a grid

Evaluates
[`gaussian_plume`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pg_sigmas.md)
at every point of an `x` by `y` ground-level grid (or at height `z`) and
returns the field as a matrix with the axes, ready for
[`plot()`](https://rdrr.io/r/graphics/plot.default.html).

## Usage

``` r
plume_field(
  q,
  u,
  h,
  x,
  y,
  z = 0,
  stability = "D",
  setting = "rural",
  mixing_height = NULL,
  n_images = 3
)
```

## Arguments

- q, u, h, stability, setting, mixing_height, n_images:

  As in
  [`gaussian_plume`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pg_sigmas.md).

- x, y:

  Downwind and crosswind coordinates of the grid (metres).

- z:

  Receptor height (metres).

## Value

A list of class `rmbl_field`: `field` (a matrix, rows along `x`, columns
along `y`), `x`, `y`, `dx`, `dy`, `units` and `title`.

## Examples

``` r
f <- plume_field(100, 5, 50, x = seq(100, 3000, by = 100), y = seq(-500, 500, by = 50))
dim(f$field)
#> [1] 30 21
plot(f)
```
