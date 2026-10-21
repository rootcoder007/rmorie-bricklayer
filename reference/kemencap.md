# Encapsulate a shared secret under an ML-KEM key

Produces a ciphertext and the 32-byte shared secret it carries. Only the
public key is needed, which is the point: the sender never holds
anything the recipient has to trust them with. The sender keeps the
shared secret (to derive an encryption key, for example) and sends the
ciphertext; the recipient gets the same secret back with
[`kemdecap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemdecap.md).

## Usage

``` r
kemencap(key, m = NULL)
```

## Arguments

- key:

  A key or public key from
  [`kemkg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemkg.md)
  /
  [`kempubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemkg.md).

- m:

  Optional raw vector of 32 bytes of encapsulation randomness. Supplying
  it makes the operation reproducible, which is what the standard's test
  vectors need; the default draws from the operating system's CSPRNG.
  Reusing it across encapsulations to the same key reuses the shared
  secret, so supply it only deliberately.

## Value

A list of class `bricklayer_kem_capsule` with `ciphertext` (character,
hex, of the length in bytes that
[`kemsz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemsz.md)`[["ciphertext"]]`
gives: send this), `shared` (character, 64 hex characters, the 32-byte
shared secret: keep this) and `level` (integer). Printing it never shows
the shared secret.

## Details

This is ML-KEM.Encaps of FIPS 203 (Algorithm 20) on the 32-byte message
`m`. Without `m`, fresh randomness is drawn with
[`rndbytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rndbytes.md),
so two encapsulations to one key give different ciphertexts and secrets.
A full key pair works as well as a public key; only its public half is
read.

Errors: `key` not from
[`kemkg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemkg.md)
or
[`kempubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemkg.md);
a key whose public half is not valid hex (“key has no usable public
key”); `m` that is not a raw vector of 32 bytes.

## See also

[`kemdecap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemdecap.md),
[`kemkg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemkg.md).

## Examples

``` r
key <- kemkg(512)
a <- kemencap(key)
nchar(a$ciphertext) / 2 == kemsz(512)[["ciphertext"]]
#> [1] TRUE

# two encapsulations to one key give different secrets
b <- kemencap(key)
identical(a$shared, b$shared)
#> [1] FALSE

# both decapsulate correctly
identical(kemdecap(key, a$ciphertext), a$shared)
#> [1] TRUE
identical(kemdecap(key, b$ciphertext), b$shared)
#> [1] TRUE

# fixed randomness makes the result reproducible (test vectors only)
m <- as.raw(1:32)
identical(kemencap(key, m = m)$shared, kemencap(key, m = m)$shared)
#> [1] TRUE

# the randomness must be exactly 32 bytes
try(kemencap(key, m = as.raw(1:8)))
#> Error : `m` must be a raw vector of 32 bytes
```
