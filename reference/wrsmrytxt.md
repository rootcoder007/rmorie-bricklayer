# Write a Plain-Language Run Summary

Writes `SUMMARY.txt` into an output folder: a plain-text page a person
can read without any software, giving the project, author, time,
operating system and R version of the run, whether it ran on real or
synthetic data, the paths it used, the tally of cross-check results, the
files in the folder, and optional notes, contact and licence lines. It
is the human-readable companion of
[`wrmnfjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrmnfjs.md).

## Usage

``` r
wrsmrytxt(man, outdir, paths, whatwasdone = NULL, contact = NULL, lic = NULL)
```

## Arguments

- man:

  A manifest as returned by
  [`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md);
  its `meta` supplies the header and its `results` the counts.

- outdir:

  Character scalar, an existing folder to write `SUMMARY.txt` into and
  to list the files of.

- paths:

  A named list (or named character vector) of paths to report, one line
  each, labelled by the capitalised name. Names such as `capsule`,
  `input`, `results`, `analysis_script` and `provenance` are typical.
  [`list()`](https://rdrr.io/r/base/list.html) reports none.

- whatwasdone:

  Optional character vector, one line each, describing what the run did.
  Default `NULL` (no section).

- contact:

  Optional character scalar appended as a `Contact:` line. Default
  `NULL`.

- lic:

  Optional character scalar appended as a `Licence:` line. Default
  `NULL`.

## Value

The path to the written `SUMMARY.txt` (character scalar), invisibly.

## Details

Header fields come from `manifest$meta`: `project` (default
`"(unnamed)"`), `author` (`"(unknown)"`), `run_at` (default the current
time), `os` (default
[`Sys.info()`](https://rdrr.io/r/base/Sys.info.html)), `r_version`
(default `R.version.string`) and `synthetic`. When
`meta$r_package_versions` is present a section lists those versions.
Result counts are tallied from the `status` of each entry of
`manifest$results` (PASS, DIFFER, WARN, INFO).

The file list is `list.files(outdir)` at the time of the call, sorted,
so write the summary last. The paths are printed as given (they are not
made absolute). An existing `SUMMARY.txt` is overwritten.

Errors when `man` is not a list, and (from base R) when `outdir` does
not exist or cannot be written.

## See also

[`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md),
[`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md),
[`wrmnfjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrmnfjs.md).

## Examples

``` r
man <- mkmnf(list(project = "demo", author = "A. Author"),
  env = FALSE
)
man <- recrd(man, "rowcount", obs = 20, expd = 20)
#>   rowcount                                     observed = 20.0000      expected = 20.0000      [INFO]
out <- file.path(tempdir(), "demo-run")
dir.create(out, showWarnings = FALSE)
s <- wrsmrytxt(man, out, paths = list(results = out))
readLines(s)[7:8]
#> [1] "Project:   demo"      "Author:    A. Author"

# with notes, contact and licence lines
s <- wrsmrytxt(man, out, paths = list(results = out),
  whatwasdone = c("- read the extract", "- recomputed table 2"),
  contact = "analyst at example.org", lic = "CC BY 4.0")
tail(readLines(s), 6)
#> [1] "----------------------------------------------------------"
#> [2] "- read the extract"                                        
#> [3] "- recomputed table 2"                                      
#> [4] ""                                                          
#> [5] "Contact: analyst at example.org"                           
#> [6] "Licence: CC BY 4.0"                                        

# the manifest has to be a list
try(wrsmrytxt("demo", out, paths = list()))
#> Error : `man` must be a manifest from mkmnf()
```
