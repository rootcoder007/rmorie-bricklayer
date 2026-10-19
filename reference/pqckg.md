# Generate a post-quantum signing key for capsule provenance

Builds an XMSS key pair: a Merkle tree over `2^height` Winternitz
one-time keys, all derived from two 32-byte seeds. Security rests on
SHA-256 alone – no lattice assumption, no elliptic curve, nothing Shor's
algorithm breaks. The key signs a fixed number of messages, `2^height`,
and must be carried forward after each signature (see
[`xmssadv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/xmssadv.md));
for a key with no such state use
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md).

## Usage

``` r
pqckg(height = 10L, skseed = NULL, pubseed = NULL, skprf = NULL)
```

## Arguments

- height:

  Tree height, 1 to 16 (default 10, i.e. 1024 signatures).

- skseed, pubseed, skprf:

  64-character hex seeds (32 bytes each) – the three secrets RFC 8391's
  private key carries. `skseed` derives the WOTS+ chains, `pubseed`
  masks the hashes, and `skprf` keys the per-signature randomiser. Omit
  them and they are drawn from the operating system's CSPRNG via
  [`rndbytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rndbytes.md),
  which fails rather than falling back to R's reproducible generator.
  Supply them ONLY to reproduce a key deterministically in a test – a
  seed you can guess is a key you can forge.

## Value

A list of class `bricklayer_signing_key`: `root` (the public
verification value, 64 hex characters), `pubseed`, `skseed` (SECRET) and
`skprf` (SECRET), each 64 hex characters, `height` (an integer),
`next_index` (the next unused leaf, 0 for a new key), `capacity`
(`2^height`, the number of signatures), and `scheme` (`"xmss-sha256"`).

## Details

Key generation walks all `2^height` leaves, so cost doubles with each
unit of height. The default 10 gives 1024 signatures and takes a few
seconds; heights above about 14 are slow enough to be worth avoiding
unless the key really must last that long. A spinner on stderr shows the
work after 0.75 s when a person is watching (see
[`blprog()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blprog.md)),
and Ctrl-C stops it.

The construction is single-tree XMSS with SHA-256, n = 32 and Winternitz
parameter 16 (RFC 8391; at heights 10 and 16 these are its
`XMSS-SHA2_10_256` and `XMSS-SHA2_16_256` parameter sets, and the other
heights use the same construction with a smaller or larger tree). Its
signatures are byte-identical to the XMSS reference implementation's for
the same key material.

Side effect: a key generated from fresh randomness is entered in the
package's used-index record (the file described under
[`xmssadv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/xmssadv.md)),
so that a stale copy of it can never sign an index twice on this
machine. A key built from given seeds is NOT entered, and signs only
after
[`xmssregkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/xmssadv.md)
vouches that it never has.

Refusals: a `height` that is not a whole number from 1 to 16, and a seed
that is not 64 hex characters.

## A height-`h` key signs exactly `2^h` messages

Each signature consumes one leaf, and **signing two different messages
with the same leaf index breaks the scheme outright** – between two
signatures at one index an adversary can forge a third message.
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
therefore tracks `next_index` and refuses to reuse one. Do not hand-edit
that field, and do not copy a key to two machines that sign
independently.

## Key format

A key made before the RFC 8391 conformance work carries no `skprf` and
cannot sign;
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
raises rather than producing a signature no other implementation could
read. Generate a new one.

## Security

The implementation is hand-written. Its standardised schemes are checked
byte for byte against OpenSSL 3.5 and NIST known-answer vectors in the
test suite. Side channels are checked, not assumed: `inst/ctcheck` runs
every operation that touches a secret under valgrind memcheck with the
secret marked undefined (the ctgrind method), so a branch or a memory
address that depends on it is a reported error, and afterwards scans the
dead stack for copies of the secret. Both checks run in CI on every
change, with GCC and with Clang. Timing is also measured on x86-64 and
arm64 hardware (`inst/dudect`) and power leakage is assessed in
simulation under the value and the transition models (`inst/tvla`) for
the masked ML-KEM and ML-DSA kernels; this scheme is not masked. These
are checks of this code on those compilers; the README's security
section lists what each check does and does not cover.

## See also

[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md),
[`cpsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsvrf.md),
[`signpubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/signpubkey.md)

## Examples

``` r
op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
# one-time index record out of your configuration directory; leave the default in use
# A small key, to keep the example quick.
key <- pqckg(height = 3)
key$capacity            # 8 signatures
#> [1] 8
key$next_index          # none used yet
#> [1] 0

# The public half is what a verifier needs; it carries no secret.
pub <- signpubkey(key)
names(pub)
#> [1] "root"    "pubseed" "height"  "scheme" 

# Deterministic seeds reproduce the same key -- for tests only. A key built from given
# seeds is not entered in the used-index record (it may have signed elsewhere): it signs
# only after xmssregkey() vouches that it never has.
s1 <- paste(rep("11", 32), collapse = "")
s2 <- paste(rep("22", 32), collapse = "")
identical(pqckg(3, s1, s2)$root, pqckg(3, s1, s2)$root)
#> [1] TRUE

# The height is limited to 16 (65,536 signatures).
try(pqckg(height = 20))
#> Error : `height` must be a single integer between 1 and 16
options(op)
```
