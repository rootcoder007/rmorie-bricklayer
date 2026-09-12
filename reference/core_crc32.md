# CRC-32 checksum (C backend)

The CRC-32 of ITU V.42 and zip (reflected polynomial `0xEDB88320`) .

## Usage

``` r
core_crc32(x)
```

## Arguments

- x:

  A character vector or a raw vector.

## Value

A numeric vector of unsigned 32-bit checksums (one per element for
character input; length-1 for raw input). Returned as `double` rather
than `integer` because values above `2^31 - 1` are not representable as
an R integer.

## Details

A CRC is NOT a cryptographic digest: it detects accidental corruption –
a truncated download, a flipped bit on disk – but anyone can construct a
different input with the same value, so it must never be used where
[`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md)
is meant. It is here because it is far cheaper than SHA-256 over
gigabyte-scale capsule members, which makes it the right first pass when
the question is only "did this file arrive intact".

## See also

[`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md)
for integrity against tampering rather than accident.

## Examples

``` r
# The standard check value: CRC-32("123456789") is 0xCBF43926.
core_crc32("123456789")
#> [1] 3421780262
core_crc32("123456789") == 0xCBF43926
#> [1] TRUE

# The empty input has checksum zero.
core_crc32("")
#> [1] 0

# Vectorised, and sensitive to a single changed byte.
core_crc32(c("brick", "brack"))
#> [1] 928041788 960731780

# Raw bytes work the same way.
core_crc32(charToRaw("123456789"))
#> [1] 3421780262
```
