# Fetch an Ontario SIU director's report by drid

Downloads the HTML of one Ontario Special Investigations Unit (SIU)
director's report to `dest`, via
[`bricklayer_fetch`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch.md)
(live URL with a Wayback Machine fallback). This is the fetch step of
the open SIU corpus pipeline: pair it with the SIU parser in rmorie (or
the standalone `siu` C++ package) to rebuild the full director's-report
corpus yourself, then audit it with the multi-agent panel.

## Usage

``` r
bricklayer_fetch_siu(
  drid,
  dest,
  lang = c("en", "fr"),
  wayback = "",
  timeout = 120L
)
```

## Arguments

- drid:

  Director's-report id – the `drid=` query parameter (integer or
  integer-like scalar).

- dest:

  Destination file path for the fetched HTML.

- lang:

  `"en"` (default) or `"fr"`.

- wayback:

  Optional explicit Wayback snapshot URL (passed through to
  `bricklayer_fetch`); `""` lets it discover one.

- timeout:

  Request timeout in seconds. Default 120.

## Value

`"live"` or `"wayback"` (invisibly), as `bricklayer_fetch`.

## See also

[`bricklayer_fetch`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Fetch report drid 648 to a temp file.
dest <- tempfile(fileext = ".html")
bricklayer_fetch_siu(648, dest)
} # }
```
