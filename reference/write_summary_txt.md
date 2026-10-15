# Write a Plain-Language Run Summary

Writes `SUMMARY.txt` into an output folder: a plain-text page a person
can read without any software, giving the project, author, time,
operating system and R version of the run, whether it ran on real or
synthetic data, the paths it used, the tally of cross-check results, the
files in the folder, and optional notes, contact and licence lines. It
is the human-readable companion of
[`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md).

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
  its `meta` supplies the header and its `results` the counts.

- output_dir:

  Character scalar, an existing folder to write `SUMMARY.txt` into and
  to list the files of.

- paths:

  A named list (or named character vector) of paths to report, one line
  each, labelled by the capitalised name (for example `capsule`,
  `input`, `results`, `analysis_script`, `provenance`).
  [`list()`](https://rdrr.io/r/base/list.html) reports none.

- what_was_done:

  Optional character vector, one line each, describing what the run did.
  Default `NULL` (no section).

- contact:

  Optional character scalar appended as a `Contact:` line. Default
  `NULL`.

- licence:

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

The file list is `list.files(output_dir)` at the time of the call,
sorted, so write the summary last. The paths are printed as given (they
are not made absolute). An existing `SUMMARY.txt` is overwritten.

Errors when `manifest` is not a list, and (from base R) when
`output_dir` does not exist or cannot be written.

## See also

[`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md),
[`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md),
[`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md).

## Examples

``` r
man <- make_manifest(list(project = "demo", author = "A. Author"),
  environment = FALSE
)
man <- record(man, "row_count", observed = 20, expected = 20)
#>   row_count                                    observed = 20.0000      expected = 20.0000      [INFO]
out <- file.path(tempdir(), "demo-run")
dir.create(out, showWarnings = FALSE)
s <- write_summary_txt(man, out, paths = list(results = out))
readLines(s)[7:8]
#> [1] "Project:   demo"      "Author:    A. Author"

# with notes, contact and licence lines
s <- write_summary_txt(man, out, paths = list(results = out),
  what_was_done = c("- read the extract", "- recomputed table 2"),
  contact = "analyst at example.org", licence = "CC BY 4.0")
tail(readLines(s), 6)
#> [1] "----------------------------------------------------------"
#> [2] "- read the extract"                                        
#> [3] "- recomputed table 2"                                      
#> [4] ""                                                          
#> [5] "Contact: analyst at example.org"                           
#> [6] "Licence: CC BY 4.0"                                        

# the manifest has to be a list
try(write_summary_txt("demo", out, paths = list()))
#> Error : `manifest` must be a manifest from make_manifest()
```
