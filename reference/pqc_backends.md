# Available post-quantum signature schemes

Reports the signature schemes this package implements. The list is
fixed, not probed: all of them are implemented in the package's own C++
and none depends on a system library, so a scheme available on one
machine is available on every machine.

## Usage

``` r
pqc_backends()
```

## Value

A character vector of scheme names, `"xmss-sha256"` first.

## Details

`"xmss-sha256"` is the stateful hash-based scheme of
[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md).
The rest are the NIST standards, taken with
[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md):
ML-DSA (FIPS 204) at all three parameter sets, and SLH-DSA (FIPS 205) at
all twelve – six over SHAKE and six over SHA-2, which are different
schemes and not merely different code paths.

## See also

[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
for the standardised schemes,
[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
for the stateful one.

## Examples

``` r
pqc_backends()
#>  [1] "xmss-sha256"        "ML-DSA-44"          "ML-DSA-65"         
#>  [4] "ML-DSA-87"          "SLH-DSA-SHA2-128s"  "SLH-DSA-SHA2-128f" 
#>  [7] "SLH-DSA-SHA2-192s"  "SLH-DSA-SHA2-192f"  "SLH-DSA-SHA2-256s" 
#> [10] "SLH-DSA-SHA2-256f"  "SLH-DSA-SHAKE-128s" "SLH-DSA-SHAKE-128f"
#> [13] "SLH-DSA-SHAKE-192s" "SLH-DSA-SHAKE-192f" "SLH-DSA-SHAKE-256s"
#> [16] "SLH-DSA-SHAKE-256f"

# Every scheme is present in every build.
all(c("xmss-sha256", "ML-DSA-65", "SLH-DSA-SHAKE-128s") %in%
    pqc_backends())
#> [1] TRUE
```
