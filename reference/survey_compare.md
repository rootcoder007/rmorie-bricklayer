# Compare survey estimates between domains

Each domain's estimate against a reference domain: the difference, its
standard error from the design (the covariance between the two estimates
included, which is what a pair of separate intervals leaves out), a
confidence interval and a two-sided p-value from the normal
approximation. Use it to test whether two regions or groups differ,
rather than checking whether their separate intervals overlap:
overlapping intervals do not mean no difference, and domains of one
survey are not independent.

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

  Character scalar, the analysis column: numeric for a mean, total or
  ratio; any type for a proportion (each distinct value is a category).

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
  labels joined with `" / "`); a number is matched as the label it
  prints as. Default `NULL`: the first domain.

- conf_level:

  Numeric scalar in (0, 1), the confidence level; default `0.95`.

## Value

A data frame of class `c("rmbl_svy_compare", "data.frame")`, one row per
non-reference domain (and category): `domain`, `level` (for a proportion
only), numeric `estimate` (the domain's), `reference` (the reference
domain's), `difference`, `se`, `lower`, `upper` and `p_value`.
Attributes `ref`, `stat`, `y` and `conf_level`.

## Details

The estimates come from
[`survey_estimate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/survey_estimate.md)
with Wald intervals. For domain \\i\\ and reference \\0\\ the difference
is \\d = \hat\theta_i - \hat\theta_0\\ with \\SE(d) = \sqrt{V\_{ii} +
V\_{00} - 2V\_{i0}}\\ from the design covariance; the interval is \\d
\pm z\\SE(d)\\ and the p-value \\2\Phi(-\|d\|/SE(d))\\, both on the
normal distribution (there is no `df` argument). For a proportion every
category is compared separately. No adjustment for multiple comparisons
is made.

Errors: `by` missing or empty; fewer than two domains; a `ref` that is
not a single domain label present in the data; and every error of
[`survey_estimate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/survey_estimate.md).

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

# means, against the default (first) domain, at 90 percent
d$drinks <- rpois(150, 3)
survey_compare(des, d, "drinks", by = "region", conf_level = 0.90)
#> Survey mean of drinks against east (90% interval)
#>  domain estimate reference difference     se   lower  upper p_value
#>   north    3.066     3.361    -0.2952 0.3947 -0.9444 0.3539  0.4544
#>   south    3.083     3.361    -0.2779 0.3811 -0.9048 0.3490  0.4659

# the reference must be one of the domains
try(survey_compare(des, d, "drinks", by = "region", ref = "west"))
#> Error : `ref` is not one of the domains: east, north, south
```
