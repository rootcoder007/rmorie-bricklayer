# Attest a capsule, binding a signature to what it covers

`capsule_attest()` signs a manifest's canonical digest and records
everything a verifier needs alongside it: the scheme, the public key,
the context string, the pre-hash, a note and the signing time.
`capsule_check_attestation()` checks the result against a manifest
without being told anything further. Use them to publish a capsule
together with proof that its manifest has not changed since you signed
it.

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
  (ML-DSA, SLH-DSA and the other standardised schemes) or
  [`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
  (XMSS).

- context:

  Optional context string (or raw vector), bound into the signature for
  the standardised schemes; see
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md).
  `NULL` (the default) means none.

- prehash:

  Pre-hash, as in
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md):
  `"none"` (the default) or a hash name such as `"sha256"` or
  `"sha512"`.

- note:

  Optional free text recorded in the attestation – what the signature is
  meant to assert, in the signer's own words. It is covered by the
  signature, since it is part of the digest.

- attestation:

  An attestation from `capsule_attest()`.

- key_expected:

  Optional public key the attestation must carry: hex, or a key object
  from
  [`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md),
  [`fips_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
  or
  [`signing_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/signing_public_key.md).
  Supply it when you know which key should have signed: without it the
  check confirms the attestation is internally consistent, which any
  key's holder could arrange.

## Value

`capsule_attest()` a list of class `c("bricklayer_attestation", "list")`
with the character fields `digest`, `scheme`, `public` (hex), `context`,
`prehash`, `note` and `signed_utc` (ISO 8601 UTC time), and `signature`
(a `bricklayer_signature` from
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)).
`capsule_check_attestation()` a list of class
`c("bricklayer_attestation_check", "list")` with `ok` (logical) and
`checks`, a data frame with columns `check`, `ok` and `detail`, one row
per check.

## Details

What this adds over
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md).
A bare signature leaves three things implicit – which key, which scheme,
and which bytes. A verifier who has to be told those out of band cannot
check anything they were not already given, which makes the signature a
formality. An attestation states them, so the check is
`capsule_check_attestation(attestation, manifest)` and nothing else.

What is signed: the payload `digest`
([`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md)
of the manifest), `scheme`, `public`, `context` (hex for a raw context),
`prehash`, `note` and `signed_utc` is put in canonical form
([`manifest_canonical()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md))
and its SHA-256 is signed with
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md).
Every field, the note and the time included, is therefore covered:
editing any of them breaks the signature. With an XMSS key from
[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
the scheme is `"xmss-sha256"` and the context and pre-hash are not used
by the signature; signing uses up one of the key's one-time indices, as
every XMSS signature does.

The check, one row each: `attestation_complete` (every field is
present), `manifest_digest` (the manifest's digest equals the attested
one), `key_as_expected` (only when `key_expected` is given) and
`signature` (the signature verifies under the attested public key). `ok`
is `TRUE` when every row passes.

What it does NOT establish. That the public key belongs to whoever you
think it does: an attestation is only as good as the channel the key
arrived on, which is why `key_expected` exists. And that the manifest is
true – only that it has not changed since it was signed.
[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md)
is for the other question. No chain seal is recorded; to attest a run
history, sign
[`chain_seal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
directly.

Errors: `manifest` not a list; `key` not from
[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
or
[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md);
an invalid `prehash` or `context` (from
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md));
`attestation` not from `capsule_attest()`. A signature that fails to
verify is a failed row, not an error.

## See also

[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md),
[`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md),
[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md),
[`chain_seal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md).

## Examples

``` r
m <- make_manifest(list(dataset = "otis", rows = 1200L),
  environment = FALSE
)
key <- fips_keygen("ML-DSA-65")
att <- capsule_attest(m, key, note = "counts as published")
att
#> ── Capsule attestation ───────────────────────────────────────────
#>   scheme      ML-DSA-65
#>   digest      efa1b7387f225380245de0b5170999e87ad4044f3e8fd2ef6a6bfbc2bd0a9c90
#>   context     <none>
#>   prehash     none
#>   note        counts as published
#>   signed      2026-10-16T06:45:17Z
#>   public key  67ca27fd4542855a4f7b4cc5b7a4200d... (1952 bytes)
#> ──────────────────────────────────────────────────────────────────

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
  key_expected = fips_keygen("ML-DSA-65")$public
)$ok
#> [1] FALSE

# the note is signed too: editing it breaks the signature row
forged <- att
forged$note <- "counts corrected"
capsule_check_attestation(forged, m)$checks[, c("check", "ok")]
#>                  check    ok
#> 1 attestation_complete  TRUE
#> 2      manifest_digest  TRUE
#> 3            signature FALSE

# a context string and a pre-hash
att2 <- capsule_attest(m, key, context = "release 2026-10", prehash = "sha512")
capsule_check_attestation(att2, m, key_expected = key)$ok
#> [1] TRUE

# a key that is not a signing key is refused
try(capsule_attest(m, "not-a-key"))
#> Error : `key` must come from fips_keygen() or pqc_keygen()
```
