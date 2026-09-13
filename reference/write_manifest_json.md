# Write a Manifest to JSON

Serializes a manifest to a pretty-printed JSON file with the native JSON
codec (
[`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md))
; no jsonlite needed.

## Usage

``` r
write_manifest_json(manifest, path, canonical = FALSE)
```

## Arguments

- manifest:

  A manifest as returned by
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md)
  / built up with
  [`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md).

- path:

  Destination path for the JSON file.

- canonical:

  Write the canonical form rather than the pretty-printed one: one line,
  keys sorted, which is what
  [`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md)
  hashes. Use it when the file itself has to be byte-stable rather than
  read by a person.

## Value

The `path`, returned invisibly.

## Examples

``` r
man <- make_manifest(list(project = "demo"), environment = FALSE)
man <- record(man, "row_count", observed = 20, expected = 20)
#>   row_count                                    observed = 20.0000      expected = 20.0000      [PASS]
path <- write_manifest_json(man, tempfile(fileext = ".json"))
file.exists(path)
#> [1] TRUE

# Round-trips back through the package's own codec.
back <- bricklayer_json_from_json(path, simplifyVector = FALSE)
back$results$row_count$status        # "PASS"
#> [1] "PASS"
```
