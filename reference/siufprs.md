# Fetch and parse one SIU director's report

In one call, downloads one director's report from the SIU web site with
[`siufetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siufetch.md)
and parses it with
[`siuprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuprs.md).
It is meant for loops over many report ids: a report that cannot be
retrieved gives `NULL` and a message instead of stopping the loop.

## Usage

``` r
siufprs(drid, lang = c("en", "fr"))
```

## Arguments

- drid:

  The director's report id: one positive whole number (or a string of
  one), the `drid=` query parameter of the report URL on the SIU site.

- lang:

  Report language: `"en"` (default, the English page) or `"fr"` (the
  French page). Partial matching is allowed.

## Value

A named character vector of parsed fields, as from
[`siuprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuprs.md),
or `NULL` when the fetch fails.

## Details

The arguments are checked before any network use, so a bad id or
language fails at once. The report is downloaded to a temporary file,
which is deleted on exit. Any error from the download (network failure,
an HTTP error, no report at that id) is caught and turned into a message
of the form `"bricklayer: could not fetch SIU report <drid>: <reason>"`
and a `NULL` return. Errors from parsing are not caught.

Errors: `drid` that is not one positive whole number; `lang` other than
`"en"` or `"fr"`.

## Examples

``` r
# argument errors come before any network use
try(siufprs("abc"))
#> Error : `drid` must be one positive report number (the drid in the SIU report URL)
try(siufprs(648, lang = "de"))
#> Error : `lang` must be one of "en", "fr", not "de"

if (FALSE) { # \dontrun{
# needs the network: downloads report 648 from the SIU site
f <- siufprs(648)
if (!is.null(f)) f[["police_service"]]
fr <- siufprs(648, lang = "fr")
} # }
```
