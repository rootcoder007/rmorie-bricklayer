# Byte lengths of an HQC parameter set

Reports the sizes the HQC specification fixes, so a caller never has to
hard-code them.

## Usage

``` r
hqc_sizes(level, version = c("v5", "round4"))
```

## Arguments

- level:

  Security level: 1, 3 or 5 (or 128, 192, 256).

- version:

  `"v5"` (the default) or `"round4"`, as in
  [`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md).

## Value

A named integer vector: `encapsulation_key`, `decapsulation_key`,
`ciphertext`, `seed` (key generation), `message` and `salt`
(encapsulation randomness) and `shared_secret`, all in bytes.

## See also

[`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md),
[`kem_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_sizes.md)
for ML-KEM.

## Examples

``` r
hqc_sizes(1)
#> encapsulation_key decapsulation_key        ciphertext              seed 
#>              2241              2321              4433                32 
#>           message              salt     shared_secret 
#>                16                16                32 

# code-based keys and ciphertexts are larger than ML-KEM's at the same
# category; the shared secret is 32 bytes at every level (64 in round 4)
rbind(HQC = hqc_sizes(3)[c("encapsulation_key", "ciphertext")],
      ML_KEM = kem_sizes(768)[c("encapsulation_key", "ciphertext")])
#>        encapsulation_key ciphertext
#> HQC                 4514       8978
#> ML_KEM              1184       1088
rbind(v5 = hqc_sizes(1), round4 = hqc_sizes(1, "round4"))
#>        encapsulation_key decapsulation_key ciphertext seed message salt
#> v5                  2241              2321       4433   32      16   16
#> round4              2249              2305       4433   96      16   16
#>        shared_secret
#> v5                32
#> round4            64
```
