# A single step change, with the scan's own null distribution

Asks whether a series shifted to a new level at some point (for example
after a policy change) and, if so, where. It scans every admissible
split of the series, reports the one with the largest difference between
the before and after means, and gives it a p-value from the permutation
distribution of the MAXIMUM over splits – not from the best split's own
test, which is the standard way to find a change point in noise.

## Usage

``` r
stepchg(y, x = NULL, minseg = 2L, nperm = 9999L, seed = 1L)
```

## Arguments

- y:

  Numeric vector, the series in period order.

- x:

  Vector of periods, default `NULL` (the position). Used only to label
  the break; numeric or date periods must be strictly increasing.

- minseg:

  Whole number, default 2: the fewest periods allowed on either side of
  the break.

- nperm:

  Whole number, default 9999: the number of random permutations for the
  null distribution. The exact enumeration is used instead when \\n!\\
  is at most `nperm`.

- seed:

  Integer, default 1: the seed for the permutations, so the p-value is
  reproducible.

## Value

A list with `breakafter` (the period the series changes after, from
`x`), `index` (its position), `before` and `after` (the segment means),
`difference` (after minus before), `statistic` (\\T\_{\max}\\),
`p_value`, `nperm` (orderings or permutations used) and `method`.

## Details

For a split after period \\k\\, with \\n_a = k\\ and \\n_b = n - k\\
periods and means \\\bar y_a\\, \\\bar y_b\\, the statistic is the
between-segment sum of squares \$\$T_k = \frac{n_a n_b}{n} (\bar y_a -
\bar y_b)^2,\$\$ over \\k = m, \dots, n - m\\ with \\m\\ = `minseg`. The
observed \\\max_k T_k\\ is compared with the same maximum over
reorderings of the series, and \\p = (1 + \mathrm{count}(T^\*\_{\max}
\ge T\_{\max}))/(1 + B)\\ over \\B\\ random reorderings. When \\n! \le\\
`nperm` (with the default, \\n \le 7\\) every ordering is enumerated,
the observed one among them, and the p-value is exact:
\\\mathrm{count}(T^\*\_{\max} \ge T\_{\max}) / n!\\; otherwise `nperm`
random permutations are drawn under `seed`, and the caller's random
number stream is restored afterwards.

The test assumes the periods are exchangeable under no change, so it
ignores autocorrelation and smooth trends; a steady trend can produce a
"step". With very few periods even a clean step cannot reach small
p-values (six periods allow only 720 orderings). Missing values are
dropped. A series with values beyond 1e150 is scanned in units of its
largest absolute value, so the statistic does not overflow; `before`,
`after` and `difference` are given back in the units of `y`, and
`statistic` stays in the rescaled units. Errors: infinite values; fewer
than `2 * minseg` periods; numeric or date `x` that is not strictly
increasing. A progress bar is shown in an interactive session.

## References

The permutation distribution of the maximum over splits, rather than the
chosen split's own test, is what makes this a test of whether there is a
break rather than a way of locating the largest wobble. See any
treatment of the change-point problem, e.g. Coles, S. *An Introduction
to Statistical Modeling of Extreme Values* (Springer), which discusses
change-point detection alongside the threshold choices that raise the
same multiple-comparison issue.

## See also

[`trndtst`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trndtst.md),
[`cnttrnd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnttrnd.md).

## Examples

``` r
# A step down after the third period. With six periods there are only
# 720 orderings, so even a clean step has p near 0.1.
stepchg(c(100, 104, 98, 60, 63, 58), x = 2018:2023)
#> $breakafter
#> [1] 2020
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
#> [1] 0.1
#> 
#> $nperm
#> [1] 720
#> 
#> $method
#> [1] "exact over all 720 orderings"
#> 

# A longer series with the same step is clearly significant.
stepchg(c(100, 104, 98, 101, 97, 60, 63, 58, 61, 59), nperm = 999)$p_value
#> [1] 0.014

# Pure noise: the best split is still found, and is not significant.
set.seed(2)
stepchg(stats::rnorm(12), nperm = 999)$p_value
#> [1] 0.603

try(stepchg(c(1, 2, 3)))
#> Error : need at least 4 periods for a break with 2 either side
```
