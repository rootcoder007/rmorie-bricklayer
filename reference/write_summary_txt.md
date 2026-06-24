# Write a Plain-Language Run Summary

Writes a human-readable `SUMMARY.txt` into the output directory,
covering run metadata, the exact absolute paths used, result counts, the
files produced, and optional notes, contact, and licence lines.

## Usage

``` r
write_summary_txt(
  manifest,
  output_dir,
  paths,
  what_was_done = NULL,
  contact = NULL,
  licence = NULL
)
```

## Arguments

- manifest:

  A manifest as returned by
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md);
  its `meta` supplies project/author/run details.

- output_dir:

  Directory to write `SUMMARY.txt` into and to list produced files from.

- paths:

  A named list of absolute paths to report (e.g. `bundle`, `input`,
  `results`, `analysis_script`, `provenance`).

- what_was_done:

  Optional character vector of bullet points describing what the run
  did.

- contact:

  Optional contact string appended to the summary.

- licence:

  Optional licence string appended to the summary.

## Value

The path to the written `SUMMARY.txt`, returned invisibly.
