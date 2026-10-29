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
mkbndlchk(
  bundle,
  data = NULL,
  synthetic = FALSE,
  dir = NULL,
  keep = FALSE,
  container = NULL
)
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

- container:

  Run the bundle in a container: `NULL` or `FALSE` (default) do not,
  `TRUE` uses podman, else docker, and `"podman"` or `"docker"` names
  the runtime. See Details.

## Value

An object of class `rmbl_bundle_audit`: a list with `ok`, `checks` (a
data frame of `check`, `ok`, `detail` and `severity`), `mode` (the input
the run used, from its manifest: `synthetic` when it is marked
synthetic, else its `meta$input_mode` when it records one, such as
`csv`, else `real`), `counts` (`total`, `pass`, `differ`, `info`), `log`
(the last 30 lines the run printed), `isolation` (how the run was
contained: see Details), `bundle` and `dir` (the unzipped bundle, or for
a container run the folder it wrote into; `NA` once removed). It prints
as a box.

## Details

**Warning: this runs the bundle's code on your machine**, with your
user's rights: its `setup_and_run.R`, its analysis script and anything
they start. Check only bundles you built or whose author you trust. To
limit what a hostile bundle can reach, the run gets a minimal
environment: `PATH`, the locale variables (`LANG`, `LANGUAGE`, `LC_ALL`
and the `LC_` categories such as `LC_CTYPE`, no other `LC_` name; `TZ`),
the library paths of this session (`R_LIBS`), a fresh temporary `HOME`
and `TMPDIR`, and no other variable, so API keys, tokens and passwords
in the environment (or in `~/.Renviron`) do not reach it. On Windows the
variables that look like credentials are removed instead (a best
effort): names holding `KEY`, `TOKEN`, `SECRET`, `PASS`, `CREDENTIAL`,
`AUTH`, `COOKIE` or `SESSION`, a service's prefix (`GITHUB_`, `AWS_`,
...), connection strings (`DATABASE_URL`, `*_DATABASE_URL`,
`*_WEBHOOK_URL`, `SENTRY_DSN`, `*_DSN`), `*_PWD`, `*_SK`, other `LC_`
names, and any value that is a URL with a password in it. This is not a
sandbox: the files your user can read stay readable.

The run is stopped after `getOption("rmbl.bundle.timeout")` seconds
(default 1800, 30 minutes; the exit status is then 124). How the
processes it starts are contained (the `isolation` of the result, and a
row of the checks):

- container:

  with `container = TRUE` (podman, else docker) or a runtime named: the
  run in a container, removed afterwards, with the unzipped bundle
  mounted read-only and copied into a writable folder, no network unless
  the real data is to be downloaded (no `data`, not synthetic), 4 GB of
  memory, 2 CPUs, 512 processes, a read-only root file system, no
  capabilities and your user id. The image is
  `getOption("rmbl.bundle.image")`, default R 4.6.1 from the Rocker
  project pinned by digest; it holds base R only, so a bundle that lists
  packages in `r_packages` (or downloads its data, which needs
  rmoriebricklayer) needs an image that has them. Without the runtime
  the check falls back to the next mode and says so.

- pid namespace:

  Linux, when `unshare` can make an unprivileged user and PID namespace:
  every process the run started, also one that started its own session
  or forked twice, is killed when the run ends or times out.

- job object:

  Windows: the run is started inside a job object that kills every
  process in it when the run ends or times out.

- process group:

  Linux without user namespaces, and macOS: the run leads a process
  group, killed when it ends, times out or is interrupted. A process can
  leave the group (setsid, a double fork) and clear its environment. On
  Linux this R session is made the run's child subreaper, so such a
  process is re-parented to it rather than to init: every process the
  run left behind is found by the process tree, killed by its PID and
  fails the check (the isolation row is an error). Where that cannot be
  done (macOS, or a Linux kernel older than 3.4) escaped processes
  cannot be detected, and the isolation row fails: use
  `container = TRUE` there.

Only a `results_*` folder the run itself created counts: one the zip
already carries (which
[`mkbndl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkbndl.md)
never packs) is not read, and fails the check. A run that writes no
manifest, or whose runner reports “NOT completed”, fails.

Errors: `bundle` that is not an existing `.zip` file, or not a zip this
function reads (more than 65535 entries, an entry name with a NUL byte,
one too long, absolute or leaving the folder, or an entry given twice);
a zip without `setup_and_run.R`; `data` that is not an existing file;
`dir` that already exists.

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
#> │   Folder  /tmp/Rtmp5MSEQX/audit-demo                                        │
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
#> │ ✔ VERIFIED  · 7 of 7 checks passed                                          │
#> │                                                                             │
#> │   Bundle      audit-demo_v1.zip                                             │
#> │   Input mode  synthetic                                                     │
#> │   Isolation   process group                                                 │
#> │   Checks      2                                                             │
#> │   ✔           0                                                             │
#> │   DIFFER      0                                                             │
#> │   INFO        2                                                             │
#> │                                                                             │
#> │   Every check passed: the bundle runs as a recipient's copy will and is     │
#> │   safe to ship.                                                             │
#> │                                                                             │
#> │   ✔    run finished                  exit status 0                          │
#> │   ✔    manifest written                                                     │
#> │        /tmp/Rtmp5MSEQX/bndlchk1e786833a66b/audit-demo_v1/results_20261029-0 │
#> │        70107/manifest.json                                                  │
#> │   ✔    no cross-check differs        0 DIFFER                               │
#> │   ✔    counts match config.json      not compared: a synthetic run          │
#> │   ✔    launchers executable          2 launcher(s)                          │
#> │   ✔    no results packed in the zip  none                                   │
#> │   ✔    isolation process group: no process outlived the run                 │
#> │                                                                             │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
a$counts
#>  total   pass differ   info 
#>      2      0      0      2 
```
