# Write a Manifest to JSON

Serializes a manifest to a pretty-printed JSON file via the jsonlite
package.

## Usage

``` r
write_manifest_json(manifest, path)
```

## Arguments

- manifest:

  A manifest as returned by
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md)
  / built up with
  [`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md).

- path:

  Destination path for the JSON file.

## Value

The `path`, returned invisibly.
