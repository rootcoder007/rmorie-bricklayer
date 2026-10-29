# Digest an arbitrary R object

Fingerprints any R object by hashing its serialization, so a list, a
data frame, a function or a fitted model all get a stable digest. The
counterpart of
[`digest::digest()`](https://eddelbuettel.github.io/digest/man/digest.html),
computed with this package's own hashes.

Serialization is pinned to version 2 with XDR byte order, so the digest
is the same on a big-endian machine as on a little-endian one. Two
objects that are [`identical()`](https://rdrr.io/r/base/identical.html)
produce the same digest; two that merely print the same need not,
because attributes are part of the serialization.

## Usage

``` r
dgstobj(x, algo = c("sha256", "sha512", "blake2b", "crc32"), key = NULL)
```

## Arguments

- x:

  Any R object.

- algo:

  `"sha256"` (default), `"sha512"`, `"blake2b"` or `"crc32"`.

- key:

  Optional key (a single string or raw vector), default `NULL`. Only for
  `"sha256"` (HMAC-SHA-256) and `"blake2b"` (keyed BLAKE2b): gives a
  keyed fingerprint that only a key holder can reproduce.

## Value

A length-1 character vector of lowercase hex (64 characters for
`"sha256"` and `"blake2b"`, 128 for `"sha512"`), or a length-1 numeric
for `"crc32"`.

## Details

The object is serialized with
`serialize(x, NULL, version = 2, xdr = TRUE)` and the bytes are hashed
with
[`csha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md),
[`csha512()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha512.md),
[`cblake2b()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cblake2b.md)
(32 bytes) or
[`ccrc32()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ccrc32.md).
CRC-32 is a checksum for accidental corruption, not a cryptographic
hash. With a `key` the digest is HMAC-SHA-256 for `"sha256"` and keyed
BLAKE2b for `"blake2b"`; a key with `"sha512"` or `"crc32"` is an error
rather than a silently unkeyed digest. Objects that contain environments
(functions, many fitted models) serialize their enclosing environments
too, so their digest can change between sessions even when the code does
not.

## See also

[`csha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md)
for hashing text or bytes directly,
[`jsser()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/jsserdoc.md)
for a readable form that keeps types and attributes.

## Examples

``` r
dgstobj(list(a = 1L, b = "x"))
#> [1] "4cc01b9a681cfbfedd5161e7a04da73553abe74690551e27f97f2f1541870039"

# Stable across calls, and sensitive to any change.
identical(dgstobj(1:10), dgstobj(1:10))
#> [1] TRUE
dgstobj(1:10) == dgstobj(1:11)
#> [1] FALSE

# Attributes are part of the object, so they are part of the digest.
dgstobj(matrix(1:6, nrow = 2)) == dgstobj(1:6)
#> [1] FALSE

# Any of the hashes, and a keyed fingerprint.
dgstobj(mtcars, algo = "sha512")
#> [1] "d3c1f66ebbfc07c75c80c61eb312c7e1f5eb4a437d6d903c2bd3ac625d0259779ca4ad3aebeaa1f5b832062a839e52c868b1052f7bf934b0e3ef28cd8eae8b68"
dgstobj(mtcars, algo = "crc32")
#> [1] 561500927
dgstobj(mtcars, algo = "blake2b", key = "secret")
#> [1] "c442d9eaf9d8a809894558bb3858b0ddba93ae18236d881d6c26a07202663a8b"

# A data frame's digest pins the data, so it can go in a manifest.
dgstobj(data.frame(x = 1:3))
#> [1] "dd08e77a78d0f614de146150484e2d8596312ef5aec96cb91199859beb9f899b"

# a key with an algorithm that has no keyed form is refused
try(dgstobj(1:3, algo = "crc32", key = "secret"))
#> Error : `key` is not supported for algo = "crc32"; keyed digests are available for "sha256" (HMAC-SHA-256) and "blake2b"
```
