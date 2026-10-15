# Colour palettes for change tables

Lists the names of the colour palettes that the change-table renderers
accept. In every palette the colour says whether a change is good or bad
news for the series, not whether the number went up or down: the arrow
in the table carries the sign, and the colour carries the `direction`
chosen in
[`yoy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).
Use this to see which values the `palette` argument of
[`print()`](https://rdrr.io/r/base/print.html),
[`yoy_html`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md)
and
[`yoy_pdf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md)
takes.

## Usage

``` r
yoy_palettes()
```

## Value

A character vector of palette names, currently
`c("diverging", "safe", "mono")`.

## Details

Three palettes are defined:

- `"diverging"`:

  the default; red-orange (`#c2492f`) for bad news and teal (`#1b7f6b`)
  for good news, hues pulled apart so the pair stays distinguishable in
  the common forms of colour blindness.

- `"safe"`:

  orange (`#b8621b`) and blue (`#18567d`), safe for deuteranopia and
  protanopia alike.

- `"mono"`:

  black on grey; [`print()`](https://rdrr.io/r/base/print.html) emits no
  colour codes at all with this palette.

Unchanged rows and rows without a comparison use grey (`#6b6b6b`). The
verdict-to-colour mapping is: `"worse"` uses the bad colour and
`"better"` the good colour. With `direction = "neutral"` in
[`yoy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
the verdicts are `"up"`/`"down"`, which say nothing about good or bad
news, so those rows use the grey as well; the arrow still shows the
sign. A palette name not in this list is an error in every renderer.

## See also

[`yoy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md),
[`yoy_summary`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_summary.md),
[`yoy_html`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md),
[`yoy_pdf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md).

## Examples

``` r
# the palette names
yoy_palettes()
#> [1] "diverging" "safe"      "mono"     

# use one of them when printing a change table
d <- data.frame(year = 2019:2023, n = c(40, 46, 38, 52, 49))
print(yoy(d, value = "n", period = "year"), palette = "safe", color = FALSE)
#> year  n   previous  change  change %  interval     
#> ────  ──  ────────  ──────  ────────  ─────────────
#> 2019  40  —         —         —       —            
#>     ↳ note: no comparison period
#> 2020  46  40        6       ▲ +15.0%  [-26%, +80%] 
#> 2021  38  46        -8      ▼ -17.4%  [-48%, +30%] 
#> 2022  52  38        14      ▲ +36.8%  [-12%, +114%]
#> 2023  49  52        -3      ▼ -5.8%   [-38%, +42%] 
#> 
#> lag 1 period · units: count · 95% exact rate-ratio interval

# a name that is not a palette is refused
try(print(yoy(d, value = "n", period = "year"), palette = "rainbow"))
#> Error : `palette` must be one of "diverging", "safe", "mono", not "rainbow"
```
