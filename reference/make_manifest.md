# Construct a Reproducibility Manifest

Creates an empty manifest object that accumulates cross-check entries
via
[`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md)
and is later serialized with
[`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md).

## Usage

``` r
make_manifest(meta)
```

## Arguments

- meta:

  A named list of run metadata (e.g. `project`, `author`, `run_at`,
  `os`, `r_version`, `synthetic`).

## Value

A manifest list with elements `meta` and an empty `results` list.
