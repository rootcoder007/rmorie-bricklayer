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

cpschkatst(attest, man, keyexp = NULL)
```

## Arguments

- man:

  A manifest, as from
  [`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md).

- key:

  A signing key from
  [`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
  (ML-DSA, SLH-DSA and the other standardised schemes) or
  [`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md)
  (XMSS).

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

The check, one row each: `attestation_complete` (every field is
present), `mnfdgst` (the manifest's digest equals the attested one),
`key_as_expected` (only when `keyexp` is given) and `signature` (the
signature verifies under the attested public key). `ok` is `TRUE` when
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
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md);
an invalid `prehash` or `ctx` (from
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md));
`attestation` not from `cpsatst()`. A signature that fails to verify is
a failed row, not an error.

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
#>   signed      2026-10-19T22:41:32Z
#>   public key  434dd2b7ccf1645a15bc55adbfb0e3c3... (1952 bytes)
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

# a key that is not a signing key is refused
try(cpsatst(m, "not-a-key"))
#> Error : `key` must come from fipskg() or pqckg()
```
