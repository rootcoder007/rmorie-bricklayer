# A single step change, with the scan's own null distribution

Scans every admissible split of the series, reports the one with the
largest mean difference, and gives it a p-value from the permutation
distribution of the MAXIMUM over splits – not from the best split's own
test, which is the standard way to find a change point in noise.

## Usage

``` r
step_change(y, x = NULL, min_segment = 2L, n_perm = 9999L, seed = 1L)
```

## Arguments

- y:

  The series, in period order.

- x:

  The periods. Used only for labelling the break.

- min_segment:

  Fewest periods either side of the break.

- n_perm:

  Permutations for the null distribution. The exact enumeration is used
  instead when the series is short enough for it.

- seed:

  Seed for the permutations, so the p-value is reproducible.

## Value

A list with `break_after` (the period the series changes after),
`index`, `before`, `after`, `difference`, `statistic`, `p_value`,
`n_perm` and `method`.

## References

The permutation distribution of the maximum over splits, rather than the
chosen split's own test, is what makes this a test of whether there is a
break rather than a way of locating the largest wobble. See any
treatment of the change-point problem, e.g. Coles, S. *An Introduction
to Statistical Modeling of Extreme Values* (Springer), which discusses
change-point detection alongside the threshold choices that raise the
same multiple-comparison issue.

## Examples

``` r
# A clear step down after the third period.
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
#> 

# Pure noise: the best split is still found, and is not significant.
set.seed(2)
step_change(stats::rnorm(12))$p_value
#> [1] 0.6223
```
