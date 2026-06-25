# Download a File With Diagnostic Error Messages

Wraps
[`utils::download.file()`](https://rdrr.io/r/utils/download.file.html)
and, on failure, prints plain-language guidance for the most common
academic and corporate network problems (rate limiting, TLS-inspection
VPNs, DNS failures, timeouts, HTTP 403). Optionally retries from a
Wayback Machine snapshot URL.

## Usage

``` r
friendly_download(url, target_path, attempt_wayback = NULL)
```

## Arguments

- url:

  URL to download.

- target_path:

  Destination path on disk.

- attempt_wayback:

  Wayback Machine snapshot URL tried as a fallback if the primary
  download fails. When `NULL` (the default) a snapshot is resolved
  automatically via
  [`wayback_snapshot_url()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_snapshot_url.md);
  pass an explicit URL to override the lookup, or `""` to disable the
  fallback entirely.

## Value

`TRUE` if either the primary download or the Wayback fallback succeeds,
otherwise `FALSE`.
