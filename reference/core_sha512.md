# SHA-512 hex digest (C backend)

Hashes character or raw input with the self-contained SHA-512 (FIPS
180-4) in the compiled core. Use it over
[`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md)
when a pin has to outlive the capsule by decades: the wider digest
leaves more margin, including against a quantum adversary, for whom
Grover's algorithm halves the effective preimage exponent.

## Usage

``` r
core_sha512(x)
```

## Arguments

- x:

  A character vector or a raw vector.

## Value

A character vector of 128-character lowercase hex digests (one per
element for character input; length-1 for raw input).

## See also

[`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md),
[`core_crc32()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_crc32.md),
[`sha512_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_file_digest.md)

## Examples

``` r
# FIPS 180-4 test vector for "abc".
core_sha512("abc")
#> [1] "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"

# Vectorised over character input.
core_sha512(c("abc", "def"))
#> [1] "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
#> [2] "40a855bf0a93c1019d75dd5b59cd8157608811dd75c5977e07f3bc4be0cad98b22dde4db9ddb429fc2ad3cf9ca379fedf6c1dc4d4bb8829f10c2f0ee04a66663"

# Raw input hashes the bytes directly, and agrees with the character
# form for the same bytes.
identical(core_sha512("abc"), core_sha512(charToRaw("abc")))
#> [1] TRUE

# Twice the digest width of SHA-256.
c(sha256 = nchar(core_sha256("abc")), sha512 = nchar(core_sha512("abc")))
#> sha256 sha512 
#>     64    128 
```
