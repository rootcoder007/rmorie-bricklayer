# The compressed HQC decapsulation key

Shrinks an HQC key pair for storage by replacing its secret half with
the seed it was generated from (32 bytes for v5, instead of several
kilobytes). The full key is derived again from the seed whenever
[`hqcdecap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcdecap.md)
needs it, so a compressed key works everywhere a full one does in this
package.

## Usage

``` r
hqccmpkey(key)
```

## Arguments

- key:

  A key from
  [`hqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqckg.md).

## Value

The key (class `bricklayer_hqc_key`) with `secret` replaced by the hex
of its seed: 32 bytes for v5, 96, 104 or 112 for round 4. The other
elements are unchanged.

## Details

The HQC specification of 2025-08-22 allows the decapsulation key to be
stored as its 32-byte `seed_KEM` alone (the compressed format
`dk_KEM = (seed_KEM)`), from which the whole key pair is derived again.
`hqccmpkey()` keeps only that seed;
[`hqcdecap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcdecap.md)
takes such a key and expands it, and refuses one whose seed does not
derive the key's public half.

The round-4 revision (64-byte shared secret) defines no compressed
format, but its key pair is derived from the randomness its key
generation draws, `skseed || sigma || pk_seed` (96, 104 or 112 bytes:
the `seed` of
[`hqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqckg.md)
and
[`hqcsz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcsz.md)),
all of which its secret key `skseed || sigma || pk_seed || s` carries.
For a round-4 key the compressed form is that seed: this package's
convention, not a format of the submission, so software built on round 4
(liboqs, PQClean) expects the full secret key.

A key that is already compressed is returned unchanged. Errors: `key`
not from
[`hqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqckg.md);
a secret of neither the full nor the seed length. The public half is
kept, and anyone with the seed can rebuild the whole secret key, so the
compressed key must be protected exactly like the full one.

## References

Gaborit, P. et al. (2025). Hamming Quasi-Cyclic (HQC), specification of
2025-08-22, section 3 (HQC-KEM key pair formats). pqc-hqc.org

## See also

[`hqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqckg.md),
[`hqcdecap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcdecap.md)

## Examples

``` r
key <- hqckg(1)
small <- hqccmpkey(key)
nchar(small$secret) / 2
#> [1] 32
sent <- hqcencap(hqcpubkey(key))
identical(hqcdecap(small, sent$ciphertext), sent$shared)
#> [1] TRUE

# compressing twice changes nothing
identical(hqccmpkey(small), small)
#> [1] TRUE

# a seed paired with someone else's public key is refused on use
spliced <- small
spliced$public <- hqckg(1)$public
try(hqcdecap(spliced, sent$ciphertext))
#> Error : the compressed secret key does not derive this key's public key
```
