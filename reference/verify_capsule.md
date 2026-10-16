# Re-Verify an Entire Reproducible Data Capsule

Runs the full custody chain over a capsule directory in one call and
reports, check by check, whether the capsule is still the one the
analysis was run on: the provenance record is readable, the pinned data
file is present and has its recorded SHA-256, the schema still
validates, a recorded analysis script still has its pinned hash, every
numeric cross-check in a results manifest still reproduces its recorded
verdict, and the data are real rather than synthetic. Use it before
re-running or publishing an analysis, or when receiving a capsule from
someone else.

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

  Directory containing the capsule, a single string.

- provenance_file:

  Provenance JSON filename, relative to `capsule_dir` (default
  `"data_provenance.json"`).

- data_file:

  Data filename relative to `capsule_dir`. `NULL` (the default) uses the
  provenance's `resource$filename`.

- manifest_file:

  Optional results-manifest JSON (as written by
  [`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md)),
  relative to `capsule_dir`. `NULL` (the default) uses `manifest.json`
  when the capsule has one.

- script_file:

  Optional analysis-script filename relative to `capsule_dir`; compared
  against the pinned script digest. `NULL` (the default) uses the script
  named in the provenance or the manifest, if any.

## Value

An object of class `c("bricklayer_capsule_check", "list")`, printed as
one line per check:

- `ok`:

  logical scalar, the overall verdict described in Details.

- `checks`:

  data.frame with columns `check` (character, the check name), `ok`
  (logical) and `detail` (character: the path checked, the digest found,
  or why it failed).

- `required`:

  character, the checks that had to be made.

- `missing`:

  character, required checks that were never made (`character(0)` when
  none).

## Details

The checks, in the order they appear in `checks`:

- `provenance_readable`:

  `provenance_file` is a plain relative path inside the capsule (no
  `..`, no absolute path, no symlink out) and parses as JSON.

- `data_present`:

  the data file (`data_file`, else the provenance's `resource$filename`)
  is inside the capsule and is a file.

- `data_sha256`:

  its SHA-256 equals `resource$sha256` (64 hex characters), compared by
  [`verify_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_sha256.md).

- `data_size_bytes`:

  when `resource$size_bytes` is recorded: the size on disk matches.

- `data_readable`:

  a `.csv` file is read with
  [`utils::read.csv()`](https://rdrr.io/r/utils/read.table.html); a
  non-CSV file fails this row when a row count or schema is recorded
  (they cannot be checked).

- `data_row_count`:

  when `resource$row_count_data_rows` is recorded: the CSV has that many
  rows.

- `schema_valid`:

  when a `schema` is recorded:
  [`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
  finds no fatal issue (warnings are listed in `detail` but pass).

- `manifest_consistent`:

  when `manifest_file` is given, or the capsule holds `manifest.json`:
  every result with numeric `observed` and `expected`, a `tol` and a
  status of `PASS` or `DIFFER` still gets that status from
  \\\|observed - expected\| \le tol\\.

- `script_sha256`:

  when a script is named (`script_file`, `script$filename` in the
  provenance or `meta$script_file` in the manifest) or a script digest
  is pinned (`meta$script_sha256` or `script$sha256`): the script's
  SHA-256 matches the pin.

- `data_not_synthetic`:

  no `<data>.synthetic` sidecar (written by
  [`make_synthetic_csv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_csv.md)),
  and neither the manifest nor the provenance records
  `synthetic = true`.

A check that cannot be made because the provenance lacks a field is a
FAILED row, never skipped: a provenance of
[`{}`](https://rdrr.io/r/base/Paren.html) verifies nothing. `ok` is
`TRUE` only when every row passed and every required check
(`provenance_readable`, `data_present`, `data_sha256`,
`data_not_synthetic`, plus `manifest_consistent` and `script_sha256`
when a manifest or a script is in play) was made.

Entirely offline: nothing is downloaded and nothing is written. Error:
`capsule_dir` that is not one existing directory. Every other problem is
a failed row, not an error.

## Examples

``` r
dir <- file.path(tempdir(), "capsule-example")
dir.create(dir, showWarnings = FALSE)
write.csv(data.frame(id = 1:3), file.path(dir, "d.csv"), row.names = FALSE)
prov <- list(resource = list(filename = "d.csv",
                             sha256 = sha256_file(file.path(dir, "d.csv")),
                             row_count_data_rows = 3),
             schema = list(expected_columns = "id"))
writeLines(bricklayer_json_to_json(prov, auto_unbox = TRUE),
           file.path(dir, "data_provenance.json"))
verify_capsule(dir)$ok
#> [1] TRUE
verify_capsule(dir)
#> Capsule verification: intact (7 of 7 checks passed)
#>   ok    provenance_readable  /tmp/Rtmp1nz8V4/capsule-example/data_provenance.json
#>   ok    data_present         /tmp/Rtmp1nz8V4/capsule-example/d.csv
#>   ok    data_sha256          da4aaa3a009d063f36d0515f2b50a11bcc578264aa7c45504b46fedbbae4f8f7
#>   ok    data_readable        /tmp/Rtmp1nz8V4/capsule-example/d.csv
#>   ok    data_row_count       3 rows on disk
#>   ok    schema_valid         
#>   ok    data_not_synthetic   no synthetic marker: sidecar, manifest and provenance all say real data

# an edited data file fails its digest and its row count
write.csv(data.frame(id = 1:4), file.path(dir, "d.csv"), row.names = FALSE)
chk <- verify_capsule(dir)
chk$ok
#> [1] FALSE
chk$checks[!chk$checks$ok, c("check", "detail")]
#>            check
#> 3    data_sha256
#> 5 data_row_count
#>                                                                                                                                            detail
#> 3 expected da4aaa3a009d063f36d0515f2b50a11bcc578264aa7c45504b46fedbbae4f8f7, got b24bb2c082053f4d1f5db97140babb86d4cc7e31b49be4e3c4cf94ca87a86d2b
#> 5                                                                                                                                  4 rows on disk

# a path out of the capsule is a failed check, not a read
verify_capsule(dir, provenance_file = "../elsewhere.json")$ok
#> [1] FALSE

# a missing directory is an error
try(verify_capsule(file.path(tempdir(), "no-such-capsule")))
#> Error : `capsule_dir` is not an existing directory: /tmp/Rtmp1nz8V4/no-such-capsule
unlink(dir, recursive = TRUE)
```
