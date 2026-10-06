# The hosted MORIE services, as the project site currently describes them

Reads `https://rmorie.com/.well-known/morie-services.json`, a signed
document naming the language-model tier and the curated-data service:
their endpoints, whether each is `"key"` (reachable with a key requested
on the site) or `"off"`, the model list, and a notice. The signature
(ML-DSA-44, public key pinned in this package) is checked before
anything in it is believed, so the endpoints can move or be switched off
on the site without a package release, and a document that does not
verify is ignored. The result is cached for a day; without a network the
cached copy is used, then the copy bundled with the package.

## Usage

``` r
bricklayer_services(
  refresh = FALSE,
  max_age = 86400,
  timeout = 20,
  offline = FALSE
)
```

## Arguments

- refresh:

  `TRUE` to fetch the live document even when the cached copy is fresh.

- max_age:

  Seconds a cached copy is used without asking the site (default one
  day).

- timeout:

  Seconds allowed for the fetch.

- offline:

  `TRUE` never fetches: the cached copy, then the bundled one (what the
  examples and an offline session get).

## Value

A list with `version`, `issued`, `notice`, `llm` (`mode`, `base_url`,
`auth_url`, `default_model`, `models`, `request_access`) and `data`
(`mode`, `base_url`, `license`, `request_access`), with the attribute
`"source"` set to `"live"`, `"cache"`, `"bundled"` or `"off"`.

## Details

Every other MORIE package reads the same document through this function,
so one sign-in and one document serve rmorie, rmoriedata and morie
alike. The hosted tier is a last resort: a local model or your own API
key is always preferred where the caller offers the choice.

## Examples

``` r
# Nothing is fetched here: the cached copy if there is one, else the
# document bundled with the package.
s <- bricklayer_services(offline = TRUE)
s$llm$mode
#> [1] "key"
attr(s, "source")
#> [1] "bundled"
```
