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
#>   root       495ba36966da625137ed5b72d48a52f49d56cf06746ba7617982f6e044fe6ba9
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
#>   root    495ba36966da625137ed5b72d48a52f49d56cf06746ba7617982f6e044fe6ba9
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

On the standardised schemes: ML-DSA (FIPS 204) and SLH-DSA (FIPS 205)
are implemented here too, at every parameter set both standards define –
three for ML-DSA, twelve for SLH-DSA – with no system dependency, so the
list
[`pqc_backends()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_backends.md)
reports is the same on every machine.
[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
takes any of them,
[`fips_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_key.md)
wraps key material that came from elsewhere, and both are stateless: one
key signs any number of messages.

What makes that defensible is the cross-check rather than care. In
deterministic mode this package and OpenSSL 3.5 produce the same bytes
for every parameter set, which is a test a subtly wrong implementation
cannot pass: it would have to be wrong in exactly the same way, in a
construction where a single misplaced field changes every output.

``` r

pqc_backends()
#>  [1] "xmss-sha256"        "ML-DSA-44"          "ML-DSA-65"         
#>  [4] "ML-DSA-87"          "SLH-DSA-SHA2-128s"  "SLH-DSA-SHA2-128f" 
#>  [7] "SLH-DSA-SHA2-192s"  "SLH-DSA-SHA2-192f"  "SLH-DSA-SHA2-256s" 
#> [10] "SLH-DSA-SHA2-256f"  "SLH-DSA-SHAKE-128s" "SLH-DSA-SHAKE-128f"
#> [13] "SLH-DSA-SHAKE-192s" "SLH-DSA-SHAKE-192f" "SLH-DSA-SHAKE-256s"
#> [16] "SLH-DSA-SHAKE-256f"
```

## Signing something a verifier can check

[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
signs a string, which proves the string was signed and leaves three
things implicit: which key, which scheme, which bytes. A verifier handed
a directory still has to be told all three, and a check that depends on
being told what to check is a formality.

[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)
records them inside the signed payload.

``` r

m <- make_manifest(list(dataset = "otis", rows = 1200L),
                   environment = FALSE)
key <- fips_keygen("ML-DSA-65")
att <- capsule_attest(m, key, note = "counts as published")
capsule_check_attestation(att, m)
#> ── Attestation check: OK ─────────────────────────────────────────
#>   attestation_complete   ok    
#>   manifest_digest        ok    efa1b7387f225380245de0b5170999e87ad4044f3e8f
#>   signature              ok    
#> ──────────────────────────────────────────────────────────────────
```

The check needs the attestation and the manifest, nothing else. Change
either – or edit the note, which is covered by the signature because it
is part of the digest – and it fails:

``` r

m2 <- m
m2$meta$rows <- 1201L
capsule_check_attestation(att, m2)$ok
#> [1] FALSE
```

What it does not establish is that the key belongs to whoever you think:
an attestation is only as good as the channel the public key arrived on.
Pass `key_expected` when you know which key should have signed.

## The number in the manifest is the number

A manifest is meant to be checked against later. That only works if it
records what actually happened, at the precision it happened:

``` r

one_third <- make_manifest(list(x = 1 / 3), environment = FALSE)
back <- bricklayer_json_from_json(manifest_canonical(one_third))
identical(back$meta$x, 1 / 3)
#> [1] TRUE
```

Sign
[`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md)
rather than the pretty JSON. R lists keep insertion order, so building
`meta` before `results` or the other way round gives different bytes for
the same content; the canonical form sorts the keys, so the digest
depends on what the manifest says and not on how a script assembled it.

``` r

identical(
  manifest_digest(make_manifest(list(a = 1, b = 2), environment = FALSE)),
  manifest_digest(make_manifest(list(b = 2, a = 1), environment = FALSE)))
#> [1] TRUE
```

## Whether the finding survives

Everything above is about the record being intact. None of it says the
number means anything: a capsule can be signed, hashed, chained and
reproduced byte for byte while reporting an artefact. That is a separate
question and it needs controls that can fail.

``` r

set.seed(1)
d <- data.frame(x = rnorm(200))
d$y <- 0.8 * d$x + rnorm(200)
capsule_falsify(d, function(z) cor(z$x, z$y), treatment = "x",
                n = 199, seed = 42)
#> ── Falsification controls ────────────────────────────────────────
#>   observed statistic  0.5812737
#>   permutations        199 (seed 42)
#> ──────────────────────────────────────────────────────────────────
#>   permutation            ok    p = 0.005 with 199 usable permutations; 
#>   placebo                ok    a permuted exposure gives 0.0702711, aga
#>   random_common_cause    ok    adding a column of noise moved the stati
#>   subset_stability       ok    the middle 95% of 199 subsets spans [0.5
#> ──────────────────────────────────────────────────────────────────
```

Four controls, each for a different way of being wrong: permuting the
exposure destroys the association, so the statistic should fall to its
null; a column of noise cannot matter, so the statistic should not move;
a placebo exposure should show nothing; and random subsets should agree.

They can fail, which is the point. A constant fails the permutation test
and nothing else, because everything else about a constant is perfectly
stable:

``` r

capsule_falsify(d, function(z) 0.5, treatment = "x", n = 199,
                seed = 42)$controls[, c("control", "passed")]
#>               control passed
#> 1         permutation  FALSE
#> 2             placebo   TRUE
#> 3 random_common_cause   TRUE
#> 4    subset_stability   TRUE
```

Note what the permutation control reports alongside its p-value: the
smallest p-value the design could have produced. With 199 permutations
that floor is 0.005, and with 19 it is 0.05 – so a p of 0.05 from 19
permutations is not weak evidence, it is no evidence at all.

## Re-deriving the numbers, not just checking them

[`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md)
reads a manifest and confirms it is consistent with itself. That catches
an edited manifest and cannot catch one that was wrong when it was
written, because a manifest written from the wrong data is perfectly
consistent too.

``` r

d <- data.frame(x = 1:10)
man <- make_manifest(list(dataset = "demo"), environment = FALSE)
man <- record(man, "mean_x", observed = mean(d$x), expected = 5.5)
#>   mean_x                                       observed = 5.5000       expected = 5.5000       [PASS]
man <- record(man, "n", observed = nrow(d), expected = 10)
#>   n                                            observed = 10.0000      expected = 10.0000      [PASS]

manifest_recompute(man, d, list(mean_x = function(z) mean(z$x),
                                n = function(z) nrow(z)))
#> ── Recomputation: everything checked and matched ─────────────────
#>   mean_x                   MATCH      |recorded - recomputed| = 0
#>   n                        MATCH      |recorded - recomputed| = 0
#> ──────────────────────────────────────────────────────────────────
```

Recompute only some of them and the rest are reported as unchecked
rather than passed over, which is the difference between a clean bill of
health and a partial one:

``` r

manifest_recompute(man, d, list(n = function(z) nrow(z)))
#> ── Recomputation: see below ──────────────────────────────────────
#>   n                        MATCH      |recorded - recomputed| = 0
#> ──────────────────────────────────────────────────────────────────
#>   1 recorded result(s) NOT recomputed: mean_x
#> ──────────────────────────────────────────────────────────────────
```

For anything stochastic, record the generator state rather than the
seed. `set.seed(1)` reproduces a run only if everything before it does
too – one extra draw anywhere upstream shifts every later value:

``` r

set.seed(1)
m2 <- manifest_record_seed(make_manifest(list(a = 1),
                                         environment = FALSE))
first <- runif(3)
invisible(runif(1000))          # any amount of other work
manifest_restore_seed(m2)
identical(runif(3), first)
#> [1] TRUE
```

## Saying in advance what you will report

The falsification controls above are worth much more when the statistics
were named before the data was looked at. A declaration makes the two
ways of departing from a plan visible, and they are different failures:

``` r

plan <- prereg_declare(c(
  ate = "use of force is higher in the exposed division",
  n_rows = "the extract has the row count the source publishes"))

# a declared outcome that was not reported
prereg_check(plan, "n_rows")
#> ── Against the declaration of 2026-09-13T02:36:00Z: departures below 
#>   declared but not reported (outcome switching): ate
#> ──────────────────────────────────────────────────────────────────

# statistics reported that were never declared
prereg_check(plan, c("ate", "n_rows", "by_year", "by_precinct"))
#> ── Against the declaration of 2026-09-13T02:36:00Z: departures below 
#>   reported but not declared (2 addition(s)): by_year, by_precinct
#> ──────────────────────────────────────────────────────────────────
```

That second case is why a nominal p-value needs correcting. Run the
permutation control over several statistics and the smallest is not the
finding:

``` r

falsify_family(c(ate = 0.02, by_year = 0.3, by_precinct = 0.4,
                 by_shift = 0.6, by_month = 0.7), method = "holm")
#> ── Family of 5, corrected by holm at alpha 0.05 ──────────────────
#>   ate                    p 0.02       adjusted 0.1        
#>   by_year                p 0.3        adjusted 1          
#>   by_precinct            p 0.4        adjusted 1          
#>   by_shift               p 0.6        adjusted 1          
#>   by_month               p 0.7        adjusted 1          
#> ──────────────────────────────────────────────────────────────────
```

And for the confounder nobody measured, the E-value says how strong it
would have to be to explain the result away – with both the exposure and
the outcome:

``` r

evalue_rr(2, lo = 1.4, hi = 2.9)
#> evalue_point evalue_limit 
#>     3.414214     2.148331
```

## One file to hand someone

A bundle carries a digest of every file, the manifest digest, and an
attestation over both. The file digests are inside the signature, which
is the point: a list of hashes that is not itself signed can be
rewritten to match whatever the files now say.

``` r

dir <- tempfile()
dir.create(dir)
write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"),
          row.names = FALSE)
b <- capsule_bundle(dir, man, key, note = "as published")
capsule_bundle_verify(attr(b, "path"), dir, manifest = man)
#> ── Bundle check: OK ──────────────────────────────────────────────
#>   file:data.csv                  ok    95aecaa7399a39092c9e716ce1e18bb1c606
#>   no_unlisted_files              ok    
#>   attestation:attestation_comple ok    
#>   attestation:manifest_digest    ok    7ec9ce5b87041795d4c16405f92493de7d02
#>   attestation:signature          ok    
#>   manifest_digest                ok    5f711161c72a5bcf5b5918d69a6a59fbe38a
#> ──────────────────────────────────────────────────────────────────
```

Files sitting in the directory that the bundle does not mention are
reported as well: a signed list of what should be there says nothing
about what else was put beside it.

``` r

unlink(dir, recursive = TRUE)
```

## When, not just in what order

The chain proves the order of a sequence of manifests. It does not prove
that any of them existed at a particular time – the whole chain can be
built in an afternoon and dated however one likes. An RFC 3161 timestamp
token from a third party supplies the date, and
[`timestamp_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/timestamp_verify.md)
checks three separate things: that the token is about these bytes, what
time it asserts, and that the authority’s signature holds.

``` r

res <- timestamp_verify("response.tsr", data = "manifest.json")
res$time
res$checks
```

What it does not check, and this is the difference between it and a
browser’s padlock: whether the certificate should be trusted. There is
no chain building, no validity dates, no revocation and no check of the
timeStamping key usage. Pass the certificate you have independently
decided to trust, and read a pass as “this key said so” rather than
“this is true”.

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
