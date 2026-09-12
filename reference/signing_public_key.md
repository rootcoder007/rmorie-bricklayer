# Public half of a signing key

Strips the secret seed, leaving only what a verifier needs. Publish
this; never the object returned by
[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md).

## Usage

``` r
signing_public_key(key)
```

## Arguments

- key:

  A `bricklayer_signing_key` from
  [`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md).

## Value

A list of class `bricklayer_public_key`: `root`, `pub_seed`, `height`,
`scheme`.

## Examples

``` r
key <- pqc_keygen(height = 2)
pub <- signing_public_key(key)

# The secret seed is gone.
is.null(pub$sk_seed)
#> [1] TRUE

# And verification works from the public half alone.
sig <- capsule_sign("manifest-digest", key)
capsule_verify("manifest-digest", sig, pub)
#> [1] TRUE
```
