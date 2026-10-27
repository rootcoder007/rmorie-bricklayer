# Do Reasonable Alternative Analyses Agree?

Runs several specifications of the same estimate (other covariates,
another model, another handling of outliers or missing values) and
reports how far they spread and whether they agree in sign. A finding
that holds under one specification only is fragile; one that survives
the reasonable alternatives is robust.

## Usage

``` r
cpsspec(data, specs)
```

## Arguments

- data:

  A data frame.

- specs:

  A named list of functions, each taking the data frame and returning
  one number: the estimate under that specification. The first is the
  one the paper reports.

## Value

A list of class `rmbl_spec`: `ok` (every estimate has the sign of the
reported one), `table` (`spec`, `estimate`, `same_sign`), `reported`,
`range` and `share` (the share agreeing in sign). It prints as a box and
goes into a manifest with
[`recevid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recevid.md).

## See also

[`cpsplant()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsplant.md),
[`recevid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recevid.md).

## Examples

``` r
set.seed(2)
d <- data.frame(x = rnorm(300), z = rnorm(300))
d$y <- 0.5 * d$x + 0.3 * d$z + rnorm(300)
cpsspec(d, list(
  adjusted = function(df) coef(lm(y ~ x + z, df))[["x"]],
  simple = function(df) coef(lm(y ~ x, df))[["x"]],
  trimmed = function(df) {
    keep <- abs(df$y - mean(df$y)) < 3 * sd(df$y)
    coef(lm(y ~ x + z, df[keep, ]))[["x"]]
  }
))
#> ╭── Specification check: robust ──────────────────────────────────────────────╮
#> │ ✔ VERIFIED                                                                  │
#> │                                                                             │
#> │   Specifications         3                                                  │
#> │   Reported               0.574115 (adjusted)                                │
#> │   Range                  0.56001 to 0.574115                                │
#> │   Same sign as reported  3 of 3                                             │
#> │                                                                             │
#> │   specification  estimate  sign                                             │
#> │   -------------  --------  ----                                             │
#> │   adjusted         0.5741  same                                             │
#> │   simple           0.5603  same                                             │
#> │   trimmed          0.5600  same                                             │
#> │                                                                             │
#> │   Every specification agrees in sign with the reported one, so the finding  │
#> │   does not hang on one analytic choice.                                     │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```
