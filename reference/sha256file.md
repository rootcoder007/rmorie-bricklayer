# Compute a File's SHA256 Digest

Returns the SHA-256 digest of a file as a lowercase hex string. A digest
is a 64-character fingerprint of the file's exact bytes: any change to
the file, even one byte, gives a different digest, so recording it when
data are downloaded and checking it later shows whether the file used in
an analysis is the one that was recorded. The package uses it to record
and verify data provenance in capsules and manifests.

## Usage

``` r
sha256file(path)
```

## Arguments

- path:

  A single string: the path of the file to hash (`~` is expanded as
  usual by R's file functions).

## Value

A single string of 64 lowercase hexadecimal characters, the SHA-256
digest of the file's bytes.

## Details

The digest is SHA-256 as specified in FIPS 180-4 (National Institute of
Standards and Technology, 2015), computed by the package's own compiled
core; it is identical to `digest::digest(file = path, algo = "sha256")`
and to the `sha256sum` command-line tool. The file is read in binary
mode, 8 MB at a time, so memory use stays at one chunk whatever the
file's size, and line endings or encodings are never altered. A file
larger than one chunk shows a byte-progress bar on stderr after 0.75 s
when a person is watching (an interactive session, or
`options(morie.progress = TRUE)`); `options(morie.quiet = TRUE)`
silences it. Hashing runs at roughly 100 MB a second or faster.

When this file is sourced on its own inside a capsule bundle (outside
the package), the same digest comes from base R's
[`tools::sha256sum()`](https://rdrr.io/r/tools/sha256sum.html) (R 4.5.0
and later) or else from the bundle's pure-R SHA-256 implementation,
which reads the file 1 MB at a time (slow on a large file, but in
constant memory).

Refusals: anything other than a single string naming an existing regular
file – a missing path, a directory, `NA`, a number or a vector of
several paths – stops with `"sha256file: <path> is not a file"`.

## References

National Institute of Standards and Technology (2015). Secure Hash
Standard (SHS). FIPS PUB 180-4.
[doi:10.6028/NIST.FIPS.180-4](https://doi.org/10.6028/NIST.FIPS.180-4)

## See also

[`csha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md)
for the digest of a string or raw vector held in memory.

## Examples

``` r
f <- tempfile()
writeLines("hello capsule", f)
sha256file(f)
#> [1] "55d6110230c260319d580bb6274db530b7e751c4f687fc00d0736ec531260a02"

# Deterministic: the same bytes always yield the same digest.
identical(sha256file(f), sha256file(f))
#> [1] TRUE

# Any change to the file changes the digest (tamper-evidence).
before <- sha256file(f)
writeLines("hello capsule (edited)", f)
after <- sha256file(f)
before == after      # FALSE
#> [1] FALSE

# Provenance pin: record a digest, verify it later.
pinned <- sha256file(f)
stopifnot(sha256file(f) == pinned)

# An empty file has the well-known empty-input digest.
e <- tempfile()
file.create(e)
#> [1] TRUE
sha256file(e)
#> [1] "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

# The file's bytes and the same bytes in memory hash alike.
identical(sha256file(f), csha256(readBin(f, "raw", file.size(f))))
#> [1] TRUE

# A directory or a missing file is refused.
try(sha256file(tempdir()))
#> Error : sha256file: /tmp/Rtmps0jgIx is not a file
```
