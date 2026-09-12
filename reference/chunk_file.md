# Split a file into fixed-size chunks

Reads `path` as bytes and returns them as chunk strings suitable for
[`merkle_root()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md)
and friends. The default 1 MiB chunk is a compromise: smaller chunks
localise a change more precisely but make the tree and its proofs
larger.

## Usage

``` r
chunk_file(path, chunk_bytes = 1048576L)
```

## Arguments

- path:

  Path to an existing file.

- chunk_bytes:

  Chunk size in bytes (default 1048576, i.e. 1 MiB).

## Value

A character vector of chunks, in file order. A zero-length file gives
`character(0)`.

## See also

[`merkle_root()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md),
[`sha512_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_file_digest.md)

## Examples

``` r
p <- tempfile()
writeLines(rep("some capsule content", 50), p)

# One small chunk size to show the splitting.
ch <- chunk_file(p, chunk_bytes = 128)
length(ch)
#> [1] 9

# The chunks reconstruct the file and pin it as a Merkle root.
merkle_root(ch)
#> [1] "c4cb691d88a0dbf1dad9767c19095d54ac6958e6411e06d81dced0dba895c382"

# Editing the file changes exactly one leaf.
unlink(p)
```
