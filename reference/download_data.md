# Download a File

Thin wrapper around
[`utils::download.file()`](https://rdrr.io/r/utils/download.file.html)
that returns the target path invisibly so it composes in pipelines.

## Usage

``` r
download_data(url, target_path, mode = "wb", quiet = FALSE)
```

## Arguments

- url:

  URL to download.

- target_path:

  Destination path on disk.

- mode:

  Write mode passed to
  [`utils::download.file()`](https://rdrr.io/r/utils/download.file.html);
  defaults to `"wb"` (binary) for cross-platform safety.

- quiet:

  Logical; suppress progress output. Defaults to `FALSE`.

## Value

The `target_path`, returned invisibly.
