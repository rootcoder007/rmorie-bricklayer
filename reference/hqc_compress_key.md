# The compressed HQC decapsulation key

The HQC specification of 2025-08-22 allows the decapsulation key to be
stored as its 32-byte `seed_KEM` alone (the compressed format
`dk_KEM = (seed_KEM)`), from which the whole key pair is derived again.
`hqc_compress_key()` keeps only that seed;
[`hqc_decapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_decapsulate.md)
takes such a key and expands it, and refuses one whose seed does not
derive the key's public half.

## Usage

``` r
hqc_compress_key(key)
```

## Arguments

- key:

  A key from
  [`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md).

## Value

The key with `secret` replaced by the hex of its seed: 32 bytes for v5,
96, 104 or 112 for round 4.

## Details

The round-4 revision (64-byte shared secret) defines no compressed
format, but its key pair is derived from the randomness its key
generation draws, `sk_seed || sigma || pk_seed` (96, 104 or 112 bytes:
the `seed` of
[`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md)
and
[`hqc_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_sizes.md)),
all of which its secret key `sk_seed || sigma || pk_seed || s` carries.
For a round-4 key the compressed form is that seed: this package's
convention, not a format of the submission, so software built on round 4
(liboqs, PQClean) expects the full secret key.

## References

Gaborit, P. et al. (2025). Hamming Quasi-Cyclic (HQC), specification of
2025-08-22, section 3 (HQC-KEM key pair formats). <https://pqc-hqc.org/>

## See also

[`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md),
[`hqc_decapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_decapsulate.md)

## Examples

``` r
key <- hqc_keygen(1)
small <- hqc_compress_key(key)
nchar(small$secret) / 2
#> [1] 32
sent <- hqc_encapsulate(hqc_public_key(key))
identical(hqc_decapsulate(small, sent$ciphertext), sent$shared)
#> [1] TRUE
```
