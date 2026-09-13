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
- **Change tables** —
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
  computes period-over-period change matched on the period’s own value
  rather than on row order, so a missing year is a gap instead of a
  quietly multi-year comparison. A percent off a small base is withheld
  with its reason; a column already in percent is reported in percentage
  *points*; a ratio of counts carries the exact conditional-binomial
  interval.
  [`yoy_write()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_write.md)
  renders to HTML, PDF, CSV, TSV, JSON or Markdown, format taken from
  the file name, with nothing outside base R.
- **Banded categories** —
  [`parse_bands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/parse_bands.md)
  reads the interval labels publishers actually use (`"2 to 5"`,
  `"50+"`, `"under 18"`) and returns bounds;
  [`band_sensitivity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md)
  measures how far a result moves as the open top band’s assumed cap
  varies, which is the dependence every figure computed from banded data
  carries.
- **Concentration and tails** —
  [`gini()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md),
  [`lorenz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md),
  [`top_share()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md),
  and
  [`hill_tail_index()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hill_tail_index.md),
  which maximises the exact discrete likelihood because the closed-form
  continuity correction is badly biased at the small thresholds
  administrative counts start from.
- **Short-series trend** —
  [`trend_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trend_test.md)
  (Mann-Kendall with Theil-Sen),
  [`step_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/step_change.md)
  (permutation scan over splits, not the best split’s own test) and
  [`count_trend()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/count_trend.md)
  (Poisson rate ratio per period). Meaningful at the five-to-ten annual
  points an open-data extract actually has.
- **Region-coded counts** —
  [`expected_counts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expected_counts.md)
  for indirect standardisation,
  [`sir()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sir.md)
  with the exact Poisson interval,
  [`eb_rates()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/eb_rates.md)
  for Clayton-Kaldor shrinkage,
  [`funnel_limits()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/funnel_limits.md),
  and
  [`morans_i()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/morans_i.md).

## Verification

Every hash, keyed hash, checksum, key derivation, base64 and JSON output
is compared against an **independent implementation** — `digest`,
`openssl`, `jsonlite` and base R’s own inflater — over a length sweep
crossing each construction’s block boundaries, so the digest this
package records for a set of bytes is the number anybody else would
compute for them. Published vectors are checked too: SHA-512 (FIPS
180-4), HMAC-SHA-256 (RFC 4231), PBKDF2-HMAC-SHA256, BLAKE2b (RFC 7693)
and CRC-32 (ITU V.42). The statistics are anchored on base R
([`stats::poisson.test`](https://rdrr.io/r/stats/poisson.test.html),
[`stats::glm`](https://rdrr.io/r/stats/glm.html),
[`stats::cor.test`](https://rdrr.io/r/stats/cor.test.html),
[`stats::qpois`](https://rdrr.io/r/stats/Poisson.html)) or on closed
forms recomputed by hand.

The compiled kernels are published for `LinkingTo`, and a consumer
package is built **and run** against `inst/include/rmoriebricklayer.h`
as part of the test suite — a signature mismatch is a compile error,
while a misregistered name compiles cleanly and fails only when called.

**The XMSS signature scheme is byte-compatible with the RFC 8391
reference implementation.** The whole 2500-byte signature for
XMSS-SHA2_10_256 – index, randomiser, WOTS+ signature and authentication
path – matches it exactly, checked against embedded vectors in the test
suite so the check needs no network. The **The standardised schemes are
byte-identical to OpenSSL.** ML-DSA (FIPS 204) at all three parameter
sets and SLH-DSA (FIPS 205) at all twelve – six over SHAKE, six over
SHA-2 – are implemented here, with no system dependency. Every one of
the fifteen is checked against OpenSSL 3.5: in deterministic mode the
two implementations produce the SAME BYTES, over several message and
context lengths, and each verifies the other’s signatures. OpenSSL’s
keys and the digests of its signatures are embedded in the test suite,
so the check needs no network and no system library.

ML-KEM (FIPS 203) is here too, at all three levels, along with the
pre-hashed variants of both signature standards and ML-DSA’s external-mu
interface. ML-KEM keys generated from the same seed agree with OpenSSL’s
byte for byte, its ciphertexts decapsulate here to the secret it
reports, and a corrupted ciphertext produces the same rejection secret
in both – which is the check that catches a wrong compression width,
since compressing and decompressing with the same wrong width
round-trips perfectly.

Signing is fast enough to be tested unconditionally: an SLH-DSA `s`
parameter set signs in about a second, down from seven, after the Keccak
round was made branch-free, the tweakable hash stopped heap-allocating a
few million times per signature, and the SHA-2 sets learned to resume
from a cached midstate.

That cross-check is the claim, not reference parity. This implementation
matched the pq-crystals and sphincsplus reference code byte for byte
while disagreeing with the standards in two places – FIPS 204 and FIPS
205 both prepend a context domain separator that the reference code
omits, and FIPS 205 reads the FORS indices most significant bit first
where SPHINCS+ read them least significant bit first. A signature scheme
that verifies only its own output passes every security-property test
there is, so only an independent implementation can find that class of
bug.

It is also verified against its security properties: a valid signature
verifies, and every tampering of the message, signature, authentication
path, index or key fails.

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
