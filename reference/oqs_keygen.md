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

## See also

[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md).

## Examples

``` r
# Deprecated: use fips_keygen().
key <- suppressWarnings(oqs_keygen("ML-DSA-65"))
key$scheme
#> [1] "ML-DSA-65"
```
