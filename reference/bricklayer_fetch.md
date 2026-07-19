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
# Inputs are validated before any network access:
try(bricklayer_fetch("", tempfile()))          # empty url -> error
#> Error in bricklayer_fetch("", tempfile()) : nzchar(url) is not TRUE

if (FALSE) { # \dontrun{
dst <- tempfile(fileext = ".xlsx")

# Live download; auto-resolves a Wayback snapshot only if the live URL fails.
bricklayer_fetch(
  "https://www.cihi.ca/sites/default/files/document/hospital-beds-2024-2025-data-tables-en.xlsx",
  dst)

# Pin an explicit Wayback snapshot to fall back to, and a shorter timeout.
bricklayer_fetch(
  "https://example.org/rotated-file.csv", tempfile(fileext = ".csv"),
  wayback = "https://web.archive.org/web/2024id_/https://example.org/rotated-file.csv",
  timeout = 60)

# The return value tells you which source served the file.
status <- bricklayer_fetch("https://cloud.r-project.org/", tempfile())
status   # "live" or "wayback"
} # }
```
