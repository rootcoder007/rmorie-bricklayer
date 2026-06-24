# Resolve a Download URL via CKAN package_search

Fallback for
[`resolve_via_ckan()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_ckan.md)
when the dataset slug has changed. Derives the CKAN portal base URL from
the provenance's `package_show` endpoint, runs a `package_search` query
(from `resource$search_query`, or derived from the name-match pattern),
and returns the URL of the first matching resource, preferring CSV
format when specified.

## Usage

``` r
resolve_via_ckan_search(provenance)
```

## Arguments

- provenance:

  A provenance list as returned by
  [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md).
  Uses `resource$search_query`, `resource$name_match_pattern`,
  `resource$format`, and `dataset$ckan_api_endpoint`.

## Value

The matched resource URL as a character string, or `NULL` if no query or
base URL can be derived, the request fails, or nothing matches.
