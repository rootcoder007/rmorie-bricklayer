# Byte lengths of an HQC parameter set

Reports the byte lengths that the HQC specification fixes for a security
level: the encapsulation (public) key, the decapsulation (secret) key,
the ciphertext, the key-generation seed, the encapsulation randomness
and the shared secret. Use it to validate stored keys and ciphertexts,
or to size storage, without hard-coding numbers.

## Usage

``` r
hqc_sizes(level, version = c("v5", "round4"))
```

## Arguments

- level:

  Security level: 1, 3 or 5 (or 128, 192, 256 for the same three). There
  is no default.

- version:

  `"v5"` (the default) or `"round4"`, as in
  [`hqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_keygen.md).

## Value

A named integer vector: `encapsulation_key`, `decapsulation_key`,
`ciphertext`, `seed` (key generation), `message` and `salt`
(encapsulation randomness) and `shared_secret`, all in bytes.

## Details

The values come from the compiled implementation, so they are the sizes
it actually uses. For `version = "v5"` (specification of 2025-08-22):

|                   |       |       |       |
|-------------------|-------|-------|-------|
|                   | HQC-1 | HQC-3 | HQC-5 |
| encapsulation key | 2241  | 4514  | 7237  |
| decapsulation key | 2321  | 4602  | 7333  |
| ciphertext        | 4433  | 8978  | 14421 |
| seed              | 32    | 32    | 32    |
| message           | 16    | 24    | 32    |
| salt              | 16    | 16    | 16    |
| shared secret     | 32    | 32    | 32    |

For `version = "round4"` the codes are the same but the key encoding
differs: the seed is 96, 104 or 112 bytes and the shared secret 64
bytes. A level other than 1, 3, 5 (or 128, 192, 256) is an error.

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

# check a stored public key's length
key <- hqc_keygen(1)
nchar(key$public) / 2 == hqc_sizes(1)[["encapsulation_key"]]
#> [1] TRUE

# an unknown level is refused rather than mapped to a default
try(hqc_sizes(2))
#> Error : `level` must be one of 1, 3 or 5 (HQC-1, HQC-3, HQC-5)
```
