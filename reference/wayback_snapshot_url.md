# Resolve a Wayback Machine snapshot URL

Queries the Internet Archive availability API
(`http://archive.org/wayback/available`) for the closest archived
snapshot of `url` and returns a directly-downloadable snapshot URL, or
`NULL` if no snapshot exists or the lookup fails. This is the shared
fetch failsafe the wider morie package family relies on: callers attempt
the live source first and fall back to this snapshot when the source is
unreachable.

## Usage

``` r
wayback_snapshot_url(url, timestamp = NULL)
```

## Arguments

- url:

  The original source URL to look up.

- timestamp:

  Optional 14-digit `YYYYMMDDhhmmss` target; the API returns the
  snapshot closest to it. Defaults to the most recent.

## Value

A character scalar snapshot URL, or `NULL`.

## Examples

``` r
# \donttest{
wayback_snapshot_url("https://www.r-project.org/")
#> Warning: cannot open URL 'http://archive.org/wayback/available?url=https%3A%2F%2Fwww.r-project.org%2F': HTTP status was '503 Service Unavailable'
#> NULL
# }
```
