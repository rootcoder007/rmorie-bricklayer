# Bundle a capsule into one signed artifact

Records a digest of every file named, the manifest's canonical digest,
and an attestation covering both, as a single JSON file.
`capsule_bundle_verify()` re-hashes the files on disk and checks
everything against it.

## Usage

``` r
capsule_bundle(
  dir,
  manifest,
  key,
  files = NULL,
  context = NULL,
  prehash = "none",
  note = NULL,
  path = NULL
)

capsule_bundle_read(path)

capsule_bundle_verify(bundle, dir, manifest = NULL, key_expected = NULL)
```

## Arguments

- dir:

  Directory the capsule lives in.

- manifest:

  A manifest, as from
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md).

- key:

  A signing key from
  [`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
  or
  [`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md).

- files:

  Paths relative to `dir`. Defaults to every regular file in `dir`,
  excluding the bundle itself.

- context, prehash, note:

  As in
  [`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md).

- path:

  Where to write the bundle. Defaults to `capsule_bundle.json` inside
  `dir`.

- bundle:

  A bundle read back with `capsule_bundle_read()`, or the path to one.

- key_expected:

  Optional public key hex the bundle's attestation must carry. Supply it
  when you know which key should have signed: without it the check
  confirms the bundle is internally consistent, which any key's holder
  could arrange.

## Value

`capsule_bundle()` the bundle, invisibly, with the path it was written
to as an attribute; `capsule_bundle_read()` the bundle;
`capsule_bundle_verify()` a list with `ok` and a `checks` data frame.

## Details

The file digests are inside the signed payload, not alongside it. That
is the whole point: a list of hashes that is not itself signed can be
rewritten to match whatever the files now say, and a recipient who
re-hashes the files and compares them to that list learns only that the
list is consistent with itself.

What it establishes: the named files have not changed since signing, the
manifest has not changed, and both were signed together by the holder of
that key. What it does not: that the key belongs to anyone in
particular, or that the manifest's claims are true.

## See also

[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md),
[`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md),
[`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md).

## Examples

``` r
dir <- tempfile()
dir.create(dir)
write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"),
          row.names = FALSE)
m <- make_manifest(list(dataset = "demo"), environment = FALSE)
key <- fips_keygen("ML-DSA-44")

b <- capsule_bundle(dir, m, key, note = "as published")
capsule_bundle_verify(attr(b, "path"), dir, manifest = m)$ok
#> [1] TRUE

# touch a byte of the data and the bundle no longer holds
write.csv(data.frame(x = 1:4), file.path(dir, "data.csv"),
          row.names = FALSE)
capsule_bundle_verify(attr(b, "path"), dir, manifest = m)$ok
#> [1] FALSE
unlink(dir, recursive = TRUE)
```
