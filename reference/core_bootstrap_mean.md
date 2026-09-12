# Bootstrap replicate means (C backend)

`B` resamples of `x`, drawn with replacement and each the same length as
`x`, with the mean of every resample returned. The resampling uses the
core's own 64-bit Mersenne Twister seeded by `seed`, NOT R's RNG, so a
given `seed` reproduces the same replicates in every binding of the core
and R's own random stream is left untouched.

## Usage

``` r
core_bootstrap_mean(x, B = 1000L, seed = 42L)
```

## Arguments

- x:

  Numeric vector to resample.

- B:

  Number of bootstrap replicates (default 1000).

- seed:

  Seed for the core's generator (default 42).

## Value

A numeric vector of length `B`: the replicate means.

## Examples

``` r
set.seed(1)
x <- stats::rnorm(50, mean = 5)

reps <- core_bootstrap_mean(x, B = 500, seed = 7)
length(reps)
#> [1] 500

# The replicates centre on the sample mean, and their spread estimates
# the standard error.
c(sample = mean(x), bootstrap = mean(reps))
#>    sample bootstrap 
#>  5.100448  5.097066 
c(bootstrap_se = stats::sd(reps), formula_se = stats::sd(x) / sqrt(length(x)))
#> bootstrap_se   formula_se 
#>    0.1174288    0.1175769 

# A percentile confidence interval for the mean.
stats::quantile(reps, c(0.025, 0.975))
#>     2.5%    97.5% 
#> 4.864298 5.311439 

# Reproducible: the same seed gives the same replicates, and R's own
# random stream is not consumed.
identical(core_bootstrap_mean(x, 100, seed = 1),
          core_bootstrap_mean(x, 100, seed = 1))
#> [1] TRUE
```
