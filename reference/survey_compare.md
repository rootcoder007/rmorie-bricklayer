# Compare survey estimates between domains

Each domain's estimate against a reference domain: the difference, its
standard error from the design (the covariance between the two estimates
included, which is what a pair of separate intervals leaves out), a
confidence interval and a two-sided p-value from the normal
approximation.

## Usage

``` r
survey_compare(
  design,
  data,
  y,
  by,
  stat = c("mean", "total", "proportion", "ratio"),
  denominator = NULL,
  levels = NULL,
  ref = NULL,
  conf_level = 0.95
)
```

## Arguments

- design:

  A
  [`survey_design()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/survey_design.md)
  built on `data`.

- data:

  The data frame the design was built on.

- y:

  The analysis column.

- by:

  The domain columns to compare across.

- stat:

  `"mean"`, `"total"`, `"proportion"` or `"ratio"` (of `y` to
  `denominator`).

- denominator:

  For a ratio, the denominator column.

- levels:

  For a proportion, the categories to report (default all observed).

- ref:

  The reference domain, as its label (for several `by` columns, the
  labels joined with `" / "`); default the first.

- conf_level:

  Confidence level.

## Value

A data frame of class `rmbl_svy_compare`: `domain`, `level` (for a
proportion), `estimate`, `reference`, `difference`, `se`, `lower`,
`upper`, `p_value`.

## Examples

``` r
set.seed(1)
d <- data.frame(region = rep(c("north", "south", "east"), length.out = 150),
                smoker = rbinom(150, 1, 0.3), w = runif(150, 50, 150))
des <- survey_design(d, weights = "w")
survey_compare(des, d, "smoker", by = "region", stat = "proportion",
               levels = "1", ref = "north")
#> Survey proportion of smoker against north (95% interval)
#>  domain level estimate reference difference      se   lower   upper p_value
#>    east     1   0.2538    0.3701    -0.1164 0.09485 -0.3023 0.06954  0.2199
#>   south     1   0.2352    0.3701    -0.1350 0.09464 -0.3205 0.05052  0.1538
```
