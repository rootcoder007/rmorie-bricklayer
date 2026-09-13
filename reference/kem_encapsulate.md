# Encapsulate a shared secret under an ML-KEM key

Produces a ciphertext and the 32-byte shared secret it carries. Only the
public key is needed, which is the point: the sender never holds
anything the recipient has to trust them with.

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

A list of class `bricklayer_kem_capsule`: `ciphertext` and `shared`
(both hex), and `level`.

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
```
