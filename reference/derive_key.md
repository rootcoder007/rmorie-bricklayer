# Derive a key from a passphrase

PBKDF2-HMAC-SHA256 (RFC 8018): stretches a passphrase into a key of full
width by iterating a keyed hash, so guessing the passphrase costs
`iterations` times more than a single hash would.

## Usage

``` r
derive_key(passphrase, salt, iterations = 100000L, length = 32L)
```

## Arguments

- passphrase:

  Passphrase, as a length-1 character or raw vector.

- salt:

  Unique, non-secret salt (length-1 character or raw). Use
  [`random_bytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/random_bytes.md)
  to make one, and store it beside the key.

- iterations:

  Iteration count (default 100000, minimum 1).

- length:

  Derived key length in bytes (default 32).

## Value

A length-1 character vector: the key as lowercase hex.

## Details

The `salt` must be UNIQUE per key and need not be secret. Its job is to
make precomputation useless: without one, a single table of common
passphrases attacks every key at once.

`iterations` is the cost knob. The default 100,000 is a reasonable 2020s
floor for an interactive use; raise it for anything valuable, and record
the value you used, since verification must repeat it exactly.

PBKDF2 resists brute force by ITERATION only, not by memory. Where a
memory-hard function is available ( `argon2` in sodium, `bcrypt_pbkdf`
in openssl) prefer it for passwords a human chose. PBKDF2 is here
because it needs nothing beyond the bundled SHA-256, so it works
wherever this package works.

## References

Moriarty K, Kaliski B, Rusch A (2017). PKCS \#5: Password-Based
Cryptography Specification Version 2.1. RFC 8018.
[doi:10.17487/RFC8018](https://doi.org/10.17487/RFC8018)

## See also

[`random_bytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/random_bytes.md),
[`core_hmac_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_keyed_digest.md),
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)

## Examples

``` r
# The published PBKDF2-HMAC-SHA256 vector: "password", "salt", 1 round.
derive_key("password", "salt", iterations = 1)
#> [1] "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"

# Deterministic, so verification can repeat it.
identical(derive_key("pw", "s", 1000), derive_key("pw", "s", 1000))
#> [1] TRUE

# The salt, the passphrase and the iteration count all change the key.
derive_key("pw", "salt-a", 1000) == derive_key("pw", "salt-b", 1000)
#> [1] FALSE
derive_key("pw", "s", 1000) == derive_key("pw", "s", 2000)
#> [1] FALSE

# Use it to sign a manifest from a passphrase rather than raw bytes.
salt <- paste(format(random_bytes(16)), collapse = "")
key <- derive_key("correct horse battery staple", salt)
sig <- capsule_sign("manifest-digest", key, scheme = "hmac")
capsule_verify("manifest-digest", sig, key)
#> [1] TRUE

# A longer key is a prefix-consistent extension of a shorter one.
identical(substring(derive_key("pw", "s", 10, length = 64), 1, 64),
          derive_key("pw", "s", 10, length = 32))
#> [1] TRUE
```
