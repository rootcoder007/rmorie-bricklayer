# Sign a capsule manifest

Authenticates `message` – normally a manifest digest, or the whole
manifest text – so a verifier can tell that it came from the holder of
the key and has not been altered since.

## Usage

``` r
capsule_sign(
  message,
  key,
  scheme = NULL,
  context = NULL,
  deterministic = FALSE,
  prehash = "none"
)
```

## Arguments

- message:

  Length-1 character vector (or raw vector) to sign.

- key:

  A shared secret (character/raw) for `"hmac"`, a
  `bricklayer_signing_key` from
  [`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
  for `"xmss"`, or a `bricklayer_fips_key` from
  [`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
  for a standardised scheme (in which case `scheme` is taken from the
  key and ignored).

- scheme:

  `"xmss"` (post-quantum, asymmetric) or `"hmac"` (symmetric). Inferred
  from `key` when not given.

- context:

  Optional context string (character or raw, at most 255 bytes) for the
  standardised schemes, and ignored by the others. FIPS 204 and FIPS 205
  both bind it into the message encoding, so a signature made under one
  context does not verify under another – which is how the same key is
  safely used for two purposes.

- deterministic:

  For the standardised schemes, use the deterministic variant rather
  than drawing fresh randomness per signature. The signature then
  depends only on the key, message and context, which is what the
  standards' test vectors rely on.

- prehash:

  For the standardised schemes, sign a digest of the message rather than
  the message itself – HashML-DSA (FIPS 204 section 5.4) or HashSLH-DSA
  (FIPS 205 section 10.2.2). One of `"none"` (the default, the pure
  variants), `"sha256"`, `"sha512"`, `"shake128"` or `"shake256"`. The
  identifier of the pre-hash is bound into the signature, so a
  pre-hashed signature is never interchangeable with a pure one over the
  same digest.

## Value

A list of class `bricklayer_signature`: `scheme`, `signature`, and for
XMSS also `auth`, `index`, `root`, `height`, `key_state`, `randomizer`
(the per-signature `R` of RFC 8391, which a verifier needs and which
therefore travels with the signature) and `wire` – the signature in the
RFC's own byte order, `index || R || WOTS || auth`, hex-encoded. `wire`
is byte-identical to what the XMSS reference implementation produces
from the same key material, so it can be handed to another
implementation as bytes.

## Details

With `scheme = "hmac"` the `key` is a shared secret string and the
result is an HMAC-SHA-256 tag. Symmetric, so anyone who can verify can
also sign.

With `scheme = "xmss"` the `key` is a
[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
object and the result is a post-quantum one-time signature under the
key's Merkle root. Asymmetric: a verifier holding only the public root
cannot forge.

## The returned key state must be carried forward

An XMSS signature consumes a leaf. The returned object therefore carries
`key_state`, the key with `next_index` advanced, and **subsequent
signing must use that** – reusing an index breaks the scheme. Passing an
exhausted key is an error, not a silent wrap-around.

## See also

[`capsule_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_verify.md),
[`core_hmac_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_keyed_digest.md)

## Examples

``` r
# Symmetric: one shared secret.
sig <- capsule_sign("sha256:abc123", key = "shared-secret",
                    scheme = "hmac")
capsule_verify("sha256:abc123", sig, "shared-secret")
#> [1] TRUE
capsule_verify("sha256:TAMPERED", sig, "shared-secret")
#> [1] FALSE

# Post-quantum: the verifier needs only the public root.
key <- pqc_keygen(height = 2)
s1 <- capsule_sign("manifest-1", key)
capsule_verify("manifest-1", s1, signing_public_key(key))
#> [1] TRUE

# Carry the advanced key state forward for the next signature.
key <- s1$key_state
key$next_index
#> [1] 1
s2 <- capsule_sign("manifest-2", key)
capsule_verify("manifest-2", s2, signing_public_key(key))
#> [1] TRUE

# A signature does not transfer to another message.
capsule_verify("manifest-1", s2, signing_public_key(key))
#> [1] FALSE
```
