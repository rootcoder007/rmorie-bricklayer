# Fetch a file from its source or a mirror, verified by its SHA-256

Downloads `url` to `dest`, trying the source first (with its Wayback
Machine snapshot as the source's own fallback, as
[`blfetch`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blfetch.md)
does) and then each mirror in turn, and keeps the first copy whose
SHA-256 is `sha256`. A copy with another digest is never used: a changed
or truncated file is a different file.

## Usage

``` r
fetchvrf(
  url,
  dest,
  sha256 = NULL,
  mirrors = character(),
  tmout = 120L,
  arcs = "rmorie"
)
```

## Arguments

- url:

  The source URL (https).

- dest:

  Path the verified file is written to (by way of a `.part` file).

- sha256:

  The expected SHA-256, 64 hexadecimal characters, or `NULL`.

- mirrors:

  Further URLs that serve the same file, tried in order after the
  source.

- tmout:

  Seconds allowed for each download (default 120).

- arcs:

  Archives tried after the source, its Wayback snapshot and the mirrors:
  `"rmorie"` (archive.rmorie.com, by
  [`arcget`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arcget.md))
  and folders written by
  [`arccap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arccap.md)
  (read from their WARC files), in order.
  [`character()`](https://rdrr.io/r/base/character.html) tries none.

## Value

Invisibly, a list of class `rmbl_fetch` (it prints as a box): `source`
(`"live"`, `"wayback"`, `"mirror"`, `"rmorie"` or `"local"`), `url` (the
URL that served the kept copy), `sha256`, `bytes`, and `tried` (a data
frame of every attempt: `url`, `outcome`).

## Details

Some servers refuse the Internet Archive's crawler while serving
everyone else (Statistics Canada does), so a Wayback snapshot of their
files may not exist. The remedy is a capture made from elsewhere,
published as a mirror and pinned by its digest. It can be an Internet
Archive item, at `https://archive.org/download/` followed by
`<item>/<file>`; the data service; or an institutional repository.
Because the digest is checked, a mirror does not have to be trusted: a
copy that matches is the same bytes the analysis used, wherever it came
from.

Without `sha256` the first copy that downloads is kept and its digest is
returned, to be pinned for the next run.

## See also

[`blfetch`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blfetch.md),
[`sha256file`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256file.md),
[`wbsave`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md).

## Examples

``` r
if (FALSE) { # interactive()
# a Statistics Canada table the Wayback Machine cannot capture, with the
# archive.org copy made from elsewhere as a mirror
item <- paste0(
  "https://archive.org/download/rmorie-statc",
  "an-indigenous-tables-2026-10"
)
fetchvrf(
  "https://www150.statcan.gc.ca/n1/tbl/csv/41100063-eng.zip",
  file.path(tempdir(), "41100063-eng.zip"),
  mirrors = paste0(item, "/41100063-eng.zip")
)
}
```
