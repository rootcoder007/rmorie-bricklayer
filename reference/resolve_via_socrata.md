# Resolve a Download URL via the Socrata Metadata API

Verifies that a Socrata dataset still exists by fetching its `api/views`
metadata, then returns the canonical CSV export URL. Socrata powers the
Calgary, Chicago, and NYC open-data portals used across the MORIE
family.

## Usage

``` r
resolve_via_socrata(provenance)
```

## Arguments

- provenance:

  A provenance list as returned by
  [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md).
  Must contain `dataset$socrata_domain` (e.g.
  `"data.cityofchicago.org"`) and `dataset$socrata_id` (the 4x4 dataset
  id, e.g. `"ijzp-q8t2"`).

## Value

The CSV export URL as a character string, or `NULL` if the fields are
missing, the request fails, or the metadata reports an error.

## Examples

``` r
# Missing fields return NULL rather than erroring:
resolve_via_socrata(list())
#> NULL
# \donttest{
prov <- list(dataset = list(socrata_domain = "data.cityofchicago.org",
                            socrata_id     = "ijzp-q8t2"))
resolve_via_socrata(prov)
#> [1] "https://data.cityofchicago.org/api/views/ijzp-q8t2/rows.csv?accessType=DOWNLOAD"
# }
```
