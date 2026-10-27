# Load a Pinned Data-Provenance Record

Reads a `data_provenance.json` file, the record that pins where a
project's data came from: the portal endpoint (CKAN, Socrata or ArcGIS),
the resource name pattern, the expected SHA-256 of the file, a Wayback
Machine snapshot, the schema the data must match and the recipe for a
synthetic stand-in. The resolvers
([`rslvckan()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rslvckan.md),
[`rslvsoc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rslvsoc.md),
[`rslvarc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rslvarc.md))
and the checks
([`vrfsha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfsha256.md),
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md))
all take the list this returns.

## Usage

``` r
loadprov(path)
```

## Arguments

- path:

  Path to the provenance JSON file, a single string.

## Value

The parsed provenance as a nested named list (JSON objects become named
lists, arrays become unnamed lists, strings, numbers and booleans become
length-1 vectors), or `NULL` if the file does not exist. The list has
class `c("rmbl_provenance", "list")`, which only changes how it prints
(a box); its elements, and the JSON written from it, are those of a
plain list.

## Details

The file is parsed with the package's own JSON codec (see
[`fromjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fromjs.md))
without simplification: JSON arrays stay lists, so a pinned digest such
as `"sha256": "abc"` is a length-1 character and an array of column
names is a list of strings (use
[`unlist()`](https://rdrr.io/r/base/unlist.html) where a vector is
needed). Nothing is checked about the content here;
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md)
reads the `schema` block.

A missing file is not an error: it returns `NULL`, so a project can run
without a provenance record and every resolver treats `NULL` as “nothing
pinned”.

Errors: `path` that is not a single non-empty string; `path` that is a
directory; a file that is not valid JSON.

## Examples

``` r
provfile <- tempfile(fileext = ".json")
writeLines('{"dataset": {"title": "demo"}, "sha256": "abc"}', provfile)
prov <- loadprov(provfile)
prov$dataset$title
#> [1] "demo"
loadprov(file.path(tempdir(), "no-such-file.json")) # NULL
#> NULL

# arrays stay lists: unlist() them for a vector
writeLines('{"schema": {"expected_columns": ["id", "year"]}}', provfile)
p <- loadprov(provfile)
unlist(p$schema$expected_columns)
#> [1] "id"   "year"
length(valsch(data.frame(id = 1, year = 2020), p))
#> [1] 0

# a directory is not a provenance file
try(loadprov(tempdir()))
#> Error : `path` is a directory, not a provenance file: /tmp/Rtmp8mkWXN
```
