# Pin and sign every capsule under a folder

Seals each capsule (a folder holding `data_provenance.json`) under
`path`, so that a program in any language only has to write the data
file and a plain provenance naming it
(`{"resource": {"filename": "data.csv"}}`): on its first run the
provenance is pinned to the data file's bytes as
[`cpsrfrsh`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsrfrsh.md)
pins it (`resource$sha256`, `size_bytes`, `retrieved_utc`, the row count
when one is recorded), then
[`cpsbndl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md)
signs every file of the capsule into `capsule_bundle.json`, over its
`manifest.json` when it has one. `rmbl sign` calls it and then verifies
([`cpschk`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpschk.md)).

## Usage

``` r
cpsseal(path = ".", key, overwrite = FALSE, glob = "")
```

## Arguments

- path:

  Character scalar, the folder searched recursively.

- key:

  The signing key, as
  [`cpsbndl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md)
  takes it: a shared secret (a string or raw vector) for an `"hmac"`
  bundle, or a key from
  [`fipskg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
  or
  [`fipskey`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskey.md),
  or an XMSS key from
  [`pqckg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md),
  which signs one capsule after another at consecutive indices (each
  reserved as
  [`cpssign`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
  reserves it).

- overwrite:

  Logical: sign a capsule that already has a bundle again.

- glob:

  Character scalar: only the provenance files whose path matches this
  glob (`*` also matches `/`), or `""`.

## Value

A data frame, one row per capsule: `capsule`, `pinned` (whether the
provenance was pinned now), `files` (the number signed) and `public`
(the HMAC key id or the public key; never the secret).

## Details

A provenance already pinned (one with `resource$sha256`) is left as it
is. Side effects: writes `data_provenance.json` (first run) and
`capsule_bundle.json` in each capsule. Errors, before anything is
written: no provenance under `path`; a capsule that already has a
bundle, unless `overwrite`; then, per capsule, a `resource$filename`
that is not a plain relative path to a file in the capsule, and the
refusals of
[`cpsbndl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md)
(a key it cannot sign with).

## See also

[`cpsbndl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md),
[`cpschk`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpschk.md),
[`blcli`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blcli.md)
(`rmbl sign`).

## Examples

``` r
root <- tempfile("capsules-")
d <- file.path(root, "one")
dir.create(d, recursive = TRUE)
utils::write.csv(data.frame(x = 1:3), file.path(d, "data.csv"),
                 row.names = FALSE)
writeLines('{"resource": {"filename": "data.csv"}}',
           file.path(d, "data_provenance.json"))
s <- cpsseal(root, "a shared secret")
s
#>                                     capsule pinned files
#> 1 /tmp/RtmpAwgnfi/capsules-21d92c3386c4/one   TRUE     2
#>                                                             public
#> 1 2b23046c08926e30017362694e61c9f76f64815699749bede71734e74c84f65e
cpschk(root, key = "a shared secret", fp = FALSE)$status
#> [1] "ok"

# a second run needs overwrite, and a post-quantum key signs too
try(cpsseal(root, "a shared secret"))
#> Error : cpsseal: capsule_bundle.json already exists in /tmp/RtmpAwgnfi/capsules-21d92c3386c4/one; pass overwrite = TRUE (rmbl sign --overwrite) to sign again
cpsseal(root, fipskg("ML-DSA-44"), overwrite = TRUE)$pinned
#> [1] FALSE
```
