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

> Analyze a published table, and be able to show later exactly which data the result came from.

## What it is

`rmoriebricklayer` is for individuals who work from a variety of published and unpublished tables: a
ministry's open-data portal, Statistics Canada, a police oversight agency, or your own data. It
does three things with such a table.

1. **It analyzes the table.** `anltab()` takes counts by period and group and reports what changed
   between periods, with exact intervals, trends and rates, and says how far the publisher's
   rounding and suppressed cells could move each figure.
2. **It pins the data the result came from.** A *capsule* records where the table came from, the
   SHA-256 digest of the exact file, the columns and values it should have, and the address of an
   archived copy. Rerun later, `rmbl verify` says whether the source still matches, and
   `rmbl drift` says, column by column, what moved if it does not.
3. **It signs the record.** A capsule can be signed (with a shared key, or with the post-quantum
   signature standards), so a reader can check who produced a result and that nothing changed
   afterwards.

The rest of the package (the statistics for administrative tables, the plots, the dashboard, the
cryptography written from the standards) serves one of these three.

## Why it exists

I analyze Canadian justice and health statistics from published tables. Three things kept
going wrong, and a checksum alone catches none of them.

- **Sources go down or move.** The federal open-data portal, `open.canada.ca`, was unreachable in
  October 2026 while analyses depended on it. A capsule keeps the address of an archived copy of
  every source in the Internet Archive, so the analysis still runs, and it says that it used the
  archived copy.
- **The same table comes back different.** A re-released extract can hold the same numbers in a
  different byte layout, or keep a column's name and type while the column has been rescaled. The
  drift checks compare distributions, not bytes.
- **Labels end up on the wrong groups.** In 2020 the Ontario Human Rights Commission reported
  Black people in Toronto as 30 to 58 times as likely as White people to face police use of
  force; its 2023 correction gives 4 to 5 times, because four race codes had been rotated between
  two statistical programs. The package relabels only by a named map, never by position, and can
  say which rotation reproduces a set of published ratios (`vignette("categorical-integrity")`).

## How I use it

A table of people in Ontario's adult correctional institutions (OTIS, shipped with the package),
analyzed, plotted and written up:

```r
library(rmoriebricklayer)
f <- system.file("extdata", "otis_a01_individuals.csv", package = "rmoriebricklayer")
otis <- read.csv(f)
a <- anltab(otis, value = "individuals", prd = "year", by = c("table", "group"), rnd = 5)
a                                              # what changed, how sure, what was withheld
plot(a)
rptanl(a, file.path(tempdir(), "otis.html"))   # one self-contained page
```

Next year, the question is whether the table behind those numbers is still the same:

```r
pin <- sha256file(f)            # recorded with the result
identical(sha256file(f), pin)   # TRUE: the same bytes, so the same table

# a re-release that silently reports the counts in a different unit (tens)
moved <- otis
moved$individuals <- moved$individuals * 10
cpsdrft(otis, moved)$anydrft    # TRUE: the column's distribution moved
cpsdrft(otis, otis)$anydrft     # FALSE: an unchanged table raises no alarm
```

The digest catches any change to the file, however small. The distribution checks say whether
the numbers moved as a whole; on a table of 15 rows they will not notice a change to two or three
cells, which is why the capsule keeps both.

A capsule does this for every source of an analysis at once; `usecpstmpl()` starts one and
`vignette("capsules")` walks through it.

## What it does

- **One call for a published table** — `anltab()` takes a table of
  counts by period and group and returns what changed with exact intervals,
  p-values adjusted over the whole scan, the envelope that rounding and
  suppression in the release imply (`pubbnd()`), trend, rates if
  there is an exposure, and a drift screen against the prior capsule;
  `rptanl()` writes it as Markdown or one HTML file and
  `usecpstmpl()` starts a capsule that runs as written. Start
  with `vignette("getting-started")`.
  Topic guides: `vignette("post-quantum-signatures")`, `vignette("key-encapsulation")`,
  `vignette("side-channel-assurance")`, `vignette("hawkes-processes")`,
  `vignette("small-area-rates")`, `vignette("trends-and-change")`,
  `vignette("stock-and-flow")`, `vignette("air-pollution-and-health")`,
  `vignette("plotting-results")` and the rest,
  grouped by topic on the package website.
- **A dashboard on your own machine** — `rmblapp()` (or `rmbl app [PATH]`) opens forms over the
  analysis families: load a CSV file, a capsule or a data.rmorie.com table, run an analysis, see
  the package's plot and the exact R call it ran, and gather the results into one HTML page,
  Markdown or a GitHub comment. Needs shiny; `vignette("dashboard")`.
- **Distributions and plots** — `dstfit()` fits and ranks candidate distributions by maximum
  likelihood (continuous, proportions and counts with zero inflation), with bootstrap intervals,
  a Hill tail index and density, QQ, PP and tail plots; `mksyncol(list(type = "fitted"))` draws
  from a fit. `plotrdg()`, `plotecdf()`, `plotvln()`, `plothex()`, `plotgain()`, `plotcal()`,
  `plothrz()`, `plotsm()` and `plotbump()` draw distributions and many series in the house style;
  `plothwk()` and `chwksim()` show and simulate a fitted Hawkes process.
- **Proof ledgers** — `ldgrread()` reads a ledger of formal proofs (Lean theorems, their status
  and the package functions they cover) against `schemapath("ledger")`; `ldgrchk()` checks each
  theorem is proved, each covered function exists and each numeric check holds, in a sandbox.
  `rmbl verify` adds those rows to a capsule that holds a ledger.
- **CKAN resolution** — `rslvckan()` / `rslvckns()`
  locate resources through a portal's `package_show` / `package_search`
  endpoints.
- **Reproducibility bundles** — `mkbndl()` packs an analysis into one
  zip a reviewer with only R unzips and double-clicks (macOS, Windows,
  Linux); it finds, downloads or carries the data, checks it against the
  pinned SHA-256 and reports expected against observed for every number.
  `mkbndlproj()` starts a project of your own; see
  [Reproducibility bundles](#reproducibility-bundles).
- **Provenance** — `loadprov()`, `mkmnf()`, `recrd()`,
  `wrmnfjs()`, and `wrsmrytxt()` capture every run as a
  manifest plus a plain-language summary.
- **Integrity** — `sha256file()` / `vrfsha256()` hash and verify
  downloads; `dldata()` / `fdl()` fetch with a Wayback
  Machine fallback.
- **Categorical integrity** — `grdrcd()`, `deccodes()`,
  `grdlvls()`, `audcats()`, `vrfrcd()`,
  `vrfmrg()`, `orchk()`, `relbl()`,
  `declbld()`, `xfrvrf()`, `rlblfrns()` and a
  signed `rcdmnf()`: recodes that refuse anything unmapped or
  positional, an SPSS/Stata/SAS import checked against the source code
  book and frequency table, reported odds ratios recomputed under every
  relabelling, and the mechanical step behind a permutation named, so a
  swapped label is fixed on the day, not blamed on the software.
- **Asking a model** — `llmask()` puts a question to a language
  model you bring: a key for any major provider (OpenAI, Anthropic, Gemini,
  OpenRouter, Groq, Mistral, DeepSeek, xAI, Hugging Face, OpenCode and more:
  `llmprvd()`), an Ollama server, or an OpenAI-compatible
  server of your own. The model is given every function of the installed
  MORIE packages and tools to read their help, as much as it can take in;
  `llmstat()` shows which route answers, and the
  `rmoriebricklayer` launcher offers the same as shell verbs.
- **Schema validation** — `infsch()` derives a pinnable schema from
  data you trust; `valsch()` checks names, types, ranges, value
  sets and missingness against it; `rul()` and the `rule_*()` library
  express the project-specific checks a generic schema cannot.
- **Drift detection** — `cpsdrft()` asks whether the *data* moved,
  not just the bytes, with Kolmogorov-Smirnov, two-sample homogeneity,
  population stability index, Jensen-Shannon divergence and a Benford
  first-digit screen. `plot()` draws the PSI per column against its bands
  and each column's distributions; `drfthtml()` writes the report as one
  interactive HTML file (`rmbl drift PATH --html FILE`), and `drftapp()`
  opens it as a Shiny app.
- **Signed provenance** — `cpssign()` authenticates a manifest with a
  keyed digest or a post-quantum hash-based signature; `mrkroot()` pins
  a capsule chunk by chunk so a mismatch names which chunk moved; and
  `chnapp()` links manifests so the run *history* is tamper-evident,
  not only each run.
- **Description** — `profcols()`, `freqtbl()`,
  `cortbl()`, `mahaoutl()`, `missgrid()` and
  `mcartst()` (Little's test, with the EM estimator it requires) describe
  a capsule before you trust it.
- **Capsules larger than memory** — exact block-wise moment accumulation,
  reservoir sampling, and HyperLogLog distinct counts, all in one pass.
- **Synthetic fallback** — `mksyncol()` / `mksyncsv()`
  generate schema-driven stand-ins when the real source is down, so a
  pipeline still runs end-to-end.
- **Rates and shares** — `rtcalc()` gives events per population at any
  denominator (`per = 1000`, `"100k"`, `"1m"`) with the exact Poisson
  interval; `shrs()` gives percentage of a total with Wilson's interval.
  They are separate functions because a share of a total is not a rate per
  population, and labelling one as the other is the most common error in a
  published table. `ratechg()` gives the change in a rate between
  periods, conditioning on the two counts and correcting for the exposure
  ratio rather than treating two rates as measured numbers.
- **Change tables** — `yoy()` computes period-over-period change matched on
  the period's own value rather than on row order, so a missing year is a
  gap instead of a quietly multi-year comparison. A percent off a small
  base is withheld with its reason; a column already in percent is
  reported in percentage *points*; a ratio of counts carries the exact
  conditional-binomial interval. `yoywr()` renders to HTML, PDF, CSV,
  TSV, JSON or Markdown, format taken from the file name, with nothing
  outside base R.
- **Banded categories** — `prsbands()` reads the interval labels
  publishers actually use (`"2 to 5"`, `"50+"`, `"under 18"`) and returns
  bounds; `bandsens()` measures how far a result moves as the open
  top band's assumed cap varies, which is the dependence every figure
  computed from banded data carries.
- **Concentration and tails** — `ginicoef()`, `lorenzc()`, `topshr()`, and
  `hilltlidx()`, which maximises the exact discrete likelihood
  because the closed-form continuity correction is badly biased at the
  small thresholds administrative counts start from.
- **Short-series trend** — `trndtst()` (Mann-Kendall with Theil-Sen),
  `stepchg()` (permutation scan over splits, not the best split's own
  test) and `cnttrnd()` (Poisson rate ratio per period). Meaningful at
  the five-to-ten annual points an open-data extract actually has.
- **Region-coded counts** — `expcnts()` for indirect
  standardisation, `stdinc()` with the exact Poisson interval, `ebrates()`
  for Clayton-Kaldor shrinkage, `fnllim()`, and `morani()`.
- **Points, and the regions that contain them** — `rgnmapintg()`,
  `rgnmapcmp()` and `rgnmapalt()` check a
  point-to-region assignment on its own terms, since an error in it
  reproduces perfectly in every table built on it; `rgnmappts()`
  recomputes one by point in polygon when `sf` is available; and
  `rgncov()` reports the population of the regions holding a unit
  while saying, each time it prints, why that share is not a rate
  denominator.
- **Stock and flow** — `adp()`, `alos()` and `stkflow()` read the same
  person-days two ways, per day and per person, after Lakner (1976). When
  stays lengthen the two move in opposite directions, so `stkflow()`
  reports both and the exact decomposition between them.
- **Self-exciting event series (Hawkes)** — `chwkfit()` fits a
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
  its bound, as L-BFGS-B does: a Lomax fit to 19,651 events takes 12 s.
  `converged` reports the optimiser's stop and `at_bound` the parameters
  left on the parameter box (a shape driven to its wall by day-dated times,
  or a Lomax at its exponential limit).
  `chwknll()` gives the same likelihood on the same parameters,
  `chwkres()` the time-rescaling residuals and their
  Kolmogorov-Smirnov test. Events at one instant do not excite each other
  (the intensity sums over strictly earlier events); times recorded to a
  resolution, such as daily dates, are spread across their interval with
  `chwkjit()` before the fit (Filimonov & Sornette 2015;
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
  for the base call, `plotopt()` for the session and
  `blpal()` for colour-blind-safe colours. `plmfld()`
  evaluates a plume on a grid for the image; `plotlrnz()` and
  `plotfnl()` cover the results that are plain data frames. Every
  method returns the numbers it drew. `vignette("plotting-results")`.
- **Archiving in bulk** — `wbsave()` (and `rmbl wayback FILE`) saves many
  URLs in the Wayback Machine with archive.org's Save Page Now 2 API and your
  S3-like keys: captures in flight at once but started no faster than
  archive.org allows an account (`per_minute`, and a cap per run), every
  slow-down reply and `Retry-After` waited out, recent captures kept, results
  written as they land so a stopped run resumes (captures already started are
  polled, not sent again), `wbrtry()` for the failures, and a live
  animated progress bar (drawn in C, shared with `bldl()`).
- **Your own archive copy** — `arccap()` saves files from your own
  connection (for servers that refuse the Wayback Machine) as WARC files,
  and with `upload = "rmorie"` keeps them at archive.rmorie.com with their
  SHA-256 (`upload = "wayback"` asks the Wayback Machine too). `arcfind()`
  lists the captures of an address and `arcget()` fetches the exact bytes;
  `fetchvrf()` falls back to the archive and to your WARC files on its own,
  and `wbsave(fallback = "rmorie")` saves what the Wayback Machine refused.
  From a terminal: `rmbl archive save | find | get`. In CI, `cpschk(archive = TRUE)`
  (the rmbl action's `archive: true`) takes the archived copy when a source and
  its Wayback snapshot are down. Reading a public copy needs no key; saving needs
  one, except in a GitHub Actions job allowed `id-token: write`, where the
  package uses the job's short-lived OIDC token and the repository is the saver,
  so no secret is stored.
- **Courts and police-reported crime** — `caseflow()` (clearance rate with
  exact intervals, rolling clearance, net flow and months to clear the
  pending inventory), `lifetbl()` (actuarial life table with Greenwood
  intervals from banded times such as "disposed within 10 months"),
  `dispmix()` (outcome shares with Goodman simultaneous intervals,
  homogeneity and Cochran-Armitage trend tests), `clrdcmp()`
  (Kitagawa's exact split of a change in a clearance rate into rate and
  case-mix effects, a Mantel-Haenszel rate ratio within parts, and a
  Simpson's-paradox verdict), `crmdens()` (kernel density of incident
  locations in incidents per square kilometre, with highest-density regions)
  and `knoxtst()` (near-repeat space-time clustering, exact expectations,
  permutation p-values). Each has a plot. Real Ontario Court of Justice and
  Toronto Police Service excerpts ship in `inst/extdata` (`?justice-data`);
  `vignette("courts-and-crime")`.
- **Search and rescue** — `ltrlrng()` (lateral range curves: inverse
  cube, definite range, M-Beta), `swpwdth()` (sweep width),
  `srchpod()` and `pswppod()` (probability of detection from coverage,
  and for a parallel sweep with navigation error), `srchscs()` (probability
  of success and the Bayesian update after a search), `datumpmap()` (point,
  line and area datums on a grid), `optcrcsrch()` and `opteffort()`
  (Koopman's and Stone's optimal effort), `optsqr()` (the optimal search
  square for a point datum, one search or a series). Each result prints and
  plots, and `srchfig()` draws every figure of Frost's *The Theory of
  Search* (1996) from them; `vignette("search-and-rescue")`.
  For a search of your own, see its section "Your own search, step by step".
- **Evaluating a policy** — `plndid()` (two-way fixed effects with
  cluster-robust errors), `evstudy()` (leads, lags and the pre-trend
  test), `stgatt()` (Callaway-Sant'Anna and Wooldridge),
  `bacondcmp()`, `swtdid()` (de Chaisemartin-D'Haultfoeuille),
  `perminf()` with `stpdnpv()` (Westfall-Young),
  `plnpois()`, `synctl()`; and `sevidx()`,
  `piperate()`, `cmlrisk()`, `bufasgn()` for justice
  data. Each matches the reference implementation;
  `vignette("policy-evaluation")`.
  For a panel of your own, see its section "Your own panel, step by step".
- **First Nations, Métis and Inuit health, mental health and wellness** —
  distinctions-based methods for Statistics Canada's published tables:
  - `sctidy()` and `scests()` read every layout of limit,
    coefficient of variation and standard error;
  - `indgap()`, `dstntst()`, `ordcmp()`,
    `agestd()` and `stdprev()` compare groups;
  - `exptrnd()` covers the intergenerational effects of the residential
    schools;
  - `trcprog()` tracks the Calls to Action.

  Estimators built from Indigenous scholarship on mental wellness:
  - Prof. Suzanne L. Stewart's work: `welprof()`,
    `holbal()`, `dualcont()` and `healchg()`;
  - Prof. Angela Mashford-Pringle's: `connassoc()`;
  - the First Nations Mental Wellness Continuum: `mhcont()`;
  - community-weighted protective and risk factors: `commidx()`;
  - ISC's Community Well-Being index: `cwbscr()`;
  - Walter's 5D critique: `frmaud()`.

  Census profile tools: `cnsprof()`, `profshr()`,
  `cnsstd()`, `cnscwb()`; Call to Action 19: `trchlthgap()`.
  Any agency's table works after `limfrom()` and `qltyrcd()`.

  Each has a plot. Data governance follows OCAP® and CARE. Eight published
  excerpts ship in `inst/extdata` (`?indiex`), and
  `indtabs()` lists the mirrored tables;
  `vignette("first-nations-metis-inuit-health")`.
  For a table or microdata of your own, see its section "Your own data, step
  by step".
- **Complex surveys** — `svydes()` (replicate weights: bootstrap,
  mean bootstrap, JK1, JKn, BRR and Fay's BRR; or strata, PSUs and a finite
  population correction for Taylor linearization), `svyest()`
  (means, totals, proportions and ratios by domain, with the whole design kept
  for every subgroup, Wilson intervals at SAS's modified effective sample size,
  and small domains flagged, not withheld) and `svycmp()` (domain
  differences with the design covariance). Matches the `survey` package;
  `vignette("survey-estimation")` reproduces Health Canada's published CSUS
  intervals.
- **Hot spots over time** — `hotpers()`: how concentrated
  incidents are in place, which cells are hot each period (ties counted and
  said), and how much each period's hot spots overlap the last.
- **Air pollution, from source to burden** — where a plume goes:
  `pgsig()` (Pasquill-Gifford coefficients with Briggs's fits, rural and
  urban), `briggs()` (buoyant and stable branches, transitional
  rise), `gplume()` and `gspuff()` (ground reflection,
  mixing-lid images), `advdif2d()` and `lagrprt()`
  (grid and particle models; the walk takes any normal generator). What a
  concentration costs in lives: `crfpm25()` and `crfno2()` (the WHO 2021
  review's pooled estimates, Chen & Hoek 2020 and Huangfu & Atkinson 2020,
  and Burnett et al.'s 2014 integrated exposure-response curves per cause),
  `attrfrac()` (Levin), `mortdisp()` (BenMAP),
  `polbrdn()` and `polbrdarea()` (the GBD chain, per
  area, worst first). Who bears it: `expconcidx()`
  (Wagstaff, Paci & van Doorslaer 1991). From your own data:
  `plrcf()` and `exprspplr()` (Chernozhukov et al.'s 2018
  partially linear model by cross-fitting, with a percentile bootstrap).
  All of it in one call with an assumption log: `vrfpol()` and
  `polrpttxt()`. Every coefficient cites its paper and is
  asserted in the tests. `vignette("air-pollution-and-health")`.
- **The footprint of the computation** — `co2fp()` reports
  the electricity an expression used and the CO2-equivalent it implies:
  measured from the CPU packages' RAPL energy counters where the operating
  system exposes them (as codecarbon does on Linux; wrap-around handled,
  subdomains not double-counted), otherwise modelled with the Green
  Algorithms formula (Lannelongue, Grealey & Inouye 2021). Utilisation is
  measured rather than assumed, per process or per whole machine (codecarbon's
  two tracking modes), with Green Algorithms' linear or codecarbon's load
  curves. `co2int()` and `co2inttab()` give the grid's
  gCO2e/kWh offline for any country at its latest published year (Ember via
  Our World in Data, 2024-25) and for sub-national zones (Electricity Maps
  2024), each row with its year and source; `dtctloc()` finds where
  you are from the environment, time zone or locale, no network needed;
  `raplok()` says which method you will get; `fpeqv()`
  turns grams into car-kilometres and tree-months. Every default that stood in
  for a measurement is listed in the result.
- **Post-quantum keys and signatures** — ML-KEM (`kemkg()`,
  `kemencap()`, `kemdecap()`); ML-DSA and SLH-DSA keys from
  `fipskg()` and XMSS keys from `pqckg()`, both signing through
  `cpssign()` (an XMSS index never signs twice: carry each
  key forward with `xmssadv()`); and HQC-KEM in both revisions:
  `hqckg(version = "v5")`, the default (specification of
  2025-08-22, 32-byte shared secret), and `hqckg(version = "round4")`
  (the fourth-round submission of 2023-04-30 — the HQC of liboqs up to
  0.12 and of PQClean — with a 64-byte shared secret). Keys carry their
  revision and `hqcencap()` / `hqcdecap()` follow it;
  `hqccmpkey()` stores a secret key as its seed alone (v5's
  32-byte `seed_KEM`; round 4's key-generation seed) and
  `hqcdecap()` expands it. All of it is implemented here, with no
  system library; see
  [Verification](#verification).
- **Deterministic random bits** — `drbgnew()`, `drbggen()` and
  `drbgrsd()`: the AES-256 CTR_DRBG of NIST SP 800-90A (no derivation
  function), with a table-free AES written to run in constant time, and AES-NI on x86-64. The same entropy
  gives the same bytes, which is what reproducible key generation and
  known-answer tests need; `rndbytes()` reads the operating system's
  generator for keys meant to stay secret.
- **Ontario SIU director's reports** — `siufetch()` fetches a
  report by its id, in English or French; `siuprs()` reads
  it into the 16 fields of `siusch()` (the police service;
  the dates of the incident, the notification and the decision; the SIU
  team's size; the counts of subject officials, witness officials and
  civilian witnesses; the affected person's age and sex; the charges; the
  director; where the call was; the injuries; the legislation);
  `siufprs()` does both.
  `siuso()` counts the subject officials from the text
  ("SO", "subject officer" and "subject official" are one quantity).
  `police_service` is the service of the subject officials, read from the
  director's analysis — not the force that notified the SIU, which is
  often a custody, requesting or neighbouring service. Every layout is
  read: the 2005-2011 legacy pages, the 2012-2019 and 2020-on English
  pages, and the French pages (the SIU publishes each report in both
  languages). rmorie and morie run the same parser.
- **JSON without jsonlite** — `tojs()` and
  `fromjs()` are jsonlite's `toJSON()` and
  `fromJSON()`, natively: every option, the same defaults and the same
  bytes out. `jsser()` round-trips an R object with its type
  and attributes (exactly, doubles included, with `digits = I(17)`), with
  base64 and base64url codecs beside it.
- **Curated tables** — `dtabs()` lists the tables served
  at data.rmorie.com (Google BigQuery public datasets and the survey, court
  and justice data the MORIE ledger uses), and `dload("db/table")` opens one with your
  MORIE key (`rmoriebricklayer login` signs in with GitHub or an emailed
  code; or ask at `www.rmorie.com/access/`), under the terms at
  `www.rmorie.com/data-license/`, cached locally. The ICPSR, NCVS
  38604 and a2aj tables open once you accept their terms at
  `data.rmorie.com/terms`. `blfetch()` downloads any URL with an Internet Archive
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
| Survives hostile arguments | Every one of the 125 C++ entry points runs behind a generated try/catch barrier (a C++ exception is an R error, never `std::terminate`), and the 17 written in plain C (the file lock, its release and the locked call, the path probe, the environment wipe, the CSV splitter, the checked writer, the checked gzip reader and its size count, the progress bar and spinner, the survey replicate totals, the survey row keys, their digest and set digest, the survey replicate column pass, and the interrupt check before a key prompt) report errors through R itself; argument types, lengths and sizes are checked before any allocation; quadratic loops and the RSA arithmetic are interruptible; the RSA exponent, SHAKE output, PBKDF2 iterations and SIU inputs are bounded. A C stack overflow is not an exception, so the SIU text passes over a whole document are loops, not regexes, and every line the extractors see is capped; a test runs ten hostile inputs through every one-string SIU entry point in a subprocess | `src/rmbl_barrier.cpp`, `inst/scripts/gen_barrier.R`, `tests/testthat/test-review2.R`, `tests/testthat/test-review3.R` |
| No request to a private address | One check in the transport: the authority parsed as a URL parser does, IPv4/IPv6 literals canonicalised (`127.1`, `0x7f000001`, `::ffff:7f00:1`), local names refused by suffix, every resolved address tested and the connection pinned to it (no DNS rebinding), redirects re-checked hop by hop, `https` never downgraded | `src/rmbl_fetch.cpp`, `tests/testthat/test-review2.R` |
| Robust against hostile input | libFuzzer with ASan + UBSan over the DER parser and RSA arithmetic, the decimal-to-double conversion (checked against the C library bit for bit on every input both accept), and the SIU report parsers; weekly long runs | `inst/fuzz/`, workflow `fuzz` |
| Standards vectors | The C2SP Wycheproof post-quantum sets and the NIST ACVP sets for ML-KEM, ML-DSA, SLH-DSA, SHA-3, SHAKE and HMAC: 6,848 checks, 0 failures, each not-applicable vector named with its reason (the published ACVP PBKDF set is SHA2-224 only, so none of its vectors apply to this package's PBKDF2-HMAC-SHA256, which the test suite checks against the RFC 7914 vectors instead); the masked and the plain paths are compared on every ML-KEM decapsulation and ML-DSA signing vector | `tools/vectors/`, workflow `vectors` |
| Agrees with OpenSSL on any input | libFuzzer differential fuzzing against OpenSSL 3.5: ML-KEM, ML-DSA, SLH-DSA-SHA2-128f, the SHA-2, SHA-3 and SHAKE digests, BLAKE2b, HMAC and PBKDF2 must agree byte for byte | `inst/fuzz/fuzz_ossl.cpp`, workflow `fuzz` |
| Timing on hardware | dudect fixed-versus-random Welch t on x86-64 and arm64 Linux and on Apple silicon (with and without DIT): ML-KEM decapsulation plain and masked, valid against invalid with both classes varying, each phase alone, encapsulation, HQC decapsulation, the digest comparison, PBKDF2; an early-exit comparison is the control that must be flagged | `inst/dudect/`, workflow `dudect` |
| Power, in simulation | TVLA on the code compiled for a Cortex-M4 and run in an emulator, under the Hamming-weight and the Hamming-distance models: every masked kernel shows no first-order leakage under either, every unmasked control leaks | `inst/tvla/`, workflow `tvla` |
| Masked by default | First-order masking of ML-KEM decapsulation and ML-DSA signing, output identical to the unmasked computation. The share-combining gadgets run in assembly on Cortex-M, x86-64 and aarch64 (plain C elsewhere, with the same results) with a fixed register order, zeroed temporaries and a zero store between the two shares; code that handles one share at a time runs each share in its own pass with the registers zeroed in between. Shares are recombined for what the algorithm publishes: the shared secret, the signature and, during signing, the public high bits, the hint and the rejection decision (on rejected attempts too, as FIPS 204 reveals them) | `src/rmbl_masked.h` |
| DER means DER | The parser refuses BER: long-form lengths below 128, lengths with leading zeros, non-minimal tags, end-of-contents octets, trailing bytes; `ECDSA-Sig-Value` must be exactly two canonical INTEGERs and the PKCS#1 block exactly the RFC 8017 DigestInfo | `src/rmbl_asn1.cpp`, `R/x509.R`, `R/timestamp.R` |

Outside what these checks model: electromagnetic emanation, fault injection, glitches and
coupling a leakage model omits, and higher-order attacks on two-share masking. The power
assessment is a simulation, not a capture from a board. `SECURITY.md`
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

The worked example in `inst/bundle/otis-mrp/` goes further than checking the
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
(`hqckg()`, `hqcencap()`, `hqcdecap()`), in two
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
`hqccmpkey()` writes v5's compressed format, `dk = seed_KEM` (32
bytes, defined by the v5 specification), or for round 4 the 96 to 112
bytes its key generation draws (a convention of this package: round 4
defines no compressed format), and `hqcdecap()` re-derives the key
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
is also a cross-language parity check; `cunif()` is the splitmix64
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

## Reproducibility bundles

`mkbndl()` packs a project
folder into one zip that a reviewer with nothing but R unzips and
double-clicks; it checks the data against its pinned SHA-256 and writes
expected against observed for every reported number. `mkbndlproj()`
starts a project of your own:

```r
p <- mkbndlproj(file.path(tempdir(), "my-study"), title = "My study")
# the reviewer's copy finds or downloads the data, or runs on synthetic data
mkbndl(p$dir, dest = tempdir(), overwrite = TRUE)
# or carry the data inside, to run offline
dat <- data.frame(group = rep(c("a", "b"), 50), value = rep(c(4, 6), 50))
csv <- file.path(tempdir(), "my_data.csv")
utils::write.csv(dat, csv, row.names = FALSE)
mkbndl(p$dir, dest = tempdir(), data = csv, overwrite = TRUE)
# the OTIS example above
mkbndl("otis-mrp", dest = tempdir(), overwrite = TRUE)
```

The runner inside the zip takes the data from `--data FILE`, from a copy
inside the bundle, from the bundle's folder or the usual download folders,
or downloads it from the pinned address and refuses a file whose digest
differs; `--synthetic` runs on generated data from the project's recipe,
and every check is then marked INFO, never PASS. See `?mkbndl` for the
project format.

## Algorithms

Several methods re-implement established ones and are tested against them:
the design-based survey estimators (`svydes()`, `svyest()`, `svycmp()`)
against the `survey` package's `svymean()`, `svytotal()`, `svyratio()`,
`svyby()` and `svyciprop()`; the Mann-Kendall trend test and Theil-Sen slope
(`trndtst()`) against `stats::cor.test()`'s Kendall tau and its exact
p-values; the Hawkes-process fits (`chwkfit()`) against the reference fits of
MORIE's Python package, which uses the same C++ core; and the hashes and
signatures against `digest`, `openssl` and published test vectors (see
Verification above). Others are, as far as we know, new in R: the bounds
that a release's rounding and suppression imply for its cells (`pubbnd()`)
and the reproducible data capsules with signed manifests.

## Life cycle

Since 1.0.0 the package is *maturing*: the exported function names and arguments are
stable. A function or argument that is to change or go is first deprecated
with a warning for one minor release, and the change is listed in `NEWS.md`.

## Running the extended tests

`R CMD check` and `devtools::test()` never reach a real host. Setting
`RMBL_LIVE_TESTS=1` (exactly `1`, together with `NOT_CRAN=true`) switches on
the live tests in the same `testthat` suite: downloads from
`cloud.r-project.org` and `www.r-project.org`, a redirect chain at
`httpbin.org`, and Wayback Machine lookups at `archive.org` (never a capture
request). They write only to temporary files and take about a minute on a
broadband connection:

```sh
NOT_CRAN=true RMBL_LIVE_TESTS=1 Rscript -e 'devtools::test()'
```

## Installation

Current release from r-universe (prebuilt binaries for macOS and Windows, a
source build on Linux) or from
[CRAN](https://CRAN.R-project.org/package=rmoriebricklayer).

With [pak](https://pak.r-lib.org) (progress bars, parallel downloads, compiler
output hidden unless a build fails, and the named packages always upgraded to
the current release). Keep the `repos` arguments as written: under `Rscript`
there is no mirror chooser, so a bare `install.packages()` stops with "trying to
use CRAN without setting a mirror", and listing r-universe first gets the newest
release while CRAN still carries an older one.

```r
if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak", repos = "https://cloud.r-project.org")
}
pak::repo_add(rootcoder007 = "https://rootcoder007.r-universe.dev")
pak::pkg_install("rmoriebricklayer")
```

From a terminal (single quotes outside, double quotes inside, so the shell
passes the R code through untouched):

```sh
Rscript -e 'if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak", repos = "https://cloud.r-project.org"); pak::repo_add(rootcoder007 = "https://rootcoder007.r-universe.dev"); pak::pkg_install("rmoriebricklayer")'
```

Without pak, plain `install.packages()` does the same with R's own output:

```sh
Rscript -e 'install.packages("rmoriebricklayer", repos = c("https://rootcoder007.r-universe.dev", "https://cloud.r-project.org"))'
```

Development version from GitHub (a source build; needs a C/C++ toolchain):

```sh
Rscript -e 'if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak", repos = "https://cloud.r-project.org"); pak::repo_add(rootcoder007 = "https://rootcoder007.r-universe.dev"); pak::pkg_install("rootcoder007/rmorie-bricklayer")'
# without pak
Rscript -e 'repos <- c("https://rootcoder007.r-universe.dev", "https://cloud.r-project.org"); install.packages("remotes", repos = repos); remotes::install_github("rootcoder007/rmorie-bricklayer", repos = repos, upgrade = "always")'
```

On macOS, CRAN's R (from <https://CRAN.R-project.org/bin/macosx/>) installs
r-universe's prebuilt binaries in seconds. Homebrew's R cannot use them, so
there every package is compiled from source.

## Quick example

The shortest path, on the OTIS table that ships with the package:

```r
library(rmoriebricklayer)
otis <- read.csv(system.file("extdata", "otis_a01_individuals.csv",
                             package = "rmoriebricklayer"))
a <- anltab(otis, value = "individuals", prd = "year",
            by = c("table", "group"), rnd = 5)
a                                   # what changed, how sure, what was withheld
rptanl(a, file.path(tempdir(), "otis.html"))   # one self-contained file
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
prov <- loadprov(prov_path)

# 2. The data. With network: resolve the pinned endpoint to a current URL and
#    download (Wayback fallback). Without: a reproducible stand-in from the
#    recipe, marked synthetic all the way through.
#   url  <- rslvckan(prov)
#   path <- fdl(url, file.path(tempdir(), "data.csv"))
path <- file.path(tempdir(), "data.csv")
gen  <- mksyncsv(prov$schema$synthetic_recipe, path)

# 3. Integrity and schema.
sha256file(path)                               # pin this in the provenance
df     <- read.csv(path)
issues <- valsch(df, prov)             # names, types, value sets, rows

# 4. The manifest: named cross-checks, then the two capsule artifacts.
man <- mkmnf(list(project = "my-study", synthetic = TRUE))
man <- recrd(man, "rows", obs = nrow(df), expd = gen$rows, syn = TRUE)
wrmnfjs(man, file.path(tempdir(), "manifest.json"))
wrsmrytxt(man, tempdir(),
                  paths = list(input = path, results = tempdir()),
                  whatwasdone = "* validated the schema and recorded the row count")
```

Then ask whether the data itself moved, and sign the answer:

```r
# Did the distribution change, not just the bytes?
set.seed(1)
ref  <- data.frame(value = rnorm(300), size = runif(300, 1, 10),
                   grade = sample(c("a", "b", "c"), 300, TRUE))
same <- data.frame(value = rnorm(300), size = runif(300, 1, 10),
                   grade = sample(c("a", "b", "c"), 300, TRUE))
cpsdrft(ref, same)$anydrft          # a fresh draw: FALSE
moved <- same
moved$size <- moved$size * 3              # a silently rescaled column
moved$grade[1:100] <- "z"                 # and a new category
cpsdrft(ref, moved)                 # both are caught

# Authenticate the manifest so a verifier knows who produced it.
digest <- sha256file(file.path(tempdir(), "manifest.json"))
key <- pqckg()                       # post-quantum, hash-based
sig <- cpssign(digest, key)
cpsvrf(digest, sig, signpubkey(key))
key <- xmssadv(key, sig)            # the next signature must use this
```

An XMSS index must never sign twice, so the package keeps a record of the highest index each
key has used (`xmss_used_indices.txt` in `tools::R_user_dir("rmoriebricklayer", "config")`,
locked by the operating system while a signature reserves its index). A key generated by
`pqckg()` is entered at birth. A key from another machine, one rebuilt from its seeds, or
one used in CI or a container with a fresh home directory is unknown to the record and is
refused at index 0 until `xmssregkey(key)` vouches that it has never signed; or point
`options(rmoriebricklayer.xmssidxfile = )` at a record that persists. See
`?xmssadv`.

See `vignette("drift")` for the distributional checks and
`vignette("provenance")` for signing, Merkle pinning and manifest chains.

## Finding a function

The names are short (`anltab()`, `mkbndl()`, `svyest()`), so look for a
function by what it does:

```r
library(rmoriebricklayer)
help.search("bundle", package = "rmoriebricklayer")   # titles and descriptions
ls("package:rmoriebricklayer", pattern = "^plot")     # by name
```

From a terminal, `rmbl functions bundle` lists the exported functions whose
name or help title matches, `rmbl describe mkbndl` prints one help page and
`rmbl examples mkbndl` its examples. A name from before 1.0.0 still works and
says what it is called now (`?rmbl-aliases`; `rmbl migrate script.R` shows the
rewrite of a script). Each vignette (`browseVignettes("rmoriebricklayer")`)
starts from a worked example and ends with one on your own data.

## Asking a model

The package can put a question to a language model, from R or from the
shell. You bring the model; the package runs no model service of its own and
sends nothing anywhere you did not set up. The routes are tried in this
order, and the first that is set up is used:

1. **An endpoint of your own.** Set `MORIE_LLM_BASE_URL` to any
   OpenAI-compatible server (with `MORIE_LLM_API_KEY` and `MORIE_LLM_MODEL`
   when it needs them).
2. **A provider whose key is set**: OpenAI, Anthropic, Google Gemini,
   OpenRouter, Groq, Together AI, Fireworks AI, DeepSeek, Mistral, xAI,
   Cerebras, Perplexity, Hugging Face, OpenCode Zen, Cohere and NVIDIA, each
   from its usual variable (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
   `GEMINI_API_KEY`, ...) or a key saved with `rmbl config set <provider>.key`.
   Anthropic's and Gemini's own APIs are spoken natively.
3. **Ollama**, found at `OLLAMA_HOST` (or `OLLAMA_BASE_URL`), default
   `http://localhost:11434`. Its server has to be running: `ollama serve` in a
   terminal (or the Ollama desktop app, or the `ollama` system service the
   Linux installer sets up), then `ollama pull NAME` for a model. `rmbl doctor`
   says "not running" until it answers; the model is `OLLAMA_MODEL` or the first one the
   server lists, including the cloud models Ollama serves. Ollama's own cloud
   API works the same way: `rmbl config set ollama.url https://ollama.com` and
   `rmbl config set ollama.key` (your Ollama API key). `OLLAMA_HOST=off` skips it.

While it works, `rmbl ask` (or `rmbl aye`, `rmbl tellme`) shows a spinner with the seconds so far. The same question again
is answered from this machine at once (`--fresh` asks the model again; `MORIE_LLM_CACHE=off`
turns that off), and an error of these packages can be explained without any model:
`rmbl explain-error "the error text"` (R: `explerr()`) names the function that
raised it, the exported functions it comes from and what the message asks for.

The model gets the packages' help: the name, arguments and title of every
function of rmoriebricklayer (and of rmoriedata and rmorie when installed),
and tools to search the help, read a page, its examples, a vignette and the
dataset list before it writes code. A large model (a provider's, or an
Ollama cloud model) gets all of it; a small model running locally gets the
functions nearest the question and can still look up any other.
`MORIE_LLM_CONTEXT` sets the size by hand.

```r
library(rmoriebricklayer)

llmprvd()   # the providers, their addresses and key variables
llmstat()      # which route would answer from this machine, and why
Sys.setenv(ANTHROPIC_API_KEY = "...")    # or llmcfg(anthropic.key = "...")
llmask("How do I estimate a weighted proportion with bootstrap replicate weights?")
llmask("The same question, on the local model.", route = "ollama")
llmmdls(route = "anthropic")   # the models that route offers; attr(, "default")
```

### Choosing the route and model

Every setting can be saved once, from R or the shell, without touching the
environment or the source. Saved settings live in
`~/.config/morie/llm.json` (private to you); an environment variable that is
set still wins for that session.

```r
llmcfg()                                        # every setting, its value and source
llmcfg(route = "anthropic")                     # always this provider
llmcfg(anthropic.model = "claude-opus-5-5")     # its model
llmcfg(ollama.url = "http://192.168.1.20:11434", ollama.model = "qwen3:8b")
llmcfg(own.url = "http://localhost:1234/v1", own.model = "my-model", own.key = "sk-...")
llmcfg(route = NULL)                            # back to the automatic order
```

| Setting | What it does | Environment variable |
|---|---|---|
| `route` | `auto` (own endpoint, a provider with a key, then Ollama), `own`, `ollama` or a provider id | `MORIE_LLM_ROUTE` |
| `own.url`, `own.model`, `own.key` | your OpenAI-compatible server (LM Studio, vLLM, llama.cpp, a gateway) | `MORIE_LLM_BASE_URL`, `MORIE_LLM_MODEL`, `MORIE_LLM_API_KEY` |
| `ollama.url`, `ollama.model`, `ollama.key` | an Ollama server here or on your network; `ollama.url off` skips it | `OLLAMA_HOST`, `OLLAMA_MODEL`, `OLLAMA_API_KEY` |
| `<provider>.key`, `<provider>.model` | a provider's key (stored privately, shown only as "set") and model | the provider's key variable, `MORIE_<PROVIDER>_MODEL` |

With `route = "auto"`, a local Ollama server that has no model pulled is
passed over.

Signing in (`dlogin()`, `rmbl login`) is for the curated tables
at data.rmorie.com only; it is never a language model.

The same verbs exist on the command line once the launcher is on your
`PATH`:

```sh
Rscript -e 'rmoriebricklayer::instcli()'   # links ~/.local/bin/rmoriebricklayer and ~/.local/bin/rmbl
rmoriebricklayer help                           # every verb; `help start`, `help llm`, `help config`, `help r`
rmoriebricklayer doctor                         # which routes answer here, and the one ask will use
rmoriebricklayer ask "your question"            # own endpoint, a provider with a key, then Ollama
rmoriebricklayer ask --model NAME "your question"
rmoriebricklayer ask --route anthropic "your question"   # one route, this time
rmoriebricklayer aye "your question"            # aye and tellme are ask under other names
rmoriebricklayer tellme "your question"
rmoriebricklayer config                         # every language-model setting and where it comes from
rmoriebricklayer config setup                   # pick a provider, paste its key, pick a model
rmoriebricklayer config set route anthropic     # always this provider
rmoriebricklayer config set anthropic.key       # asks for the key; saved privately
rmoriebricklayer config set ollama.url http://192.168.1.20:11434
rmoriebricklayer config set own.url http://localhost:1234/v1
rmoriebricklayer config unset route             # back to the automatic order
rmoriebricklayer config reset --force           # move an unreadable settings file aside
rmoriebricklayer explain-error "the error text" # where an error comes from, no model needed
rmoriebricklayer models --route ollama          # the models a route offers, the one in use marked
rmoriebricklayer login --token                  # the data key: paste the key you were issued
rmoriebricklayer login --email you@example.com  # or: a code is emailed, type it at the prompt
rmoriebricklayer login --email you@example.com --code 123456   # the same, code passed (scripts)
rmoriebricklayer login                          # or: GitHub device flow
rmoriebricklayer login --no-browser             # server / SSH: prints a link + code for any device
rmoriebricklayer logout                         # forget the data key
rmoriebricklayer data list                      # the curated tables at data.rmorie.com
rmoriebricklayer data pull db/table --out t.csv # download one (your MORIE key)
rmoriebricklayer app [PATH]                     # the analysis dashboard (needs shiny)
rmoriebricklayer wayback urls.txt --out w.jsonl # archive every URL in a file (archive.org keys)
rmoriebricklayer wayback --retry w.jsonl        # retry the ones that failed
rmoriebricklayer archive save URL --reason TEXT # save from this connection to archive.rmorie.com
rmoriebricklayer archive find URL               # its captures; archive get ID -o FILE fetches one
rmoriebricklayer pack --new my-study            # start a reproducibility bundle project (mkbndlproj())
rmoriebricklayer pack my-study --data data.csv  # its zip, data inside; a reviewer double-clicks it (mkbndl())
rmoriebricklayer bundle "your request"          # agentbndl() from the shell
rmoriebricklayer verify capsules --fail-on warn # every capsule under a folder, as the rmbl GitHub Action checks it
rmoriebricklayer verify capsules --json         # the check rows as JSON (hmac secret: RMBL_KEY)
rmoriebricklayer drift capsules                 # fetch each source again and compare it with the pin
rmoriebricklayer drift capsules --psi-warn 0.1 --psi-fail 0.25   # the PSI bands of the column table
rmoriebricklayer drift capsules --allow-file --cache .rmbl-cache --snapshot   # file:// sources, a cache, snapshots
rmoriebricklayer verify capsules --base base-copy/   # each manifest against its base copy (a file or a folder)
rmoriebricklayer refresh capsules               # pin each source's new bytes (cpsrfrsh())
RMBL_KEY=... rmoriebricklayer sign capsules     # pin each plain provenance and sign each capsule (cpsseal())
rmoriebricklayer sign capsules --scheme ML-DSA-44 --key-file key.json --overwrite
rmoriebricklayer report capsules --format md    # the Markdown report; never fails
rmoriebricklayer functions [PATTERN]            # exported functions and their titles
rmoriebricklayer describe NAME                  # one function's help page
rmoriebricklayer examples NAME                  # its examples
rmoriebricklayer version
```

`rmbl` is the same command under a short name; every verb works under either:

```sh
rmbl help
rmbl doctor
rmbl config setup
rmbl ask "your question"
rmbl aye "your question"
rmbl tellme "your question"
rmbl "how do I weight a survey?"               # a quoted question with no verb is asked too
rmbl login --token
rmbl models
```

The capsule verbs are `cpschk()` and `cpsseal()` from R, and `ghann()`, `ghcmt()` and `ghout()` give the
annotations, the sticky pull-request comment and the step outputs the rmbl GitHub Action prints.

## Part of the MORIE family

`rmoriebricklayer` is the reproducibility / provenance layer of the
[MORIE](https://github.com/rootcoder007/morie) ecosystem, alongside
[rmorie](https://github.com/rootcoder007/rmorie) and
[rmoriedata](https://github.com/rootcoder007/rmoriedata).

## Acknowledgements

The Indigenous mental wellness estimators stand on the work of Professor
Suzanne Stewart (Yellowknives Dene First Nation), Director of the
Waakebiness-Bryce Institute for Indigenous Health at the University of
Toronto's Dalla Lana School of Public Health, and Professor Angela
Mashford-Pringle (Timiskaming First Nation), its Associate Director. Their
research made it possible to bring their frameworks into this library as
estimators. Any error in that translation is ours.

## Citation

If you use rmoriebricklayer in your research, please cite the software:

> Ruhela, V. S. (2026). *rmoriebricklayer: Reproducible Data Capsules with Provenance and Fallback.* R package version 1.0.3. doi:10.32614/CRAN.package.rmoriebricklayer. https://CRAN.R-project.org/package=rmoriebricklayer

BibTeX (or run `citation("rmoriebricklayer")` after installation for the entry
stamped with the exact installed version, sourced from `inst/CITATION`):

```bibtex
@Manual{ruhela_rmoriebricklayer_2026,
  title  = {rmoriebricklayer: Reproducible Data Capsules with Provenance and Fallback},
  author = {Ruhela, Vansh Singh},
  year   = {2026},
  doi    = {10.32614/CRAN.package.rmoriebricklayer},
  url    = {https://rootcoder007.r-universe.dev/rmoriebricklayer}
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
