# Old names kept for rmoriedata 0.3.x

rmoriedata 0.3.x on CRAN calls eleven functions by their 0.5.x names.
These wrappers keep that release installing and checking against
rmoriebricklayer 1.0.0. Each one forwards to the function named in its
body, translating the old argument names:
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md),
[`cpsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsvrf.md),
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md),
[`signpubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/signpubkey.md),
[`csha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md),
[`cmn()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cstat.md),
[`sha256file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256file.md),
[`tojs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tojs.md),
[`fromjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fromjs.md),
[`blfetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blfetch.md)
and
[`wbsnpurl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsnpurl.md).
New code should call the new names directly; these wrappers go when
every released rmoriedata uses them.

## Usage

``` r
capsule_sign(
  message,
  key,
  scheme = NULL,
  context = NULL,
  deterministic = FALSE,
  prehash = "none",
  masked = getOption("rmoriebricklayer.masked", TRUE)
)

capsule_verify(message, signature, key, context = NULL, prehash = NULL)

pqc_keygen(height = 10L, sk_seed = NULL, pub_seed = NULL, sk_prf = NULL)

signing_public_key(key)

core_sha256(x)

core_mean(x)

sha256_file(path)

bricklayer_json_to_json(x, ...)

bricklayer_json_from_json(txt, ...)

bricklayer_fetch(url, dest, wayback = "", timeout = 120L)

wayback_snapshot_url(url, timestamp = NULL)
```

## Arguments

- message, signature:

  `msg` and `sig` of the new name.

- key, scheme, prehash, masked:

  As in the new name.

- context:

  `ctx` of the new name.

- deterministic:

  `determ` of
  [`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md).

- height:

  `height` of
  [`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md).

- sk_seed:

  `skseed` of
  [`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md).

- pub_seed:

  `pubseed` of
  [`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md).

- sk_prf:

  `skprf` of
  [`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md).

- x:

  `x` of
  [`csha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md),
  [`cmn()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cstat.md)
  or
  [`tojs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tojs.md).

- path:

  `path` of
  [`sha256file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256file.md).

- ...:

  Passed through to
  [`tojs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tojs.md)
  or
  [`fromjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fromjs.md).

- txt:

  `txt` of
  [`fromjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fromjs.md).

- url, dest:

  As in
  [`blfetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blfetch.md)
  and
  [`wbsnpurl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsnpurl.md).

- wayback, timeout:

  `wb` and `tmout` of
  [`blfetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blfetch.md).

- timestamp:

  `ts` of
  [`wbsnpurl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsnpurl.md).

## Value

What the forwarded function returns.

## Examples

``` r
k <- pqc_keygen(height = 2)
s <- capsule_sign(core_sha256("manifest"), k)
capsule_verify(core_sha256("manifest"), s, signing_public_key(k))
#> [1] TRUE
```
