# SHA-512 hex digest (C backend)

Hashes character or raw input with the self-contained SHA-512 (FIPS
180-4) in the compiled core and returns the digest as hex. A digest is a
fingerprint: any change to the input gives a different value, so it pins
a data file, a code string or a manifest. Use it over
[`csha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md)
when a pin has to outlive the capsule by decades: the wider digest
leaves more margin, including against a quantum adversary, for whom
Grover's algorithm halves the effective preimage exponent.

## Usage

``` r
csha512(x)
```

## Arguments

- x:

  A character vector (one digest per element) or a raw vector (one
  digest of all its bytes).

## Value

A character vector of 128-character lowercase hex digests: one per
element for character input (`NA` for `NA`), length 1 for raw input.

## Details

Character input is hashed element by element, each string as its bytes
(UTF-8 text gives the UTF-8 bytes; no newline is added). `NA` elements
give `NA`. Other atomic input (numbers, logicals) is first converted
with [`as.character()`](https://rdrr.io/r/base/character.html), so
`csha512(1)` is the digest of the text `"1"`. A raw vector is hashed as
one byte string. For files use
[`sha512file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/filedgst.md).
Pure computation; no side effects.

## See also

[`csha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md),
[`ccrc32()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ccrc32.md),
[`sha512file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/filedgst.md)

## Examples

``` r
# FIPS 180-4 test vector for "abc".
csha512("abc")
#> [1] "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"

# Vectorised over character input; NA stays NA.
csha512(c("abc", "def", NA))
#> [1] "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
#> [2] "40a855bf0a93c1019d75dd5b59cd8157608811dd75c5977e07f3bc4be0cad98b22dde4db9ddb429fc2ad3cf9ca379fedf6c1dc4d4bb8829f10c2f0ee04a66663"
#> [3] NA                                                                                                                                

# Raw input hashes the bytes directly, and agrees with the character
# form for the same bytes.
identical(csha512("abc"), csha512(charToRaw("abc")))
#> [1] TRUE

# Twice the digest width of SHA-256.
c(sha256 = nchar(csha256("abc")), sha512 = nchar(csha512("abc")))
#> sha256 sha512 
#>     64    128 

# numbers are hashed as their text
identical(csha512(1), csha512("1"))
#> [1] TRUE
```
