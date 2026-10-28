# Send a capture kept on this computer to the archives later

[`arccap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arccap.md)
keeps every capture on this computer first: the files, their SHA-256, a
manifest and, by default, a WARC copy. When the Wayback Machine,
archive.rmorie.com or archive.org is down, or there is no network but
the source's, the capture is still complete there. `arcpush()` sends
that same capture on later: the very files that were fetched, each
checked first against the SHA-256 the manifest recorded, so an archive
keeps what you captured, not a new download. Run it again to retry what
failed; what an archive already took is not sent twice.

The Wayback Machine takes no uploads: with `upload = "wayback"` it is
asked to capture each address itself, as the page is then. If the page
has changed since, its copy differs from yours, and your copy, with the
manifest's timestamp, remains the record of what you had.

A manifest with no timestamp yet (the authority was unreachable, or
`tsa = NULL` at capture) is stamped now when `tsa` is given; that
timestamp shows the files existed by now, not by the time they were
fetched.

Errors: `dir` without the `manifest.json` that
[`arccap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arccap.md)
writes, or a manifest that lists no files; nowhere to send (neither
`item` nor `upload`); as for
[`arccap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arccap.md)
for `item`, `meta`, `upload`, `reason`, `tmout` and the keys.

## Usage

``` r
arcpush(
  dir,
  item = NULL,
  meta = list(),
  ak = NULL,
  sk = NULL,
  upload = NULL,
  reason = NULL,
  visibility = c("public", "private"),
  tsa = "https://freetsa.org/tsr",
  tmout = 600L
)
```

## Arguments

- dir:

  The folder of an
  [`arccap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arccap.md)
  capture.

- item, meta, ak, sk, upload, reason, visibility, tmout:

  As for
  [`arccap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arccap.md).

- tsa:

  A time-stamping authority, asked only when the manifest has no
  timestamp yet (default as for
  [`arccap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arccap.md));
  `NULL` asks none.

## Value

An object of class `rmbl_archive_capture`, as
[`arccap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arccap.md)
returns: one row per file of the capture, with what each archive
answered, this time or an earlier one. A file that is missing, or whose
bytes no longer match the manifest, is `"failed: ..."` and is not sent.
What each archive took is also kept in `push.json` in `dir`, which the
next run reads.

## See also

[`arccap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arccap.md)
makes the capture;
[`wbsave()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md)
and
[`wbrtry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbrtry.md)
for the Wayback Machine alone;
[`fetchvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fetchvrf.md)
falls back to the copies.

## Examples

``` r
if (FALSE) { # interactive()
# capture now, on this computer only
src <- "https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip"
d <- file.path(tempdir(), "cap")
arccap(src, d, tsa = NULL)
# later, when the archives answer: the same bytes, sent on
arcpush(
  d,
  upload = c("rmorie", "wayback"),
  reason = "Custody table cited in chapter 3"
)
}
```
