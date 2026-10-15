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
can be changed without changing the session. Use `bricklayer_palette()`
also to colour your own plots so they match the package's.

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

  Character scalar, the palette: `"okabe"` (the default), `"diverging"`,
  `"sequential"` or `"grey"`.

- n:

  Integer scalar or `NULL` (the default: the palette's own colours). The
  number of colours wanted; `"okabe"` and `"grey"` recycle,
  `"sequential"` and `"diverging"` interpolate.

- ...:

  For `bricklayer_plot_options()`, named options to set: `palette` (a
  palette name), `grid` (logical, draw grid lines), `cex` (numeric text
  and symbol size), `las` (axis label orientation, as in
  [`par()`](https://rdrr.io/r/graphics/par.html)), `bg` (background
  colour) and `panel` (the plot region's fill behind white grid lines,
  `NA` for none). With no arguments, the current values are returned.

## Value

`bricklayer_palette()`: a character vector of hexadecimal colours.
`bricklayer_plot_options()`: a named list of the six options in force
(after the change), invisibly when setting.

## Details

The palettes: `"okabe"` is the eight-colour set of Okabe and Ito (2008),
distinguishable under the common forms of colour-vision deficiency;
`"diverging"` has three anchors (blue `#2166AC`, grey `#8C8C8C`,
orange-red `#D6604D`) and is used for changes (decrease, no change,
increase); `"sequential"` has five blues from light to dark; `"grey"`
five greys from dark to light. With `n` given, `"okabe"` and `"grey"`
repeat their colours ([`rep_len()`](https://rdrr.io/r/base/rep.html))
and `"diverging"` and `"sequential"` are interpolated with
[`grDevices::colorRampPalette()`](https://rdrr.io/r/grDevices/colorRamp.html).

The session options are stored in `options(rmoriebricklayer.plot)`; the
defaults are `palette = "okabe"`, `grid = TRUE`, `cex = 1`, `las = 1`,
`bg = "white"` and `panel = "#EEF1F6"`. Setting some options keeps the
others.

Errors: an unknown palette `name`; `n` not a positive whole number; an
option name other than the six above, or an unnamed value; an unknown
`palette` option.

## References

Okabe, M. and Ito, K. (2008). Color Universal Design (CUD): how to make
figures and presentations that are friendly to colorblind people.
<https://jfly.uni-koeln.de/color/>

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
#> $panel
#> [1] "#EEF1F6"
#> 
bricklayer_plot_options(palette = old$palette, grid = old$grid)

# an interpolated sequential scale, shown as swatches
cols <- bricklayer_palette("sequential", 7)
barplot(rep(1, 7), col = cols, border = NA, axes = FALSE, names.arg = cols, las = 2,
        cex.names = 0.6)


# the same palette in a base plot of your own
plot(1:8, pch = 19, cex = 3, col = bricklayer_palette("okabe"))


# names are checked
try(bricklayer_palette("viridis"))
#> Error : `name` must be one of "okabe", "diverging", "sequential", "grey", not "viridis"
try(bricklayer_plot_options(colour = "red"))
#> Error : plot options are palette, grid, cex, las, bg, panel
```
