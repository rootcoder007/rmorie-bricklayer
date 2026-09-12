# SHA-512 and CRC-32 of a file

Streams the file in blocks, so memory use does not grow with the file.
The SHA-256 counterpart is
[`sha256_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256_file.md).

## Usage

``` r
sha512_file(path, block_bytes = 1048576L)

crc32_file(path, block_bytes = 1048576L)
```

## Arguments

- path:

  Path to an existing file.

- block_bytes:

  Read size in bytes (default 1048576). Affects speed only, never the
  result.

## Value

A length-1 character vector ( `sha512_file()`) or numeric (
`crc32_file()`) .

## Examples

``` r
p <- tempfile()
writeLines("capsule payload", p)

sha512_file(p)
#> [1] "5d0664a30f586585aca8896c34269ca62f2eba708d5d7983a80925d50eaee5535116f104f245649f33054880810b4f88c542d70fd86ba95111f80342fa9bf9ba"
crc32_file(p)
#> [1] 2211766739

# The block size is a speed knob and cannot change the digest.
identical(sha512_file(p, 16), sha512_file(p, 1048576))
#> [1] TRUE

unlink(p)
```
