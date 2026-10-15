# Assemble a standardised key from raw key material

Wraps key bytes that came from somewhere else – another implementation,
a key store, a file written by an earlier session – in the object
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
and
[`capsule_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_verify.md)
expect. The lengths are checked against the parameter set, so material
for the wrong scheme is refused here rather than producing a signature
nothing can verify.

## Usage

``` r
fips_key(scheme, public, secret = NULL)
```

## Arguments

- scheme:

  Scheme name, as in
  [`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md).

- public:

  Public key, hex or raw.

- secret:

  Secret key, hex or raw. Omit for a verification-only key.

## Value

A `bricklayer_fips_key` (`public`, `secret`, `scheme`) when `secret` is
given, otherwise a `bricklayer_fips_public_key` (`public`, `scheme`);
keys are held as lowercase hex, as
[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
returns them.

## Details

The byte layouts are the standards' own, which is what makes this
interoperable: an ML-DSA secret key is
`rho || K || tr || s1 || s2 || t0` and an SLH-DSA one is
`SK.seed || SK.prf || PK.seed || PK.root`, exactly as FIPS 204 and FIPS
205 encode them.

Hex input may be upper or lower case and is stored lower case; raw input
is converted to hex. Only the lengths are checked (against
[`fips_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_sizes.md)):
a secret key that does not belong to the public key is not detected
here, and gives signatures that do not verify under that public key.
Refusals: an unknown scheme, and material that is not hex of an even
length or not exactly the scheme's length
(`"must be N bytes of key material"`).

## See also

[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md),
[`fips_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_sizes.md).

## Examples

``` r
key <- fips_keygen("ML-DSA-44")
# the round trip through raw material changes nothing
again <- fips_key("ML-DSA-44", key$public, key$secret)
identical(again$secret, key$secret)
#> [1] TRUE

sig <- capsule_sign("m", again)
capsule_verify("m", sig, fips_key("ML-DSA-44", key$public))
#> [1] TRUE

# material of the wrong length is refused
try(fips_key("ML-DSA-65", key$public, key$secret))
#> Error : `public` must be 1952 bytes of key material for ML-DSA-65
```
