# Find saved copies of an address in archive.rmorie.com

Lists the captures the archive holds of a web address, oldest first:
when each was taken, its HTTP status, media type, size and SHA-256, and
the addresses to open or download it. An address ending in `*` lists
every address that starts with it. Public captures are listed for
anyone; with your key (see
[`dlogin`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dlogin.md))
your private ones are listed too.

## Usage

``` r
arcfind(url, from = NULL, to = NULL, limit = 1000L)
```

## Arguments

- url:

  A web address, or the start of one followed by `*`.

- from, to:

  Optional limits on the capture time, as `"YYYY"`, `"YYYYMM"` ... up to
  `"YYYYMMDDhhmmss"` (UTC).

- limit:

  The most captures to list (default 1000).

## Value

A data frame of class `rmbl_archive_find`: `capture_id`, `captured` (UTC
time), `url`, `status`, `mime`, `bytes`, `sha256`, `mode` (`"client"`:
saved from the capturer's connection; `"worker"`: saved by the archive),
`visibility`, `capture` (its page) and `replay` (its exact bytes).

## Details

The archive answers the same CDX query as the Wayback Machine
(`/cdx/search/cdx?url=...&output=json`), so tools written for it can
read it as well. Set `MORIE_ARCHIVE_URL` to query another archive that
speaks the same protocol, with its key in `MORIE_ARCHIVE_KEY`.

## See also

[`arcget`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arcget.md),
[`arccap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arccap.md),
[`fetchvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fetchvrf.md).

## Examples

``` r
if (FALSE) { # interactive()
caps <- arcfind("https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip")
caps
arcfind("www150.statcan.gc.ca/n1/tbl/*")
}
```
