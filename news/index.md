# Changelog

## rmoriebricklayer 0.3.1

### rOpenSci submission preparation

- License wording corrected: the optional `rmorie` CLI that
  [`agent_bundle()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agent_bundle.md)
  forwards to is AGPL-3.0-or-later (the entire MORIE family is AGPL; an
  earlier internal comment mislabelled it proprietary).

- Package moved from the `bricklayer/` subdirectory to the repository
  root (required by rOpenSci’s review tooling); repo-level extras stay
  as `.Rbuildignore`d siblings.

- New vignette `capsules.Rmd` walking the essential flow offline:
  provenance pin -\> schema validation -\> SHA256 integrity -\>
  synthetic fallback -\> manifest + summary.

- Every exported function now has runnable `@examples` (network calls in
  `\donttest`; offline NULL-contracts shown runnable).

- README gained development-version install instructions.

- New CI: test coverage (covr + Codecov) and rOpenSci `pkgcheck`.

- Test coverage raised from 84 percent to 96 percent: offline tests for
  the CKAN/Socrata/ArcGIS resolver success paths, `friendly_download`
  diagnostics and Wayback retry, summary contact/licence blocks, pinned
  script hashes, and the multi-block SHA-256 path. Dead
  `requireNamespace` guards for Imports (`digest`, `jsonlite`) removed.

- Repo-level `LICENSE` text excluded from the build (`License: AGPL-3`
  is the canonical spec; the stray file triggered a check NOTE).

## rmoriebricklayer 0.3.0

### Capsule-level integrity

- New
  [`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md):
  one call re-verifies an entire reproducible data capsule offline —
  provenance readability, pinned sha256/size/row count, schema validity,
  script hash, and re-derivation of every stored manifest cross-check
  from its own numbers.
- New
  [`capture_environment()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_environment.md)
  records R version, platform, OS, UTC timestamp, and loaded package
  versions;
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md)
  now attaches it by default (`environment = FALSE` to opt out).
- New
  [`cite_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cite_capsule.md)
  generates a ready-to-paste data citation (text + BibTeX `@misc`,
  DOI-aware) from a provenance object.

### Portal coverage

- New
  [`resolve_via_socrata()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_socrata.md)
  and
  [`resolve_via_arcgis()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_arcgis.md)
  extend URL-rot recovery beyond CKAN to the Socrata
  (Calgary/Chicago/NYC) and ArcGIS FeatureServer (Toronto Police
  Service) portals the MORIE family fetches from.

## rmoriebricklayer 0.2.5

- `make_synthetic_column("id_pattern")` without a `year_col` now returns
  all `n` ids (a vectorised-`gsub` misuse returned a single id).
- `bernoulli` columns unlist JSON-derived `labels`, fixing mangled
  column names from provenance-parsed schemas.
- Single-value `row_replication` no longer trips base R’s scalar
  [`sample()`](https://rdrr.io/r/base/sample.html) expansion.
- Test suite grown from 9 to 43 behavioural tests covering the full
  export surface (provenance, CKAN guards, Wayback handling, offline
  <file://> downloads, sha256, schema validation, manifests, synthetic
  generation, RNG hygiene).

## rmoriebricklayer 0.2.4

- [`make_synthetic_csv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_csv.md)
  now restores the caller’s `.Random.seed` on exit (CRAN policy: no
  lasting RNG-state change).
- First CRAN submission prep: `cran-comments.md`, build exclusions.

## rmoriebricklayer 0.2.3

- Capsule terminology adopted across the documentation; CITATION added;
  37/37 reproduction checks in `examples/otis-mrp/`.
