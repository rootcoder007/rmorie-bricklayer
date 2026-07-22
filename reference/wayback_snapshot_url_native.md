# Resolve a Wayback Machine snapshot URL (C++/libcurl)

Queries the Internet Archive “available” API for the closest archived
snapshot of `url`. C++ backend; supersedes the older jsonlite-based
resolver (kept internally for offline use).

## Usage

``` r
wayback_snapshot_url_native(url, timeout = 30L)
```

## Arguments

- url:

  URL to resolve.

- timeout:

  Request timeout, seconds.

## Value

The https snapshot URL, or `NULL` if none is archived.

## Examples

``` r
# Input is validated before any network call:
try(wayback_snapshot_url_native(""))     # empty url -> error
#> Error in wayback_snapshot_url_native("") : nzchar(url) is not TRUE

# \donttest{
# Uses the live Wayback service; degrades gracefully offline: any
# network failure returns NULL rather than erroring.
# Closest archived snapshot of a live page (or NULL if none archived).
wayback_snapshot_url_native("https://www.r-project.org/")
#> [1] "https://web.archive.org/web/20260717171813/https://www.r-project.org/"

# A shorter timeout for a quick lookup.
wayback_snapshot_url_native("https://cloud.r-project.org/", timeout = 10)
#> NULL

# A never-archived URL returns NULL rather than erroring.
wayback_snapshot_url_native("https://example.invalid/never-archived")
#> NULL
# }
```
