# Encapsulate a shared secret under an HQC key

The sender's half of an HQC key exchange. Given the recipient's public
key, it draws fresh randomness and produces a ciphertext together with
the shared secret that the ciphertext carries. The sender keeps the
shared secret (for example as the key of a symmetric cipher) and sends
the ciphertext; the recipient recovers the same secret with
[`hqc_decapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_decapsulate.md).
Only the public key is needed, and a full key from
[`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md)
is accepted too (its public half is used).

## Usage

``` r
hqc_encapsulate(key, m = NULL, salt = NULL)
```

## Arguments

- key:

  A key or public key from
  [`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md)
  /
  [`hqc_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md).

- m, salt:

  Optional raw vectors of encapsulation randomness, default `NULL`
  (drawn fresh): `m` of
  [`hqc_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_sizes.md)`["message"]`
  bytes (16, 24 or 32) and `salt` of 16 bytes. Supplying them makes the
  operation reproducible, which is what the known-answer tests need.
  Reusing them for the same key repeats the shared secret, so supply
  them only deliberately.

## Value

A list of class `bricklayer_hqc_capsule` with `ciphertext` and `shared`
(character, lowercase hex; see
[`hqc_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_sizes.md)
for the byte lengths: the shared secret is 32 bytes, 64 for a round-4
key), `level` (integer) and `version` (character). The print method
withholds the shared secret.

## Details

The level and version are taken from the key. The randomness is a
message `m` of `hqc_sizes(level)[["message"]]` bytes and a 16-byte
`salt`, both drawn with
[`random_bytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/random_bytes.md)
from the operating system's generator unless supplied. With the same
key, `m` and `salt`, the ciphertext and secret are the same; that is
what the known-answer tests need, and it is why fixed values must never
be used for real traffic.

Errors: `key` not from
[`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md)
or
[`hqc_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md);
a public key of the wrong length for its level; `m` or `salt` of the
wrong type or length.

## See also

[`hqc_decapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_decapsulate.md),
[`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md).

## Examples

``` r
key <- hqc_keygen(1)
a <- hqc_encapsulate(key)
nchar(a$ciphertext) / 2 == hqc_sizes(1)[["ciphertext"]]
#> [1] TRUE

# two encapsulations to one key give different secrets
b <- hqc_encapsulate(key)
identical(a$shared, b$shared)
#> [1] FALSE

# both decapsulate correctly
identical(hqc_decapsulate(key, a$ciphertext), a$shared)
#> [1] TRUE
identical(hqc_decapsulate(key, b$ciphertext), b$shared)
#> [1] TRUE

# fixed randomness repeats the result (for tests only)
r1 <- hqc_encapsulate(key, m = as.raw(1:16), salt = as.raw(1:16))
r2 <- hqc_encapsulate(key, m = as.raw(1:16), salt = as.raw(1:16))
identical(r1$ciphertext, r2$ciphertext)
#> [1] TRUE

# randomness of the wrong length is refused
try(hqc_encapsulate(key, m = as.raw(1:3)))
#> Error : `m` must be a raw vector of 16 bytes for HQC-1
```
