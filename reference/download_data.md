# Download a File

Downloads one file to a path on disk through the package's own
transport,
[`bricklayer_download()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_download.md),
and returns the path. It is the plain download step of a data pipeline:
resolve a URL (for example with
[`resolve_via_ckan()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_ckan.md)),
download it with this function, then check it with
[`verify_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_sha256.md).
Use
[`friendly_download()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/friendly_download.md)
instead when a person should see advice about the failure and a Wayback
Machine fallback.

## Usage

``` r
download_data(url, target_path, mode = "wb", quiet = FALSE, allow_file = FALSE)
```

## Arguments

- url:

  The URL to download, a single string.

- target_path:

  Destination path on disk, a single string. Its directory must exist.

- mode:

  Kept for the signature of
  [`utils::download.file()`](https://rdrr.io/r/utils/download.file.html);
  only `"wb"` (the default) or `"w"` is accepted. Every transfer is
  binary and written fresh through the package's own transport, so an
  append mode cannot be honoured and is an error rather than a silent
  `"wb"`.

- quiet:

  Logical. `TRUE` suppresses the progress output; `FALSE` (the default)
  shows it.

- allow_file:

  Logical. Accept a `file://` URL (default `FALSE`; offline tests and
  examples pass `TRUE`). Every URL must otherwise be `https` and public.

## Value

The `target_path`, returned invisibly.

## Details

Before anything is fetched the URL must be one public `https` URL: plain
`http` needs `options(rmoriebricklayer.allow_http = TRUE)`, `file://`
needs `allow_file = TRUE`, and loopback, private, link-local and
cloud-metadata addresses are refused. The transport then resolves the
host, pins the connection to the checked addresses, re-checks every
redirect hop, caps the body at 2 GiB and allows 3600 seconds for the
transfer. The file at `target_path` is overwritten. Errors from the
transfer (network, HTTP status, size cap) propagate as R errors; nothing
partial is left behind.

Progress is drawn on stderr while `quiet = FALSE`, whatever the
`morie.quiet` option says, because the value is passed to the transport
explicitly.

Errors: `url` or `target_path` not a single non-empty string; a refused
URL; `mode` other than `"wb"` or `"w"`.

## Examples

``` r
# offline: a local file through a file:// URL
src <- tempfile(fileext = ".csv")
writeLines(c("id,value", "1,10", "2,20"), src)
dest <- download_data(paste0("file://", src), tempfile(fileext = ".csv"),
  quiet = TRUE, allow_file = TRUE)
read.csv(dest)
#>   id value
#> 1  1    10
#> 2  2    20

# file:// is refused unless asked for, and so is an append mode
try(download_data(paste0("file://", src), tempfile()))
#> Error : url must be an https:// URL, not file:// ('file:///tmp/RtmpgjAb8K/file1dfe46897ad2.csv'); options(rmoriebricklayer.allow_http = TRUE) admits a trusted plain-http mirror
try(download_data("https://example.org/x.csv", tempfile(), mode = "a"))
#> Error : `mode` must be "wb" (every transfer is binary)
if (FALSE) { # \dontrun{
# needs the network
dest <- download_data("https://cloud.r-project.org/",
  tempfile(fileext = ".html"),
  quiet = TRUE
)
file.exists(dest)
} # }
```
