# Reproducible uniforms shared with morie's Python arm (splitmix64)

The splitmix64 generator (Steele, Lea & Flood 2014): `n` uniforms on
\[0, 1) from a 64-bit `seed`, the same numbers morie's Python computes,
so the R and Python arms can draw identical "random" values where their
results must agree (the within-day jitter of tied event dates in the TPS
Hawkes fits, a subsample). Not a statistical replacement for R's own
generators.

## Usage

``` r
core_uniforms(n, seed)
```

## Arguments

- n:

  Number of uniforms.

- seed:

  A non-negative whole number below 2^53.

## Value

A numeric vector of length `n`.

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
```
