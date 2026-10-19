# Available post-quantum signature schemes

Reports the signature schemes this package implements. The list is
fixed, not probed: all of them are implemented in the package's own C++
and none depends on a system library, so a scheme available on one
machine is available on every machine.

## Usage

``` r
pqcbknd()
```

## Value

A character vector of 16 scheme names: `"xmss-sha256"` first, then the
three ML-DSA sets, the six SLH-DSA SHA-2 sets and the six SLH-DSA SHAKE
sets.

## Details

`"xmss-sha256"` is the stateful hash-based scheme of
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md).
The rest are the NIST standards, taken with
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md):
ML-DSA (FIPS 204) at all three parameter sets, and SLH-DSA (FIPS 205) at
all twelve – six over SHAKE and six over SHA-2, which are different
schemes and not merely different code paths. Use it to see which names
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md),
[`fipssz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipssz.md)
and
[`fipskey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskey.md)
accept, or to choose a parameter set.

The names follow the standards: `"ML-DSA-44"`, `"ML-DSA-65"` and
`"ML-DSA-87"` (NIST security categories 2, 3 and 5), then
`"SLH-DSA-SHA2-"` and `"SLH-DSA-SHAKE-"` followed by `128`, `192` or
`256` (the security level in bits) and `s` (small signatures, slow
signing) or `f` (fast signing, larger signatures). The function takes no
arguments, has no side effects and returns the same 16 names in the same
order on every platform.

## See also

[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
for the standardised schemes,
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md)
for the stateful one.

## Examples

``` r
pqcbknd()
#>  [1] "xmss-sha256"        "ML-DSA-44"          "ML-DSA-65"         
#>  [4] "ML-DSA-87"          "SLH-DSA-SHA2-128s"  "SLH-DSA-SHA2-128f" 
#>  [7] "SLH-DSA-SHA2-192s"  "SLH-DSA-SHA2-192f"  "SLH-DSA-SHA2-256s" 
#> [10] "SLH-DSA-SHA2-256f"  "SLH-DSA-SHAKE-128s" "SLH-DSA-SHAKE-128f"
#> [13] "SLH-DSA-SHAKE-192s" "SLH-DSA-SHAKE-192f" "SLH-DSA-SHAKE-256s"
#> [16] "SLH-DSA-SHAKE-256f"

# Every scheme is present in every build.
all(c("xmss-sha256", "ML-DSA-65", "SLH-DSA-SHAKE-128s") %in%
    pqcbknd())
#> [1] TRUE

# The SLH-DSA sets with fast signing, and their signature sizes in bytes.
fast <- grep("^SLH-DSA-.*f$", pqcbknd(), value = TRUE)
vapply(fast, function(s) fipssz(s)[["signature"]], integer(1))
#>  SLH-DSA-SHA2-128f  SLH-DSA-SHA2-192f  SLH-DSA-SHA2-256f SLH-DSA-SHAKE-128f 
#>              17088              35664              49856              17088 
#> SLH-DSA-SHAKE-192f SLH-DSA-SHAKE-256f 
#>              35664              49856 
```
