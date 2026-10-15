# Tamper-evident chain of capsule manifests

Keeps a history of runs (one manifest per run) as a hash chain: each
entry records the digest of the entry before it, so the chain's
integrity covers the ORDER and COMPLETENESS of the history, not merely
the contents of each manifest. Deleting an entry, inserting one, or
editing one breaks the links from that point onward, and
`chain_verify()` reports the first index where the break occurs. Use it
when the record of which analyses were run, and in what order, has to be
auditable.

## Usage

``` r
chain_new()

chain_append(chain, entry, label = NA_character_)

chain_head(chain)

chain_seal(chain)

chain_verify(chain)
```

## Arguments

- chain:

  A chain from `chain_new()` or `chain_append()`.

- entry:

  Any object to record. It is digested through its own deterministic
  serialization, so lists and data frames are accepted as readily as
  strings.

- label:

  Optional short label for the entry (the first element of
  `as.character(label)` is kept); `NA` by default. Covered by the
  entry's digest.

## Value

`chain_new()` and `chain_append()` return an object of class
`c("bricklayer_chain", "list")` with `entries` (a list of entries, each
with `label`, `payload`, `prev`, `scheme` and `digest`) and `genesis`
(64 zeros). `chain_verify()` returns a list of class
`bricklayer_chain_check` with `valid` (logical), `n` (integer, entries),
`broken_at` (integer index of the first bad entry, `NA` when intact) and
`head`. `chain_head()` returns the head digest (64 hex characters; the
genesis value for an empty chain). `chain_seal()` returns a single
digest over the verified chain's length and links, or `NA` if the chain
does not verify.

## Details

`chain_new()` starts an empty chain, `chain_append()` adds an entry,
`chain_head()` returns the last link, `chain_verify()` checks every link
and `chain_seal()` returns one digest to sign.

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
SHA-256 of `"<prev>:<payload>"` (the label not covered, and the payload
of a non-string entry taken over serialized bytes that include the
writer's R version). `chain_verify()` and `chain_seal()` still accept
them under those rules, with a warning that they were sealed with the
weaker scheme. Appending to such a chain adds scheme-2 entries.

`chain_verify()` walks the chain from the start: an entry fails when its
`prev` is not the previous link, its `scheme` is neither 2 nor absent,
or its `digest` does not recompute (compared in constant time with
[`core_digest_equal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_keyed_digest.md)).

### What the head covers, and what it does not

`chain_head()` is the STORED digest of the last entry. Deleting an entry
from the MIDDLE leaves that value untouched – the stored digests do not
change, only the links between them stop agreeing – so the head alone
will not notice. `chain_verify()` will, and names the index.

Conversely, truncating from the END leaves a perfectly valid prefix that
`chain_verify()` accepts, while the head changes.

The two failures are complementary, which is why `chain_seal()` exists:
it verifies the links AND folds the entry count and every link digest
into one value (SHA-256 of the count and the links joined by `"|"`), so
a single signature over the seal detects an edit, a deletion, a
reordering, an insertion and a truncation alike. Sign the seal, not the
head.

Signing is what turns tamper-EVIDENT into tamper-PROOF: without a
signature an attacker who rewrites the whole chain leaves it internally
consistent, because recomputing every link is cheap.

Error: a `chain` that does not come from `chain_new()` (for
`chain_append()`, `chain_head()` and `chain_verify()`).

## See also

[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
to sign the seal,
[`merkle_root()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md)
for pinning the contents of one capsule rather than a history.

## Examples

``` r
op <- options(rmoriebricklayer.xmss_index_file = tempfile())  # keep this example's
# one-time index record out of your configuration directory; leave the default in use
ch <- chain_new()
ch <- chain_append(ch, "manifest for run 1", label = "run-1")
ch <- chain_append(ch, "manifest for run 2", label = "run-2")
ch <- chain_append(ch, "manifest for run 3", label = "run-3")
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
chain_verify(ch)$valid
#> [1] TRUE

# Editing an entry breaks it, and names where.
edited <- ch
edited$entries[[2]]$digest <- core_sha256("something else")
chain_verify(edited)$valid
#> [1] FALSE
chain_verify(edited)$broken_at
#> [1] 2

# So does deleting one, which a per-manifest digest would not catch.
dropped <- ch
dropped$entries[[2]] <- NULL
chain_verify(dropped)$valid
#> [1] FALSE

# Sign the SEAL, which covers the links and the length together.
key <- pqc_keygen(height = 2)
sig <- capsule_sign(chain_seal(ch), key)
capsule_verify(chain_seal(ch), sig, signing_public_key(key))
#> [1] TRUE

# Truncating the chain still seals, but to a different value, so the
# signature no longer verifies.
truncated <- ch
truncated$entries[[3]] <- NULL
capsule_verify(chain_seal(truncated), sig, signing_public_key(key))
#> [1] FALSE

# A chain whose links disagree has no seal to present at all.
chain_seal(dropped)
#> [1] NA

# any object can be an entry, such as a whole manifest list
ch2 <- chain_append(chain_new(), list(run = 1, mean = 2.5), label = "list entry")
chain_head(ch2)
#> [1] "05bb042d04eb7378d536c4197e61f280f2e9f99d33d0c9cc28a475c488a4a206"

# only chains are accepted
try(chain_verify(list(entries = list())))
#> Error : `chain` must come from chain_new()
options(op)
```
