# Fetch the exact bytes of a saved copy from archive.rmorie.com

Downloads a capture's bytes and checks their SHA-256: against the
archive's record, and against `sha256` when you give one (the pin from
your analysis). A file that does not match is deleted.

## Usage

``` r
arcget(x, dest, sha256 = NULL, at = NULL, tmout = 600L)
```

## Arguments

- x:

  A capture id (`"20261021133005-1a2b3c4d"`, from
  [`arcfind`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arcfind.md)
  or a capture page) or a web address; for an address, the capture
  closest to `at` (default: the latest) is taken.

- dest:

  The file to write.

- sha256:

  Optional SHA-256 the bytes must have.

- at:

  For an address, the time to be closest to, `"YYYY..."` up to 14 digits
  (UTC).

- tmout:

  Seconds allowed for the download.

## Value

`dest`, invisibly, with attributes `capture_id`, `url`, `captured` and
`sha256`.

## See also

[`arcfind`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arcfind.md),
[`fetchvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fetchvrf.md)
(which falls back to the archive on its own).

## Examples

``` r
if (FALSE) { # interactive()
f <- arcget("https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip", tempfile(fileext = ".zip"))
attr(f, "sha256")
}
```
