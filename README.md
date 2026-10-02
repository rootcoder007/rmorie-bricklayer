# rmoriebricklayer

<!-- badges: start -->
[![CRAN status](https://www.r-pkg.org/badges/version/rmoriebricklayer)](https://CRAN.R-project.org/package=rmoriebricklayer)
[![CRAN downloads](https://cranlogs.r-pkg.org/badges/grand-total/rmoriebricklayer)](https://cran.r-project.org/package=rmoriebricklayer)
[![R-CMD-check](https://github.com/rootcoder007/rmorie-bricklayer/actions/workflows/r-pkg-check.yml/badge.svg)](https://github.com/rootcoder007/rmorie-bricklayer/actions/workflows/r-pkg-check.yml)
[![Codecov test coverage](https://codecov.io/gh/rootcoder007/rmorie-bricklayer/graph/badge.svg)](https://app.codecov.io/gh/rootcoder007/rmorie-bricklayer)
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

- **One call for a published table** — `analyse_table()` takes a table of
  counts by period and group and returns what changed with exact intervals,
  p-values adjusted over the whole scan, the envelope that rounding and
  suppression in the release imply (`published_bounds()`), trend, rates if
  there is an exposure, and a drift screen against the prior capsule;
  `report_analysis()` writes it as Markdown or one HTML file and
  `use_capsule_template()` starts a capsule that runs as written. Start
  with `vignette("getting-started")`.
- **CKAN resolution** — `resolve_via_ckan()` / `resolve_via_ckan_search()`
  locate resources through a portal's `package_show` / `package_search`
  endpoints.
- **Provenance** — `load_provenance()`, `make_manifest()`, `record()`,
  `write_manifest_json()`, and `write_summary_txt()` capture every run as a
  manifest plus a plain-language summary.
- **Integrity** — `sha256_file()` / `verify_sha256()` hash and verify
  downloads; `download_data()` / `friendly_download()` fetch with a Wayback
  Machine fallback.
- **Categorical integrity** — `guard_recode()`, `decode_codes()`,
  `guard_levels()`, `audit_categories()`, `verify_recode()`,
  `verify_marginals()`, `odds_ratio_check()`, `relabel()`,
  `decode_labelled()`, `transfer_verify()`, `relabel_forensics()` and a
  signed `recode_manifest()`: recodes that refuse anything unmapped or
  positional, an SPSS/Stata/SAS import checked against the source code
  book and frequency table, reported odds ratios recomputed under every
  relabelling, and the mechanical step behind a permutation named, so a
  swapped label is fixed on the day, not blamed on the software.
- **Asking a model** — `bricklayer_llm_login()`, `bricklayer_llm_models()`
  and `bricklayer_llm_ask()` sign in to the hosted MORIE tier, list the
  models your key can use and put a question to one; the
  `rmoriebricklayer` launcher offers the same as shell verbs.
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
- **Rates and shares** — `rate()` gives events per population at any
  denominator (`per = 1000`, `"100k"`, `"1m"`) with the exact Poisson
  interval; `share()` gives percentage of a total with Wilson's interval.
  They are separate functions because a share of a total is not a rate per
  population, and labelling one as the other is the most common error in a
  published table. `rate_change()` gives the change in a rate between
  periods, conditioning on the two counts and correcting for the exposure
  ratio rather than treating two rates as measured numbers.
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
- **Points, and the regions that contain them** — `region_map_integrity()`,
  `region_map_compare()` and `region_map_second_route()` check a
  point-to-region assignment on its own terms, since an error in it
  reproduces perfectly in every table built on it; `region_map_from_points()`
  recomputes one by point in polygon when `sf` is available; and
  `region_coverage()` reports the population of the regions holding a unit
  while saying, each time it prints, why that share is not a rate
  denominator.
- **Stock and flow** — `adp()`, `alos()` and `stock_flow()` read the same
  person-days two ways, per day and per person, after Lakner (1976). When
  stays lengthen the two move in opposite directions, so `stock_flow()`
  reports both and the exact decomposition between them.

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

The worked example in `examples/otis-mrp/` goes further than checking the
package: it recomputes **147 published year-over-year tables across 29
datasets — 8,214 cells** — from the source data and compares every one,
alongside the descriptives, the matched sample and the causal estimates.
It also checks what a cell-by-cell comparison cannot: three of those
datasets reach the same population by different routes, so a wrong
grain rule would move both sides of a cell comparison together and pass,
while `a01` distinct individuals against `c01` and `c04` totals fails.
The datasets are not shipped — point `OTIS_DATASETS_DIR` at a copy you
have, or set `OTIS_YOY_DOWNLOAD=1` to fetch them from the province.

The compiled kernels are published for `LinkingTo`, and a consumer
package is built **and run** against `inst/include/rmoriebricklayer.h` as
part of the test suite — a signature mismatch is a compile error, while a
misregistered name compiles cleanly and fails only when called.

**The XMSS signature scheme is byte-compatible with the RFC 8391
reference implementation.** The whole 2500-byte signature for
XMSS-SHA2_10_256 -- index, randomiser, WOTS+ signature and
authentication path -- matches it exactly, checked against embedded
vectors in the test suite so the check needs no network.

**The standardised schemes are byte-identical to OpenSSL.** ML-DSA
(FIPS 204) at all three parameter sets and SLH-DSA (FIPS 205) at all
twelve -- six over SHAKE, six over SHA-2 -- are implemented here, with
no system dependency. Every one of the fifteen is checked against
OpenSSL 3.5: in deterministic mode the two implementations produce the
SAME BYTES, over several message and context lengths, and each verifies
the other's signatures. OpenSSL's keys and the digests of its
signatures are embedded in the test suite, so the check needs no network
and no system library.

ML-KEM (FIPS 203) is here too, at all three levels, along with the
pre-hashed variants of both signature standards and ML-DSA's external-mu
interface. ML-KEM keys generated from the same seed agree with
OpenSSL's byte for byte, its ciphertexts decapsulate here to the secret
it reports, and a corrupted ciphertext produces the same rejection
secret in both -- which is the check that catches a wrong compression
width, since compressing and decompressing with the same wrong width
round-trips perfectly.

Signing is fast enough to be tested unconditionally: an SLH-DSA `s`
parameter set signs in about a second, down from seven, after the Keccak
round was made branch-free, the tweakable hash stopped heap-allocating
a few million times per signature, and the SHA-2 sets learned to resume
from a cached midstate.

That cross-check is the claim, not reference parity. This
implementation matched the pq-crystals and sphincsplus reference code
byte for byte while disagreeing with the standards in two places -- FIPS
204 and FIPS 205 both prepend a context domain separator that the
reference code omits, and FIPS 205 reads the FORS indices most
significant bit first where SPHINCS+ read them least significant bit
first. A signature scheme that verifies only its own output passes every
security-property test there is, so only an independent implementation
can find that class of bug.

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

The shortest path, on the OTIS table that ships with the package:

```r
library(rmoriebricklayer)
otis <- read.csv(system.file("extdata", "otis_a01_individuals.csv",
                             package = "rmoriebricklayer"))
a <- analyse_table(otis, value = "individuals", period = "year",
                   by = c("table", "group"), rounding = 5)
a                                   # what changed, how sure, what was withheld
report_analysis(a, "otis.html")     # one self-contained file
```

The full capsule, step by step. It runs as written, offline: the
provenance file pins the source, the schema and a recipe for a synthetic
stand-in, and the stand-in is what gets validated and recorded when the
portal is not reachable.

```r
library(rmoriebricklayer)

# 1. The pin: portal endpoint, resource pattern, expected schema, recipe.
prov_path <- file.path(tempdir(), "data_provenance.json")
writeLines('{
  "dataset": {
    "title": "Demo library statistics",
    "ckan_api_endpoint": "https://data.ontario.ca/api/3/action/package_show?id=ontario-public-library-statistics"
  },
  "resource": { "name_match_pattern": "2014" },
  "schema": {
    "expected_columns": ["year", "visits", "alert"],
    "structural_invariants": { "min_data_rows": 5 },
    "expected_value_sets": { "year": [2024, 2025] },
    "synthetic_recipe": {
      "n_rows": 25, "seed": 42,
      "columns": {
        "year":   { "type": "sample",    "values": [2024, 2025] },
        "visits": { "type": "poisson",   "lambda": 3, "min": 1 },
        "alert":  { "type": "bernoulli", "p": 0.2 },
        "id":     { "type": "id_pattern", "pattern": "p-{seq:05d}" }
      }
    }
  }
}', prov_path)
prov <- load_provenance(prov_path)

# 2. The data. With network: resolve the pinned endpoint to a current URL and
#    download (Wayback fallback). Without: a reproducible stand-in from the
#    recipe, marked synthetic all the way through.
#   url  <- resolve_via_ckan(prov)
#   path <- friendly_download(url, file.path(tempdir(), "data.csv"))
path <- file.path(tempdir(), "data.csv")
gen  <- make_synthetic_csv(prov$schema$synthetic_recipe, path)

# 3. Integrity and schema.
sha256_file(path)                               # pin this in the provenance
df     <- read.csv(path)
issues <- validate_schema(df, prov)             # names, types, value sets, rows

# 4. The manifest: named cross-checks, then the two capsule artifacts.
man <- make_manifest(list(project = "my-study", synthetic = TRUE))
man <- record(man, "rows", observed = nrow(df), expected = gen$rows,
              synthetic = TRUE)
write_manifest_json(man, file.path(tempdir(), "manifest.json"))
write_summary_txt(man, tempdir(),
                  paths = list(input = path, results = tempdir()),
                  what_was_done = "* validated the schema and recorded the row count")
```

Then ask whether the data itself moved, and sign the answer:

```r
# Did the distribution change, not just the bytes?
set.seed(1)
ref  <- data.frame(value = rnorm(300), size = runif(300, 1, 10),
                   grade = sample(c("a", "b", "c"), 300, TRUE))
same <- data.frame(value = rnorm(300), size = runif(300, 1, 10),
                   grade = sample(c("a", "b", "c"), 300, TRUE))
capsule_drift(ref, same)$any_drift        # a fresh draw: FALSE
moved <- same
moved$size <- moved$size * 3              # a silently rescaled column
moved$grade[1:100] <- "z"                 # and a new category
capsule_drift(ref, moved)                 # both are caught

# Authenticate the manifest so a verifier knows who produced it.
digest <- sha256_file(file.path(tempdir(), "manifest.json"))
key <- pqc_keygen()                       # post-quantum, hash-based
sig <- capsule_sign(digest, key)
capsule_verify(digest, sig, signing_public_key(key))
```

See `vignette("drift")` for the distributional checks and
`vignette("provenance")` for signing, Merkle pinning and manifest chains.

## Asking a model

The package can put a question to a language model, from R or from the
shell, through the hosted MORIE tier at `https://llm.rmorie.com`. Nothing
runs until you sign in; without a key every call returns empty.

```r
library(rmoriebricklayer)

# Sign in once. The device flow prints a link and a code to confirm in a
# browser; the email flow mails the code; a key you already hold can be
# pasted. The key is saved under ~/.config/rmorie and is shared with rmorie.
bricklayer_llm_login()                                   # device flow
bricklayer_llm_login(email = "you@example.org")           # mailed code, then
bricklayer_llm_login(email = "you@example.org", code = "123456")
bricklayer_llm_login(token = "sk-...")                    # paste a key

bricklayer_llm_status()      # base URL, whether a key is stored, the default model
bricklayer_llm_models()      # the models your key can use; attr(, "default")
bricklayer_llm_ask("Summarise what a Benford screen can and cannot show.")
bricklayer_llm_ask("Same question, another model.", model = "gpt-oss-120b:cf")
bricklayer_llm_logout()      # forget the key
```

`bricklayer_llm_models()` lists the hosted tier only; a local Ollama
server is not consulted here. `MORIE_HOSTED_KEY` in the environment
overrides the stored key, and `MORIE_HOSTED_BASE_URL` points the package at
another gateway (set it to `off` to disable the hosted tier).

The tier serves ollama.com cloud models and Cloudflare Workers AI models
(kimi-k2.6:cf, kimi-k2.7-code:cf, deepseek-v4-pro:cf, deepseek-v4-flash:cf, glm-5.2:cf, glm-5.3:cf, glm-5.3-flash:cf, gpt-oss-120b:cf, gpt-oss-20b:cf, llama-4-scout:cf, qwen3.8-27b:cf, nemotron-3-120b:cf and gemma-4-26b:cf); when a cloud model is rate limited or down the gateway answers from
Workers AI.

The same verbs exist on the command line once the launcher is on your
`PATH`:

```sh
Rscript -e 'rmoriebricklayer::install_cli()'   # links ~/.local/bin/rmoriebricklayer
rmoriebricklayer login                          # or: login --email ADDRESS, login --token
rmoriebricklayer models                         # what you can ask, default marked
rmoriebricklayer ask --model NAME "your question"
rmoriebricklayer doctor                         # which routes answer from this machine
```

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
