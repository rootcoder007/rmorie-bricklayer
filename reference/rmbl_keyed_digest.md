# Keyed digest and constant-time comparison (C backend)

`core_hmac_sha256()` is HMAC-SHA-256 (RFC 2104): a digest computed under
a secret key. The difference from a plain
[`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md)
is AUTHENTICATION – anyone can recompute a SHA-256 and so anyone can
forge one after editing a manifest, but only a holder of the key can
produce a matching HMAC. This is what makes
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)'s
`"hmac"` scheme meaningful.

## Usage

``` r
core_hmac_sha256(key, message)

core_digest_equal(a, b)
```

## Arguments

- key:

  Secret key, as a length-1 character vector or a raw vector. Keys
  longer than the 64-byte block are hashed down first, per RFC 2104. Use
  at least 32 bytes of real entropy; against a quantum adversary Grover
  halves the effective key strength, so a 256-bit key retains a 128-bit
  margin.

- message:

  Message to authenticate, as a length-1 character vector or a raw
  vector.

- a, b:

  Digests to compare, as length-1 character vectors.

## Value

`core_hmac_sha256()` a length-1 character vector: 64 lowercase hex
characters. `core_digest_equal()` a length-1 logical; `FALSE` when the
two differ in length.

## Details

`core_digest_equal()` compares two digests in constant time. Use it
instead of `==` whenever the comparison is against a value an attacker
supplied: a short-circuiting comparison leaks, through its own timing,
how many leading characters were correct, which is enough to recover a
tag byte by byte.

## References

Krawczyk H, Bellare M, Canetti R (1997). HMAC: Keyed-Hashing for Message
Authentication. RFC 2104.
[doi:10.17487/RFC2104](https://doi.org/10.17487/RFC2104)

## Examples

``` r
# RFC 4231 test case 2.
core_hmac_sha256("Jefe", "what do ya want for nothing?")
#> [1] "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"

# The key changes the digest, so a manifest cannot be re-signed
# without it.
core_hmac_sha256("key-a", "manifest")
#> [1] "463b8b2c47caadd6334c53e4d9492fdac6fcaca185f56229043e1a025138ceae"
core_hmac_sha256("key-b", "manifest")
#> [1] "f3ebaf1b8fad504c57fd4cf82b163e30eac6eabd31b7c41a2a6e268ec445b134"

# Raw keys and messages are accepted.
core_hmac_sha256(as.raw(rep(0x0b, 20)), "Hi There")
#> [1] "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"

# Compare tags in constant time, never with ==.
tag <- core_hmac_sha256("k", "m")
core_digest_equal(tag, core_hmac_sha256("k", "m"))
#> [1] TRUE
core_digest_equal(tag, core_hmac_sha256("k", "tampered"))
#> [1] FALSE
core_digest_equal(tag, "too-short")
#> [1] FALSE
```
