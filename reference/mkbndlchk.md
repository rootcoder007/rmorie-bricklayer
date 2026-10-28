# Check a reproducibility bundle before shipping it

Unzips a bundle built by
[`mkbndl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkbndl.md)
into a new folder, runs it the way a recipient would
(`Rscript setup_and_run.R --quick`) and reads the `manifest.json` the
run writes. The bundle passes when the run finishes, writes its
manifest, no cross-check is DIFFER and, on real data, the number of
checks and of passes is the one the `expected` block of its
`config.json` gives (`pass_csv` for a CSV input, `pass_real` for the
`.RData`). A run on synthetic data marks every check INFO, so it is not
compared with `expected`. A launcher (`start_here.sh`,
`START_HERE.command`) the zip does not mark executable is reported as a
warning: it still runs as `bash start_here.sh`.

## Usage

``` r
mkbndlchk(bundle, data = NULL, synthetic = FALSE, dir = NULL, keep = FALSE)
```

## Arguments

- bundle:

  Path to the bundle zip.

- data:

  Optional path to the data file, passed to the run as `--data`. `NULL`
  (default): the bundle finds the file, downloads it or, with
  `synthetic = TRUE`, generates data.

- synthetic:

  Run on synthetic data (`--synthetic`), default `FALSE`; needs no data
  file and no network.

- dir:

  A folder to unzip into, which must not exist yet. Default: a new
  folder under [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- keep:

  Keep that folder after the check, default `FALSE`.

## Value

An object of class `rmbl_bundle_audit`: a list with `ok`, `checks` (a
data frame of `check`, `ok`, `detail` and `severity`), `mode` (the input
the run used, from its manifest: `synthetic` when it is marked
synthetic, else its `meta$input_mode` when it records one, such as
`csv`, else `real`), `counts` (`total`, `pass`, `differ`, `info`), `log`
(the last 30 lines the run printed), `bundle` and `dir` (the unzipped
bundle, or `NA` once removed). It prints as a box.

## Details

Errors: `bundle` that is not an existing `.zip` file; a zip without
`setup_and_run.R`; `data` that is not an existing file; `dir` that
already exists.

## See also

[`mkbndl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkbndl.md)
builds the bundle;
[`mkbndlproj()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkbndlproj.md)
starts a project.

## Examples

``` r
proj <- file.path(tempdir(), "audit-demo")
mkbndlproj(proj, title = "Demo analysis")
#> ╭── Bundle project ───────────────────────────────────────────────────────────╮
#> │   Folder  /tmp/RtmpTOhCOh/audit-demo                                        │
#> │   Files   config.json, data_provenance.json, analysis.R                     │
#> │                                                                             │
#> │   Edit config.json (who and what), data_provenance.json (the data file,     │
#> │   its URL and SHA-256) and analysis.R (the checks), then build the zip      │
#> │   with mkbndl().                                                            │
#> │   It runs as it is on synthetic data, so the bundle can be tried before     │
#> │   the analysis is written.                                                  │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
b <- mkbndl(proj, dest = tempdir(), overwrite = TRUE)
a <- mkbndlchk(b$path, synthetic = TRUE)
a
#> ╭── Bundle audit: VERIFIED ───────────────────────────────────────────────────╮
#> │ ✔ VERIFIED  · 5 of 5 checks passed                                          │
#> │                                                                             │
#> │   Bundle      audit-demo_v1.zip                                             │
#> │   Input mode  synthetic                                                     │
#> │   Checks      2                                                             │
#> │   ✔           0                                                             │
#> │   DIFFER      0                                                             │
#> │   INFO        2                                                             │
#> │                                                                             │
#> │   Every check passed: the bundle runs as a recipient's copy will and is     │
#> │   safe to ship.                                                             │
#> │                                                                             │
#> │   ✔    run finished              exit status 0                              │
#> │   ✔    manifest written          /tmp/RtmpTOhCOh/bndlchk1f206bfd0d2f/audit- │
#> │                                  demo_v1/results_20261028-134752/manifest.j │
#> │                                  son                                        │
#> │   ✔    no cross-check differs    0 DIFFER                                   │
#> │   ✔    counts match config.json  not compared: a synthetic run              │
#> │   ✔    launchers executable      2 launcher(s)                              │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
a$counts
#>  total   pass differ   info 
#>      2      0      0      2 
```
