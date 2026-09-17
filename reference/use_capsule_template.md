# Start a capsule from a template

Writes the skeleton of a reproducible capsule: a `data_provenance.json`
with the fields
[`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md)
and
[`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md)
expect, an `analysis.R` that fetches the source, verifies it, runs
[`analyse_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/analyse_table.md)
and writes the manifest and report, and a README that says how to run
it. Every field that must be filled in is marked `TODO`. The script runs
as written against the shipped OTIS example when `example = TRUE`.

## Usage

``` r
use_capsule_template(path, name = basename(path), example = FALSE)
```

## Arguments

- path:

  Directory to create.

- name:

  Capsule name.

- example:

  Use the shipped OTIS table as the source so the skeleton runs
  immediately.

## Value

The directory path, invisibly.

## Examples

``` r
d <- use_capsule_template(tempfile("capsule-"), example = TRUE)
list.files(d)
#> [1] "README.md"            "analysis.R"           "data_provenance.json"
```
