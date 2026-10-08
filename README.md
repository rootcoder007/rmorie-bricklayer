# rmoriebricklayer <img src="man/figures/logo.png" align="right" height="139" alt="rmoriebricklayer hex logo" />

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
  Topic guides: `vignette("post-quantum-signatures")`, `vignette("key-encapsulation")`,
  `vignette("side-channel-assurance")`, `vignette("hawkes-processes")`,
  `vignette("small-area-rates")`, `vignette("trends-and-change")`,
  `vignette("stock-and-flow")`, `vignette("air-pollution-and-health")`,
  `vignette("plotting-results")` and the rest,
  grouped by topic on the package website.
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
- **Asking a model** — `bricklayer_llm_ask()` puts a question to the first
  language-model route that answers: an OpenAI-compatible endpoint of your
  own, a local Ollama server, then the hosted MORIE tier as a last resort
  (`bricklayer_llm_login()` stores its key, `bricklayer_llm_models()` lists
  its models, `bricklayer_llm_status()` shows which route answers). The
  hosted addresses come from a signed services document
  (`bricklayer_services()`), so they can change without a release; the
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
- **Self-exciting event series (Hawkes)** — `core_hawkes_fit()` fits a
  univariate Hawkes process by maximum likelihood: a constant or seasonal
  (sinusoidal) baseline, and an exponential, Weibull, gamma or Lomax
  kernel, maximised in C++ by projected BFGS on the analytic gradient.
  `method` picks how the likelihood is evaluated: `"exact"` (Ozaki's O(n)
  recursion for the exponential kernel; the Weibull and gamma sums stop
  where the kernel underflows to 0), `"soe"` (Lomax and gamma as a sum of
  exponentials, Beylkin & Monzón 2010, relative error `eps`),
  `"truncate"`, `"em"` (Veen & Schoenberg 2008, finished by the BFGS on the
  exact likelihood, so it reaches the same maximum) or `"inar"` (Kirchner
  2017); `"auto"` chooses by kernel. The reported likelihood is exact
  whatever the route, so AIC compares across routes and kernels. The
  optimiser restarts its curvature whenever a parameter reaches or leaves
  its bound, as L-BFGS-B does: a Lomax fit to 19,651 events takes 12 s (it took 344 s).
  `converged` reports the optimiser's stop and `at_bound` the parameters
  left on the parameter box (a shape driven to its wall by day-dated times,
  or a Lomax at its exponential limit).
  `core_hawkes_nll()` gives the same likelihood on the same parameters,
  `core_hawkes_residuals()` the time-rescaling residuals and their
  Kolmogorov-Smirnov test. Events at one instant do not excite each other
  (the intensity sums over strictly earlier events); times recorded to a
  resolution, such as daily dates, are spread across their interval with
  `core_hawkes_jitter()` before the fit (Filimonov & Sornette 2015;
  `horizon =` keeps an event dated on the window's last day inside it), and
  the fit warns when it sees ties.
- **Every result draws itself** — `plot()` on anything the package returns:
  stock and flow, period-over-period change with its intervals, rates and
  shares, drift by column, Benford digits, power curves, outliers,
  correlations, permutation nulls, rounding envelopes, concentration-response
  curves, burdens, concentration curves, the footprint, plume fields and
  particle clouds, trends, and a whole-table analysis one panel at a time.
  Base graphics only (no new dependency), one shared look, and the same
  customisation on every method: `main`, `col` or `palette`, `grid`, `...`
  for the base call, `bricklayer_plot_options()` for the session and
  `bricklayer_palette()` for colour-blind-safe colours. `plume_field()`
  evaluates a plume on a grid for the image; `plot_lorenz()` and
  `plot_funnel()` cover the results that are plain data frames. Every
  method returns the numbers it drew. `vignette("plotting-results")`.
- **Air pollution, from source to burden** — where a plume goes:
  `pg_sigmas()` (Pasquill-Gifford coefficients with Briggs's fits, rural and
  urban), `briggs_plume_rise()` (buoyant and stable branches, transitional
  rise), `gaussian_plume()` and `gaussian_puff()` (ground reflection,
  mixing-lid images), `advection_diffusion_2d()` and `lagrangian_particles()`
  (grid and particle models; the walk takes any normal generator). What a
  concentration costs in lives: `crf_pm25()` and `crf_no2()` (the WHO 2021
  review's pooled estimates, Chen & Hoek 2020 and Huangfu & Atkinson 2020,
  and Burnett et al.'s 2014 integrated exposure-response curves per cause),
  `attributable_fraction()` (Levin), `mortality_displaced()` (BenMAP),
  `pollution_burden()` and `pollution_burden_by_area()` (the GBD chain, per
  area, worst first). Who bears it: `exposure_concentration_index()`
  (Wagstaff, Paci & van Doorslaer 1991). From your own data:
  `plr_crossfit()` and `exposure_response_plr()` (Chernozhukov et al.'s 2018
  partially linear model by cross-fitting, with a percentile bootstrap).
  All of it in one call with an assumption log: `verify_pollution()` and
  `pollution_report_text()`. Every coefficient cites its paper and is
  asserted in the tests. `vignette("air-pollution-and-health")`.
- **The footprint of the computation** — `compute_footprint()` reports
  the electricity an expression used and the CO2-equivalent it implies:
  measured from the CPU packages' RAPL energy counters where the operating
  system exposes them (as codecarbon does on Linux; wrap-around handled,
  subdomains not double-counted), otherwise modelled with the Green
  Algorithms formula (Lannelongue, Grealey & Inouye 2021). Utilisation is
  measured rather than assumed, per process or per whole machine (codecarbon's
  two tracking modes), with Green Algorithms' linear or codecarbon's load
  curves. `carbon_intensity()` and `carbon_intensity_table()` give the grid's
  gCO2e/kWh offline for any country at its latest published year (Ember via
  Our World in Data, 2024-25) and for sub-national zones (Electricity Maps
  2024), each row with its year and source; `detect_location()` finds where
  you are from the environment, time zone or locale, no network needed;
  `rapl_available()` says which method you will get; `footprint_equivalents()`
  turns grams into car-kilometres and tree-months. Every default that stood in
  for a measurement is listed in the result.
- **Post-quantum keys and signatures** — ML-KEM (`kem_keygen()`,
  `kem_encapsulate()`, `kem_decapsulate()`); ML-DSA and SLH-DSA keys from
  `fips_keygen()` and XMSS keys from `pqc_keygen()`, both signing through
  `capsule_sign()` (an XMSS index never signs twice: carry each
  signature's `key_state` forward); and HQC-KEM in both revisions:
  `hqc_keygen(version = "v5")`, the default (specification of
  2025-08-22, 32-byte shared secret), and `hqc_keygen(version = "round4")`
  (the fourth-round submission of 2023-04-30 — the HQC of liboqs up to
  0.12 and of PQClean — with a 64-byte shared secret). Keys carry their
  revision and `hqc_encapsulate()` / `hqc_decapsulate()` follow it;
  `hqc_compress_key()` stores a secret key as its seed alone (v5's
  32-byte `seed_KEM`; round 4's key-generation seed) and
  `hqc_decapsulate()` expands it. All of it is implemented here, with no
  system library; see
  [Verification](#verification).
- **Deterministic random bits** — `drbg_new()`, `drbg_generate()` and
  `drbg_reseed()`: the AES-256 CTR_DRBG of NIST SP 800-90A (no derivation
  function), with a table-free AES written to run in constant time, and AES-NI on x86-64. The same entropy
  gives the same bytes, which is what reproducible key generation and
  known-answer tests need; `random_bytes()` reads the operating system's
  generator for keys meant to stay secret.
- **Ontario SIU director's reports** — `bricklayer_fetch_siu()` fetches a
  report by its id, in English or French; `bricklayer_parse_siu()` reads
  it into the 16 fields of `bricklayer_siu_schema()` (the police service;
  the dates of the incident, the notification and the decision; the SIU
  team's size; the counts of subject officials, witness officials and
  civilian witnesses; the affected person's age and sex; the charges; the
  director; where the call was; the injuries; the legislation);
  `bricklayer_fetch_parse_siu()` does both.
  `bricklayer_siu_resolve_so()` counts the subject officials from the text
  ("SO", "subject officer" and "subject official" are one quantity).
  `police_service` is the service of the subject officials, read from the
  director's analysis — not the force that notified the SIU, which is
  often a custody, requesting or neighbouring service. Every layout is
  read: the 2005-2011 legacy pages, the 2012-2019 and 2020-on English
  pages, and the French pages (the SIU publishes each report in both
  languages). rmorie and morie run the same parser.
- **JSON without jsonlite** — `bricklayer_json_to_json()` and
  `bricklayer_json_from_json()` are jsonlite's `toJSON()` and
  `fromJSON()`, natively: every option, the same defaults and the same
  bytes out. `bricklayer_json_serialize()` round-trips an R object with its type
  and attributes (exactly, doubles included, with `digits = I(17)`), with
  base64 and base64url codecs beside it.
- **Curated tables** — `bricklayer_data_tables()` lists the tables served
  at data.rmorie.com (161 databases and 203 tables on 2026-10-05,
  materialised from Google BigQuery public datasets), and
  `bricklayer_data_load("db/table")` opens one with your MORIE key (issued
  on request at <https://www.rmorie.com/access/>, under the terms at
  <https://www.rmorie.com/data-license/>), cached locally. `bricklayer_fetch()` downloads any URL with an Internet Archive
  fallback (libcurl).

## Security posture

Everything cryptographic in this package is a hand-written implementation:
ML-KEM, ML-DSA, SLH-DSA, HQC, XMSS, the CTR_DRBG, SHA-2, SHA-3, BLAKE2b,
ECDSA and RSA verification, the ASN.1/DER parser and the X.509 / OCSP /
timestamp stack. Each property below is **measured in CI on every change**,
by a check you can run yourself; none is a claim about the design.

| Property | How it is checked | Where |
|---|---|---|
| Correct | Byte-identical to OpenSSL 3.5 (ML-KEM, ML-DSA, SLH-DSA) and to the NIST / reference known-answer vectors (HQC 300 KATs, CTR_DRBG CAVP, SHA-3, XMSS); SHA-2, HMAC, PBKDF2, BLAKE2b, CRC-32 against `digest`/`openssl` and the RFC vectors | `tests/testthat/test-fips-*.R`, `test-hqc*.R`, `test-xmss-kat.R`, `test-byte-parity.R` |
| Rejects what a verifier must reject | 1,247 Project Wycheproof vectors: ECDSA P-256/SHA-256 (484), P-384/SHA-384 (504), RSASSA-PKCS1-v1_5 2048/SHA-256 (259) -- malformed DER, non-canonical integers, r or s out of range, points off the curve, every padding and DigestInfo variant. Every valid vector verifies, every invalid one is refused, and the legacy "acceptable" encodings are refused too | `tests/testthat/test-wycheproof.R` |
| Constant time | ctgrind: every operation that touches a secret runs under valgrind memcheck with the secret marked undefined, so a branch or a memory address depending on it is an error. 22 cases -- ML-KEM 512/768/1024 (keygen, encaps, decaps and implicit rejection), ML-DSA 44/65/87 (keygen, sign), SLH-DSA (SHAKE and SHA-2 families), HQC 1/3/5 and round 4, XMSS, CTR_DRBG on the portable and the AES-NI path, HMAC, PBKDF2, keyed BLAKE2b, SHA-2, SHA-3, digest comparison -- all clean with GCC and with Clang. The only values the schemes branch on are the ones their specifications publish (a rejected sample, the challenge, the hints, R), each declassified at one named line | `inst/ctcheck/`, workflow `constant-time` |
| Secrets are wiped | After each of those operations the harness scans the dead stack below it for copies of the seed, the signing key, the password: none remain | same harness, `ZEROISATION` lines |
| Memory safe | The whole test suite under AddressSanitizer and UndefinedBehaviorSanitizer (R-devel built with both) | workflow `sanitizers` |
| Survives hostile arguments | Every one of the 113 registered entry points runs behind a generated try/catch barrier (a C++ exception is an R error, never `std::terminate`); argument types, lengths and sizes are checked before any allocation; quadratic loops and the RSA arithmetic are interruptible; the RSA exponent, SHAKE output, PBKDF2 iterations and SIU inputs are bounded. A C stack overflow is not an exception, so the SIU text passes over a whole document are loops, not regexes, and every line the extractors see is capped; a test runs ten hostile inputs through every one-string SIU entry point in a subprocess | `src/rmbl_barrier.cpp`, `inst/scripts/gen_barrier.R`, `tests/testthat/test-review2.R`, `tests/testthat/test-review3.R` |
| No request to a private address | One check in the transport: the authority parsed as a URL parser does, IPv4/IPv6 literals canonicalised (`127.1`, `0x7f000001`, `::ffff:7f00:1`), local names refused by suffix, every resolved address tested and the connection pinned to it (no DNS rebinding), redirects re-checked hop by hop, `https` never downgraded | `src/rmbl_fetch.cpp`, `tests/testthat/test-review2.R` |
| Robust against hostile input | libFuzzer with ASan + UBSan over the DER parser and RSA arithmetic, the decimal-to-double conversion (checked against the C library bit for bit on every input both accept), and the SIU report parsers; weekly long runs | `inst/fuzz/`, workflow `fuzz` |
| Standards vectors | The C2SP Wycheproof post-quantum sets and the NIST ACVP sets for ML-KEM, ML-DSA, SLH-DSA, SHA-3, SHAKE, HMAC and PBKDF2: 6,848 checks, 0 failures, each not-applicable vector named with its reason; the masked and the plain paths are compared on every ML-KEM decapsulation and ML-DSA signing vector | `tools/vectors/`, workflow `vectors` |
| Agrees with OpenSSL on any input | libFuzzer differential fuzzing against OpenSSL 3.5: ML-KEM, ML-DSA, SLH-DSA-SHA2-128f, the SHA-2, SHA-3 and SHAKE digests, BLAKE2b, HMAC and PBKDF2 must agree byte for byte | `inst/fuzz/fuzz_ossl.cpp`, workflow `fuzz` |
| Timing on hardware | dudect fixed-versus-random Welch t on x86-64 and arm64 Linux and on Apple silicon (with and without DIT): ML-KEM decapsulation plain and masked, valid against invalid with both classes varying, each phase alone, encapsulation, HQC decapsulation, the digest comparison, PBKDF2; an early-exit comparison is the control that must be flagged | `inst/dudect/`, workflow `dudect` |
| Power, in simulation | TVLA on the code compiled for a Cortex-M4 and run in an emulator, under the Hamming-weight and the Hamming-distance models: every masked kernel shows no first-order leakage under either, every unmasked control leaks | `inst/tvla/`, workflow `tvla` |
| Masked by default | First-order masking of ML-KEM decapsulation and ML-DSA signing, output identical to the unmasked computation. The share-combining gadgets run in assembly on Cortex-M, x86-64 and aarch64 (plain C elsewhere, with the same results) with a fixed register order, zeroed temporaries and a zero store between the two shares; code that handles one share at a time runs each share in its own pass with the registers zeroed in between. Shares are recombined for what the algorithm publishes: the shared secret, the signature and, during signing, the public high bits, the hint and the rejection decision (on rejected attempts too, as FIPS 204 reveals them) | `src/rmbl_masked.h` |
| DER means DER | The parser refuses BER: long-form lengths below 128, lengths with leading zeros, non-minimal tags, end-of-contents octets, trailing bytes; `ECDSA-Sig-Value` must be exactly two canonical INTEGERs and the PKCS#1 block exactly the RFC 8017 DigestInfo | `src/rmbl_asn1.cpp`, `R/x509.R`, `R/timestamp.R` |

Outside what these checks model: electromagnetic emanation, fault injection, glitches and
coupling a leakage model omits, and higher-order attacks on two-share masking. No third-party
security audit has been commissioned, and the power assessment is a simulation, not a
capture from a board. `SECURITY.md`
has the threat model, the reporting address and the list of what each check would and would
not catch. The checks are reproducible on any Linux machine
with valgrind and clang: `bash inst/ctcheck/build.sh && bash inst/ctcheck/run.sh`
and `bash inst/fuzz/build.sh && bash inst/fuzz/run.sh`.

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

That cross-check is the claim, not reference parity. This
implementation matched the pq-crystals and sphincsplus reference code
byte for byte while disagreeing with the standards in two places -- FIPS
204 and FIPS 205 both prepend a context domain separator that the
reference code omits, and FIPS 205 reads the FORS indices most
significant bit first where SPHINCS+ read them least significant bit
first. A signature scheme that verifies only its own output passes every
security-property test there is, so only an independent implementation
can find that class of bug.

ML-KEM (FIPS 203) is here too, at all three levels, along with the
pre-hashed variants of both signature standards and ML-DSA's external-mu
interface. ML-KEM keys generated from the same seed agree with
OpenSSL's byte for byte, its ciphertexts decapsulate here to the secret
it reports, and a corrupted ciphertext produces the same rejection
secret in both -- which is the check that catches a wrong compression
width, since compressing and decompressing with the same wrong width
round-trips perfectly.

HQC (Hamming Quasi-Cyclic), the code-based KEM NIST selected in March
2025 to stand beside ML-KEM, is here as well at HQC-1, HQC-3 and HQC-5
(`hqc_keygen()`, `hqc_encapsulate()`, `hqc_decapsulate()`), in two
revisions. The default, v5, reproduces all 300 of the authors' official
known-answer vectors (specification of 2025-08-22, reference
implementation v5.0.0), runs in constant time with respect to secrets
(checked with valgrind: no secret reaches a branch, a memory index or a
variable shift), gives the same bytes on big-endian machines (the
reference code does not), and uses the carry-less multiply instruction on
x86-64 and ARMv8 when the processor has it. `version = "round4"` is the
fourth-round submission of 2023-04-30 — the revision liboqs (up to 0.12)
and PQClean ship — with its 64-byte shared secret; it shares v5's codes
and parameters and reproduces all 300 of that revision's official
known-answer vectors on both multipliers. The two are not
interchangeable: use round 4 to exchange keys with software built on it,
v5 otherwise. A secret key can be kept as its seed alone:
`hqc_compress_key()` writes v5's compressed format, `dk = seed_KEM` (32
bytes, defined by the v5 specification), or for round 4 the 96 to 112
bytes its key generation draws (a convention of this package: round 4
defines no compressed format), and `hqc_decapsulate()` re-derives the key
pair and refuses a seed that does not give the key's own public half. NIST
has named the HQC standard FIPS 207 but has not published it or a draft
of it yet (checked 2026-10-05); v5 already carries the changes NIST
listed for it, including the seed-only key, and the published standard may
still differ in detail.

The random bit generator reproduces all 720 AES-256 no-derivation-function
vectors of NIST's DRBG validation suite (no reseed, reseed, and
prediction resistance) on both AES paths, and seeded with the bytes 0..47
it is the `randombytes()` of NIST's `rng.c`, the generator the
post-quantum known-answer files were written with.

The JSON codec is checked against jsonlite itself, output byte for byte
and parsed values exactly. The Hawkes likelihood, gradient and fit are
checked on the same inputs as morie's Python tests, so every Hawkes test
is also a cross-language parity check; `core_uniforms()` is the splitmix64
stream both draw from. The SIU parser's police service agrees with the
panel-reviewed English corpus on 2,147 of 2,163 French reports and 111 of
118 English ones.

Signing is fast enough to be tested unconditionally: an SLH-DSA `s`
parameter set signs in about a second, down from seven, after the Keccak
round was made branch-free, the tweakable hash stopped heap-allocating
a few million times per signature, and the SHA-2 sets learned to resume
from a cached midstate.

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
key <- sig$key_state                     # the next signature must use this
```

See `vignette("drift")` for the distributional checks and
`vignette("provenance")` for signing, Merkle pinning and manifest chains.

## Asking a model

The package can put a question to a language model, from R or from the
shell. Three routes are tried, in this order, and the first that answers
is used:

1. **An endpoint of your own.** Set `MORIE_LLM_BASE_URL` to any
   OpenAI-compatible server (with `MORIE_LLM_API_KEY` and `MORIE_LLM_MODEL`
   when it needs them).
2. **A local Ollama server.** Found at `OLLAMA_HOST` (or `OLLAMA_BASE_URL`),
   default `http://localhost:11434`; the model is `OLLAMA_MODEL` or the first
   one the server lists. `OLLAMA_HOST=off` skips it.
3. **The hosted MORIE tier**, a last resort for people who can run neither.
   Its address and model list come from the signed services document at
   `https://rmorie.com/.well-known/morie-services.json` (ML-DSA-44, the
   public key pinned in the package: `bricklayer_services()`), so the
   endpoint can move or be paused without a package release. Keys are
   personal, rate limited and issued on request at
   <https://www.rmorie.com/access/>; a key is stored once, in
   `~/.config/morie/credentials.json`, and shared with rmorie, rmoriedata and
   the Python package morie.

```r
library(rmoriebricklayer)

bricklayer_llm_status()      # which route would answer from this machine, and why
bricklayer_llm_ask("Summarise what a Benford screen can and cannot show.")
bricklayer_llm_ask("The same question, on the local model.", route = "ollama")

# The hosted tier: store the key you were issued, or sign in
bricklayer_llm_login(token = "sk-...")                    # the key from rmorie.com/access
bricklayer_llm_login(email = "you@example.org")           # or: a code is emailed, then
bricklayer_llm_login(email = "you@example.org", code = "123456")
bricklayer_llm_login()                                   # or: GitHub device flow
bricklayer_llm_models()      # the hosted models your key can use; attr(, "default")
bricklayer_llm_ask("Summarise what a Benford screen can and cannot show.",
                  model = "gpt-oss-120b:cf", route = "hosted")
bricklayer_llm_logout()      # forget the key

bricklayer_services()        # the signed document: endpoints, modes, models, notice
```

`MORIE_HOSTED_KEY` in the environment overrides the stored key, and
`MORIE_HOSTED_BASE_URL` points the package at another gateway (set it to
`off` to disable the hosted tier). The hosted tier serves ollama.com cloud
models (minimax-m3:cloud, the default; minimax-m2.7:cloud, glm-5.2:cloud,
deepseek-v4-pro:cloud, gemma4:31b-cloud, gpt-oss:20b-cloud and
gpt-oss:120b-cloud) and additional AI models; `bricklayer_llm_models()`
reports what your key can use now.

The same verbs exist on the command line once the launcher is on your
`PATH`:

```sh
Rscript -e 'rmoriebricklayer::install_cli()'   # links ~/.local/bin/rmoriebricklayer and ~/.local/bin/rmbl
rmoriebricklayer doctor                         # which routes answer from this machine
rmoriebricklayer ask "your question"            # own endpoint, local Ollama, then the hosted tier
rmoriebricklayer ask --model NAME "your question"
rmoriebricklayer login --token                  # paste the key you were issued (or pipe it in)
rmoriebricklayer login --email you@example.com  # or: a code is emailed, type it at the prompt
rmoriebricklayer login --email you@example.com --code 123456   # the same, code passed (scripts)
rmoriebricklayer login                          # or: GitHub device flow
rmoriebricklayer login --no-browser             # server / SSH: prints a link + code for any device
rmoriebricklayer models                         # hosted models your key can use, default marked
rmoriebricklayer logout                         # forget the key
rmoriebricklayer data list                      # the curated tables at data.rmorie.com
rmoriebricklayer data pull db/table --out t.csv # download one (your MORIE key)
rmoriebricklayer bundle "your request"          # agent_bundle() from the shell
rmoriebricklayer functions [PATTERN]            # exported functions and their titles
rmoriebricklayer describe NAME                  # one function's help page
rmoriebricklayer examples NAME                  # its examples
rmoriebricklayer version
```

`rmbl` is the same command under a short name; every verb works under either:

```sh
rmbl doctor
rmbl ask "your question"
rmbl login --token
rmbl models
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
