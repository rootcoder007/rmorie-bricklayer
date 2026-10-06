# Generate a standardised post-quantum signing key (deprecated name)

Kept so code written against the liboqs-backed version keeps working.
The schemes are no longer reached through liboqs – they are implemented
in this package – and the name no longer describes anything, so use
[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
instead.

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
and
[`fips_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md).

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

## See also

[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md).

## Examples

``` r
# Deprecated: use fips_keygen().
key <- suppressWarnings(oqs_keygen("ML-DSA-65"))
key$scheme
#> [1] "ML-DSA-65"
```
