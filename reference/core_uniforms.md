# Reproducible uniforms shared with morie's Python arm (splitmix64)

Returns `n` pseudo-random numbers on \[0, 1) from a 64-bit seed with the
splitmix64 generator, the same numbers morie's Python computes for the
same seed. Use it where the R and Python arms must draw identical
"random" values so that their results agree: the within-day jitter of
tied event dates in the TPS Hawkes fits, or a subsample.

## Usage

``` r
core_uniforms(n, seed)
```

## Arguments

- n:

  Number of uniforms, one non-negative whole number (0 gives
  `numeric(0)`).

- seed:

  The seed, one whole number in \\\[0, 2^{53})\\ (so that it is exact as
  an R double).

## Value

A numeric vector of length `n`, values in \[0, 1).

## Details

splitmix64 (Steele, Lea & Flood 2014) advances a 64-bit state by the
constant `0x9E3779B97F4A7C15` and mixes it with two multiply-xorshift
rounds; the top 53 bits of each output divided by \\2^{53}\\ give a
double in \[0, 1). The stream depends only on `seed`: R's own generator
and [`set.seed()`](https://rdrr.io/r/base/Random.html) are neither used
nor changed. It is not a statistical replacement for R's generators.

Errors: `n` not one non-negative whole number; `seed` not one whole
number in \\\[0, 2^{53})\\.

## References

Steele GL, Lea D, Flood CH (2014). Fast splittable pseudorandom number
generators. *OOPSLA 2014*, 453–472.
[doi:10.1145/2660193.2660195](https://doi.org/10.1145/2660193.2660195)

## Examples

``` r
core_uniforms(3, 42)
#> [1] 0.7415649 0.1599104 0.2786011
identical(core_uniforms(5, 1), core_uniforms(5, 1))
#> [1] TRUE

# a stream is a prefix of a longer one with the same seed
all.equal(core_uniforms(3, 7), core_uniforms(10, 7)[1:3])
#> [1] TRUE

# R's own generator is left alone
set.seed(1); a <- runif(1)
set.seed(1); invisible(core_uniforms(100, 9)); b <- runif(1)
identical(a, b)
#> [1] TRUE

# negative counts and seeds past 2^53 are refused
try(core_uniforms(-1, 1))
#> Error : `n` must be a non-negative whole number
try(core_uniforms(2, 2^53))
#> Error : `seed` must be a whole number in [0, 2^53)
```
