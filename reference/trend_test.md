# Trend in a short series

The Mann-Kendall rank test for monotone trend with the Theil-Sen
median-of-slopes estimator: no distributional assumption, resistant to a
single aberrant period, and meaningful at the series lengths an annual
administrative extract actually has.

## Usage

``` r
trend_test(
  y,
  x = NULL,
  value = NULL,
  period = NULL,
  exact = NULL,
  alternative = c("two.sided", "increasing", "decreasing"),
  conf_level = 0.95
)
```

## Arguments

- y:

  The series, in period order, or a data frame.

- x:

  The periods. Defaults to the position, which is right for an evenly
  spaced series.

- value, period:

  Column names, when `y` is a data frame.

- exact:

  Whether to compute the exact null distribution of Mann-Kendall's S by
  enumeration. Feasible and used by default up to `n = 8` (40,320
  orderings); above that the normal approximation with the tie and
  continuity corrections is used.

- alternative:

  `"two.sided"`, `"increasing"` or `"decreasing"`.

- conf_level:

  Confidence level for the slope interval.

## Value

A list with `S`, `tau`, `p_value`, `slope` (Theil-Sen), `intercept`,
`slope_lower` / `slope_upper` (the distribution-free interval), `n` and
`method`.

## Details

Kendall's tau here is S over the number of comparable pairs, so it is
the rank correlation between the value and the period.

The slope interval is the standard rank-based one: the pairwise slopes
are sorted and the interval runs between the order statistics that
Mann-Kendall's variance places at the chosen level, so it is consistent
with the test rather than derived from a different model.

## References

Sen, P. K. (1968). Estimates of the regression coefficient based on
Kendall's tau. *Journal of the American Statistical Association*
63(324), 1379-1389, for the median-of-slopes estimator and the
distribution-free interval.

Wilcox, R. R. *Modern Statistics for the Social and Behavioral Sciences:
A Practical Introduction* treats Theil-Sen among the regression methods
that carry no normality assumption, which is the reason for preferring
it on a series this short.

## See also

[`step_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/step_change.md),
[`count_trend()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/count_trend.md)

## Examples

``` r
# Five years of placements.
y <- c(402, 377, 190, 268, 331)
trend_test(y)
#> $S
#> [1] -4
#> 
#> $tau
#> [1] -0.4
#> 
#> $p_value
#> [1] 0.4833333
#> 
#> $slope
#> [1] -21.375
#> 
#> $intercept
#> [1] 419.75
#> 
#> $slope_lower
#> [1] -187
#> 
#> $slope_upper
#> [1] 78
#> 
#> $n
#> [1] 5
#> 
#> $var_S
#> [1] 16.66667
#> 
#> $alternative
#> [1] "two.sided"
#> 
#> $conf_level
#> [1] 0.95
#> 
#> $method
#> [1] "Mann-Kendall, exact over all 120 orderings"
#> 

# A monotone series is detected even at n = 5, where a regression's
# standard error would be nearly uninformative.
trend_test(c(1, 2, 3, 4, 5))
#> $S
#> [1] 10
#> 
#> $tau
#> [1] 1
#> 
#> $p_value
#> [1] 0.01666667
#> 
#> $slope
#> [1] 1
#> 
#> $intercept
#> [1] 0
#> 
#> $slope_lower
#> [1] 1
#> 
#> $slope_upper
#> [1] 1
#> 
#> $n
#> [1] 5
#> 
#> $var_S
#> [1] 16.66667
#> 
#> $alternative
#> [1] "two.sided"
#> 
#> $conf_level
#> [1] 0.95
#> 
#> $method
#> [1] "Mann-Kendall, exact over all 120 orderings"
#> 

# One aberrant period does not create a trend.
trend_test(c(100, 100, 100, 100, 900))$p_value
#> [1] 0.4833333

# From a data frame.
d <- data.frame(year = 2019:2023, n = y)
trend_test(d, value = "n", period = "year")$slope
#> [1] -21.375
```
