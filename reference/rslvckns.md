# Resolve a Download URL via CKAN package_search

The fallback for
[`rslvckan()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rslvckan.md)
when a dataset's slug has changed and `package_show` no longer finds it.
It runs a full-text `package_search` on the same CKAN portal and returns
the URL of the first resource, across all datasets returned, whose name
matches the pinned pattern.

## Usage

``` r
rslvckns(prov)
```

## Arguments

- prov:

  A provenance list as returned by
  [`loadprov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loadprov.md),
  or `NULL`. Reads `dataset$ckan_api_endpoint`,
  `resource$name_match_pattern` (a regular expression, required for a
  match), `resource$search_query` (optional search words) and
  `resource$format` (optional format name such as `"XLSX"`).

## Value

The matched resource URL as a length-1 character string, or `NULL`.

## Details

The portal base is the part of `dataset$ckan_api_endpoint` before
`/api/3/`; the request is
`<base>/api/3/action/package_search?q=<query>`. The query is
`resource$search_query` when given, otherwise the
`resource$name_match_pattern` with every character other than a letter,
digit or space replaced by a space. Datasets are walked in the order
CKAN ranks them, and their resources in listed order. A resource is
taken when its `name` matches `resource$name_match_pattern`
(case-insensitively) and either its format is CSV, or `resource$format`
is unset, or its format equals `resource$format` (case-insensitively). A
CSV resource is therefore accepted even when `resource$format` asks for
another format.

`NULL` is returned when `prov` is `NULL`, when no query can be formed,
when there is no endpoint to derive the base from, when the request
fails, or when nothing matches. Errors: a `prov` that is not a list; a
search URL or matched resource URL that is not public `https`. One
network request.

## Examples

``` r
# Missing fields return NULL rather than erroring:
rslvckns(list())
#> NULL

# no endpoint to derive the portal from: NULL, no request made
rslvckns(list(resource = list(name_match_pattern = "2014")))
#> NULL

# a provenance must be a list
try(rslvckns("data.ontario.ca"))
#> Error : `prov` must be a provenance list (loadprov())
if (FALSE) { # \dontrun{
# needs the network: searches data.ontario.ca
prov <- list(
  dataset = list(ckan_api_endpoint = paste0(
    "https://data.ontario.ca/api/3/action/package_show",
    "?id=ontario-public-library-statistics"
  )),
  resource = list(
    name_match_pattern = "2014",
    search_query = "public library statistics"
  )
)
rslvckns(prov)
} # }
```
