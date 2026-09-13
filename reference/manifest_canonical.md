# The canonical serialisation of a manifest, and its digest

`manifest_canonical()` renders a manifest as one line of JSON with every
object's keys in sorted order and every number at full double precision.
`manifest_digest()` is the SHA-256 of those bytes.

## Usage

``` r
manifest_canonical(manifest)

manifest_digest(manifest)
```

## Arguments

- manifest:

  A manifest, as from
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md).

## Value

`manifest_canonical()` a length-1 character vector; `manifest_digest()`
64 hex characters.

## Details

Why this is needed. Two manifests that record the same thing can easily
differ as bytes: R lists keep insertion order, so building `meta` before
`results` or the other way round gives different JSON, and a signature
over the JSON would then depend on the order a script happened to
assemble the list. Sorting the keys removes that. The precision matters
for a different reason: the default JSON writer emits four significant
digits, which is right for a human-readable report and wrong for a
record something will later be checked against, because `1/3` comes back
as `0.3333` and no recomputation can match it.

Sign `manifest_digest()`, not the pretty JSON. The digest is stable
across the assembly order, across `pretty`, and across a round trip
through a file.

## See also

[`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md),
[`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md),
[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md).

## Examples

``` r
a <- make_manifest(list(b = 2, a = 1), environment = FALSE)
b <- make_manifest(list(a = 1, b = 2), environment = FALSE)
# the same content in a different order has the same digest
identical(manifest_digest(a), manifest_digest(b))
#> [1] TRUE

# full precision, so a recorded number can be checked later
m <- make_manifest(list(x = 1/3), environment = FALSE)
grepl("0.33333333333333331", manifest_canonical(m), fixed = TRUE)
#> [1] TRUE
```
