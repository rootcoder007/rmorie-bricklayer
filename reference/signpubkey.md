# Public half of a signing key

Strips the secret seeds from an XMSS signing key, leaving only what a
verifier needs. Publish this, or hand it to whoever must check your
signatures; never the object returned by
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md),
which lets its holder sign in your name. The public key does not change
as the signing key is used, so it is made once.

## Usage

``` r
signpubkey(key)
```

## Arguments

- key:

  A `bricklayer_signing_key` from
  [`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md).

## Value

A list of class `bricklayer_public_key`: `root` and `pubseed` (64 hex
characters each), `height` and `scheme`.

## Details

The public key is the Merkle root and the public seed that masks the
hashes (RFC 8391's `root || SEED`), with the tree height and scheme
name. `skseed`, `skprf` and `next_index` are dropped. For a standardised
key from
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
use
[`fipspubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
instead: this function refuses any key that is not a
`bricklayer_signing_key` (`"key must come from pqckg()"`).

## See also

[`cpsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsvrf.md),
which takes it.

## Examples

``` r
# keep this example's
op <- options(rmoriebricklayer.xmssidxfile = tempfile())
# one-time index record out of your configuration directory; leave the
# default in use
key <- pqckg(height = 2)
pub <- signpubkey(key)

# The secret seed is gone.
is.null(pub$skseed)
#> [1] TRUE

# And verification works from the public half alone.
sig <- cpssign("manifest-digest", key)
cpsvrf("manifest-digest", sig, pub)
#> [1] TRUE

# A standardised key has its own function.
try(signpubkey(fipskg("ML-DSA-44")))
#> Error : `key` must come from pqckg()
options(op)
```
