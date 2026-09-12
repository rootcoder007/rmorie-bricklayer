# Available post-quantum signature backends

Reports which signature backends this build of the package can use.
`"xmss-sha256"` is always present – it needs nothing but the bundled
SHA-256. `"liboqs"` appears only when the Open Quantum Safe library was
found at configure time, which additionally enables the standardised
lattice and hash-based schemes (ML-DSA / FIPS 204, SLH-DSA / FIPS 205)
through that library rather than through any hand-written implementation
here.

## Usage

``` r
pqc_backends()
```

## Value

A character vector of scheme names. `"xmss-sha256"` is always first; any
standardised schemes this build of liboqs enabled follow.

## See also

[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md),
which takes any of these as its `scheme`.

## Examples

``` r
pqc_backends()
#> [1] "xmss-sha256"

# The dependency-free backend is always available.
"xmss-sha256" %in% pqc_backends()
#> [1] TRUE

# Whether a lattice scheme is available depends on the build.
"ML-DSA-65" %in% pqc_backends()
#> [1] FALSE
```
