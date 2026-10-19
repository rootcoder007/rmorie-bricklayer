# Capture files the Internet Archive cannot reach, and publish them as an archive.org item

Downloads each URL from here, records its SHA-256, size and time in a
manifest, timestamps the manifest with an RFC 3161 time-stamping
authority, and, with archive.org keys, uploads the files, the manifest
and its timestamp as one public archive.org item. The item is the mirror
that
[`fetchvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fetchvrf.md)
falls back to, and the timestamp shows that these were the bytes on that
date.

## Usage

``` r
arccap(
  urls,
  dir,
  item = NULL,
  meta = list(),
  tsa = "https://freetsa.org/tsr",
  ak = NULL,
  sk = NULL,
  tmout = 600L
)
```

## Arguments

- urls:

  URLs to capture, or a
  [`wbsave`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md)
  result (its refused URLs are taken).

- dir:

  A folder for the files and the manifest (created if needed).

- item:

  Optional archive.org item identifier (5 to 100 letters, digits, dots,
  hyphens, underscores) to upload to; `NULL` (default) captures without
  uploading.

- meta:

  Named metadata for a new item (`title`, `creator`, `licenseurl`,
  `description`, `subject`, ...); `mediatype` defaults to `"data"`.

- tsa:

  The time-stamping authority, or `NULL` for no timestamp (default
  `"https://freetsa.org/tsr"`).

- ak, sk:

  archive.org keys; default from the environment as
  [`wbsave`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md)
  reads them.

- tmout:

  Seconds allowed for each download and each upload (default 600).

## Value

A data frame of class `rmbl_archive_capture`, one row per URL: `url`,
`file`, `sha256`, `bytes`, `fetched_utc`, `status` (`"captured"`,
`"uploaded"` or `"failed: ..."`) and `mirror` (the archive.org download
address, for
[`fetchvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fetchvrf.md));
attributes `manifest`, `timestamp` (a
[`tsvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md)
result, or `NULL`) and `item`.

## Details

Some servers refuse the Internet Archive's crawler while serving
everyone else: Save Page Now then reports that the target "cannot find"
the page, or "blocks access" to it, although the page is there. Those
URLs cannot be put in the Wayback Machine, but they can be captured by
anyone who can reach them, and the capture can be published. Pass a
[`wbsave`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md)
result as `urls` to capture just the URLs it failed on with such a
refusal.

The manifest (`manifest.json`) lists, for each URL, the file, its
SHA-256, its size and the time it was fetched. The timestamp
(`manifest.tsr`) is the authority's signed statement that the manifest's
SHA-256 existed at its time;
[`tsvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md)
checks it, as does `openssl ts -verify`. Each file's digest in the
manifest ties the file to that time.

The upload uses the Internet Archive's S3-like API: each file is sent
with a PUT to `https://s3.us.archive.org/<item>/<file>`, streamed from
disk. The first request creates the item with the metadata given. The
keys are those of
[`wbsave`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md)
(`IA_S3_ACCESS_KEY` and `IA_S3_SECRET_KEY`, or their `_FILE` twins);
they travel only in the `authorization` header and are never written or
printed. Publish only what the source's licence lets you redistribute.

## References

Adams C, Cain P, Pinkas D, Zuccherato R (2001). Internet X.509 Public
Key Infrastructure Time-Stamp Protocol (TSP). RFC 3161.
[doi:10.17487/RFC3161](https://doi.org/10.17487/RFC3161)

Internet Archive. ias3: the Internet Archive's S3-like API.
<https://archive.org/developers/ias3.html>

## See also

[`fetchvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fetchvrf.md),
[`wbsave`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md),
[`tsvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md).

## Examples

``` r
if (FALSE) { # \dontrun{
w <- wbsave(urls)
lic <- "https://www.statcan.gc.ca/en/terms-conditions/open-licence"
meta <- list(title = "Statistics Canada tables (captures)",
             creator = "Statistics Canada", licenseurl = lic)
cap <- arccap(w, file.path(tempdir(), "capture"),
                       item = "my-statcan-tables-2026", meta = meta)
fetchvrf(cap$url[1], tempfile(), sha256 = cap$sha256[1],
               mirrors = cap$mirror[1])
} # }
```
