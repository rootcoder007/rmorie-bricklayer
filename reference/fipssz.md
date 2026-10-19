# Byte lengths of a standardised signature scheme

Reports the sizes fixed by a FIPS 204 or FIPS 205 parameter set, so a
caller never has to hard-code them. Use it to check key material before
[`fipskey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskey.md),
to size storage for signatures, or to compare parameter sets: an SLH-DSA
signature is 7,856 to 49,856 bytes where an ML-DSA one is 2,420 to
4,627.

## Usage

``` r
fipssz(scheme)
```

## Arguments

- scheme:

  Scheme name, as in
  [`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md).

## Value

A named integer vector of five byte counts: `public_key`, `secret_key`,
`signature`, `seed` and `rnd` (the per-signature randomness the scheme
consumes).

## Details

The sizes are the standards' tables (FIPS 204 Table 2, FIPS 205 Table 2)
as the compiled code uses them. `seed` is the key-generation input of
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md);
`rnd` is the per-signature randomness (32 bytes for ML-DSA's `rnd`,
\\n\\ bytes for SLH-DSA's `opt_rand`), which the deterministic variants
replace with a fixed value. XMSS is not covered: its sizes follow from
the tree height of
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md).
An unknown scheme, or anything but one string, is refused.

## See also

[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md),
[`pqcbknd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqcbknd.md).

## Examples

``` r
fipssz("ML-DSA-65")
#> public_key secret_key  signature       seed        rnd 
#>       1952       4032       3309         32         32 
fipssz("SLH-DSA-SHAKE-128s")
#> public_key secret_key  signature       seed        rnd 
#>         32         64       7856         48         16 

# An SLH-DSA signature is far larger than an ML-DSA one at the same
# security level, which is the price of dropping the lattice
# assumption.
fipssz("SLH-DSA-SHAKE-128s")[["signature"]] >
  fipssz("ML-DSA-44")[["signature"]]
#> [1] TRUE

# Every standardised set at once.
sapply(setdiff(pqcbknd(), "xmss-sha256"), fipssz)["signature", ]
#>          ML-DSA-44          ML-DSA-65          ML-DSA-87  SLH-DSA-SHA2-128s 
#>               2420               3309               4627               7856 
#>  SLH-DSA-SHA2-128f  SLH-DSA-SHA2-192s  SLH-DSA-SHA2-192f  SLH-DSA-SHA2-256s 
#>              17088              16224              35664              29792 
#>  SLH-DSA-SHA2-256f SLH-DSA-SHAKE-128s SLH-DSA-SHAKE-128f SLH-DSA-SHAKE-192s 
#>              49856               7856              17088              16224 
#> SLH-DSA-SHAKE-192f SLH-DSA-SHAKE-256s SLH-DSA-SHAKE-256f 
#>              35664              29792              49856 

# XMSS has no fixed sizes here.
try(fipssz("xmss-sha256"))
#> Error : unknown scheme 'xmss-sha256'. The standardised schemes are: ML-DSA-44, ML-DSA-65, ML-DSA-87, SLH-DSA-SHA2-128s, SLH-DSA-SHA2-128f, SLH-DSA-SHA2-192s, SLH-DSA-SHA2-192f, SLH-DSA-SHA2-256s, SLH-DSA-SHA2-256f, SLH-DSA-SHAKE-128s, SLH-DSA-SHAKE-128f, SLH-DSA-SHAKE-192s, SLH-DSA-SHAKE-192f, SLH-DSA-SHAKE-256s, SLH-DSA-SHAKE-256f. For the stateful hash-based scheme use pqckg().
```
