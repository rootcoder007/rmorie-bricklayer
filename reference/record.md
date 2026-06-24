# Record a Cross-Check Result in a Manifest

Appends one named cross-check entry to a manifest, classifying it as
`PASS`, `DIFFER`, or `INFO`, printing a formatted line to the console,
and returning the updated manifest.

## Usage

``` r
record(
  manifest,
  name,
  observed,
  expected,
  tol = 1e-04,
  group = "general",
  synthetic = FALSE
)
```

## Arguments

- manifest:

  A manifest as returned by
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md).

- name:

  Unique name for this cross-check; used as the result key.

- observed:

  The observed value (numeric or otherwise).

- expected:

  The expected value to compare against.

- tol:

  Numeric tolerance; a numeric pair within `tol` is `PASS`. Defaults to
  `0.0001`.

- group:

  Optional grouping label for the entry. Defaults to `"general"`.

- synthetic:

  Logical; if `TRUE` the entry is marked `INFO` because comparison
  against synthetic data is not meaningful.

## Value

The updated manifest, returned so calls can be chained.
