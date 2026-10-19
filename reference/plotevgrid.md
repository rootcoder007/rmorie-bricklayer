# Event studies for several outcomes in one grid

Draws a list of
[`evstudy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md)
(or
[`stgatt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stgatt.md))
results in a grid of panels, one per outcome, with the same style, the
way papers show an effect on several crimes or several groups at once.

## Usage

``` r
plotevgrid(x, ncol = NULL, main = NULL, ...)
```

## Arguments

- x:

  A named list of
  [`evstudy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md)
  or
  [`stgatt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stgatt.md)
  results; the names title the panels.

- ncol:

  Panels per row (default up to 3).

- main:

  Optional overall title.

- ...:

  Passed to each panel's
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) (for example
  `style = "stata"`, `shadepost = TRUE`, `refline = 0`).

## Value

Invisibly, a data frame of every panel's estimates with a column
`panel`.

## See also

[`evstudy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md),
[`plot-methods`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md).

## Examples

``` r
p <- polex()
es <- list(
  "Crime rate" = evstudy(p, "district", "month", "crmrate", "refmonth",
                             leads = 3, lags = 4),
  "Arrest rate" = evstudy(p, "district", "month", "arrrate", "refmonth",
                              leads = 3, lags = 4))
plotevgrid(es, style = "stata")
```
