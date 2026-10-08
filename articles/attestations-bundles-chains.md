# Attestations, signed bundles and tamper-evident chains

The *Building reproducible data capsules* vignette shows how a capsule
pins data and describes it in a manifest. This one covers the three ways
of putting a signature on that work so a reader can check it: an
**attestation** of a manifest, a **bundle** of a whole capsule
directory, and a **chain** that makes a sequence of manifests
tamper-evident.

## Attesting a manifest

An attestation binds a signature to a manifest *and* to what the
manifest covers, with an optional note from the person signing:

``` r

m <- make_manifest(list(dataset = "otis", rows = 1200L), environment = FALSE)
key <- fips_keygen("ML-DSA-65")
att <- capsule_attest(m, key, note = "counts as published")

res <- capsule_check_attestation(att, m)
res$ok
#> [1] TRUE
res$checks
#>                  check   ok
#> 1 attestation_complete TRUE
#> 2      manifest_digest TRUE
#> 3            signature TRUE
#>                                                             detail
#> 1                                                                 
#> 2 efa1b7387f225380245de0b5170999e87ad4044f3e8fd2ef6a6bfbc2bd0a9c90
#> 3
```

A verifier needs the attestation and the manifest, nothing else. Any
change to the manifest breaks it, and so does presenting a different
key:

``` r

m2 <- m
m2$meta$rows <- 1201L
capsule_check_attestation(att, m2)$ok
#> [1] FALSE

capsule_check_attestation(att, m, key_expected = fips_keygen("ML-DSA-65")$public)$ok
#> [1] FALSE
```

`key_expected` is how a reader pins the signer: the attestation carries
the public key that made it, but a reader who knows which key to expect
should say so, or any key would do.

## Bundling a capsule

A bundle is one signed artifact covering a directory: every file is
hashed (hidden files included), the hashes and the manifest are signed,
and the bundle verifies against the directory later:

``` r

dir <- tempfile()
dir.create(dir)
write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"), row.names = FALSE)
m <- make_manifest(list(dataset = "demo"), environment = FALSE)
key <- fips_keygen("ML-DSA-44")

b <- capsule_bundle(dir, m, key, note = "as published")
capsule_bundle_verify(attr(b, "path"), dir, manifest = m)$ok
#> [1] TRUE
```

Touch a byte of the data and the bundle no longer holds; the result
names the file:

``` r

write.csv(data.frame(x = 1:4), file.path(dir, "data.csv"), row.names = FALSE)
v <- capsule_bundle_verify(attr(b, "path"), dir, manifest = m)
v$ok
#> [1] FALSE
```

``` r

capsule_bundle_read(attr(b, "path"))$attestation$note
#> [1] "as published"
unlink(dir, recursive = TRUE)
```

## A chain of manifests

A per-manifest signature proves each manifest is intact but says nothing
about the *sequence*: a run could be deleted from the middle of a
series, or two swapped, and every remaining signature would still
verify. A hash chain links each entry to the one before it, so deletion,
insertion and reordering all break it:

``` r

ch <- chain_new()
ch <- chain_append(ch, "manifest for run 1", label = "run-1")
ch <- chain_append(ch, "manifest for run 2", label = "run-2")
ch <- chain_append(ch, "manifest for run 3", label = "run-3")
chain_verify(ch)$valid
#> [1] TRUE
```

Editing an entry breaks the chain and names where:

``` r

edited <- ch
edited$entries[[2]]$digest <- core_sha256("something else")
chain_verify(edited)$valid
#> [1] FALSE
chain_verify(edited)$broken_at
#> [1] 2
```

Deleting one breaks it too, which a per-manifest digest would never
catch:

``` r

dropped <- ch
dropped$entries[[2]] <- NULL
chain_verify(dropped)$valid
#> [1] FALSE
```

### Sealing the chain

The seal covers the links *and the length* together, so one signature
over the seal fixes the whole history. Truncating the chain still seals,
but to a different value:

``` r

key <- fips_keygen("ML-DSA-44")
sig <- capsule_sign(chain_seal(ch), key)
capsule_verify(chain_seal(ch), sig, fips_public_key(key))
#> [1] TRUE

truncated <- ch
truncated$entries[[3]] <- NULL
capsule_verify(chain_seal(truncated), sig, fips_public_key(key))
#> [1] FALSE
```

A chain whose links disagree has no seal to present at all:

``` r

chain_seal(dropped)
#> [1] NA
```

## Which to use

- One manifest, one signer:
  [`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md).
- A directory of files that must travel together:
  [`capsule_bundle()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_bundle.md).
- A series of runs, releases or data refreshes where order and
  completeness matter:
  [`chain_append()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  after each, sign
  [`chain_seal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  at each release.

All three accept any signing key the package knows: ML-DSA and SLH-DSA
([`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md))
or XMSS
([`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md),
with the key state carried forward). A shared secret from
[`derive_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/derive_key.md)
is for keyed digests
([`core_hmac_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_keyed_digest.md)),
not for attestations: an attestation names a public key, and a shared
secret has none.
