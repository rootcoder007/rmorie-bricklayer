# Changelog

All notable changes to this project will be documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/), and versioning follows [Semantic Versioning](https://semver.org/).

## [0.1.0] — 2026-06-23

Initial public release. Extracted from the OTIS A01RCDD MRP reproducibility bundle (Vansh Singh Ruhela, U of T MA, August 2026 submission).

### Added

- Cross-platform brick-proof orchestrator (`setup_and_run.R`) — pure R, no shell dependencies.
- OS launchers — `START_HERE.command` (macOS), `START_HERE.bat` (Windows), `start_here.sh` (Linux). All route to the same orchestrator.
- Reusable R libraries: `lib_helpers.R`, `lib_data_loader.R`, `lib_synthetic.R`, `lib_manifest.R`.
- CKAN open-data resolution: `package_show` by slug + name pattern, with `package_search` fallback.
- SHA256 verification with pinned provenance manifest.
- Schema validation: required columns (fatal), value sets (warning), row-count bounds (warning).
- Synthetic-data fallback for offline / no-data review.
- Constrained save-location menu: bundle / Downloads / Documents / R-policy / custom.
- "WHERE EVERYTHING WILL GO" startup panel with absolute paths and contacted endpoints.
- `SUMMARY.txt` written into every results folder.
- `SECURITY.md` template addressing common "is this safe" concerns including the `.tar.gz = malware` misconception.
- `DATA_NOTICE.md` template for vendored open-data attribution.
- Templated docs: `README.md`, `INSTRUCTIONS.txt`, `SECURITY.md`, `DATA_NOTICE.md`.
- `make_bundle.sh` — CLI: config + provenance + scripts → shippable zip.
- `verify_bundle.sh` — author-side audit: extract, run, parse manifest, exit non-zero on regression.
- `examples/otis-mrp/` — complete reference example using Ontario's open OTIS A01RCDD data.
- Documentation: quickstart, customization, data sources, FAQ.

### Known limitations

- Only CKAN data sources are built in (Dataverse, Zenodo are extensible — see `docs/data_sources.md`).
- Cross-platform code paths written but only macOS has been end-to-end tested. Linux + Windows test reports welcome.
- No Wayback Machine snapshot capture from networks that block `archive.org`.
- Bundle SHA256 must be communicated out-of-band by the publisher (not automated).

### Provenance

The OTIS reference bundle reproduces all 36 numerical claims in the paper:
- 36/36 PASS with the author's `.RData` workspace (full DML cross-checks).
- 28/36 PASS + 8 INFO from the public OGL-Ontario CSV (DML estimates are pre-computed and only available in the `.RData`).
- 36 INFO from synthetic data (pipeline machinery verified; comparison not meaningful).
