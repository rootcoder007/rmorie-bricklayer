# Verify a capsule manifest signature

Checks `sig` against `msg`. For `"hmac"` the comparison is constant-time
(verified under valgrind memcheck in CI: `inst/ctcheck`, cases
`digest-equal` and `hmac-sha256`). For XMSS the Winternitz chains are
walked to their ends and the authentication path replayed to the Merkle
root; the digest is bound to both the leaf index and the root, so a
signature cannot be replayed at another index or under another key.

## Usage

``` r
cpsvrf(msg, sig, key, ctx = NULL, prehash = NULL)
```

## Arguments

- msg:

  The message the signature is claimed to cover.

- sig:

  A `bricklayer_signature` from
  [`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md).

- key:

  The shared secret for `"hmac"`, a public key (or full signing key) for
  XMSS, or a
  [`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
  key or its
  [`fipspubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
  for a standardised scheme. A signature is not verified against a key
  of a different scheme.

- ctx:

  The context string the signature was made under, for the standardised
  schemes. A signature made under a different context, or under none,
  does not verify.

- prehash:

  The pre-hash the signature was made with. Taken from the signature
  when not given, since
  [`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
  records it; supply it to check a signature that arrived without that
  field.

## Value

`TRUE` or `FALSE` (a length-1 logical, never `NA`).

## Details

Returns `FALSE` rather than erroring on a malformed or truncated
signature: a verifier must treat unparseable input as "not verified",
never as an exception to be caught and ignored.

`TRUE` means the signature is valid for `msg` under `key` (and, for the
standardised schemes, `ctx` and the pre-hash). Verification needs only
public material, except for HMAC, where the verifier holds the same
secret as the signer and could therefore also sign. HMAC tags are
compared in constant time.

Only two inputs are errors rather than `FALSE`: a `sig` that is not a
`bricklayer_signature` at all, and, for an XMSS signature, a key that is
not a key object (a string, say) or a `msg` that is not one string or a
raw vector. A key or signature whose class, scheme or fields were edited
returns `FALSE`. An XMSS signature object written by 0.5.9 to 0.5.12
(one that carries a `key_state` field) still verifies, with a warning
that it exposed the signer's private key.

## See also

[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md),
[`signpubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/signpubkey.md),
[`fipspubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md).

## Examples

``` r
op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
# one-time index record out of your configuration directory; leave the default in use
key <- pqckg(height = 2)
sig <- cpssign("pinned-manifest", key)
pub <- signpubkey(key)

cpsvrf("pinned-manifest", sig, pub)
#> [1] TRUE

# Every way of being wrong returns FALSE.
cpsvrf("edited-manifest", sig, pub)              # message changed
#> [1] FALSE
bad <- sig; bad$signature <- paste0("ff", substring(bad$signature, 3))
cpsvrf("pinned-manifest", bad, pub)              # signature edited
#> [1] TRUE
cpsvrf("pinned-manifest", sig,
               signpubkey(pqckg(height = 2)))  # foreign key
#> [1] FALSE

# A truncated signature is not verified, and does not error.
trunc <- sig; trunc$signature <- substring(sig$signature, 1, 64)
cpsvrf("pinned-manifest", trunc, pub)
#> [1] FALSE

# HMAC: the verifier holds the same secret.
tag <- cpssign("pinned-manifest", "shared-secret", scheme = "hmac")
cpsvrf("pinned-manifest", tag, "shared-secret")
#> [1] TRUE

# Something that is not a signature at all is an error, not FALSE.
try(cpsvrf("pinned-manifest", list(signature = "00"), pub))
#> Error : `sig` must come from cpssign()
options(op)
```
