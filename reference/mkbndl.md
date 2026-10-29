# Build a Reproducibility Bundle

Packs a project folder into one zip that anyone can unzip and run with a
double-click: `START_HERE.command` on macOS, `START_HERE.bat` on
Windows, `start_here.sh` on Linux. The launchers find R, the runner
(`setup_and_run.R`) checks the packages the project lists, finds or
downloads the data (checking it against the pinned SHA-256), or
generates synthetic data from the project's recipe, runs the project's
analysis script and summarises its `manifest.json` in plain language.

## Usage

``` r
mkbndl(
  project,
  dest,
  data = NULL,
  version = "1",
  overwrite = FALSE,
  secrets = FALSE
)
```

## Arguments

- project:

  A project folder, or the name of an example shipped with the package
  (`"otis-mrp"`, the Ontario restrictive confinement analysis).

- dest:

  An existing folder to write the zip into.

- data:

  Optional path to the data file, copied into the bundle (under the file
  name the provenance pins) so it runs offline. `NULL` (default) leaves
  it out: the runner asks for it, offers to download it, or uses
  synthetic data.

- version:

  Version label in the zip's name, default `"1"`.

- overwrite:

  Replace a zip of the same name, default `FALSE`.

- secrets:

  Pack files whose names look like credentials (see Details), default
  `FALSE`: they are left out with a warning.

## Value

An object of class `rmbl_bundle`: a list with `path` (the zip),
`sha256`, `bytes`, `files` (the paths inside the zip), `project` (the
project name) and `data` (whether the data file is inside). It prints as
a box.

## Details

A project is a folder holding at least `config.json` and the analysis
script it names (default `analysis.R`);
[`mkbndlproj()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkbndlproj.md)
writes a working starter. `data_provenance.json` pins the data file
(name, URL, SHA-256, licence) and may carry a `schema$synthetic_recipe`
for the offline synthetic route. Every other file in the folder is
copied into the bundle too, except hidden files, `results_*` folders and
zip files.

Symbolic links are not followed: a link to a file inside the project is
packed as that file, and a link to a folder, or to anything outside the
project, is left out with a warning that names it. Files whose names
look like credentials are left out too, with a warning that lists them,
unless `secrets = TRUE`: `llm.json`, `credentials.json`, `secrets.yaml`,
`token.txt`, `api_key*`, `id_rsa` and the other SSH private keys, `.env`
and `*.env`, `.netrc`, `.Renviron`, `.pgpass`, `kubeconfig` and
`kube.config`, key stores (`.p12`, `.pfx`, `.jks`, `.ppk`), `.pem` or
`.key` files holding a private key, and any other file (not a data table
such as `.csv` or `.rds`, nor a document such as `.md`, `.html`, `.Rmd`
or `.qmd`) whose name, split into words at `-`, `_`, `.` and spaces, has
the word `key`, `keys`, `apikey`, `token`, `tokens`, `secret`,
`secrets`, `credential`, `credentials`, `creds`, `password`,
`passwords`, `passwd`, `pat` or `adc` (`openai_key.txt`,
`github_pat.txt`, `access_token`, `aws_credentials`, `gcloud_adc.json`,
`keys.R`; not `keyboard.csv`). Public keys (`.pub`) are packed.

The runner calls the analysis script as
`Rscript analysis.R <data file> <results folder>`, with
`BRICKLAYER_SYNTHETIC=1` set on synthetic data. The script writes
`manifest.json` into the results folder:
[`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md),
[`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md)
and
[`wrmnfjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrmnfjs.md)
build it, and they are in the bundle (the script sources them from its
own folder, as the starter does), so the reviewer needs only R and the
packages listed in `r_packages`. To call other functions of this package
from the analysis, list `"rmoriebricklayer"` in `r_packages`.

Optional keys of `config.json`: `project` (`name`, `title`,
`paper_title`, `work_type`, `author`, `contact`, `orcid`, `affiliation`,
`supervisor`, `licence`), `analysis$r_script`, `r_packages`,
`env_packages` (packages needed only when an environment variable is
set), `optional_stages` (opt-in stages with their own packages),
`synthetic_env` (another variable that turns on the synthetic route),
`data$default_candidates`, `network$endpoints`, `summary$what_was_done`
and `expected` (`total_checks`, `pass_real`).

Before zipping, every internal name the bundled R files call is checked
to be defined by a bundled file, and by one the runner itself sources
when the runner calls it: a bundle that would stop with “could not find
function” on the reviewer's machine is refused here instead.

Nothing is written except the zip in `dest`; the staging folder is a
temporary directory removed on exit. The zip is written under a
temporary name in `dest` and renamed when it is complete, so an
interrupted build leaves no partial zip (and keeps the one it was to
replace). Send the SHA-256 that is printed to recipients separately, so
they can check the zip was not altered.

Errors: `project` that is neither a folder nor a bundled example; a
project without `config.json` or without its analysis script; a project
file whose name a bundle file already uses; `dest` that is not an
existing folder; a zip that exists when `overwrite` is `FALSE`; `data`
that is not an existing file; a `version`, or a `project$name` in
`config.json`, that is not a plain name (letters, digits, dot, dash and
underscore, not starting with a dot, no `..`, at most 64 characters); a
bundle of more than 65535 files and folders or over 4 GB (more than a
plain zip holds).

## See also

[`mkbndlproj()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkbndlproj.md)
for a starter project;
[`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md)
and
[`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md)
for the manifest the analysis writes.

## Examples

``` r
# a starter project, bundled
proj <- file.path(tempdir(), "demo-project")
mkbndlproj(proj, title = "Demo analysis", author = "A. Researcher")
#> ╭── Bundle project ───────────────────────────────────────────────────────────╮
#> │   Folder  /tmp/Rtmp3auSYS/demo-project                                      │
#> │   Files   config.json, data_provenance.json, analysis.R                     │
#> │                                                                             │
#> │   Edit config.json (who and what), data_provenance.json (the data file,     │
#> │   its URL and SHA-256) and analysis.R (the checks), then build the zip      │
#> │   with mkbndl().                                                            │
#> │   It runs as it is on synthetic data, so the bundle can be tried before     │
#> │   the analysis is written.                                                  │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
b <- mkbndl(proj, dest = tempdir(), overwrite = TRUE)
b
#> ╭── Reproducibility bundle ───────────────────────────────────────────────────╮
#> │   Project    demo-project                                                   │
#> │   Zip        demo-project_v1.zip                                            │
#> │   Folder     /tmp/Rtmp3auSYS                                                │
#> │   Size       204.7 KB                                                       │
#> │   Files      26                                                             │
#> │   Data file  not inside                                                     │
#> │   SHA-256    d7847d4ea18a58fda06efcaa0004de7ce51f0f202f2315797ddd93e4b347f0 │
#> │              be                                                             │
#> │                                                                             │
#> │   Recipients unzip it and double-click START_HERE.command (macOS) or        │
#> │   START_HERE.bat (Windows), or run ./start_here.sh (Linux).                 │
#> │   The data file is not inside: the runner finds it, downloads it and        │
#> │   checks its SHA-256, or runs on synthetic data.                            │
#> │                                                                             │
#> │   Send the SHA-256 separately from the zip, so recipients can check the     │
#> │   copy they received was not altered.                                       │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
head(b$files)
#> [1] "demo-project_v1/"                   "demo-project_v1/INSTRUCTIONS.txt"  
#> [3] "demo-project_v1/README.md"          "demo-project_v1/SECURITY.md"       
#> [5] "demo-project_v1/START_HERE.bat"     "demo-project_v1/START_HERE.command"

# the example shipped with the package
otis <- mkbndl("otis-mrp", dest = tempdir(), overwrite = TRUE)
otis$sha256
#> [1] "b50651b4ae923b42c085dc441879b0ff5ccf08e8702076f6815045dc8cf79556"

# an existing zip is kept unless overwrite = TRUE
try(mkbndl(proj, dest = tempdir()))
#> Error : /tmp/Rtmp3auSYS/demo-project_v1.zip exists: pass overwrite = TRUE to replace it
```
