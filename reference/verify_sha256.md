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
