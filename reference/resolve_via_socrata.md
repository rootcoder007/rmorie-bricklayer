# Resolve a Download URL via the Socrata Metadata API

Checks that a dataset still exists on a Socrata open-data portal and
returns its full CSV export URL. Socrata powers the Calgary, Chicago and
New York City portals used across the MORIE family; a dataset is named
by its portal domain and a four-by-four id such as `ijzp-q8t2`.

## Usage

``` r
resolve_via_socrata(provenance)
```

## Arguments

- provenance:

  A provenance list as returned by
  [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md),
  or `NULL`. Must contain `dataset$socrata_domain` (a host name without
  scheme, e.g. `"data.cityofchicago.org"`) and `dataset$socrata_id` (the
  four-by-four dataset id, e.g. `"ijzp-q8t2"`).

## Value

The CSV export URL as a length-1 character string, or `NULL` if the
fields are missing, the request fails, or the metadata reports an error.

## Details

One request is made, to `https://<domain>/api/views/<id>.json`. If it
answers with JSON that has an `id` field the dataset is taken to exist
and the function returns
`https://<domain>/api/views/<id>/rows.csv?accessType=DOWNLOAD`, the
portal's export of every row. The id is not checked further, and the
export URL is not fetched.

`NULL` is returned when `provenance` is `NULL`, when the domain or id is
missing, when the request fails (offline, HTTP error, invalid JSON) or
when the metadata has no `id`. Errors: a `provenance` that is not a
list; a domain that is not a public host (`localhost`, a private
address, a single-label name).

## Examples

``` r
# Missing fields return NULL rather than erroring:
resolve_via_socrata(list())
#> NULL
resolve_via_socrata(list(dataset = list(socrata_domain = "data.cityofchicago.org")))
#> NULL

# a local host is refused before any request
try(resolve_via_socrata(list(dataset = list(
  socrata_domain = "localhost", socrata_id = "abcd-1234"))))
#> Error : socrata_domain points at a local or private address ('https://localhost'): refused (a single-label name is not a public host (localhost))
if (FALSE) { # \dontrun{
# needs the network
prov <- list(dataset = list(
  socrata_domain = "data.cityofchicago.org",
  socrata_id = "ijzp-q8t2"
))
resolve_via_socrata(prov)
} # }
```
