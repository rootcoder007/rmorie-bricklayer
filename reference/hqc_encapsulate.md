# Encapsulate a shared secret under an HQC key

Produces a ciphertext and the 32-byte shared secret it carries. Only the
public key is needed.

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

  Optional raw vectors of encapsulation randomness: `m` of
  [`hqc_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_sizes.md)`["message"]`
  bytes (16, 24 or 32) and `salt` of 16 bytes. Supplying them makes the
  operation reproducible, which is what the known-answer tests need; the
  default draws both from the operating system's CSPRNG. Reusing them
  for the same key repeats the shared secret, so supply them only
  deliberately.

## Value

A list of class `bricklayer_hqc_capsule`: `ciphertext` and `shared`
(both hex), and `level`.

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
```
