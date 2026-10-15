# Estimate a mean, total, proportion or ratio from a survey design

Design-based point estimates with standard errors, confidence intervals
and coefficients of variation, for the whole population or for each
domain of `by`. A respondent outside a domain, or missing the analysis
variable, counts zero in that domain and stays in the design, so the
variance of a subgroup estimate reflects the whole sample design.

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

  The analysis column.

- by:

  Optional domain columns.

- stat:

  `"mean"`, `"total"`, `"proportion"` or `"ratio"` (of `y` to
  `denominator`).

- denominator:

  For a ratio, the denominator column.

- levels:

  For a proportion, the categories to report (default all observed).

- conf_level:

  Confidence level.

- ci:

  Interval method: `"auto"` (Wilson for proportions, Wald otherwise),
  `"wilson"`, `"logit"` or `"wald"`.

- min_n:

  Domains with fewer respondents are flagged.

- df:

  Degrees of freedom for the interval: `Inf` (the default) for the
  normal quantile, a number for Student's t, or `"design"` for the
  design's own (PSUs less strata under linearization, replicates less
  one otherwise).

## Value

A data frame of class `rmbl_svy_estimate`: the domain (and `level`)
columns, then `estimate`, `se`, `lower`, `upper`, `cv` (percent), `n`
(respondents counted) and `flag`. The covariance of the estimates is the
`vcov` attribute.

## Details

Proportions are reported for every category of `y` (or those in
`levels`), each with its own interval. The default interval for a
proportion is Wilson's score interval at the modified effective sample
size of SAS PROC SURVEYFREQ, the software behind Health Canada's
published Canadian Substance Use Survey intervals: \\n /
\mathrm{Deff}\\, with the design effect taken against the
simple-random-sampling variance \\p(1 - p)/(n - 1)\\, scaled by \\(z /
t\_{df})^2\\ for the design's degrees of freedom (Korn and Graubard
1998) and capped at the \\n\\ respondents behind the estimate.
`ci = "logit"` builds the interval on the logit scale and `"wald"`
symmetrically. Means, totals and ratios get the symmetric normal
interval.

A domain with fewer than `min_n` respondents is flagged, not withheld:
Health Canada suppresses such CSUS estimates in its data tool
(denominator under 30), and the flag lets the reader do the same.

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
```
