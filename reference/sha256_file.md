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
