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
digest_object(x, algo = c("sha256", "sha512", "blake2b", "crc32"), key = NULL)
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
[`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md),
[`core_sha512()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha512.md),
[`core_blake2b()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_blake2b.md)
(32 bytes) or
[`core_crc32()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_crc32.md).
CRC-32 is a checksum for accidental corruption, not a cryptographic
hash. With a `key` the digest is HMAC-SHA-256 for `"sha256"` and keyed
BLAKE2b for `"blake2b"`; a key with `"sha512"` or `"crc32"` is an error
rather than a silently unkeyed digest. Objects that contain environments
(functions, many fitted models) serialize their enclosing environments
too, so their digest can change between sessions even when the code does
not.

## See also

[`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md)
for hashing text or bytes directly,
[`bricklayer_json_serialize()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_serialize.md)
for a readable form that keeps types and attributes.

## Examples

``` r
digest_object(list(a = 1L, b = "x"))
#> [1] "bf5d21a8b26f6cec8503a46f69e854bf98fea03b62dfaf90cb780feac7165b27"

# Stable across calls, and sensitive to any change.
identical(digest_object(1:10), digest_object(1:10))
#> [1] TRUE
digest_object(1:10) == digest_object(1:11)
#> [1] FALSE

# Attributes are part of the object, so they are part of the digest.
digest_object(matrix(1:6, nrow = 2)) == digest_object(1:6)
#> [1] FALSE

# Any of the hashes, and a keyed fingerprint.
digest_object(mtcars, algo = "sha512")
#> [1] "c53613500c91362b1d1ff5b142277240a9f80aa35ad4e6e8f1642c8c1023d79d2e249b54ffe9c6f1a176fb337eca8cd57c7e057d473f0f3137e319c890477655"
digest_object(mtcars, algo = "crc32")
#> [1] 358362979
digest_object(mtcars, algo = "blake2b", key = "secret")
#> [1] "fa9c0c955ca0d50abcb2bc2a984cbd143035beeaf7366c689755873d8aa84d8d"

# A data frame's digest pins the data, so it can go in a manifest.
digest_object(data.frame(x = 1:3))
#> [1] "24b0995a368ea8d1178b7f6e44c6d8956db4aadfc91d3e6f6911868b38c06d21"

# a key with an algorithm that has no keyed form is refused
try(digest_object(1:3, algo = "crc32", key = "secret"))
#> Error : `key` is not supported for algo = "crc32"; keyed digests are available for "sha256" (HMAC-SHA-256) and "blake2b"
```
