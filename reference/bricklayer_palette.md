# Plot styling for the package's plot methods

Every [`plot()`](https://rdrr.io/r/graphics/plot.default.html) method in
the package draws with base graphics and the same small set of style
choices, which these functions expose. `bricklayer_palette()` returns
colour-blind-safe palettes: `"okabe"` (the Okabe-Ito categorical set),
`"diverging"` (blue, grey, orange), `"sequential"` (light to dark blue)
and `"grey"`. `bricklayer_plot_options()` sets the defaults every method
uses, for the session: `palette`, `grid`, `cex`, `las` and `bg`. Each
method also takes `main`, `col` (which overrides the palette), `palette`
and `...` passed to the underlying base-graphics call, so a single plot
can be changed without changing the session.

## Usage

``` r
bricklayer_palette(
  name = c("okabe", "diverging", "sequential", "grey"),
  n = NULL
)

bricklayer_plot_options(...)
```

## Arguments

- name:

  Palette name.

- n:

  Number of colours; the categorical palettes recycle, the sequential
  and diverging ones interpolate.

- ...:

  For `bricklayer_plot_options()`, named options to set (`palette`,
  `grid`, `cex`, `las`, `bg`); none to read the current values.

## Value

`bricklayer_palette()`: a character vector of colours.
`bricklayer_plot_options()`: the options in force, invisibly when
setting.

## Examples

``` r
bricklayer_palette("okabe", 3)
#> [1] "#0072B2" "#D55E00" "#009E73"
old <- bricklayer_plot_options(palette = "grey", grid = FALSE)
bricklayer_plot_options()
#> $palette
#> [1] "grey"
#> 
#> $grid
#> [1] FALSE
#> 
#> $cex
#> [1] 1
#> 
#> $las
#> [1] 1
#> 
#> $bg
#> [1] "white"
#> 
bricklayer_plot_options(palette = old$palette, grid = old$grid)
```
