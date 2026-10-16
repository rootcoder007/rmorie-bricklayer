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

  Character scalar, the directory the capsule lives in. For
  `capsule_bundle_verify()`, the directory to check the files in.

- manifest:

  A manifest, as from
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md).
  Required by `capsule_bundle()`; optional for
  `capsule_bundle_verify()`, where it adds a check that the manifest
  still has the bundled digest.

- key:

  A signing key from
  [`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
  or
  [`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md).

- files:

  Character vector of paths relative to `dir`. Defaults to every regular
  file in `dir` (recursively, dot-files included), excluding the bundle
  itself.

- context, prehash, note:

  As in
  [`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md).

- path:

  Character scalar. For `capsule_bundle()`, where to write the bundle;
  defaults to `capsule_bundle.json` inside `dir` (an existing file is
  overwritten). For `capsule_bundle_read()`, the bundle file to read.

- bundle:

  A bundle read back with `capsule_bundle_read()`, or the path to one.

- key_expected:

  Optional public key hex the bundle's attestation must carry. Supply it
  when you know which key should have signed: without it the check
  confirms the bundle is internally consistent, which any key's holder
  could arrange.

## Value

`capsule_bundle()`: the bundle, invisibly, a list of class
`bricklayer_bundle` with `files` (a list of `path`, `sha256`,
`size_bytes`), `manifest_digest`, `bundled_utc` and `attestation` (from
[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)),
and the path it was written to as attribute `"path"`.
`capsule_bundle_read()`: the same structure read from the file.
`capsule_bundle_verify()`: a list of class `bricklayer_bundle_check`
with `ok` (logical) and `checks` (a data frame of `check`, logical `ok`
and `detail`: one `file:PATH` row per listed file, `no_unlisted_files`,
the `attestation:` rows and, with a manifest, `manifest_digest`).

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

How it is built. Each file is hashed with SHA-256
([`sha256_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256_file.md));
the payload is the list of `path`, `sha256` and `size_bytes`, the
manifest's
[`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md)
and the UTC time;
[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)
signs a manifest whose `meta` is that payload, and the bundle (payload
plus attestation) is written as pretty JSON with doubles at 17 digits.
With `files = NULL` every regular file under `dir` is hashed,
recursively and including dot-files (a `.Rprofile` dropped into a
capsule runs code), except the bundle file itself. A progress bar is
shown when `options(morie.progress)` allows it.

How it is checked. `capsule_bundle_verify()` re-hashes every listed file
(a path that is absolute or climbs out of `dir` fails its row), reports
every file on disk the bundle does not list (the bundle's own file
excepted), checks the attestation with
[`capsule_check_attestation()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)
(signature, digest, and `key_expected` when given), and, when `manifest`
is given, compares its digest with the bundled one. Every check is a row
of `checks`; `ok` is `TRUE` only when all pass. A failed check is a row,
not an error.

Errors: `dir` missing or not a directory; no files to bundle, or a named
file not in `dir`; a key
[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)
cannot sign with; `capsule_bundle_read()` given a file that is not a
bundle; `capsule_bundle_verify()` given something other than a bundle or
a path. Reading a bundle whose signature records a stateful key's state
warns (see
[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)).

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
res <- capsule_bundle_verify(attr(b, "path"), dir, manifest = m)
res$ok
#> [1] FALSE
res$checks[!res$checks$ok, c("check", "detail")]
#>           check
#> 1 file:data.csv
#>                                                                                                                                            detail
#> 1 expected 95aecaa7399a39092c9e716ce1e18bb1c606c82f9503d679ac55c82988f6c38e, got 5140963bf019d514b126f382bc4c324b98109d2fd252c1858b60c821cff88c37

# read back, and checked against the key you expected to have signed
b2 <- capsule_bundle_read(attr(b, "path"))
b2
#> ── Capsule bundle ────────────────────────────────────────────────
#>   files            1
#>   manifest digest  8995763848bcf59327ed818c561d5428a958cd82f86a60c91e4167960781a579
#>   bundled          2026-10-16T02:39:58Z
#>   scheme           ML-DSA-44
#> ──────────────────────────────────────────────────────────────────
capsule_bundle_verify(b2, dir, key_expected = "00ff")$ok
#> [1] FALSE

# a file added beside the bundle is reported too
writeLines("x", file.path(dir, "extra.txt"))
capsule_bundle_verify(b2, dir)$checks[, c("check", "ok")]
#>                              check    ok
#> 1                    file:data.csv FALSE
#> 2                no_unlisted_files FALSE
#> 3 attestation:attestation_complete  TRUE
#> 4      attestation:manifest_digest  TRUE
#> 5            attestation:signature  TRUE

# a directory that does not exist
try(capsule_bundle(file.path(tempdir(), "no-such-capsule"), m, key))
#> Error : `dir` does not exist: /tmp/RtmpmyxrsO/no-such-capsule
unlink(dir, recursive = TRUE)
```
