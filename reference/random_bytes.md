# Cryptographically strong random bytes

Reads the operating system's own random source – `/dev/urandom` on Unix
and macOS, `RtlGenRandom` on Windows – rather than R's Mersenne Twister.

## Usage

``` r
random_bytes(n)
```

## Arguments

- n:

  Number of bytes (1 to 1048576).

## Value

A raw vector of length `n`.

## Details

This distinction matters for anything that becomes a key.
[`set.seed()`](https://rdrr.io/r/base/Random.html) makes R's generator
reproducible BY DESIGN, and its state can be recovered from its output;
a key drawn from it is guessable. Reading the OS source also leaves R's
own random stream untouched, so generating a key does not perturb a
reproducible analysis.

If no OS source can be read the function FAILS rather than falling back
to a weaker generator, because a silent downgrade in a key is worse than
an error.

## See also

[`derive_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/derive_key.md)
to stretch a passphrase instead,
[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
which uses this for its seeds.

## Examples

``` r
random_bytes(8)
#> [1] 71 43 8c 5a 22 fa 01 0a

# Independent between calls, unlike a seeded generator.
identical(random_bytes(16), random_bytes(16))
#> [1] FALSE

# R's own stream is not consumed, so a seeded analysis is unaffected.
set.seed(1)
a <- stats::runif(1)
set.seed(1)
invisible(random_bytes(32))
identical(stats::runif(1), a)
#> [1] TRUE

# As hex, for a seed argument.
paste(format(random_bytes(4)), collapse = "")
#> [1] "38e183ba"
```
