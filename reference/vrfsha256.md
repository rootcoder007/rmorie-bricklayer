# Verify a File's SHA256 Against an Expected Digest

Computes the SHA-256 digest of a file and compares it with the digest
pinned in a provenance record, so a pipeline can tell whether the file
it downloaded is byte for byte the one the analysis was run on. A
changed file (a silent re-release, a truncated download, an edited copy)
gives a different digest.

## Usage

``` r
vrfsha256(path, expsha)
```

## Arguments

- path:

  Path to the file to hash, a single string.

- expsha:

  The expected SHA-256 digest: a hex string (64 characters, any case),
  or a length-1 list holding one, as read from provenance JSON.

## Value

A list of three elements: `actual` (character, the computed digest, 64
lower-case hex characters), `expected` (character, the normalised
expected value) and `match` (logical, `TRUE` when they are identical).

## Details

The digest is computed by
[`sha256file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256file.md),
the package's own compiled SHA-256 core (FIPS 180-4), reading the file
in chunks. The expected value is normalised before the comparison: a
length-1 list (as
[`loadprov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loadprov.md)
returns a pinned digest) is unlisted, surrounding spaces are trimmed and
letters are lower-cased, so an upper-case digest copied from a web page
still matches. The function reports and does not stop on a mismatch; the
caller decides.

Errors: `path` that does not name a readable file; `expsha` that is not
exactly one non-NA value.

## Examples

``` r
f <- tempfile()
writeLines("hello capsule", f)

# Matching digest -> match TRUE.
chk <- vrfsha256(f, sha256file(f))
chk$match # TRUE
#> [1] TRUE

# A wrong expected digest -> match FALSE, with both values reported.
bad <- vrfsha256(f, strrep("0", 64L))
bad$match # FALSE
#> [1] FALSE
bad$actual # the real digest
#> [1] "55d6110230c260319d580bb6274db530b7e751c4f687fc00d0736ec531260a02"

# case and a list wrapper (as from provenance JSON) do not matter
vrfsha256(f, list(toupper(sha256file(f))))$match
#> [1] TRUE

# a missing file, or more than one expected digest, is an error
try(vrfsha256(file.path(tempdir(), "missing.csv"), strrep("0", 64L)))
#> Error : sha256file: /tmp/RtmpeCv5Ei/missing.csv is not a file
try(vrfsha256(f, c("a", "b")))
#> Error : `expsha` must be a single SHA-256 hex string
```
