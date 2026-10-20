# Plot fitted distributions

Four views of a
[`dstfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstfit.md)
result: the histogram (or, for counts, the observed proportions) with
each fitted density or mass over it; a QQ plot and a PP plot per family;
and the empirical survival function on log-log axes with each fitted
survival curve, where a power law is a straight line.

## Usage

``` r
# S3 method for class 'rmbl_dstfit'
plot(
  x,
  ...,
  which = c("density", "qq", "pp", "tail"),
  fams = NULL,
  main = NULL,
  col = NULL,
  palette = NULL
)
```

## Arguments

- x:

  A
  [`dstfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstfit.md)
  result.

- ...:

  Further arguments to the first
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) call.

- which:

  One of `"density"`, `"qq"`, `"pp"` or `"tail"`.

- fams:

  Families to draw; default the three best by AIC.

- main, col, palette:

  The title, colours, and a
  [`blpal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blpal.md)
  palette name.

## Value

The data drawn, invisibly: a data frame with `family`, `x` and `y` (and
for `qq` and `pp` the empirical value in `y` against the fitted one in
`x`).

## Examples

``` r
set.seed(2)
f <- dstfit(stats::rlnorm(200), nboot = 0)
plot(f)

plot(f, which = "qq")

plot(f, which = "pp", fams = "lognormal")

plot(f, which = "tail")

try(plot(f, fams = "beta"))
#> Error : plot: no converged fit for beta
```
