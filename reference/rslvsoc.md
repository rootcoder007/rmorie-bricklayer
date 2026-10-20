# Resolve a Download URL via the Socrata Metadata API

Checks that a dataset still exists on a Socrata open-data portal and
returns its full CSV export URL. Socrata powers the Calgary, Chicago and
New York City portals used across the MORIE family; a dataset is named
by its portal domain and a four-by-four id such as `ijzp-q8t2`.

## Usage

``` r
rslvsoc(prov)
```

## Arguments

- prov:

  A provenance list as returned by
  [`loadprov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loadprov.md),
  or `NULL`. It must have two fields. The first is
  `dataset$socrata_domain`, a host name without scheme such as
  `"data.cityofchicago.org"`. The second is `dataset$socrata_id`, the
  four-by-four dataset id such as `"ijzp-q8t2"`.

## Value

The CSV export URL as a length-1 character string, or `NULL` if the
fields are missing, the request fails, or the metadata reports an error.

## Details

One request is made, to `https://<domain>/api/views/<id>.json`. If it
answers with JSON that has an `id` field the dataset is taken to exist.
The function then returns the portal's export of every row, the URL
`https://<domain>/api/views/<id>/` followed by
`rows.csv?accessType=DOWNLOAD`. The id is not checked further, and the
export URL is not fetched.

`NULL` is returned when `prov` is `NULL`, when the domain or id is
missing, when the request fails (offline, HTTP error, invalid JSON) or
when the metadata has no `id`. Errors: a `prov` that is not a list; a
domain that is not a public host (`localhost`, a private address, a
single-label name).

## Examples

``` r
# Missing fields return NULL rather than erroring:
rslvsoc(list())
#> NULL
rslvsoc(list(dataset = list(socrata_domain = "data.cityofchicago.org")))
#> NULL

# a local host is refused before any request
try(rslvsoc(list(dataset = list(
  socrata_domain = "localhost", socrata_id = "abcd-1234"))))
#> Error : socrata_domain points at a local or private address ('https://localhost'): refused (a single-label name is not a public host (localhost))

if (FALSE) { # interactive()
# needs the network
prov <- list(dataset = list(
  socrata_domain = "data.cityofchicago.org",
  socrata_id = "ijzp-q8t2"
))
rslvsoc(prov)
}
```
