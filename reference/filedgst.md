# SHA-512 and CRC-32 of a file

`sha512file()` returns the SHA-512 digest of a file's bytes and
`crc32file()` its CRC-32 checksum. Use the first to pin a data file for
the long term and the second as a fast check that a large file arrived
intact (it is the checksum zip archives record). The SHA-256 counterpart
is
[`sha256file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256file.md).

## Usage

``` r
sha512file(path, blkbytes = 1048576L)

crc32file(path, blkbytes = 1048576L)
```

## Arguments

- path:

  Path to an existing file, a single string.

- blkbytes:

  Read size in bytes, a positive whole number (default 1048576). Affects
  speed only, never the result.

## Value

`sha512file()`: a length-1 character vector, 128 lowercase hex
characters. `crc32file()`: a length-1 numeric (double) checksum between
0 and `2^32 - 1`.

## Details

The file is read in blocks of `blkbytes` with
[`readBin()`](https://rdrr.io/r/base/readBin.html), the blocks are
joined into one raw vector, and the digest of that vector is computed
with
[`csha512()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha512.md)
or
[`ccrc32()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ccrc32.md).
The whole file is therefore held in memory once: memory use grows with
the file size. `blkbytes` affects only the reading, never the result. An
empty file gives the digest of no bytes (`cf83e135...` for SHA-512, 0
for CRC-32).

Errors: `path` that does not name an existing file (or names a
directory); `blkbytes` that is not a positive whole number.

## Examples

``` r
p <- tempfile()
writeLines("capsule payload", p)

sha512file(p)
#> [1] "5d0664a30f586585aca8896c34269ca62f2eba708d5d7983a80925d50eaee5535116f104f245649f33054880810b4f88c542d70fd86ba95111f80342fa9bf9ba"
crc32file(p)
#> [1] 2211766739

# The block size is a speed knob and cannot change the digest.
identical(sha512file(p, 16), sha512file(p, 1048576))
#> [1] TRUE

# the same as hashing the bytes directly
identical(sha512file(p), csha512(readBin(p, "raw", file.size(p))))
#> [1] TRUE

# a missing file is an error
try(crc32file(file.path(tempdir(), "no-such-file")))
#> Error : ccrc32: `path`: no such file: /tmp/Rtmp3o9fBQ/no-such-file
unlink(p)
```
