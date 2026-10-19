# Encapsulate a shared secret under an HQC key

The sender's half of an HQC key exchange. Given the recipient's public
key, it draws fresh randomness and produces a ciphertext together with
the shared secret that the ciphertext carries. The sender keeps the
shared secret (for example as the key of a symmetric cipher) and sends
the ciphertext; the recipient recovers the same secret with
[`hqcdecap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcdecap.md).
Only the public key is needed, and a full key from
[`hqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqckg.md)
is accepted too (its public half is used).

## Usage

``` r
hqcencap(key, m = NULL, salt = NULL)
```

## Arguments

- key:

  A key or public key from
  [`hqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqckg.md)
  /
  [`hqcpubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqckg.md).

- m, salt:

  Optional raw vectors of encapsulation randomness, default `NULL`
  (drawn fresh): `m` of
  [`hqcsz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcsz.md)`["message"]`
  bytes (16, 24 or 32) and `salt` of 16 bytes. Supplying them makes the
  operation reproducible, which is what the known-answer tests need.
  Reusing them for the same key repeats the shared secret, so supply
  them only deliberately.

## Value

A list of class `bricklayer_hqc_capsule` with `ciphertext` and `shared`
(character, lowercase hex; see
[`hqcsz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcsz.md)
for the byte lengths: the shared secret is 32 bytes, 64 for a round-4
key), `level` (integer) and `version` (character). The print method
withholds the shared secret.

## Details

The level and version are taken from the key. The randomness is a
message `m` and a 16-byte `salt`. The length of `m` in bytes is
`hqcsz(level)[["message"]]`. They are both drawn with
[`rndbytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rndbytes.md)
from the operating system's generator unless supplied. With the same
key, `m` and `salt`, the ciphertext and secret are the same; that is
what the known-answer tests need, and it is why fixed values must never
be used for real traffic.

Errors: `key` not from
[`hqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqckg.md)
or
[`hqcpubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqckg.md);
a public key of the wrong length for its level; `m` or `salt` of the
wrong type or length.

## See also

[`hqcdecap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcdecap.md),
[`hqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqckg.md).

## Examples

``` r
key <- hqckg(1)
a <- hqcencap(key)
nchar(a$ciphertext) / 2 == hqcsz(1)[["ciphertext"]]
#> [1] TRUE

# two encapsulations to one key give different secrets
b <- hqcencap(key)
identical(a$shared, b$shared)
#> [1] FALSE

# both decapsulate correctly
identical(hqcdecap(key, a$ciphertext), a$shared)
#> [1] TRUE
identical(hqcdecap(key, b$ciphertext), b$shared)
#> [1] TRUE

# fixed randomness repeats the result (for tests only)
r1 <- hqcencap(key, m = as.raw(1:16), salt = as.raw(1:16))
r2 <- hqcencap(key, m = as.raw(1:16), salt = as.raw(1:16))
identical(r1$ciphertext, r2$ciphertext)
#> [1] TRUE

# randomness of the wrong length is refused
try(hqcencap(key, m = as.raw(1:3)))
#> Error : `m` must be a raw vector of 16 bytes for HQC-1
```
