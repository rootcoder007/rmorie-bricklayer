# A deterministic random bit generator: AES-256 CTR_DRBG (NIST SP 800-90A)

Creates the counter-mode DRBG of NIST SP 800-90A Rev. 1, section 10.2.1,
with AES-256 and no derivation function, implemented in this package (no
system library). From the same entropy, personalization and additional
inputs it returns the same bytes, which is what reproducible key
generation and known-answer tests need; for keys meant to stay secret,
seed it from
[`random_bytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/random_bytes.md)
(the default) or use
[`random_bytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/random_bytes.md)
directly.

## Usage

``` r
drbg_new(entropy = NULL, personalization = NULL)
```

## Arguments

- entropy:

  Entropy input: 48 bytes, raw or hex. `NULL` (the default) draws them
  from the operating system's CSPRNG.

- personalization:

  Optional personalization string of up to 48 bytes, raw or hex.

## Value

An object of class `bricklayer_drbg`. Its state (Key, V) is not printed.

## Details

It reproduces all 720 AES-256 no-df vectors of NIST's DRBG validation
suite (without reseeding, with reseeding, and with prediction
resistance; the package's tests check a sample of them), and it is the
`randombytes()` of NIST's `rng.c`, with which most post-quantum
submissions wrote their known-answer files: `drbg_new(as.raw(0:47))`
followed by `drbg_generate(d, 48)` gives the `seed` of their vector 0.
AES runs in constant time: the S-box is computed (an inversion in
GF(2^8) and the affine map) rather than looked up, and on x86-64
processors with AES-NI the rounds use those instructions. Both paths are
checked under valgrind memcheck with the entropy input marked secret
(`inst/ctcheck`, case `drbg-portable` and `drbg-aesni`).

The generator is an object that changes as it is used: every
[`drbg_generate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_generate.md)
and
[`drbg_reseed()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_reseed.md)
advances it in place.

## Security

A hand-written implementation. The standardised schemes are checked byte
for byte against OpenSSL 3.5 and NIST known-answer vectors in the test
suite. Side channels are checked, not assumed: `inst/ctcheck` runs every
operation that touches a secret under valgrind memcheck with the secret
marked undefined (the ctgrind method), so a branch or a memory address
that depends on it is a reported error, and afterwards scans the dead
stack for copies of the secret. Both checks run in CI on every change,
with GCC and with Clang. They are checks of this code on those
compilers, not of the hardware it runs on, and no third-party audit has
been commissioned; the README's security section says exactly what is
and is not covered.

## References

NIST SP 800-90A Rev. 1 (2015). Recommendation for Random Number
Generation Using Deterministic Random Bit Generators, section 10.2.1.
[doi:10.6028/NIST.SP.800-90Ar1](https://doi.org/10.6028/NIST.SP.800-90Ar1)

NIST FIPS 197 (2001, updated 2023). Advanced Encryption Standard (AES).
[doi:10.6028/NIST.FIPS.197-upd1](https://doi.org/10.6028/NIST.FIPS.197-upd1)

## See also

[`drbg_generate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_generate.md),
[`drbg_reseed()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_reseed.md),
[`random_bytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/random_bytes.md).

## Examples

``` r
# NIST's rng.c, as the post-quantum known-answer files use it: vector 0's seed
d <- drbg_new(as.raw(0:47))
drbg_generate(d, 48)
#>  [1] 06 15 50 23 4d 15 8c 5e c9 55 95 fe 04 ef 7a 25 76 7f 2e 24 cc 2b c4 79 d0
#> [26] 9d 86 dc 9a bc fd e7 05 6a 8c 26 6f 9e f9 7e d0 85 41 db d2 e1 ff a1

# the same inputs give the same bytes; a personalization string separates streams
a <- drbg_new(as.raw(1:48), personalization = charToRaw("session 1"))
b <- drbg_new(as.raw(1:48), personalization = charToRaw("session 2"))
identical(drbg_generate(a, 16), drbg_generate(b, 16))
#> [1] FALSE

# seeded from the operating system
d <- drbg_new()
length(drbg_generate(d, 32))
#> [1] 32
```
