# Cryptographically strong random bytes

Returns `n` random bytes that are suitable for keys, salts and nonces.
Use it whenever a value must be unguessable; use
[`set.seed()`](https://rdrr.io/r/base/Random.html) and
[`runif()`](https://rdrr.io/r/stats/Uniform.html) for simulations, where
reproducibility is the point.

## Usage

``` r
rndbytes(n)
```

## Arguments

- n:

  Whole number from 1 to 1048576: the number of bytes.

## Value

A raw vector of length `n`. Print it as hex with
`paste(format(x), collapse = "")`.

## Details

Reads the operating system's own random source rather than R's Mersenne
Twister: `/dev/urandom` on Unix and macOS, `RtlGenRandom` on Windows.

This distinction matters for anything that becomes a key.
[`set.seed()`](https://rdrr.io/r/base/Random.html) makes R's generator
reproducible BY DESIGN, and its state can be recovered from its output;
a key drawn from it is guessable. Reading the OS source also leaves R's
own random stream untouched, so generating a key does not perturb a
reproducible analysis.

If no OS source can be read the function FAILS rather than falling back
to a weaker generator, because a silent downgrade in a key is worse than
an error.

Errors: `n` not a single whole number from 1 to 1,048,576 (1 MiB); no
readable operating-system source.

## See also

[`drvkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drvkey.md)
to stretch a passphrase instead,
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md)
which uses this for its seeds.

## Examples

``` r
rndbytes(8)
#> [1] 68 88 60 81 f1 92 d6 26

# Independent between calls, unlike a seeded generator.
identical(rndbytes(16), rndbytes(16))
#> [1] FALSE

# R's own stream is not consumed, so a seeded analysis is unaffected.
set.seed(1)
a <- stats::runif(1)
set.seed(1)
invisible(rndbytes(32))
identical(stats::runif(1), a)
#> [1] TRUE

# As hex, for a seed argument.
paste(format(rndbytes(4)), collapse = "")
#> [1] "b918140f"

try(rndbytes(0))
#> Error : `n` must be a single integer between 1 and 1048576
```
