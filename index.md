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

- **One call for a published table** —
  [`analyse_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/analyse_table.md)
  takes a table of counts by period and group and returns what changed
  with exact intervals, p-values adjusted over the whole scan, the
  envelope that rounding and suppression in the release imply
  ([`published_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/published_bounds.md)),
  trend, rates if there is an exposure, and a drift screen against the
  prior capsule;
  [`report_analysis()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/report_analysis.md)
  writes it as Markdown or one HTML file and
  [`use_capsule_template()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/use_capsule_template.md)
  starts a capsule that runs as written. Start with
  [`vignette("getting-started")`](https://rootcoder007.github.io/rmorie-bricklayer/articles/getting-started.md).
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
- **Categorical integrity** —
  [`guard_recode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/guard_recode.md),
  [`decode_codes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/decode_codes.md),
  [`guard_levels()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/guard_levels.md),
  [`audit_categories()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/audit_categories.md),
  [`verify_recode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_recode.md),
  [`verify_marginals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_marginals.md),
  [`odds_ratio_check()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/odds_ratio_check.md),
  [`relabel()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relabel.md),
  [`decode_labelled()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/decode_labelled.md),
  [`transfer_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/transfer_verify.md),
  [`relabel_forensics()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relabel_forensics.md)
  and a signed
  [`recode_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recode_manifest.md):
  recodes that refuse anything unmapped or positional, an SPSS/Stata/SAS
  import checked against the source code book and frequency table,
  reported odds ratios recomputed under every relabelling, and the
  mechanical step behind a permutation named, so a swapped label is
  fixed on the day, not blamed on the software.
- **Asking a model** —
  [`bricklayer_llm_login()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_login.md),
  [`bricklayer_llm_models()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_models.md)
  and
  [`bricklayer_llm_ask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
  sign in to the hosted MORIE tier, list the models your key can use and
  put a question to one; the `rmoriebricklayer` launcher offers the same
  as shell verbs.
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
- **Rates and shares** —
  [`rate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate.md)
  gives events per population at any denominator (`per = 1000`,
  `"100k"`, `"1m"`) with the exact Poisson interval;
  [`share()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/share.md)
  gives percentage of a total with Wilson’s interval. They are separate
  functions because a share of a total is not a rate per population, and
  labelling one as the other is the most common error in a published
  table.
  [`rate_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate_change.md)
  gives the change in a rate between periods, conditioning on the two
  counts and correcting for the exposure ratio rather than treating two
  rates as measured numbers.
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
- **Points, and the regions that contain them** —
  [`region_map_integrity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_integrity.md),
  [`region_map_compare()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_compare.md)
  and
  [`region_map_second_route()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_second_route.md)
  check a point-to-region assignment on its own terms, since an error in
  it reproduces perfectly in every table built on it;
  [`region_map_from_points()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_from_points.md)
  recomputes one by point in polygon when `sf` is available; and
  [`region_coverage()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_coverage.md)
  reports the population of the regions holding a unit while saying,
  each time it prints, why that share is not a rate denominator.
- **Stock and flow** —
  [`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
  [`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)
  and
  [`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md)
  read the same person-days two ways, per day and per person, after
  Lakner (1976). When stays lengthen the two move in opposite
  directions, so
  [`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md)
  reports both and the exact decomposition between them.

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

The worked example in `examples/otis-mrp/` goes further than checking
the package: it recomputes **147 published year-over-year tables across
29 datasets — 8,214 cells** — from the source data and compares every
one, alongside the descriptives, the matched sample and the causal
estimates. It also checks what a cell-by-cell comparison cannot: three
of those datasets reach the same population by different routes, so a
wrong grain rule would move both sides of a cell comparison together and
pass, while `a01` distinct individuals against `c01` and `c04` totals
fails. The datasets are not shipped — point `OTIS_DATASETS_DIR` at a
copy you have, or set `OTIS_YOY_DOWNLOAD=1` to fetch them from the
province.

The compiled kernels are published for `LinkingTo`, and a consumer
package is built **and run** against `inst/include/rmoriebricklayer.h`
as part of the test suite — a signature mismatch is a compile error,
while a misregistered name compiles cleanly and fails only when called.

**The XMSS signature scheme is byte-compatible with the RFC 8391
reference implementation.** The whole 2500-byte signature for
XMSS-SHA2_10_256 – index, randomiser, WOTS+ signature and authentication
path – matches it exactly, checked against embedded vectors in the test
suite so the check needs no network.

**The standardised schemes are byte-identical to OpenSSL.** ML-DSA (FIPS
204) at all three parameter sets and SLH-DSA (FIPS 205) at all twelve –
six over SHAKE, six over SHA-2 – are implemented here, with no system
dependency. Every one of the fifteen is checked against OpenSSL 3.5: in
deterministic mode the two implementations produce the SAME BYTES, over
several message and context lengths, and each verifies the other’s
signatures. OpenSSL’s keys and the digests of its signatures are
embedded in the test suite, so the check needs no network and no system
library.

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

The shortest path, on the OTIS table that ships with the package:

``` r

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

``` r

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

``` r

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

See
[`vignette("drift")`](https://rootcoder007.github.io/rmorie-bricklayer/articles/drift.md)
for the distributional checks and
[`vignette("provenance")`](https://rootcoder007.github.io/rmorie-bricklayer/articles/provenance.md)
for signing, Merkle pinning and manifest chains.

## Asking a model

The package can put a question to a language model, from R or from the
shell, through the hosted MORIE tier at `https://llm.rmorie.com`.
Nothing runs until you sign in; without a key every call returns empty.

``` r

library(rmoriebricklayer)

# Sign in once. The device flow prints a link and a code to confirm in a
# browser; the email flow mails the code; a key you already hold can be
# pasted. The key is saved in ~/.config/morie/credentials.json, shared with
# rmorie and the Python package morie.
bricklayer_llm_login()                                   # with a GitHub account (device flow)
bricklayer_llm_login(email = "you@example.org")           # no GitHub account: a code is emailed, then
bricklayer_llm_login(email = "you@example.org", code = "123456")
bricklayer_llm_login(token = "sk-...")                    # paste a key

bricklayer_llm_status()      # base URL, whether a key is stored, the default model
bricklayer_llm_models()      # the models your key can use; attr(, "default")
bricklayer_llm_ask("Summarise what a Benford screen can and cannot show.")
bricklayer_llm_ask("Same question, another model.", model = "gpt-oss-120b:cf")
bricklayer_llm_logout()      # forget the key
```

[`bricklayer_llm_models()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_models.md)
lists the hosted tier only; a local Ollama server is not consulted here.
`MORIE_HOSTED_KEY` in the environment overrides the stored key, and
`MORIE_HOSTED_BASE_URL` points the package at another gateway (set it to
`off` to disable the hosted tier).

The tier serves AI cloud models via ollama and Cloudflare (kimi-k2.6:cf,
kimi-k2.7-code:cf, deepseek-v4-pro:cf, deepseek-v4-flash:cf, glm-5.2:cf,
glm-5.3:cf, glm-5.3-flash:cf, gpt-oss-120b:cf, gpt-oss-20b:cf,
llama-4-scout:cf, qwen3.8-27b:cf, nemotron-3-120b:cf and
gemma-4-26b:cf).

The same verbs exist on the command line once the launcher is on your
`PATH`:

``` sh
Rscript -e 'rmoriebricklayer::install_cli()'   # links ~/.local/bin/rmoriebricklayer and ~/.local/bin/rmbl
rmoriebricklayer login                          # with a GitHub account
rmoriebricklayer login --email you@example.com  # no GitHub account: a code is emailed, type it at the prompt
rmoriebricklayer login --email you@example.com --code 123456   # the same, code passed (scripts)
rmoriebricklayer login --token                  # paste a key you already have
rmoriebricklayer login --no-browser             # server / SSH: prints a link + code for any device
rmoriebricklayer models                         # what you can ask, default marked
rmoriebricklayer ask --model NAME "your question"
rmoriebricklayer doctor                         # which routes answer from this machine
```

`rmbl` is the same command under a short name; every verb works under
either:

``` sh
rmbl login                                      # GitHub
rmbl login --email you@example.com              # no GitHub account: type the emailed code at the prompt
rmbl login --no-browser                         # server / SSH
rmbl models
rmbl ask "your question"
rmbl doctor
```

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
