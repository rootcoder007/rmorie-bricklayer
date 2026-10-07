# Trends and change in short count series

A published series is usually short: five to ten annual counts. Three
questions recur. Is there a monotone trend? How fast is the count
changing per period? Did something change at one point? Each has a
method suited to short series, and each is wrong to answer with a
least-squares line on five points.

## A monotone trend: Mann–Kendall and Sen’s slope

The Mann–Kendall test counts, over all pairs of periods, how many later
values exceed earlier ones minus how many fall below. It is
distribution-free and exact for small *n*, so it is informative where a
regression’s standard error would be nearly meaningless. Sen’s slope is
the median of all pairwise slopes, a robust rate of change.

``` r

y <- c(402, 377, 190, 268, 331)        # five years of placements
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
```

A monotone series is detected even at *n* = 5:

``` r

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
```

One aberrant period does not create a trend:

``` r

trend_test(c(100, 100, 100, 100, 900))$p_value
#> [1] 0.4
```

From a data frame, with a direction when one is hypothesised in advance:

``` r

d <- data.frame(year = 2019:2023, n = y)
trend_test(d, value = "n", period = "year")$slope
#> [1] -21.375
trend_test(d, value = "n", period = "year", alternative = "decreasing")$p_value
#> [1] 0.2416667
```

## The rate of change: a Poisson trend

For counts, the natural model is a Poisson log-linear trend:
`log E[y] = a + b * t`, so `exp(b)` is the **rate ratio per period**,
the multiplicative change from one period to the next.
[`count_trend()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/count_trend.md)
fits it with an interval:

``` r

set.seed(3)
y <- stats::rpois(8, lambda = 200 * 0.85^(0:7))   # falling ~15% a year
fit <- count_trend(y)
round(fit$rate_ratio, 3)
#> [1] 0.869
```

With a varying denominator the trend is in the *rate*, via an offset:

``` r

count_trend(c(20, 25, 30), offset = c(1000, 1500, 2500))$rate_ratio
#> [1] 0.7708656
```

Counts here rise while the rate per 1,000 falls, which is the finding.

## A step change

A trend test asks “is it drifting?”; a step-change test asks “did it
jump once?”. The best single split point is found by maximising the
between-segment difference, and its significance is judged by
permutation, which accounts for having searched over every possible
split:

``` r

step_change(c(100, 104, 98, 60, 63, 58))
#> $break_after
#> [1] 3
#> 
#> $index
#> [1] 3
#> 
#> $before
#> [1] 100.6667
#> 
#> $after
#> [1] 60.33333
#> 
#> $difference
#> [1] -40.33333
#> 
#> $statistic
#> [1] 2440.167
#> 
#> $p_value
#> [1] 0.1012483
#> 
#> $n_perm
#> [1] 720
#> 
#> $method
#> [1] "exact over all 720 orderings"
```

Pure noise still yields a best split, and it is not significant:

``` r

set.seed(2)
step_change(stats::rnorm(12))$p_value
#> [1] 0.6223
```

## Choosing between them

| Question | Tool | Reports |
|----|----|----|
| Is the series moving in one direction? | [`trend_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trend_test.md) | Mann–Kendall p-value, Sen’s slope with interval |
| By what factor per period? | [`count_trend()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/count_trend.md) | rate ratio with interval, optional offset |
| Did it change once, and when? | [`step_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/step_change.md) | split point, segment means, permutation p-value |
| Year over year, with publication rounding | [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md) (its own vignette) | exact intervals on each change |

All of them work on the five to ten values a published table gives, and
none of them assumes the counts are large.

## References

Mann (1945). Nonparametric tests against trend. *Econometrica* 13(3).
Kendall (1975). *Rank Correlation Methods*. 4th ed. Sen (1968).
Estimates of the regression coefficient based on Kendall’s tau. *JASA*
63(324).
