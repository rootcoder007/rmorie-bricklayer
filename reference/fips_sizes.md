# Byte lengths of a standardised signature scheme

Reports the sizes fixed by a FIPS 204 or FIPS 205 parameter set, so a
caller never has to hard-code them.

## Usage

``` r
fips_sizes(scheme)
```

## Arguments

- scheme:

  Scheme name, as in
  [`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md).

## Value

A named integer vector: `public_key`, `secret_key`, `signature`, `seed`
and `opt_rand`, all in bytes. `opt_rand` is the per-signature randomness
the scheme consumes.

## See also

[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md),
[`pqc_backends()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_backends.md).

## Examples

``` r
fips_sizes("ML-DSA-65")
#> public_key secret_key  signature       seed   opt_rand 
#>       1952       4032       3309         32         32 
fips_sizes("SLH-DSA-SHAKE-128s")
#> public_key secret_key  signature       seed   opt_rand 
#>         32         64       7856         48         16 

# An SLH-DSA signature is far larger than an ML-DSA one at the same
# security level, which is the price of dropping the lattice
# assumption.
fips_sizes("SLH-DSA-SHAKE-128s")[["signature"]] >
  fips_sizes("ML-DSA-44")[["signature"]]
#> [1] TRUE
```
