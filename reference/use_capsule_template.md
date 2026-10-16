# Start a capsule from a template

Creates a new folder with the three files a reproducible analysis
"capsule" needs, ready to be filled in: a `data_provenance.json` that
says where the data come from, an `analysis.R` script that fetches,
checks, analyses and records, and a `README.md` that says how to run it.
Use it to start a new project in the package's
fetch-verify-analyse-record pattern instead of writing that scaffolding
by hand.

## Usage

``` r
use_capsule_template(path, name = basename(path), example = FALSE)
```

## Arguments

- path:

  Character string: the directory to create. It may exist only if it is
  empty.

- name:

  Character string: the capsule name written into the provenance and
  README. Defaults to the last part of `path`.

- example:

  Logical, default `FALSE`. `TRUE` uses the shipped OTIS table as the
  source so the skeleton runs immediately; `FALSE` leaves a `TODO` URL.

## Value

The directory path, invisibly.

## Details

The files:

- `data_provenance.json`:

  the fields
  [`load_provenance`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md)
  and
  [`verify_capsule`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md)
  expect: `name`, `source` (`url`, `publisher`, `licence`, `retrieved`,
  `sha256`) and `table` (`value`, `period`, `by`, `rounding`,
  `suppression_limit`). Every field that must be filled in is marked
  `TODO`.

- `analysis.R`:

  reads the provenance, downloads the source with
  [`friendly_download`](https://rootcoder007.github.io/rmorie-bricklayer/reference/friendly_download.md)
  (a local path is read directly), computes its SHA-256 with
  [`sha256_file`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256_file.md)
  and stops if it no longer matches the pinned value, runs
  [`analyse_table`](https://rootcoder007.github.io/rmorie-bricklayer/reference/analyse_table.md),
  and writes `results/manifest.json`, `results/report.html` and
  `results/report.md`.

- `README.md`:

  the three steps to fill in and run the capsule.

With `example = TRUE` the source is the OTIS table shipped with the
package (`extdata/otis_a01_individuals.csv`), so `Rscript analysis.R`
runs as written. The table settings in the template
(`value = "individuals"`, `period = "year"`, `by = c("table", "group")`)
fit that example and must be edited for other data.

Side effects: creates `path` (and its parents) and writes the three
files. Errors: `path` exists and is not empty; `name` is not a single
non-empty string. The `name` and source are written as escaped JSON
strings, so quotes and backslashes are safe.

## See also

[`load_provenance`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md),
[`verify_capsule`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md),
[`analyse_table`](https://rootcoder007.github.io/rmorie-bricklayer/reference/analyse_table.md).

## Examples

``` r
d <- use_capsule_template(tempfile("capsule-"), example = TRUE)
list.files(d)
#> [1] "README.md"            "analysis.R"           "data_provenance.json"

# the provenance file to fill in
cat(readLines(file.path(d, "data_provenance.json")), sep = "\n")
#> {
#>   "name": "capsule-1dd241241e10",
#>   "source": {
#>     "url": "/tmp/Rtmp6k5Jxv/temp_libpath1dd25c8352b1/rmoriebricklayer/extdata/otis_a01_individuals.csv",
#>     "publisher": "TODO: who publishes the table",
#>     "licence": "TODO: e.g. Open Government Licence - Ontario",
#>     "retrieved": "TODO: YYYY-MM-DD",
#>     "sha256": "TODO: filled by analysis.R on first run"
#>   },
#>   "table": {
#>     "value": "individuals",
#>     "period": "year",
#>     "by": ["table", "group"],
#>     "rounding": null,
#>     "suppression_limit": null
#>   }
#> }

# a blank template with a chosen name
d2 <- use_capsule_template(tempfile("capsule-"), name = "segregation-2024")
grep("TODO", readLines(file.path(d2, "data_provenance.json")), value = TRUE)
#> [1] "    \"url\": \"TODO: https://example.org/open-data/table.csv\","   
#> [2] "    \"publisher\": \"TODO: who publishes the table\","             
#> [3] "    \"licence\": \"TODO: e.g. Open Government Licence - Ontario\","
#> [4] "    \"retrieved\": \"TODO: YYYY-MM-DD\","                          
#> [5] "    \"sha256\": \"TODO: filled by analysis.R on first run\""       

# an existing, non-empty folder is never overwritten
try(use_capsule_template(d))
#> Error : `path` exists and is not empty
```
