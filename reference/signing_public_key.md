# Public half of a signing key

Strips the secret seeds from an XMSS signing key, leaving only what a
verifier needs. Publish this, or hand it to whoever must check your
signatures; never the object returned by
[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md),
which lets its holder sign in your name. The public key does not change
as the signing key is used, so it is made once.

## Usage

``` r
signing_public_key(key)
```

## Arguments

- key:

  A `bricklayer_signing_key` from
  [`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md).

## Value

A list of class `bricklayer_public_key`: `root` and `pub_seed` (64 hex
characters each), `height` and `scheme`.

## Details

The public key is the Merkle root and the public seed that masks the
hashes (RFC 8391's `root || SEED`), with the tree height and scheme
name. `sk_seed`, `sk_prf` and `next_index` are dropped. For a
standardised key from
[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
use
[`fips_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
instead: this function refuses any key that is not a
`bricklayer_signing_key` (`"key must come from pqc_keygen()"`).

## See also

[`capsule_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_verify.md),
which takes it.

## Examples

``` r
op <- options(rmoriebricklayer.xmss_index_file = tempfile())  # keep this example's
# one-time index record out of your configuration directory; leave the default in use
key <- pqc_keygen(height = 2)
pub <- signing_public_key(key)

# The secret seed is gone.
is.null(pub$sk_seed)
#> [1] TRUE

# And verification works from the public half alone.
sig <- capsule_sign("manifest-digest", key)
capsule_verify("manifest-digest", sig, pub)
#> [1] TRUE

# A standardised key has its own function.
try(signing_public_key(fips_keygen("ML-DSA-44")))
#> Error : `key` must come from pqc_keygen()
options(op)
```
