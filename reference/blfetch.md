# Fetch a URL to disk with an Internet Archive fallback (C++/libcurl)

The shared data-fetch foundation of the morie ecosystem. Downloads `url`
to `dest`; if the live download fails (404, network), it retries the
Wayback Machine snapshot – so a rotated or removed source file (CIHI,
open-data portals) stays retrievable. Backed by the package's C++ kernel
`rmbl_fetch_with_fallback` (libcurl), which rmorie and morie share
through `LinkingTo`. The return value says which source served the file,
so a report can note that it used an archived copy.

## Usage

``` r
blfetch(url, dest, wb = "", tmout = 120L)
```

## Arguments

- url:

  Live source URL, a single `https` string.

- dest:

  Destination file path, a single string; its directory must exist.

- wb:

  Optional explicit Wayback snapshot URL, a string. `""` (default) or
  `NULL` auto-resolves one via
  [`wbsnpurl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsnpurl.md)'s
  API when the live download fails.

- tmout:

  Per-request timeout in seconds, a positive whole number (default 120).

## Value

Invisibly, `"live"` or `"wayback"`: the source that served the file.
Throws on total failure.

## Details

Before any network use the arguments are checked: `url` must be one
`https` URL to a public host (plain `http` only when the option
`rmoriebricklayer.allowhttp` is `TRUE`; loopback, private, link-local
and metadata addresses are refused), the directory of `dest` must exist
and be writable, and `tmout` must be at least one second. The compiled
layer then resolves the host, pins the connection to the checked
addresses and re-checks every redirect.

If the live download fails, the fallback is the `wb` URL when given,
else a snapshot looked up through the Wayback availability API (as
[`wbsnpnat()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsnpnat.md)
does). `dest` is overwritten. A spinner is drawn on stderr while
waiting, unless `options(morie.quiet = TRUE)`.

Errors: invalid arguments as above; and, when both sources fail, an
error saying whether the live URL could not be reached or answered an
HTTP status, and whether the Wayback Machine had no snapshot or its copy
could not be downloaded.

## Examples

``` r
# Inputs are validated before any network access:
try(blfetch("", tempfile()))          # empty url -> error
#> Error : `url` must be one non-empty URL string
try(blfetch("ftp://example.org/data.csv", tempfile()))
#> Error : blfetch: 'ftp://example.org/data.csv' is not an http(s) URL
try(blfetch("https://127.0.0.1/data.csv", tempfile()))
#> Error : url points at a local or private address ('https://127.0.0.1/data.csv'): refused (a local or private address (127.0.0.1))
try(blfetch("https://example.org/data.csv",
                     file.path(tempdir(), "no-such-dir", "data.csv")))
#> Error : blfetch: cannot write /tmp/RtmpMK7Ka6/no-such-dir/data.csv (its directory does not exist)

if (FALSE) { # interactive()
# needs the network
dst <- tempfile(fileext = ".xlsx")

# Live download; auto-resolves a Wayback snapshot only if the live URL fails.
blfetch(
  paste0("https://www.cihi.ca/sites/default/files/document/",
         "hospital-beds-2024-2025-data-tables-en.xlsx"),
  dst)

# Pin an explicit Wayback snapshot to fall back to, and a shorter timeout.
blfetch(
  "https://example.org/rotated-file.csv", tempfile(fileext = ".csv"),
  wb = "https://web.archive.org/web/2024id_/https://example.org/rotated-file.csv",
  tmout = 60)

# The return value tells you which source served the file.
status <- blfetch("https://cloud.r-project.org/", tempfile())
status   # "live" or "wayback"
}
```
