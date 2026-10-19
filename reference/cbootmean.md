# Bootstrap replicate means (C backend)

`B` resamples of `x`, drawn with replacement and each the same length as
`x`, with the mean of every resample returned. The spread of these
replicate means estimates the standard error of the sample mean, and
their quantiles give a percentile confidence interval, without assuming
the data are normal (Efron and Tibshirani, 1993). The resampling uses
the core's own 64-bit Mersenne Twister seeded by `seed`, NOT R's RNG, so
a given `seed` reproduces the same replicates in every binding of the
core and R's own random stream is left untouched.

## Usage

``` r
cbootmean(x, B = 1000L, seed = 42L)
```

## Arguments

- x:

  Numeric (or logical) vector to resample.

- B:

  Number of bootstrap replicates, a single whole number of at least 1
  (default 1000).

- seed:

  Seed for the core's generator, a single non-negative whole number
  (default 42). It does not use or change
  [`set.seed()`](https://rdrr.io/r/base/Random.html)'s stream.

## Value

A numeric vector of length `B`: the replicate means, in the units of
`x`.

## Details

Replicate \\b\\ draws \\n\\ indices uniformly from \\1, \dots, n\\ with
replacement (C++ `std::mt19937_64` seeded with `seed`, then
`std::uniform_int_distribution`, whose algorithm is the C++ library's
own, so the replicates for a seed can differ between libstdc++ and
libc++) and returns the mean of the drawn values, accumulated in
extended precision. The replicates are a single stream: the first `B`
replicates for a seed are the same whatever larger `B` is asked for
later.

Edge cases: an empty `x` gives `B` values of `NaN`; an `NA` in `x` makes
every replicate that draws it `NA`, so remove missing values first. `B`
must be a whole number of at least 1
(`"B must be a single whole number >= 1"`); a character, factor or list
`x` is refused (`"must be numeric"`). `seed` must be a whole number from
0 to below \\2^{53}\\: `NA`, a negative or a fractional seed is refused.

Performance: the work is \\B \times n\\ draws (about 0.4 s for \\B =
2000\\, \\n = 20000\\ on a laptop). The kernel polls for a Ctrl-C after
about every million draws, so a long run can be interrupted; while it
runs, an interactive session (or one with
`options(morie.progress = TRUE)`) shows a spinner on stderr from 0.75 s
on, and `options(morie.quiet = TRUE)` silences it.

## References

Efron B, Tibshirani RJ (1993). *An Introduction to the Bootstrap*.
Chapman and Hall.

## See also

[`exprspplr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/exprspplr.md)
for a bootstrap of a model estimate.

## Examples

``` r
set.seed(1)
x <- stats::rnorm(50, mean = 5)

reps <- cbootmean(x, B = 500, seed = 7)
length(reps)
#> [1] 500

# The replicates centre on the sample mean, and their spread estimates
# the standard error.
c(sample = mean(x), bootstrap = mean(reps))
#>    sample bootstrap 
#>  5.100448  5.097066 
c(bootstrapse = stats::sd(reps),
  formulase = stats::sd(x) / sqrt(length(x)))
#> bootstrapse   formulase 
#>   0.1174288   0.1175769 

# A percentile confidence interval for the mean.
stats::quantile(reps, c(0.025, 0.975))
#>     2.5%    97.5% 
#> 4.864298 5.311439 

# Reproducible: the same seed gives the same replicates, and R's own
# random stream is not consumed.
identical(cbootmean(x, 100, seed = 1),
          cbootmean(x, 100, seed = 1))
#> [1] TRUE

# A longer run continues the same stream.
identical(cbootmean(x, 10, seed = 1),
          cbootmean(x, 100, seed = 1)[1:10])
#> [1] TRUE

# At least one replicate is needed.
try(cbootmean(x, B = 0))
#> Error : `B` must be a single whole number >= 1
```
