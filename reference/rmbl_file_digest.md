# SHA-512 and CRC-32 of a file

`sha512_file()` returns the SHA-512 digest of a file's bytes and
`crc32_file()` its CRC-32 checksum. Use the first to pin a data file for
the long term and the second as a fast check that a large file arrived
intact (it is the checksum zip archives record). The SHA-256 counterpart
is
[`sha256_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256_file.md).

## Usage

``` r
sha512_file(path, block_bytes = 1048576L)

crc32_file(path, block_bytes = 1048576L)
```

## Arguments

- path:

  Path to an existing file, a single string.

- block_bytes:

  Read size in bytes, a positive whole number (default 1048576). Affects
  speed only, never the result.

## Value

`sha512_file()`: a length-1 character vector, 128 lowercase hex
characters. `crc32_file()`: a length-1 numeric (double) checksum between
0 and `2^32 - 1`.

## Details

The file is read in blocks of `block_bytes` with
[`readBin()`](https://rdrr.io/r/base/readBin.html), the blocks are
joined into one raw vector, and the digest of that vector is computed
with
[`core_sha512()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha512.md)
or
[`core_crc32()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_crc32.md).
The whole file is therefore held in memory once: memory use grows with
the file size. `block_bytes` affects only the reading, never the result.
An empty file gives the digest of no bytes (`cf83e135...` for SHA-512, 0
for CRC-32).

Errors: `path` that does not name an existing file (or names a
directory); `block_bytes` that is not a positive whole number.

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

# the same as hashing the bytes directly
identical(sha512_file(p), core_sha512(readBin(p, "raw", file.size(p))))
#> [1] TRUE

# a missing file is an error
try(crc32_file(file.path(tempdir(), "no-such-file")))
#> Error : `path`: no such file: /tmp/Rtmp88UIXI/no-such-file
unlink(p)
```
