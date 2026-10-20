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
usecpstmpl(path, name = basename(path), ex = FALSE)
```

## Arguments

- path:

  Character string: the directory to create. It may exist only if it is
  empty.

- name:

  Character string: the capsule name written into the provenance and
  README. Defaults to the last part of `path`.

- ex:

  Logical, default `FALSE`. `TRUE` uses the shipped OTIS table as the
  source so the skeleton runs immediately; `FALSE` leaves a `TODO` URL.

## Value

The directory path, invisibly.

## Details

The files:

- `data_provenance.json`:

  the fields
  [`loadprov`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loadprov.md)
  and
  [`vrfcps`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md)
  expect: `name`, `source` (`url`, `publisher`, `licence`, `retrieved`,
  `sha256`) and `table` (`value`, `period`, `by`, `rounding`, `suplim`).
  Every field that must be filled in is marked `TODO`.

- `analysis.R`:

  reads the provenance, downloads the source with
  [`fdl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fdl.md)
  (a local path is read directly), computes its SHA-256 with
  [`sha256file`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256file.md)
  and stops if it no longer matches the pinned value, runs
  [`anltab`](https://rootcoder007.github.io/rmorie-bricklayer/reference/anltab.md),
  and writes `manifest.json`, `report.html` and `report.md` in
  `results/`.

- `README.md`:

  the three steps to fill in and run the capsule.

With `example = TRUE` the source is the OTIS table
`otis_a01_individuals.csv` shipped in the package's `extdata` folder, so
`Rscript analysis.R` runs as written. The table settings in the template
(`value = "individuals"`, `period = "year"`, `by = c("table", "group")`)
fit that example and must be edited for other data.

Side effects: creates `path` (and its parents) and writes the three
files. Errors: `path` exists and is not empty; `name` is not a single
non-empty string. The `name` and source are written as escaped JSON
strings, so quotes and backslashes are safe.

## See also

[`loadprov`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loadprov.md),
[`vrfcps`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md),
[`anltab`](https://rootcoder007.github.io/rmorie-bricklayer/reference/anltab.md).

## Examples

``` r
d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
list.files(d)
#> [1] "README.md"            "analysis.R"           "data_provenance.json"

# the provenance file to fill in
cat(readLines(file.path(d, "data_provenance.json")), sep = "\n")
#> {
#>   "name": "capsule-1db361d074b6",
#>   "source": {
#>     "url": "/tmp/RtmpW0vzft/temp_libpath1db32ede7d22/rmoriebricklayer/extdata/otis_a01_individuals.csv",
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
d2 <- usecpstmpl(tempfile("capsule-"), name = "segregation-2024")
grep("TODO", readLines(file.path(d2, "data_provenance.json")), value = TRUE)
#> [1] "    \"url\": \"TODO: https://example.org/open-data/table.csv\","   
#> [2] "    \"publisher\": \"TODO: who publishes the table\","             
#> [3] "    \"licence\": \"TODO: e.g. Open Government Licence - Ontario\","
#> [4] "    \"retrieved\": \"TODO: YYYY-MM-DD\","                          
#> [5] "    \"sha256\": \"TODO: filled by analysis.R on first run\""       

# an existing, non-empty folder is never overwritten
try(usecpstmpl(d))
#> Error : `path` exists and is not empty
```
