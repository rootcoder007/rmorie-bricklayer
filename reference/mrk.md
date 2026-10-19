# Merkle tree over capsule chunks (C backend)

A single SHA-256 over a whole file tells you it changed. A Merkle tree
over its chunks tells you WHICH chunk changed, and proves that one chunk
belongs to the pinned file without re-reading the rest of it. Use these
functions to pin a large data file as a root digest, to find the part of
a re-released file that differs, or to hand someone one chunk with a
short proof that it is part of the pinned file.

## Usage

``` r
mrkroot(chunks, scheme = 2L)

mrklvs(chunks, scheme = 2L)

mrkprf(chunks, index, scheme = 2L)

mrkvrf(leaf, proof, root, scheme = NULL)
```

## Arguments

- chunks:

  Chunk contents, in order: a character vector (one chunk per element),
  a single raw vector (one chunk), or a list of raw vectors and single
  strings, such as
  [`chnkfile()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chnkfile.md)
  returns.

- scheme:

  The hashing scheme: 2 (the default for building, with leaf and node
  prefixes) or 1 (no prefixes, as 0.5.12 and earlier built them). For
  `mrkvrf()`, `NULL` (the default) reads the scheme from `proof`; a
  number requires that scheme, and a proof that records a different one
  does not verify.

- index:

  The chunk to prove, one whole number from 1 to the number of chunks.

- leaf:

  The chunk whose membership is being verified: one string or one raw
  vector.

- proof:

  The list returned by `mrkprf()`.

- root:

  The expected root digest, a 64-character hex string as `mrkroot()`
  returns.

## Value

`mrkroot()` a length-1 character vector (64 lowercase hex characters),
or `NA` for no chunks. `mrklvs()` a character vector of per-chunk
digests, one per chunk (`character(0)` for none). `mrkprf()` a list with
`sibling` (character, the sibling digests from the leaf upward), `side`
(character, `"left"` or `"right"`: the side the sibling is on) and
`scheme` (integer). `mrkvrf()` a length-1 logical.

## Details

`mrkroot()` reduces the chunks to one root digest. `mrklvs()` returns
the per-chunk digests the root is built from, so two capsules can be
diffed chunk by chunk. `mrkprf()` returns the sibling digests on the
path from one leaf to the root, and `mrkvrf()` replays that path.

Each leaf is the SHA-256 of the byte 0x00 followed by a chunk's bytes.
Each parent is the SHA-256 of the byte 0x01 followed by the 64 bytes of
its left and right child digests (the bytes, not their hex spelling).
Levels are paired left to right. This is `scheme = 2`, the default from
0.5.13 on.

An unpaired node at an odd level is PROMOTED unchanged rather than
hashed against a duplicate of itself. Duplicating it would let two
different chunk lists produce the same root – the weakness behind
CVE-2012-2459 – so promotion is a correctness requirement, not a
preference. A promoted node adds no step to a proof, so a proof can be
shorter than \\\lceil \log_2 n \rceil\\.

The two prefix bytes are the leaf and node domain separation of RFC
6962: without them an interior node, given as the 64 bytes of its two
child digests, verifies as a "leaf" with the shorter proof from its
parent. Roots and proofs made by 0.5.12 and earlier have no prefixes
(`scheme = 1`, the weaker scheme). Pass `scheme = 1` to `mrkroot()`,
`mrklvs()` or `mrkprf()` to recompute such a root. `mrkprf()` records
its scheme in the proof, and `mrkvrf()` reads it from there unless
`scheme` is given. A proof with no recorded scheme was made by 0.5.12 or
earlier: it is verified under scheme 1, with a warning. Pass
`scheme = 2` to `mrkvrf()` to refuse such a proof, since a scheme-1
check still accepts an interior node as a leaf.

Character chunks are taken as their bytes, so a root computed from
character input equals the root of the same bytes as raw vectors. The
comparison in `mrkvrf()` is
[`cdgsteq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/keyeddgst.md)
(constant time, case-sensitive).

Errors: `chunks` that is not character, raw or a list of raw vectors and
single strings, or that contains `NA`; `index` outside
`1..length(chunks)`; a `scheme` other than 1 or 2; a `leaf` that is more
than one chunk; a `proof` without `sibling` and `side`, or with the two
of different lengths.

## Examples

``` r
chunks <- c("row1,row2", "row3,row4", "row5,row6", "row7,row8")

root <- mrkroot(chunks)
root
#> [1] "3b1537c90e21c2e66f341b946388abbb78bf249fb433f961fba223b67141be31"

# A single chunk's root is just its own leaf digest.
mrkroot("only") == csha256(c(as.raw(0), charToRaw("only")))
#> [1] TRUE

# The leaves are the per-chunk digests, so a diff names the culprit.
before <- mrklvs(chunks)
after <- mrklvs(c(chunks[1:2], "row5,row6-EDITED", chunks[4]))
which(before != after)
#> [1] 3

# Prove chunk 3 belongs, without holding chunks 1, 2 or 4.
pr <- mrkprf(chunks, 3)
pr
#> $sibling
#> [1] "a1d2780e3c438372d14e12c01b280cf9be97a244adfa43671903812ca0deb88f"
#> [2] "28ee5f4ac1a7a56c508b5f1b9cd5dd74abf929b3d0f2e5852280914ddef3cb88"
#> 
#> $side
#> [1] "right" "left" 
#> 
#> $scheme
#> [1] 2
#> 
mrkvrf(chunks[3], pr, root)
#> [1] TRUE

# The proof fails for a chunk that was not in the tree.
mrkvrf("row5,row6-EDITED", pr, root)
#> [1] FALSE

# Any change to any chunk changes the root.
mrkroot(chunks) == mrkroot(c(chunks[1:3], "row7,row8 "))
#> [1] FALSE

# an odd count: the last node is promoted, so its proof has one step
mrkprf(c("a", "b", "c"), 3)
#> $sibling
#> [1] "b137985ff484fb600db93107c77b0365c80d78f5b429ded0fd97361d077999eb"
#> 
#> $side
#> [1] "left"
#> 
#> $scheme
#> [1] 2
#> 

# an index past the end is refused
try(mrkprf(chunks, 5))
#> Error : `index` must be between 1 and the number of chunks

# a root pinned by 0.5.12 or earlier recomputes with scheme = 1, and its
# proofs (which record no scheme) verify with a warning
old <- mrkprf(chunks, 3, scheme = 1)
old$scheme <- NULL
withCallingHandlers(
  mrkvrf(chunks[3], old, mrkroot(chunks, scheme = 1)),
  warning = function(w) invokeRestart("muffleWarning"))
#> [1] TRUE
```
