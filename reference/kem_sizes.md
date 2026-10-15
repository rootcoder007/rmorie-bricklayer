# Byte lengths of an ML-KEM parameter set

Reports the byte sizes that FIPS 203 fixes for one ML-KEM parameter set:
the public (encapsulation) key, the secret (decapsulation) key, the
ciphertext, the key-generation seed and the shared secret. Use it to
check a key or ciphertext before storing or sending it, or to size a
buffer or a database column, so a caller never has to hard-code the
numbers.

## Usage

``` r
kem_sizes(level)
```

## Arguments

- level:

  Security level, one whole number: 512, 768 or 1024. There is no
  default.

## Value

A named integer vector of five elements, all in bytes:
`encapsulation_key`, `decapsulation_key`, `ciphertext`, `seed` and
`shared_secret`.

## Details

The values come from the native core and are those of FIPS 203, Table 3:

|                   |      |      |      |
|-------------------|------|------|------|
|                   | 512  | 768  | 1024 |
| encapsulation key | 800  | 1184 | 1568 |
| decapsulation key | 1632 | 2400 | 3168 |
| ciphertext        | 768  | 1088 | 1568 |
| seed              | 64   | 64   | 64   |
| shared secret     | 32   | 32   | 32   |

Hex strings from
[`kem_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md)
and
[`kem_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_encapsulate.md)
are twice these lengths in characters. Error: `level` other than one
whole number 512, 768 or 1024.

## See also

[`kem_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md).

## Examples

``` r
kem_sizes(768)
#> encapsulation_key decapsulation_key        ciphertext              seed 
#>              1184              2400              1088                64 
#>     shared_secret 
#>                32 

# the shared secret is 32 bytes at every level: the level buys
# security margin, not a longer secret
vapply(c(512, 768, 1024),
       function(l) kem_sizes(l)[["shared_secret"]], integer(1))
#> [1] 32 32 32

# check a ciphertext's length before sending it
key <- kem_keygen(768)
ct <- kem_encapsulate(key)$ciphertext
nchar(ct) / 2 == kem_sizes(768)[["ciphertext"]]
#> [1] TRUE

# an unknown level is an error, not a default
try(kem_sizes(2048))
#> Error : `level` must be one of 512, 768 or 1024
```
