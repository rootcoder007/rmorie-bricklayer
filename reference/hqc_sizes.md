# Byte lengths of an HQC parameter set

Reports the sizes the HQC specification fixes, so a caller never has to
hard-code them.

## Usage

``` r
hqc_sizes(level)
```

## Arguments

- level:

  Security level: 1, 3 or 5 (or 128, 192, 256).

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
# category; the shared secret is 32 bytes at every level
rbind(HQC = hqc_sizes(3)[c("encapsulation_key", "ciphertext")],
      ML_KEM = kem_sizes(768)[c("encapsulation_key", "ciphertext")])
#>        encapsulation_key ciphertext
#> HQC                 4514       8978
#> ML_KEM              1184       1088
```
