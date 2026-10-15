# Recover a shared secret from an HQC ciphertext

The recipient's half of an HQC key exchange. Given the key pair from
[`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md)
(with its secret half) and a ciphertext from
[`hqc_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_encapsulate.md),
it returns the shared secret the ciphertext carries, as hex (32 bytes;
64 for a round-4 key). The sender and recipient then hold the same
secret without it ever having been sent.

## Usage

``` r
hqc_decapsulate(key, ciphertext)
```

## Arguments

- key:

  A key from
  [`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md),
  with its secret half (full or compressed).

- ciphertext:

  Ciphertext from
  [`hqc_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_encapsulate.md),
  as a hex string or a raw vector.

## Value

The shared secret as a lowercase hex string: 64 characters (32 bytes),
or 128 for a round-4 key.

## Details

A ciphertext that was not produced by a correct encapsulation under this
key does not raise an error: it yields the key `J(H(ek) || sigma || c)`
(round 4: `K(sigma || u || v)`), derived from a value only the
decapsulation key holds (the Fujisaki-Okamoto transform's implicit
rejection), so whoever sent it learns nothing from the outcome. A
mismatch between the two sides' secrets is the signal that something was
wrong. A decapsulation key whose stored seeds no longer derive from each
other (corrupted or spliced; for round 4, whose public half is not the
one its secret seed makes) IS refused.

A compressed key from
[`hqc_compress_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_compress_key.md)
is accepted: the full key pair is derived again from the seed, and the
call errors if that does not give the key's own public half. The level
and version are taken from the key, so the ciphertext must come from a
key of the same level and version.

Errors: `key` not an HQC key; a public key (no secret half); a secret of
the wrong length; a ciphertext of the wrong length or not valid hex.

## See also

[`hqc_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_encapsulate.md),
[`hqc_compress_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_compress_key.md).

## Examples

``` r
key <- hqc_keygen(1)
sent <- hqc_encapsulate(hqc_public_key(key))
identical(hqc_decapsulate(key, sent$ciphertext), sent$shared)
#> [1] TRUE

# a tampered ciphertext returns a secret, and it is the wrong one
bad <- sent$ciphertext
substring(bad, 3L, 4L) <- if (substring(bad, 3L, 4L) == "ff") "fe" else "ff"
other <- hqc_decapsulate(key, bad)
nchar(other) == 64L
#> [1] TRUE
identical(other, sent$shared)
#> [1] FALSE

# the public key alone cannot decapsulate, and a truncated ciphertext
# is refused
try(hqc_decapsulate(hqc_public_key(key), sent$ciphertext))
#> Error : decapsulation needs a key with its secret half
try(hqc_decapsulate(key, substring(sent$ciphertext, 1L, 100L)))
#> Error : `ciphertext` must be 4433 bytes for HQC-1
```
