# Download a file with live progress

One download routine for the MORIE family: a bar with percent, size and
rate on stderr while a person is watching (an interactive session, or a
command line that sets `options(morie.progress = TRUE)`), milestone
lines when stderr is not a terminal, and nothing when
`options(morie.quiet = TRUE)` or `quiet = TRUE`.

## Usage

``` r
bricklayer_download(
  url,
  dest,
  headers = NULL,
  label = basename(dest),
  size = NULL,
  timeout = 3600,
  quiet = NULL,
  tty = NULL,
  allow_file = FALSE
)
```

## Arguments

- url:

  The URL: `https` (plain `http` only with
  `options(rmoriebricklayer.allow_http = TRUE)`); a loopback, link-local
  or private address is refused.

- dest:

  Path to write.

- headers:

  Named character vector of request headers, or `NULL`.

- label:

  Text shown in front of the bar; the file name by default.

- size:

  Expected size in bytes when known (a percent bar instead of a
  spinner).

- timeout:

  Seconds allowed for the whole transfer.

- quiet:

  `TRUE`, `FALSE`, or `NULL` to follow the session and options.

- tty:

  Draw the live bar (`TRUE`) or print milestone lines (`FALSE`); `NULL`
  asks whether stderr is a terminal.

- allow_file:

  Accept a `file://` URL (default `FALSE`).

## Value

`dest`, invisibly.

## Examples

``` r
src <- tempfile(fileext = ".txt")
writeLines("hello", src)
dest <- tempfile(fileext = ".txt")
bricklayer_download(paste0("file://", src), dest, quiet = TRUE,
                    allow_file = TRUE)
readLines(dest)
#> [1] "hello"
```
