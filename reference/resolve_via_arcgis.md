# Resolve a Query URL via ArcGIS FeatureServer Metadata

Checks that an ArcGIS FeatureServer layer still exists and returns a
query URL that downloads every feature of the layer as GeoJSON.
FeatureServer layers back the Toronto Police Service open-data portal
and many municipal portals used across the MORIE family.

## Usage

``` r
resolve_via_arcgis(provenance)
```

## Arguments

- provenance:

  A provenance list as returned by
  [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md),
  or `NULL`. Must contain `dataset$arcgis_layer_url`, a FeatureServer
  layer root such as
  `"https://services.arcgis.com/.../Assault_Open_Data/FeatureServer/0"`.

## Value

The layer query URL as a length-1 character string, or `NULL` if the
field is missing, the request fails, or the layer metadata reports an
error.

## Details

Trailing slashes are dropped from `dataset$arcgis_layer_url`, the URL is
checked (public `https` only), and one request is made to
`<layer>?f=json`. If the answer is JSON with a `name` and no `error`
element, the function returns
`<layer>/query?where=1%3D1&outFields=*&f=geojson`: every row
(`where=1=1`), every field, as GeoJSON. ArcGIS servers return at most
their `maxRecordCount` features per request, so a large layer needs
paging (`resultOffset`) by the caller; the URL is not fetched here.

`NULL` is returned when `provenance` is `NULL`, when the field is
missing, when the request fails or when the metadata reports an error.
Errors: a `provenance` that is not a list; a layer URL that is not
public `https`.

## Examples

``` r
# Missing fields return NULL rather than erroring:
resolve_via_arcgis(list())
#> NULL

# only https layer URLs are accepted
try(resolve_via_arcgis(list(dataset = list(
  arcgis_layer_url = "ftp://example.org/FeatureServer/0"))))
#> Error : arcgis_layer_url must be an https:// URL, not ftp:// ('ftp://example.org/FeatureServer/0'); options(rmoriebricklayer.allow_http = TRUE) admits a trusted plain-http mirror
try(resolve_via_arcgis("not a list"))
#> Error : `provenance` must be a provenance list (load_provenance())
if (FALSE) { # \dontrun{
# needs the network
prov <- list(dataset = list(arcgis_layer_url = paste0(
  "https://services.arcgis.com/S9th0jAJ7bqgIRjw/arcgis/rest/services/",
  "Neighbourhood_Crime_Rates_Open_Data/FeatureServer/0"
)))
resolve_via_arcgis(prov)
} # }
```
