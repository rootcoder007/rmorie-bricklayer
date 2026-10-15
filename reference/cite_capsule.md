# Generate a Data Citation From Provenance

Builds a ready-to-paste data citation, as plain text and as a BibTeX
`@misc` entry, from the `dataset` and `resource` blocks of a provenance
record. Use it so that every report and paper built from a capsule cites
the data set in the same words, with the retrieval date and licence that
were actually pinned.

## Usage

``` r
cite_capsule(provenance)
```

## Arguments

- provenance:

  A provenance list as returned by
  [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md),
  or `NULL`.

## Value

A list with `text` and `bibtex`, each a length-1 character string (the
BibTeX entry has embedded newlines), or `NULL` if `provenance` is
`NULL`.

## Details

The fields used, with their fallbacks:

- author: `dataset$publisher`, else `"Unknown publisher"`;

- title: `resource$name`, else `dataset$package_slug`, else
  `"Untitled dataset"`;

- year: the first four characters of `captured_at_utc`, else the current
  year; retrieval date: its first ten characters (omitted if absent);

- link: `https://doi.org/<dataset$doi>` when a DOI is recorded, else
  `resource$direct_url`, else `dataset$catalogue_page`;

- licence: `dataset$licence_short`, else `dataset$licence_name`.

The text form is
`Publisher (year). Title [Data set]. link Retrieved date. Licence: x.`
The BibTeX key is the package slug with non-alphanumeric characters
removed, followed by the year. In the BibTeX entry the licence is
written in the `note` field only when a retrieval date is present. No
character in the fields is escaped for LaTeX. Error: `provenance` that
is not a list.

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
cit <- cite_capsule(prov)

# Plain-text citation ready to paste.
cat(cit$text)
#> Ontario Ministry of the Solicitor General (2026). Restrictive Confinement - Detailed Dataset [Data set]. https://data.ontario.ca/example.csv Retrieved 2026-06-23. Licence: OGL-Ontario.

# BibTeX @misc entry for LaTeX bibliographies.
cat(cit$bibtex)
#> @misc{dataoninmatesinontario2026,
#>   author = {{Ontario Ministry of the Solicitor General}},
#>   title = {Restrictive Confinement - Detailed Dataset},
#>   year = {2026},
#>   url = {https://data.ontario.ca/example.csv},
#>   note = {Retrieved 2026-06-23; licence: OGL-Ontario},
#> }

# a recorded DOI replaces the URL
prov$dataset$doi <- "10.5683/SP3/EXAMPLE"
cat(cite_capsule(prov)$text)
#> Ontario Ministry of the Solicitor General (2026). Restrictive Confinement - Detailed Dataset [Data set]. https://doi.org/10.5683/SP3/EXAMPLE Retrieved 2026-06-23. Licence: OGL-Ontario.

# NULL provenance returns NULL (composes safely).
cite_capsule(NULL)
#> NULL

# anything else that is not a list is an error
try(cite_capsule("data-on-inmates-in-ontario"))
#> Error : `provenance` must be a provenance list (load_provenance())
```
