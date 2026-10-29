# Construct a Reproducibility Manifest

Creates an empty manifest: the record of one analysis run that collects
the run's metadata, the cross-checks of its results against expected
values (added with
[`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md)),
and optionally a snapshot of the R environment it ran in. Write it out
with
[`wrmnfjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrmnfjs.md)
and
[`wrsmrytxt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrsmrytxt.md),
or hash and sign it with
[`mnfdgst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md)
and
[`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md),
so a reader can later see what was run, where, and whether the numbers
matched.

## Usage

``` r
mkmnf(meta, env = TRUE)
```

## Arguments

- meta:

  A list of run metadata, normally named (for example `project`,
  `author`, `run_at`, `synthetic`). May be
  [`list()`](https://rdrr.io/r/base/list.html).

- env:

  Logical scalar; when `TRUE` (the default) the manifest also records
  the analysis environment via
  [`capenv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capenv.md):
  R version, platform, OS, UTC timestamp, random number generator kind
  and whether it was seeded, and the version of every loaded package.
  Any other value leaves it out.

## Value

A list with elements `meta` (the list given, plus `synthetic = TRUE`
when flagged), `results` (an empty list, filled by
[`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md))
and, when `environment = TRUE`, `environment` (the list from
[`capenv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capenv.md)).
The list has class `c("rmbl_manifest", "list")`, which only changes how
it prints (a box); its elements, and the JSON written from it, are those
of a plain list.

## Details

The manifest is a plain list, so you can add your own elements to `meta`
before writing it. The package owns the synthetic-data flag:
`meta$synthetic` is set to `TRUE` when you pass it, when the environment
variable `BRICKLAYER_SYNTHETIC` is set to a value other than `0`,
`false`, `no` or `off`, or when the package generated synthetic data
earlier in the session. It is written only when `TRUE`, so a manifest of
real data keeps the digest it had before the flag existed. On a
synthetic manifest every
[`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md)
entry is `INFO`.

The fields of `meta` that
[`wrsmrytxt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrsmrytxt.md)
reads are `project`, `author`, `run_at`, `os`, `r_version` and, as a
named list or vector of versions, `r_package_versions`.

Errors when `meta` is not a list. Nothing is written.

## See also

[`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md),
[`wrmnfjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrmnfjs.md),
[`wrsmrytxt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrsmrytxt.md),
[`mnfdgst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md).

## Examples

``` r
# Minimal manifest, no environment capture.
man <- mkmnf(list(project = "demo-study", author = "A. Author"),
  env = FALSE
)
names(man) # "meta" "results"
#> [1] "meta"    "results"
man$meta$project
#> [1] "demo-study"

# With environment = TRUE it also records R version / platform / packages.
full <- mkmnf(list(project = "demo"), env = TRUE)
names(full) # adds "environment"
#> [1] "meta"        "results"     "environment"
full$environment$r_version
#> [1] "4.6.2"

# a run on generated data is flagged, and its checks become INFO
syn <- mkmnf(list(project = "demo", synthetic = TRUE), env = FALSE)
syn$meta$synthetic
#> [1] TRUE

# meta must be a list
try(mkmnf("demo"))
#> Error : `meta` must be a list
```
