# Chi-square test of homogeneity for two categorical samples

Tests whether two SAMPLES were drawn from the same categorical
distribution, by Pearson's chi-square on the 2-by-k contingency table of
their counts.

## Usage

``` r
drift_homogeneity(x, y, seed = 1L)
```

## Arguments

- x, y:

  Factor or character vectors (or named count vectors) – the reference
  and the new sample.

- seed:

  Seed for the Monte Carlo branch (small expected counts). The draw is
  made under this seed and the caller's RNG stream is restored, so the
  same inputs give the same p-value and nothing downstream moves.

## Value

A named length-4 numeric: `statistic`, `df`, `p_value` and
`log_p_value`, the natural log of the upper tail, which keeps its
information where `p_value` underflows to 0. On the Monte Carlo branch
(sparse tables) `p_value` is floored at 1/(B+1) and `log_p_value` is its
log, so it carries no extra range there. The attribute `method` names
the branch, or says why the test was inapplicable (one category, no
counts).

## Why this and not [`drift_chisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_chisq.md)

[`drift_chisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_chisq.md)
compares observed counts against a distribution taken as KNOWN –
proportions fixed by a specification. When the reference is itself a
finite sample, that treatment ignores the reference's own sampling
error, understates the variance of the comparison, and so reports drift
too readily. A homogeneity test estimates the shared distribution from
the pooled margins and carries the uncertainty of both samples, which is
the right test when comparing a pinned extract with a fresh fetch.
[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
therefore uses this one.

Categories present in only one sample are aligned by name and given zero
counts, so an appearing or vanishing level registers.

## See also

[`drift_chisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_chisq.md)
for a known reference distribution,
[`stats::chisq.test()`](https://rdrr.io/r/stats/chisq.test.html) for the
full test object.

## Examples

``` r
set.seed(1)
a <- sample(c("x", "y", "z"), 300, TRUE)
b <- sample(c("x", "y", "z"), 300, TRUE)

# Two draws from the same distribution: no evidence of a difference.
drift_homogeneity(a, b)
#>   statistic          df     p_value log_p_value 
#>   0.5150386   2.0000000   0.7729667  -0.2575193 
#> attr(,"method")
#> [1] "chi-square approximation"

# A reallocated mix is detected.
drift_homogeneity(a, sample(c("x", "y", "z"), 300, TRUE,
                            prob = c(0.7, 0.2, 0.1)))
#>     statistic            df       p_value   log_p_value 
#>  6.978222e+01  2.000000e+00  7.030469e-16 -3.489111e+01 
#> attr(,"method")
#> [1] "chi-square approximation"

# Agrees with stats::chisq.test() on the 2-by-k table.
tab <- rbind(table(a), table(b))
all.equal(drift_homogeneity(a, b)[["statistic"]],
          as.numeric(stats::chisq.test(tab)$statistic))
#> [1] TRUE

# It is more conservative than treating the reference as known, which
# is exactly the point.
drift_homogeneity(a, b)[["p_value"]] >= drift_chisq(b, a)[["p_value"]]
#> [1] TRUE
```
