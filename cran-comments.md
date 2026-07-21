# cran-comments.md — rmoriebricklayer 0.3.5

## Resubmission

This is a resubmission addressing every point in the 0.3.0 review
(thank you, Konstanze Lauseker). Point-by-point:

* **Explain all acronyms in the Description** — done. The Description
  now spells out "Comprehensive Knowledge Archive Network ('CKAN')"
  and "Secure Hash Algorithm 256 ('SHA-256')".
* **Link the used web services in the Description** — done, with
  angle-bracket auto-linking: <https://ckan.org/> and
  <https://web.archive.org/>.
* **agent_bundle.Rd: replace \dontrun{} with \donttest{}** — done.
  The example is executable everywhere: when the optional 'rmorie'
  command-line binary is not on the PATH the function returns an
  install-hint string immediately (no error, no network), which is
  the situation on any check machine.
* **inst/scripts/setup_and_run.R: reset options()/working directory**
  — the script no longer changes the working directory at all
  (`setwd()` removed; every path is anchored on the script's own
  directory), and it no longer sets any option.
* **inst/scripts/setup_and_run.R: do not install packages** — the
  auto-install step was removed. The script now only checks
  availability and prints the exact `install.packages()` command for
  the user to run themselves.
* **inst/scripts/setup_and_run.R: do not use installed.packages()** —
  replaced with per-package `requireNamespace()` checks.

## No \dontrun{} anywhere

Since 0.3.0 the package gained a compiled 'libcurl' download core; every
example was re-triaged against the review's \dontrun rule and the
package now contains zero `\dontrun{}` blocks. Network-touching
examples (`bricklayer_fetch`, `bricklayer_fetch_siu`,
`wayback_snapshot_url_native`) are `\donttest{}` and degrade
gracefully: calls are wrapped in `try()` (or return `NULL` on any
network failure), so they execute cleanly on machines with or without
internet access.

## About the package

Reproducible data capsules with provenance manifests, SHA-256
pinning, and Wayback Machine fallback resolution. It is the
foundation package of the MORIE family (the 'rmorie' and
'rmoriedata' packages Import it and will be submitted separately
once this package is on CRAN).

## Test environments

* Local: Fedora 44 (x86_64), R 4.6.1 —
  R CMD check --as-cran --run-donttest
* GitHub Actions: ubuntu-latest (R release + devel), ubuntu-22.04
  (oldrel-1), windows-latest, macos-latest
* win-builder R-devel (0.3.5 tarball): [pending upload]

## R CMD check results

0 errors | 0 warnings | 2 notes

* "New submission" — unavoidable.
* Non-portable compiler flags — these come from the local Fedora
  toolchain's site defaults, not from the package's Makevars.

## CRAN policy notes

* No writes outside `tempdir()`: all file-producing functions take an
  explicit output path; examples and tests write only under
  `tempfile()`/`tempdir()`.
* `make_synthetic_csv()` seeds the RNG for reproducibility and
  restores the caller's `.Random.seed` on exit.
* Network access: capsule resolution helpers construct URLs; no
  example contacts a remote service during check (the `agent_bundle()`
  `\donttest{}` example returns immediately when the optional binary
  is absent).
