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
if (FALSE)  wayback_snapshot_url_native("https://www.r-project.org/")  # \dontrun{}
```
