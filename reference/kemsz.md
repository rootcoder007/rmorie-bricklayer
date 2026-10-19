# Byte lengths of an ML-KEM parameter set

Reports the byte sizes that FIPS 203 fixes for one ML-KEM parameter set:
the public (encapsulation) key, the secret (decapsulation) key, the
ciphertext, the key-generation seed and the shared secret. Use it to
check a key or ciphertext before storing or sending it, or to size a
buffer or a database column, so a caller never has to hard-code the
numbers.

## Usage

``` r
kemsz(lvl)
```

## Arguments

- lvl:

  Security level, one whole number: 512, 768 or 1024. There is no
  default.

## Value

A named integer vector of five elements, all in bytes: `public` (the
encapsulation key), `secret` (the decapsulation key), `ciphertext`,
`seed` and `shared` (the shared secret), named as
[`kemkg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemkg.md)
and
[`kemencap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemencap.md)
name their results.

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
[`kemkg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemkg.md)
and
[`kemencap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemencap.md)
are twice these lengths in characters. Error: `lvl` other than one whole
number 512, 768 or 1024.

## See also

[`kemkg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemkg.md).

## Examples

``` r
kemsz(768)
#>     public     secret ciphertext       seed     shared 
#>       1184       2400       1088         64         32 

# the shared secret is 32 bytes at every level: the level buys
# security margin, not a longer secret
vapply(c(512, 768, 1024),
       function(l) kemsz(l)[["shared"]], integer(1))
#> [1] 32 32 32

# check a ciphertext's length before sending it
key <- kemkg(768)
ct <- kemencap(key)$ciphertext
nchar(ct) / 2 == kemsz(768)[["ciphertext"]]
#> [1] TRUE

# an unknown level is an error, not a default
try(kemsz(2048))
#> Error : `level` must be one of 512, 768 or 1024
```
