# rmoriebricklayer 0.4.0

The release that makes a capsule answer three questions a checksum
cannot: is this still the same *data*, who *says* so, and what is
actually *in* it.

## Is this still the same data?

A SHA-256 tells you the bytes changed. It cannot tell you whether the
distribution changed -- and those are different questions. A re-released
open-data extract legitimately has a different digest while being the
same data statistically; conversely a column can keep its name, its type
and its row count while having been silently rescaled, and no digest
notices.

* `capsule_drift()` tests every shared column between a pinned extract
  and a fresh fetch, and reports which moved.
* `drift_ks()` (two-sample Kolmogorov-Smirnov), `drift_psi()`
  (population stability index and Jensen-Shannon divergence),
  `drift_homogeneity()` (two-sample chi-square) and `drift_chisq()`
  (goodness-of-fit against a known distribution) are available
  individually.
* `benford_test()` screens a numeric column's leading digits against
  Benford's law -- a cheap check on figures that were rounded, capped or
  invented. It is a screen, not a verdict, and says so.

`capsule_drift()` uses the two-sample homogeneity test for categorical
columns, not goodness-of-fit: the reference is itself a finite sample,
and treating it as a known distribution ignores its sampling error and
reports drift too readily. For the same reason the population stability
index is reported as an effect size but only allowed to raise the drift
flag once both samples pass `psi_min_n` -- its 0.25 "material shift"
band is a large-sample heuristic with no calibrated null, and on a few
hundred rows binning noise alone clears it.

## Who says so?

A digest in a manifest proves the data was not corrupted. It proves
nothing about who produced it, because anyone who edits the data can
recompute the digest.

* `capsule_sign()` / `capsule_verify()` authenticate a manifest, either
  with a shared secret (`HMAC-SHA-256`, RFC 2104) or with a
  post-quantum, asymmetric, hash-based signature.
* `pqc_keygen()` builds that signature's key: a Merkle tree over
  Winternitz one-time keys, following the RFC 8391 construction over the
  SHA-256 this package already ships. Its security rests on the hash
  alone -- no lattice assumption, no elliptic curve, nothing Shor's
  algorithm breaks, and no new system dependency.
* `merkle_root()` and friends pin a capsule chunk by chunk, so a
  mismatch names *which* chunk moved rather than only that the file did.
* `chain_new()` / `chain_append()` link each manifest to the digest of
  the one before, making the run history tamper-evident. `chain_seal()`
  is the value to sign: the head alone misses a deletion from the middle
  and the links alone miss a truncation from the end.

On post-quantum choices: SHA-2 and HMAC are already adequate against a
quantum adversary, since Grover only halves the exponent. Signatures are
the part Shor breaks, so that is the part replaced.

A lattice scheme is deliberately **not** hand-rolled here -- an
uncertified hand-written NTT and rejection sampler would be a worse
outcome than no lattice signature. Instead, `./configure` looks for
liboqs, and where it is found `oqs_keygen()` exposes the standardised
schemes -- ML-DSA (FIPS 204) and SLH-DSA (FIPS 205) -- computed entirely
by that library. `pqc_backends()` reports what the build actually
enabled, checked per scheme, since liboqs is configurable. Absence is
not an error: the package builds without it, and the bundled hash-based
scheme needs nothing.

Unlike the hash-based key, the standardised keys are STATELESS -- one key
signs any number of messages, with no leaf index to track. A signature
is never verified against a key of a different scheme.

A height-`h` signing key signs exactly `2^h` messages. Signing twice at
one index breaks the scheme outright, so `capsule_sign()` tracks the
index, returns the advanced key state, and refuses an exhausted key
rather than wrapping around.

## What is actually in it?

A capsule is only worth pinning if somebody looked at the data first,
and the look is the step that gets skipped.

* `profile_columns()` describes every column: type, missingness,
  distinct values, the counts of zero, negative and infinite values, the
  classical *and* robust centre and spread side by side (where they
  disagree, the mean is not describing the column), and an
  `inline_hist()` sketch that shows bimodality no summary number
  carries.
* `frequency_table()`, `correlation_table()`, `top_correlations()`,
  `duplicate_rows()`, `drop_empty()`, `drop_constant()` and
  `clean_column_names()` cover the rest of a first pass.
* `mahalanobis_outliers()` finds rows that are unremarkable on every
  variable separately and impossible jointly. It defaults to a robust
  centre and scale, because outliers inflate the very covariance used to
  judge them.
* `missingness_summary()`, `missingness_pattern()`, `missing_runs()` and
  `missingness_map()` describe the *shape* of the gaps, not just the
  rate: whether columns are missing together, and whether a gap is one
  outage or scattered failures.
* `mcar_test()` is Little's test for missing-completely-at-random --
  the assumption that licenses dropping incomplete rows. It carries an
  expectation-maximisation estimator, because the maximum-likelihood
  mean and covariance under missingness have no closed form; on complete
  data that estimator reproduces the ML estimates exactly.
* `environment_diff()` reports what moved between two runs' captured
  environments, which is the question a failed reproduction actually
  raises.

## Schemas and rules

* `infer_schema()` derives the schema `validate_schema()` consumes from
  data you already trust, so a capsule need not be pinned on nothing.
  It describes one extract and should be read and edited, not trusted
  blindly.
* `validate_schema()` gains the checks to match: column types (with
  integer and double treated as interchangeable), numeric ranges, and
  per-column missingness ceilings. Every field stays optional, so
  schemas written for earlier versions are unaffected.
* `rule()` and `validate_rules()` express the project-specific checks a
  generic schema cannot -- an age that must be non-negative, two dates
  that must be ordered -- and `rule_in_set()`, `rule_between()`,
  `rule_not_null()`, `rule_unique()`, `rule_regex()`,
  `rule_increasing()`, `rule_within_n_mads()`, `rule_complete_rows()`,
  `rule_distinct_rows()` and `rule_col_count()` supply the common ones
  ready-made.

## Capsules larger than memory

* `online_summary()` accumulates mean, variance, skewness and kurtosis
  block by block. The merge is **exact** -- Chan, Golub and LeVeque's
  parallel combination with Terriberry's higher moments -- so a chunked
  pass agrees with a single batch pass rather than approximating it.
* `reservoir_indices()` / `reservoir_sample()` take a uniform sample of
  a stream in one pass (Vitter's Algorithm R).
* `distinct_sketch()` / `distinct_count()` estimate cardinality in fixed
  memory (HyperLogLog), with the published relative error.

## Newly reachable

Several things existed in the package with no way to call them. The
compiled core carried kernels that had no binding, and the JSON codec
had three internal helpers:

* `core_sd()`, `core_dist()`, `core_normal_logpdf()`,
  `core_bootstrap_mean()`, `core_ipw_weights()`, `core_gamma_cdf()` and
  `core_hawkes_nll()` now reach kernels that were already compiled in.
* `bricklayer_json_serialize()` / `bricklayer_json_unserialize()` --
  lossless JSON that round trips an object rather than only its data --
  were internal, and left a dangling documentation link.
* The base64 codec (`bricklayer_json_base64_enc()` and the URL-safe
  variant) was internal too.
* `json_gzip_encode()` / `json_gzip_decode()` are new: gzip plus base64,
  for a payload that travels.

All of these are published through `LinkingTo: rmoriebricklayer`, so
`rmorie` and `rmoriedata` call one compiled copy rather than carrying
their own.

## Keys

`pqc_keygen()`'s seeds previously came from a function that mixed the
clock, the process id and R's Mersenne Twister. `set.seed()` makes R's
generator reproducible by design and its state is recoverable from its
output, so a key drawn from it is guessable.

* `random_bytes()` reads the operating system's CSPRNG and **fails**
  rather than falling back to a weaker source.
* `derive_key()` is PBKDF2-HMAC-SHA256, so a passphrase can stand in for
  raw key bytes.
* `core_blake2b()` is a natively keyed digest of any width from 1 to 64
  bytes -- a MAC without the HMAC construction.
* `digest_object()` fingerprints an arbitrary R object.

## Verification

Everything with a published test vector is checked against it: SHA-512
against FIPS 180-4, HMAC-SHA-256 against RFC 4231, PBKDF2-HMAC-SHA256
against the published vectors including the multi-block case, BLAKE2b
against RFC 7693, and CRC-32 against the ITU V.42 check value. The
statistics are anchored on base R, the Merkle construction on digests
recomputed by hand, and the exceedance and reservoir distributions on
exhaustive enumeration and simulation respectively.

The XMSS signature scheme has **no** official known-answer vectors
available offline, so it is verified against its security properties
instead -- a valid signature verifies, and every tampering of the
message, signature, authentication path, index or key fails. It is not
claimed to be byte-compatible with other XMSS implementations and must
not be treated as certified.

# rmoriebricklayer 0.3.11

Test fix; no code changes.

`test-json-branches.R` asserted one platform's spelling of a
full-precision double. With `digits = NULL` the encoder calls
`sprintf("%.17g", ...)`, which asks the C library for 17 significant
digits and lets it choose how to print them: x86 gives
`9.9999999999999995e-21` for `1e-20`, Windows arm64 gives `1e-20`. Both
are the same double and both round trip, but the hard-coded expectation
failed the arm64 builds on r-universe.

The test now asserts the contract the option actually promises -- full
precision that survives a round trip -- and carries an anchor that fails
if the round trip stops being exact.

# rmoriebricklayer 0.3.10

Documentation only; no code changes.

The manual still credited 'jsonlite' and 'digest' for work the package
now does itself, which had been true before 0.3.8 moved both to Suggests
behind a native JSON codec and a compiled SHA-256 core:

* `load_provenance()` said it parsed via `jsonlite::fromJSON()`, and
  linked to it; it reads with `bricklayer_json_from_json()`.
* `verify_capsule()`'s example called `jsonlite::write_json()` -- a
  Suggests package used unconditionally in an example. It now writes with
  `bricklayer_json_to_json()`.
* `sha256_file()` and `verify_sha256()` said they hashed "via the digest
  package"; they use the compiled core, or the bundled pure-R FIPS 180-4
  implementation when a capsule is sourced standalone.
* `wayback_snapshot_url_native()` described the R-level resolver it
  supersedes as "jsonlite-based"; that resolver parses natively too.
* `write_manifest_json()`'s example said it round-tripped through
  'jsonlite'.

# rmoriebricklayer 0.3.9

* The native JSON codec is now jsonlite's complete mapping: every `toJSON()`
  option (dataframe/matrix/Date/POSIXt/factor/complex/raw/null/na/digits/
  pretty/force plus rownames, keep_vec_names, json_verbatim, always_decimal,
  time_format, UTC, no_dots), the same number formatting (`num_to_char` /
  `modp_dtoa2` rules), `fromJSON()` simplification (record lists, matrices,
  arrays, `$date`, `_row`, `"NA"` strings), prettify/minify (yajl layout),
  validate, serializeJSON/unserializeJSON, base64, ndjson streaming and
  rbind_pages. A parity test pins all of it to jsonlite byte-for-byte when
  jsonlite is installed (1,742 cases, 0 differences).
* Standalone capsule bundles: `make_bundle.sh` now ships `json_native.R`
  and a pure-R SHA-256 (`sha256_native.R`), `setup_and_run.R` no longer
  requires jsonlite, and `sha256_file()` falls back to the pure-R digest
  when the compiled core is not loaded. This fixes the 0.3.8 CI failure of
  the otis-mrp bundle (`bricklayer_json_from_json` not found).
* pkgdown index and examples for the two exported codec functions.

# rmoriebricklayer 0.3.8

* No more runtime dependence on 'digest' or 'jsonlite': Imports is now
  base R only (`stats`, `utils`). `sha256_file()` hashes through the
  compiled SHA-256 core that already backed `core_sha256()`; every JSON
  read (CKAN, Socrata, ArcGIS, Wayback metadata, local manifests) and the
  manifest writer go through a new pure-R, jsonlite-compatible codec
  exported as `bricklayer_json_from_json()` / `bricklayer_json_to_json()`
  (same simplification rules and encoder options as jsonlite). Both old
  packages move to Suggests and are only used by the cross-check tests,
  which pin the native codec and hash to their output when installed.
* Remote JSON endpoints are fetched with `bricklayer_fetch()` (the
  compiled fetch core with its Wayback fallback) instead of jsonlite's
  URL reader.

# rmoriebricklayer 0.3.7

* Test-only change: local_mocked_bindings() tests are guarded so they skip
  cleanly under a bare testthat::test_dir() (they need the package namespace,
  which devtools::test() and R CMD check provide). No user-facing change.

# rmoriebricklayer 0.3.6

* CRAN incoming-pretest NOTE cleanup: quote 'Wayback Machine' in
  DESCRIPTION; README Code-of-Conduct link is now an absolute URL (the
  file is .Rbuildignore'd, so the relative URI flagged as invalid).

# rmoriebricklayer 0.3.5

* SIU features now live natively in bricklayer: the deterministic parse/resolve core is part of `src/` (zero new dependencies, hand-rolled `.Call` glue like the rest of the backend). New: `bricklayer_parse_siu()` (16 schema fields + language from report HTML or a saved file), `bricklayer_fetch_parse_siu()` (fetch + parse in one call), `bricklayer_siu_schema()`, `bricklayer_siu_text()`, `bricklayer_siu_iso_date()`, `bricklayer_siu_resolve_so()` (rule-ordered subject-official count; 0 is a real answer). Synthetic-report fixture + offline tests included.

# rmoriebricklayer 0.3.4

* CRAN reviewer round (K. Lauseker, 0.3.0): spell out CKAN + SHA-256 and link the CKAN/Wayback web services in DESCRIPTION; agent_bundle example `\dontrun` -> `\donttest`; setup_and_run.R no longer calls `setwd()`, `install.packages()`, or `installed.packages()` (checks via `requireNamespace()` and prints the install command instead).

# rmoriebricklayer 0.3.3

* Add `bricklayer_fetch_siu(drid, dest)`: fetch an Ontario SIU director's report by drid through the live+Wayback engine -- the fetch step of the open SIU corpus pipeline.

# rmoriebricklayer 0.3.2

## Documentation

* Every exported function now carries exhaustive, multiple-example
  documentation covering each argument, edge cases, and a realistic
  workflow (previously most had a single one-liner).
* Version bump ensures the `bricklayer_fetch()` help topic (added in an
  earlier 0.3.1 build without a version bump) propagates to the
  r-universe binary and downstream reverse-dependency checks.

# rmoriebricklayer 0.3.1

## rOpenSci submission preparation

* License wording corrected: the optional `rmorie` CLI that
  `agent_bundle()` forwards to is AGPL-3.0-or-later (the entire MORIE
  family is AGPL; an earlier internal comment mislabelled it
  proprietary).

* Package moved from the `bricklayer/` subdirectory to the repository
  root (required by rOpenSci's review tooling); repo-level extras stay
  as `.Rbuildignore`d siblings.
* New vignette `capsules.Rmd` walking the essential flow offline:
  provenance pin -> schema validation -> SHA256 integrity ->
  synthetic fallback -> manifest + summary.
* Every exported function now has runnable `@examples` (network calls
  in `\donttest`; offline NULL-contracts shown runnable).
* README gained development-version install instructions.
* New CI: test coverage (covr + Codecov) and rOpenSci `pkgcheck`.
* Test coverage raised from 84 percent to 96 percent: offline tests for the
  CKAN/Socrata/ArcGIS resolver success paths, `friendly_download`
  diagnostics and Wayback retry, summary contact/licence blocks, pinned
  script hashes, and the multi-block SHA-256 path. Dead `requireNamespace`
  guards for Imports (`digest`, `jsonlite`) removed.
* Repo-level `LICENSE` text excluded from the build (`License: AGPL-3`
  is the canonical spec; the stray file triggered a check NOTE).

# rmoriebricklayer 0.3.0

## Capsule-level integrity

* New `verify_capsule()`: one call re-verifies an entire reproducible
  data capsule offline: provenance readability, pinned sha256/size/row
  count, schema validity, script hash, and re-derivation of every
  stored manifest cross-check from its own numbers.
* New `capture_environment()` records R version, platform, OS, UTC
  timestamp, and loaded package versions; `make_manifest()` now attaches
  it by default (`environment = FALSE` to opt out).
* New `cite_capsule()` generates a ready-to-paste data citation (text +
  BibTeX `@misc`, DOI-aware) from a provenance object.

## Portal coverage

* New `resolve_via_socrata()` and `resolve_via_arcgis()` extend
  URL-rot recovery beyond CKAN to the Socrata (Calgary/Chicago/NYC) and
  ArcGIS FeatureServer (Toronto Police Service) portals the MORIE
  family fetches from.

# rmoriebricklayer 0.2.5

* `make_synthetic_column("id_pattern")` without a `year_col` now returns
  all `n` ids (a vectorised-`gsub` misuse returned a single id).
* `bernoulli` columns unlist JSON-derived `labels`, fixing mangled
  column names from provenance-parsed schemas.
* Single-value `row_replication` no longer trips base R's scalar
  `sample()` expansion.
* Test suite grown from 9 to 43 behavioural tests covering the full
  export surface (provenance, CKAN guards, Wayback handling, offline
  file:// downloads, sha256, schema validation, manifests, synthetic
  generation, RNG hygiene).

# rmoriebricklayer 0.2.4

* `make_synthetic_csv()` now restores the caller's `.Random.seed` on exit
  (CRAN policy: no lasting RNG-state change).
* First CRAN submission prep: `cran-comments.md`, build exclusions.

# rmoriebricklayer 0.2.3

* Capsule terminology adopted across the documentation; CITATION added;
  37/37 reproduction checks in `examples/otis-mrp/`.