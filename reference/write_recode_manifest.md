# Write and verify a recode manifest

`write_recode_manifest()` saves a manifest from
[`recode_manifest`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recode_manifest.md)
as a JSON file. `verify_recode_manifest()` reads such a file back and
checks it against the data: that the mapping and the manifest body are
unchanged since they were written, that the recode in the data still
matches the recorded mapping, that the recoded counts are the recorded
counts, and, for a signed manifest, that the signature verifies. Use the
pair to hand a recode to a reviewer or to re-check it before a later
analysis.

## Usage

``` r
write_recode_manifest(manifest, path)

verify_recode_manifest(path, original, recoded)
```

## Arguments

- manifest:

  A manifest returned by
  [`recode_manifest`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recode_manifest.md).

- path:

  Character string: the JSON file to write (`write_recode_manifest()`)
  or read (`verify_recode_manifest()`).

- original, recoded:

  The vectors before and after the recode, to check the manifest
  against.

## Value

`write_recode_manifest()` returns `path` invisibly.

`verify_recode_manifest()` returns a list with `ok` (logical), `reasons`
(character, `character(0)` when `ok`), `signature_ok` (logical, `NA`
when the manifest is unsigned) and `manifest` (the parsed JSON as a
list).

## Details

`verify_recode_manifest()` collects every failure in `reasons` instead
of stopping at the first:

- the SHA-256 of the stored mapping differs from `mapping_sha256`;

- the SHA-256 of the body (all fields except `body_sha256`, `signature`
  and `public_key`) differs from `body_sha256`, meaning the file was
  edited after it was written;

- [`verify_recode`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_recode.md)`(original, recoded, mapping)`
  fails;

- the counts of `recoded` differ from `counts_after`.

The signature, when present, is checked with
[`capsule_verify`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_verify.md)
over the stored `body_sha256`. It therefore proves who wrote that hash;
the body check above proves the body still matches it. Both are needed
for `ok = TRUE`.

`write_recode_manifest()` errors when `manifest` is not a
`bricklayer_recode_manifest`; it overwrites `path`.

## Examples

``` r
x <- c("W", "B", "W")
y <- guard_recode(x, c(W = "White", B = "Black"))
m <- recode_manifest(x, y, c(W = "White", B = "Black"))
p <- write_recode_manifest(m, tempfile(fileext = ".json"))
verify_recode_manifest(p, x, y)$ok
#> [1] TRUE

# the data changed after the manifest was written
y2 <- y
y2[2] <- "White"
verify_recode_manifest(p, x, y2)$reasons
#> [1] "verify_recode: ‘B’ was mapped to ‘White’ but the declared mapping says ‘Black’. THIS is how groups get swapped; fix the recode before any model runs."
#> [2] "recoded counts differ from the manifest"                                                                                                              

# only manifests can be written
try(write_recode_manifest(list(a = 1), tempfile()))
#> Error : write_recode_manifest: `manifest` must come from recode_manifest()
```
