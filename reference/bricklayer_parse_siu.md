# Parse an SIU director's report into the schema fields

Deterministic, offline extraction of every
[`bricklayer_siu_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_schema.md)
field (plus `_language`) from report HTML. Fields the report does not
state come back as `""`.

## Usage

``` r
bricklayer_parse_siu(html)
```

## Arguments

- html:

  A length-1 character vector of raw report HTML, or the path to a saved
  report file (e.g. from
  [`bricklayer_fetch_siu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch_siu.md)).

## Value

A named character vector: the 16 schema fields plus `_language`.

## Examples

``` r
f <- bricklayer_parse_siu(system.file("extdata",
                                      "siu_synthetic_report.html",
                                      package = "rmoriebricklayer"))
f[["number_of_subject_officers"]]
#> [1] "2"
```
