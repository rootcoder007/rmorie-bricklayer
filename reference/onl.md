# Summary statistics accumulated in blocks

An accumulator for the count, mean, variance, skewness and kurtosis of a
numeric column that does not fit in memory, or that arrives in pieces (a
file read in chunks, results from several machines). Start one with
`onlsmry()`, feed it blocks with `smryupd()`, combine two with
`smrymrg()` and read the result with `smrystat()`.

## Usage

``` r
onlsmry(x = NULL)

smryupd(acc, x)

smrymrg(a, b)

smrystat(acc)
```

## Arguments

- x:

  Numeric vector: the first block, or `NULL` (the default) for an empty
  accumulator; for `smryupd()`, the next block.

- acc, a, b:

  Accumulators from `onlsmry()`.

## Value

`onlsmry()`, `smryupd()` and `smrymrg()` return an object of class
`c("bricklayer_online", "list")` (its `state` element is the numeric
vector described in Details); `smrystat()` returns a named numeric
vector with `n`, `mean`, `variance`, `sd`, `skewness` and `kurtosis`
(excess).

## Details

The merge is exact algebra, not an approximation: it uses Chan, Golub
and LeVeque's parallel combination of central sums, extended to the
third and fourth moments by Terriberry, so accumulating a column in
blocks gives the answer of
[`cmom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cmom.md)
over the whole column at once, to the rounding of double arithmetic.
Each block's sums are taken in two passes, as
[`var()`](https://rdrr.io/r/stats/cor.html) takes them, so values far
from zero keep their digits: values near \\10^8\\ with a spread of 1, in
blocks of 100, give the variance of
[`var()`](https://rdrr.io/r/stats/cor.html) to a relative \\10^{-11}\\
(one pass lost nine digits). That is what makes it usable for a capsule
member of any size: memory stays constant in the number of blocks.

The state is \\(n, \bar{x}, M_2, M_3, M_4)\\ with \\M_k = \sum (x_i -
\bar{x})^k\\. `smrystat()` reports the sample variance \\M_2 / (n -
1)\\, the moment skewness \\g_1 = (M_3/n) / (M_2/n)^{3/2}\\ and the
excess kurtosis \\g_2 = (M_4/n) / (M_2/n)^2 - 3\\ (the biased moment
estimators, without small-sample correction). `NA` values are dropped
from every block. Undefined quantities are `NaN`: the mean for \\n =
0\\, the variance for \\n \< 2\\, the skewness for \\n \< 3\\ and the
kurtosis for \\n \< 4\\, and both shape statistics for a constant
column.

The object is a plain list and is copied on assignment like any other R
value, so `smryupd()` returns the new accumulator and you must keep it:
`acc <- smryupd(acc, block)`.

Errors: a block that is not numeric; an accumulator that does not come
from `onlsmry()`.

## References

Chan TF, Golub GH, LeVeque RJ (1983). Algorithms for computing the
sample variance: analysis and recommendations. *The American
Statistician* 37(3), 242–247.
[doi:10.1080/00031305.1983.10483115](https://doi.org/10.1080/00031305.1983.10483115)

## See also

[`cmom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cmom.md)
for the single-pass batch version.

## Examples

``` r
set.seed(1)
x <- stats::rnorm(1000)

# Accumulate in blocks of 100.
acc <- onlsmry()
for (i in seq(1, 1000, by = 100)) {
  acc <- smryupd(acc, x[i:(i + 99)])
}
smrystat(acc)
#>             n          mean      variance            sd      skewness 
#>  1.000000e+03 -1.164814e-02  1.071051e+00  1.034916e+00 -1.916710e-02 
#>      kurtosis 
#> -1.775465e-03 

# The batch answer to rounding (the formulas are exact; the arithmetic is double):
all.equal(smrystat(acc)[["variance"]], stats::var(x))
#> [1] TRUE
all.equal(smrystat(acc)[["mean"]], mean(x))
#> [1] TRUE

# Two accumulators built independently can be merged, so blocks can be
# processed in any order or on different machines.
a <- smryupd(onlsmry(), x[1:400])
b <- smryupd(onlsmry(), x[401:1000])
all.equal(smrystat(smrymrg(a, b)), smrystat(acc))
#> [1] TRUE

# An empty accumulator reports nothing rather than zero.
smrystat(onlsmry())
#>        n     mean variance       sd skewness kurtosis 
#>        0      NaN      NaN      NaN      NaN      NaN 

# NA values are skipped; text is refused
smrystat(onlsmry(c(1, NA, 3)))[c("n", "mean")]
#>    n mean 
#>    2    2 
try(onlsmry(c("1", "2")))
#> ── Accumulated summary ─────────────────────────────────────────── 
#>   n         2
#>   mean          1.5
#>   sd        0.707107
#>   skewness    NaN
#>   kurtosis    NaN
#> ────────────────────────────────────────────────────────────────── 
```
