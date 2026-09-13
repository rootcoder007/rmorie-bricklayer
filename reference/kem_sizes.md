# Byte lengths of an ML-KEM parameter set

Reports the sizes FIPS 203 fixes, so a caller never has to hard-code
them.

## Usage

``` r
kem_sizes(level)
```

## Arguments

- level:

  Security level: 512, 768 or 1024.

## Value

A named integer vector: `encapsulation_key`, `decapsulation_key`,
`ciphertext`, `seed` and `shared_secret`, all in bytes.

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
```
