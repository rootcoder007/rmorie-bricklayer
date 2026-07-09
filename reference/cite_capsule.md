# Generate a Data Citation From Provenance

Builds a ready-to-paste data citation (plain text and BibTeX `@misc`)
from a provenance object's `dataset` and `resource` blocks, using
publisher, resource name, source system, retrieval date, license, the
pinned URL, and a DOI when one is recorded (`dataset$doi`).

## Usage

``` r
cite_capsule(provenance)
```

## Arguments

- provenance:

  A provenance list as returned by
  [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md).

## Value

A list with `text` and `bibtex` character scalars, or `NULL` if
`provenance` is `NULL`.

## Examples

``` r
prov <- list(
  captured_at_utc = "2026-06-23T04:41:40Z",
  dataset = list(publisher = "Ontario Ministry of the Solicitor General",
                 licence_short = "OGL-Ontario",
                 package_slug = "data-on-inmates-in-ontario"),
  resource = list(name = "Restrictive Confinement - Detailed Dataset",
                  direct_url = "https://data.ontario.ca/example.csv")
)
cat(cite_capsule(prov)$text)
#> Ontario Ministry of the Solicitor General (2026). Restrictive Confinement - Detailed Dataset [Data set]. https://data.ontario.ca/example.csv Retrieved 2026-06-23. Licence: OGL-Ontario.
```
