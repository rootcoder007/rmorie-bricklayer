# Chi-square test for a categorical column

Pearson's chi-square goodness-of-fit statistic comparing observed
category counts with the proportions a capsule was pinned against. Use
it where
[`drift_ks()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_ks.md)
cannot apply, because the column is a factor or a set of codes rather
than a number.

## Usage

``` r
drift_chisq(observed, expected)
```

## Arguments

- observed:

  Named numeric vector of counts in the new sample, or a
  factor/character vector to be tabulated.

- expected:

  Named numeric vector of reference counts or proportions, or a
  factor/character vector to be tabulated. Rescaled to the total of
  `observed`.

## Value

A named length-3 numeric: `statistic`, `df`, `p_value`.

## Details

Categories present in one argument and not the other are aligned by
name, so a vanished category registers as a shortfall against its
expected count.

A category that OCCURS but which the reference gives probability zero
contradicts the pinned distribution outright, and its chi-square term is
unbounded; `statistic` is then `Inf` and `p_value` is `0`. If a new
category is a legitimate possibility rather than a contradiction – which
it usually is when the reference is itself a finite sample – use
[`drift_homogeneity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_homogeneity.md)
instead.

## See also

[`stats::chisq.test()`](https://rdrr.io/r/stats/chisq.test.html) for the
full test object.

## Examples

``` r
ref <- c(a = 50, b = 30, c = 20)

# Counts matching the reference proportions: nothing to report.
drift_chisq(c(a = 100, b = 60, c = 40), ref)
#> statistic        df   p_value 
#>         0         2         1 

# A reallocated mix is detected.
drift_chisq(c(a = 40, b = 60, c = 100), ref)
#> statistic        df   p_value 
#>       126         2         0 

# Agrees with stats::chisq.test().
o <- c(a = 40, b = 60, c = 100)
all.equal(drift_chisq(o, ref)[["statistic"]],
          as.numeric(stats::chisq.test(o, p = ref / sum(ref))$statistic))
#> [1] TRUE

# Raw vectors are tabulated for you.
drift_chisq(c("a", "a", "b", "b"), c("a", "b"))
#> statistic        df   p_value 
#>         0         1         1 

# A category the reference rules out, but which occurs, is a flat
# contradiction rather than a large finite statistic.
drift_chisq(c("a", "a", "b", "d"), c("a", "a", "b", "b"))
#> statistic        df   p_value 
#>       Inf         1         0 

# When a new category is legitimate, compare two samples instead.
drift_homogeneity(c("a", "a", "b", "b"), c("a", "a", "b", "d"))
#> statistic        df   p_value 
#> 1.3333333 2.0000000 0.5134171 
```
