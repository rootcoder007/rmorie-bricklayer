# Fetch a URL to disk with an Internet Archive fallback (C++/libcurl)

The shared data-fetch foundation of the morie ecosystem. Downloads `url`
to `dest`; if the live download fails (404, network), it retries the
Wayback Machine snapshot – so a rotated or removed source file (CIHI,
open-data portals) stays retrievable. Backed by the package's C++
`rmbl_fetch_with_fallback` kernel (libcurl), which rmorie and morie
share through `LinkingTo`.

## Usage

``` r
bricklayer_fetch(url, dest, wayback = "", timeout = 120L)
```

## Arguments

- url:

  Live source URL.

- dest:

  Destination file path.

- wayback:

  Optional explicit Wayback snapshot URL. `""` (default) auto-resolves
  one via
  [`wayback_snapshot_url`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_snapshot_url.md).

- timeout:

  Per-request timeout, seconds.

## Value

Invisibly, one of `"live"`, `"wayback"`, or throws on total failure.

## Examples

``` r
if (FALSE) { # \dontrun{
dst <- tempfile(fileext = ".xlsx")
bricklayer_fetch(
  "https://www.cihi.ca/sites/default/files/document/hospital-beds-2024-2025-data-tables-en.xlsx",
  dst)
} # }
```
