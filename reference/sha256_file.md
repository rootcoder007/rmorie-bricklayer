# Compute a File's SHA256 Digest

Returns the SHA256 digest of a file as a lowercase hex string, using the
digest package. Used to record and verify data provenance.

## Usage

``` r
sha256_file(path)
```

## Arguments

- path:

  Path to the file to hash.

## Value

The SHA256 digest as a character string.

## Examples

``` r
f <- tempfile()
writeLines("hello capsule", f)
sha256_file(f)
#> [1] "55d6110230c260319d580bb6274db530b7e751c4f687fc00d0736ec531260a02"
```
