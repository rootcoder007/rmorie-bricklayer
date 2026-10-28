# Start a Reproducibility Bundle Project

Writes a starter project that
[`mkbndl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkbndl.md)
packs as it is: a `config.json` with the project's details, a
`data_provenance.json` to pin the data file and describe synthetic data,
and an `analysis.R` that reads the data, records its checks with
[`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md)
and writes `manifest.json`. Edit the three files for the real project;
the starter runs from the first build, on synthetic data, so every step
can be tried before the analysis is written.

## Usage

``` r
mkbndlproj(
  dir,
  name = basename(dir),
  title = name,
  author = "",
  contact = "",
  overwrite = FALSE
)
```

## Arguments

- dir:

  Folder for the project, created if needed.

- name:

  Short project name used in the zip's name, default the folder's name.

- title:

  Title shown in the bundle's pages, default `name`.

- author, contact:

  Who the reviewer contacts; default empty.

- overwrite:

  Replace starter files that exist, default `FALSE`.

## Value

An object of class `rmbl_bundle_project`: a list with `dir` and `files`
(the files written). It prints as a box.

## Details

The starter's data is a CSV with columns `group` and `value`; its one
check is the row count, so the first run on synthetic data shows one
INFO. Set `resource$filename`, `resource$direct_url` and
`resource$sha256` in `data_provenance.json` (see
[`sha256file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256file.md))
and the runner finds, downloads and checks the real file.

Errors: `dir` holding any of the three files when `overwrite` is
`FALSE`; a `name` with characters other than letters, digits, dot, dash
and underscore.

## See also

[`mkbndl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkbndl.md)
to build the bundle.

## Examples

``` r
p <- mkbndlproj(file.path(tempdir(), "my-study"), title = "My study")
p
#> ╭── Bundle project ───────────────────────────────────────────────────────────╮
#> │   Folder  /tmp/Rtmp1U0s11/my-study                                          │
#> │   Files   config.json, data_provenance.json, analysis.R                     │
#> │                                                                             │
#> │   Edit config.json (who and what), data_provenance.json (the data file,     │
#> │   its URL and SHA-256) and analysis.R (the checks), then build the zip      │
#> │   with mkbndl().                                                            │
#> │   It runs as it is on synthetic data, so the bundle can be tried before     │
#> │   the analysis is written.                                                  │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
readLines(file.path(p$dir, "analysis.R"), n = 5)
#> [1] "## analysis.R -- the analysis of this bundle. The runner (setup_and_run.R)"
#> [2] "## calls it as:  Rscript analysis.R <data file> <results folder>"          
#> [3] "## with BRICKLAYER_SYNTHETIC=1 set when the data are synthetic. It writes" 
#> [4] "## manifest.json into the results folder: one record per check, with the"  
#> [5] "## value the paper reports and the value this run computed."               

# files are kept unless overwrite = TRUE
try(mkbndlproj(p$dir))
#> Error : /tmp/Rtmp1U0s11/my-study already holds config.json, data_provenance.json, analysis.R: pass overwrite = TRUE to replace
```
