# rmoriebricklayer

> Brick-proof, reproducible data capsules for R.

`rmoriebricklayer` resolves open-data sources, records and verifies
provenance, validates downloaded data against a pinned schema, and falls
back to schema-driven synthetic data when the real source is unreachable
— so any analysis result can be traced back to its exact inputs.

A checksum answers one question: are these the same bytes? The package
exists because that is rarely the question that matters. A re-released
extract can be statistically identical and differ byte-for-byte; a
column can keep its name, type and row count while having been silently
rescaled; and a digest anyone can recompute says nothing about who
produced the data.

## What it does

- **CKAN resolution** —
  [`resolve_via_ckan()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_ckan.md)
  /
  [`resolve_via_ckan_search()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_ckan_search.md)
  locate resources through a portal’s `package_show` / `package_search`
  endpoints.
- **Provenance** —
  [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md),
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md),
  [`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md),
  [`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md),
  and
  [`write_summary_txt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_summary_txt.md)
  capture every run as a manifest plus a plain-language summary.
- **Integrity** —
  [`sha256_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256_file.md)
  /
  [`verify_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_sha256.md)
  hash and verify downloads;
  [`download_data()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/download_data.md)
  /
  [`friendly_download()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/friendly_download.md)
  fetch with a Wayback Machine fallback.
- **Schema validation** —
  [`infer_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infer_schema.md)
  derives a pinnable schema from data you trust;
  [`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
  checks names, types, ranges, value sets and missingness against it;
  [`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
  and the `rule_*()` library express the project-specific checks a
  generic schema cannot.
- **Drift detection** —
  [`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
  asks whether the *data* moved, not just the bytes, with
  Kolmogorov-Smirnov, two-sample homogeneity, population stability
  index, Jensen-Shannon divergence and a Benford first-digit screen.
- **Signed provenance** —
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
  authenticates a manifest with a keyed digest or a post-quantum
  hash-based signature;
  [`merkle_root()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md)
  pins a capsule chunk by chunk so a mismatch names which chunk moved;
  and
  [`chain_append()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  links manifests so the run *history* is tamper-evident, not only each
  run.
- **Description** —
  [`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md),
  [`frequency_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/frequency_table.md),
  [`correlation_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/correlation_table.md),
  [`mahalanobis_outliers()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mahalanobis_outliers.md),
  [`missingness_map()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_map.md)
  and
  [`mcar_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mcar_test.md)
  (Little’s test, with the EM estimator it requires) describe a capsule
  before you trust it.
- **Capsules larger than memory** — exact block-wise moment
  accumulation, reservoir sampling, and HyperLogLog distinct counts, all
  in one pass.
- **Synthetic fallback** —
  [`make_synthetic_column()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_column.md)
  /
  [`make_synthetic_csv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_csv.md)
  generate schema-driven stand-ins when the real source is down, so a
  pipeline still runs end-to-end.

Every primitive with a published test vector is checked against it:
SHA-512 (FIPS 180-4), HMAC-SHA-256 (RFC 4231), PBKDF2-HMAC-SHA256,
BLAKE2b (RFC 7693) and CRC-32 (ITU V.42). The statistics are anchored on
base R. The one exception is the XMSS signature scheme, which has no
offline known-answer vectors and is verified against its security
properties instead — it follows the RFC 8391 construction but is not
claimed to be byte-compatible with other implementations.

## Installation

Released version from
[CRAN](https://CRAN.R-project.org/package=rmoriebricklayer):

``` r

install.packages("rmoriebricklayer")
```

Latest build from r-universe (tracks `main` ahead of CRAN):

``` r

install.packages(
  "rmoriebricklayer",
  repos = c("https://rootcoder007.r-universe.dev",
            "https://cloud.r-project.org")
)
```

Development version from GitHub:

``` r

# install.packages("remotes")
remotes::install_github("rootcoder007/rmorie-bricklayer")
```

## Quick example

``` r

library(rmoriebricklayer)

prov <- load_provenance("provenance.json")     # pinned source + schema + hash
res  <- resolve_via_ckan(prov)                  # find the resource on the portal
path <- friendly_download(res$url, "data.csv")  # download (Wayback fallback)
verify_sha256(path, prov$sha256)                # integrity check
df   <- validate_schema(read.csv(path), prov)   # schema-validated data frame

man  <- make_manifest(project = "my-study")
record(man, "input", path)                      # trace the input
write_manifest_json(man, "manifest.json")
```

Then ask whether the data itself moved, and sign the answer:

``` r

# Did the distribution change, not just the bytes?
capsule_drift(reference_extract, fresh_fetch)

# Authenticate the manifest so a verifier knows who produced it.
key <- pqc_keygen()                              # post-quantum, hash-based
sig <- capsule_sign(core_sha256(readLines("manifest.json")), key)
capsule_verify(core_sha256(readLines("manifest.json")), sig,
               signing_public_key(key))
```

See
[`vignette("drift")`](https://rootcoder007.github.io/rmorie-bricklayer/articles/drift.md)
for the distributional checks and
[`vignette("provenance")`](https://rootcoder007.github.io/rmorie-bricklayer/articles/provenance.md)
for signing, Merkle pinning and manifest chains.

## Part of the MORIE family

`rmoriebricklayer` is the reproducibility / provenance layer of the
[MORIE](https://github.com/rootcoder007/morie) ecosystem, alongside
[rmorie](https://github.com/rootcoder007/rmorie) and
[rmoriedata](https://github.com/rootcoder007/rmoriedata).

## Citation

If you use rmoriebricklayer in your research, please cite the software:

> Ruhela, V. S. (2026). *rmoriebricklayer: Reproducible Data Capsules
> with Provenance and Fallback.*
> <https://github.com/rootcoder007/rmorie-bricklayer>

BibTeX (or run `citation("rmoriebricklayer")` after installation for the
entry stamped with the exact installed version, sourced from
`inst/CITATION`):

``` bibtex
@Manual{ruhela_rmoriebricklayer_2026,
  title  = {rmoriebricklayer: Reproducible Data Capsules with Provenance and Fallback},
  author = {Ruhela, Vansh Singh},
  year   = {2026},
  url    = {https://github.com/rootcoder007/rmorie-bricklayer}
}
```

See
[`CITATION.cff`](https://github.com/rootcoder007/rmorie-bricklayer/blob/main/CITATION.cff)
for the machine-readable metadata GitHub’s “Cite this repository” button
uses.

## License

AGPL-3.0-or-later.

## Code of Conduct

Please note that this project is released with a [Contributor Code of
Conduct](https://github.com/rootcoder007/rmorie-bricklayer/blob/main/CODE_OF_CONDUCT.md).
By contributing, you agree to abide by its terms.
