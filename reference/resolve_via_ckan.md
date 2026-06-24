# Resolve a Download URL via CKAN package_show

Queries the CKAN `package_show` endpoint recorded in a provenance object
and returns the URL of the first resource whose name matches the
provenance's name-match pattern. CKAN powers data.ontario.ca,
data.gov.uk, data.gov, and most government open-data portals, so this
recovers the current download URL even if the underlying resource UUID
has been replaced.

## Usage

``` r
resolve_via_ckan(provenance)
```

## Arguments

- provenance:

  A provenance list as returned by
  [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md).
  Must contain `dataset$ckan_api_endpoint` and
  `resource$name_match_pattern`.

## Value

The matched resource URL as a character string, or `NULL` if the
endpoint is missing, the request fails, CKAN reports failure, or no
resource name matches.
