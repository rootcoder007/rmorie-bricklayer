# Verify a capsule manifest signature

Checks `signature` against `message`. For `"hmac"` the comparison is
constant-time. For XMSS the Winternitz chains are walked to their ends
and the authentication path replayed to the Merkle root; the digest is
bound to both the leaf index and the root, so a signature cannot be
replayed at another index or under another key.

## Usage

``` r
capsule_verify(message, signature, key)
```

## Arguments

- message:

  The message the signature is claimed to cover.

- signature:

  A `bricklayer_signature` from
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md).

- key:

  The shared secret for `"hmac"`, a public key (or full signing key) for
  XMSS, or an
  [`oqs_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/oqs_keygen.md)
  key or its
  [`oqs_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/oqs_keygen.md)
  for a standardised scheme. A signature is not verified against a key
  of a different scheme.

## Value

A length-1 logical.

## Details

Returns `FALSE` rather than erroring on a malformed or truncated
signature: a verifier must treat unparseable input as "not verified",
never as an exception to be caught and ignored.

## Examples

``` r
key <- pqc_keygen(height = 2)
sig <- capsule_sign("pinned-manifest", key)
pub <- signing_public_key(key)

capsule_verify("pinned-manifest", sig, pub)
#> [1] TRUE

# Every way of being wrong returns FALSE.
capsule_verify("edited-manifest", sig, pub)              # message changed
#> [1] FALSE
bad <- sig; bad$signature <- paste0("ff", substring(bad$signature, 3))
capsule_verify("pinned-manifest", bad, pub)              # signature edited
#> [1] FALSE
capsule_verify("pinned-manifest", sig,
               signing_public_key(pqc_keygen(height = 2)))  # foreign key
#> [1] FALSE

# A truncated signature is not verified, and does not error.
trunc <- sig; trunc$signature <- substring(sig$signature, 1, 64)
capsule_verify("pinned-manifest", trunc, pub)
#> [1] FALSE
```
