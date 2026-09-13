# Attest a capsule, binding a signature to what it covers

Signs a manifest's canonical digest and records everything a verifier
needs alongside it: the scheme, the public key, the context string, the
digest that was signed, and the manifest's seal if it came from a chain.
`capsule_check_attestation()` checks the result against a manifest
without being told anything further.

## Usage

``` r
capsule_attest(manifest, key, context = NULL, prehash = "none", note = NULL)

capsule_check_attestation(attestation, manifest, key_expected = NULL)
```

## Arguments

- manifest:

  A manifest, as from
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md).

- key:

  A signing key from
  [`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
  or
  [`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md).

- context:

  Optional context string, bound into the signature for the standardised
  schemes; see
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md).

- prehash:

  Pre-hash, as in
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md).

- note:

  Optional free text recorded in the attestation – what the signature is
  meant to assert, in the signer's own words. It is covered by the
  signature, since it is part of the digest.

- attestation:

  An attestation from `capsule_attest()`.

- key_expected:

  Optional public key hex the attestation must carry. Supply it when you
  know which key should have signed: without it the check confirms the
  attestation is internally consistent, which any key's holder could
  arrange.

## Value

`capsule_attest()` a list of class `bricklayer_attestation`;
`capsule_check_attestation()` a list with `ok` and a `checks` data
frame, one row per check.

## Details

What this adds over
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md).
A bare signature leaves three things implicit – which key, which scheme,
and which bytes. A verifier who has to be told those out of band cannot
check anything they were not already given, which makes the signature a
formality. An attestation states them, so the check is
`capsule_check_attestation(attestation, manifest)` and nothing else.

What it does NOT establish. That the public key belongs to whoever you
think it does: an attestation is only as good as the channel the key
arrived on. And that the manifest is true – only that it has not changed
since it was signed.
[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md)
is for the other question.

## See also

[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md),
[`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md),
[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md),
[`chain_seal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md).

## Examples

``` r
m <- make_manifest(list(dataset = "otis", rows = 1200L),
                   environment = FALSE)
key <- fips_keygen("ML-DSA-65")
att <- capsule_attest(m, key, note = "counts as published")

# a verifier needs the attestation and the manifest, nothing else
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

# any change to the manifest breaks it
m2 <- m
m2$meta$rows <- 1201L
capsule_check_attestation(att, m2)$ok
#> [1] FALSE

# and so does presenting a different key
capsule_check_attestation(att, m,
  key_expected = fips_keygen("ML-DSA-65")$public)$ok
#> [1] FALSE
```
