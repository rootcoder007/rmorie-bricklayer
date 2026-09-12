# Merkle tree over capsule chunks (C backend)

A single SHA-256 over a whole file tells you it changed. A Merkle tree
over its chunks tells you WHICH chunk changed, and proves that one chunk
belongs to the pinned file without re-reading the rest of it.

## Usage

``` r
merkle_root(chunks)

merkle_leaves(chunks)

merkle_proof(chunks, index)

merkle_verify(leaf, proof, root)
```

## Arguments

- chunks:

  Character vector of chunk contents, in order. Use
  [`chunk_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chunk_file.md)
  to produce it from a file.

- index:

  1-based index of the chunk to prove.

- leaf:

  The chunk whose membership is being verified.

- proof:

  The list returned by `merkle_proof()`.

- root:

  The expected root digest.

## Value

`merkle_root()` a length-1 character vector (64 hex characters), or `NA`
for no chunks. `merkle_leaves()` a character vector of per-chunk
digests. `merkle_proof()` a list with `sibling` (character) and `side` (
`"left"` / `"right"`) . `merkle_verify()` a length-1 logical.

## Details

`merkle_root()` reduces the chunks to one root digest. `merkle_leaves()`
returns the per-chunk digests the root is built from, so two capsules
can be diffed chunk by chunk. `merkle_proof()` returns the sibling
digests on the path from one leaf to the root, and `merkle_verify()`
replays that path.

An unpaired node at an odd level is PROMOTED unchanged rather than
hashed against a duplicate of itself. Duplicating it would let two
different chunk lists produce the same root – the weakness behind
CVE-2012-2459 – so promotion is a correctness requirement, not a
preference.

## Examples

``` r
chunks <- c("row1,row2", "row3,row4", "row5,row6", "row7,row8")

root <- merkle_root(chunks)
root
#> [1] "d2197affda886ecc49807b28c90a8c4ff7a07f122225ecc64788d08df5a312f3"

# A single chunk's root is just its own digest.
merkle_root("only") == core_sha256("only")
#> [1] TRUE

# The leaves are the per-chunk digests, so a diff names the culprit.
before <- merkle_leaves(chunks)
after <- merkle_leaves(c(chunks[1:2], "row5,row6-EDITED", chunks[4]))
which(before != after)
#> [1] 3

# Prove chunk 3 belongs, without holding chunks 1, 2 or 4.
pr <- merkle_proof(chunks, 3)
pr
#> $sibling
#> [1] "a9199c29a2bc724e33e3dd4ad9bffd41e9bc0f187d998b46676980240fe16bce"
#> [2] "797f2302a18a964bc609952c054c5ed815d371dc71428cade513006202d05a9c"
#> 
#> $side
#> [1] "right" "left" 
#> 
merkle_verify(chunks[3], pr, root)
#> [1] TRUE

# The proof fails for a chunk that was not in the tree.
merkle_verify("row5,row6-EDITED", pr, root)
#> [1] FALSE

# Any change to any chunk changes the root.
merkle_root(chunks) == merkle_root(c(chunks[1:3], "row7,row8 "))
#> [1] FALSE
```
