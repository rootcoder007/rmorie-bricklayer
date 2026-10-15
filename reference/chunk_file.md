# Split a file into fixed-size chunks

Reads a file as bytes and returns it as consecutive chunks of a fixed
size, ready for
[`merkle_root()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md),
[`merkle_leaves()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md)
and
[`merkle_proof()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md).
Use it to pin a large data file as a Merkle root, so that a later change
can be traced to the chunk that moved.

## Usage

``` r
chunk_file(path, chunk_bytes = 1048576L)
```

## Arguments

- path:

  Path to an existing file, a single string.

- chunk_bytes:

  Chunk size in bytes, a positive whole number (default 1048576, i.e. 1
  MiB).

## Value

A list of raw vectors, in file order. A zero-length file gives an empty
list. Chunks are returned as bytes rather than strings because a file is
bytes: an R string cannot hold a zero byte, so a character chunk could
not represent an arbitrary binary file at all.

## Details

The file is read sequentially with
[`readBin()`](https://rdrr.io/r/base/readBin.html) in pieces of
`chunk_bytes`; every chunk has exactly that many bytes except the last,
which holds the remainder. All chunks are held in memory at once, so the
memory used is about the size of the file. The default 1 MiB chunk is a
compromise: smaller chunks localise a change more precisely but make the
tree and its proofs larger. An edit that changes the file's length
shifts every later chunk boundary, so only edits that keep the length
localise to one chunk.

Errors: `path` that does not name an existing file (or names a
directory); `chunk_bytes` that is not a positive whole number.

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
lengths(ch)
#> [1] 128 128 128 128 128 128 128 128  26

# The chunks pin the file as a Merkle root.
merkle_root(ch)
#> [1] "3f565b39becbebbc336618294525d7a1ff45394d68ecaec899d292bb0fd357c1"

# They are the file's bytes, so they concatenate back to it exactly.
identical(unlist(ch), readBin(p, "raw", file.size(p)))
#> [1] TRUE

# Overwriting bytes in place changes exactly one leaf.
b <- readBin(p, "raw", file.size(p))
b[300] <- as.raw(0x58)
q <- tempfile()
writeBin(b, q)
which(merkle_leaves(ch) != merkle_leaves(chunk_file(q, chunk_bytes = 128)))
#> [1] 3

# a chunk size must be positive
try(chunk_file(p, chunk_bytes = 0))
#> Error : `chunk_bytes` must be a positive integer
unlink(c(p, q))
```
