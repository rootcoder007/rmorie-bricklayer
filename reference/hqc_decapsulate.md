# Recover a shared secret from an HQC ciphertext

Returns the 32-byte shared secret the ciphertext carries, as hex.

## Usage

``` r
hqc_decapsulate(key, ciphertext)
```

## Arguments

- key:

  A key from
  [`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md),
  with its secret half.

- ciphertext:

  Ciphertext from
  [`hqc_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_encapsulate.md),
  hex or raw.

## Value

64 hex characters: the 32-byte shared secret.

## Details

A ciphertext that was not produced by a correct encapsulation under this
key does not raise an error: it yields the key `J(H(ek) || sigma || c)`,
derived from a value only the decapsulation key holds (the
Fujisaki-Okamoto transform's implicit rejection), so whoever sent it
learns nothing from the outcome. A mismatch between the two sides'
secrets is the signal that something was wrong. A decapsulation key
whose stored seeds no longer derive from each other (corrupted or
spliced) IS refused.

## See also

[`hqc_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_encapsulate.md).

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
```
