# Derive a key from a passphrase

Turns a passphrase that a person can remember into a fixed-length key
(32 bytes by default) for signing or encryption, in a way that makes
guessing the passphrase slow. The same passphrase, salt and iteration
count always give the same key, so the key need not be stored: it can be
derived again when needed.

## Usage

``` r
drvkey(pass, salt, iter = 100000L, length = 32L)
```

## Arguments

- pass:

  Passphrase, as a length-1 character or raw vector.

- salt:

  Unique, non-secret salt (length-1 character or raw). Use
  [`rndbytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rndbytes.md)
  to make one, and store it beside the key.

- iter:

  Whole number, default 100000 (minimum 1): the PBKDF2 iteration count.
  Verification must use the same value.

- length:

  Whole number from 1 to 1024, default 32: the derived key length in
  bytes.

## Value

A length-1 character vector: the key as lowercase hex (`2 * length`
characters).

## Details

PBKDF2-HMAC-SHA256 (RFC 8018): stretches a passphrase into a key of full
width by iterating a keyed hash, so guessing the passphrase costs `iter`
times more than a single hash would.

The `salt` must be UNIQUE per key and need not be secret. Its job is to
make precomputation useless: without one, a single table of common
passphrases attacks every key at once.

`iter` is the cost knob. The default 100,000 is a reasonable 2020s floor
for an interactive use; raise it for anything valuable, and record the
value you used, since verification must repeat it exactly.

PBKDF2 resists brute force by ITERATION only, not by memory. Where a
memory-hard function is available ( `argon2` in sodium, `bcrypt_pbkdf`
in openssl) prefer it for passwords a human chose. PBKDF2 is here
because it needs nothing beyond the bundled SHA-256, so it works
wherever this package works.

The derivation runs in compiled code; at the default 100,000 iterations
it takes a fraction of a second, and a busy indicator is shown in an
interactive session. Errors: a passphrase or salt that is not a single
non-missing string or a raw vector; `iter` below 1; `length` outside 1
to 1024.

## References

Moriarty K, Kaliski B, Rusch A (2017). PKCS \#5: Password-Based
Cryptography Specification Version 2.1. RFC 8018.
[doi:10.17487/RFC8018](https://doi.org/10.17487/RFC8018)

## See also

[`rndbytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rndbytes.md),
[`chmac()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/keyeddgst.md),
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)

## Examples

``` r
# The published PBKDF2-HMAC-SHA256 vector: "password", "salt", 1 round.
drvkey("password", "salt", iter = 1)
#> [1] "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"

# Deterministic, so verification can repeat it.
identical(drvkey("pw", "s", 1000), drvkey("pw", "s", 1000))
#> [1] TRUE

# The salt, the passphrase and the iteration count all change the key.
drvkey("pw", "salt-a", 1000) == drvkey("pw", "salt-b", 1000)
#> [1] FALSE
drvkey("pw", "s", 1000) == drvkey("pw", "s", 2000)
#> [1] FALSE

# Use it to sign a manifest from a passphrase rather than raw bytes.
salt <- paste(format(rndbytes(16)), collapse = "")
key <- drvkey("purple otter lantern", salt)
sig <- cpssign("manifest-digest", key, scheme = "hmac")
cpsvrf("manifest-digest", sig, key)
#> [1] TRUE

# A longer key is a prefix-consistent extension of a shorter one.
identical(
  substring(drvkey("pw", "s", 10, length = 64), 1, 64),
  drvkey("pw", "s", 10, length = 32)
)
#> [1] TRUE

# a vector of passphrases is refused
try(drvkey(c("a", "b"), "salt"))
#> Error : `pass` must be a length-1 character vector or raw vector
```
