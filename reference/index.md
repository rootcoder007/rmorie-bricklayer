# Package index

## Fetch open data

Resilient downloaders with libcurl + Wayback fallback for pulling public
datasets over flaky endpoints.

- [`bricklayer_fetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch.md)
  : Fetch a URL to disk with an Internet Archive fallback (C++/libcurl)
- [`bricklayer_fetch_siu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch_siu.md)
  : Fetch an Ontario SIU director's report by drid
- [`download_data()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/download_data.md)
  : Download a File
- [`friendly_download()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/friendly_download.md)
  : Download a File With Diagnostic Error Messages

## SIU report mining

Deterministic, offline parse/resolve core for Ontario Special
Investigations Unit director’s reports — schema, parser,
subject-official resolver.

- [`bricklayer_siu_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_schema.md)
  : The panel-reviewed SIU report field schema
- [`bricklayer_parse_siu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_parse_siu.md)
  : Parse an SIU director's report into the schema fields
- [`bricklayer_fetch_parse_siu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch_parse_siu.md)
  : Fetch and parse one SIU director's report
- [`bricklayer_siu_text()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_text.md)
  : Convert SIU report HTML to plain text
- [`bricklayer_siu_iso_date()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_iso_date.md)
  : Convert a human-readable SIU report date to ISO format
- [`bricklayer_siu_resolve_so()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_resolve_so.md)
  : Resolve the subject-official count from SIU report text

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
- [`manifest_canonical()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md)
  [`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md)
  : The canonical serialisation of a manifest, and its digest
- [`manifest_recompute()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_recompute.md)
  : Recompute a manifest's recorded statistics against the data
- [`manifest_record_seed()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_record_seed.md)
  [`manifest_restore_seed()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_record_seed.md)
  : Record and restore the random number generator state
- [`capture_dependencies()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_dependencies.md)
  : Where each loaded package came from
- [`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md)
  : Write a Manifest to JSON
- [`write_summary_txt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_summary_txt.md)
  : Write a Plain-Language Run Summary
- [`agent_bundle()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agent_bundle.md)
  : Agent-assisted reproducibility-bundle help

## JSON (native codec)

jsonlite’s mapping in base R, byte-for-byte; no jsonlite at run time.

- [`bricklayer_json_from_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_from_json.md)
  : Parse JSON into R objects (jsonlite's fromJSON, natively)
- [`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md)
  : Encode an R object as JSON (jsonlite's toJSON, natively)
- [`bricklayer_json_serialize()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_serialize.md)
  [`bricklayer_json_unserialize()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_serialize.md)
  : Lossless JSON serialisation of an R object
- [`json_gzip_encode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_gzip.md)
  [`json_gzip_decode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_gzip.md)
  : Compressed, base64-encoded JSON
- [`bricklayer_json_base64_enc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_base64.md)
  [`bricklayer_json_base64_dec()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_base64.md)
  [`bricklayer_json_base64url_enc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_base64.md)
  [`bricklayer_json_base64url_dec()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_base64.md)
  : Base64 encoding

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

Thin R wrappers over the shared compiled core that the whole ecosystem
links against via `LinkingTo: rmoriebricklayer`, so every sibling
package computes with one copy of the arithmetic.

- [`core_mean()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_stats.md)
  [`core_var()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_stats.md)
  [`core_cor()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_stats.md)
  : Fast summary statistics (C backend)
- [`core_normal_pdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_normal_pdf.md)
  : Normal density (C backend)
- [`core_normal_logpdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_normal_logpdf.md)
  : Normal log-density (C backend)
- [`core_sd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_spread.md)
  [`core_dist()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_spread.md)
  : Standard deviation and Euclidean distance (C backend)
- [`core_moments()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_moments.md)
  : Mean, variance, skewness and kurtosis in one pass (C backend)
- [`core_quantile()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_robust.md)
  [`core_median()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_robust.md)
  [`core_mad()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_robust.md)
  [`core_iqr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_robust.md)
  [`core_tukey_fences()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_robust.md)
  : Quantiles, median and robust spread (C backend)
- [`core_trimmed_mean()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_trimmed.md)
  [`core_winsorized_mean()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_trimmed.md)
  : Trimmed and winsorized means (C backend)
- [`core_weighted()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_weighted.md)
  : Weighted mean and variance (C backend)
- [`core_cor_spearman()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_rank.md)
  [`core_midranks()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_rank.md)
  : Rank correlation and midranks (C backend)
- [`core_cov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_cov.md)
  : Covariance matrix of a numeric matrix (C backend)
- [`core_bootstrap_mean()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_bootstrap_mean.md)
  : Bootstrap replicate means (C backend)
- [`core_ipw_weights()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_ipw_weights.md)
  : Trimmed inverse-probability weights (C backend)
- [`core_gamma_cdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_gamma_cdf.md)
  : Regularized incomplete gamma function (C backend)
- [`core_hawkes_nll()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_hawkes_nll.md)
  : Hawkes-process negative log-likelihood (C backend)

## Distributional drift

Whether a freshly fetched column is still the column the capsule was
pinned against. A byte digest cannot answer this: a re-release can be
statistically identical yet differ byte-for-byte, and a column can keep
its name and type while having been silently rescaled.

- [`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
  : Compare a fetched data frame with the one a capsule was pinned
  against
- [`drift_ks()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_ks.md)
  : Two-sample Kolmogorov-Smirnov test (C backend)
- [`drift_psi()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_psi.md)
  : Population stability index and Jensen-Shannon divergence (C backend)
- [`drift_chisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_chisq.md)
  : Chi-square test for a categorical column
- [`drift_homogeneity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_homogeneity.md)
  : Chi-square test of homogeneity for two categorical samples
- [`benford_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/benford_test.md)
  : Benford first-digit test

## Signed provenance

Authenticated rather than merely checksummed. Keyed digests for a shared
secret, post-quantum hash-based signatures for a public verifier, Merkle
trees to pin a capsule chunk by chunk, and hash chains to make the run
history itself tamper-evident.

- [`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)
  [`capsule_check_attestation()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)
  : Attest a capsule, binding a signature to what it covers
- [`capsule_bundle()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_bundle.md)
  [`capsule_bundle_read()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_bundle.md)
  [`capsule_bundle_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_bundle.md)
  : Bundle a capsule into one signed artifact
- [`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md)
  : Run falsification controls against a statistic
- [`capsule_power()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_power.md)
  : Detect an injected effect of known size
- [`prereg_declare()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prereg_declare.md)
  [`prereg_check()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prereg_declare.md)
  : Declare an analysis before running it
- [`falsify_family()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/falsify_family.md)
  : Correct a family of falsification results for multiple testing
- [`evalue_rr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evalue_rr.md)
  : How strong would an unmeasured confounder have to be
- [`timestamp_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/timestamp_verify.md)
  [`timestamp_info()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/timestamp_verify.md)
  : Verify an RFC 3161 timestamp token
- [`cert_parse()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_parse.md)
  : Parse an X.509 certificate
- [`cert_chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_chain_verify.md)
  : Verify a certificate chain
- [`revocation_fetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/revocation_fetch.md)
  : Fetch revocation data for a certificate path
- [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
  : Sign a capsule manifest
- [`capsule_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_verify.md)
  : Verify a capsule manifest signature
- [`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
  : Generate a post-quantum signing key for capsule provenance
- [`signing_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/signing_public_key.md)
  : Public half of a signing key
- [`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
  [`fips_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
  : Generate a standardised post-quantum signing key
- [`fips_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_key.md)
  : Assemble a standardised key from raw key material
- [`fips_mu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_mu.md)
  [`fips_sign_mu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_mu.md)
  [`fips_verify_mu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_mu.md)
  : Sign an ML-DSA message digest computed elsewhere
- [`fips_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_sizes.md)
  : Byte lengths of a standardised signature scheme
- [`kem_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md)
  [`kem_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md)
  : Generate an ML-KEM key pair
- [`kem_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_sizes.md)
  : Byte lengths of an ML-KEM parameter set
- [`kem_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_encapsulate.md)
  : Encapsulate a shared secret under an ML-KEM key
- [`kem_decapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_decapsulate.md)
  : Recover a shared secret from an ML-KEM ciphertext
- [`oqs_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/oqs_keygen.md)
  [`oqs_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/oqs_keygen.md)
  : Generate a standardised post-quantum signing key (deprecated name)
- [`pqc_backends()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_backends.md)
  : Available post-quantum signature schemes
- [`chain_new()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  [`chain_append()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  [`chain_head()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  [`chain_seal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  [`chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  : Tamper-evident chain of capsule manifests
- [`merkle_root()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md)
  [`merkle_leaves()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md)
  [`merkle_proof()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md)
  [`merkle_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md)
  : Merkle tree over capsule chunks (C backend)
- [`chunk_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chunk_file.md)
  : Split a file into fixed-size chunks

## Digests and keys

The hashes and key-derivation the provenance layer is built on, each
verified against its published test vectors.

- [`core_sha512()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha512.md)
  : SHA-512 hex digest (C backend)
- [`core_crc32()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_crc32.md)
  : CRC-32 checksum (C backend)
- [`core_blake2b()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_blake2b.md)
  : BLAKE2b digest, optionally keyed
- [`core_hmac_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_keyed_digest.md)
  [`core_digest_equal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_keyed_digest.md)
  : Keyed digest and constant-time comparison (C backend)
- [`sha512_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_file_digest.md)
  [`crc32_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_file_digest.md)
  : SHA-512 and CRC-32 of a file
- [`digest_object()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/digest_object.md)
  : Digest an arbitrary R object
- [`random_bytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/random_bytes.md)
  : Cryptographically strong random bytes
- [`derive_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/derive_key.md)
  : Derive a key from a passphrase

## Schema and rules

Derive a pinnable schema from data you already trust, then declare the
project-specific checks a generic schema cannot express.

- [`infer_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infer_schema.md)
  : Infer a pinnable schema from a data frame
- [`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
  : Declare a validation rule
- [`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md)
  : Apply declared rules to a data frame
- [`rule_in_set()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
  [`rule_between()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
  [`rule_not_null()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
  [`rule_unique()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
  [`rule_regex()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
  [`rule_increasing()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
  [`rule_within_n_mads()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
  [`rule_complete_rows()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
  [`rule_distinct_rows()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
  [`rule_col_count()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
  : Ready-made validation rules

## Period-over-period change

Year-over-year change matched on the period’s own value rather than on
row order, so a missing year is a gap instead of a quietly multi-year
comparison. A percent off a small base is withheld with its reason; a
percentage is reported in percentage points; a ratio of counts carries
the exact conditional-binomial interval. The same object renders to
HTML, PDF, CSV, TSV, JSON or Markdown.

- [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
  [`print(`*`<rmbl_yoy>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
  : Year-over-year (and period-over-period) change
- [`yoy_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_summary.md)
  : Summarise a change table
- [`yoy_label()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_label.md)
  : Label a period without changing it
- [`fiscal_year_label()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fiscal_year_label.md)
  : Name a fiscal year by the years it spans
- [`yoy_html()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md)
  [`yoy_pdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md)
  : Render a change table to HTML or PDF
- [`yoy_write()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_write.md)
  : Write a change table to a file, in whatever format the name implies
- [`yoy_csv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md)
  [`yoy_tsv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md)
  [`yoy_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md)
  [`yoy_markdown()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md)
  : Write a change table as delimited text, JSON or Markdown
- [`yoy_palettes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_palettes.md)
  : Colour palettes for change tables

## Banded categories

Published categories are intervals – “2 to 5”, “50+” – and anything
computed from them rests on where inside each band the mass sits and on
where the open top band ends. These parse to bounds, make the
representative-value rule explicit, and measure how far a result moves
as the open band’s assumed cap varies.

- [`parse_bands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/parse_bands.md)
  : Parse banded category labels into numeric bounds
- [`band_values()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_values.md)
  : Representative values for banded categories
- [`expand_bands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expand_bands.md)
  : Expand a banded frequency table into per-unit values
- [`band_sensitivity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md)
  [`print(`*`<rmbl_band_sensitivity>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md)
  : How much a result depends on the open band's assumed cap

## Concentration and association

Whether a few units account for most of a total, and how strongly two
categorical variables move together. Gini is twice the area under its
own Lorenz curve, and has a ceiling of 1 - 1/n rather than 1. The tail
index maximises the exact discrete likelihood, the closed-form
continuity correction being badly biased at the small thresholds
administrative counts start from.

- [`gini()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
  [`lorenz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
  [`top_share()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
  : Concentration of a total across units
- [`hill_tail_index()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hill_tail_index.md)
  : Tail index of a heavy-tailed count
- [`hurwitz_zeta()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hurwitz_zeta.md)
  : Hurwitz zeta function
- [`cramers_v()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cramers_v.md)
  : Association in a contingency table

## Trend in a short series

An annual extract is five to ten points, which supports a rank test and
a resistant slope but not a model with an autocorrelation structure. The
step test takes its p-value from the permutation distribution of the
maximum over splits, not from the best split’s own test.

- [`trend_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trend_test.md)
  : Trend in a short series
- [`step_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/step_change.md)
  : A single step change, with the scan's own null distribution
- [`count_trend()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/count_trend.md)
  : Trend in a count series, as a rate ratio per period

## Region-coded counts

A region is an areal unit with a population, not a coordinate. Indirect
standardisation removes the part of a difference explained by who the
area holds; empirical Bayes stops a small area’s noise from ranking it
to the top or bottom; a funnel plot shows the reader the same thing
directly.

- [`expected_counts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expected_counts.md)
  : Expected counts under indirect standardisation
- [`sir()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sir.md)
  : Standardised incidence ratio, with an exact interval
- [`eb_rates()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/eb_rates.md)
  : Empirical Bayes rates, shrunk toward the overall experience
- [`funnel_limits()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/funnel_limits.md)
  : Funnel-plot control limits
- [`morans_i()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/morans_i.md)
  : Global Moran's I over a neighbour list

## Describe a capsule

The summaries worth reading before trusting a capsule: what every column
looks like, where the gaps are, which values dominate, and which rows do
not belong.
[`capsule_report()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_report.md)
runs the lot and orders the findings by severity.

- [`capsule_report()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_report.md)
  : Assess a capsule in one call
- [`report_markdown()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/report_markdown.md)
  : Write a capsule report as Markdown
- [`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md)
  : Column report for a data frame
- [`inline_hist()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/inline_hist.md)
  : Inline histogram for a numeric vector
- [`frequency_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/frequency_table.md)
  : Frequency table for one column
- [`correlation_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/correlation_table.md)
  : Full pairwise correlation table
- [`top_correlations()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/top_correlations.md)
  : Strongest pairwise correlations in a data frame
- [`mahalanobis_outliers()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mahalanobis_outliers.md)
  : Multivariate outliers by Mahalanobis distance
- [`duplicate_rows()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/duplicate_rows.md)
  : Duplicated rows, with their groups
- [`drop_empty()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_drop.md)
  [`drop_constant()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_drop.md)
  : Drop empty or constant columns and rows
- [`clean_column_names()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/clean_column_names.md)
  : Tidy the column names of an ingested table
- [`environment_diff()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/environment_diff.md)
  : Compare two captured environments

## Missingness

Not just how much is missing, but the shape of it – which columns go
together, whether the gaps are contiguous, and whether the missingness
is related to the data (in which case dropping incomplete rows is
biased).

- [`missingness_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_summary.md)
  : Missingness in one line per question
- [`missingness_pattern()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_pattern.md)
  : Which columns are missing together
- [`missing_runs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missing_runs.md)
  : Runs of consecutive missing values
- [`missingness_map()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_map.md)
  : Text map of where the missing values are
- [`mcar_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mcar_test.md)
  : Little's test for data missing completely at random

## Large capsules

One-pass algorithms for members bigger than memory: exact block-wise
moments, uniform sampling of a stream, and fixed-memory distinct counts.

- [`online_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_online.md)
  [`summary_update()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_online.md)
  [`summary_merge()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_online.md)
  [`summary_stats()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_online.md)
  : Exact summary statistics accumulated in blocks
- [`reservoir_indices()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_reservoir.md)
  [`reservoir_sample()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_reservoir.md)
  : Uniform sample of a stream in one pass
- [`distinct_sketch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_distinct.md)
  [`distinct_count()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_distinct.md)
  [`sketch_merge()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_distinct.md)
  : Distinct-value count in fixed memory

## Output

Printed reports for the objects the package returns.

- [`print(`*`<bricklayer_attestation>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_attestation_check>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_bundle>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_bundle_check>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_chain>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_falsification>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_kem_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_kem_public_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_kem_capsule>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_mcar>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_power>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_prereg>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_prereg_check>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_falsify_family>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_drift>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`summary(`*`<bricklayer_drift>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_benford>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_signing_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_public_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_signature>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`summary(`*`<bricklayer_benford>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_env_diff>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_report>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`summary(`*`<bricklayer_report>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_recompute>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_schema>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_oqs_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_oqs_public_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_timestamp>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_certificate>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  [`print(`*`<bricklayer_certpath_check>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_print_methods.md)
  : Printed reports for bricklayer objects
