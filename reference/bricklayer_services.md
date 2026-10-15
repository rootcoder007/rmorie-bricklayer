# The hosted MORIE services, as the project site currently describes them

Reads `https://rmorie.com/.well-known/morie-services.json`, a signed
document naming the curated-data service and its sign-in: their
endpoints, whether each is `"key"` (reachable with a key requested on
the site) or `"off"`, and a notice. The signature (ML-DSA-44, public key
pinned in this package) is checked before anything in it is believed, so
the endpoints can move or be switched off on the site without a package
release, and a document that does not verify is ignored. The result is
cached for a day; without a network the cached copy is used, then the
copy bundled with the package.

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

  Logical scalar, default `FALSE`: `TRUE` fetches the live document even
  when the cached copy is fresh.

- max_age:

  Numeric scalar, the seconds a cached copy is used without asking the
  site; default `86400` (one day); `Inf` keeps a cached copy forever.

- timeout:

  Numeric scalar, the seconds allowed for each of the two fetches
  (document and signature); default `20`.

- offline:

  Logical scalar, default `FALSE`: `TRUE` never fetches: the session's
  copy, the cached copy, then the bundled one (what the examples and an
  offline session get).

## Value

A list with `version` (integer, 1), `issued` (the signing time, ISO 8601
UTC), `notice` (text for the user, possibly empty), `llm` (`mode`,
`base_url`, `auth_url`: where the sign-in for the data key is reached;
also `models`, `default_model` and `request_access`) and `data` (`mode`,
`base_url`, `license`, `request_access`, and `auth_url` when the
document has one), with the attribute `"source"` set to `"live"`,
`"cache"`, `"bundled"` or `"off"`.

## Details

Every other MORIE package reads the same document through this function,
so one sign-in and one document serve rmorie, rmoriedata and morie
alike. Language models are never hosted: you bring your own key or model
([`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)).
The `llm` block of documents signed before that change carries the
sign-in address only.

The environment variable `MORIE_SERVICES_URL` points the fetch at a
mirror of the document (its signature is fetched from the same place,
with the suffix `.sig`); the signature check is unchanged, so a mirror
can only serve a document the project signed.

The order of resolution: a cached copy younger than `max_age` (unless
`refresh`); the live document, fetched through the package's own checked
transport (public https only, at most 1 MiB), verified, and kept only
when it is not older than the copy already held or the bundled copy (an
older signed document is a rollback and is refused); the stale cached
copy; the bundled copy; and finally a document with every mode `"off"`.
A cached copy no newer than the bundled one is not used, and one that is
older is deleted. Network failures are not errors: they fall through to
the next copy.

Side effects: an accepted live document and its signature are written to
`tools::R_user_dir("rmoriebricklayer", "cache")` as
`morie-services.json` and `morie-services.sig`. The result is also kept
for the session, so later `offline = TRUE` calls (which the rest of the
package makes) return it without checking the signature again.

Errors: `refresh` or `offline` not `TRUE` or `FALSE`; `max_age` not a
single non-negative number; `timeout` not a single finite number of at
least 1.

## See also

[`bricklayer_llm_login`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_login.md),
[`bricklayer_data_manifest`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_data_manifest.md).

## Examples

``` r
# Nothing is fetched here: the cached copy if there is one, else the
# document bundled with the package.
s <- bricklayer_services(offline = TRUE)
s$llm$mode
#> [1] "off"
attr(s, "source")
#> [1] "bundled"

# where the curated-data service is, and whether it takes a key
s$data[c("mode", "base_url")]
#> $mode
#> [1] "key"
#> 
#> $base_url
#> [1] "https://data.rmorie.com"
#> 
s$issued
#> [1] "2026-10-14T00:46:57Z"

# arguments are checked
try(bricklayer_services(max_age = -1))
#> Error : `max_age` must be a single non-negative number of seconds (Inf keeps a cached copy forever)
if (FALSE) { # \dontrun{
# ask the site now (network), and keep the answer for a day
bricklayer_services(refresh = TRUE)
} # }
```
