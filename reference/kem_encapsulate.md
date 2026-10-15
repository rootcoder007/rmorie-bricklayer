# Encapsulate a shared secret under an ML-KEM key

Produces a ciphertext and the 32-byte shared secret it carries. Only the
public key is needed, which is the point: the sender never holds
anything the recipient has to trust them with. The sender keeps the
shared secret (to derive an encryption key, for example) and sends the
ciphertext; the recipient gets the same secret back with
[`kem_decapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_decapsulate.md).

## Usage

``` r
kem_encapsulate(key, m = NULL)
```

## Arguments

- key:

  A key or public key from
  [`kem_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md)
  /
  [`kem_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md).

- m:

  Optional raw vector of 32 bytes of encapsulation randomness. Supplying
  it makes the operation reproducible, which is what the standard's test
  vectors need; the default draws from the operating system's CSPRNG.
  Reusing it across encapsulations to the same key reuses the shared
  secret, so supply it only deliberately.

## Value

A list of class `c("bricklayer_kem_capsule", "list")` with `ciphertext`
(character, hex,
[`kem_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_sizes.md)`[["ciphertext"]]`
bytes: send this), `shared` (character, 64 hex characters, the 32-byte
shared secret: keep this) and `level` (integer). Printing it never shows
the shared secret.

## Details

This is ML-KEM.Encaps of FIPS 203 (Algorithm 20) on the 32-byte message
`m`. Without `m`, fresh randomness is drawn with
[`random_bytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/random_bytes.md),
so two encapsulations to one key give different ciphertexts and secrets.
A full key pair works as well as a public key; only its public half is
read.

Errors: `key` not from
[`kem_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md)
or
[`kem_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md);
a key whose public half is not valid hex ("key has no usable public
key"); `m` that is not a raw vector of 32 bytes.

## See also

[`kem_decapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_decapsulate.md),
[`kem_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md).

## Examples

``` r
key <- kem_keygen(512)
a <- kem_encapsulate(key)
nchar(a$ciphertext) / 2 == kem_sizes(512)[["ciphertext"]]
#> [1] TRUE

# two encapsulations to one key give different secrets
b <- kem_encapsulate(key)
identical(a$shared, b$shared)
#> [1] FALSE

# both decapsulate correctly
identical(kem_decapsulate(key, a$ciphertext), a$shared)
#> [1] TRUE
identical(kem_decapsulate(key, b$ciphertext), b$shared)
#> [1] TRUE

# fixed randomness makes the result reproducible (test vectors only)
m <- as.raw(1:32)
identical(kem_encapsulate(key, m = m)$shared, kem_encapsulate(key, m = m)$shared)
#> [1] TRUE

# the randomness must be exactly 32 bytes
try(kem_encapsulate(key, m = as.raw(1:8)))
#> Error : `m` must be a raw vector of 32 bytes
```
