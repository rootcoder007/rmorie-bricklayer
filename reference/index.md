# Package index

## Fetch open data

Resilient downloaders with libcurl + Wayback fallback for pulling public
datasets over flaky endpoints.

- [`bricklayer_fetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch.md)
  : Fetch a URL to disk with an Internet Archive fallback (C++/libcurl)
- [`download_data()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/download_data.md)
  : Download a File
- [`friendly_download()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/friendly_download.md)
  : Download a File With Diagnostic Error Messages

## Portal resolvers

Turn a dataset identifier on a government open-data portal into a direct
resource URL — CKAN, Socrata, ArcGIS, and Wayback snapshots.

- [`resolve_via_ckan()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_ckan.md)
  : Resolve a Download URL via CKAN package_show
- [`resolve_via_ckan_search()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_ckan_search.md)
  : Resolve a Download URL via CKAN package_search
- [`resolve_via_socrata()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_socrata.md)
  : Resolve a Download URL via the Socrata Metadata API
- [`resolve_via_arcgis()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_arcgis.md)
  : Resolve a Query URL via ArcGIS FeatureServer Metadata
- [`wayback_snapshot_url()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_snapshot_url.md)
  : Resolve a Wayback Machine snapshot URL
- [`wayback_snapshot_url_native()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_snapshot_url_native.md)
  : Resolve a Wayback Machine snapshot URL (C++/libcurl)

## Provenance & reproducibility capsules

Capture the environment, record a citable data-provenance capsule, and
verify it later so an analysis reproduces from the same inputs.

- [`capture_environment()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_environment.md)
  : Capture the Analysis Environment for a Manifest
- [`cite_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cite_capsule.md)
  : Generate a Data Citation From Provenance
- [`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md)
  : Re-Verify an Entire Reproducible Data Capsule
- [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md)
  : Load a Pinned Data-Provenance Record
- [`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md)
  : Record a Cross-Check Result in a Manifest
- [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md)
  : Construct a Reproducibility Manifest
- [`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md)
  : Write a Manifest to JSON
- [`write_summary_txt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_summary_txt.md)
  : Write a Plain-Language Run Summary
- [`agent_bundle()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agent_bundle.md)
  : Agent-assisted reproducibility-bundle help

## Integrity & checksums

SHA-256 hashing and verification for downloaded files.

- [`sha256_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256_file.md)
  : Compute a File's SHA256 Digest
- [`verify_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_sha256.md)
  : Verify a File's SHA256 Against an Expected Digest
- [`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md)
  : SHA-256 hex digest (C backend)

## Schema validation & synthetic data

Validate a data frame against a declared schema, and build typed
synthetic columns/CSVs for tests and documentation.

- [`apply_schema_validation()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/apply_schema_validation.md)
  : Apply Schema Validation, Stopping on Fatal Issues
- [`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
  : Validate a Data Frame Against a Provenance Schema
- [`make_synthetic_column()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_column.md)
  : Generate One Synthetic Column From a Spec
- [`make_synthetic_csv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_csv.md)
  : Generate a Synthetic CSV From a Schema Recipe

## Text & encoding utilities

ASCII transliteration and safe text fallbacks for non-UTF-8 sinks.

- [`to_ascii()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/to_ascii.md)
  : Transliterate Text to Plain ASCII
- [`ascii_fallback()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ascii_fallback.md)
  : Use Text As-Is, Falling Back to ASCII When It Cannot Be Represented
- [`write_text_fallback()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_text_fallback.md)
  : Write Text as UTF-8, Falling Back to ASCII on an Encoding Error

## Core numeric primitives

Thin R wrappers over the shared compiled morie core (mean, variance,
correlation, normal density) that the whole ecosystem links against.

- [`core_mean()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_stats.md)
  [`core_var()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_stats.md)
  [`core_cor()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_stats.md)
  : Fast summary statistics (C backend)
- [`core_normal_pdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_normal_pdf.md)
  : Normal density (C backend)
