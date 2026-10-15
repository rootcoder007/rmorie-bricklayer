# Generate a standardised post-quantum signing key (deprecated name)

Kept so code written against the liboqs-backed version keeps working.
The schemes are no longer reached through liboqs – they are implemented
in this package – and the name no longer describes anything, so use
[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
instead. New code should not call these functions.

## Usage

``` r
oqs_keygen(scheme = "ML-DSA-65")

oqs_public_key(key)
```

## Arguments

- scheme:

  Scheme name; see
  [`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md).

- key:

  A key from `oqs_keygen()`.

## Value

As
[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
(a `bricklayer_fips_key`) and
[`fips_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
(a `bricklayer_fips_public_key`).

## Details

`oqs_keygen()` calls
[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
(with a fresh random seed) and `oqs_public_key()` calls
[`fips_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md),
each after a deprecation warning from
[`.Deprecated()`](https://rdrr.io/r/base/Deprecated.html). The keys are
the same objects
[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
returns, with the same classes.

## Security

A hand-written implementation. The standardised schemes are checked byte
for byte against OpenSSL 3.5 and NIST known-answer vectors in the test
suite. Side channels are checked, not assumed: `inst/ctcheck` runs every
operation that touches a secret under valgrind memcheck with the secret
marked undefined (the ctgrind method), so a branch or a memory address
that depends on it is a reported error, and afterwards scans the dead
stack for copies of the secret. Both checks run in CI on every change,
with GCC and with Clang. Timing is also measured on x86-64 and arm64
hardware (`inst/dudect`), power leakage is assessed in simulation under
the value and the transition models (`inst/tvla`), and ML-KEM
decapsulation and ML-DSA signing are first-order masked by default.
These are checks of this code on those compilers and under those leakage
models; no third-party security audit has been commissioned, and the
README's security section lists what each check does and does not cover.

## See also

[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md).

## Examples

``` r
# Deprecated: use fips_keygen().
key <- suppressWarnings(oqs_keygen("ML-DSA-65"))
key$scheme
#> [1] "ML-DSA-65"

# The same as the current name, after a warning.
pub <- suppressWarnings(oqs_public_key(key))
identical(pub, fips_public_key(key))
#> [1] TRUE

# The warning names the replacement.
tryCatch(oqs_keygen(), warning = function(w) conditionMessage(w))
#> [1] "'oqs_keygen' is deprecated.\nUse 'fips_keygen' instead.\nSee help(\"Deprecated\")"
```
