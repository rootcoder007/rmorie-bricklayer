# Exact summary statistics accumulated in blocks

An accumulator for the count, mean, variance, skewness and kurtosis of a
numeric column that does not fit in memory, or that arrives in pieces (a
file read in chunks, results from several machines). Start one with
`online_summary()`, feed it blocks with `summary_update()`, combine two
with `summary_merge()` and read the result with `summary_stats()`.

## Usage

``` r
online_summary(x = NULL)

summary_update(acc, x)

summary_merge(a, b)

summary_stats(acc)
```

## Arguments

- x:

  Numeric vector: the first block, or `NULL` (the default) for an empty
  accumulator; for `summary_update()`, the next block.

- acc, a, b:

  Accumulators from `online_summary()`.

## Value

`online_summary()`, `summary_update()` and `summary_merge()` return an
object of class `c("bricklayer_online", "list")` (its `state` element is
the numeric vector described in Details); `summary_stats()` returns a
named numeric vector with `n`, `mean`, `variance`, `sd`, `skewness` and
`kurtosis` (excess).

## Details

The merge is EXACT, not approximate: it uses Chan, Golub and LeVeque's
parallel combination of central sums, extended to the third and fourth
moments by Terriberry, so accumulating a column in blocks gives the same
answer as
[`core_moments()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_moments.md)
over the whole column at once. That is what makes it usable for a
capsule member of any size: memory stays constant in the number of
blocks.

The state is \\(n, \bar{x}, M_2, M_3, M_4)\\ with \\M_k = \sum (x_i -
\bar{x})^k\\. `summary_stats()` reports the sample variance \\M_2 / (n -
1)\\, the moment skewness \\g_1 = (M_3/n) / (M_2/n)^{3/2}\\ and the
excess kurtosis \\g_2 = (M_4/n) / (M_2/n)^2 - 3\\ (the biased moment
estimators, without small-sample correction). `NA` values are dropped
from every block. Undefined quantities are `NaN`: the mean for \\n =
0\\, the variance for \\n \< 2\\, the skewness for \\n \< 3\\ and the
kurtosis for \\n \< 4\\, and both shape statistics for a constant
column.

The object is a plain list and is copied on assignment like any other R
value, so `summary_update()` returns the new accumulator and you must
keep it: `acc <- summary_update(acc, block)`.

Errors: a block that is not numeric; an accumulator that does not come
from `online_summary()`.

## References

Chan TF, Golub GH, LeVeque RJ (1983). Algorithms for computing the
sample variance: analysis and recommendations. *The American
Statistician* 37(3), 242–247.
[doi:10.1080/00031305.1983.10483115](https://doi.org/10.1080/00031305.1983.10483115)

## See also

[`core_moments()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_moments.md)
for the single-pass batch version.

## Examples

``` r
set.seed(1)
x <- stats::rnorm(1000)

# Accumulate in blocks of 100.
acc <- online_summary()
for (i in seq(1, 1000, by = 100)) {
  acc <- summary_update(acc, x[i:(i + 99)])
}
summary_stats(acc)
#>             n          mean      variance            sd      skewness 
#>  1.000000e+03 -1.164814e-02  1.071051e+00  1.034916e+00 -1.916710e-02 
#>      kurtosis 
#> -1.775465e-03 

# Which is exactly the batch answer, not an approximation to it.
all.equal(summary_stats(acc)[["variance"]], stats::var(x))
#> [1] TRUE
all.equal(summary_stats(acc)[["mean"]], mean(x))
#> [1] TRUE

# Two accumulators built independently can be merged, so blocks can be
# processed in any order or on different machines.
a <- summary_update(online_summary(), x[1:400])
b <- summary_update(online_summary(), x[401:1000])
all.equal(summary_stats(summary_merge(a, b)), summary_stats(acc))
#> [1] TRUE

# An empty accumulator reports nothing rather than zero.
summary_stats(online_summary())
#>        n     mean variance       sd skewness kurtosis 
#>        0      NaN      NaN      NaN      NaN      NaN 

# NA values are skipped; text is refused
summary_stats(online_summary(c(1, NA, 3)))[c("n", "mean")]
#>    n mean 
#>    2    2 
try(online_summary(c("1", "2")))
#> ── Accumulated summary ─────────────────────────────────────────── 
#>   n         2
#>   mean          1.5
#>   sd        0.707107
#>   skewness    NaN
#>   kurtosis    NaN
#> ────────────────────────────────────────────────────────────────── 
```
