# Download a File

Downloads through the package's own transport,
[`bricklayer_download()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_download.md):
the URL checked and pinned, every redirect hop re-checked, the body
capped, a live progress bar. Returns the target path invisibly so it
composes in pipelines.

## Usage

``` r
download_data(url, target_path, mode = "wb", quiet = FALSE, allow_file = FALSE)
```

## Arguments

- url:

  URL to download.

- target_path:

  Destination path on disk.

- mode:

  Kept for the signature of
  [`utils::download.file()`](https://rdrr.io/r/utils/download.file.html);
  only `"wb"` (or `"w"`) is accepted. Every transfer is binary and
  written fresh through the package's own transport, so an append mode
  cannot be honoured and is an error rather than a silent `"wb"`.

- quiet:

  Logical; suppress progress output. Defaults to `FALSE`.

- allow_file:

  Accept a `file://` URL (default `FALSE`; an offline test passes
  `TRUE`). Every URL must otherwise be `https` and public.

## Value

The `target_path`, returned invisibly.

## Examples

``` r
# \donttest{
# try(): a live download must fail gracefully on an offline check machine.
dest <- try(download_data("https://cloud.r-project.org/",
  tempfile(fileext = ".html"),
  quiet = TRUE
))
if (!inherits(dest, "try-error")) file.exists(dest)
#> [1] TRUE
# }
```
