# Lorenz and funnel plots

Two plots for results that are plain data frames rather than classed
objects. `plot_lorenz()` draws the Lorenz curve of a vector (or of
[`lorenz`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)'s
output) with the Gini coefficient in the title. `plot_funnel()` draws
every area's ratio of observed to expected against its expected count,
inside the control limits of
[`funnel_limits`](https://rootcoder007.github.io/rmorie-bricklayer/reference/funnel_limits.md),
the standard small-area funnel plot.

## Usage

``` r
plot_lorenz(x, ..., main = NULL, col = NULL, palette = NULL)

plot_funnel(
  observed,
  expected,
  area = NULL,
  levels = c(0.95, 0.998),
  target = 1,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
)
```

## Arguments

- x:

  For `plot_lorenz()`, a numeric vector or the data frame
  [`lorenz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
  returns.

- main, col, palette, ...:

  As in
  [`plot-methods`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md).

- observed, expected:

  Observed and expected counts per area.

- area:

  Optional labels, drawn for the areas outside the limits.

- levels:

  Control-limit levels, as in
  [`funnel_limits`](https://rootcoder007.github.io/rmorie-bricklayer/reference/funnel_limits.md).

- target:

  The ratio the limits are drawn around.

## Value

The data drawn, invisibly.

## Examples

``` r
plot_lorenz(c(1, 1, 2, 3, 5, 8, 13))

plot_funnel(observed = c(4, 20, 50, 9), expected = c(5, 22, 40, 20),
            area = c("a", "b", "c", "d"))
```
