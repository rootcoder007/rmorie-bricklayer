# Recover a shared secret from an HQC ciphertext

Returns the shared secret the ciphertext carries, as hex (32 bytes; 64
for a round-4 key).

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

The shared secret as hex: 64 characters (32 bytes), or 128 for a round-4
key.

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
