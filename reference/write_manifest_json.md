# Write a Manifest to JSON

Writes a manifest to a JSON file, so the record of a run (its metadata,
cross-checks and environment) can be kept next to the outputs, shared,
and read back by any JSON reader. By default the file is pretty-printed
for people; `canonical = TRUE` writes the byte-stable form that
[`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md)
hashes. The package's own JSON codec
([`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md))
is used; jsonlite is not needed.

## Usage

``` r
write_manifest_json(manifest, path, canonical = FALSE)
```

## Arguments

- manifest:

  A manifest as returned by
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md)
  and built up with
  [`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md).

- path:

  Character scalar, the destination file path.

- canonical:

  Logical scalar, default `FALSE`. `TRUE` writes the canonical form
  instead of the pretty-printed one: one line, keys sorted, which is
  what
  [`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md)
  hashes. Use it when the file itself has to be byte-stable rather than
  read by a person.

## Value

`path` (character scalar), invisibly.

## Details

Numbers are written with 17 significant digits, so every double reads
back exactly; `NA` and `NULL` are written as `null`, and length-one
vectors as scalars. When the manifest's `meta$synthetic` is `TRUE`, or
the session is flagged synthetic (see
[`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md)),
`meta$synthetic = true` is written whatever the list says, so a file
written from generated data always says so. An existing file at `path`
is overwritten; the folder must exist.

Errors when `path` is not a single non-empty string, and (from base R)
when the file cannot be opened for writing.

## See also

[`manifest_canonical()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md),
[`write_summary_txt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_summary_txt.md).

## Examples

``` r
man <- make_manifest(list(project = "demo"), environment = FALSE)
man <- record(man, "row_count", observed = 20, expected = 20)
#>   row_count                                    observed = 20.0000      expected = 20.0000      [INFO]
path <- write_manifest_json(man, tempfile(fileext = ".json"))
file.exists(path)
#> [1] TRUE

# Round-trips back through the package's own codec.
back <- bricklayer_json_from_json(path, simplifyVector = FALSE)
back$results$row_count$status # "PASS"
#> [1] "INFO"

# the canonical form: one line whose SHA-256 is the manifest digest
cpath <- write_manifest_json(man, tempfile(fileext = ".json"), canonical = TRUE)
identical(readLines(cpath), manifest_canonical(man))
#> [1] FALSE

# the path must be one string
try(write_manifest_json(man, c("a.json", "b.json")))
#> Error : `path` must be a single non-empty string
```
