# Generate a standardised post-quantum signing key

Generates a key for one of the NIST-standardised signature schemes –
ML-DSA (FIPS 204) or SLH-DSA (FIPS 205) – **through liboqs**.

## Usage

``` r
oqs_keygen(scheme = "ML-DSA-65")

oqs_public_key(key)
```

## Arguments

- scheme:

  Scheme name, as reported by
  [`pqc_backends()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_backends.md).
  The default `"ML-DSA-65"` is the FIPS 204 middle security level.

- key:

  A key from `oqs_keygen()`.

## Value

A list of class `bricklayer_oqs_key`: `public`, `secret` (both hex), and
`scheme`.

## Details

bricklayer implements no lattice arithmetic of its own. These keys and
signatures are produced entirely by the Open Quantum Safe library, which
is tested and maintained for the purpose; a hand-written NTT and
rejection sampler here would be a worse outcome than deferring. The
trade-off is that the scheme is available only where liboqs was found at
build time, which
[`pqc_backends()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_backends.md)
reports.

Unlike
[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)'s
hash-based key, these are STATELESS: a key signs any number of messages,
with no index to track.

## References

National Institute of Standards and Technology (2024).
Module-Lattice-Based Digital Signature Standard. FIPS 204.
[doi:10.6028/NIST.FIPS.204](https://doi.org/10.6028/NIST.FIPS.204)

## See also

[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
for the dependency-free hash-based key,
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
which accepts either.

## Examples

``` r
# Only where the build found liboqs.
if ("ML-DSA-65" %in% pqc_backends()) {
  key <- oqs_keygen("ML-DSA-65")
  key$scheme

  sig <- capsule_sign("a manifest digest", key)
  capsule_verify("a manifest digest", sig, oqs_public_key(key))
  capsule_verify("an edited digest", sig, oqs_public_key(key))

  # Stateless: the same key signs again with no index to advance.
  sig2 <- capsule_sign("a second digest", key)
  capsule_verify("a second digest", sig2, oqs_public_key(key))
}
```
