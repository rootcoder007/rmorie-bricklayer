# Resolve a Download URL via CKAN package_show

Asks a CKAN open-data portal for the current list of files in a dataset
and returns the URL of the first file whose name matches the pattern
pinned in the provenance record. CKAN powers data.ontario.ca,
data.gov.uk, data.gov and most government open-data portals; when a
portal replaces a file (a new resource UUID, a new URL) the dataset page
stays the same, so this recovers the current download URL without
editing the project.

## Usage

``` r
rslvckan(prov)
```

## Arguments

- prov:

  A provenance list as returned by
  [`loadprov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loadprov.md),
  or `NULL`. A lookup is made only when it has both of these fields:

  - `dataset$ckan_api_endpoint`;

  - `resource$name_match_pattern`.

## Value

The matched resource URL as a length-1 character string, or `NULL` as
described in Details.

## Details

The function reads `dataset$ckan_api_endpoint`, the full URL, which ends
in `/api/3/action/` and `package_show?id=<slug>`. It also reads
`resource$name_match_pattern`, a regular expression. It fetches the
endpoint as JSON, and walks `result$resources` in the order the portal
lists them. The first resource whose `name` matches the pattern
(case-insensitively, with [`grepl()`](https://rdrr.io/r/base/grep.html))
wins. If the slug itself has changed,
[`rslvckns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rslvckns.md)
is the fallback.

`NULL` is returned, without an error, when `prov` is `NULL`, when either
field is missing or empty, when the request fails (offline, HTTP error,
invalid JSON), when CKAN answers `"success": false`, or when no resource
name matches. Errors are raised for a `prov` that is not a list, for an
endpoint that is not a public `https` URL (plain `http` only when the
option `rmoriebricklayer.allowhttp` is `TRUE`; loopback, private and
link-local addresses are refused), and for a matched resource URL that
fails the same check. One network request; nothing is written.

## Examples

``` r
# Missing fields return NULL rather than erroring:
rslvckan(list())
#> NULL
rslvckan(NULL)
#> NULL

# the endpoint must be public https, checked before any request
prov <- list(
  dataset = list(
    ckan_api_endpoint = "http://localhost/api/3/action/package_show?id=x"
  ),
  resource = list(name_match_pattern = "2014")
)
try(rslvckan(prov))
#> Error : ckan_api_endpoint must be an https:// URL, not http:// ('http://localhost/api/3/action/package_show?id=x'); options(rmoriebricklayer.allowhttp = TRUE) admits a trusted plain-http mirror
if (FALSE) { # interactive()
# needs the network: asks data.ontario.ca for the current file URL
prov <- list(
  dataset = list(ckan_api_endpoint = paste0(
    "https://data.ontario.ca/api/3/action/package_show",
    "?id=ontario-public-library-statistics"
  )),
  resource = list(name_match_pattern = "2014")
)
rslvckan(prov)
}
```
