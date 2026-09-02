# Changelog

## rmoriebricklayer 0.3.9

- The native JSON codec is now jsonlite’s complete mapping: every
  `toJSON()` option
  (dataframe/matrix/Date/POSIXt/factor/complex/raw/null/na/digits/
  pretty/force plus rownames, keep_vec_names, json_verbatim,
  always_decimal, time_format, UTC, no_dots), the same number formatting
  (`num_to_char` / `modp_dtoa2` rules), `fromJSON()` simplification
  (record lists, matrices, arrays, `$date`, `_row`, `"NA"` strings),
  prettify/minify (yajl layout), validate,
  serializeJSON/unserializeJSON, base64, ndjson streaming and
  rbind_pages. A parity test pins all of it to jsonlite byte-for-byte
  when jsonlite is installed (1,742 cases, 0 differences).
- Standalone capsule bundles: `make_bundle.sh` now ships `json_native.R`
  and a pure-R SHA-256 (`sha256_native.R`), `setup_and_run.R` no longer
  requires jsonlite, and
  [`sha256_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256_file.md)
  falls back to the pure-R digest when the compiled core is not loaded.
  This fixes the 0.3.8 CI failure of the otis-mrp bundle
  (`bricklayer_json_from_json` not found).
- pkgdown index and examples for the two exported codec functions.

## rmoriebricklayer 0.3.8

- No more runtime dependence on ‘digest’ or ‘jsonlite’: Imports is now
  base R only (`stats`, `utils`).
  [`sha256_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256_file.md)
  hashes through the compiled SHA-256 core that already backed
  [`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md);
  every JSON read (CKAN, Socrata, ArcGIS, Wayback metadata, local
  manifests) and the manifest writer go through a new pure-R,
  jsonlite-compatible codec exported as
  [`bricklayer_json_from_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_from_json.md)
  /
  [`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md)
  (same simplification rules and encoder options as jsonlite). Both old
  packages move to Suggests and are only used by the cross-check tests,
  which pin the native codec and hash to their output when installed.
- Remote JSON endpoints are fetched with
  [`bricklayer_fetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch.md)
  (the compiled fetch core with its Wayback fallback) instead of
  jsonlite’s URL reader.

## rmoriebricklayer 0.3.7

CRAN release: 2026-08-05

- Test-only change: local_mocked_bindings() tests are guarded so they
  skip cleanly under a bare testthat::test_dir() (they need the package
  namespace, which devtools::test() and R CMD check provide). No
  user-facing change.

## rmoriebricklayer 0.3.6

- CRAN incoming-pretest NOTE cleanup: quote ‘Wayback Machine’ in
  DESCRIPTION; README Code-of-Conduct link is now an absolute URL (the
  file is .Rbuildignore’d, so the relative URI flagged as invalid).

## rmoriebricklayer 0.3.5

- SIU features now live natively in bricklayer: the deterministic
  parse/resolve core is part of `src/` (zero new dependencies,
  hand-rolled `.Call` glue like the rest of the backend). New:
  [`bricklayer_parse_siu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_parse_siu.md)
  (16 schema fields + language from report HTML or a saved file),
  [`bricklayer_fetch_parse_siu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch_parse_siu.md)
  (fetch + parse in one call),
  [`bricklayer_siu_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_schema.md),
  [`bricklayer_siu_text()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_text.md),
  [`bricklayer_siu_iso_date()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_iso_date.md),
  [`bricklayer_siu_resolve_so()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_resolve_so.md)
  (rule-ordered subject-official count; 0 is a real answer).
  Synthetic-report fixture + offline tests included.

## rmoriebricklayer 0.3.4

- CRAN reviewer round (K. Lauseker, 0.3.0): spell out CKAN + SHA-256 and
  link the CKAN/Wayback web services in DESCRIPTION; agent_bundle
  example `\dontrun` -\> `\donttest`; setup_and_run.R no longer calls
  [`setwd()`](https://rdrr.io/r/base/getwd.html),
  [`install.packages()`](https://rdrr.io/r/utils/install.packages.html),
  or
  [`installed.packages()`](https://rdrr.io/r/utils/installed.packages.html)
  (checks via
  [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) and prints
  the install command instead).

## rmoriebricklayer 0.3.3

- Add `bricklayer_fetch_siu(drid, dest)`: fetch an Ontario SIU
  director’s report by drid through the live+Wayback engine – the fetch
  step of the open SIU corpus pipeline.

## rmoriebricklayer 0.3.2

### Documentation

- Every exported function now carries exhaustive, multiple-example
  documentation covering each argument, edge cases, and a realistic
  workflow (previously most had a single one-liner).
- Version bump ensures the
  [`bricklayer_fetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch.md)
  help topic (added in an earlier 0.3.1 build without a version bump)
  propagates to the r-universe binary and downstream reverse-dependency
  checks.

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
  one call re-verifies an entire reproducible data capsule offline:
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
