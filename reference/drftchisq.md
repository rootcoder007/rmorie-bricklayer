# Chi-square test for a categorical column

Tests whether the category counts of a new sample agree with a reference
distribution that is taken as known, such as proportions fixed by a
specification or a published breakdown. It is Pearson's chi-square
goodness-of-fit test. When the reference is itself a sample, use
[`drfthomog()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drfthomog.md),
which accounts for the reference's own sampling error.

## Usage

``` r
drftchisq(obs, expd)
```

## Arguments

- obs:

  Named numeric vector of counts in the new sample, or a
  factor/character vector to be tabulated.

- expd:

  Named numeric vector of reference counts or proportions, or a
  factor/character vector to be tabulated. Rescaled to the total of
  `obs`.

## Value

A named length-4 numeric: `statistic`, `df`, `p_value` and `logpvalue`,
the natural log of the upper tail, which keeps its information where
`p_value` underflows to 0.

## Details

Pearson's chi-square goodness-of-fit statistic comparing observed
category counts with the proportions a capsule was pinned against. Use
it where
[`drftks()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftks.md)
cannot apply, because the column is a factor or a set of codes rather
than a number.

Categories present in one argument and not the other are aligned by
name, so a vanished category registers as a shortfall against its
expected count.

A category that OCCURS but which the reference gives probability zero
contradicts the pinned distribution outright, and its chi-square term is
unbounded; `statistic` is then `Inf` and `p_value` is `0`. If a new
category is a legitimate possibility rather than a contradiction – which
it usually is when the reference is itself a finite sample – use
[`drfthomog()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drfthomog.md)
instead.

With \\O_j\\ the observed counts and \\E_j = N e_j / \sum e\\ the
reference scaled to the observed total \\N\\, \$\$X^2 = \sum_j
\frac{(O_j - E_j)^2}{E_j}\$\$ over the categories with \\E_j \> 0\\, on
\\k - 1\\ degrees of freedom. The p-value is the upper tail of the
chi-square distribution, computed directly (not as one minus the lower
tail), so it does not round to zero early. With a single category there
is nothing to test: `df` is 0 and both p-values are `NA`. The chi-square
approximation is poor when expected counts are below about 5;
[`stats::chisq.test()`](https://rdrr.io/r/stats/chisq.test.html) with
`simulate.p.value = TRUE` is an alternative there.

Errors: a numeric vector without names; negative, infinite or missing
counts; a total of zero on either side.

## See also

[`drfthomog()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drfthomog.md),
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md),
[`stats::chisq.test()`](https://rdrr.io/r/stats/chisq.test.html) for the
full test object.

## Examples

``` r
ref <- c(a = 50, b = 30, c = 20)

# Counts matching the reference proportions: nothing to report.
drftchisq(c(a = 100, b = 60, c = 40), ref)
#> statistic        df   p_value logpvalue 
#>         0         2         1         0 

# A reallocated mix is detected.
drftchisq(c(a = 40, b = 60, c = 100), ref)
#>    statistic           df      p_value    logpvalue 
#>  1.26000e+02  2.00000e+00  4.35961e-28 -6.30000e+01 

# Agrees with stats::chisq.test().
o <- c(a = 40, b = 60, c = 100)
all.equal(drftchisq(o, ref)[["statistic"]],
          as.numeric(stats::chisq.test(o, p = ref / sum(ref))$statistic))
#> [1] TRUE

# Raw vectors are tabulated for you.
drftchisq(c("a", "a", "b", "b"), c("a", "b"))
#> statistic        df   p_value logpvalue 
#>         0         1         1         0 

# A category the reference rules out, but which occurs, is a flat
# contradiction rather than a large finite statistic.
drftchisq(c("a", "a", "b", "d"), c("a", "a", "b", "b"))
#> statistic        df   p_value logpvalue 
#>       Inf         1         0      -Inf 

# When a new category is legitimate, compare two samples instead.
drfthomog(c("a", "a", "b", "b"), c("a", "a", "b", "d"))
#> statistic        df   p_value logpvalue 
#>  1.333333  2.000000  1.000000  0.000000 
#> attr(,"method")
#> [1] "Monte Carlo permutation (small expected counts)"
```
