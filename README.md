# rmoriebricklayer

<!-- badges: start -->
[![CRAN status](https://www.r-pkg.org/badges/version/rmoriebricklayer)](https://CRAN.R-project.org/package=rmoriebricklayer)
[![R-CMD-check](https://github.com/rootcoder007/rmorie-bricklayer/actions/workflows/r-pkg-check.yml/badge.svg)](https://github.com/rootcoder007/rmorie-bricklayer/actions/workflows/r-pkg-check.yml)
[![Codecov test coverage](https://codecov.io/gh/rootcoder007/rmorie-bricklayer/graph/badge.svg)](https://app.codecov.io/gh/rootcoder007/rmorie-bricklayer)
[![Project Status: Active](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![Lifecycle: maturing](https://img.shields.io/badge/lifecycle-maturing-blue.svg)](https://lifecycle.r-lib.org/articles/stages.html#maturing)
[![r-universe](https://rootcoder007.r-universe.dev/badges/rmoriebricklayer)](https://rootcoder007.r-universe.dev/rmoriebricklayer)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://spdx.org/licenses/AGPL-3.0-or-later.html)
<!-- badges: end -->

> Brick-proof, reproducible data capsules for R.

`rmoriebricklayer` resolves open-data sources, records and verifies
provenance, validates downloaded data against a pinned schema, and falls
back to schema-driven synthetic data when the real source is unreachable —
so any analysis result can be traced back to its exact inputs.

A checksum answers one question: are these the same bytes? The package
exists because that is rarely the question that matters. A re-released
extract can be statistically identical and differ byte-for-byte; a column
can keep its name, type and row count while having been silently rescaled;
and a digest anyone can recompute says nothing about who produced the data.

## What it does

- **CKAN resolution** — `resolve_via_ckan()` / `resolve_via_ckan_search()`
  locate resources through a portal's `package_show` / `package_search`
  endpoints.
- **Provenance** — `load_provenance()`, `make_manifest()`, `record()`,
  `write_manifest_json()`, and `write_summary_txt()` capture every run as a
  manifest plus a plain-language summary.
- **Integrity** — `sha256_file()` / `verify_sha256()` hash and verify
  downloads; `download_data()` / `friendly_download()` fetch with a Wayback
  Machine fallback.
- **Schema validation** — `infer_schema()` derives a pinnable schema from
  data you trust; `validate_schema()` checks names, types, ranges, value
  sets and missingness against it; `rule()` and the `rule_*()` library
  express the project-specific checks a generic schema cannot.
- **Drift detection** — `capsule_drift()` asks whether the *data* moved,
  not just the bytes, with Kolmogorov-Smirnov, two-sample homogeneity,
  population stability index, Jensen-Shannon divergence and a Benford
  first-digit screen.
- **Signed provenance** — `capsule_sign()` authenticates a manifest with a
  keyed digest or a post-quantum hash-based signature; `merkle_root()` pins
  a capsule chunk by chunk so a mismatch names which chunk moved; and
  `chain_append()` links manifests so the run *history* is tamper-evident,
  not only each run.
- **Description** — `profile_columns()`, `frequency_table()`,
  `correlation_table()`, `mahalanobis_outliers()`, `missingness_map()` and
  `mcar_test()` (Little's test, with the EM estimator it requires) describe
  a capsule before you trust it.
- **Capsules larger than memory** — exact block-wise moment accumulation,
  reservoir sampling, and HyperLogLog distinct counts, all in one pass.
- **Synthetic fallback** — `make_synthetic_column()` / `make_synthetic_csv()`
  generate schema-driven stand-ins when the real source is down, so a
  pipeline still runs end-to-end.
- **Change tables** — `yoy()` computes period-over-period change matched on
  the period's own value rather than on row order, so a missing year is a
  gap instead of a quietly multi-year comparison. A percent off a small
  base is withheld with its reason; a column already in percent is
  reported in percentage *points*; a ratio of counts carries the exact
  conditional-binomial interval. `yoy_write()` renders to HTML, PDF, CSV,
  TSV, JSON or Markdown, format taken from the file name, with nothing
  outside base R.
- **Banded categories** — `parse_bands()` reads the interval labels
  publishers actually use (`"2 to 5"`, `"50+"`, `"under 18"`) and returns
  bounds; `band_sensitivity()` measures how far a result moves as the open
  top band's assumed cap varies, which is the dependence every figure
  computed from banded data carries.
- **Concentration and tails** — `gini()`, `lorenz()`, `top_share()`, and
  `hill_tail_index()`, which maximises the exact discrete likelihood
  because the closed-form continuity correction is badly biased at the
  small thresholds administrative counts start from.
- **Short-series trend** — `trend_test()` (Mann-Kendall with Theil-Sen),
  `step_change()` (permutation scan over splits, not the best split's own
  test) and `count_trend()` (Poisson rate ratio per period). Meaningful at
  the five-to-ten annual points an open-data extract actually has.
- **Region-coded counts** — `expected_counts()` for indirect
  standardisation, `sir()` with the exact Poisson interval, `eb_rates()`
  for Clayton-Kaldor shrinkage, `funnel_limits()`, and `morans_i()`.

## Verification

Every hash, keyed hash, checksum, key derivation, base64 and JSON output
is compared against an **independent implementation** — `digest`,
`openssl`, `jsonlite` and base R's own inflater — over a length sweep
crossing each construction's block boundaries, so the digest this package
records for a set of bytes is the number anybody else would compute for
them. Published vectors are checked too: SHA-512 (FIPS 180-4),
HMAC-SHA-256 (RFC 4231), PBKDF2-HMAC-SHA256, BLAKE2b (RFC 7693) and
CRC-32 (ITU V.42). The statistics are anchored on base R
(`stats::poisson.test`, `stats::glm`, `stats::cor.test`, `stats::qpois`)
or on closed forms recomputed by hand.

The compiled kernels are published for `LinkingTo`, and a consumer
package is built **and run** against `inst/include/rmoriebricklayer.h` as
part of the test suite — a signature mismatch is a compile error, while a
misregistered name compiles cleanly and fails only when called.

**The XMSS signature scheme is byte-compatible with the RFC 8391
reference implementation.** The whole 2500-byte signature for
XMSS-SHA2_10_256 -- index, randomiser, WOTS+ signature and
authentication path -- matches it exactly, checked against embedded
vectors in the test suite so the check needs no network. The
standardised schemes (ML-DSA, SLH-DSA) are liboqs's implementation
rather than one of ours; what is tested here is the binding, including
that ML-DSA-65 produces the key and signature sizes FIPS 204
specifies.

It is also verified against its security properties: a valid signature
verifies, and every tampering of the message, signature, authentication
path, index or key fails.

## Installation

Released version from [CRAN](https://CRAN.R-project.org/package=rmoriebricklayer):

```r
install.packages("rmoriebricklayer")
```

Latest build from r-universe (tracks `main` ahead of CRAN):

```r
install.packages(
  "rmoriebricklayer",
  repos = c("https://rootcoder007.r-universe.dev",
            "https://cloud.r-project.org")
)
```

Development version from GitHub:

```r
# install.packages("remotes")
remotes::install_github("rootcoder007/rmorie-bricklayer")
```

## Quick example

```r
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

```r
# Did the distribution change, not just the bytes?
capsule_drift(reference_extract, fresh_fetch)

# Authenticate the manifest so a verifier knows who produced it.
key <- pqc_keygen()                              # post-quantum, hash-based
sig <- capsule_sign(core_sha256(readLines("manifest.json")), key)
capsule_verify(core_sha256(readLines("manifest.json")), sig,
               signing_public_key(key))
```

See `vignette("drift")` for the distributional checks and
`vignette("provenance")` for signing, Merkle pinning and manifest chains.

## Part of the MORIE family

`rmoriebricklayer` is the reproducibility / provenance layer of the
[MORIE](https://github.com/rootcoder007/morie) ecosystem, alongside
[rmorie](https://github.com/rootcoder007/rmorie) and
[rmoriedata](https://github.com/rootcoder007/rmoriedata).

## Citation

If you use rmoriebricklayer in your research, please cite the software:

> Ruhela, V. S. (2026). *rmoriebricklayer: Reproducible Data Capsules with Provenance and Fallback.* https://github.com/rootcoder007/rmorie-bricklayer

BibTeX (or run `citation("rmoriebricklayer")` after installation for the entry
stamped with the exact installed version, sourced from `inst/CITATION`):

```bibtex
@Manual{ruhela_rmoriebricklayer_2026,
  title  = {rmoriebricklayer: Reproducible Data Capsules with Provenance and Fallback},
  author = {Ruhela, Vansh Singh},
  year   = {2026},
  url    = {https://github.com/rootcoder007/rmorie-bricklayer}
}
```

See [`CITATION.cff`](https://github.com/rootcoder007/rmorie-bricklayer/blob/main/CITATION.cff) for the
machine-readable metadata GitHub's "Cite this repository" button uses.

## License

AGPL-3.0-or-later.

## Code of Conduct

Please note that this project is released with a
[Contributor Code of Conduct](https://github.com/rootcoder007/rmorie-bricklayer/blob/main/CODE_OF_CONDUCT.md). By contributing, you agree to
abide by its terms.
