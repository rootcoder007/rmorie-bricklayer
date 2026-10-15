# Construct a Reproducibility Manifest

Creates an empty manifest: the record of one analysis run that collects
the run's metadata, the cross-checks of its results against expected
values (added with
[`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md)),
and optionally a snapshot of the R environment it ran in. Write it out
with
[`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md)
and
[`write_summary_txt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_summary_txt.md),
or hash and sign it with
[`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md)
and
[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md),
so a reader can later see what was run, where, and whether the numbers
matched.

## Usage

``` r
make_manifest(meta, environment = TRUE)
```

## Arguments

- meta:

  A list of run metadata, normally named (for example `project`,
  `author`, `run_at`, `synthetic`). May be
  [`list()`](https://rdrr.io/r/base/list.html).

- environment:

  Logical scalar; when `TRUE` (the default) the manifest also records
  the analysis environment via
  [`capture_environment()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_environment.md):
  R version, platform, OS, UTC timestamp, random number generator kind
  and whether it was seeded, and the version of every loaded package.
  Any other value leaves it out.

## Value

A list with elements `meta` (the list given, plus `synthetic = TRUE`
when flagged), `results` (an empty list, filled by
[`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md))
and, when `environment = TRUE`, `environment` (the list from
[`capture_environment()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_environment.md)).

## Details

The manifest is a plain list, so you can add your own elements to `meta`
before writing it. The package owns the synthetic-data flag:
`meta$synthetic` is set to `TRUE` when you pass it, when the environment
variable `BRICKLAYER_SYNTHETIC` is set to a value other than `0`,
`false`, `no` or `off`, or when the package generated synthetic data
earlier in the session. It is written only when `TRUE`, so a manifest of
real data keeps the digest it had before the flag existed. On a
synthetic manifest every
[`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md)
entry is `INFO`.

Fields of `meta` that
[`write_summary_txt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_summary_txt.md)
reads: `project`, `author`, `run_at`, `os`, `r_version` and
`r_package_versions` (a named list or vector of versions).

Errors when `meta` is not a list. Nothing is written.

## See also

[`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md),
[`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md),
[`write_summary_txt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_summary_txt.md),
[`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md).

## Examples

``` r
# Minimal manifest, no environment capture.
man <- make_manifest(list(project = "demo-study", author = "A. Author"),
  environment = FALSE
)
names(man) # "meta" "results"
#> [1] "meta"    "results"
man$meta$project
#> [1] "demo-study"

# With environment = TRUE it also records R version / platform / packages.
full <- make_manifest(list(project = "demo"), environment = TRUE)
names(full) # adds "environment"
#> [1] "meta"        "results"     "environment"
full$environment$r_version
#> [1] "4.6.1"

# a run on generated data is flagged, and its checks become INFO
syn <- make_manifest(list(project = "demo", synthetic = TRUE), environment = FALSE)
syn$meta$synthetic
#> [1] TRUE

# meta must be a list
try(make_manifest("demo"))
#> Error : `meta` must be a list
```
