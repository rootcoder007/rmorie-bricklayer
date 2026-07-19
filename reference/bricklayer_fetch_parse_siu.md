# Fetch and parse one SIU director's report

Convenience:
[`bricklayer_fetch_siu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch_siu.md)
then
[`bricklayer_parse_siu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_parse_siu.md).
Fails gracefully – returns `NULL` with a message when the report cannot
be retrieved.

## Usage

``` r
bricklayer_fetch_parse_siu(drid, lang = c("en", "fr"))
```

## Arguments

- drid:

  Director's-report id (the `drid=` query parameter).

- lang:

  `"en"` (default) or `"fr"`.

## Value

A named character vector of parsed fields, or `NULL` when the fetch
fails.

## Examples

``` r
# \donttest{
f <- try(bricklayer_fetch_parse_siu(648), silent = TRUE)
if (is.character(f)) f[["police_service"]]
#> [1] "Peel Regional Police"
# }
```
