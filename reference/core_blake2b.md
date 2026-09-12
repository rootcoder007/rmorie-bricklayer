# BLAKE2b digest, optionally keyed

BLAKE2b (RFC 7693): a modern cryptographic hash, faster than SHA-256 in
software, that takes a key natively and produces any digest length from
1 to 64 bytes.

## Usage

``` r
core_blake2b(x, key = NULL, length = 32L)
```

## Arguments

- x:

  A character vector or a raw vector.

- key:

  Optional key, at most 64 bytes. `NULL` (default) gives the plain
  digest.

- length:

  Digest length in bytes, 1 to 64 (default 32, matching SHA-256's
  width).

## Value

A character vector of lowercase hex digests – one per element for
character input, length-1 for raw input.

## Details

The native key is the interesting part. A keyed BLAKE2b IS a message
authentication code, with no HMAC wrapper and so no doubled hashing –
`core_blake2b(msg, key = k)` does the job of
[`core_hmac_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_keyed_digest.md)
at lower cost. Use SHA-256 or HMAC where interoperability with other
tools matters; use this where it does not and speed does.

## References

Saarinen MJ, Aumasson JP (2015). The BLAKE2 Cryptographic Hash and
Message Authentication Code (MAC). RFC 7693.
[doi:10.17487/RFC7693](https://doi.org/10.17487/RFC7693)

## See also

[`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md),
[`core_sha512()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha512.md),
[`core_hmac_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_keyed_digest.md)

## Examples

``` r
# The RFC 7693 test vector for BLAKE2b-512 of "abc".
core_blake2b("abc", length = 64)
#> [1] "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923"

# 32 bytes by default, the same width as SHA-256.
core_blake2b("abc")
#> [1] "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319"
nchar(core_blake2b("abc"))
#> [1] 64

# Any digest length, which SHA-2 cannot do.
core_blake2b("abc", length = 8)
#> [1] "d8bb14d833d59559"

# Keyed, so it authenticates without an HMAC construction.
core_blake2b("manifest", key = "secret")
#> [1] "0fa448067a359db7f409a8de6a616a39d51393c32532bce014075308cbb1f222"
core_blake2b("manifest", key = "secret") ==
  core_blake2b("manifest", key = "other")
#> [1] FALSE

# Vectorised, and raw input hashes the same bytes.
core_blake2b(c("a", "b"))
#> [1] "8928aae63c84d87ea098564d1e03ad813f107add474e56aedd286349c0c03ea4"
#> [2] "6e5c1f45cbaf19f94230ba3501c378a5335af71a331b5b5aed62792332288dc3"
identical(core_blake2b("abc"), core_blake2b(charToRaw("abc")))
#> [1] TRUE
```
