# Provenance you can verify

A manifest with a SHA-256 in it proves the data was not corrupted. It
proves nothing about who produced it, because anyone who can edit the
data can recompute the digest and write it back.

This vignette covers the three things that close that gap: signing a
manifest, pinning a capsule chunk by chunk, and making the *history* of
runs tamper-evident rather than only each run.

## Signing: a shared secret

The simplest case is one team, one secret.
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
with `scheme = "hmac"` produces an HMAC-SHA-256 tag: only a key holder
can compute it, so only a key holder can produce a manifest that
verifies.

``` r

manifest <- paste0(
  "source=https://example.org/extract.csv\n",
  "sha256=", core_sha256("id,value\n1,2\n"), "\n",
  "fetched=2026-09-12"
)

sig <- capsule_sign(core_sha256(manifest), key = "team-secret",
                    scheme = "hmac")
capsule_verify(core_sha256(manifest), sig, "team-secret")
#> [1] TRUE
```

An edited manifest has a different digest, which the signature does not
cover:

``` r

edited <- sub("fetched=2026-09-12", "fetched=2026-01-01", manifest)
capsule_verify(core_sha256(edited), sig, "team-secret")
#> [1] FALSE
```

Do not carry raw key bytes around by hand.
[`derive_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/derive_key.md)
stretches a passphrase into a full-width key with PBKDF2:

``` r

# Fixed here so the vignette is reproducible. For a real key the salt
# comes from random_bytes(16), which reads the operating system's
# CSPRNG rather than R's generator.
salt <- "9f2c41a7d8e05b36"
key <- derive_key("correct horse battery staple", salt)
nchar(key)
#> [1] 64
```

The salt is not secret and must be stored beside the capsule – without
the same salt and iteration count, the key cannot be re-derived.

HMAC is symmetric, so anyone who can *verify* can also *sign*. That is
fine within one team and useless for publishing.

## Signing: a public verifier, after quantum

For a verifier who should be able to check but not forge, the signature
has to be asymmetric. The classical options (RSA, Ed25519) fall to
Shor’s algorithm.

Worth being precise about what that threatens. Hashing is fine: Grover’s
algorithm only halves the security exponent, so SHA-256 retains roughly
2^128 preimage resistance, and HMAC with a 256-bit key is likewise fine.
**Signatures** are the part that breaks.

[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
builds a hash-based signing key – a Merkle tree over Winternitz one-time
keys, the RFC 8391 construction, over the SHA-256 this package already
ships. Its security rests on the hash function alone: no lattice
assumption, no elliptic curve, and no new system dependency.

``` r

# Small for the vignette; the default height 10 gives 1024 signatures.
signing_key <- pqc_keygen(height = 3)
signing_key
#> ── Signing key (post-quantum) ────────────────────────────────────
#>   scheme     xmss-sha256
#>   root       ad257038dd2c02ce0d1f6ceb992beb09dd2d210e56639a70ce889312bb069dad
#>   height     3
#>   used       0 of 8 signatures
#>   remaining  8
#>   secret     <withheld>
#>   ! one signature per index; never sign twice at one index
#> ──────────────────────────────────────────────────────────────────
```

Publish the public half. It carries no secret:

``` r

pub <- signing_public_key(signing_key)
pub
#> ── Public verification key ───────────────────────────────────────
#>   scheme  xmss-sha256
#>   root    ad257038dd2c02ce0d1f6ceb992beb09dd2d210e56639a70ce889312bb069dad
#>   height  3
#> ──────────────────────────────────────────────────────────────────
```

``` r

s1 <- capsule_sign(core_sha256(manifest), signing_key)
capsule_verify(core_sha256(manifest), s1, pub)
#> [1] TRUE

# A verifier holding only `pub` cannot forge one.
capsule_verify(core_sha256(edited), s1, pub)
#> [1] FALSE
```

### One signature per index, and no more

A Winternitz key signs **once**. Signing two different messages at one
leaf index leaks enough chain material to forge a third. So the key is
stateful, and
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
returns the advanced state for you to carry forward:

``` r

signing_key <- s1$key_state
signing_key$next_index
#> [1] 1

s2 <- capsule_sign(core_sha256("a second manifest"), signing_key)
capsule_verify(core_sha256("a second manifest"), s2, pub)
#> [1] TRUE
```

An exhausted key is an error rather than a silent wrap-around:

``` r

k <- pqc_keygen(height = 1)          # signs exactly 2 messages
k <- capsule_sign("one", k)$key_state
k <- capsule_sign("two", k)$key_state
capsule_sign("three", k)
#> Error:
#> ! this key is exhausted: a height-1 key signs 2 messages and all of them are used. Generate a new key -- reusing an index would break the signature scheme.
```

On lattices: a standardised lattice signature (ML-DSA, FIPS 204) is
deliberately *not* hand-written here. An uncertified NTT, SHAKE and
rejection sampler would be a worse outcome than no lattice signature at
all.
[`pqc_backends()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_backends.md)
reports what this build can use; where liboqs was found at configure
time it appears alongside the built-in scheme.

``` r

pqc_backends()
#> [1] "xmss-sha256"
```

## Pinning chunk by chunk

A single digest over a file tells you it changed. A Merkle tree over its
chunks tells you *which* chunk changed, and lets you prove one chunk
belongs without re-reading the rest.

``` r

chunks <- c("id,value", "1,2", "3,4", "5,6")
root <- merkle_root(chunks)
root
#> [1] "43bb94e5930a98ec80fc2e06d6a9227fde4174f74e7dd15e710c97f4de80e0ab"
```

``` r

# Editing one chunk moves exactly one leaf.
edited_chunks <- chunks
edited_chunks[3] <- "3,5"
which(merkle_leaves(chunks) != merkle_leaves(edited_chunks))
#> [1] 3
```

``` r

# Prove chunk 3 belongs, holding only it and log2(n) sibling digests.
proof <- merkle_proof(chunks, 3)
proof
#> $sibling
#> [1] "e96f71a6079688ae6f7063cb93d59d5d80d15287032b2b777d77c0f6e15452e2"
#> [2] "a5996cc23ea660aef0bc1260431c976e7d451cceb94cab2bafa8ff2ff09ddc4c"
#> 
#> $side
#> [1] "right" "left"
merkle_verify(chunks[3], proof, root)
#> [1] TRUE
merkle_verify("3,5", proof, root)
#> [1] FALSE
```

[`chunk_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chunk_file.md)
produces the chunks from a file.

An unpaired node at an odd level is *promoted* rather than hashed
against a duplicate of itself. That is a correctness requirement, not a
preference: duplicating the last leaf lets two different chunk lists
produce the same root, which is the CVE-2012-2459 weakness.

``` r

merkle_root(c("a", "b", "c")) == merkle_root(c("a", "b", "c", "c"))
#> [1] FALSE
```

## The history, not just the run

Every manifest above verifies on its own. That says nothing about
whether any were *removed* – delete an inconvenient run and the
remaining manifests are all still perfectly valid.

A chain fixes that by linking each entry to the digest of the one
before:

``` r

chain <- chain_new()
chain <- chain_append(chain, "manifest for run 1", label = "run-1")
chain <- chain_append(chain, "manifest for run 2", label = "run-2")
chain <- chain_append(chain, "manifest for run 3", label = "run-3")
chain
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
```

``` r

# Deleting an entry from the middle breaks the links, and names where.
tampered <- chain
tampered$entries[[2]] <- NULL
chain_verify(tampered)
#> ✗ chain broken at entry 2 of 2
```

### Sign the seal, not the head

Two failure modes, and neither single value catches both:

- Deleting from the **middle** leaves the last entry’s stored digest
  untouched, so the head is unchanged – but
  [`chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  fails.
- Truncating from the **end** leaves a valid prefix that
  [`chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  accepts – but the head changes.

``` r

truncated <- chain
truncated$entries[[3]] <- NULL

c(head_unchanged_by_middle_deletion =
    chain_head(tampered) == chain_head(chain),
  links_accept_truncation = chain_verify(truncated)$valid)
#> head_unchanged_by_middle_deletion           links_accept_truncation 
#>                              TRUE                              TRUE
```

[`chain_seal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
folds the entry count and every link digest into one value, which covers
both. It is the thing to sign:

``` r

seal_sig <- capsule_sign(chain_seal(chain), signing_key)
capsule_verify(chain_seal(chain), seal_sig, pub)
#> [1] TRUE

# The truncated chain seals to a different value.
capsule_verify(chain_seal(truncated), seal_sig, pub)
#> [1] FALSE

# A chain whose links disagree has no seal to offer at all.
chain_seal(tampered)
#> [1] NA
```

## What is verified, and what is not

Every primitive with a published test vector is checked against it:
SHA-512 against FIPS 180-4, HMAC-SHA-256 against RFC 4231, PBKDF2
against the published vectors, BLAKE2b against RFC 7693, CRC-32 against
the ITU V.42 check value.

The XMSS signature scheme is the exception. No official RFC 8391
known-answer vectors ship with the RFC itself, which carries only XDR
formats. The check is instead made against the **reference
implementation**: the whole 2500-byte signature for XMSS-SHA2_10_256 –
index, randomiser, WOTS+ signature and authentication path – is
byte-identical to what `github.com/XMSS/xmss-reference` produces from
the same key material, and those vectors are embedded in the test suite
so the check needs no network. A signature written here can therefore be
handed to another XMSS implementation as bytes.

It is verified against its security properties as well: a genuine
signature verifies, and every tampering of the message, the signature,
the authentication path, the leaf index or the key fails. The scheme is
not *certified*, which is a statement about process rather than about
the bytes.
