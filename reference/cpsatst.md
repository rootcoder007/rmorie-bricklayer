# Attest a capsule, binding a signature to what it covers

`cpsatst()` signs a manifest's canonical digest and records everything a
verifier needs alongside it: the scheme, the public key, the context
string, the pre-hash, a note and the time of signing. `cpschkatst()`
checks the result against a manifest without being told anything
further. Use them to publish a capsule together with proof that its
manifest has not changed since you signed it.

## Usage

``` r
cpsatst(man, key, ctx = NULL, prehash = "none", note = NULL)

cpschkatst(attest, man, keyexp = NULL, key = NULL)
```

## Arguments

- man:

  A manifest, as from
  [`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md).

- key:

  For `cpsatst()`, a signing key from
  [`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
  (ML-DSA, SLH-DSA and the other standardised schemes) or
  [`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md)
  (XMSS), or a shared secret (a string or raw vector) for `"hmac"`. For
  `cpschkatst()`, the shared secret that checks an `"hmac"` attestation;
  it is not used for the other schemes, whose public key the attestation
  carries.

- ctx:

  Optional context string (or raw vector), bound into the signature for
  the standardised schemes; see
  [`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md).
  `NULL` (the default) means none.

- prehash:

  Pre-hash, as in
  [`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md).
  It is `"none"` (the default) or a hash name such as `"sha256"` or
  `"sha512"`.

- note:

  Optional free text recorded in the attestation – what the signature is
  meant to assert, in the signer's own words. It is covered by the
  signature, since it is part of the digest.

- attest:

  An attestation from `cpsatst()`.

- keyexp:

  Optional public key the attestation must carry, as hex or as a key
  object from
  [`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md),
  [`fipspubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
  or
  [`signpubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/signpubkey.md).
  Supply it when you know which key should have signed: without it the
  check confirms the attestation is internally consistent, which any
  key's holder could arrange.

## Value

`cpsatst()` a list of class `bricklayer_attestation` with the character
fields `digest`, `scheme`, `public` (hex), `context`, `prehash`, `note`
and `signed_utc` (ISO 8601 UTC time), and `signature` (a
`bricklayer_signature` from
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)).

`cpschkatst()` a list of class `bricklayer_attestation_check` with `ok`
(logical) and `checks`, a data frame with columns `check`, `ok` and
`detail`, one row per check.

## Details

What this adds over
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md).
A bare signature leaves three things implicit – which key, which scheme,
and which bytes. A verifier who has to be told those out of band cannot
check anything they were not already given, which makes the signature a
formality. An attestation states them, so the check is
`cpschkatst(attestation, manifest)` and nothing else.

What is signed: the payload `digest`
([`mnfdgst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md)
of the manifest), `scheme`, `public`, `ctx` (hex for a raw context),
`prehash`, `note` and `signed_utc` is put in canonical form
([`mnfcanon()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md))
and its SHA-256 is signed with
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md).
Every field, the note and the time included, is therefore covered:
editing any of them breaks the signature. With an XMSS key from
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md)
the scheme is `"xmss-sha256"` and the context and pre-hash are not used
by the signature; signing uses up one of the key's one-time indices, as
every XMSS signature does.

With a shared secret (a string or raw vector) as `key` the scheme is
`"hmac"`: HMAC-SHA-256 under that secret, as `cpssign(scheme = "hmac")`.
`public` is then a key id, the hex of HMAC-SHA-256 of the string
`"public"` under the secret: it names the key, so `keyexp` can pin it,
without revealing it. The secret itself is never recorded, so checking
needs it again (`key` in `cpschkatst()`). `context` is `""` and
`prehash` `"none"`, the bytes morie's capsule signer writes. HMAC is
symmetric: anyone who can check the signature can also make one. It is
not one of the post-quantum signature schemes and carries none of their
guarantees.

The check, one row each: `attestation_complete` (every field is
present), `manifest_digest` (the manifest's digest equals the attested
one), `key_as_expected` (only when `keyexp` is given) and `signature`
(the signature verifies under the attested public key; for `"hmac"`,
under `key`, whose key id must equal `public`). `ok` is `TRUE` when
every row passes.

What it does NOT establish. That the public key belongs to whoever you
think it does: an attestation is only as good as the channel the key
arrived on, which is why `keyexp` exists. And that the manifest is true
– only that it has not changed since it was signed.
[`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md)
is for the other question. No chain seal is recorded; to attest a run
history, sign
[`chnseal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chn.md)
directly.

Errors: `man` not a list; `key` not from
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
or
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md)
and not a non-empty string or raw vector; an invalid `prehash` or `ctx`
(from
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)),
or either given with an HMAC key; `attestation` not from `cpsatst()`. A
signature that fails to verify is a failed row, not an error.

## See also

[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md),
[`mnfdgst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md),
[`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md),
[`chnseal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chn.md).

## Examples

``` r
m <- mkmnf(list(dataset = "otis", rows = 1200L),
  env = FALSE
)
key <- fipskg("ML-DSA-65")
att <- cpsatst(m, key, note = "counts as published")
att
#> ── Capsule attestation ───────────────────────────────────────────
#>   scheme      ML-DSA-65
#>   digest      efa1b7387f225380245de0b5170999e87ad4044f3e8fd2ef6a6bfbc2bd0a9c90
#>   context     <none>
#>   prehash     none
#>   note        counts as published
#>   signed      2026-10-21T14:05:17Z
#>   public key  bd382543d52fbf167ea57f52a1a2c37a... (1952 bytes)
#> ──────────────────────────────────────────────────────────────────

# a verifier needs the attestation and the manifest, nothing else
res <- cpschkatst(att, m)
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
cpschkatst(att, m2)$ok
#> [1] FALSE

# and so does presenting a different key
cpschkatst(att, m,
  keyexp = fipskg("ML-DSA-65")$public
)$ok
#> [1] FALSE

# the note is signed too: editing it breaks the signature row
forged <- att
forged$note <- "counts corrected"
cpschkatst(forged, m)$checks[, c("check", "ok")]
#>                  check    ok
#> 1 attestation_complete  TRUE
#> 2      manifest_digest  TRUE
#> 3            signature FALSE

# a context string and a pre-hash
att2 <- cpsatst(m, key, ctx = "release 2026-10", prehash = "sha512")
cpschkatst(att2, m, keyexp = key)$ok
#> [1] TRUE

# a shared secret signs with HMAC; `public` is its key id, not the secret
att3 <- cpsatst(m, "shared-secret")
att3$public
#> [1] "4e289ef69cbe6f4c0d7de16c0801ad1155aba1598f2f4b25cddb46880caacd60"
cpschkatst(att3, m, key = "shared-secret", keyexp = att3$public)$ok
#> [1] TRUE
cpschkatst(att3, m, key = "another-secret")$checks[, c("check", "ok", "detail")]
#>                  check    ok
#> 1 attestation_complete  TRUE
#> 2      manifest_digest  TRUE
#> 3            signature FALSE
#>                                                             detail
#> 1                                                                 
#> 2 efa1b7387f225380245de0b5170999e87ad4044f3e8fd2ef6a6bfbc2bd0a9c90
#> 3               the key given is not the key the attestation names

# a key that is not a signing key is refused
try(cpsatst(m, 42))
#> Error : `key` must come from fipskg() or pqckg(), or be a shared secret (a string or raw vector) for hmac
```
