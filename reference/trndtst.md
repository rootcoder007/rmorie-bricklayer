# Trend in a short series

Tests whether a short series (for example five to ten fiscal years of an
administrative count) is rising or falling, and estimates the size of
the change per period. It uses the Mann-Kendall rank test for monotone
trend and the Theil-Sen median-of-slopes estimator: no distributional
assumption, resistant to a single aberrant period, and meaningful at the
series lengths an annual administrative extract actually has.

## Usage

``` r
trndtst(
  y,
  x = NULL,
  value = NULL,
  prd = NULL,
  exact = NULL,
  alt = c("two.sided", "increasing", "decreasing"),
  conflvl = 0.95
)
```

## Arguments

- y:

  Numeric vector, the series in period order, or a data frame.

- x:

  Numeric vector of periods, default `NULL`: the position `1, 2, ...`,
  which is right for an evenly spaced series. Ignored when `y` is a data
  frame and `prd` is given.

- value, prd:

  Column names (strings), when `y` is a data frame. `value` is required;
  `prd` is optional and must be convertible with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html).

- exact:

  Logical or `NULL` (the default). Whether to compute the exact null
  distribution of Mann-Kendall's \\S\\ by enumeration. `NULL` uses it up
  to `n = 8` (40,320 orderings); above that the normal approximation
  with the tie and continuity corrections is used.

- alt:

  `"two.sided"` (the default), `"increasing"` or `"decreasing"`.

- conflvl:

  Number in (0, 1), default 0.95: the confidence level of the slope
  interval.

## Value

A list of class `rmbl_trend_test` with `S`, `tau`, `p_value`, `slope`
(Theil-Sen, in units of `y` per unit of `x`), `intercept`, `slopelo` and
`slopeup` (the distribution-free interval), `slopecicla` (`TRUE` when
the pairwise slopes do not reach the requested confidence on a side, so
that bound is the extreme slope and the true interval is wider), `n`,
`var_S` (the tie-corrected variance of \\S\\), `alternative`, `conflvl`
and `method`.

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
session, up to 32 of them. A series whose values are all tied has \\S =
0\\ in every ordering, so its p-value is 1 at every length.

The slope interval is the standard rank-based one: the pairwise slopes
are sorted and the interval runs between the order statistics that
Mann-Kendall's variance places at the chosen level, so it is consistent
with the test rather than derived from a different model. At small \\n\\
the slopes may not reach the requested confidence; the bound is then the
most extreme slope and `slopecicla` is `TRUE`.

Missing periods are dropped and the series is sorted by `x`. Errors:
fewer than three periods; infinite values; `x` and `y` of different
lengths; a period given twice in `x`; a data frame without `value` or
with a column not found; more than 20,000 periods (the pairwise slopes
would not fit in memory); a `conflvl` outside (0, 1). `exact = TRUE`
with \\n \> 8\\ warns and uses the normal approximation.

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

[`stepchg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stepchg.md),
[`cnttrnd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnttrnd.md)

## Examples

``` r
# Five years of placements.
y <- c(402, 377, 190, 268, 331)
trndtst(y)
#> ╭── Trend test ───────────────────────────────────────────────────────────╮
#> │   Method       Mann-Kendall, exact over all 120 orderings               │
#> │   Periods      5                                                        │
#> │   S            -4                                                       │
#> │   Alternative  two.sided                                                │
#> │   Confidence   95%                                                      │
#> │                                                                         │
#> │   term         estimate  95% CI          p                              │
#> │   -----------  --------  ----------  -----                              │
#> │   Kendall tau     -0.40              0.483                              │
#> │   Sen slope      -21.38  [-187, 78]                                     │
#> │                                                                         │
#> │   Kendall's tau of -0.4 means a downward tendency (p = 0.483); the Sen  │
#> │   slope says the series moves by about -21.38 per period.               │
#> │                                                                         │
#> │   The slope's interval was clamped to the range of the pairwise slopes. │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# A monotone series is detected even at n = 5, where a regression's
# standard error would be nearly uninformative.
trndtst(c(1, 2, 3, 4, 5))
#> ╭── Trend test ───────────────────────────────────────────────────────────╮
#> │   Method       Mann-Kendall, exact over all 120 orderings               │
#> │   Periods      5                                                        │
#> │   S            10                                                       │
#> │   Alternative  two.sided                                                │
#> │   Confidence   95%                                                      │
#> │                                                                         │
#> │   term         estimate  95% CI      p                                  │
#> │   -----------  --------  ------  -----                                  │
#> │   Kendall tau         1          0.017                                  │
#> │   Sen slope           1  [1, 1]                                         │
#> │                                                                         │
#> │   Kendall's tau of 1 means an upward tendency (p = 0.017); the Sen      │
#> │   slope says the series moves by about 1 per period.                    │
#> │                                                                         │
#> │   The slope's interval was clamped to the range of the pairwise slopes. │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# One aberrant period does not create a trend.
trndtst(c(100, 100, 100, 100, 900))$p_value
#> [1] 0.4

# From a data frame, testing for a decrease only.
d <- data.frame(year = 2019:2023, n = y)
trndtst(d, value = "n", prd = "year", alt = "decreasing")$p_value
#> [1] 0.2416667

try(trndtst(c(5, 6)))
#> Error : trndtst: a trend needs at least three periods
```
