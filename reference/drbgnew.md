# A deterministic random bit generator: AES-256 CTR_DRBG (NIST SP 800-90A)

Creates the counter-mode DRBG of NIST SP 800-90A Rev. 1, section 10.2.1,
with AES-256 and no derivation function, implemented in this package (no
system library). From the same entropy, personalization and additional
inputs it returns the same bytes, which is what reproducible key
generation and known-answer tests need; for keys meant to stay secret,
seed it from
[`rndbytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rndbytes.md)
(the default) or use
[`rndbytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rndbytes.md)
directly.

## Usage

``` r
drbgnew(entropy = NULL, person = NULL)
```

## Arguments

- entropy:

  Entropy input: exactly 48 bytes, as a raw vector or one string of 96
  hexadecimal digits. `NULL` (the default) draws them from the operating
  system's CSPRNG through
  [`rndbytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rndbytes.md).

- person:

  Optional personalization string of up to 48 bytes, raw or hex; `NULL`
  (the default) is the empty string. Different personalization strings
  give independent streams from the same entropy.

## Value

An object of class `bricklayer_drbg` (an environment holding the 32-byte
Key, the 16-byte V, the request count and the process id). Its state
(Key, V) is not printed.

## Details

It reproduces all 720 AES-256 no-df vectors of NIST's DRBG validation
suite (without reseeding, with reseeding, and with prediction
resistance; the package's tests check a sample of them), and it is the
`randombytes()` of NIST's `rng.c`, with which most post-quantum
submissions wrote their known-answer files: `drbgnew(as.raw(0:47))`
followed by `drbggen(d, 48)` gives the `seed` of their vector 0. AES
runs in constant time: the S-box is computed (an inversion in GF(2^8)
and the affine map) rather than looked up, and on x86-64 processors with
AES-NI the rounds use those instructions. Both paths are checked under
valgrind memcheck with the entropy input marked secret (`inst/ctcheck`,
case `drbg-portable` and `drbg-aesni`).

The generator is an object that changes as it is used: every
[`drbggen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbggen.md)
and
[`drbgrsd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbgrsd.md)
advances it in place.

The generator is an environment, so copies share one state. It is not
meant to be saved: a generator restored from
[`saveRDS()`](https://rdrr.io/r/base/readRDS.html) or inherited by a
forked process reseeds itself from the operating system on its next use,
so two processes never replay the same stream (and such a stream is then
no longer reproducible). Errors when `entropy` is not exactly 48 bytes
or `person` is longer than 48 bytes, or either is neither a raw vector
nor one hexadecimal string.

## Security

A hand-written implementation. The standardised schemes are checked byte
for byte against OpenSSL 3.5 and NIST known-answer vectors in the test
suite. Side channels are checked, not assumed: `inst/ctcheck` runs every
operation that touches a secret under valgrind memcheck with the secret
marked undefined (the ctgrind method), so a branch or a memory address
that depends on it is a reported error, and afterwards scans the dead
stack for copies of the secret. Both checks run in CI on every change,
with GCC and with Clang. Timing is also measured on x86-64 and arm64
hardware (`inst/dudect`) and power leakage is assessed in simulation
under the value and the transition models (`inst/tvla`) for the masked
ML-KEM and ML-DSA kernels; this scheme is not masked. These are checks
of this code on those compilers; no third-party security audit has been
commissioned, and the README's security section lists what each check
does and does not cover.

## References

NIST SP 800-90A Rev. 1 (2015). Recommendation for Random Number
Generation Using Deterministic Random Bit Generators, section 10.2.1.
[doi:10.6028/NIST.SP.800-90Ar1](https://doi.org/10.6028/NIST.SP.800-90Ar1)

NIST FIPS 197 (2001, updated 2023). Advanced Encryption Standard (AES).
[doi:10.6028/NIST.FIPS.197-upd1](https://doi.org/10.6028/NIST.FIPS.197-upd1)

## See also

[`drbggen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbggen.md),
[`drbgrsd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbgrsd.md),
[`rndbytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rndbytes.md).

## Examples

``` r
# NIST's rng.c, as the post-quantum known-answer files use it: vector 0's seed
d <- drbgnew(as.raw(0:47))
drbggen(d, 48)
#>  [1] 06 15 50 23 4d 15 8c 5e c9 55 95 fe 04 ef 7a 25 76 7f 2e 24 cc 2b c4 79 d0
#> [26] 9d 86 dc 9a bc fd e7 05 6a 8c 26 6f 9e f9 7e d0 85 41 db d2 e1 ff a1

# the same inputs give the same bytes; a personalization string separates streams
a <- drbgnew(as.raw(1:48), person = charToRaw("session 1"))
b <- drbgnew(as.raw(1:48), person = charToRaw("session 2"))
identical(drbggen(a, 16), drbggen(b, 16))
#> [1] FALSE

# seeded from the operating system
d <- drbgnew()
length(drbggen(d, 32))
#> [1] 32

# the entropy must be exactly 48 bytes
try(drbgnew(as.raw(1:16)))
#> Error : `entropy` must be exactly 48 bytes, raw or hex
```
