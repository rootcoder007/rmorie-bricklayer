# Tamper-evident chain of capsule manifests

Keeps a history of runs (one manifest per run) as a hash chain: each
entry records the digest of the entry before it, so the chain's
integrity covers the ORDER and COMPLETENESS of the history, not merely
the contents of each manifest. Deleting an entry, inserting one, or
editing one breaks the links from that point onward, and `chnvrf()`
reports the first index where the break occurs. Use it when the record
of which analyses were run, and in what order, has to be auditable.

## Usage

``` r
chnnew()

chnapp(chain, entry, label = NA_character_)

chnhead(chain)

chnseal(chain)

chnvrf(chain)
```

## Arguments

- chain:

  A chain from `chnnew()` or `chnapp()`.

- entry:

  Any object to record. It is digested through its own deterministic
  serialization, so lists and data frames are accepted as readily as
  strings.

- label:

  Optional short label for the entry (the first element of
  `as.character(label)` is kept); `NA` by default. Covered by the
  entry's digest.

## Value

`chnnew()` and `chnapp()` return an object of class
`c("bricklayer_chain", "list")` with `entries` (a list of entries, each
with `label`, `payload`, `prev`, `scheme` and `digest`) and `genesis`
(64 zeros). `chnvrf()` returns a list of class `bricklayer_chain_check`
with `valid` (logical), `n` (integer, entries), `broken_at` (integer
index of the first bad entry, `NA` when intact) and `head`. `chnhead()`
returns the head digest (64 hex characters; the genesis value for an
empty chain). `chnseal()` returns a single digest over the verified
chain's length and links, or `NA` if the chain does not verify.

## Details

`chnnew()` starts an empty chain, `chnapp()` adds an entry, `chnhead()`
returns the last link, `chnvrf()` checks every link and `chnseal()`
returns one digest to sign.

This is the structure behind an append-only audit log, and it is what a
per-manifest digest alone cannot give you: individually valid manifests
say nothing about whether any were removed.

Each entry stores `payload`, the SHA-256 of the entry (of its UTF-8
bytes for a single string, otherwise of
`serialize(entry, version = 2, xdr = TRUE)` with the four bytes that
name the writer's R version set to zero), `prev`, the previous link (64
zeros for the first), `scheme` (2) and `digest` = SHA-256 of
`"v2|<prev>|<payload>|<label>"`, where `<label>` is `"0"` for a missing
label and `"1"` followed by the label otherwise. The entry itself is not
kept, only its digest; the label is covered, so editing it breaks the
link. Zeroing the writer-version bytes makes the payload the same on
every R version, for any R object (a canonical JSON encoding would cover
only the objects JSON can hold); the rest of a version-2 stream depends
only on the object.

Entries written by 0.5.12 and earlier carry no `scheme`. Their digest is
the SHA-256 of the string `"<prev>:<payload>"` (the label not covered,
and the payload of a non-string entry taken over serialized bytes that
include the writer's R version). `chnvrf()` and `chnseal()` still accept
them under those rules, with a warning that they were sealed with the
weaker scheme. Appending to such a chain adds scheme-2 entries.

`chnvrf()` walks the chain from the start: an entry fails when its
`prev` is not the previous link, its `scheme` is neither 2 nor absent,
or its `digest` does not recompute (compared in constant time with
[`cdgsteq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/keyeddgst.md)).

### What the head covers, and what it does not

`chnhead()` is the STORED digest of the last entry. Deleting an entry
from the MIDDLE leaves that value untouched – the stored digests do not
change, only the links between them stop agreeing – so the head alone
will not notice. `chnvrf()` will, and names the index.

Conversely, truncating from the END leaves a perfectly valid prefix that
`chnvrf()` accepts, while the head changes.

The two failures are complementary, which is why `chnseal()` exists: it
verifies the links AND folds the entry count and every link digest into
one value (SHA-256 of the count and the links joined by `"|"`), so a
single signature over the seal detects an edit, a deletion, a
reordering, an insertion and a truncation alike. Sign the seal, not the
head.

Signing is what turns tamper-EVIDENT into tamper-PROOF: without a
signature an attacker who rewrites the whole chain leaves it internally
consistent, because recomputing every link is cheap.

Error: a `chain` that does not come from `chnnew()` (for `chnapp()`,
`chnhead()` and `chnvrf()`).

## See also

[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
to sign the seal,
[`mrkroot()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mrk.md)
for pinning the contents of one capsule rather than a history.

## Examples

``` r
op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
# one-time index record out of your configuration directory; leave the default in use
ch <- chnnew()
ch <- chnapp(ch, "manifest for run 1", label = "run-1")
ch <- chnapp(ch, "manifest for run 2", label = "run-2")
ch <- chnapp(ch, "manifest for run 3", label = "run-3")
ch
#> ── Manifest chain ────────────────────────────────────────────────
#>   ✓ chain intact
#> 
#>   entries  3
#>   head     b9ccb96106a68f3d4d2a0cfb8e2ae160f7996393e28e93d7f4650c2bbd81ff49
#>   seal     940721e3704268b570bcbf1c9ae841bde02927f584ec44dc3cf053ef7404d8a0
#> 
#>     1  run-1            cb25fa776c693a106b2d08a1
#>     2  run-2            03a645a531c93fbb12bb2c07
#>     3  run-3            b9ccb96106a68f3d4d2a0cfb
#> ──────────────────────────────────────────────────────────────────

# An intact chain verifies.
chnvrf(ch)$valid
#> [1] TRUE

# Editing an entry breaks it, and names where.
edited <- ch
edited$entries[[2]]$digest <- csha256("something else")
chnvrf(edited)$valid
#> [1] FALSE
chnvrf(edited)$broken_at
#> [1] 2

# So does deleting one, which a per-manifest digest would not catch.
dropped <- ch
dropped$entries[[2]] <- NULL
chnvrf(dropped)$valid
#> [1] FALSE

# Sign the SEAL, which covers the links and the length together.
key <- pqckg(height = 2)
sig <- cpssign(chnseal(ch), key)
cpsvrf(chnseal(ch), sig, signpubkey(key))
#> [1] TRUE

# Truncating the chain still seals, but to a different value, so the
# signature no longer verifies.
truncated <- ch
truncated$entries[[3]] <- NULL
cpsvrf(chnseal(truncated), sig, signpubkey(key))
#> [1] FALSE

# A chain whose links disagree has no seal to present at all.
chnseal(dropped)
#> [1] NA

# any object can be an entry, such as a whole manifest list
ch2 <- chnapp(chnnew(), list(run = 1, mean = 2.5), label = "list entry")
chnhead(ch2)
#> [1] "05bb042d04eb7378d536c4197e61f280f2e9f99d33d0c9cc28a475c488a4a206"

# only chains are accepted
try(chnvrf(list(entries = list())))
#> Error : `chain` must come from chnnew()
options(op)
```
