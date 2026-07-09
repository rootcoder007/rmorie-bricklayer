# Re-Verify an Entire Reproducible Data Capsule

Runs the full custody chain over a capsule directory in one call: the
provenance manifest is readable, the pinned data file exists and matches
its recorded `sha256` (and `size_bytes` / row count where recorded), the
schema still validates, a recorded analysis script still matches its
pinned hash, and every numeric cross-check stored in a results manifest
still reproduces its recorded `PASS`/`DIFFER` status from its own
`observed`/`expected`/`tol` fields.

## Usage

``` r
verify_capsule(
  capsule_dir,
  provenance_file = "data_provenance.json",
  data_file = NULL,
  manifest_file = NULL,
  script_file = NULL
)
```

## Arguments

- capsule_dir:

  Directory containing the capsule.

- provenance_file:

  Provenance JSON filename inside `capsule_dir` (default
  `"data_provenance.json"`).

- data_file:

  Data filename inside `capsule_dir`. Defaults to the provenance's
  `resource$filename`.

- manifest_file:

  Optional results-manifest JSON (as written by
  [`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md))
  inside `capsule_dir`; checked when present.

- script_file:

  Optional analysis-script filename inside `capsule_dir`; compared
  against the manifest's recorded `meta$script_sha256` when both are
  present.

## Value

A list with `ok` (logical scalar: every check passed) and `checks`
(data.frame with columns `check`, `ok`, `detail`).

## Details

Entirely offline: nothing is downloaded and nothing is written.

## Examples

``` r
dir <- file.path(tempdir(), "capsule-example")
dir.create(dir, showWarnings = FALSE)
write.csv(data.frame(id = 1:3), file.path(dir, "d.csv"), row.names = FALSE)
prov <- list(resource = list(filename = "d.csv",
                             sha256 = sha256_file(file.path(dir, "d.csv"))))
jsonlite::write_json(prov, file.path(dir, "data_provenance.json"),
                     auto_unbox = TRUE)
verify_capsule(dir)$ok
#> [1] TRUE
```
