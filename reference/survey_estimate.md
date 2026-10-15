# Estimate a mean, total, proportion or ratio from a survey design

Design-based point estimates with standard errors, confidence intervals
and coefficients of variation, for the whole population or for each
domain of `by`. A respondent outside a domain, or missing the analysis
variable, counts zero in that domain and stays in the design, so the
variance of a subgroup estimate reflects the whole sample design. Use it
for the figures a survey report publishes (the prevalence of a behaviour
by region, the mean number of drinks, a population total) with the
standard errors the survey's design implies rather than those of a
simple random sample.

## Usage

``` r
survey_estimate(
  design,
  data,
  y,
  by = NULL,
  stat = c("mean", "total", "proportion", "ratio"),
  denominator = NULL,
  levels = NULL,
  conf_level = 0.95,
  ci = c("auto", "wilson", "logit", "wald"),
  min_n = 30,
  df = Inf
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

  Optional character vector of domain columns; `NULL` (the default)
  estimates for the whole population.

- stat:

  `"mean"`, `"total"`, `"proportion"` or `"ratio"` (of `y` to
  `denominator`).

- denominator:

  For a ratio, the denominator column.

- levels:

  For a proportion, the categories to report (default all observed).

- conf_level:

  Numeric scalar in (0, 1), the confidence level; default `0.95`.

- ci:

  Interval method: `"auto"` (the default; Wilson for proportions, Wald
  otherwise), `"wilson"`, `"logit"` or `"wald"`. Wilson and logit apply
  to proportions only.

- min_n:

  Numeric scalar, default `30`: domains with fewer respondents are
  flagged.

- df:

  Degrees of freedom for the interval: `Inf` (the default) for the
  normal quantile, a number for Student's t, or `"design"` for the
  design's own (PSUs less strata under linearization, replicates less
  one otherwise).

## Value

A data frame of class `c("rmbl_svy_estimate", "data.frame")`, one row
per domain (and category, for a proportion): the domain columns (and
`level`), then numeric `estimate`, `se`, `lower`, `upper`, `cv`
(coefficient of variation, percent), integer `n` (respondents counted)
and character `flag` (`NA` when there is nothing to say). Attributes:
`vcov` (the covariance matrix of the estimates, used by
[`survey_compare()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/survey_compare.md)),
`stat`, `y`, `by`, `ci`, `conf_level`, `df`, `method` (the variance
method) and `denominator`.

## Details

The estimates are ratios of weighted totals: a mean is \\\sum w_i y_i /
\sum w_i\\ over the domain, a total \\\sum w_i y_i\\, a proportion the
mean of the 0/1 indicator of each category, and a ratio \\\sum w_i y_i /
\sum w_i x_i\\ with \\x\\ the `denominator`. Their variances come from
the design: the replicate formula, or Taylor linearization of the ratio
(see
[`survey_design()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/survey_design.md)).

Proportions are reported for every category of `y` (or those in
`levels`), each with its own interval. The default interval for a
proportion is Wilson's score interval at the modified effective sample
size of SAS PROC SURVEYFREQ, the software behind Health Canada's
published Canadian Substance Use Survey intervals: \\n /
\mathrm{Deff}\\, with the design effect taken against the
simple-random-sampling variance \\p(1 - p)/(n - 1)\\, scaled by
\\(t\_{n-1} / t\_{df})^2\\ for the design's degrees of freedom (Korn and
Graubard 1998; \\t\_{df}\\ is the normal quantile when the design's
degrees of freedom are infinite) and capped at the \\n\\ respondents
behind the estimate. `ci = "logit"` builds the interval on the logit
scale and `"wald"` symmetrically. Means, totals and ratios get the
symmetric normal interval.

A domain with fewer than `min_n` respondents is flagged, not withheld:
Health Canada suppresses such CSUS estimates in its data tool
(denominator under 30), and the flag lets the reader do the same. Other
flags say why a standard error is missing (no stratum with two PSUs, a
replicate that left the domain empty, weights all zero) or that a domain
has no respondents.

Errors: `design` not from
[`survey_design()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/survey_design.md);
`data` not the rows the design was built on, in the same order; `y`,
`by` or `denominator` naming a column `data` does not have; a ratio
without `denominator`; `conf_level` outside (0, 1); `df` not positive,
`Inf` or `"design"`, or a design with no degrees of freedom under
`df = "design"`; a single-PSU stratum under `lonely_psu = "fail"`.

## See also

[`survey_design()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/survey_design.md),
[`survey_compare()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/survey_compare.md)

## Examples

``` r
set.seed(1)
d <- data.frame(region = rep(c("north", "south"), each = 50),
                smoker = rbinom(100, 1, rep(c(0.2, 0.35), each = 50)),
                drinks = rpois(100, 3), w = runif(100, 50, 150))
des <- survey_design(d, weights = "w", strata = "region")
survey_estimate(des, d, "smoker", by = "region", stat = "proportion", levels = "1")
#> Survey proportion of smoker by region (linearization variance, 95% wilson interval)
#>  region level estimate      se   lower  upper    cv  n flag
#>   north     1   0.1570 0.05295 0.08093 0.2825 33.73 50   NA
#>   south     1   0.3752 0.07282 0.25036 0.5192 19.41 50   NA
survey_estimate(des, d, "drinks", stat = "mean")
#> Survey mean of drinks (linearization variance, 95% wald interval)
#>  estimate     se lower upper    cv   n flag
#>     3.088 0.1668 2.761 3.415 5.401 100   NA
survey_estimate(des, d, "drinks", by = "region", stat = "total")
#> Survey total of drinks by region (linearization variance, 95% wald interval)
#>  region estimate   se lower upper    cv  n flag
#>   north    15080 1390 12356 17805 9.218 50   NA
#>   south    13796 1109 11621 15970 8.041 50   NA

# a ratio of two totals, with Student's t on the design's degrees of freedom
d$visits <- rpois(100, 6)
survey_estimate(des, d, "drinks", stat = "ratio", denominator = "visits", df = "design")
#> Survey ratio of drinks (linearization variance, 95% wald interval)
#>  estimate      se  lower  upper    cv   n flag
#>     0.496 0.03564 0.4253 0.5667 7.185 100   NA

# a logit interval at 90 percent
survey_estimate(des, d, "smoker", stat = "proportion", levels = "1", ci = "logit",
                conf_level = 0.90)
#> Survey proportion of smoker (linearization variance, 90% logit interval)
#>  level estimate      se  lower  upper    cv   n flag
#>      1    0.261 0.04474 0.1943 0.3409 17.14 100   NA

# the design remembers its rows: a subset is refused
try(survey_estimate(des, d[-1, ], "drinks"))
#> Error : `data` must be the data frame the design was built on
```
