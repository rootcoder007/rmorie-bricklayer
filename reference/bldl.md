# Download a file with live progress

Downloads one file from the web to a local path, showing a progress bar
(percent, size and rate) while a person is watching. It is the single
download routine of the package and its sibling packages, and it applies
the package's network safety rules: HTTPS only, no local or private
addresses, a size cap, and checked redirects. Use it when a script must
fetch a source file and you want a visible, safe transfer.

## Usage

``` r
bldl(
  url,
  dest,
  headers = NULL,
  label = basename(dest),
  size = NULL,
  tmout = 3600,
  quiet = NULL,
  tty = NULL,
  allowfile = FALSE,
  maxbytes = 2^31
)
```

## Arguments

- url:

  The URL: `https` (plain `http` only with
  `options(rmoriebricklayer.allowhttp = TRUE)`); a loopback, link-local
  or private address is refused.

- dest:

  Character string: the path to write.

- headers:

  Character vector of request headers, every element named (name =
  header, value = its value), or `NULL` (the default).

- label:

  Text shown in front of the bar; the file name by default.

- size:

  Expected size in bytes when known (a percent bar instead of a
  spinner); otherwise the size the server announces is used.

- tmout:

  Seconds allowed for the whole transfer: a whole number from 1 to
  2147483647, default 3600. A transfer slower than 64 bytes a second for
  30 seconds is ended before that.

- quiet:

  `TRUE`, `FALSE`, or `NULL` (the default) to follow the session and
  options.

- tty:

  Draw the live bar (`TRUE`) or print milestone lines (`FALSE`); `NULL`
  (the default) draws the bar when the console redraws a line in place,
  as described in Details.

- allowfile:

  Logical, default `FALSE`: accept a `file://` URL (for offline tests).

- maxbytes:

  Most bytes the body may have (default 2 GiB, the transport's ceiling).
  A body past it, chunked or not, ends the transfer with an error and
  leaves nothing behind: a caller that expects a small file should say
  so.

## Value

`dest`, invisibly.

## Details

Progress is an animated bar, redrawn in place, when the console can
redraw a line: a terminal, or the RStudio, Positron, R.app or RKWard
console (never a knitr or Jupyter notebook; the options
`rmoriebricklayer.dynamic` or `cli.dynamic`, or the environment variable
`R_CLI_DYNAMIC`, override the choice). In the RStudio or Positron
console the bar is drawn on stdout, elsewhere on stderr. Otherwise
milestone lines go to stderr (every 10 percent, or every 50 MB when the
size is unknown), and nothing is shown when quiet. By default output is
shown in an interactive session or when `options(morie.progress = TRUE)`
is set, and suppressed by `options(morie.quiet = TRUE)`.

Network: the transfer runs in the package's compiled HTTP client. The
URL is checked, its host resolved and pinned, and every redirect is
checked again (no switch from https to http; credentials are not passed
to another host). Plain `http://` is allowed only with
`options(rmoriebricklayer.allowhttp = TRUE)`. A transfer slower than 64
bytes a second for 30 seconds is abandoned. A `file://` URL is copied
locally through the same progress display, only with `allowfile = TRUE`.

Errors: a URL that is not https (or allowed http/file), or that points
at a loopback, link-local or private address; `headers` not a named
character vector; `tmout` below 1 or above 2147483647; `maxbytes` below
1; a network failure; an HTTP status of 400 or more; a body larger than
`maxbytes`. `dest` is overwritten.

## See also

[`blfetch`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blfetch.md)
for a download with a Wayback Machine fallback.

## Examples

``` r
# offline: a local file through the same routine
src <- tempfile(fileext = ".txt")
writeLines("hello", src)
dest <- tempfile(fileext = ".txt")
bldl(paste0("file://", src), dest, quiet = TRUE,
                    allowfile = TRUE)
readLines(dest)
#> [1] "hello"

# the safety checks run before any connection is made
try(bldl("http://example.org/table.csv", tempfile()))
#> Error : url must be an https:// URL, not http:// ('http://example.org/table.csv'); options(rmoriebricklayer.allowhttp = TRUE) admits a trusted plain-http mirror
try(bldl("https://127.0.0.1/table.csv", tempfile()))
#> Error : url points at a local or private address ('https://127.0.0.1/table.csv'): refused (a local or private address (127.0.0.1))
try(bldl(paste0("file://", src), tempfile()))
#> Error : url must be an https:// URL, not file:// ('file:///tmp/Rtmp1CrjBs/file1e2c3f4f1d7a.txt'); options(rmoriebricklayer.allowhttp = TRUE) admits a trusted plain-http mirror

# a real download needs the network
if (FALSE) { # \dontrun{
bldl("https://www.ontario.ca/some/open-data/table.csv",
                    "table.csv", maxbytes = 50e6)
} # }
```
