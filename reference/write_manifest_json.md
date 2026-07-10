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

## Examples

``` r
man <- make_manifest(list(project = "demo"), environment = FALSE)
man <- record(man, "row_count", observed = 20, expected = 20)
#>   row_count                                    observed = 20.0000      expected = 20.0000      [PASS]
path <- write_manifest_json(man, tempfile(fileext = ".json"))
file.exists(path)
#> [1] TRUE
```
