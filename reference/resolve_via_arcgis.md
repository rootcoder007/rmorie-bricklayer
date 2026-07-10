# Resolve a Query URL via ArcGIS FeatureServer Metadata

Verifies that an ArcGIS FeatureServer layer still exists by fetching its
`f=json` metadata, then returns a paged GeoJSON query URL for the full
layer. ArcGIS FeatureServer layers back the Toronto Police Service
open-data portal used across the MORIE family.

## Usage

``` r
resolve_via_arcgis(provenance)
```

## Arguments

- provenance:

  A provenance list as returned by
  [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md).
  Must contain `dataset$arcgis_layer_url`, a FeatureServer layer root
  such as
  `"https://services.arcgis.com/.../Assault_Open_Data/FeatureServer/0"`.

## Value

The layer query URL (`where=1=1`, all fields, GeoJSON) as a character
string, or `NULL` if the field is missing, the request fails, or the
layer metadata reports an error.

## Examples

``` r
# Missing fields return NULL rather than erroring:
resolve_via_arcgis(list())
#> NULL
# \donttest{
prov <- list(dataset = list(arcgis_layer_url = paste0(
  "https://services.arcgis.com/S9th0jAJ7bqgIRjw/arcgis/rest/services/",
  "Neighbourhood_Crime_Rates_Open_Data/FeatureServer/0")))
resolve_via_arcgis(prov)
#> [1] "https://services.arcgis.com/S9th0jAJ7bqgIRjw/arcgis/rest/services/Neighbourhood_Crime_Rates_Open_Data/FeatureServer/0/query?where=1%3D1&outFields=*&f=geojson"
# }
```
