# Construct a Reproducibility Manifest

Creates an empty manifest object that accumulates cross-check entries
via
[`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md)
and is later serialized with
[`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md).

## Usage

``` r
make_manifest(meta, environment = TRUE)
```

## Arguments

- meta:

  A named list of run metadata (e.g. `project`, `author`, `run_at`,
  `synthetic`).

- environment:

  Logical; when `TRUE` (the default) the manifest also records the
  analysis environment via
  [`capture_environment()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_environment.md)
  (R version, platform, OS, UTC timestamp, loaded package versions).

## Value

A manifest list with elements `meta`, an empty `results` list, and (when
requested) `environment`.

## Examples

``` r
# Minimal manifest, no environment capture.
man <- make_manifest(list(project = "demo-study", author = "A. Author"),
                     environment = FALSE)
names(man)          # "meta" "results"
#> [1] "meta"    "results"
man$meta$project
#> [1] "demo-study"

# With environment = TRUE it also records R version / platform / packages.
full <- make_manifest(list(project = "demo"), environment = TRUE)
names(full)         # adds "environment"
#> [1] "meta"        "results"     "environment"
full$environment$r_version
#> [1] "4.6.1"
```
