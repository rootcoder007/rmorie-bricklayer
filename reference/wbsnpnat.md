# Resolve a Wayback Machine snapshot URL (C++/libcurl)

Queries the Internet Archive “available” API for the closest archived
snapshot of `url` and returns its address, or `NULL` when nothing is
archived. Use it to find an archived copy of a data file or page that
has moved or been removed. C++ backend; supersedes the older R-level
resolver
[`wbsnpurl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsnpurl.md),
which is kept for the pure-R path and now parses with the package's own
JSON codec.

## Usage

``` r
wbsnpnat(url, tmout = 30L)
```

## Arguments

- url:

  URL to resolve, a single string (`http` or `https`).

- tmout:

  Request timeout in seconds, default 30.

## Value

The `https` snapshot URL (a length-1 character string), or `NULL` if
none is archived or the lookup failed.

## Details

`url` is only a query parameter of the lookup, never fetched, so a plain
`http://` page can be looked up; a local or private address is still
refused. One request is made to `https://archive.org/`; the most recent
snapshot is asked for (there is no timestamp argument; use
[`wbsnpurl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsnpurl.md)
for one). Any network failure, and a URL that was never archived, give
`NULL` rather than an error. A spinner is drawn on stderr while waiting,
unless `options(morie.quiet = TRUE)`.

Errors: `url` not a single non-empty string; a local or private address.

## Examples

``` r
# Input is validated before any network call:
try(wbsnpnat(""))     # empty url -> error
#> Error : `url` must be a single non-empty string
try(wbsnpnat("http://localhost/report.csv"))
#> Error : url points at a local or private address ('http://localhost/report.csv'): refused (a single-label name is not a public host (localhost))
if (FALSE) { # interactive()
# needs the network; any network failure returns NULL rather than erroring.
# Closest archived snapshot of a live page (or NULL if none archived).
wbsnpnat("https://www.r-project.org/")

# A shorter timeout for a quick lookup.
wbsnpnat("https://cloud.r-project.org/", tmout = 10)

# A never-archived URL returns NULL rather than erroring.
wbsnpnat("https://example.invalid/never-archived")
}
```
