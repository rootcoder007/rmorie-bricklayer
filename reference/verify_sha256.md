# Verify a File's SHA256 Against an Expected Digest

Computes the SHA256 digest of a file (via the digest package) and
compares it to the expected value pinned in provenance.

## Usage

``` r
verify_sha256(path, expected_sha)
```

## Arguments

- path:

  Path to the file to hash.

- expected_sha:

  The expected SHA256 digest, as a lowercase hex string.

## Value

A list with `actual` (computed digest), `expected` (the value passed
in), and `match` (logical; `TRUE` if they are identical).

## Examples

``` r
f <- tempfile()
writeLines("hello capsule", f)

# Matching digest -> match TRUE.
chk <- verify_sha256(f, sha256_file(f))
chk$match          # TRUE
#> [1] TRUE

# A wrong expected digest -> match FALSE, with both values reported.
bad <- verify_sha256(f, "0000000000000000000000000000000000000000000000000000000000000000")
bad$match          # FALSE
#> [1] FALSE
bad$actual         # the real digest
#> [1] "55d6110230c260319d580bb6274db530b7e751c4f687fc00d0736ec531260a02"
```
