# Tamper-evident chain of capsule manifests

Each entry records the digest of the entry before it, so the chain's
integrity covers the ORDER and COMPLETENESS of the history, not merely
the contents of each manifest. Deleting an entry, inserting one, or
editing one breaks the links from that point onward, and
`chain_verify()` reports the first index where the break occurs.

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

  Optional short character label for the entry.

## Value

`chain_new()` and `chain_append()` return an object of class
`bricklayer_chain`. `chain_verify()` returns a list with `valid`, `n`,
`broken_at` (`NA` when intact) and `head`. `chain_head()` returns the
head digest. `chain_seal()` returns a single digest over the verified
chain's length and links, or `NA` if the chain does not verify.

## Details

This is the structure behind an append-only audit log, and it is what a
per-manifest digest alone cannot give you: individually valid manifests
say nothing about whether any were removed.

## What the head covers, and what it does not

`chain_head()` is the STORED digest of the last entry. Deleting an entry
from the MIDDLE leaves that value untouched – the stored digests do not
change, only the links between them stop agreeing – so the head alone
will not notice. `chain_verify()` will, and names the index.

Conversely, truncating from the END leaves a perfectly valid prefix that
`chain_verify()` accepts, while the head changes.

The two failures are complementary, which is why `chain_seal()` exists:
it verifies the links AND folds the entry count and every link digest
into one value, so a single signature over the seal detects an edit, a
deletion, a reordering, an insertion and a truncation alike. Sign the
seal, not the head.

Signing is what turns tamper-EVIDENT into tamper-PROOF: without a
signature an attacker who rewrites the whole chain leaves it internally
consistent, because recomputing every link is cheap.

## See also

[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
to sign the head,
[`merkle_root()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md)
for pinning the contents of one capsule rather than a history.

## Examples

``` r
ch <- chain_new()
ch <- chain_append(ch, "manifest for run 1", label = "run-1")
ch <- chain_append(ch, "manifest for run 2", label = "run-2")
ch <- chain_append(ch, "manifest for run 3", label = "run-3")
ch
#> ── Manifest chain ────────────────────────────────────────────────
#>   ✓ chain intact
#> 
#>   entries  3
#>   head     2afe0e270d2b1fbbc080dd4624540c181e5b8458aaecf247ccb8c38dc4c387da
#>   seal     de28f9277b3f9f4cb3b1a7dd80e556d0c6e1568723f1395732f9d087ee7f7353
#> 
#>     1  run-1            7947c9201969a6793f9daf05
#>     2  run-2            9dbaa6d33259f974f30ff33e
#>     3  run-3            2afe0e270d2b1fbbc080dd46
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
```
