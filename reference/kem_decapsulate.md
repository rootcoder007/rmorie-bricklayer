# Recover a shared secret from an ML-KEM ciphertext

Returns the 32-byte shared secret the ciphertext carries, as hex.

## Usage

``` r
kem_decapsulate(key, ciphertext)
```

## Arguments

- key:

  A key from
  [`kem_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md),
  with its secret half.

- ciphertext:

  Ciphertext from
  [`kem_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_encapsulate.md),
  hex or raw.

## Value

64 hex characters: the 32-byte shared secret.

## Details

There is no failure path, and that is deliberate. A ciphertext that was
not produced by a correct encapsulation under this key yields a shared
secret derived from a value held only inside the decapsulation key – so
it is a real secret, just not the sender's. Whoever sent it learns
nothing about whether it was accepted, which is what closes off a
chosen-ciphertext attack. The consequence for a caller: a mismatch
between the two sides' secrets is the signal that something was wrong,
not an error from this function.

## See also

[`kem_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_encapsulate.md).

## Examples

``` r
key <- kem_keygen(512)
sent <- kem_encapsulate(kem_public_key(key))
identical(kem_decapsulate(key, sent$ciphertext), sent$shared)
#> [1] TRUE

# a tampered ciphertext returns a secret, and it is the wrong one
bad <- sent$ciphertext
substring(bad, 3L, 4L) <- "ff"
other <- kem_decapsulate(key, bad)
nchar(other) == 64L
#> [1] TRUE
identical(other, sent$shared)
#> [1] FALSE
```
