# Load a Pinned Data-Provenance Record

Reads a `data_provenance.json` file describing a project's pinned data
source: the CKAN endpoint, resource name pattern, expected SHA256,
Wayback snapshot, schema, and synthetic-data recipe.

## Usage

``` r
load_provenance(path)
```

## Arguments

- path:

  Path to the provenance JSON file.

## Value

The parsed provenance as a nested list (via
[`jsonlite::fromJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
with `simplifyVector = FALSE`), or `NULL` if the file does not exist.

## Examples

``` r
prov_file <- tempfile(fileext = ".json")
writeLines('{"dataset": {"title": "demo"}, "sha256": "abc"}', prov_file)
prov <- load_provenance(prov_file)
prov$dataset$title
#> [1] "demo"
load_provenance(file.path(tempdir(), "no-such-file.json"))  # NULL
#> NULL
```
