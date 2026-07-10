# cran-comments.md — rmoriebricklayer 0.3.0

## Submission

First CRAN submission of rmoriebricklayer: reproducible data capsules
with provenance manifests, sha256 pinning, and Wayback-Machine
fallback resolution. It is the foundation package of the MORIE
family (the `rmorie` and `rmoriedata` packages Import it and will be
submitted separately once this package is on CRAN).

## Test environments

* Local: Debian (aarch64), R 4.5.x — R CMD check --as-cran
* GitHub Actions: ubuntu-latest (R release + devel), ubuntu-22.04
  (oldrel-1), windows-latest, macos-latest
* win-builder R-devel (2026-07-09, this exact 0.3.0 tarball):
  0 errors | 0 warnings | 1 note (new submission)

## R CMD check results

0 errors | 0 warnings | 1 note

* "New submission" — this is the package's first CRAN submission.
* The spell-checker flags "CKAN", "SHA", and "Wayback" in the
  Description; all three are correct technical terms (the CKAN data
  portal API, SHA-256 checksums, the Internet Archive Wayback
  Machine).

## CRAN policy notes

* No writes outside `tempdir()`: all file-producing functions take an
  explicit output path; examples and tests write only under
  `tempfile()`/`tempdir()`.
* `make_synthetic_csv()` seeds the RNG for reproducibility and
  restores the caller's `.Random.seed` on exit.
* Network access: the resolver and Wayback examples that contact live
  open-data portals are wrapped in `\donttest{}`; everything that runs
  on CRAN is fully offline.
