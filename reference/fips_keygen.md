# Generate a standardised post-quantum signing key

Generates a key for one of the NIST-standardised signature schemes:
ML-DSA (FIPS 204) or SLH-DSA (FIPS 205). Both are implemented in this
package, natively, with no system dependency;
[`pqc_backends()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_backends.md)
lists the parameter sets.

## Usage

``` r
fips_keygen(scheme = "ML-DSA-65", seed = NULL)

fips_public_key(key)
```

## Arguments

- scheme:

  Scheme name, one of
  [`pqc_backends()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_backends.md)
  other than `"xmss-sha256"`. The default `"ML-DSA-65"` is the FIPS 204
  middle security level.

- seed:

  Optional raw vector of key-generation seed bytes, of the length
  [`fips_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_sizes.md)
  reports for the scheme. Supplying it makes the key reproducible, which
  is what the standards' test vectors need; the default draws from the
  operating system's CSPRNG.

- key:

  A key from `fips_keygen()`.

## Value

A list of class `bricklayer_fips_key`: `public`, `secret` (both hex),
and `scheme`.

## Details

Unlike
[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
's hash-based key, these are STATELESS: one key signs any number of
messages, with no index to track and nothing to persist between
signatures.

Which to pick. ML-DSA is small and fast and rests on a lattice
assumption. SLH-DSA rests on nothing but the hash function, at the cost
of a signature one to two orders of magnitude larger; its `s` parameter
sets have small signatures and slow signing, its `f` sets the reverse,
and its SHAKE and SHA-2 families are equally strong: pick SHA-2 where a
validated SHA-2 implementation is what an auditor will ask about.
`"ML-DSA-65"` is the sensible default.

## References

National Institute of Standards and Technology (2024).
Module-Lattice-Based Digital Signature Standard. FIPS 204.
[doi:10.6028/NIST.FIPS.204](https://doi.org/10.6028/NIST.FIPS.204)

National Institute of Standards and Technology (2024). Stateless
Hash-Based Digital Signature Standard. FIPS 205.
[doi:10.6028/NIST.FIPS.205](https://doi.org/10.6028/NIST.FIPS.205)

## See also

[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
for the stateful hash-based key,
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
which accepts either,
[`fips_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_sizes.md)
for the byte lengths.

## Examples

``` r
key <- fips_keygen("ML-DSA-65")
key$scheme
#> [1] "ML-DSA-65"

sig <- capsule_sign("a manifest digest", key)
capsule_verify("a manifest digest", sig, fips_public_key(key))
#> [1] TRUE

# A context string binds the signature to its purpose: the same
# message signed for one context does not verify under another.
sig2 <- capsule_sign("a manifest digest", key, context = "release")
capsule_verify("a manifest digest", sig2, key, context = "release")
#> [1] TRUE
capsule_verify("a manifest digest", sig2, key, context = "staging")
#> [1] FALSE
```
