# Generate a post-quantum signing key for capsule provenance

Builds an XMSS key pair: a Merkle tree over `2^height` Winternitz
one-time keys, all derived from two 32-byte seeds. Security rests on
SHA-256 alone – no lattice assumption, no elliptic curve, nothing Shor's
algorithm breaks.

## Usage

``` r
pqc_keygen(height = 10L, sk_seed = NULL, pub_seed = NULL)
```

## Arguments

- height:

  Tree height, 1 to 16 (default 10, i.e. 1024 signatures).

- sk_seed, pub_seed:

  64-character hex seeds (32 bytes each). Omit them and seeds are drawn
  from the operating system's CSPRNG via
  [`random_bytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/random_bytes.md),
  which fails rather than falling back to R's reproducible generator.
  Supply them ONLY to reproduce a key deterministically in a test – a
  seed you can guess is a key you can forge.

## Value

A list of class `bricklayer_signing_key`: `root` (the public
verification value), `pub_seed`, `sk_seed` (SECRET), `height`,
`next_index`, `capacity`, and `scheme`.

## A height-`h` key signs exactly `2^h` messages

Each signature consumes one leaf, and **signing two different messages
with the same leaf index breaks the scheme outright** – between two
signatures at one index an adversary can forge a third message.
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
therefore tracks `next_index` and refuses to reuse one. Do not hand-edit
that field, and do not copy a key to two machines that sign
independently.

Key generation walks all `2^height` leaves, so cost doubles with each
unit of height. The default 10 gives 1024 signatures and takes a moment;
heights above about 14 are slow enough to be worth avoiding unless the
key really must last that long.

## See also

[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md),
[`capsule_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_verify.md),
[`signing_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/signing_public_key.md)

## Examples

``` r
# A small key, to keep the example quick.
key <- pqc_keygen(height = 3)
key$capacity            # 8 signatures
#> [1] 8
key$next_index          # none used yet
#> [1] 0

# The public half is what a verifier needs; it carries no secret.
pub <- signing_public_key(key)
names(pub)
#> [1] "root"     "pub_seed" "height"   "scheme"  

# Deterministic seeds reproduce the same key -- for tests only.
s1 <- paste(rep("11", 32), collapse = "")
s2 <- paste(rep("22", 32), collapse = "")
identical(pqc_keygen(3, s1, s2)$root, pqc_keygen(3, s1, s2)$root)
#> [1] TRUE
```
