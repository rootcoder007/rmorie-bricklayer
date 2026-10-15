# Trend in a short series

Tests whether a short series (for example five to ten fiscal years of an
administrative count) is rising or falling, and estimates the size of
the change per period. It uses the Mann-Kendall rank test for monotone
trend and the Theil-Sen median-of-slopes estimator: no distributional
assumption, resistant to a single aberrant period, and meaningful at the
series lengths an annual administrative extract actually has.

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

  Numeric vector, the series in period order, or a data frame.

- x:

  Numeric vector of periods, default `NULL`: the position `1, 2, ...`,
  which is right for an evenly spaced series. Ignored when `y` is a data
  frame and `period` is given.

- value, period:

  Column names (strings), when `y` is a data frame. `value` is required;
  `period` is optional and must be convertible with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html).

- exact:

  Logical or `NULL` (the default). Whether to compute the exact null
  distribution of Mann-Kendall's \\S\\ by enumeration. `NULL` uses it up
  to `n = 8` (40,320 orderings); above that the normal approximation
  with the tie and continuity corrections is used.

- alternative:

  `"two.sided"` (the default), `"increasing"` or `"decreasing"`.

- conf_level:

  Number in (0, 1), default 0.95: the confidence level of the slope
  interval.

## Value

A list with `S`, `tau`, `p_value`, `slope` (Theil-Sen, in units of `y`
per unit of `x`), `intercept`, `slope_lower` and `slope_upper` (the
distribution-free interval), `slope_ci_clamped` (`TRUE` when the
pairwise slopes do not reach the requested confidence on a side, so that
bound is the extreme slope and the true interval is wider), `n`, `var_S`
(the tie-corrected variance of \\S\\), `alternative`, `conf_level` and
`method`.

## Details

With values \\y_1, \dots, y_n\\ in period order, \$\$S = \sum\_{i \< j}
\mathrm{sign}(y_j - y_i),\$\$ and Kendall's tau here is \\S /
(n(n-1)/2)\\, the rank correlation between the value and the period. The
Theil-Sen slope is the median of the pairwise slopes \\(y_j -
y_i)/(x_j - x_i)\\; `intercept` is the line's intercept from the
compiled Theil-Sen routine.

For \\n \le 8\\ the p-value is exact by default: \\S\\ is computed over
every ordering of the observed values (with ties kept, so tied data get
the correct conditional null). Otherwise the normal approximation is
used, with the tie-corrected variance of \\S\\ and a continuity
correction of one unit toward zero. Exact tables are cached in the
session, up to 32 of them.

The slope interval is the standard rank-based one: the pairwise slopes
are sorted and the interval runs between the order statistics that
Mann-Kendall's variance places at the chosen level, so it is consistent
with the test rather than derived from a different model. At small \\n\\
the slopes may not reach the requested confidence; the bound is then the
most extreme slope and `slope_ci_clamped` is `TRUE`.

Missing periods are dropped and the series is sorted by `x`. Errors:
fewer than three periods; infinite values; `x` and `y` of different
lengths; a data frame without `value` or with a column not found; more
than 20,000 periods (the pairwise slopes would not fit in memory); a
`conf_level` outside (0, 1). `exact = TRUE` with \\n \> 8\\ warns and
uses the normal approximation.

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

[`step_change`](https://rootcoder007.github.io/rmorie-bricklayer/reference/step_change.md),
[`count_trend`](https://rootcoder007.github.io/rmorie-bricklayer/reference/count_trend.md)

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
#> $slope_ci_clamped
#> [1] TRUE
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
#> $slope_ci_clamped
#> [1] TRUE
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
#> [1] 0.4

# From a data frame, testing for a decrease only.
d <- data.frame(year = 2019:2023, n = y)
trend_test(d, value = "n", period = "year", alternative = "decreasing")$p_value
#> [1] 0.2416667

try(trend_test(c(5, 6)))
#> Error : a trend needs at least three periods
```
