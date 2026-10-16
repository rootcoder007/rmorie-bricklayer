# Load a Pinned Data-Provenance Record

Reads a `data_provenance.json` file, the record that pins where a
project's data came from: the portal endpoint (CKAN, Socrata or ArcGIS),
the resource name pattern, the expected SHA-256 of the file, a Wayback
Machine snapshot, the schema the data must match and the recipe for a
synthetic stand-in. The resolvers
([`resolve_via_ckan()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_ckan.md),
[`resolve_via_socrata()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_socrata.md),
[`resolve_via_arcgis()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_arcgis.md))
and the checks
([`verify_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_sha256.md),
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md))
all take the list this returns.

## Usage

``` r
load_provenance(path)
```

## Arguments

- path:

  Path to the provenance JSON file, a single string.

## Value

The parsed provenance as a nested named list (JSON objects become named
lists, arrays become unnamed lists, strings, numbers and booleans become
length-1 vectors), or `NULL` if the file does not exist.

## Details

The file is parsed with the package's own JSON codec (see
[`bricklayer_json_from_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_from_json.md))
without simplification: JSON arrays stay lists, so a pinned digest such
as `"sha256": "abc"` is a length-1 character and an array of column
names is a list of strings (use
[`unlist()`](https://rdrr.io/r/base/unlist.html) where a vector is
needed). Nothing is checked about the content here;
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
reads the `schema` block.

A missing file is not an error: it returns `NULL`, so a project can run
without a provenance record and every resolver treats `NULL` as "nothing
pinned".

Errors: `path` that is not a single non-empty string; `path` that is a
directory; a file that is not valid JSON.

## Examples

``` r
prov_file <- tempfile(fileext = ".json")
writeLines('{"dataset": {"title": "demo"}, "sha256": "abc"}', prov_file)
prov <- load_provenance(prov_file)
prov$dataset$title
#> [1] "demo"
load_provenance(file.path(tempdir(), "no-such-file.json")) # NULL
#> NULL

# arrays stay lists: unlist() them for a vector
writeLines('{"schema": {"expected_columns": ["id", "year"]}}', prov_file)
p <- load_provenance(prov_file)
unlist(p$schema$expected_columns)
#> [1] "id"   "year"
length(validate_schema(data.frame(id = 1, year = 2020), p))
#> [1] 0

# a directory is not a provenance file
try(load_provenance(tempdir()))
#> Error : `path` is a directory, not a provenance file: /tmp/Rtmp1nz8V4
```
