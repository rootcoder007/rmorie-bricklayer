# Chi-square test of homogeneity for two categorical samples

Tests whether two samples of a categorical variable (for example race,
offence type or region in an old and a new data extract) were drawn from
the same distribution, by Pearson's chi-square on the 2-by-k contingency
table of their counts. Use it to ask whether the mix of categories has
changed between two samples; it is the categorical test that
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
runs.

## Usage

``` r
drfthomog(x, y, seed = 1L)
```

## Arguments

- x, y:

  Factor or character vectors (or named count vectors) – the reference
  and the new sample.

- seed:

  Integer, default 1: seed for the Monte Carlo branch (small expected
  counts). The draw is made under this seed and the caller's RNG stream
  is restored, so the same inputs give the same p-value and nothing
  downstream moves.

## Value

A named length-4 numeric: `statistic`, `df`, `p_value` and `logpvalue`,
the natural log of the upper tail, which keeps its information where
`p_value` underflows to 0. On the Monte Carlo branch (sparse tables)
`p_value` is floored at 1/(B+1) and `logpvalue` is its log, so it
carries no extra range there. The attribute `method` names the branch,
or says why the test was inapplicable (one category, no counts).

## Details

With pooled shares \\\hat\pi_j = (x_j + y_j)/(n_x + n_y)\\ and expected
counts \\n_x \hat\pi_j\\ and \\n_y \hat\pi_j\\, \$\$X^2 = \sum_j
\frac{(x_j - n_x\hat\pi_j)^2}{n_x\hat\pi_j} + \frac{(y_j -
n_y\hat\pi_j)^2}{n_y\hat\pi_j}\$\$ on \\k - 1\\ degrees of freedom.
Three branches, named in the `method` attribute:

- `"chi-square approximation"`: every expected count is at least 5; the
  p-value is the chi-square upper tail.

- `"Monte Carlo permutation (small expected counts)"`: some expected
  count is below 5; the p-value then comes from
  [`stats::chisq.test()`](https://rdrr.io/r/stats/chisq.test.html) with
  `simulate.p.value = TRUE` and `B = 10000` tables with the same
  margins, drawn under `seed`.

- `"inapplicable: ..."`: a single category, or fewer than two
  observations per category (for example two disjoint sets of dates); no
  test has power there, so `p_value` is `NA` rather than 1.

Errors: a numeric vector without names; negative, infinite or missing
counts; an empty sample.

## Why this and not [`drftchisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftchisq.md)

[`drftchisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftchisq.md)
compares observed counts against a distribution taken as KNOWN –
proportions fixed by a specification. When the reference is itself a
finite sample, that treatment ignores the reference's own sampling
error, understates the variance of the comparison, and so reports drift
too readily. A homogeneity test estimates the shared distribution from
the pooled margins and carries the uncertainty of both samples, which is
the right test when comparing a pinned extract with a fresh fetch.
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
therefore uses this one.

Categories present in only one sample are aligned by name and given zero
counts, so an appearing or vanishing level registers.

## See also

[`drftchisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftchisq.md)
for a known reference distribution,
[`stats::chisq.test()`](https://rdrr.io/r/stats/chisq.test.html) for the
full test object.

## Examples

``` r
set.seed(1)
a <- sample(c("x", "y", "z"), 300, TRUE)
b <- sample(c("x", "y", "z"), 300, TRUE)

# Two draws from the same distribution: no evidence of a difference.
drfthomog(a, b)
#>  statistic         df    p_value  logpvalue 
#>  0.5150386  2.0000000  0.7729667 -0.2575193 
#> attr(,"method")
#> [1] "chi-square approximation"

# A reallocated mix is detected.
drfthomog(a, sample(c("x", "y", "z"), 300, TRUE,
                            prob = c(0.7, 0.2, 0.1)))
#>     statistic            df       p_value     logpvalue 
#>  6.978222e+01  2.000000e+00  7.030469e-16 -3.489111e+01 
#> attr(,"method")
#> [1] "chi-square approximation"

# Agrees with stats::chisq.test() on the 2-by-k table.
tab <- rbind(table(a), table(b))
all.equal(drfthomog(a, b)[["statistic"]],
          as.numeric(stats::chisq.test(tab)$statistic))
#> [1] TRUE

# It is more conservative than treating the reference as known, which
# is exactly the point.
drfthomog(a, b)[["p_value"]] >= drftchisq(b, a)[["p_value"]]
#> [1] TRUE

# named count vectors, and a small table that takes the Monte Carlo branch
drfthomog(c(a = 30, b = 20), c(a = 25, b = 25))
#>  statistic         df    p_value  logpvalue 
#>  1.0101010  1.0000000  0.3148786 -1.1555680 
#> attr(,"method")
#> [1] "chi-square approximation"
attr(drfthomog(c(a = 3, b = 1, c = 2), c(a = 1, b = 4, c = 1)), "method")
#> [1] "Monte Carlo permutation (small expected counts)"

try(drfthomog(c(1, 2), c(a = 3)))
#> Error : a numeric `x`/`y` must be named
```
