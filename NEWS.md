# rmoriebricklayer 1.0.0

## Fixes after the CRAN resubmission

* An error raised while `co2fp()` measures a computation's footprint is now named after the function that asked for the footprint (for example `cpschk: the provenance names no source to fetch`), not after `co2fp()`.
* The vignettes run their code again wherever they are built (r-universe, pkgdown, `R CMD build`), so the articles show their plots; only `R CMD check` re-building a vignette skips the computing.
* The package installs faster, which keeps its CRAN check under ten minutes: R code is no longer byte-compiled at install (R compiles each function the first time it runs), and the two SIU parser files build as one compilation unit, so `<regex>` is compiled once.

## A dashboard, distributions and proof ledgers

* `rmblapp()` opens a dashboard over the package's analyses on your own machine (`rmbl app [PATH]
  [--port N] [--no-browser]` from a terminal; it needs shiny, which is suggested, not imported).
  Load a CSV file, a capsule's pinned data or a data.rmorie.com table, then describe, compare
  years, compute rates, test trends, estimate from a survey, fit distributions, check a capsule,
  evaluate a policy on a panel, read the First Nations, Metis and Inuit tables, work through
  courts and corrections counts, model a plume and its burden, fit a Hawkes process, or check a
  proof ledger. Each analysis shows the R call it ran and runs exactly that call; a refusal is
  shown in the package's words with `explerr()`'s note. The Report tab gathers results into one
  HTML page (plots as inline SVG), Markdown or a GitHub comment. `vignette("dashboard")`.
* The dashboard is built with bslib (suggested, and installed with shiny): menus in the navbar, a
  form in each tab's sidebar, value boxes with the estimate, its interval, n and a verdict, a
  plot card that opens full screen and downloads as PNG, SVG or CSV, a method card (the method in
  its help page's words, its assumptions, what the numbers mean, how to read the effect sizes), a
  diagnostics card, the table and the R call. Every tab opens with its first analysis run on a demo
  dataset. Resampling analyses run in the background so the page stays live, refusals also show as
  a notice, a column of the profile opens its distribution, the year-over-year plot shows a
  period's rows on hover, the Drift tab gives each snapshot's share of a brushed range, and
  "Share this view" bookmarks the page in its URL. Dark mode follows the switch in the navbar.
* `rmbldemo()` returns seeded, made-up datasets for the dashboard and examples: a court caseload
  panel with a staggered reform, monthly offence counts with a step change, a stratified survey
  with replicate weights, a published health table with suppressed cells, custody stock and flow,
  a monitor series around a plume source, a Hawkes event stream, two drift snapshots, case
  processing times and a proof ledger.
* `dstfit()` fits normal, log-normal, exponential, gamma, Weibull, Student t, Pareto, beta,
  Poisson, negative binomial and zero-inflated Poisson and negative binomial distributions by
  maximum likelihood in base R, ranks them by AIC with BIC, Kolmogorov-Smirnov and
  Anderson-Darling statistics, gives percentile bootstrap intervals and a Hill tail index, and
  plots the density, QQ, PP and log-log tail. `mksyncol()` takes `type = "fitted"` to draw from a
  fit.
* New plots in the house style, each returning what it drew: `plotrdg()` (ridgelines),
  `plotecdf()`, `plotvln()` (violins), `plothex()` (hexagonal bins), `plotgain()` (concentration
  curves), `plotcal()` (calendar heatmap), `plothrz()` (horizon chart), `plotsm()` (small
  multiples) and `plotbump()` (ranks over time). `plothwk()` draws a fitted Hawkes process's
  intensity, time-rescaling check and most probable branching; `chwksim()` simulates from it.
* `ldgrread()` and `ldgrchk()` read and check a proof ledger (`schemapath("ledger")`): each theorem
  proved with no `sorry`, each covered function exported by the installed package, each numeric
  check within its tolerance. A check is evaluated in a sandbox that allows only the named
  package's functions and base arithmetic, so `system()` or a file read is refused before it runs.
  A capsule whose provenance says `kind: "ledger"` gets these rows, and its commit and build pins,
  from `rmbl verify`.

## Standards and the fixes they surfaced

* The package documents the rOpenSci statistical software standards (General, EDA, Time Series)
  with `srr` tags: 149 standards tagged as met, 29 not applicable, none left to do.
* A period with no percentage change in `plot(yoy(...))` carries its whole reason again ("first period:
  nothing to compare with", "no percentage: previous period is zero"), sized to the panel; the period-axis
  rewrite had cut every reason at the colon.
* The plots over time put the period on its own scale (a number or a `Date`; text at labelled
  positions) with the unit as the axis title, and take `xlab`, which passed through `...` was an
  error. `plot()` of a `yoy()` or `ratechg()` result draws the period across and the change up, with
  vertical interval bars; groups sit side by side. `gaps = "break"` (the default) breaks a line at a
  missing value, such as a "no data" year `yoy()` inserted, and `gaps = "join"` draws over it.
* A refusal that several functions share now starts with the name of the function that refused
  ("anltab: `data` must be a data frame"), and so do the shared argument checks.
* `stepchg()` puts `before`, `after` and `difference` back into the units of `y` when the
  series is above 1e150 (they stayed rescaled), rescales a series below 1e-150 as well (the
  squares underflowed and every split tied), and refuses an `x` that is not numbers or dates, has a
  missing period or is not strictly increasing. `trndtst()` refuses duplicated periods.
* `yoy()` compares yearly, quarterly and monthly `Date` periods (all on one day of the month, or
  all month ends) on a grid of calendar months; on a grid of days none of them had a comparison.
* `svydes(type = "jkn")` on a domain keeps a replicate that deletes a PSU of a stratum of 101 or
  more PSUs: its factor, within 1% of the weight, is the 1 / rscale its `rscales` says, and it
  was refused as a copy.
* The plots over time put text periods in time order (fiscal years, years, year-months,
  quarters), not in the order they first appear. `plot(yoy(...))` says "no data in the previous
  period" for a period after a gap, which it called the first period, and refuses a result with
  no values.
* `rtcalc()` and `ratechg()` name `pop` in their refusal, and `exprspplr()` names the call
  `estr(data, y, expo, confs)`. `blcli()` refuses `NA` or a function as `args`, `dlogin()` a
  function as `email`, and `instcli()` a `dir` it cannot create or write, each with its name in
  front.
* The examples that sign keep the one-time index record in a temporary file, and the slower
  examples of `blcli()` and `explerr()` run only in an interactive session.
* `chwkfit()` warns when the branching ratio sits on its 0.99 bound.
* `yoy()` compares ordered-factor periods by level order and completes missing levels; its
  refusal names every accepted input. `fylbl()`'s help says a fractional year is an error.
* Every internal function has a roxygen2 block with `@noRd` (srr G1.4a).
* Plot labels shrink to no less than 0.6 of the session `cex` (`?blpal`).
* `cpsatst()`, `cpsbndl()` and their checks take a shared secret (hmac, the attestation recording only its key id), so bundles signed by morie verify with `cpsbndlvrf(key = )`.
* README: who the package is for, which algorithms re-implement existing packages and are checked
  against them, the life cycle, and how to run the extended tests.

## Capsule template and the attestation check

* `vrfcps()` reports a provenance record that does not parse as a failed `provenance_readable`
  row with the parser's message, instead of stopping; the other rows are then run as for a
  missing record. `morie.capsule.verify()` answers the same way.

* `usecpstmpl()`'s `analysis.R` pins the source digest into `data_provenance.json` on its first
  run (`source$sha256` and a `resource` block), so `vrfcps()` verifies the capsule from then on.
  Before, the provenance said the digest would be filled in and nothing ever did.
* `cpschkatst()`'s `key_as_expected` row says whether the key matched; its detail read the same
  either way.
* The Docker image installs the package and puts `rmbl` on the PATH.
* `capenv()$packages` is a named list, so a manifest written with `wrmnfjs()` keeps the package
  names; as a named character vector they were written as a bare array of versions.

## Drift you can look at

* `plot()` of a `cpsdrft()` result takes `what`: `"psi"` (the default) draws the PSI per column,
  worst first, coloured by verdict with the warn and fail bands as dashed lines; `"columns"` draws
  the reference and current distributions of up to six columns (`cols`) with each PSI bin's term;
  `"benford"` the first digits of numeric columns against Benford's law with its 95% band; `"ecdf"`
  the two ECDFs, `"quantiles"` the quantile shift and `"fingerprint"` the PSI of every column on
  spokes, the bands as rings.
* `cpsdrft()` keeps a binned summary of each column (`summ`: missing shares, summary statistics or
  the largest categories, the PSI bins, a histogram, first-digit counts; never the rows) and its
  PSI `bands`, which the plots and reports colour by.
* `drfthtml()` writes the drift report as one HTML file that fetches nothing: the verdict and
  provenance; the chosen column's two distributions drawn in on a canvas; a column table to search,
  filter and sort; per column its statistics and the density overlay or category flow, ECDF
  overlay, quantile shift, PSI by bin and Benford charts, each with a line on how to read it; the
  drift fingerprint and a tile per column; the manifest diff as a tree; PSI over earlier runs as a
  heatmap; the capsule chain (provenance, bytes, manifest, attestation); sliders for the bands and
  alpha that score every chart again; and Markdown, JSON, SVG and GitHub-comment exports. Dates show
  in ISO 8601. `rmbl drift PATH --html FILE` writes it.
* `drftapp()` is the same report as a Shiny app (shiny is suggested), with what would clear a
  column, a rerun on chosen columns and a download of the page; `drftapp()` alone opens on two
  uploaded CSV files, and `rmbl drift PATH --app` opens it on a capsule whose source moved.
  `cpschk()` keeps each capsule's `cpsdrft()` result in its `drifts` attribute.

## Capsule checks from the command line

The checks the rmbl GitHub Action ran in its own script are now in the package, so the action
can call them.

* `rmbl verify PATH` checks every capsule under PATH: each capsule file against its JSON Schema,
  then `vrfcps()` and `cpsbndlvrf()`, one row per check, with the action's Markdown report.
  `--json` prints the rows as JSON instead, and `--fail-on error|drift|warn` sets which failed
  row makes the exit status 1. The secret of an hmac bundle is read from `RMBL_KEY`, which is
  removed from the environment at once; `--public-key` pins the signing key.
* `rmbl drift PATH` verifies, then fetches each source again: new bytes are a warning, and
  columns that drift (`cpsdrft()`) are drift. `rmbl refresh PATH` pins the new bytes, and
  `rmbl report PATH [--format md|json]` prints the verify report and never fails.
* The schemas ship in `inst/schemas/` (the same files as the action's `spec/`); `schemapath()`
  gives their path.
* `mnfdiff()` lists the resources two manifests (provenance records, bundles or data frames)
  added, removed or changed, with their digests and sizes.
* `cpsrfrsh()` fetches a capsule's source again and, when the bytes changed, writes them and pins
  them in the provenance as `usecpstmpl()`'s `analysis.R` does; it returns the `mnfdiff()`.
* `dload()` takes `token`, a MORIE key for that call that is used in place of the stored one and
  never printed. (`key` is already the table's name.)
* `explerr()` takes a data frame of check rows, as `rmbl verify --json` writes them, and explains
  each failed row.
* `cpschk()` runs these checks from R, and with them everything the action's script computed on
  its own: PSI bands (`psiwarn`, `psifail`; `--psi-warn`, `--psi-fail`) with the action's verdicts,
  the per-column drift table with the Benford first-digit p-values of the pinned and the new data,
  each manifest compared with its base copy (`base`, `--base`: a manifest file, a folder, or a
  function that resolves a git ref; results through `mnfrcmp()`, resources through `mnfdiff()`),
  a cache of fetched sources read when a fetch fails (`cache`, `--cache`; none outside an
  interactive session unless a folder is given), `file://` sources (`allowfile`, `--allow-file`),
  Wayback snapshot rows (`snapshot`, `--snapshot`) and captures on refresh (`wayback`), a glob over
  the capsule files (`glob`, `--manifests`), `explerr()` notes on every failed row, and the
  footprint of the checks (`co2fp()`) at the foot of the report (`fp`, `--no-footprint`).
  `format()` renders the Markdown report or the JSON.
* `ghann()`, `ghcmt()` and `ghout()` turn a `cpschk()` result into GitHub workflow annotations (the
  file, and the line of a schema problem), the body of a sticky pull-request comment and the
  action's step outputs. They return text; nothing in the package calls GitHub.
* In `rmbl drift`, new bytes whose columns all stay within the PSI bands are a note rather than a
  warning; new bytes that cannot be compared column by column are still a warning.
* `cpsrfrsh()` records `resource$retrieved_utc`, takes `allowfile` for a `file://` source, and
  refuses new data that fail the schema the provenance pins.
* `rmbl sign PATH` pins each plain provenance on its first run and signs each capsule into
  `capsule_bundle.json` (`cpsseal()`), then verifies, so a program in any language only writes
  the data and a provenance naming it. The key is `RMBL_KEY` or the contents of `--key-file`,
  never printed: the shared secret for `--scheme hmac` (the default), or for a standardised
  scheme the JSON of a `fipskg()` key or its secret hex with `--public-key`. An existing bundle
  is refused without `--overwrite`.
* `rmbl sign --scheme xmss-sha256 --key-file key.json` signs with an XMSS key and treats the key
  file as its state, as RFC 10033 asks: before anything is signed the file is rewritten
  atomically (a temporary file beside it, flushed and renamed, under a lock) with `next_index`
  advanced and a `used` field holding the highest index used, a generation counter and a digest
  of the host that wrote it. A key file that cannot be rewritten is refused; `--state-file`
  keeps the state elsewhere, and a key in `RMBL_KEY` needs it. `--sectors K --sector-index I`
  (or `--sector NAME`) signs only in one of K disjoint index ranges, `--reserve N` reserves N
  indices in one write, `--warn-left N` warns when the range is nearly used up, and a key file
  older than a signature it is seen to have made (in a bundle under the path, or in the
  `--seen-log` each run appends to) is refused as a stale copy. The command line never writes
  to the configuration directory; `RMBL_XMSS_INDEX_FILE` is used only when it is set.
* `rmbl verify` and `cpsbndlvrf()` name each XMSS signature's index and key fingerprint, and an
  index one key signed twice under the path or in `--seen-log` (`cpsbndlvrf(seen = )`,
  `cpschk(seenlog = )`) is a failed `xmss_index` row. `xmssidxseen()` lists the XMSS signatures
  in a folder of bundles and seen-logs and marks a reused index. `cpsseal()` signs several
  capsules with one XMSS key, at consecutive indices.
* The capsule checks compare manifests with a base folder by paths relative to the folder
  searched on every system, and the smoke test restores what its drift case changed, so a
  Windows path no longer reaches `rmbl refresh` as a `file://` URL.
* `plot()` of a `rtcalc()` result with `period` draws the period on its own scale, as the other
  plots over time do, and takes `xlab`; it drew index positions with no axis title.

## Short names

Every exported function, argument, output column, help topic and option now has a short name without
underscores (`survey_design()` is `svydes()`, `conf_level` is `conflvl`, `trend_sensitivity()` is
`tse()`). Each help page gives the full form of every short name. Every 0.5.13 export is still callable
by its old name with its old argument names and defaults: `?rmbl-aliases` lists the 304 aliases, each a
wrapper that forwards to the new function (the eleven rmoriedata 0.3.x calls among them in
`?rmbl-compat`). Allowed values that were renamed (`"mean_bootstrap"` is `"meanboot"`,
`"higher_is_better"` is `"higher"`, `"all_cause_mortality"` is `"allcause"`) are translated on the way,
as are old argument names passed through `...` and the old `what` and `which` values of the plot
methods. The nine options read their 0.5.x names too (`rmoriebricklayer.xmss_index_file` for
`rmoriebricklayer.xmssidxfile`), so a record or cache an old `.Rprofile` points to is still used. `rate()`, `rate_change()`, `share()` and
`yoy_summary()` stay S3 generics, so methods written for them still dispatch. `yoy()` kept its name and
takes its 0.5.x argument names (`period`, `min_base`, `conf_level`, `direction`) beside the new ones.
Code written against 0.5.x keeps running through the aliases: results come back under their 0.5.x
column and field names (`co2e_g`, `pct_valid`, nested tables and attributes too, and the header row of a
delimited writer), `print()`, `plot()`, `format()` and `summary()` work on them, and an alias that is
given one reads it. A 1.0.0 call returns the 1.0.0 names. The one call that cannot tell is `yoy()`,
which kept its name: with a 0.5.x argument name it returns the 0.5.x names, without one the 1.0.0
names (`pctchg` for `pct_change`); `?rmbl-aliases` lists every renamed column and field. `rmbl functions` and the help-aware language-model
tools list the new names. Wire formats (capsule, manifest and service JSON fields, CSV columns from
published tables) keep their names, so files written by earlier versions still read.

## First Nations, Metis and Inuit health, mental health and wellness

Methods for the published tables, distinctions-based (First Nations, Metis and Inuit are each
reported on their own), with suppressed cells never imputed. Data governance follows OCAP® and the
CARE Principles: only openly licensed aggregate tables are used, and First Nations-held survey data
are not mirrored. A new vignette, "First Nations, Metis and Inuit health: published tables,
distinctions and governance", covers them all.

**Reading the tables**

* `sctidy()` reads a Statistics Canada table as published. `VALUE` becomes a number, and the
  quality flag is kept beside it. `F`, `x`, `..` and `...` cells are `NA`.
* `scests()` puts each estimate beside its confidence limits and count.
* `indtabs()` lists the tables the data service mirrors: the 233 Indigenous-titled
  Statistics Canada tables, and the 2021 Census Indigenous Population Profile.
* `indiex()` bundles four published excerpts (tables 13-10-0924, 41-10-0067, 41-10-0082
  and 41-10-0021), so the examples run on real values.

**Comparisons**

* `indgap()` gives the difference and ratio against a reference group.
* `dstntst()` tests whether the groups differ before they are pooled (Cochran's Q and I²).
* `ordcmp()` compares rated scales, such as perceived mental health or life satisfaction,
  as whole distributions: the probability of a higher rating, with an interval from the published
  limits.
* `agestd()` and `rategap()` cover counts. `stdprev()` covers survey
  percentages.
* `genexpo()` and `exptrnd()` cover the intergenerational effects of the
  residential schools.
* `trcind()` maps each indicator of Call to Action 19 (health gaps) and Call 55 (children
  in care, education, income) to the tables that measure it. `trchlthgap()` measures every
  gap against non-Indigenous people on one scale, "times worse", with intervals. Life expectancy and
  infant mortality (tables 17-10-0160 and 17-10-0161) are bundled for it.
* `trccmpl()` and `trcprog()` track the 94 Calls to Action, as the Yellowhead
  Institute counts them (Jewell and Mosby).

**Estimators built from Indigenous scholarship on mental wellness**

These translations are ours. They are inspired by the scholars' work, which is largely qualitative,
and are not taken from it as stated methods. Each help page says so, and says what the estimator
cannot show.

* Prof. Suzanne L. Stewart:
  * `welprof()` reports wellness beside distress, strengths first (Stewart 2008, 2020).
  * `holbal()` measures how evenly wellness is held across a person's domains: the ratio
    of the geometric to the arithmetic mean, with community-set weights and Monte Carlo intervals
    (Stewart 2008; Gabriel, Mirza and Stewart 2022).
  * `dualcont()` treats wellness and distress as two axes (with Keyes 2002, 2005).
  * `healchg()` reads change between survey periods as healing in process (Stewart 2008).
* Prof. Angela Mashford-Pringle:
  * `connassoc()` measures connection to land, community and education across
    places: Spearman's rho with an exact permutation p-value, and an interval that carries the
    published sampling error (Mashford-Pringle and Stewart 2019, *Akiikaa*; Mashford-Pringle 2016).
* Other frameworks:
  * `mhcont()` covers the First Nations Mental Wellness Continuum's four
    directions (hope, belonging, meaning, purpose) from published proxies. A direction with no
    proxy is said to have none.
  * `commidx()` combines protective and risk factors with weights the community sets, after
    the National Inuit Suicide Prevention Strategy. The function never chooses the weights.
  * `cwbscr()` computes Indigenous Services Canada's Community Well-Being index.
  * `frmaud()` gives the share of a report that is deficit-framed (Walter's 5D data).

**The 2021 Census Indigenous Population Profile**

* `cnsprof()` reads the profile. It keeps the characteristic hierarchy, the full-count or 25%
  sample of each topic, the residence (on or off reserve), and the suppression symbols. Repeated
  labels are told apart by their member number.
* `profshr()` gives shares (for example foster children among children, or speakers of an
  Indigenous language) with intervals that carry the long-form sample and random rounding.
* `cnsstd()` gives an Indigenous standard population for age standardisation.
* `cnscwb()` computes a Community Well-Being score from the public profile, and says where it
  departs from the Department's method.
* Two real excerpts (`indiex("census_population")` and `"census_households"`) make every
  example and test run on published values.

Every result draws itself with `plot()`.

**Any agency's table, and the review of every estimator**

* `limfrom()` builds limits from a standard error, a coefficient of variation or a margin of
  error, and `qltyrcd()` maps another agency's flags onto suppressed and use-with-caution.
  An unknown flag warns and counts as ok.
* Published limits that miss their own estimate warn, and that estimate is set aside, in every
  estimator.
* `indgap()`, `ordcmp()` and `dstntst()` take `pooled_groups`; the
  output column `pan_indigenous` is now `pooled_group`. Duplicate groups are refused, and a total
  as the reference warns.
* `scests()` turns a coefficient of variation into log-normal limits, which stay above 0.
* `holbal()` refuses proportions and gives a bias-corrected interval that holds the
  estimate.
* `stdprev()` takes `scale` (100 by default, `Inf` for rates).
* `genexpo()` takes `partial`: a known attendance beside an unknown one is `NA` by
  default, or 1 as a lower bound.
* `connassoc()` gives a Monte Carlo p-value of (b + 1) / (R + 1) beyond eight places;
  its band is documented as a sensitivity band.
* `healchg()` takes `distress`; other indicators are marked `"other"`.
* `commidx()` keeps its `conf_level`.
* `profshr()` takes `rounding_base`; on reserves, where the long form was a full canvass,
  there is no sampling term.
* `cnscwb()` matches places by DGUID and takes `min_population` (250 by default; the
  Department uses 65). Its doc says that housing is pooled across Indigenous households.
* `cnsstd()` takes a DGUID where place names repeat.
* `trchlthgap()`: `times_worse` is now `disadvantage_ratio`. It takes `reference`, and
  warns on duplicate rows.
* `rategap()` refuses a group against itself; `exptrnd()` refuses an outcome with no
  variation.
* The README, the vignette and the pages of the estimators acknowledge Professors Suzanne
  Stewart and Angela Mashford-Pringle, on whose frameworks they are built.

**Fetching what the Wayback Machine cannot capture**

* `fetchvrf()` fetches a file from its source (with the source's own Wayback fallback) or
  from any mirror, and keeps only a copy whose SHA-256 is the one pinned. For servers that refuse
  the Internet Archive's crawler (Statistics Canada does), a capture made elsewhere and published
  as a mirror serves the same verified bytes.
* `arccap()` makes that capture: it fetches each URL from here, records its SHA-256 in a
  manifest, timestamps the manifest with an RFC 3161 authority (verified with
  `tsvrf()`), and uploads the files, the manifest and the timestamp as one public
  archive.org item, streamed from disk with a new libcurl PUT. Given a `wbsave()` result it
  takes the URLs whose server refused the Internet Archive.

**Evaluating a policy from administrative panels**

New estimators, each checked against the reference implementation (`fixest`, `did`,
`bacondecomp`) to rounding error, in base R:

* `plndid()`: difference in differences with two-way fixed effects and CR1 cluster-robust
  errors (one-way or two-way), weights, linear combinations with delta-method errors (the
  effect after a phase-in), and the effect relative to the comparison units' pre-period mean.
* `evstudy()`: leads and lags around adoption, with the joint Wald test of the leads.
* `stgatt()`: group-time effects for staggered adoption (Callaway and Sant'Anna, with
  not-yet-treated or never-treated comparisons; or Wooldridge's extended two-way regression),
  aggregated overall and by time since adoption, with a cluster bootstrap.
* `bacondcmp()`: the two-way estimate split exactly into its two-group comparisons.
* `swtdid()`: de Chaisemartin and D'Haultfoeuille's estimator, with its placebo.
* `perminf()` and `stpdnpv()`: Fisher's test by re-assigning adoption
  dates across clusters (every assignment when there are few), and Westfall-Young stepdown
  p-values for several outcomes.
* `plnpois()`: fixed-effects Poisson or negative binomial (NB2, base R) for counts, as rate
  ratios.
* `synctl()`: one treated unit against a convex combination of donors, with the
  placebo-in-space test.
* `sevidx()`, `piperate()`, `cmlrisk()` and `bufasgn()`: the
  measures these designs take from justice data.
* `polex()` and the vignette "Evaluating a policy from administrative panels". The
  designs are those of Professor Angela Zorro Medina's empirical work.
* `stgatt()` takes `covariates`: doubly robust, IPW or regression difference in
  differences per cohort and period (Sant'Anna and Zhao 2020), equal to `did::att_gt()`.
* `perminf()` and the wild bootstrap take `ties` (`"count"` or `"strict"`).

**Causal estimation on panels**

* `plndml()`: double machine learning with unit and period fixed effects (Clarke and
  Polselli 2025), cross-fitted by unit, with base-R lasso, ridge or OLS learners or any
  learner function, a second-order basis built before demeaning, repeated splits, and
  cluster-robust errors; equal to DoubleML given the same folds.
* `aipwcf()`: cross-fitted augmented inverse probability weighting for a binary
  treatment (average effect, or effect on the treated) with survey weights and propensity
  clipping; the average effect equals DoubleML's interactive regression model given the same
  folds. With `design = svydes(...)` the standard error comes from the design's
  replicate weights (any replicate type) or strata and PSUs, from one fit: the learners are
  fitted without the weights, so each replicate estimate is the replicate-weighted mean of the
  same cross-fitted scores, equal to re-running on every replicate weight.
* `mtchdid()` and `baltab()`: matching on pre-treatment trajectories (Mahalanobis,
  pooled within-group or full-sample covariance, exact groups, calipers), then the weighted
  difference in differences; matches equal MatchIt's.
* `syndid()`: synthetic difference in differences (Arkhangelsky et al. 2021) with exact
  weights, placebo or jackknife errors.
* `wcb()`: the restricted wild cluster bootstrap with Rademacher or Webb
  weights, full enumeration, and an interval by test inversion that is unbounded when the
  design cannot reject.
* `tse()`: Rambachan and Roth's relative-magnitudes bounds with a conservative
  interval and the breakdown value.
* `plnpwr()`: design-based power and the minimum detectable effect on real data.
* The figures of policy papers: event studies in a Stata style or with the post-period
  shaded, `plotevgrid()` for several outcomes, the Goodman-Bacon scatter, permutation
  distributions, `loounit()` and `cohtrnd()`.
* `sprd()`: the variance, standard deviation and standard error with the correction the
  data call for (Bessel's n - 1 for a sample, none for a whole population described as it is,
  the finite-population correction for a sample drawn without replacement, frequency or
  reliability weights), chosen automatically from the population size and explained.

## Search and rescue

* Search theory for planning a search, in base R: `ltrlrng()` (lateral range curves), `swpwdth()`
  (sweep width), `srchpod()` (probability of detection from coverage), `pswppod()` (a parallel sweep,
  with navigation error), `srchscs()` (probability of success and the update after a search that
  finds nothing), `datumpmap()` (point, line and area datums on a grid), `optcrcsrch()` and
  `opteffort()` (the optimal effort for a circular datum and over cells), and `optsqr()` (the
  square a point-datum search should cover, for one search or a series). The numbers agree with
  rmorie's to 1e-12. Each result prints and plots, and the dashboard (`rmblapp()`) has a "Search and
  rescue" tab with them and a picker for the book's figures. `srchfig()` draws each of the 36 figures of
  Frost's *The Theory of Search* (1996) from these functions with the book's parameters, and a new
  vignette, "Search and rescue", walks the book's chapters through them.

## Fixes from the CRAN stress test of 0.5.14

* **No leak on an argument error in compiled code**: an error raised inside a C++ entry point
  jumped over the C++ objects alive at that moment (two strings at every error of the barrier,
  3,200 bytes over 50 calls under valgrind; the Merkle chunks, an NA URL with headers set, BLAKE2b
  with an NA element). The barrier now holds its message in a fixed buffer, and an argument error
  inside a body is thrown and raised by the barrier once the body's objects are destroyed; valgrind
  reports nothing lost on those paths. The barrier generator (`inst/scripts/gen_barrier.R`) writes all
  of it, so regenerating the file keeps it.
* **`rsvidx()` answers Ctrl-C**: 3e9 items ran 37.9 s through a SIGINT.
* **`stepchg()`**: when every ordering is enumerated the observed one is among them, and is no
  longer counted twice (p = 73/721 for 0.1). Drawn permutations keep the `+1`.
* **`trndtst()`** on a constant series gives p = 1 at every length (it was NA past n = 8).
* **`cnttrnd()`** with zeros at one end only (`c(0, 0, 5)`) warns that the trend has no finite
  estimate and reports a rate ratio of `Inf` (or 0) with no interval; it was 9.7e16 silently.
* **`valrules()`** on a table of no rows fails no row-wise rule (every rule failed).
* **`onlsmry()`** takes each block's sums in two passes, as `var()` does: values near 1e8
  with a spread of 1 lost nine digits of the variance. The help page says "to rounding", not exact.
* **Seeds**: `knoxtst()` takes every seed up to 2^53 - 1 (2^40 was refused, -2^31 called too
  large), and `cpsfals()` records a seed past 2^31 - 1 as given (it became NA).
* **Network**: the URL gate refuses 6to4 addresses that carry a private IPv4 address
  (`[2002:7f00:1::]` is 127.0.0.1), Teredo, the local-use NAT64 prefix and the discard prefix; a
  307 or 308 redirect repeats a POST as a POST, to the same host only (it became a GET);
  `wbsave()` does not send the public archive a URL on your own network (`https://10.0.0.7/`,
  a `.local` or one-label name); the manifest is read with a 32 MiB cap (a 300 MiB gzip bomb was
  read whole before allocation failed).
* **JSON**: a well-formed reply is parsed in compiled code (15 MiB took 85 s; 9.4 MiB takes 0.26
  s). Whatever the R parser has words for (an error, a big integer, a duplicate key, nesting past 100
  levels) is still parsed by it, so messages and warnings are unchanged, and a staged bundle, which
  has no compiled code, parses as before (its R parser is twice as fast too).
* **CSV reader parity with `read.csv(skipNul = TRUE)`**: NUL bytes are dropped before quotes are
  read (a quote, a NUL and a quote is a doubled quote; a line of `""` with a NUL in it is blank); a
  quote after a closed quoted field opens a quoted run again, a comma or line end inside it being text
  (`"x"y",z"` is the one field `xy,z`); a byte-order mark after an empty `""` in the first row is
  dropped. The two shapes it refuses, where `read.csv()` changes the data without a word (a record
  with more fields than the header, a quote inside an unquoted field), are now in the help page.
* **CLI**: a three-letter near miss (`rmbl "dat list"`), a hyphenated one (`"xplain-rror?"`) and a
  short line naming a file (`"urls.txt?"`, `"my urls.txt"`) are not questions; a run of 16 or more
  letters and digits mixed (an archive.org key) is a key; `--model` and `llmask(model =)`
  refuse a key given as a model name before any route is looked for (it was sent as the model).
* **`svydes()`**: a post-stratified JK1 set on a post-stratum subset is accepted (the
  replicates that delete a PSU with no row there are the weight); the adjustment is read from the
  replicates that differ from the weight, and for JK1 from the factors across the set (one factor
  n / (n - 1) unadjusted).
* **Tests on CRAN**: no test renames the installed launcher (it wrote into the library); the wall-
  clock bounds are fifty times wider where CRAN runs the tests (under valgrind they took 19 s against
  15 and 30 s against 10); the archive.org lookup needs `RMBL_LIVE_TESTS=1`. The `agentbndl()`
  example points the settings folder at an empty one, so a saved key cannot make it call a provider.
* **Undefined behaviour**: a NaN probability in the quantile kernel and a NaN time in the Hawkes
  compensator are no longer cast to an integer.
* **`plots.R`**: the "µg" unit is a value, not a name in `c()`, so a non-UTF-8 locale keeps it.
* **Arguments, again**: a battery of every export with 41 hostile values in every argument (not only
  those the examples set; 38,836 calls over 306 functions) found 1,007 base R errors in 77 functions
  past the fixes above (the stress test counted 1,070 in 180), among them every `yoy_*()` writer's
  `digits`, `stepchg()`, `scanadj()` and the plots' `col =`; each is refused in words, naming the
  argument (the final audit's wider battery, 15 values in every argument of every export, found
  90 more raw errors in 31 functions; those are fixed below). Shared checks do most of it: a single
  number in a range (`.rmbl_scalar()`), an environment refused where data goes, a date refused as a
  count (`reps = Sys.Date()` ran 20,000 replications), colours checked before a device sees them (one
  check for every plot), titles checked once. `morani(n_perm = 1)` no longer fails on the spread of
  one permutation.
* **Memory**: `chwkres()` and the fits built a grid of one point a time unit, 32 GB for
  a horizon of 2^31 (the process was killed); a constant baseline needs none, a sinusoidal one keeps a
  point a day and refuses a horizon past 4,194,304 days. `mksyncsv()` refuses more than
  100 million rows (it builds the table in memory; 2^31 was a process killed). `svydes()`
  computes its row keys and their digests in C and its degrees of freedom a block of rows at a time:
  5e6 rows and 20 replicates peak at 2.8 GiB as a matrix and 2.4 GiB by name (3.5 and 3.1), the design
  in 20 s and an estimate in 5 s (52 s each in the stress test).
* **A time limit ends a loop over your function**: `cpsfals()`, `cpspwr()` and the
  exposure-response bootstrap caught `setTimeLimit()`'s error as one more failed statistic and ran on.
* The README says 123 C++ entry points behind the barrier (one new, the JSON path) and 15 in plain
  C (the survey column pass and the set digest are new).

## After the tag: the manual, the plots, a C locale

* **The reference manual** ran off the page on 123 lines: long URL templates and option names
  inside inline code, dense lists of code, references with long DOIs. R's `Rd.sty` lets inline
  code neither break nor stretch, so the help text was reworded (URL templates split at a slash,
  references with the link on its own line, options named in prose, long lists as bullets). No
  line is 10pt over now; the 61 left are under 10pt, most under 2pt.
* **Plot titles** of 17 methods were handed straight to the base-graphics call, so a title wider
  than the panel was cut ("Community Well-Being, by place and gro"). Every method now draws its
  title with the fitter the others use: full size, then smaller, then two lines.
* **Row labels** are drawn with `mtext()`, sized to the row (down to 0.45), instead of `axis()`,
  which leaves out labels that would overlap: `trchlthgap()`'s 44 rows showed 22 labels beside
  the wrong points. `plot.rmbl_trc_gaps()` adds a key for the groups.
* **Labels cut to the same text** keep the part that told them apart ("...of 8, 9 or 10" and
  "...between 0 and 5") instead of a number; the wellness profile breaks long indicator names
  onto two lines.
* **A C locale**: `cnsprof()` matched the profile's column names against UTF-8 keys, so "MÉTIS"
  never became "Métis", and its table of column names was built with a non-ASCII name inside
  `c()`, which a package installed in a C locale stores as `M<U+00C9>TIS`; `.rmbl_json_parse()` converted before it checked, so invalid UTF-8 was
  reported as an unexpected character; the CSV reader's byte-order-mark cases are compared with
  `read.csv()` only in a UTF-8 locale, where its behaviour is defined.
* **`rmoriebricklayer.allowhttp`** was read by the R-level URL check but the native transport still
  read the old `rmoriebricklayer.allow_http`, so `bldl()` refused plain `http` whatever the option
  said. Three more from the coverage pass: `evstudy(leads = 1)` failed with "subscript out of
  bounds" (no lead left to test); `baltab()` failed on a group of one unit (its tests are `NA`
  now, as after `mtchdid()` with a tight caliper); `chwkfit(meth = "em")` with every event at the
  horizon divided 0 by 0 (the branching ratio goes to its floor). `mcartst()` refuses an infinite
  value in its own words rather than as collinearity.
* Every line of R and the reachable lines of C++ are now covered by the tests; the dead guards
  found by the pass are gone.
* The statement about a third-party security audit is gone from `DESCRIPTION`, the README,
  `SECURITY.md` and the help pages.
* Every example's output was read against its comment. `print.rmbl_yoy()` printed "no
  periods" for a column subset; the `cpsrpt()` example read a `mrkroot` field that is called
  `merkle_root`; the `recrd()` comments say when a status is `INFO` instead of `PASS`; the
  `onlsmry()`, `benfordtst()`, `wrmnfjs()`, `cpspwr()` and `plnpois()` examples show what
  they claim.
* `vignette("plotting-results")` gains the policy-evaluation plots, one call per result;
  `vignette("policy-evaluation")` draws the synthetic difference in differences and
  `vignette("causal-effects")` the AIPW estimate beside its overlap.

**The final pre-CRAN audit** (three reviewers and a re-run of every earlier finding)

* **A test failed `R CMD check` on a host without IPv6 sockets** (a kernel booted with
  `ipv6.disable=1`): the socket guard's probe now answers `NA` where the address family cannot be
  opened, and the test skips there instead of reading it as a refusal.
* **Large CSVs read through the streamed path** (tables past 512 MiB) took a ragged row silently,
  the first column as row names and the data shifted one column left; `read.csv()`'s field count is
  checked record by record first, and the file is refused in the same words as the in-memory path.
* **The survey reorder check** read a swap of two rows beside one edited cell as "in order" (SE
  9.60 for 9.92 with no error): the design keeps one key per row, and rows that moved beside fewer
  rows that changed are a reorder, whatever the columns the swap left unchanged say. An edit that
  turned an integer column into a double one changed every row's code as well; integer and logical
  columns now code as their doubles do.
* **A double column holding -0** (`round(-0.3)` is -0) gave its row an `NA` key, which wiped the
  other columns' contribution and hid reorders among such rows: -0 codes as 0 and every NaN
  payload, `NA` among them, as one value. A design saved by 0.5.14 with `NA` in a double column
  is rebuilt on its data.
* **The degrees of freedom** read the replicate matrix's rank from a `B x B` cross-product: with
  more replicates than rows that asked for 74.5 GB (`n = 20`, `B = 1e5`) and took 113 s at
  `B = 5,000`. The smaller of the two Gram matrices is read, the replicates scaled first (a
  replicate of 1e308 overflowed `eigen()`).
* **Memory, again**: `svydes()` reads each replicate column against the weight in one native pass
  with nothing allocated as long as the column (the R pass held 340 MB a column at 5e6 rows), and
  its row-key digests read a column as a set through an order-independent hash in place of a
  sorted copy (a radix sort asks for working memory as long as the column outside R's heap, and
  that request failed at the limit). 5e6 rows and 20 replicates now fit a 3 GB address space as a
  matrix and by name, the matrix design in 6 s (17 before). A domain estimate centres its
  linearized values within strata one column at a time and reads the rows of each domain once:
  fifty domains at a million rows peak at 0.65 GB of heap (1.9 before).
* **The replicate contract's edges**: a Fay replicate equal to the weight (a post-stratified domain
  whose rows sit in one PSU per stratum) is said, not refused; one factor `k/(k - 1)` on every row
  with no row left out, carried by more or fewer replicates than its `k` (`w * 1.005` beside 200
  JKn replicates, the full data plus `w * 15/14` under JK1), is said as a rescaled copy. Two or more
  JKn replicates equal to the weight stay as they are: a stratum left out of a subset leaves all of
  its replicates at the weight, and two copies of it cannot be told from that.
* **The manifest fetch** capped the bytes on the wire, and a reply sent with
  `Content-Encoding: gzip` was stored as sent and decompressed whole by `readLines()`: 300 MiB of
  zeros in a 300 KB body (a 2.3 GB allocation, or an OOM kill). The manifest is read a megabyte at
  a time through `gzcon()` and refused past 32 MiB decoded.
* **The JSON fast path** gave up on a big integer, a duplicate key and nesting past 100 levels and
  handed the whole document to the character-by-character R parser: one such value at the end of
  a 15 MiB reply cost minutes. Whole numbers of 16 digits or more follow the R parser's rules in
  C++ (text when asked, else a double, the inexact ones warned about once), a duplicate key and
  deep nesting are refused there in the same words and at the same character, and any other
  failure in a document past 128 KiB is refused with its reason instead of re-read. The direct
  `.Call` refuses bytes that are not UTF-8 rather than handing back an invalid string, in a C
  locale too (R's translation there rewrote such bytes as `<ff>` before the check saw them).
* **The command line**: a trailing `?` no longer makes a question of a near-miss command
  (`dat list?`, `conifg set openai.api_key?`); zero-width characters are removed before the key
  check, so a key broken by them is still a key; dotted or underscored runs with digits in two
  segments or more, sixteen letters that change case four times or more, and a key typed in groups
  of 8 to 16 characters are keys; a UUID, dashed groups of mixed-case characters, a 15-character
  mixed token or a key of a known prefix given as `--model` is not sent as the model name.
* **`col =`** is checked by the field, density, Knox and leave-one-out plots (raw `image()` errors
  before; the leave-one-out plot ignored it).
* `onlsmry()` refuses an infinite value in words (`smrystat()` failed in R's); `stepchg()` reads a
  series near the double's range in units of its largest value (the statistic overflowed to `Inf`,
  the p-value to `NaN`); `fylbl(2024.5)` is refused instead of labelled "2023/24".
* `rmbl` exits 130 for a Ctrl-C that lands while R is still starting (status 1 and "Execution
  halted" before); an interrupt a native call took and a `tryCatch(error = )` swallowed as
  "interrupted" is raised again as the interrupt it was (`rmbl data pull` went on for 65 s once in
  ten runs).
* The tests' wall-clock bounds widen with the machine's load per core and under covr; the test
  that connects to the loopback discard port skips on CRAN.
* **`syndid()` and `synctl()`** solve their simplex-constrained least squares by an active set on
  the KKT system (one small solve a step) with the projected-gradient method as the fallback: the
  tiny ridge of the time weights ran the latter to its iteration cap, a second a placebo and 55 s
  of CPU in each of two vignettes; 0.04 s now, at the exact optimum (the earlier weights were the
  cap's approximation, so estimates move in the third digit).
* **The hostile-argument battery**, 20 values in every argument of every export, found raw base R
  errors in 31 functions: a `NULL` seed (`set.seed(NULL)` in seven functions), a learner function
  of the wrong arity, `NULL` column names, `1e308` in the air-dispersion arguments, block sizes,
  `pubbnd()`'s `suplim` and `supmar`, `mksyncol()`'s `basep`, `tojs()`'s `digits`, the bundle,
  capsule and template file arguments, `yoylbl()`'s `labels`, `profshr()`'s `num` and `den`,
  `plotevgrid()`'s `main`, `plnpois()`'s `offset`, `trchlthgap()`'s tables, `wcb()`'s `trtd`,
  `chgenv()`'s `per`, the `strict` and `ex` flags, the `col` of the `rule*()` builders and
  `chwknll()`'s `par`, and `shrs()`'s `total`. Each is refused in words now. The re-check of the
  fixes replayed the battery and found 29 more in nine functions, refused in words too: `blcli()`'s
  `out`, `cnscwb()`'s `groups`, `dlogin()`'s `token`, `rtcalc()`'s infinite counts, `recrd()`'s
  manifest, `plotfnl()`'s `target` and `stkflow()`'s `per`. A key typed in groups with punctuation on
  its last group ("... qrst9012uvwx?") is a key.
* The native CSV reader drops a byte-order mark before a header name when blanks follow the mark
  (`read.csv()` keeps the mark in the name, `X.s`): 37 of 24,000 fuzz inputs, documented.

**Fixes from the review of the native code**

* **macOS**: `siudate()` returned "" for every accented French date ("3 août 2017",
  "3 DÉCEMBRE 2017") because the native text code folded case with `std::tolower()`,
  which on macOS in a UTF-8 locale rewrites the bytes of a multibyte character as if they
  were Latin-1. Case folding of text that may hold UTF-8 is ASCII-only now, in the SIU
  parser, the SIU resolver and the transport (r-universe macOS checks of 1.0.0).
* `fetchvrf()` no longer passes on R's "cannot rename file" warning when it falls back to
  copying the kept file into place.
* ECDSA verification refuses an `r` or `s` longer than the curve and a key coordinate that is
  not exactly one field element: `r` with 2^1152 added was read back as `r` and verified.
* The elliptic-curve multiplication refuses a scalar longer than 144 bytes instead of reading
  only its low bytes.
* A host written with a trailing dot (`https://example.com./`) is fetched as `example.com`, so
  the address pin and the URL libcurl is given name the same host; before, libcurl found no pin
  and resolved the name again itself.
* Every connection the transport opens is checked as it opens, so a private or loopback address
  is refused even when it comes from somewhere other than the pin. This includes a proxy named
  by `http_proxy` or `https_proxy`: a proxy on the loopback interface or a private network is
  now refused.
* The decimal reader is correctly rounded past 768 significant digits: dropped digits that were
  not all zero now count when the kept ones are exactly halfway.
* The decimal reader takes nothing after `Inf`, `Infinity` or `NaN` (any case), so `"Info"` and
  `"nanny"` are `NA`, as `as.numeric()` reads them.
* `cgamcdf()` is accurate for large shapes. At `x = a` it gave 0.4786 for `a = 1e4` and 0.0797
  for `a = 1e6`, where the answer is 0.5013 and 0.5001.
* A missing, zero or negative timeout is the default for every request, never no limit at all.
* Destinations and upload paths starting with `~` are expanded. A destination that cannot be
  written is reported as a local failure, without a Wayback lookup.
* On Unix, a download that cannot be moved into place leaves the old file as it was. Only
  Windows removes the destination before the move.
* The download progress callback protects both of its arguments while it builds the call.
* An RSA signature must be exactly as long as the modulus (RFC 8017 8.2.2): leading-zero
  variants of a valid signature no longer verify.
* An XMSS signature whose randomizer is not 32 bytes of hex does not verify. It used to raise an
  error.
* XMSS keys name their seeds `pubseed`, `skseed` and `skprf`, as the help pages always said.
  Keys saved with the earlier `pub_seed`, `sk_seed` and `sk_prf` still sign and verify.
* The Hawkes messages name the argument `hor`.
* `kemsz()` and `hqcsz()` name their sizes `public`, `secret` and `shared`, as the keys and
  capsules name them. `siusch()` names its column `count`, and `fipssz()` names the
  per-signature randomness `rnd`.
* The native errors name the R arguments: `person` and `addl` for the DRBG, `pass` for PBKDF2,
  `rnd` for SLH-DSA.
* One-shot SHA-3 and SHAKE wipe their Keccak state. The permutation can be run backwards, so the
  state gave back secret inputs such as ML-KEM and ML-DSA seeds.
* The SHA-256 and SHA-512 message schedules and contexts are wiped after use, so an HMAC key
  padded with ipad no longer stays on the stack.
* XMSS key generation and signing wipe their seeds on every exit, including a refused argument or
  an interrupt, along with the heap buffers and chain steps derived from them.
* The heap copies of BLAKE2b and HMAC keys, the derived PBKDF2 key and the operating system's
  random buffer are wiped before they are freed. HMAC no longer frees an unwiped copy of the
  padded key when its buffer grows.
* Unmasked ML-DSA signing wipes the sampler seed, the packed mask and the values of rejected
  attempts.
* `siuso()` removes the glossary sentence in one linear pass. 8000 repeats took 28 s before.
* `siutxt()` no longer rescans to the end of the page for every unclosed script or style tag.
* The SIU parsers and the distinct-count sketch read latin1 input as the text it is: a latin1
  "5 décembre 2023" is a date, and one value in two encodings is counted once.
* `siudate()` refuses an impossible ISO date such as 2023-02-30 or 2023-13-45, as it already
  refused February 30.
* A director whose name contains the letters "the", such as Heather Smith, is no longer dropped.
* A numeric entity naming a UTF-16 surrogate decodes to nothing instead of invalid UTF-8.
* HTML entities are decoded once each, in one pass, so `&amp;lt;` stays the literal `&lt;`.
* Lower-casing SIU text no longer passes negative values to `tolower()`.
* The kernels published to `LinkingTo` packages have the guards of their `.Call` versions.
  Theil-Sen takes at most 20,000 points and polls for a Ctrl-C, and an exception in any of them
  is an R error instead of ending the session.
* Moran's I checks its neighbour indices and `nperm` before it allocates, and polls for a Ctrl-C
  between permutations.
* The Hawkes entry points refuse an `eps` or a sum-of-exponentials window that is not one. `eps`
  of `NaN` silently dropped the excitation term, and 0 ran out of memory.
* The C API's Hawkes likelihood keeps its own kernel codes and Lomax shape, now documented in the
  header and checked against `chwknll()`.
* Midranks of a vector with `NaN` are defined: the comparator orders `NaN` last.
* The SHA-256 chunk state no longer carries four uninitialised padding bytes.
* The Wayback snapshot URL is returned whole and with its JSON escapes undone. A long URL was cut
  at 2047 bytes.
* A download whose file cannot be reopened after a redirect ends cleanly, instead of writing to a
  closed stream.
* POST bodies set their size with the 64-bit libcurl option, which also works on Windows.
* The scratch file of a download is created exclusively (`"wbx"`).
* The CSV splitter's NUL branches are gone: under `skipNul` the NUL bytes are removed before the
  scan, so those branches could never run.
* The README counts 123 C++ entry points, the comments in `init.c` name the right source files,
  and `SECURITY.md` names `RtlGenRandom`.
* `/dev/urandom` is read through a descriptor opened close-on-exec instead of buffered stdio.
* Native error messages are no longer cut at 1024 bytes by the barrier.
* A wait for a lock held by another process ends at a Ctrl-C or a time limit.

## Security

* `rmbl drift` and `rmbl refresh` (`cpschk()`, `cpsrfrsh()`) fetch a capsule's source over
  `https://` only. A local path or a `file://` URL is read only when it resolves, links followed,
  to a file inside the capsule, inside the `allowfile` folder (`TRUE`: the folder checked), or in
  the package's `extdata`; never under `/proc`, `/sys` or `/dev`. A source such as
  `/proc/self/environ` or a `creds.csv` outside the capsule used to be printed in the report.
* Drift reads the pinned data file only inside the capsule (`resource$filename` of
  `../../outside.csv` was read and its header printed).
* Refresh does not write through a `data_provenance.json` that links out of the capsule.
* A gzip source or data file inflates to at most the option `rmoriebricklayer.maxcsvbytes` when
  drift or refresh reads it; a small gzip of zeros ran for minutes.
* `--public-key ""` (or any capsule option given an empty value) is a usage error, and
  `cpsbndlvrf()` and `cpschkatst()` refuse `keyexp = ""`; both checked against no key.

## Fixes from the audit of 30bed8e

* `fromjs()` reads a `\u` escape only with four hex digits: `\u 041` was read as "A" and
  `\u-041` as the key "NA".
* A key typed in groups joined by any punctuation with no space (`abcd1234efgh;ijkl5678mnop;...`)
  is a key and is not sent to a model; so is an AWS access key id written in letters only.
* `RMBL_KEY` is removed from the process before anything else, and its startup copy is wiped.
* A provider reply with a long number or bytes that are not UTF-8 gives the package's message,
  not R's warnings.
* `wbsave()` refuses a public name that resolves to a private address.
* `fromjs()` decodes a latin1 string in a C locale, and simplifies sparse records about twice
  as fast.
* `fdl()` passes a time limit on instead of trying the fallback; drift tries the Wayback copy the
  provenance pins and no other, and deletes its download.
* The drift report escapes directory names in its HTML, and a symlink loop lists each capsule once.
* Six test files of the native code (JSON parity, dtoa, HashML-DSA, sketches, the 1.0.0 native
  branches, X.509 branches) now also run on CRAN.

# rmoriebricklayer 0.5.14

* A new data key is issued only after the data access terms are accepted. `rmbl login` and
  `bricklayer_llm_login()` show the terms summary and their address, ask `Do you accept ...? [y/N]`,
  and then ask for your name, organisation (optional) and why you need the data; for the restricted
  tables (Schedule B: ICPSR, NCVS 38604, A2AJ case law) they also ask for a supervisor, department
  chair, director or coordinator and their email. In a script, give them as arguments
  (`accept_terms = TRUE`, `name`, `affiliation`, `purpose`, `restricted`, `supervisor_name`,
  `supervisor_role`, `supervisor_email`) or flags (`--accept-terms`, `--name`, `--affiliation`,
  `--reason`, `--restricted`, `--supervisor-name`, `--supervisor-role`, `--supervisor-email`).
  Nothing is sent until every required answer is there; the data service checks the same things.
  `login --token` with a key you already hold is unchanged.

## Fixes from the re-test of the b617a3f CRAN stress fixes

* **`setTimeLimit()` during a POST** (`ask`, Wayback `/save`, the data-key check) is an ordinary
  error that `tryCatch()` catches, said as R says it ("reached elapsed time limit"); it halted
  Rscript as an interrupt. A Ctrl-C is still an interrupt.
* **A command typed as one argument is not a question**: `rmbl "cnfig set openai.key"` and a
  tab-joined `$'cnfig\tset\topenai.key'` were sent to the first provider; they are a near miss now,
  named in "did you mean `rmbl config`", with exit status 2 and nothing sent.
* **`survey_design()`**: a JK1 replicate on a domain subset that scales every row by
  `k / (k - 1)` (its deleted PSU outside the subset; within 1% of the weight from 101 PSUs) is no
  longer refused as a copy; in a post-stratified or calibrated set, replicates equal or close to the
  weight are accepted and not warned about (bootstrap and BRR subsets were). A single JKn replicate
  equal to the weight is refused as the copy it is, and a JK1 or JKn replicate that leaves no row
  out without being such a rescale is warned about, as the Rd said.
* **A provider's key prefix (`sk-`, `gsk_`, `hf_`, `AIza`, `xai-`, ...) with twelve key characters
  or more is a key however short**: a 23-character `sk-` key in a question went to a model.
* **`survey_design()`**: a column of `data` passed in a partly named replicate matrix is refused as
  in a named one (it was taken as a replicate); two outcomes permuted for a permutation test beside
  columns still in place are no reorder (they were refused as one). Replicates given by name are no
  longer digested for the row check (the design keeps them): a design by name and each estimate on
  it were 2 to 5 times slower than the same replicates as a matrix (10.8 s and 7.8 s for 4.7 s and
  1.5 s at a million rows). The adjustment check reads 4,096 rows of each replicate.
* **CSV reader parity with `read.csv()`**: a byte-order mark at the start of the first row (after
  blank lines, or inside its opening quote) is dropped, as `scan()` drops it; a header of blanks or
  of the mark alone is a header of no columns, its rows read as row names.
* **Arguments**: 123 functions gave a base R error for a value of the wrong kind (a data frame, a
  list, `NA`, a vector, a function or a number where a path goes), 696 cases in a battery of every
  export seeded from its examples; each is now an error that names the argument. Numeric arguments
  refuse lists, data frames, factors and complex numbers in words; the writers (`yoy_csv()` and the
  other `yoy_*()` writers, `write_recode_manifest()`, `write_summary_txt()`,
  `use_capsule_template()`, `make_synthetic_csv()`, `bricklayer_download()`) refuse a path that is
  not one string (a number was written as a file named `1`); errors raised in the compiled code no
  longer carry the `.Call()`.

# rmoriebricklayer 0.5.13

* The survey-estimation vignette loads the CSUS 2023 public-use file and its 1,000 mean bootstrap
  weights with `bricklayer_data_load("csus_2023/pumf")` and `("csus_2023/bootstrap")`, now hosted on
  data.rmorie.com, or downloads them from Health Canada with `bricklayer_download()`; it no longer
  calls rmorie, which this package never depends on.
* A new vignette, *Causal effects with cross-fitted double machine learning*: `plr_crossfit()`
  recovers a known effect on simulated data and, on the NSW job-training experiment (LaLonde 1986;
  Dehejia and Wahba 1999, hosted as `nsw_dw/*` on data.rmorie.com), moves the observational
  estimate against the PSID controls from -15,205 to 618 dollars, against the experimental 1,794.

## Fixes from the CRAN stress test of b617a3f

* **A key next to punctuation never reaches a model.** A question with no verb is refused as one
  when a key-shaped run appears anywhere in it (`KEY?`, `"my key is KEY, thanks?"`, a key after a
  no-break or zero-width space), not only as a whole word: those went to the first provider, the
  wrong one for the key. Function names (`bricklayer_json_base64url_dec`) are not taken for keys. A
  verb typo with a `?` apart (`rmbl "doctr ?"`), a leading ideographic space or quotes is a near
  miss, named in "did you mean"; a CJK question ending in a full-width question mark is asked.
* **`survey_design()`**: genuine replicates passed by name are no longer refused when two of them
  are identical (216 of 2,400 test designs); JKn replicates of other strata, which equal the weight
  on a stratum subset, are accepted (every replicate equal to the weight is refused); a stratified
  bootstrap whose replicates equal the weight by chance, and post-stratified or calibrated
  jackknife subsets, are no longer warned about; a replicate a tenth of the weight's scale (a
  normalised weight, a multiplier column) is said, as one ten times it was. Rows reordered and then
  a column dropped or one cell edited are refused (the SE was silently wrong); a row-name reset is
  accepted. The Rd says how to read the survey package's own bootstrap replicates.
* **Interrupts and time limits**: every POST polls for Ctrl-C and `setTimeLimit()`, not only when
  the wait label shows (Wayback `/save`, OCSP, the data-key check, `ask` with stderr redirected);
  a Ctrl-C in `bricklayer_fetch()` or `wayback_snapshot_url_native()` is raised at once instead of
  running the Wayback lookups on to their timeouts; the Wayback back-off without a terminal sleeps
  a second at a time, so a time limit ends it.
* **`bricklayer_data_load()`** applies the option `rmoriebricklayer.maxcsvbytes` (1 GiB by
  default) on both of its read paths.
* **CSV reader parity with `read.csv()`**: a line of NUL bytes is skipped; integers with leading
  zeros past ten characters are integers; a header of `""` alone is a table of no columns; blanks
  outside a quoted header name are dropped; quotes after a closing quote are read as quotes; a header
  past a million fields is refused before it is held.
* **Language models**: the last turn after the help-page lookups keeps the tools declared with
  calls turned off and rides on the last tool result (it was a second user turn with no tools,
  which Anthropic refuses); an SSE error event, or a 200 that carries an error, is said with its
  message; the saved-answer key includes a digest of the API key in use.
* **C and C++**: argument errors and large allocations inside the entry points unwind through the
  barrier, so their buffers are freed (`sen_slopes()` leaked 858 MB at a failed allocation; small
  leaks in the HTTP header, gini, merkle, XMSS and BLAKE2b paths); a NaN or huge `timeout` is no
  longer cast to an integer (undefined behaviour).
* **Statistics**: `hurwitz_zeta(s, 1/2)` is `(2^s - 1) zeta(s)`, exact beside the trivial zeros; a
  point at -1e300 no longer collapses the Knox and hot-spot grids.
* **Arguments**: a seed that is not one whole number is refused in words wherever a function seeds
  the RNG, and seeds now run from -2147483647 to 2^53 - 1: past `set.seed()`'s 32 bits the
  Mersenne-Twister state is built from the seed (each seed its own stream; seeds in the integer
  range give the stream they always did); `lagrangian_particles(normals =)` must be a function returning `n` finite numbers; a plot
  method given something its class's function did not make says so.
* **SIU parsing** of a long run of letters is linear (a 1 MB `<p>AAAA...` took four minutes; now
  2.4 s).
* The courts vignette's case-mix paragraph is computed from its table; a test no longer writes
  `Rplots.pdf` into the tests directory; a complex-NA test follows R's own coercion (it failed on
  R 4.3); the heaviest signature-vector blocks (about 100 s) are skipped on CRAN and run in CI.

## Live progress for long work

* **`bricklayer_progress(label, total)`**, exported: the animated bar of `bricklayer_download()`
  for any loop, as an object with `$update(done, info)`, `$tick(by, info)`, `$wait(seconds)` and
  `$done(summary)`. It follows the download bar's rule (drawn while a person watches a terminal:
  an interactive session, or a command line that sets `options(morie.progress = TRUE)`; a line at
  each tenth when stderr is not a terminal; nothing with `options(morie.quiet = TRUE)` or
  `quiet = TRUE`). Nothing is drawn for the first 0.75 s, so a fast call never flashes a bar; a
  bar inside another function's running bar stays silent, so nested work shows the outer loop; an
  update is a stored value when quiet and a throttled frame when drawing. With `total = 0` it is a
  spinner with the time so far and the current stage. `on.exit(p$done(), add = TRUE)` clears the
  line when the work fails or is interrupted.
* **Wired into the long-running functions**: the bootstrap of `exposure_response_plr()`, the folds
  of `plr_crossfit()`, the permutations of `knox_test()` and `step_change()`, the controls of
  `capsule_falsify()`, the repetitions of `capsule_power()`, the splits of `drift_calibrate()`,
  the columns of `capsule_drift()`, `profile_columns()`, `correlation_table()` and
  `top_correlations()`, the stages of `mahalanobis_outliers()`, the EM iterations of
  `mcar_test()` and of `core_hawkes_fit(method = "em")`, the replicate checks of
  `survey_design()`, the steps of `lagrangian_particles()` and `advection_diffusion_2d()`, the
  receptors of `gaussian_plume()`, `gaussian_puff()` and `plume_field()`, the files of
  `capsule_bundle()` and `capsule_bundle_verify()`, the columns and the writing of
  `make_synthetic_csv()`, the packages of `capture_dependencies()`, the groups and exact p-values
  of `analyse_table()` and `yoy_pvalues()`, and long vectors in `benford_test()` and
  `distinct_sketch()` (read in blocks of a million; the counts and registers are those of one
  pass).
* **A spinner for long native calls**: XMSS key generation and signing (`pqc_keygen()`, a few
  seconds at the default height, about a minute at 14), `derive_key()`, the native routes of
  `core_hawkes_fit()` (with the stage: first start, second start) and every network request
  (`bricklayer_fetch()`, the portal resolvers, `wayback_snapshot_url_native()`, revocation and
  service lookups, model lists) show a turning spinner with the label and the seconds so far,
  drawn by the compiled layer each time the call polls for a Ctrl-C, from 0.75 s on, on a
  terminal only. The XMSS tree now polls every 32 leaves (it was every 1,024, once in a whole
  default key).
* **Live progress in the IDE consoles, and one look for it.** Whether a console can redraw a
  line is now decided as the cli package decides it, no longer by `isatty(stderr())` alone,
  which is `FALSE` in the RStudio and Positron consoles, so most R users saw only the line at
  each tenth. Bars, spinners and the native spinner now animate in a terminal, the RStudio
  console (and its build and render panes), the Positron console, R.app and RKWard. They draw
  on stdout in the RStudio and Positron consoles, which print stderr in their error colour,
  and on stderr elsewhere. Colours follow the console (24-bit, 256, 8, or none; `NO_COLOR`,
  `R_CLI_NUM_COLORS`, `RSTUDIO_CONSOLE_COLOR`), and so does the width. They never animate
  inside knitr, an R Markdown notebook chunk or a Jupyter kernel, which get the plain lines.
  `options(rmoriebricklayer.dynamic, rmoriebricklayer.numcol, rmoriebricklayer.unicode,
  rmoriebricklayer.width)`, cli's options and `R_CLI_DYNAMIC` override the detection. The bar
  shows the percent, the count (or the bytes), the rate, the time so far and, once the rate
  has settled, the time left; it fits the console's width and cuts the label or stage with an
  ellipsis. When the work ends, a green check, the label, the result and the time replace the
  bar; a red cross replaces it when the function that made the bar failed or was interrupted.
  `bricklayer_download()` shows the same cross. The native spinner of long compiled calls draws
  the same line, turns only on R's main thread, ends with a check or a cross, and in a log
  writes a line at 0.75 s, one every ten seconds after it and one at the end.

## Integrity scheme 2

New Merkle trees and chain entries are hashed under scheme 2 and record it; anything sealed by
0.5.12 or earlier (no scheme recorded) still verifies under its old rules, with a warning that it
was sealed with the weaker scheme.

* **Merkle trees separate leaves from interior nodes** (RFC 6962): a leaf is SHA-256 of the byte
  0x00 and the chunk, a node SHA-256 of 0x01 and its two children. Under scheme 1 the 64 bytes
  of two sibling digests verified as a "leaf" with the shorter proof from their parent.
  `merkle_root()`, `merkle_leaves()` and `merkle_proof()` take `scheme` (2 by default; 1
  recomputes a root pinned by an earlier version), `merkle_proof()` records it in the proof, and
  `merkle_verify()` reads it from there or takes `scheme = 2` to refuse a proof without one.
  Roots therefore differ from those of 0.5.12 for the same chunks. `capsule_report()` records
  `merkle_scheme` beside `merkle_root`.
* **Chain entries cover their label.** `chain_append()` records `scheme = 2` and links
  `"v2|<prev>|<payload>|<label>"`, so editing a label breaks the chain; under scheme 1 it went
  undetected.
* **Chain payloads no longer depend on the R version.** A non-string entry is digested over
  `serialize(version = 2)` with the four header bytes naming the writer's R version zeroed, so
  the same entry gives the same payload on every R version and for any R object.

## Fixes

* `core_bootstrap_mean()` draws its resamples with Lemire's unbiased bounded draw on
  `mt19937_64`, as the reservoir sampler already does, instead of `std::uniform_int_distribution`,
  whose algorithm differs between libstdc++ and libc++: the same seed now gives the same resamples
  on Linux, Windows and macOS (the Linux and Windows results are unchanged). The means are summed
  in `long double`, so they still agree only to rounding between x86 and arm64.

* Every `conf_level` goes through one check, with one message: `trend_test()`, `count_trend()`,
  `analyse_table()` and `survey_compare()` returned `NaN` intervals for a level outside (0, 1);
  `case_flow()`, `life_table()`, `disposition_mix()`, `clearance_decomposition()`, `rate()`,
  `share()`, `rate_change()`, `yoy()`, `stay_summary()` and `survey_estimate()` checked it in
  four different wordings. The interval helpers behind them refuse it too.
* `manifest_recompute()` reports a statistic that returns `NA`, `NaN` or `Inf` as `DIFFER`
  (or `MATCH` when the record holds the identical value) instead of failing with "missing value
  where TRUE/FALSE needed". `record()` refuses a vector `observed` or `expected` in words; it
  failed with R's "'length = 2' in coercion to 'logical(1)'".
* `stock_flow()` refuses a `t` that is neither one value nor one per period (it was recycled in
  silence) and a `period` of the wrong length; `adp()`, `alos()`, `admissions()`,
  `adp_from_counts()` and `stock_flow()`'s `per` refuse several values where one is meant (only
  the first was used).
* `profile_columns()` leaves infinite values out of the mean, spread, range, quantiles and
  outlier count; they are still counted in `n_infinite`.
* `core_hawkes_fit()` with the exponential kernel also runs from a second start and keeps the
  better optimum: from one start it could stop with the decay on its bound at a worse likelihood
  and still report `converged = TRUE`.
* `reservoir_indices()` and `reservoir_sample()` draw with Lemire's unbiased method on the raw
  64-bit output of `std::mt19937_64` instead of `std::uniform_int_distribution`, whose algorithm
  differs between C++ libraries: a seed now gives the same sample on Linux, macOS and Windows,
  and samples differ from those of 0.5.12. A seed that is `NA`, negative or fractional, and a
  fractional `n` or `k`, are refused (an `NA` seed was undefined behaviour in the cast).
* `core_bootstrap_mean()` refuses an `NA`, negative or fractional seed and a fractional `B`
  (undefined behaviour in the casts), in R and in the compiled entry point; the compiled entry
  point of `core_uniforms()` now checks its seed too (its R function already did).
* `core_normal_logpdf()` refuses a vector `mean` or `sd` and a non-positive `sd`, as
  `core_normal_pdf()` does; `core_gamma_cdf(a, Inf)` is 1, as `pgamma()`; `core_trimmed_mean()`
  and `core_winsorized_mean()` refuse a `trim` outside [0, 0.5] instead of returning `NaN`.
* `analyse_table()` warns that `rounding` and `suppression_limit` apply only to counts when
  `units` is not `"count"`; they were ignored in silence.
* Errors about a provenance list name `load_provenance()`; they named a `read_provenance()`
  that does not exist.
* `capture_dependencies()` gives `NA`, not `""`, as the library of a package that is not
  installed, and the library of an installed one is the directory the package is in (it was its
  parent).
* `print()` of a hot-spot persistence result names each period with its own count of tied
  cells ("period 2: 100 cells tied"); periods and counts were pasted into one list.
* `install_cli()` refuses an empty or malformed `name`; an empty one printed "Installed ;" and
  failed with "subscript out of bounds".
* `yoy_markdown()` right-aligns every numeric column; the value and previous value were left
  aligned.
* With `direction = "neutral"`, `print()`, `yoy_html()`, `yoy_pdf()` and `plot()` of a change
  table draw rises and falls in the neutral colour; `print()`, `yoy_html()` and `yoy_pdf()`
  painted a rise in the bad colour, and `plot()` in the good one.
* A malformed certificate, CRL, OCSP response or time-stamp token is an error without the call
  (`cert_parse()` errors read "Error in cert_parse(...)").
* Rd: `[0, 1]` in four help pages was read by roxygen as a link (an `R CMD check` warning for
  `hotspot_persistence`).
* The "is thinking" line of a language-model call is drawn where the console says, on stdout in
  the RStudio and Positron consoles; it went to stderr, which they show in the error colour.

# rmoriebricklayer 0.5.12

The 0.5.11 stress round (commit a5a4d10) and the review of this release's own branch (head
6e80794, 2026-10-12): the findings of both fixed, each fix applied to its siblings, and the
claims the earlier fixes overstated corrected.

## Language models: bring your own key; the hosted tier is retired

* **Any major provider, or your own model.** `bricklayer_llm_ask()` takes, in order, an endpoint
  of your own, then the first provider whose key is set, then Ollama. Sixteen providers are
  built in (`bricklayer_llm_providers()`): OpenAI, Anthropic, Google Gemini, OpenRouter, Groq,
  Together AI, Fireworks AI, DeepSeek, Mistral, xAI, Cerebras, Perplexity, Hugging Face,
  OpenCode Zen, Cohere and NVIDIA, each from its usual key variable or a key saved privately
  with `rmbl config set <provider>.key`. Anthropic's Messages API and Gemini's
  `generateContent` are spoken natively, tool calls included; the others are
  OpenAI-compatible. `route = "anthropic"` (or any provider id) takes one route only;
  `bricklayer_llm_models(route)` and `rmbl models --route` list a route's models;
  `rmbl config setup` asks for a provider, its key and its model.
* **The model knows the packages.** With `docs = TRUE` (the default) the model is given the
  name, arguments and title of every function of the installed MORIE packages
  (rmoriebricklayer, and rmoriedata and rmorie when present), read from their installed help,
  and five read-only tools: a search over every help page, a help page, its examples, the
  dataset list and a vignette. A model that does not take tools gets the matching pages in its
  prompt. How much goes into the prompt follows the model's context: everything for a
  provider's model or an Ollama cloud model, the functions nearest the question for a model
  Ollama runs on this machine; `MORIE_LLM_CONTEXT` overrides. `agent_bundle()` asks the same
  way (its `backend` argument is now `route`).
* `bricklayer_llm_route_info()` says which route would answer, without sending anything;
  `bricklayer_llm_chat()` sends a whole conversation as it is (no help, no tools), for chat
  loops in the other MORIE packages. rmorie's help, thousands of pages, is searched by the
  tools, and only its functions nearest the question are listed for the model.
* **The hosted MORIE tier is retired.** No route, setting or model list for it remains;
  `route = "hosted"` says so, and a saved `hosted` route falls back to the automatic order
  with a one-time message. Signing in (`rmbl login`) is for the curated tables at
  data.rmorie.com only, and `rmbl doctor` reports the data key.
* A model the route does not have is named as such, with the number it has; a refused key is
  said as such, and the key never appears in an error.
* **The data key is checked and issued by the data service.** `login --token` asks
  data.rmorie.com (`/v1/whoami`) whether it knows the key before storing it; the sign-in address
  is the services document's `data.auth_url`, then its `llm.auth_url` for documents signed earlier.
  A document may now leave out the `llm` block. A restricted table (the ICPSR studies, NCVS 38604,
  the a2aj case law) refused with 403 says to accept the terms at https://data.rmorie.com/terms.
* API calls no longer end a reply that is slow to start: a model that thinks before answering
  is not cut off by the 30-second low-speed limit.

* **It shows that it is working.** While a model thinks, the terminal shows a turning spinner,
  "<model> is thinking" and the seconds so far, then how many help pages it has read; the line
  is wiped when the answer comes. Only for a person at a terminal (never in a script, a log or
  `options(morie.quiet = TRUE)`); Ctrl-C now ends a long wait for a model.
* **A repeated question is answered at once.** The answer to the same question (spacing
  aside; case counts), on the same route, model, packages and versions, is kept on this
  machine for 30 days and comes back without asking the model: `rmbl ask` says so, `--fresh`
  (R: `fresh = TRUE`) asks again. Owner-only files under `tools::R_user_dir()`, at most 200,
  outdated ones removed on each save, the first save in a session says where; only for a
  person at a terminal (the command line with the terminal on stdin and stdout) or an
  interactive session, never from a script, a pipeline or a check; `MORIE_LLM_CACHE=off`
  turns it off. Nothing is hosted.
* **Servers can reuse the instructions.** The instructions a model gets are the same for every
  question (the functions picked for a question travel with the question), so the prompt
  caches of Ollama, OpenAI, DeepSeek and Gemini apply, and long instructions are marked for
  Anthropic's cache: a faster, cheaper first answer on every route.
* **Better retrieval.** The help search matches inflected words ("emissions" finds
  "emission", "testing" finds "test") and leaves out question words; the closest help pages go
  with every question, to large models too; and the model is told never to say the packages
  lack something before it has searched under other words.
* **`bricklayer_explain_error()` and `rmbl explain-error "MESSAGE"`**: where an error or warning
  of rmoriebricklayer, rmoriedata or rmorie comes from, without a model or the network. Every
  message is read from the packages' own code (stop(), warning(), usage errors; sprintf() and
  paste() parts as wildcards), matched exactly or by its words, and traced to the exported
  functions that reach it, whose help pages say what they expect. With no argument, the last
  error of the session. rmorie's 18,000 messages are read once per installed version and kept
  beside the saved answers.
* **Ollama has to be running.** `rmbl doctor` and the help now say to start it (`ollama serve`,
  the Ollama app, or its system service) when nothing answers at its address.
## Network and statistics stress tests of 5e1dce5 (2026-10-14)

* **A typo, a file name or a key is never sent to a model.** A line with no verb is asked only when
  it plainly is a question: the first argument is the question itself (two words or more, or
  ending in `?`), it is not a verb or one or two letters from one, it holds no path, line break or
  key-shaped word, and anything after it is an option `ask` takes (`rmbl "how?" --fresh` works).
  `rmbl explain-eror "object 'x' not found"`, `rmbl "My Documents/urls.txt"` and `rmbl conifg set
  anthropic.key "$(cat key.txt)"` with a CRLF key file went to the model before, the key with
  them. An unknown verb now names the nearest one (`did you mean ...`); one that looks like a key
  is not printed back.
* **A Ctrl-C during a GET is raised** (`rmbl models` exited 0 with "did not answer", a Wayback run
  polled on past its time limit): the transfer's callback records the interrupt it takes. The
  plain GET behind the Wayback lookups takes Ctrl-C too.
* **The key prompt finds `stty` and `sh` on PATH** without a child process (only `/bin` and
  `/usr/bin` were looked in, so on a NixOS-style layout the key was echoed), runs the `sh` it
  found, and takes a Ctrl-C already pending before the read starts. `config setup` prints its
  key explanation as part of the prompt the shell shows once echo is off.
* **A settings or cache folder left open by an earlier version is made owner-only**, not only a
  new one. `config set` writes only the settings it changes into `llm.json` (a full rewrite cut
  floats to 4 digits, unboxed arrays, renamed a `""` key and rounded integers past 2^53).
  Answers are kept only with a person at a terminal or in a GUI session (`R --interactive < file`
  kept them). The note after the tool-call cap goes with the last tool result (Anthropic and
  Gemini got two user turns in a row).
* **The native CSV reader**: a table that would decompress past 512 MiB is read the streamed way
  (`read.csv(gzfile())`; a 2.6 MB file of blank lines got the process killed for memory), and a
  `.csv.gz` that is plain text is read as such. As `read.csv()` reads them: unquoted header names
  are trimmed (`" Operational_Capacity "` came out `X.Operational_Capacity.`), CR and CRLF inside
  quotes are newlines, a line holding only `""` is blank, blanks before a quote and text after
  one are kept. A quote inside an unquoted field (`ab"c`, where `read.csv()` swallows the rest of
  the file) is refused in words. Deliberate differences from `read.csv()`: a UTF-8 byte-order mark
  is not part of the first name, and extra fields and an unclosed quote are refused. Short rows
  are filled, as `read.csv()` fills them, unless filling makes more cells than the text has bytes
  plus ten million (a 2,000-column header over short lines made 4e8 cells from a few megabytes).
  A Ctrl-C while a table is inflated or split is looked for every million fields or blank lines
  (by rows it waited 53 s on a wide table), the inflating goes in 16 MiB steps on its second pass
  too, and either comes back as R's interrupt, not an ordinary error.
* **Survey replicates**: what is refused, what is said and what cannot be told apart is in
  `?survey_design`. New: a copy of the weight within 1 percent on every row is refused under JK1,
  JKn and BRR; warnings for more replicates equal to the weight than a bootstrap draws (judged
  against the m!/m^m chance for the PSUs read from the replicates), a near copy under the
  bootstrap or Fay, a JK or BRR replicate that leaves no row out and is no rescaled weight, and
  replicates totalling on average under a tenth or over ten times the weight (`$repweights`
  multipliers), and a replicate over ten times the weight on a typical row (`api99` among the
  bootstrap replicates raised the SE 21% in silence). 360 generated genuine sets: 0 refused, 0 warned; survey's JK1 and bootstrap
  subsets of apiclus1: no warning. A second column with the id's name and other values is refused
  (it was kept); the weight beside the replicates under its own name is recognised within 1e-12.
* **Reordered survey data is caught by a key per row**, computed every time: rows reordered within
  strata or PSUs are refused now, a permuted outcome (a permutation test) is not a reorder, and a
  million rows of ten columns take 0.6 s per estimate (the per-column digests took 88 s). Only the
  columns the design uses must have unique names.
* **`hurwitz_zeta()` with a whole `q`** beside the trivial zeros goes through Riemann's zeta and the
  finite sum (5.4e-8 relative at q = 2 near s = -30); 144 points against mpmath at the exact
  doubles agree to 3e-15.
* **`knox_test()`** compares incidents too far out for the distance band to index with every
  other one directly (one outlier at 1e300, or a band of 1e-300, refused the whole test), and
  measures distances in band units. **`hotspot_persistence()`**: a period whose hot set a tie
  emptied has no overlap to report (it showed 0); the courts vignette says how ties work.
* **Refusals in words**: a `NULL`, empty or missing column name in `plr_crossfit()`,
  `exposure_response_plr()`, `exposure_concentration_index()` and `pollution_burden_by_area()`.
  `missingness_summary()` and `duplicate_rows()` take data with duplicate column names, which is
  the messy data they exist to inspect.
* **Tests**: none reaches a real host without `RMBL_LIVE_TESTS=1` (`online_now()`, the LinkingTo
  fallback, an `invalid.invalid` lookup, a route test's status lookup); the tibble reorder test
  resets row names as a tibble does (it passed on builds that never compared values).

## CI on 84840ac, and asking in other words (2026-10-14)

* **`aye`, `tellme`, or just the question.** `rmbl aye "..."`, `rmbl tellme "..."` and
  `rmbl "how do I weight a survey?"` all ask, with every option `ask` takes. A first word that is
  no verb is asked when a word holds a space or the last word ends in `?`. A lone unknown word is
  still an unknown verb, so a typo is never sent to a model.
* **Ctrl-C reaching the top level exits 130.** The launchers (`inst/bin/rmbl`,
  `inst/bin/rmoriebricklayer`, and what `install_cli()` writes) catch an interrupt that gets past
  the command's own handler, which exited 1 with "Execution halted" on the release legs of
  84840ac. A Ctrl-C in the first tenth of a second, while R itself starts and before the package
  loads, is R's own and still exits 1.
* **A Ctrl-C just before a key prompt is no longer lost.** The prompt looked for `sh` and `stty`
  with `Sys.which()`, which runs a child process. R ignores Ctrl-C while a child runs, so the
  interrupt killed only the child. The prompt then fell back to a read that ignores Ctrl-C, and
  the command waited. They are now found on disk, with no child process.
* **The otis-mrp bundle runs again.** `analysis.R` sources the package's argument checks
  (`aaa_input_guards.R`, `lib_helpers.R`) before the package files it loads on its own. Those
  files call `.rmbl_arg()` since the `match.arg` sweep, and the bundle check failed with "could
  not find function".
* **Keys from earlier logins.** A key a pre-0.5.12 login saved for `https://llm.rmorie.com` (the
  retired gateway, the same issuer and key store) goes to the signed document's data address
  again, instead of asking to sign in anew. Any other address stays bound to itself.
* **A spent time budget stops the help lookups.** When no time was left for another turn, the
  error was taken for a model that cannot use tools, and the question went out again without
  them, with a full timeout. It now stops with the time-budget message.
* **Schema check warning.** The misspelling check on structural invariants compared names of two
  lengths and warned "longer object length is not a multiple of shorter object length".
* **Coverage.** The coverage job runs the live transport checks, as the check job does.
* **This package names no package built on it.** `bricklayer_llm_ask()` and
  `bricklayer_explain_error()` read this package's help and messages by default; before, they
  also loaded rmoriedata and rmorie when those were installed. A package built on this one passes
  its own (`packages =`), and its command line sets `RMBL_PACKAGES` (comma-separated) for the
  verbs it hands over, as `RMBL_PROG` names the command.
* **explain-error announces a long read by its size.** The "Reading the messages ..." note
  came only when rmorie was among the packages; it now comes for any set of namespaces over
  5,000 objects (rmorie has 18,709, this package about 1,200).
* **No warnings in the build or the tests.** The checked writer's message buffer holds a whole
  path (gcc `-Wformat-truncation`); two unused Keccak helpers and an unused constant are gone
  (clang `-Wunused`). The tests expect the warnings they provoke: the stability bound, the
  exhausted XMSS key and the record switched off.

## Re-test of 46de6a9 (2026-10-14)

* **Survey replicates: an explicit contract, nothing guessed.** The totals and constancy checks
  added in 46de6a9 refused 13.5% of 1,320 genuine sets (a dominant PSU; a jackknife replicate
  constant on a subset) while a data column still rode along with replicates taken from the
  analysis file. Every value heuristic is gone. The replicates are exactly the columns you give,
  by name or as the object passed: a column of `data` passed under its own name is a replicate
  because it was asked for. What is refused is exact: the full-sample weight itself (for a
  jackknife, BRR or Fay design; a bootstrap replicate that draws every PSU once is the weight,
  legitimately), the id's values, the row numbers, a column of `data` passed under another name,
  and a name collision with the weight or the id whose values differ. A genuine replicate that
  shares the id's name is kept. A reordered tibble with a vector weight is caught: the design
  keeps a digest of every column as given and sorted, and the same values in another order are a
  reorder whatever the row names say; a column changed afterwards is not.
* **The prompt goes once.** A model call is never retried: a POST that timed out may have been
  read by the provider. A conversation with help-page lookups that runs out of its time budget
  says so instead of shrinking the last call to five seconds; past the cap of 12 tool calls in a
  turn the rest are dropped from the turn and the model told, rather than 3,000 "not run" rows
  being sent back. `rmbl models` and any GET take Ctrl-C; so does a gzip decompression.
* **The answer cache** makes a stored answer printable on the way out (an answer cached by an
  earlier build carried a clipboard write), writes through a fresh temporary name, treats a file
  that is not a record as a miss, and takes `MORIE_LLM_CACHE` as `off`, `0`, `false`, `no`,
  `none` or `disabled` (spaces aside), and the option as those words too. A script run at a
  terminal with stdin and stdout on it is a person watching; `</dev/null`, a pipe or a redirect
  is not. Model names from a server and `config` values print clean. The saved settings
  directory is created 0700 whatever the umask.
* **Wayback.** The daily-limit default message is what `wayback_retry()` looks for, so a URL
  captured already today is left for tomorrow; the per-run resubmission cap counts only
  resubmissions since the last capture that got through, so a slow archive finishes.
* **Tests** run in a fresh, empty config directory with the developer's saved keys, hosted key
  and `MORIE_DATA_URL` unset; every test that reaches the live internet needs
  `RMBL_LIVE_TESTS=1`.
* Pre-0.5.12 logins stored the address of the retired model tier; such a key is withheld with a
  message, so those users log in once more.
* **The curated tables load in a fraction of the time.** A gzip-compressed CSV is decompressed by
  the checked reader, split into columns in C and typed as `read.csv()` types it (plain integers,
  decimals and `TRUE`/`FALSE`/`T`/`F` decided from the bytes, everything else by
  `type.convert()`): the same table, byte for byte of meaning, in a fifth of the time (a
  million-row table: 1.3 s where `read.csv()` took 6.6 s). A record with more fields than the
  header and a quote that never closes are refused in words.
* **Hot spots made by a tie are not hot spots.** When the cells tied with the k-th busiest would
  make more than twice k cells hot, the tied group is left out (`tied_out` says how many, and
  printing says so); `cell = 0.1` on even counts no longer calls 100 of 100 cells hot.
* **Refusals in words, every time.** A choice argument given a wrong value says what it must be
  and what it got (`match.arg()`'s "'arg' should be one of" named neither); a data frame with an
  empty or repeated column name is refused before anything is looked up; `drift_psi(bins = )`
  takes one whole number up to a million; `clearance_decomposition(base = )` takes one of the two
  values of `compare` and keeps its type; an estimate without a standard error plots without a
  warning.
* **`hurwitz_zeta()` beside the trivial zeros** takes the distance to the nearest integer exactly
  before `sinpi()` (R's `sinpi(x)` beside `x = -1` is `sin(pi * x)`, which loses the digits of a
  value of order that distance: up to 8.9% at -2 +/- 1e-15, on glibc as on other libms); the test
  compares against mpmath at the exact doubles. A whole `q` of 2 or more beside the trivial zeros
  goes through Riemann's zeta and the finite sum (5.4e-8 relative at q = 2 near s = -30 before). **`crime_density()`** keeps every incident on a map that runs past 180 degrees (the
  points are in the grid's frame). `hotspot_persistence()` says when it drops an incident without
  a location or period. A planar cell index past 2^53 is refused rather than merged with its
  neighbours. A burden at rate 0 or population 0 draws. The age-specific rate message in
  `pollution_burden()` and its siblings no longer says such a rate cannot exist.

## Review of 29a55d8 (the stress round of 2026-10-14)

* **Ctrl-C while a model thinks is a Ctrl-C (G1).** The wait consumed the interrupt and the
  POST came back as a dropped connection, which was retried: the prompt went to the provider
  twice and the answer printed. The interrupted POST now raises the interrupt (exit 130 from
  `rmbl ask`, one request at the provider), and nothing is retried after one.
* **A stored key stays bound to its address (G2, G3).** With the model tier off the comparison
  had no address to compare against, so a key saved for another server went to the data
  service, and a new login recorded no address. The address is now the data service's when the
  document names no model tier; `login --token` checks the key at the signed document's address
  only, never at `MORIE_DATA_URL`.
* **The answer cache is for a person at a terminal (G4).** It wrote from `rmbl ask` in a script
  or a pipeline (the command line always turns the progress option on); now it needs the
  terminal on stdin and stdout, or an interactive session. The question keeps its case (`df$X`
  is not `df$x`), the stored question is checked on a hit, and the first save in a session says
  where the answers go.
* **Wayback status-reply throttles stop (G5).** A throttle in the status reply requeued the URL
  and the next job id reset the strike count: one URL made 174 POSTs. Strikes now reset only
  when a capture gets through, the eighth stops the run, a run resubmits at most as many times
  as it has URLs, the target page's own 503 and bandwidth errors fail that URL rather than count
  as account throttles, and a job id that reads like an error code is refused.
* **The XMSS lock is released whatever happens (G6).** The lock is taken and the locked call run
  in one C frame whose cleanup is the release (`R_ExecWithCleanup`): an `on.exit()` handler is
  R code an interrupt can cut short before its `.Call`, and 73 to 95 locks per 5,000 interrupts
  stayed held; 5,000 interrupts now leave none. A record whose name starts with another's keeps
  its temporary files.
* **Survey replicates (F1, F2, E9 residual).** Replicate columns taken out of the analysis file
  itself (`replicates = d[paste0("bw", 1:24)]`) are accepted again; a genuine replicate under the
  weight's name is refused, not dropped; a replicate that sums to less than a fifth or more than
  five times the full weights (a row number, an id, survey's multiplier matrix) or is the same
  for every row (a constant) is refused. `survey_compare(ref = 2023)` takes the number as the
  label.
* **`crime_density()` near the antimeridian (F4)** draws: grid nodes past 180 degrees keep their
  continued values when wrapping would put them out of order. `hurwitz_zeta()` past the double
  range is a signed infinity, not NaN. (This entry first called F5 a reference artefact; it was a
  real loss of digits, fixed in the re-test above.) `knox_test()` drops an incident without a location or time and says so, as its
  siblings do; `hotspot_persistence()` says when it drops (0, 0); `max_pairs = TRUE` is refused;
  the planar cell key writes whole numbers in full.
* **Model and provider text is made printable (L1)**: answers, model lists, the spinner's model
  name and error bodies lose screen-clearing, title and clipboard escapes. **Tool calls keep the
  text-only contract (L2)**: a nameless call is answered in words, the dataset filter is plain
  text, at most 12 calls are run per turn, an empty reply is "returned no text", never `""`.
  **A key with a line break is refused (L3)** in R and in C, so it never becomes a second request
  header. **The settings file is written through a fresh temporary name (L5)**. A conversation
  with help-page lookups gets three times one call's timeout (L6). The progress frame takes a
  NaN time. An assumption with `ok = NA` prints as NA. The age-specific rate message no longer
  says such a rate cannot exist. The live transport tests need `RMBL_LIVE_TESTS=1` exactly, and
  the model tests clear a developer's own endpoint and keys (L4).

## Review of e57fed5 (the stress round of 2026-10-13)

* **The spinner frame stays in its table (E1).** `rmbl_progress_spinner()`, a public C-callable,
  cast `t * 10` to an integer, which overflowed past about 9e17 (nanoseconds) and read another
  table's string; the frame is now taken in double, so every time maps to a frame. A bar wider
  than an `int` is clamped before the cast (E13).
* **The gzip reader's memory is bounded by its output (E8).** It inflates twice: once into a 64 kB
  scratch buffer to check everything and count the output (a bomb is refused having held 64 kB),
  then straight into the result, allocated once at its size; one zlib state serves every member,
  and more than 100,000 members are refused. A million empty members (20 MB) had taken 3.56 GB, a
  4 MB bomb 3.19 GB; both are now refused within a few megabytes. Each kind of damage is named (a
  bad CRC, a length trailer that does not match, a damaged header, no gzip magic), not all as a
  CRC failure. A 600 MB file under a 3.5 GB memory limit is read; under a smaller one the report
  says the memory ran out, as an error report.
* **Bulk archiving keeps to archive.org's limits (E7).** Captures start no faster than
  `per_minute` (default 6; the SPN2 documentation allows an account 7). A slow-down reply, as a
  429 or inside an HTTP 200 (`error:user-session-limit` and the other throttle codes the SPN2
  documentation lists), holds every submission back for its `Retry-After` or 15 s doubling to
  10 minutes, and sends the URL again; eight in a row stop the run. The account's daily cap stops
  submitting. Status checks that fail back off the same way. `max_captures` (default 1000) caps
  a run; the rest are left for the next. Before, 300 URLs went out in 32 s.
* **No test captures a page on archive.org (E6).** The live test runs only with
  `RMBL_LIVE_TESTS=1`, and never posts to `/save`.
* **Wayback reply handling.** A job id that is not a short token (`TRUE` looped for ever, `123`
  stopped the run) is a failure; two URLs given one id each keep their entry; a timestamp that is
  not one is recorded as missing, and a results file holding one reads back; a reply over 64 kB is
  not parsed. An API call takes its answer only from the host it asked: after a redirect to
  another host, that host's JSON had been recorded as archive.org's; the transport now refuses
  such a redirect for API calls (Save Page Now, model endpoints, OCSP), and reports `Retry-After`.
  An http page is looked up (it is a parameter of the lookup, never fetched); a key file other
  users can read is warned about; a URL with a control or bidirectional character is refused, and
  printed results show only what the URLs show. A run that is stopped records the captures it had
  started, and the next run polls them instead of sending them again; a missing folder for the
  results file is refused before anything is sent. `wayback_retry()` looks failures up one a
  second and leaves a daily limit hit today for tomorrow.
* **Survey replicate columns are only replicates (E9).** A column holding the full-sample weight,
  the id or any other column of `data` is refused by name (the full weight given as a vector and
  the id had been averaged in: a standard error of 0.2599 or 0.2704 where it is 0.2836), BRR and
  Fay replicates must come in a Hadamard order, and a matrix with a class of its own is read as
  the matrix. The full weight named in `weights` and shipped beside the replicates is dropped by
  name, as before.
* **Wilson at 0% and 100% (E2).** The interval is Wilson's at the respondents (the design effect is
  0/0 there): 40 of 40 gives [0.912, 1], where it collapsed to [1, 1]. The logit interval takes the
  same at the ends. The degrees-of-freedom factor of the modified effective sample size is
  `(t_(n-1) / t_df)^2`, as the SAS documentation gives it (it was `(z / t_df)^2`; the same for a
  large n).
* **Survey design.** New `type = "jkn"` with `rscales` (JKn weights passed as JK1 overstated the
  standard error by 37%); the replicate design's degrees of freedom are the rank of the replicate
  weight matrix less one, as the survey package computes them (twelve BRR half-samples of an
  eight-stratum design have 8, not 11), or `degf`. `survey_estimate()` checks the data is the
  design's rows in the design's order (reordered data gave a wrong answer silently). A design with
  no stratum of two PSUs has no variance to report: the standard error is missing and flagged,
  not zero; a certainty stratum is not a lonely PSU; the flag for a domain whose weights are all
  zero says so. `by = character(0)`, `conf_level = NA` and a two-element `ref` are refused in
  words.
* **(0, 0) is "no location" in Knox too (E3).** `knox_test()` drops it, as `crime_density()` and
  `hotspot_persistence()` do (twenty such rows had made the closest cell 163 observed against 33
  expected). The three share one way onto the plane: points across the antimeridian are one place,
  and an extent past 2,000 km is said. `crime_density()` refuses a bandwidth longer than half the
  earth's circumference and says when one is ten times the incidents' spread; `knox_test()` checks
  `max_pairs`; hot spots made by ties are counted (`tied_in`) and said when they are most of the
  active cells.
* **One rate band for every pollution entry point (E4).** `pollution_burden()`,
  `pollution_burden_by_area()` and `mortality_displaced()` take a rate per person-year between
  1e-5 and 0.1 (1 to 10,000 per 100,000), `rare_outcome = TRUE` below and `high_rate = TRUE` above,
  as `verify_pollution()` now does on its rate per 100,000 (0.5 had been taken as a rate per
  person-year: 14,634 deaths from a million people). `verify_pollution()` passes the switches on
  to its stages. `pollution_report_text()` refuses a list that only looks like a report.
* **The bundled TPS data, one row per occurrence (E5).** Rebuilt from the Service's Break and Enter
  file by `data-raw/tps_break_enter_d14_2024.R`: 508 occurrences (the Service publishes one row per
  offence record; five occurrences have two, kept as `offence_records`), every one located. The
  old file's all-NA row was a subsetting artefact (an NA year in a logical index), and it carried
  one 2025 occurrence and missed one of 2024. The vignette's Knox ratio is computed from the data.
  The lone 2026 court row is gone. Sources and licences: `inst/COPYRIGHTS`, and the DESCRIPTION's
  `Copyright` field.
* **The manifest (E10).** An empty dataset list does not replace a cached manifest that lists
  tables, and a table the manifest does not list is not loaded unverified.
* **The XMSS record (E11, E12).** Temporary files carry their record's name, and a writer removes
  only its own record's (with three records in one folder, 117 of 900 writes had failed); the lock
  is taken with interrupts held off and released by a handler registered before it. A record of
  100,000 keys is read without the regular-expression passes: a whole signature took 0.5 s on an
  x86-64 laptop (the documentation said 0.7 s; the reviewer measured 1.4-1.8 s).
* **The 02a38be leftovers.** `hurwitz_zeta()` uses the functional equation for Riemann's zeta at
  negative s (full relative accuracy beside the trivial zeros) and no longer overflows a Bernoulli
  polynomial whose value is finite (`hurwitz_zeta(-4, 5e61)`). The terminal prompt is printed by
  the shell that reads it, once its trap is set and the echo is off, and a read that never
  finished is an interrupt (a Ctrl-C in the first milliseconds had exited 2; a key typed at once
  was echoed). `bricklayer_llm_status()` and `rmbl models` say a key is stored for another address
  instead of "not logged in". An empty schema is said to check nothing (and refused by
  `apply_schema_validation()`); only a one-letter slip or a swap in a structural invariant's name is
  taken for a misspelling (`min_data_cols` is a field of its own). Printing keeps the zero-width
  joiner and non-joiner, variation selectors and flag tag sequences. `drift_calibrate(n = 0)` is
  refused. The README counts the 8 entry points written in plain C. The exposure CSV reader no
  longer runs two regular expressions over the whole text to see whether it is blank.

## Retrying a bulk Wayback run

* **New: `wayback_retry()` and `rmbl wayback --retry FILE.jsonl`.** Reads the results file of an
  earlier `wayback_save()` run and retries every URL whose latest result is a failure: each is
  first looked up in the Wayback Machine and recorded as `existing` when a capture is already
  there (the daily limit's refusals, pages captured by another run), the rest are captured again
  into the same file, and pages their source no longer has (HTTP 404 or 410) are left alone unless
  `include_gone = TRUE` (`--include-gone`). Returns the whole run as it now stands, with the
  retry's counts.

## Timing tests

* **dudect: both classes are written the same way.** The 150-tick ML-KEM compare-and-select was
  flagged intermittently on GitHub's x86 runners (|t| up to 30). Its compiled code is branch-free
  with a fixed memory access pattern; the difference came from the harness, which copied the
  fixed class into place and generated the random class in place, leaving the slots in different
  cache states. Random inputs now go through the same copy, and a new target,
  `mlkem768_fo_select_validity`, compares a pool ciphertext against itself and against another,
  both made by the same code, so only the match bit differs. Every target shows no evidence of
  leakage locally (x86-64, max |t| 2.8) and the positive control is still flagged.

## Hot spots over time, and rates over time

* **New: `hotspot_persistence()`.** Incidents counted in grid cells per period: the share of
  places holding half the incidents (the law of crime concentration), the hot cells (the busiest
  `top` share, ties included) and their share of incidents, the Jaccard overlap of each period's
  hot spots with the previous period's, and per cell how many periods it was hot. Plot: the
  concentration and persistence over time and a map of the cells by how often they were hot.
* **`plot()` of a rate takes `period =`.** A rate by group and period draws one panel per group,
  the rate as a line over its interval band on a shared scale.

## Complex survey estimation

* **New: `survey_design()`, `survey_estimate()`, `survey_compare()`.** Design-based means,
  totals, proportions and ratios, overall and by domain, with variances from replicate weights
  (Statistics Canada's bootstrap, mean bootstrap, jackknife, BRR, Fay's BRR) or from Taylor
  linearization over strata and PSUs with a finite population correction and a choice for
  single-PSU strata. Domain estimates keep the whole design. Replicate totals are computed in C
  straight from the data frame's columns (CSUS 2023: 36,180 respondents by 1,000 mean bootstrap
  weights in about 1.6 s). Proportions default to the modified Wilson interval of SAS PROC
  SURVEYFREQ that Health Canada's published CSUS intervals use. Estimates, standard errors and
  intervals match the survey package to machine precision for linearized, JK1, bootstrap and Fay
  designs, domain estimates and contrasts; CSUS 2023 lifetime cannabis use reproduces Health
  Infobase's published percentages from the public-use file. Domains under 30 respondents are
  flagged (Health Canada's suppression rule), not withheld. Plots for both.

## A new look for every plot

* **One theme across all 33 plot methods.** The plot region is a tinted panel crossed by white
  major and minor grid lines (`bricklayer_plot_options(panel = )`, `NA` for none), with no box and
  softer axes. Intervals are translucent bands with haloed points; lines carry a soft fill to the
  axis and a labelled, emphasised last value; bars sit on the panel with a sheen along the
  leading edge and their value at the end; the sequential palette runs deeper for fields and
  heatmaps. Drift calibration draws each column's false-alarm rate with its exact interval over
  the splits (an all-zero result drew an empty frame). Axis titles, row notes and panel keys
  shrink and wrap to fit; labels that fit are not cut.
* **Every plot is in the examples.** `?plot-methods` draws every class, the courts and crime
  plots on the shipped data included, and `vignette("plotting-results")` gains a courts and crime
  section.

## Small bases compute

* **`yoy()` and `rate_change()` report every percent change.** A small base no longer withholds
  the percent: 2 to 20 reports +900% with its exact rate-ratio interval, and a change of a few
  tenths of a percent off a base of 15 is reported as such. `min_base` now defaults to 0 for every
  unit and, when set, only adds a "small base" note; `min_count` likewise notes without hiding.
  Only a zero base has no percent change. Printed, CSV, Markdown and HTML footers say "note" where
  they said "percent withheld", and the period-over-period plot draws small-base percentages.
* **`compute_footprint()` no longer reads 0 g for fast work.** A call shorter than the elapsed
  clock's resolution had 0 s of wall time and so 0 energy; the duration is now at least the CPU
  time spread over the cores. `plot()` of a footprint shows CPU, memory and total in one unit
  chosen to fit (kg to micrograms), and says "Too short to measure" when even CPU time is 0.

## Archiving in bulk, and animated progress

* **New: `wayback_save()` and `rmbl wayback FILE`.** Save many URLs in the Wayback Machine with
  archive.org's Save Page Now 2 API and your account's S3-like keys (`IA_S3_ACCESS_KEY` and
  `IA_S3_SECRET_KEY`, or `..._FILE` naming files that hold them). Several captures run in flight
  at once through the package's own checked libcurl transport; a page captured recently is kept
  (`within`), a page captured already today is recorded with that capture, rate limits and
  server errors back off and retry, a refused key stops the run, and each result is written to a
  JSON Lines file as it lands so an interrupted run carries on where it stopped. Run live with
  real keys on the ledger's sources before release.
* **Animated progress, drawn in C.** `src/rmbl_progress.c` renders the bar (a shimmer along the
  filled part, a head that fills in eighths and pulses while work goes on, a spinner) in 24-bit
  colour or plain, block characters or ASCII; the R side eases it to each new value at up to 12
  frames a second, only on a terminal a person is watching, with milestone lines elsewhere and
  `NO_COLOR` honoured. `bricklayer_download()` and `wayback_save()` use it, and
  `rmbl_progress_bar()` / `rmbl_progress_spinner()` are C callables for the MORIE packages that
  link to this one.

## Courts and police-reported crime

* **New: `case_flow()`, `life_table()`, `disposition_mix()`, `clearance_decomposition()`,
  `crime_density()` and `knox_test()`**, each with print and plot methods. The clearance rate
  with exact intervals and months to clear the inventory; the actuarial life table for banded
  times (equal to Kaplan-Meier at the band edges without censoring, checked against
  `survival::survfit()`); outcome shares with Goodman's simultaneous intervals and
  Cochran-Armitage trends; Kitagawa's decomposition of a change in a clearance rate into rate
  and case-mix effects with a Mantel-Haenszel rate ratio and a Simpson's-paradox verdict (on the
  Court's own figures, 2014 to 2022: the aggregate fell while the rate at a fixed mix rose);
  binned Gaussian kernel density with highest-density regions (checked against
  `MASS::kde2d()`); and the Knox test with exact expected counts (checked against a full
  enumeration of permutations).
* **Real data in `inst/extdata`** (`?justice-data`): Ontario Court of Justice monthly flow and
  time to disposition (2024-2026), outcomes, offence groups and courts by calendar year
  2012-2025, each reconciled to the published provincial totals; Toronto Police Service break
  and enter occurrences in division D14, 2024. Vignette `courts-and-crime`.
* **Plots fit the device.** Multi-panel plots choose rows and columns from the device (one row
  squeezed four panels into a 3.5-inch device); y-axis titles sit outside the tick labels
  actually drawn (a five-digit tick label overprinted the title at line 3) or are left off when
  there is no room; the key under lettered panels is measured at the size it is drawn
  (`strwidth()` scales by `par("cex")`, which a panel grid lowers, and `mtext()` does not, so
  the key ran off the device); the plume and particle titles fit their panel.
* `apply_schema_validation()` checks for a data frame before the schema.

## Review of 02a38be (the sixth pass)

* **`hurwitz_zeta()` is accurate below s = 1.** The Euler-Maclaurin shift added in the fifth
  pass summed |s| + 20 terms and cancelled them against a small result: every digit was lost
  below s = -5 (zeta(-11) came back as 5.4, zeta(-15) as -2.3e7, where 52a8883 had returned NA),
  and near s = -5 only six digits were right. Now s <= -5 uses Hurwitz's Fourier formula on
  (0, 1] (exact zeros at the even negative integers, zeta(-200, 2) = -1 exactly), -5 < s < 1
  Hermite's integral on [1, 2), the integer s in (-5, 0] the Bernoulli polynomial, and any other
  q is shifted into range by sums that do not cancel. Checked against mpmath at 40-60 digits over
  112 points: the largest relative error is 1.9e-13. A tiny q keeps its own term
  (`hurwitz_zeta(0.5, 1e-20)` was `Inf`). The fifth pass's test compared against a reference
  that was wrong in the fifth digit with an absolute tolerance that accepted 0; it is relative now.
* **A truncated or damaged compressed exposure file is refused.** R's `gzfile()` returns what a
  cut gzip or bzip2 file decodes to, with no error and no warning, so half a file was read as a
  whole one (status ok). gzip is now inflated in C with zlib, every member's CRC-32 and length
  checked (several members, as `gzip -c a b` and `data.table::fwrite()` write, are read whole);
  a bzip2 file must end with its end-of-stream marker; an xz decoder warning is an error. The
  decompressed size is capped while it is read (`options(rmoriebricklayer.maxcsvbytes)`,
  1 GiB): a few megabytes of gzip no longer grow to gigabytes before anything is refused. zlib is
  now a system requirement (it ships with R's own build dependencies).
* **A baseline rate below one per 100,000 needs `rare_outcome = TRUE`, whatever its unit.** The
  check ran only when `baseline_rate_per` was missing, so a wrapper or `do.call()` that always
  passes it turned 0.008 per person-year into 0.008 per 100,000 and a burden 100,000 times too
  small, with status ok. The check is on the converted rate now, and below 1e-6 per 100,000 no
  rate is accepted (`baseline_rate_per = 1e300` was).
* **A NAPS `value` column with `"<2"` is refused, as an `exposure` column is.** The value was
  converted before the text check and counted as a row with no measurement (prevalence 1.0
  instead of 0.4).
* **`--force` belongs to `config reset` alone.** `config set own.key --force` stored "--force" as
  the key. `config show`, `help`, `get` and `unset` refuse extra arguments, and arguments after a
  bare `--` are refused by every verb but `ask` and `bundle` (`functions -- a b` listed everything).
* **A FIFO, device or directory at the legacy record path is refused at once.** The migration
  read it with `file.exists()` only, so a FIFO blocked signing for good while the lock was held.
* **Parallel manifest refreshes no longer collide**: each writes its own temporary file (one
  shared name let them delete each other's, 11 of 12 workers failed). A reply that is not a
  manifest (`{}`, an error object, a `datasets` that is not a list of tables) is refused and the
  cached copy kept.
* **A cached table is deleted only when it fails a known digest.** Offline, a stale manifest that
  lists the table without a digest now loads it, as the live manifest does; with no manifest at
  all the cached table is refused but kept for the next run, where it is checked again before
  use (it was deleted, and had to be downloaded again).
* **Ctrl-C at a prompt exits 130 where `/bin/sh` is dash** (Debian, Ubuntu). The shell's trap ran,
  but `system2()` reported no exit status for it, so the interrupt came back as an empty line and
  a usage error (exit 2, or 1 at the e-mail code prompt). The trap now also prints a marker R
  recognises. The fifth pass's test mocked `system2()`; this one runs the launcher in a real
  terminal (util-linux `script`), under dash and bash.
* The CSV reader: a UTF-32 file with a byte-order mark is read (its decoding error quoted a
  kilobyte of the file); a row with more or fewer fields than the header is refused by line number
  (it wrapped into an extra row); a column name given twice is refused (the second column was
  ignored); a numeric exposure column is no longer turned back into text to be searched (15 of the
  24 s on a 102 MB file).
* A `next_index` past 2^31 - 1 is the damaged-key error, not a raw `NA` comparison error.
* `apply_schema_validation()` needs something to validate against: `NULL`, an empty list or a
  provenance without `schema` (a typo such as `scheme`) is an error, not `TRUE`. A schema field a
  few letters from a known one (`expected_colums`, `min_data_row`) is fatal with a "did you mean";
  other unknown fields are said. `expected_dtypes`, the name the provenance files use, is checked
  as `expected_types` (the OTIS file's column types never were), and a factor matches a character
  column.
* A hosted key saved for another address is said once per session, and `ask` with no route says
  the key is stored for the other address instead of "no key stored".
* `data list` removes every default-ignorable code point (soft hyphen, U+034F, Hangul fillers,
  U+180E, the byte-order mark, the interlinear annotation marks, tag characters), not only the
  bidirectional and zero-width ones.
* The credentials file is read as bytes: a NUL byte, a file that is not UTF-8 and a file over 1 MB
  are refused with a plain reason (a NUL silently cut the file, a 10 MB file took minutes).
* A temporary record file left by a writer that died mid-write is removed at the next write.
* `verify_pollution()` refuses a non-numeric scalar such as `as.raw(25)`; the dispersion solvers
  refuse `n_steps` past 2^31 - 1 even with `max_work = Inf`, and a particle grid larger than
  `max_work` cells; `plot()` of what is not a pollution report says so.
* Plots fit small devices: the margins are scaled to the figure at the text size in use and the
  labels are cut by their measured width (`cex = 2` on a 2-3 inch device failed, and a 4-inch plot
  cut labels it had room for); the bar for missing values never takes a real level's name.
* The record documentation gives the measured cost: about 0.7 s per signature at 100,000 keys.
* The lock wait is interruptible (one non-blocking attempt at a time, the wait in R); releasing
  descriptor 0, 1 or 2 is refused; the record writer checks the written size and flushes the
  directory after the rename (the fifth pass's NEWS said "size-checked" before it was); a lock
  file owned by another user is named as such, not as a read-only directory. The barrier
  generator registers the five entry points written in plain C directly (they throw no C++
  exception) instead of stopping, and the README counts both kinds.
* Tests: a test compared a mean with its own formula and now checks two independent predictions.

## Review of 52a8883 (the fifth pass over the branch)

* **A tampered cached table no longer loads when the manifest cannot be fetched at all.** The
  fourth pass covered only the retry: when the cached manifest was over a day old (or absent)
  and the server was down, the first manifest read failed, that failure counted as "no digest",
  and the tampered file loaded and stayed. Now a manifest that cannot be had is never "no
  digest": the check falls back on the last manifest on disk, however old, and with no copy at
  all the table cannot be verified and is not kept. A refreshed manifest is written beside the
  cached one and moved over it only once it parses, so a failed refresh no longer destroys the
  copy the fallback needs. The fourth pass's NEWS item below overstated what it covered.
* **The XMSS used-index record is locked by the operating system.** The lock directory of the
  fourth pass was taken over after 60 s by check-then-delete, which let two signers hold it at
  once and sign one index (reproduced 1 time in 60), and spun for ever on a lock it could not
  delete. The record is now locked with `flock()` (Unix) or `LockFileEx()` (Windows) on
  `xmss_used_indices.txt.flock`, in C: the kernel releases the lock when the process ends, so a
  crashed session leaves nothing to take over, and the 10 s wait is bounded and draws no random
  numbers (lock contention no longer moves `set.seed()` streams). A read-only directory is said
  as such.
* **The record is written in C and checked.** It is written to a temporary file, flushed to the
  disk with `fsync()`, size-checked and only then renamed over the old one; a full disk stops
  the signature and leaves the old record in place (it emptied the record before).
* **A key's record id is a fingerprint of its secret seed**, not the `root` field it carries: a
  stale copy whose `root` was upper-cased, padded or swapped is still the same key, and a
  signature whose `root` does not match the seeds is withheld (its index stays retired).
* **A key built from given seeds is not registered at birth**: it may have signed elsewhere, so
  it signs from index 0 only after `xmss_register_key()` vouches for it.
* **The record of the releases before 0.5.12 is migrated**: `xmss_index.json` next to the record
  is read and merged, and kept as `xmss_index.json.migrated` once the new record is written; an
  unreadable one stops signing. Lines of the 0.5.12 pre-release format are read as well.
* **The record path must be an absolute path to a regular file** (or to one that does not exist
  yet): `/dev/null`, a directory, `"none"`, `"-"` and relative paths are refused.
* `xmss_advance()` without `message` accepts a signature index only up to the highest index the
  record shows this key has used here, so an edited index cannot burn the leaves in between; a
  bundle is accepted as documented; a damaged `next_index` is a clear error.
  `xmss_forget_used_indices(key)` takes the signing key (the record is keyed by its seed).
  The help says what to do in CI or a container with a fresh home directory.
* `verify_pollution()` reads gzip, bzip2 and xz CSVs again (the byte reader of the fourth pass
  refused them as "NUL bytes"), decodes UTF-16 without a byte-order mark, and stops on a parse
  problem such as an unbalanced quote instead of returning the rows before it (status ok with
  mean 12.2 instead of 36). The decoded text is parsed from a file, not a text connection, so a
  large file is no longer several times slower, and it is held once rather than with a
  file-sized logical vector beside it.
* A baseline rate below one per 100,000 is accepted when its unit is given
  (`baseline_rate_per = 1e5` for a rare outcome, `1` for a rate per person-year); the note now
  says which to pass. Exposure cells that are text rather than numbers (`"<2"`) stop the run and
  are named, since dropping them biased the mean and the prevalence; empty and missing cells are
  dropped and the report prints how many. `exposure_csv` with `demo = TRUE`, a population above
  ten billion and an empty income column are handled with a reason.
* `credentials.json` is validated with the real parser before it is edited, and the edited text
  is parsed again before it is written: bare words, missing or trailing commas, trailing
  garbage and duplicate keys are refused instead of written into (every later read failed).
* `rmbl config setup` reads the MORIE key and your own API key without echo, and the echo is
  switched off and on by the shell child itself, so Ctrl-C cannot leave the terminal silent;
  Ctrl-C at any prompt exits 130. A key given on the command line (`login --token KEY`) is
  warned about. `data list`, `data pull`, `functions`, `config path` and `config setup` refuse
  extra arguments. `config reset` moves a readable file only with `--force`, never overwrites an
  earlier backup, and is listed in the help.
* `hurwitz_zeta()` sums a negative `q` in closed form: no cap, no billion-term sum, and none of
  the cancellation that returned 0 for `s = 5` at `q = -99999.5`; below `s = 1` it returns the
  analytic continuation (`hurwitz_zeta(0.5, 0.5)` is -0.6049).
* `lagrangian_particles()` has the `max_work` cap of `advection_diffusion_2d()` (particles x
  steps); `gaussian_plume()` and `gaussian_puff()` take at most 1,000 lid image pairs; a step
  count above 2^31 no longer fails in the report title.
* Bar labels cut to fit stay distinct (a number tells apart levels the cut made identical), a
  real level named `(missing)` keeps its name, and labels are cut to the device's width.
* `print()` of an attestation or bundle written by 0.5.9 to 7703a04 warns that it carries the
  signer's private key. `fips_verify_mu()` returns `FALSE` for an edited verifier key instead of
  an error, and a scheme given as two names is refused. `hill_tail_index(x_min = factor(...))`,
  `cramers_v(bias_correct = "abc")`, `cramers_v(min_expected = NA)`, `plot_funnel()` with a bad
  `levels` or `target` and `pollution_report_text()` of a non-report are refused with a reason.

## Review of fcdce03 (the fourth pass over the branch)

* **A tampered cached table loaded when the manifest could not be re-read.** The digest retry
  of the second pass re-fetched the manifest on a mismatch and, when that fetch failed, had no
  digest left to compare and accepted the file. The digest the check started with now stands
  unless a refreshed manifest is actually fetched and lists another; a failed refresh refuses
  the file. A manifest digest that is a list, or not a digest, refuses the file and removes it
  from the cache; a `MORIE_DATA_URL` that is not the document's address is named in the error.
* **The XMSS used-index record is locked and fails closed.** Every reservation runs under an
  exclusive lock directory next to the record, so two processes signing with copies of one key
  cannot both take an index (and two keys cannot wipe each other's lines); the record is one
  line per key (`xmss_used_indices.txt`), written through a unique temporary name whose rename
  is checked; a malformed line stops signing until the file is repaired or removed; the off
  switch warns on every signature; a value that is not a path (`TRUE`, `"0"`) is refused.
  `pqc_keygen()` registers every key in the record at birth, so a key the record does not
  know that claims never to have signed is refused (a deleted record, or a key from another
  machine) until `xmss_register_key()` vouches for it or `xmss_advance()` carries it forward.
  `xmss_advance()` checks the index against the key's height, verifies the signature when the
  message is given, never advances below what the record knows, accepts an attestation, bundle
  or recode manifest, and warns when the key is exhausted; `xmss_forget_used_indices()` can
  forget one key and is documented as removing the protection. Examples and vignettes point
  the record at a temporary file so checks and builds leave the configuration directory alone.
* `verify_pollution()` reads the exposure CSV whole: UTF-16 is decoded, a UTF-8 BOM dropped, a
  file that is not UTF-8 read as Latin-1 and said, NUL bytes refused (the fifth pass found a
  quote that swallowed the rest of the file still did, and that compressed files were refused). `population = NULL` or `baseline_rate =
  NULL` is an error report with a reason. `baseline_rate` may be zero (a measured zero);
  a value between 0 and 1 per 100,000 fails the assumption and suggests `baseline_rate_per =
  1`, the new argument for a rate quoted per person-year.
* `hurwitz_zeta()` refuses `q` below -1e6 instead of allocating the recurrence's billion terms;
  logical `q`, `x_min`, `fractions` and non-logical `discrete`/`approx` are refused.
* `advection_diffusion_2d()` has one cap for every run, `max_work` (100 million cell updates,
  `Inf` lifts it): the same physics costs the same whether the caller sub-steps it or the
  scheme does, so a run cannot be refused in one spelling and accepted in another.
* `credentials.json` is edited as text: login and logout touch only this package's three
  members and every other byte (another package's floats, large integers, empty keys,
  non-ASCII text) stays as it was.
* The review's section-1 leftovers: `print()` and `capsule_bundle_read()` warn about an old
  object that carries `key_state`; an edited verifier key object is "not verified", not an
  error; `verify_pollution()` refuses scalars beside a CSV or the demo, refuses list and
  complex scalars, says how many non-numeric exposure rows it dropped and skips the equity
  index when fewer than two rows have an income; bar labels over 28 characters are cut so a
  long level cannot make the figure margins too large; own-endpoint settings without an
  address are said when the hosted tier is used instead; `OLLAMA_BASE_URL` in the environment
  wins over a saved address; `own.key` and `own.url` in one call keep the key; `rmbl config
  reset` moves an unreadable settings file aside and `doctor` reports the file instead of
  failing; verbs that take no arguments refuse extra ones and Ctrl-C exits 130; U+061C,
  U+2028 and U+2029 are stripped from listings; a `schema` that is not a list is a clear
  error; a stack within half a kelvin of the air has zero rise (no cliff); Anguilla uses
  Antigua's grid and Jersey and Guernsey France's; Ukraine's 2022 row is named as such; a
  note line is never under a tenth of an inch and one inline note no longer shrinks every
  page of a `yoy_pdf()`.
* Tests: a tampered cache with a failed refresh, two processes signing with one key, a
  malformed and a deleted record, the off switch, Latin-1 and UTF-16 CSVs, the large negative
  `q`, the cap's consistency, and the credentials bytes.

## Review of 7703a04 (the second pass over the branch)

* **The XMSS signature object carried the private key too.** The attestation fix of the first
  pass stripped `key_state` from attestations only; `capsule_sign()` itself still returned the
  advanced key, with `sk_seed` and `sk_prf`, inside every XMSS signature, so every shared
  signature, bundle JSON file, chain and report made with XMSS from 0.5.9 to 7703a04 handed
  out the private key, and anyone holding one could attest or sign anything under the
  victim's root. The signature object now carries no key material of any scheme, and the next
  key state is `xmss_advance(key, signature)` (new, exported, with `xmss_forget_used_indices()`).
  **Treat every XMSS key whose signature, attestation, bundle or report left your machine
  under 0.5.9 to 7703a04 as compromised: generate a new key and sign again.** A test checks
  that no signature, attestation, bundle, JSON or serialisation of any scheme contains
  private-key bytes.
* XMSS index reuse across sessions: the registry of used indices now persists in
  `xmss_index.json` under `tools::R_user_dir("rmoriebricklayer", "config")` (the directory CRAN
  policy sets aside for a package's own configuration), so a key reloaded from disk with a
  stale `next_index` is refused on the same machine, in a fresh session too. The option
  `rmoriebricklayer.xmssidxfile` or `RMBL_XMSS_INDEX_FILE` moves the file; `""` or `FALSE`
  turns it off. The record does not travel with the key: save the advanced key after every
  signature, as before.
* `verify_pollution()` with a mean but no prevalence (or the reverse) is an error report (exit
  2), not "ok, 0 cases": the first pass's zero-exposure fix had made the omitted input a
  silent zero. Both scalar defaults are now `NULL`. A per-100,000 `baseline_rate` below 0.01
  fails an assumption as a per-person rate typed in the wrong box; an exposure above
  10,000 ug/m3 fails the range assumption instead of throwing; a UTF-8 BOM, a negative row and
  a date are handled; the attributable-fraction step is inside the report contract.
* The French SIU resolver keeps a line break that ends a stripped boilerplate sentence (the
  first pass replaced it with a space and glued the next roster line, or the next section
  header, onto it); the property test now inserts the sentence at the line end too.
* `advection_diffusion_2d()` caps only runs that sub-stepping inflates: a large stable run is
  the caller's to wait for. The number in the message is formatted properly and the advice is
  correct (a smaller dt lowers the sub-step count). `lagrangian_particles()` refuses more than
  100 million particles; `gaussian_puff()` warns about receptors below ground or above the lid.
* `plot()` of a frequency table with a missing level draws it as "(missing)" instead of failing
  on the margin (broken since 0.5.11).
* HMAC `capsule_verify()` answers FALSE to any edited `signature` field; `capsule_check_attestation()`
  accepts a public-key object as `key_expected` (for XMSS the root and seed both) and reports a
  missing digest instead of throwing.
* Language models: a local Ollama selected by model or key at the default address that does not
  answer is announced before the hosted tier is used; a setting of the wrong type in `llm.json`
  (`route: 5`, an array, `true`, `""`) is an error, not "auto"; a credentials file without
  `hosted_base_url` (morie writes one) sends the key only to the services document's address;
  `MORIE_DATA_URL` receives the stored key only when it is the document's curated-data address;
  login and logout keep another package's entries byte for byte (the file is edited as text);
  a saved address may not contain whitespace, a fragment or user information.
* `rmbl data list` strips the C1 controls and the bidirectional format characters as bytes, in
  any locale; the help never shows `--token KEY`.
* `bricklayer_data_load()` refuses a manifest digest that is not a digest (a `sha256:` prefix is
  accepted), and a mismatch refreshes the manifest once before calling the file bad, so a table
  rebuilt upstream does not fail until the cached manifest expires.
* `apply_schema_validation()` warns when the provenance list has no `schema` (a typo such as
  `scheme` is no longer silent) and refuses an environment.
* Territory proxies: Saint-Barthélemy and Saint-Martin use Guadeloupe's grid, Wallis and Futuna
  New Caledonia's, Saipan Guam's; Kerguelen the world average. The carbon-intensity note names
  Ukraine (2022) among the older rows.
* `hurwitz_zeta()` handles a non-positive non-integer `q` (8.93 at `q = -0.5` for `s = 2`) and
  refuses a pole; `top_share()` refuses a fraction outside [0, 1] (0 is a share of nothing); `hill_tail_index()` refuses a
  vector `x_min`; `rapl_available()` refuses a non-path; `exposure_concentration_index()` refuses
  an infinite exposure. The masking-cost sentence of the side-channel vignette carries the
  measured 17 ms against 2.4 ms. `crf_pm25()` and `crf_no2()` refuse a logical exposure.
* Third pass over the branch (4b4af29): `top_share(x, 0)` is zero units again and
  `apply_schema_validation(data, NULL)` means nothing to validate (two guards of the second
  pass overshot and turned CI red); `capsule_verify()` checks the shape of a signature before
  the type of the key, so an HMAC signature whose scheme was edited to XMSS is FALSE while a
  real XMSS signature with a string for a key is still an error; a FIPS signature whose recorded
  `context` or `prehash` is not a string is FALSE; `verify_pollution()` with a missing
  `reference` is a report, not a crash; `briggs_plume_rise()` at ambient temperature has zero
  flux and zero rise (a cooler stack is refused); Ctrl-C at the `rmbl login --token` prompt
  interrupts at once (the terminal line is read by a shell child, so the interrupt is not held
  until Enter); the `yoy_pdf()` notes test asserts the page rule instead of comparing a value
  with itself; the dead-stack note on the two gadget pairs says what they hold. Verifying an XMSS
  signature or attestation that still carries `key_state` warns that the key is compromised.

## Review of the 0.5.12 branch

* **An XMSS attestation carried the signer's private key.** `capsule_attest()` embedded the
  whole signature object, and an XMSS signature carries `key_state` (the advanced key, with
  `sk_seed` and `sk_prf`) so the signer can save it. Anyone given such an attestation could
  attest anything under the victim's public key. The key is stripped before the signature is
  embedded (as the recode manifest already did), and a test checks no attestation carries a
  secret. **If you shared an XMSS attestation made by 0.5.11 or earlier, treat that key as
  compromised: generate a new one and re-attest.** HMAC and ML-DSA attestations were never
  affected.
* The composed TVLA kernels never ran: the harness wrote only the fifth argument to the
  stack, so the six-argument kernels faulted before a trace was taken, and the ML-DSA kernel's
  conditional subtraction compiled to a branch, so its trace length varied. Fixed: every
  stack argument is written per the AAPCS, the subtraction is an arithmetic-shift mask, and
  the kernels' glue handles one share per pass with the registers scrubbed between passes
  (the first measurement put 174 and 34 transition-model leaks in that glue, none in a
  gadget). The 0.5.12 note below says what the measurement now shows.
* (Superseded by the second pass above, which keeps the line break.) The French SIU boilerplate
  fix overshot: a stripped sentence was replaced by a line break,
  so boilerplate in the middle of a roster line turned the rest of the line into a line of
  its own and counted 3 officers where every earlier version counted 1 (147 new divergences
  on a 6,017-input fuzz). The sentence is replaced by a space, the two 0.5.11 cases still
  count, and a property test inserts the boilerplate at every position of a line and checks
  the count never moves.
* `verify_pollution(exposure_mean = 0, exposure_prevalence = 1)` and `(25, 0)` are valid
  runs with zero attributable cases again; "no data" is now only a call that passed neither.
  Every pipeline stage runs inside the status contract (a text `income` column, all-zero
  exposure, one row and a per-100,000 `baseline_rate` are reports, not raw errors); a factor
  argument is refused; the assumption log prints `population=1,000,000`.
* The baseline-rate check went into `pollution_burden()` and `pollution_burden_by_area()`
  (800 per 100,000 taken per person-year gave 110 million deaths from a million people), and
  the message says which function takes the per-100,000 form. `crf_no2()` refuses a logical
  or factor `beta_per_10` (TRUE gave a relative risk of e). `n_bootstrap` must be whole.
* `apply_schema_validation()` refuses a list that mixes rules with anything else, a nested
  rule list and a data frame, instead of falling through to the provenance checker and
  passing.
* `advection_diffusion_2d()` caps the work (cells x steps x sub-steps, 10 million, about five seconds) rather
  than the sub-step count: a 5 x 5 grid at 10,001 sub-steps runs in a tenth of a second
  and is allowed, a 201 x 201 grid at 9,999 for 100 steps would take hours and is refused.
  The cap no longer rounds 10,000 up to 10,001. A negative `source` and a logical `u` are
  refused; a receptor below ground or above the mixing lid is warned about; the open
  boundary is documented.
* A configured Ollama server that does not answer is skipped with a message, like one with
  no model pulled, so a prompt that leaves for the hosted tier because a local route failed is
  always said. `credentials.json`
  (shared with morie and rmorie) that does not parse is an error and is never written over;
  `llm.json` that is not a JSON object (`[]`, `"x"`, `5`) is an error too, not a warning
  that fired once and then let a saved route be dropped. The hosted key is tied to the
  address it was saved for; a new `own.url` or `ollama.url` drops the key saved for the old
  server; `ollama.url` refuses a metadata or link-local address when saved.
* `bricklayer_data_load()` checks the manifest's SHA-256 of a cached or downloaded table and
  deletes and refuses one that does not match.
* `fips_verify_mu()` answers FALSE to a length-2 `signature` field (the shared hex helper
  takes one string); an XMSS signature whose `index` or `height` is not a whole number, or
  whose `root`, `height`, `wire` or `randomizer` was removed, is not verified, and a missing
  randomiser is FALSE rather than an error.
* Time zones of territories the carbon table has no row for (Monaco, Vaduz, Andorra, the
  Channel Islands, the Antarctic stations: 41 zones) resolve to the grid of the country they
  draw on or to the world average, with the method saying so; they fell through to the
  locale, which made them the United States under `en_US`.
* `rmbl data list` keeps accents in a C locale (control characters only are stripped);
  `rmbl ask -- --like-this` passes a prompt that starts with `--`; `inst/bin/rmbl` is
  executable in git; the help and the vignette suggest `login --token` with the key pasted
  at the prompt, never on the command line.
* `yoy_pdf()` sizes its notes to the line allowance the pagination made, and many notes go
  on pages of their own (30 notes on a 5-inch page lost notes 24 to 30).
* `plot_lorenz()` sorts a hand-made frame and refuses one that is not a Lorenz curve; an
  all-NA axis no longer breaks the margin computation. `lagrangian_particles(n = 2.7)` and
  `compute_footprint(usage = c(...))` are refused.
* Documentation: masking costs the measured 2.3 to 3.4 times on decapsulation and 7 to 10
  times on signing (the help said 3 to 12 and 13 to 24). `location = "GLOBAL"` is an error
  since the duplicate row went (use `"WORLD"`); the rows older than 2024 include Ukraine
  (2022).

## Cryptography

* Masked ML-KEM decapsulation left the re-encryption shares on the dead stack: `r0/r1`,
  `e10/e11`, `e20/e21`, `u0/u1`, `v0/v1`, the FO-check shares `ok`/`msk` and the masked
  PRF's input and output buffers (whose sum is the coins `G(m' || h)[32..64]`). Summing the
  two halves of `r-hat` recovers `m'` from the public key and ciphertext alone, so a memory
  disclosure anywhere in the process was a decryption oracle for an attacker-chosen
  ciphertext. Every pair the scanner can see is wiped now, with the per-group and per-word
  temporaries; two gadget-internal 32-coefficient pairs (`sec_in_interval`, `sec_b2a`)
  remain on the dead stack (they hold `e2 + eta` and `v' - lo`; `v'` contains Decompress(m'), so
  the second pair also encodes 32 bits of m' for a chosen ciphertext: partial leakage, no key
  recovery shown), and one `dsa_bprime` pair remains on
  clang -O2. The 0.5.10 note that "every share pair is now wiped" was false and is corrected.
* Masked ML-DSA signing wipes the bitsliced share temporaries of every 32-coefficient chunk
  (the low-bits test of `v = w - c s2`, the high bits of `w` and of the hint) as it goes; one
  chunk of `v` survived on some builds and revealed part of `c t0`.
* Two composed TVLA kernels, next to the single gadgets: the ML-KEM decapsulation spine
  (`s*u`, `w = v - su`, `Compress_1`, a Keccak permutation over the message shares) and the
  ML-DSA z path (`y` from Boolean shares, `z = y + c s1`, the norm test, the low-bits test),
  so the hand-over between gadgets is measured too (the harness fix that let them run is
  above; the `tvla` workflow reports the value-model and transition-model t-statistics). The
  dudect gate on a DIT-capable CPU is the no-evidence line (|t| > 4.5 after the tripled
  re-measurement fails), not |t| > 10.
* The ctcheck harness scans the dead stack for share pairs, not only for copies of a secret:
  any two windows whose coefficient-wise sum mod q (or XOR, for Boolean shares) is a known
  value count as a remnant. The ML-KEM case recomputes `r-hat` and `m'` from the message it
  encapsulated and scans for both after the masked decapsulation; this is the check that
  would have caught the gap above.
* `capsule_verify()` answers `FALSE`, not an error, for a signature whose `signature` field
  is not one string, whose `prehash` names no digest, or whose XMSS `auth`, `randomizer` or
  `index` is missing; and an XMSS signature whose own `root`, `height` or `wire` disagrees
  with the key or with its parts no longer verifies (verification used the key's values and
  ignored the edited fields).

## Location, emissions

* Time-zone aliases map to their own country. The table gave every `backward` alias the
  country of the zone it links to, which is wrong whenever the link crosses a border:
  `Iceland` was Ivory Coast (Africa/Abidjan), `Atlantic/Jan_Mayen` Germany,
  `America/Coral_Harbour` Panama, `Africa/Asmera` Kenya, `Pacific/Truk` Papua New Guinea.
  The builder now reads the `#=` annotation of the IANA `backward` file (the zone the alias
  stood for before the merge), takes the target's country only when that target serves a
  single country in `zone1970.tab`, and keeps a reviewed table (`tools/timezone_alias_countries.csv`)
  for the remaining cross-border aliases; the generic zones `CET`, `EET`, `MET`, `WET`,
  `EST`, `HST`, `MST` and the `*ST*DT` names resolve to no country. Rebuilt from tzdata 2026e.
* `detect_location()` warns when `RMBL_LOCATION` names a location the table does not know
  instead of silently moving on to the time zone.
* `compute_footprint()` rejects a fractional `cores`.
* The duplicate `GLOBAL` row (480 gCO2e/kWh from the Green Algorithms file) is gone from
  the carbon-intensity table; `WORLD` (Ember, 458.29) is the world average, and
  `location = "GLOBAL"` is now an error. The documentation
  no longer claims every row is from 2024 or 2025.

## Air pollution and dispersion

* `verify_pollution()` with no exposure data at all (no CSV, no demo, mean and prevalence
  both zero) is an `"error"` report with exit status 2, not a clean run with zero deaths;
  an exposure at or below the reference stays a valid run with zero attributable cases. The
  input contract is enforced in the report rather than as raw R errors: a vector where a
  single number is expected, a missing or negative `reference`, an unknown `outcome`, a
  non-logical `demo`, a directory as `exposure_csv`. The report prints the population as
  `1,000,000`, not `1e+06`. The vignette's failure demo fails again.
* `advection_diffusion_2d()` refuses a run that would need more than 10,000 sub-steps per
  step (`dt = 1e5` on the previous round's reproducer meant 7.8 million sub-steps, with the
  warning deferred until the end) and a wind that overflowed the sub-step count to `NA`;
  `c0` must be a non-negative numeric matrix (a vector gave a field of mass 0) and `source`
  finite.
* `briggs_plume_rise()` rejects temperatures below 150 K, which are Celsius values typed
  where kelvin is expected (111 m of rise instead of 51).
* `lagrangian_particles()` rejects a `grid` whose bounds are reversed or whose cell counts
  are not whole (it gave a negative concentration).
* `crf_pm25()` and `crf_no2()` take exactly one finite `reference_conc` (a vector recycled
  against the exposures; `NA` gave `NA` risks). `attributable_fraction()` rejects a logical
  relative risk. `mortality_displaced()` rejects a baseline rate above 1 (a per-100,000
  figure passed where a per person-year rate is expected gave 23 million deaths from a
  million people).
* `plr_crossfit()` requires a whole `k_folds` (2.7 ran with 2) and numeric columns (a factor
  outcome was analysed by its level codes).
* `exposure_concentration_index()` refuses a factor or character income instead of ranking
  level codes, and negative exposures; `pollution_burden_by_area()` requires numeric
  exposure, population and baseline columns. The index's `n_quintiles` field, a constant
  5, is gone, and the documentation says ties share their average rank.
* `hurwitz_zeta()` takes one `q`.
* `attributable_fraction(rr_lower =, rr_upper =)` carries the relative risk's confidence limits
  through Levin's formula; `crf_pm25()` and `crf_no2()` carry the published 95 percent limits
  of their risks (`rr_lower`, `rr_upper`; NA for the IER forms), and `verify_pollution()`
  reports the fraction's interval.

## Language models

* In the automatic order, a local Ollama server that answers with no model pulled, or a
  configured one that does not answer, is skipped with a message naming the route taken
  instead ("local Ollama at ... has no model pulled; using the hosted MORIE tier"), so a
  prompt never leaves the machine silently.
* A malformed `llm.json` is an error and no setting is written over it: the next
  `config set` used to rewrite the file with only the new value, deleting the saved keys and
  addresses.
* A saved key belongs to the address it was saved with: `MORIE_LLM_BASE_URL=...` or
  `OLLAMA_HOST=...` set for one call receives the environment's key or none, never the key
  saved for another server (the `/api/tags` probe included).
* `rmbl ask --model x --model y ...` is a usage error instead of sending "--model y" in the
  prompt; `--route auto` takes the automatic order over a saved route; an invalid
  `MORIE_LLM_ROUTE` is an error, not silently "auto".
* `config set own.url` runs the same address check as use (a metadata or link-local address
  is refused when saved); `ollama.url` must be http(s).
* A key typed at a terminal prompt is not echoed (where `stty` exists), and the help no
  longer suggests putting the key on the command line.
* `rmbl data list` strips control characters from the manifest before printing.

## Data validation, plots, reports

* `apply_schema_validation()` accepts a rule list and runs it with `validate_rules()` under
  the same stop-on-fatal contract; it used to ignore a rule list in its second argument and
  report a pass, which is what the vignette told readers to do.
* The French SIU resolver: a stripped boilerplate sentence is replaced by a space, so a
  roster entry after it on the same line ("... n'est pas divulgué. AI no 3 A participé") is
  counted again; the 0.5.11 speed rewrite kept the sentence's terminator and lost those
  entries (an unresolved report and a count of 1 instead of 3 on the two cases now pinned
  as tests).
* Plot state is reset when a panel plot errors (the next plot's title showed as "A").
  `plot_funnel()` requires one `area` label per point. An empty `frequency_table()` draws an
  empty page with a title, and `plume_field()` requires increasing coordinates, with
  messages of their own instead of errors from inside the palette or base graphics.
* `yoy_pdf()` paginates on the rows that fit the page height after the title block, the page
  label and the notes (`.yoy_rows_per_page()`, with a test); a 24-inch page planned 98 rows
  where 88 fit and dropped the last rows.
* PBKDF2-HMAC-SHA256 is checked against the RFC 7914 vectors; the `agent_bundle()` help says
  which route the request takes.

## Packaging

* The rOpenSci `pkgcheck` workflow fails when pkgcheck does, and no longer asks for
  `issues: write`.
* Text corrections: 118 registered entry points (not 113); the ACVP PBKDF set is SHA2-224
  only and does not cover PBKDF2-HMAC-SHA256; the plain path's speed advantage is three to
  four times for decapsulation and seven to eleven for signing (not "about five"); a clean
  ctgrind run is evidence for that binary on the inputs run, not a proof for every input;
  the ChipWhisperer firmware is in the separate review archive, not in the package.

# rmoriebricklayer 0.5.11

## Language models: set everything from the shell or R

* A stored hosted key is used even when a local Ollama server is running with no model
  pulled. The automatic route used to stop at that empty server ("local Ollama has no model
  to use"), so a user who had logged in, and whose `doctor` listed every hosted model, could
  not reach any of them. An empty Ollama is now passed over unless `OLLAMA_MODEL` is set or
  the Ollama route is asked for.
* `bricklayer_llm_config()` and `rmbl config` show and save every language-model setting:
  the route `ask` takes (`auto`, `own`, `ollama`, `hosted`) and the address, key and model
  of your own server, of Ollama and of the hosted tier. `rmbl config setup` walks through
  them. Settings are saved in `~/.config/morie/llm.json` (mode 0600); an environment variable
  that is set still wins.
* `rmbl ask --route ROUTE` picks the route for one call.
* `rmbl doctor` ends with the route and model `ask` will use, and how to change it.
* `rmbl help` is a guide: the verbs by area, and `help start`, `help llm`, `help config` and
  `help r` pages with examples. Error messages name the `config` command that fixes them.

## The table list reads left to right

* `rmbl data list` and printing `bricklayer_data_tables()` in R show one line per table:
  the key, the row count and the name, left-aligned and cut to the terminal or console
  width. They went through `print.data.frame`, which right-aligned the names and, once the
  descriptions made a line wider than the terminal, printed every key, then every name,
  then every row count and source as separate blocks. `bricklayer_data_tables()` still
  returns the full data frame (with `source`); only its printing changed.
* A table whose manifest entry has a blank description and source (the otis tables) is
  named by its key instead of by an empty string.
* The smoke suite (`inst/smoke/smoke.R`) prints a failing case's message in full. It cut
  them at 400 characters, which shortened "https://rmorie.com/access" in the no-route
  message of `ask` to "https://rmorie.co".

# rmoriebricklayer 0.5.10

**A version of its own.** The build tagged 0.5.9 on 2026-10-07 (29ff122) and the one
that followed it the same day (dcb3cb9) shared a version number while differing in the
masking defaults, the FIPS 203 section 7.3 key check, `capsule_attest(context = raw)` and
the whole air-pollution feature. The stress test of dcb3cb9 (2026-10-08) asked for a
number that tells them apart, and for the fixes below; this is both.

## Every result draws itself

* `plot()` methods for every result the package returns, on base graphics only: stock and
  flow (`stock_flow()`, one panel per measure), period-over-period change with intervals
  (`yoy()`), rates, shares and rate change, band sensitivity, drift by column
  (`capsule_drift()`, `drift_calibrate()`), Benford digits, power curves, frequencies,
  missingness patterns, region coverage, Mahalanobis outliers, correlations, permutation
  nulls, rounding envelopes, concentration-response curves, burdens, concentration curves,
  the whole `verify_pollution()` report on one page, the footprint with its equivalents,
  concentration fields and particle clouds, count trends, and `analyse_table()` one panel
  at a time. The same customisation everywhere (`main`, `col` or `palette`, `grid`, `...`
  to the base call), `bricklayer_plot_options()` for the session,
  `bricklayer_palette()` with four colour-blind-safe palettes, and every method returns the
  data it drew. `plume_field()` evaluates a plume on a grid; `plot_lorenz()` and
  `plot_funnel()` serve the results that are plain data frames. `vignette("plotting-results")`.
  Titles fit their panel: a title too wide is drawn a step smaller, in a panel set one that
  still does not fit becomes a letter with the key printed under the panels (returned as the
  `panel_key` attribute), long axis titles shrink or wrap, and the left margin is sized from
  the widest tick label so an axis title never overlaps the numbers.
* To carry what the plots need, `exposure_concentration_index()` records its concentration
  curve, `count_trend()` its data, `verify_pollution()` returns class
  `rmbl_pollution_report`, `advection_diffusion_2d()` class `rmbl_field` and
  `lagrangian_particles()` class `rmbl_particles` (all still plain lists underneath).

## Air pollution and dispersion, after the stress test

* `verify_pollution()` applied the PM2.5 counterfactual (5.8) to NO2, overstating NO2
  deaths by 27%; `reference` now defaults per pollutant (NO2 10, PM2.5 5.8), as
  `pollution_burden()` always did.
* Levin's formula was diluted twice when prevalence was below 1: the relative risk was taken
  at the population mean, which already includes the unexposed, and then multiplied by the
  prevalence again. With a CSV or the demo data the exposed are the rows above the
  counterfactual floor: `exposure_mean` is their mean and `exposure_prevalence` their
  share, and the scalar arguments are documented the same way.
* `advection_diffusion_2d()` documented a stability criterion that was false (cfl below 1
  and diffusion number below 1); the explicit upwind-plus-FTCS scheme needs
  `|u dt/dx| + |v dt/dy| + 2 (kx dt/dx^2 + ky dt/dy^2) <= 1`, and a run outside it reached
  10^10 from a unit pulse while reporting itself stable. The bound is returned as
  `stability_number` and `stable`; a call outside it is taken in enough sub-steps of a
  smaller `dt` to satisfy it (reported, with a warning), so the field is a solution over the
  same physical time rather than an explosion.
* Physical guards throughout the dispersion code, on the package's own input helpers:
  emission rates, masses, heights and distances non-negative, wind speed, travel time and
  grid steps positive, `n_images` a whole number (2.5 was truncated silently), the stack
  hotter than the air for Briggs' rise (a cooler stack returned NaN), `x0` and `y0` single
  numbers (a vector doubled `mean_x`), and a warning when the release is above the mixing
  height. `gaussian_plume(q = -100)` returned a negative concentration and `u = 0` returned
  Inf; `gaussian_puff(t = -100)` a negative one; `pg_sigmas(-500)` a negative sigma.
* `attributable_fraction()` returned 2 for RR = -1, 0 for RR = 0 and NaN for RR = Inf, and
  coerced text; it now requires a single finite positive RR and a prevalence in [0, 1].
  `pollution_burden()`, `mortality_displaced()` and the CRFs check their inputs the same
  way; population is kept as a number (8e9 is no longer NA); `"PM2.5"`, `"PM25"` and
  `"pm2.5"` are accepted everywhere.
* A NAPS pull is converted row by row: a file mixing ppb and micrograms per cubic metre no
  longer has every row multiplied by 1.88, a `value` column without a `unit` column is an
  error rather than assumed, and any other unit is an error.
* The concentration index uses mid-ranks, so tied incomes no longer make the index depend on
  the row order (all incomes equal gives exactly 0).
* Citations: 5.8 is the lower bound of the GBD 2019 theoretical minimum risk exposure level,
  not "the WHO 2021 guideline" (that is 5); the NO2 respiratory coefficient is Huangfu and
  Atkinson's RR 1.03 per 10 micrograms per cubic metre; childhood asthma is an incidence
  coefficient (Khreis et al. 2017, OR 1.05 per 4 micrograms per cubic metre, scaled to per
  10) and its burden is reported as incident cases, not deaths. Units are stated on every
  page: `pollution_burden()` takes a rate per person-year, `verify_pollution()` per 100,000.
* Exposure at or below the counterfactual floor is a result (PAF and cases 0), not an
  assumption failure; an infinite or missing input is one (the status contract holds).
* The carbon-intensity table has one Kosovo row (`XK`), documents its provenance and
  licences, and says which values Ember reports as exactly 1000 or above it. The time-zone
  table is rebuilt from the IANA `zone.tab` (one country per zone) plus every alias in
  `backward`, 549 zones: `Europe/Stockholm`, `US/Eastern`, `Asia/Calcutta`,
  `America/Montreal` and about 130 other common names were missing and fell through to
  the locale, so an English (US) locale in Stockholm got the US grid. Every geographic zone
  in `OlsonNames()` now resolves, and the `posix/` and `right/` prefixes are stripped.
  `compute_footprint()` checks every argument before it runs `expr` (a negative
  `memory_gb` no longer gives negative CO2e after the computation has been paid for).

## Cryptography

* Masked ML-KEM decapsulation left both shares of the decrypted message, the hash input
  and K-bar on the dead stack after returning (the plain path guarded them); those share
  pairs were wiped (the re-encryption and comparison shares were not: see 0.5.12).
* Masked ML-DSA signing can be switched off: `capsule_sign(masked = FALSE)`,
  `fips_sign_mu(masked = FALSE)`, and the option `rmoriebricklayer.masked` sets the
  default for all three masked operations in a session (a chain or bundle signs many
  times). The documented cost was understated: masking takes about 3 to 12 times the
  plain time on decapsulation and 13 to 24 times on ML-DSA signing, depending on the CPU
  (4 ms and 26 ms on this package's test machine).
* The TVLA workflow also runs on changes to `rmbl_mlkem_body.h` and `rmbl_mldsa_body.h`,
  where the composed masked algorithms live; the dudect runner re-measures every target the
  first pass puts above the no-evidence line (|t| > 4.5) with three times the samples before
  judging it, because a shared CI runner moves a target by several units of t between passes
  (the arm64 runner put the unmasked ML-KEM decapsulation at 6, 9.7 and 10.6 within an hour,
  for seven ticks in eighty-four thousand; the masked default sits at 1.6). The
  re-measurement decides: above 10 fails, the inconclusive band is reported with its numbers.
  On arm64 the run with PSTATE.DIT set is the gate, as the workflow always said; when the
  runner's CPU has no FEAT_DIT (the GitHub arm64 runners of 2026-10), Arm gives no
  data-independent-timing guarantee for the instructions, so that run is reported with its
  numbers rather than gating: there the unmasked ML-KEM decapsulation shows a steady eight
  ticks in eighty-four thousand between valid and random ciphertexts (|t| 13 at 900k
  samples) that x86-64, Apple silicon (DIT) and the masked default do not show. The ACVP PBKDF sample exercises SHA-224 only; PBKDF2-SHA256 is checked
  against OpenSSL and RFC 6070, and the README now says so.
* `C_rmbl_hash_two_part` (an internal self-test entry) refuses a non-integer or logical
  `split` instead of coercing it.

## Documentation

* The statement that no third-party security audit has been commissioned had been removed
  from `DESCRIPTION`, `SECURITY.md`, the README and seven help pages without one having
  taken place; it is back in all of them, and the masking sentence no longer appears on the
  pages of HQC, XMSS and the DRBG, which are not masked.
* Vignette corrections: no ChipWhisperer firmware ships (the power figures are from the
  emulator); ML-KEM takes a 64-byte seed and HQC v5 a 32-byte one; attestations take a
  signing key, not a shared secret; a bundle's note is `$attestation$note`; the JSON codec
  is R, not C, and is not a fuzz target; Windows randomness is `RtlGenRandom`;
  `capsule_bundle()` pins whole files, the Merkle tree pins parts of one file; there is no
  separate cloud-keys route; `bricklayer_llm_ask()` has no `context` argument; the SIU
  schema column is `name` and an oversize tag is ignored, not an error; the synthetic marker
  is the `.synthetic` sidecar; XMSS is not compared with OpenSSL; verification errors on an
  object that is not a signature; ctgrind is a dynamic check, not a proof; the share
  recombination sentence in the README names what signing publishes.
* `yoy_pdf()` drew rows off the page when `height` was not 8.5: the row height follows the
  page height, as the pagination already did. `rmbl_barrier.cpp` is regenerated from its
  generator. The `www.rmorie.com` move reaches `data_hub.R` and the services fallback, with
  the trailing slashes the site expects. The offline vector subset is 3 MB, not 1.5.

## Pre-existing, found by the stress test

* The French SIU resolver was about 100 times slower than the English one (115
  microseconds per character: a 2 MiB page would have taken four minutes) because its
  legal-sentence filter re-scanned each sentence from every position. Sentences are now
  split once and tested once.
* `hill_tail_index()` on a tail of identical values reported alpha = 25 (the optimiser's
  bound) as reliable; such a tail is "not estimable", and an alpha at either bound is
  flagged unreliable.
* `mahalanobis_outliers(robust = FALSE)` called columns of very different scale (1e160
  against 1) collinear; the classical path standardises by the classical scale first (the
  distance is affine invariant, so nothing else changes).

# rmoriebricklayer 0.5.9

**Standards vectors, at scale**

* The pinned C2SP Wycheproof post-quantum sets (ML-KEM-512/768/1024 key generation,
  encapsulation, decapsulation and key validation; ML-DSA-44/65/87 signing with and without
  seed, and verification) and the NIST ACVP sets (ML-KEM keyGen/encapDecap, ML-DSA
  keyGen/sigGen/sigVer, SLH-DSA keyGen/sigGen/sigVer for all twelve parameter sets, SHA-3,
  SHAKE, HMAC-SHA-256/512, PBKDF2) run in CI on every change to the kernels
  (`.github/workflows/vectors.yml`, `tools/vectors/`): 6,848 tests checked, 0 failures. The
  3,822 not applicable are named with their reason: bit-length SHA-3 messages (the API hashes
  bytes), gigabyte messages, hedged ML-DSA signatures whose randomness the vectors do not
  carry, and PBKDF2 over SHA-224 (the only hash the published ACVP PBKDF sample exercises;
  PBKDF2-SHA256 is checked against OpenSSL and RFC 6070 instead). A subset of 3 MB ships in
  `tests/testthat/vectors` and runs offline through the same runner.
* **Found by the vectors:** `C_rmbl_mlkem_decaps` accepted a decapsulation key whose stored
  H(ek) did not match its own ek; FIPS 203 section 7.3 requires rejecting it, and it is now
  refused.
* Pre-hash: HashML-DSA and HashSLH-DSA take every hash function FIPS 204 and FIPS 205
  approve: `sha224`, `sha384`, `sha512_224`, `sha512_256`, `sha3_224`, `sha3_256`,
  `sha3_384` and `sha3_512` join `sha256`, `sha512`, `shake128` and `shake256`. SHA-224,
  SHA-512/224, SHA-512/256, SHA3-224 and SHA3-384 are new native digests, checked against
  OpenSSL at every block boundary; each OID is bound into the signature, so two digests of
  the same length (SHA-512/224, SHA3-224) never verify for each other.
* SLH-DSA gains its FIPS 205 internal interface (`slh_sign_internal` /
  `slh_verify_internal`, not exported) so the ACVP internal vectors check the core the public
  interface wraps.

## Documentation

* Seventeen new vignettes, each runnable offline: post-quantum signatures (ML-DSA, SLH-DSA,
  XMSS); key encapsulation (ML-KEM, HQC); hashing, keyed digests, key derivation and Merkle
  trees; attestations, signed bundles and tamper-evident chains; side-channel assurance
  (what is verified, how, and what is outside the checks); JSON parsing and exact
  serialisation; the language-model routes and the signed services document; trends and
  change in short count series; small-area rates (expected counts, empirical Bayes, funnel
  limits, Moran's I); Hawkes processes; banded tables and concentration; stock and flow
  (average daily population, length of stay); falsification controls, power curves and
  the E-value; validation rules, inferred schemas and
  synthetic stand-ins; missingness, duplicates, outliers and distinct counts; and the SIU
  director's-report parser; and air pollution from dispersion to health burden, equity and
  the footprint of the computation. The package website groups them by topic.

## Coverage to the last line, and what it turned up

* Every line codecov reported unreached at the previous commit (204 lines in
  53 files) was given a test that reaches it with a real input, removed as a
  guard no input can reach, or is named below as unreached by design. The
  tests run from the OCSP
  responder paths and the DER OID encoder's multi-byte arcs to the JSON
  encoder's class fallbacks, the SIU parser's French team counts, the
  ECDSA verifier's digest-longer-than-order shift, and the CLI's stdin reader.
  Where a branch could not be reached from any input, the guard was removed
  rather than excluded: `expected_counts()` and `sir()` re-checked a sign the
  input guard had already refused, `drift_homogeneity()` tested for a
  condition its earlier check made impossible, `mahalanobis_outliers()`
  re-checked a column count and inverted a matrix it had just made positive
  definite, `clean_column_names()` handled an empty word list it had already
  replaced, `hill_tail_index()` tested the finiteness of a sum of finite logs,
  and the gzip writer re-validated `memCompress()` output.
* Two real defects surfaced on the way. `capsule_attest()` with a raw
  `context` signed the raw bytes but recorded them as hex, so
  `capsule_check_attestation()` could never verify such an attestation; it
  now signs what it records. `gaussian_plume()` and the other dispersion
  models read a plain-vector `receptors` argument column-wise, so
  `c(x1, y1, z1, x2, y2, z2)` was scrambled; it is now read as the x, y, z
  triples the documentation describes.
* A self-test entry hashes a message in two pieces at every split around the
  block boundary and compares with the one-shot digest, exercising the
  partial-block buffering in the SHA-256 and SHA-512 cores that single-shot
  hashing never reaches (`C_rmbl_hash_two_part`, internal). The uncalled C
  symbol `rmbl_xmss_len()` was removed. `.bl_rd_db()` and `to_ascii()` gained
  seams so their fallbacks can be tested; `compute_footprint()`'s memory and
  core detection likewise.
* Still unreached, by design: the `getrandom()` EINTR/ENOSYS and
  `/dev/urandom` failure paths; the barrier's `Rf_error()` after an interrupt
  (unwinds first) and its C++-exception branch (no kernel throws); the ECDSA
  curve-width assertion and the point-at-infinity sum (prime-order curve); the
  ML-DSA rejection-sampling refills, which a seed reaches with probability
  below 1e-5; `small_int()`'s non-digit branch (every caller passes a `\d`
  capture); and `hexval()`'s upper-case branch (the curve constants are
  lower-case). Each is named here rather than hidden behind an exclusion.

## Air pollution, from source to burden, and the footprint of the computation

* **Atmospheric dispersion** (`pg_sigmas()`, `briggs_plume_rise()`, `gaussian_plume()`,
  `gaussian_puff()`, `advection_diffusion_2d()`, `lagrangian_particles()`): the
  Pasquill-Gifford coefficients with Briggs's fits, Briggs plume rise (buoyant and stable
  branches, transitional rise), the Gaussian plume with ground reflection and mixing-lid
  images, an instantaneous puff, an explicit upwind-advection/central-diffusion grid and a
  Lagrangian random walk with a counting grid. Formula for formula the same as rmorie's
  `AirDispersion` module; the particle walk takes any normal generator through `normals=`,
  so rmorie's Philox paths can be reproduced exactly, and defaults to the package's shared
  uniform stream. Every formula is recomputed in the tests.
* **Concentration-response and burden** (`crf_pm25()`, `crf_no2()`, `attributable_fraction()`,
  `mortality_displaced()`, `pollution_burden()`, `pollution_burden_by_area()`): the WHO 2021
  review's pooled estimates (Chen and Hoek 2020, RR 1.08 per 10 ug/m3 PM2.5; Huangfu and
  Atkinson 2020, RR 1.02 per 10 ug/m3 NO2), Burnett et al.'s (2014) integrated
  exposure-response curves for IHD and stroke, Levin's attributable fraction, the BenMAP
  displaced-mortality function and the GBD burden chain, each citing its source and each
  coefficient asserted in the tests. Mirrors rmorie's `envhealth` module.
* **Exposure-response estimation** (`plr_crossfit()`, `exposure_response_plr()`): the
  partially linear model of Chernozhukov et al. (2018) by DML2 cross-fitting with
  ordinary-least-squares nuisances and a sandwich standard error, deterministic from its
  seed and recomputed step by step in the tests, plus a percentile bootstrap; any
  estimator with the same interface (rmorie's `morie_estimate_double_ml()` among them) can
  be passed.
* **Equity** (`exposure_concentration_index()`): the Wagstaff, Paci and van Doorslaer
  (1991) concentration index of exposure by income.
* **The pipeline** (`verify_pollution()`, `pollution_report_text()`): demo data, a CSV, a
  NAPS pull (NO2 ppb converted at 1.88) or scalars; an assumption log; one reference
  concentration throughout; avoided deaths counted over the exposed share; exit statuses
  0/1/2 for scripts.
* **The footprint of the computation** (`compute_footprint()`, `carbon_intensity()`,
  `carbon_intensity_table()`, `detect_location()`, `rapl_available()`,
  `footprint_equivalents()`): the electricity an expression used and the CO2-equivalent it
  implies, measured from the CPU packages' RAPL energy counters where the operating system
  exposes them (codecarbon's Linux method; wrap-around handled, subdomains not
  double-counted), otherwise modelled with the Green Algorithms formula (Lannelongue,
  Grealey and Inouye 2021). The utilisation is measured, per process (this R process's CPU
  time, codecarbon's process mode) or per machine (`/proc/stat`, codecarbon's machine mode),
  or fixed by number; `load_curve` applies Green Algorithms' linear scaling or codecarbon's
  curves. The grid's carbon intensity comes from a table bundled for offline use anywhere:
  every country at the latest year Our World in Data publishes from Ember's yearly data
  (2024 or 2025), sub-national zones from Electricity Maps' 2024 yearly data via Green
  Algorithms data v3.1, and the world average, each row with its year and source; a
  location is matched by code, alpha-3 code or name, an unknown zone falls back to its
  country, and `location = NULL` detects it offline from the environment, time zone or
  locale and records how. Every default that stood in for a measurement is listed in the
  result. Cross-checked against codecarbon 3.3.1 and against rmorie's pollution module.

## Side channels: timing, power, masking

* **First-order masking, on by default.** `kem_decapsulate()` (ML-KEM-512/768/1024) and every
  ML-DSA signature (`capsule_sign()` with an ML-DSA key, `fips_sign_mu()`) run
  with each value that depends on the secret key held as two shares, refreshed with fresh
  randomness from the operating system for every call. The output is byte-identical to the
  unmasked computation: the full vector suite compares the two on every ML-KEM decapsulation
  and ML-DSA signing vector. `kem_decapsulate(masked = FALSE)` keeps the plain path. Cost:
  about 5 times the plain decapsulation and 16 times the plain signature (13 ms for
  ML-DSA-65 on a laptop).
* The gadgets (`src/rmbl_masked.h`): Trichina's AND, a bitsliced Boolean adder,
  arithmetic-to-Boolean and Boolean-to-arithmetic conversion modulo 3329 and 8380417, masked
  Compress_1 and the decompressed ciphertext comparison (Bhasin et al. 2021), masked CBD
  sampling, a masked Keccak, and for ML-DSA a masked SHAKE for rho'' and y, HighBits revealed
  one bit at a time (w1 is public: it is hashed into the challenge), and the three rejection
  tests revealing one bit each.
* **Simulated power analysis** (`inst/tvla`, CI on every change): the gadgets and the ML-KEM
  arithmetic, compiled for a Cortex-M4 and run in an emulator, are assessed with TVLA
  (fixed-versus-random Welch t, two experiments) under two leakage models, the value
  (Hamming-weight) model and the transition (Hamming-distance) model. Every masked kernel shows
  no first-order leakage under either, and every unmasked control leaks (|t| up to 163). CI
  fails on a masked leak under either model.
* **The masking gadgets are assembly** for Cortex-M (Thumb-2), x86-64 and aarch64: every
  operation that touches both shares of a value (AND, XOR, the public-constant operations, the
  copies) loads, computes and stores in a fixed register order, zeroes each temporary before
  it takes a new operand and each destination before it is written, and stores a zero between
  the share-0 and share-1 stores; code that handles one share at a time runs each share in its
  own pass with the general-purpose and SIMD registers zeroed in between. From C, the compiler
  had moved one share into the register that held the other, which the transition model
  showed as leakage (|t| up to 135) and the value model could not.
* **Timing measured on hardware** (`inst/dudect`, CI on x86-64 and arm64 Linux and on
  macOS): the dudect fixed-versus-random test on ML-KEM decapsulation (plain, masked, and
  each phase on its own), encapsulation, HQC decapsulation, the digest comparison and PBKDF2,
  with an early-exit comparison as the control that must be flagged. Decapsulation is also
  measured valid-against-invalid with both classes varying (fresh valid ciphertexts against
  random ones), so the only systematic difference is the rejection bit: an arm64 runner had
  flagged the fixed-ciphertext test at under one tick in 65,000 on one pass and not on the
  next, while every phase measured on its own was clean.
* **Differential fuzzing against OpenSSL 3.5** (`inst/fuzz/fuzz_ossl.cpp`, libFuzzer): ML-KEM,
  ML-DSA (valid and mutated signatures), SLH-DSA-SHA2-128f, the SHA-2, SHA-3 and SHAKE digests,
  BLAKE2b-512, HMAC and PBKDF2 must agree with OpenSSL byte for byte.
* **Found and fixed along the way:** compression divided by q with a hardware divide at -O0
  (KyberSlash) and now multiplies; three "add q when negative" corrections compiled to Thumb-2
  conditional execution on a share's sign and are branch-free; the masked share split drew by
  rejection and now draws in constant time.
* A hex logo (`man/figures/logo.png`, source `data-raw/hex_logo.svg`), on the README and the
  package website.

## The SIU parser, third pass

Two further reviews of 0.5.8 (the diff review and a dedicated SIU review) showed the
C-stack-overflow class still live from three sites the 0.5.8 rewrite did not reach, and
a correctness cost of the fix it did make. All closed here, each at every site of its
kind, pinned by `test-review5.R` and by fuzz seeds for every shape the reviewers used.

* **25,000 form feeds (or vertical tabs, or carriage returns) through the plain-text
  path killed R.** `normalize_text()` collapsed space and tab only; `flatten_ws()` had
  the full six-character set 180 lines away. The first pass now collapses every
  whitespace byte `\s` matches except the newline the second pass bounds.
* **`strip_boilerplate()` ran two unbounded, newline-crossing regexes over the whole
  document** (`[\s\S]*?` to the privacy paragraph's end, `[^.]*` to the glossary
  sentence's end); the line cap never bounded them and 44 KB of period-free text after
  "this information may include", standard boilerplate in every real report, overflowed
  the stack, from `bricklayer_parse_siu()`, `bricklayer_siu_resolve_so()` and the
  network path `bricklayer_fetch_parse_siu()`. Both passes are `find()` scans now; no
  regex in either SIU file crosses a line without a bound, and the hygiene test asserts
  it over the sources.
* **The 2000-character line split is said, and placed better.** A line longer than the
  cap is split at the last sentence end inside the window when there is one, else at the
  last space; every split is counted and `bricklayer_parse_siu()`,
  `bricklayer_siu_text()` and `bricklayer_siu_resolve_so()` warn how many lines were
  split, because a field spanning a split can come back incomplete. 0.5.8 split at any
  space, silently.
* **Two of the new regex-free passes were quadratic** (`strip_elements()` rescanned to
  the end from every unclosed `<script`, 40 minutes at the 2 MiB cap; `strip_tags()`
  rescanned for `>` from every bare `<`). Both are linear, and the whole SIU path now
  polls for a user interrupt through a hook the host installs (`rmbl::check_interrupt()`
  here; rmorie's and morie's bindings install their own).
* **`bricklayer_siu_iso_date()` errors past 4096 bytes** instead of returning `""`;
  `small_int()` reads up to nine digits (`SO #1234567` is 1234567 again, not 1);
  zero-padded numeric entities (`&#0000000233;`) decode; named entities are
  case-sensitive, as in HTML and in 0.5.7.

## From the 0.5.8 diff review

* `rmbl_pbkdf2_sha256()` and `rmbl_mann_kendall()`, the two LinkingTo kernels that poll
  for an interrupt, raise it from a frame that holds none of their buffers; 0.5.8 raised
  from inside the poll, over live `std::vector`s. `rmbl_interrupt_pending()` never
  raises now; `rmbl_interrupt_raise_unbarriered()` does, after the kernel returned. The
  header documents `rmbl_mann_kendall()`'s NA-on-interrupt contract.
* `capsule_drift()`'s identifier heuristic gates on distinct values (20 or more), not
  on a hundred rows a side: an 80-row id column is an identifier again, a 5-level
  factor on ten rows still gets its verdict.
* The exact Mann-Kendall memo evicts its oldest table instead of flushing all 32.
* `mcar_test()`'s `log_p_value` is documented; `download_data(mode =)` says what it
  accepts; `bricklayer_json_to_json()` names `keep_vec_names` and `quiet_vec_names`;
  `MORIE_SERVICES_URL` is documented and a mirror without a `.json` suffix finds its
  `.sig`; `bricklayer_download(timeout = 1e18)` is an error, not an undefined cast;
  a single-label host name is reported as a local address; `bricklayer_llm_ask()`'s
  help says an own endpoint is taken when configured, not probed, and
  `bricklayer_llm_status()`'s example switches the local route off.
* An endpoint of your own (`MORIE_LLM_BASE_URL`) may be a literal private LAN address
  over plain http (`10/8`, `172.16/12`, `192.168/16`, `fc00::/7`: an LM Studio or vLLM
  box on your own network, the documented use), through the same per-call relaxation
  the loopback host has; the diff review (D4) found it refused by two independent rules
  with no way through. Link-local addresses and host names over plain http stay refused,
  and a redirect off such an address meets the full policy. `bricklayer_services()`
  documents `MORIE_SERVICES_URL`; `bricklayer_parse_siu()` and `bricklayer_siu_text()`
  document the 2 MiB cap and the line split; `capsule_drift()` documents the identifier
  gate; `bricklayer_download()` documents its `headers` and `timeout` ranges.
* The services cache serves only when it is newer than the document bundled with the
  package: a cache earns its place by being newer, the same date falls back to the
  bundled copy, and an older one is deleted. morie's resolver gets the same floor.
* Fuzzing: a `fuzz_url` target over `url_check()` and `redirect_policy()`, seeds for
  every shape the reviewers used, and the SIU target runs under an 8 MB stack like R's.

The fourth review (network and service discovery, 2026-10-06) confirmed the 0.5.8
transport closes every bypass it was built for, then found eight things at its edges.
Each is fixed at every site of its kind and pinned by `test-review4.R`.

* **The loopback relaxation is an argument, not an option.**
  `options(rmoriebricklayer.allow_loopback = TRUE)` relaxed every fetch in the process;
  it is gone. The local-model routes pass `allow_loopback` down one call, only when
  the address is the loopback host, and a redirect from a remote origin into the
  loopback interface is refused. An endpoint of your own is either the loopback host
  or a public https address.
* **Request headers do not follow a redirect to another origin unless they are
  content negotiation.** The old rule dropped three named credential headers and let
  everything else travel; `X-Api-Key`, `api-key`, `X-Auth-Token` and the rest now stay
  with the first origin. "Another origin" compares scheme, host and effective port,
  so a redirect to another port on the same host drops them too.
* **A signed document older than the copy shipped with the package is refused.**
  A validly signed but retired document in the cache (or served live) can no longer
  pin the hosted endpoint, which is where the user's key goes; the bundled document
  is the floor, and a stale cache below it is deleted.
* **Bytes a server sent are parsed as text, never as a second address.** One helper,
  `.rmbl_json_text()`, parses every network body, cached manifest and signature file;
  the URL and file branches of `bricklayer_json_from_json()` are for a user's argument
  only. A body or a `.sig` that is a bare URL is "not JSON", not a fetch.
* **Keys are redacted by value.** A gateway's error text has the key that was sent, any
  `Bearer` token and any `sk-` key removed before it reaches an R condition.
* **`MORIE_HOSTED_AUTH_URL` is validated like every other endpoint, and the sign-in
  service's `verification_uri` is opened in a browser only when it is a public https
  address.**
* **Resource limits.** A transfer under 64 bytes/s for 30 s is ended (it used to hold
  the connection for the whole timeout); an in-memory reply past 16 MiB is dropped,
  not handed back as a partial body; `bricklayer_download()` has `max_bytes` (default
  2 GiB) and the services document and JSON fetches cap at 1 MiB and 16 MiB; the
  scratch file is private to the call and the body is moved into place on a 2xx only.

# rmoriebricklayer 0.5.8

The third review of the hardening work (2026-10-06) found seven things,
every one of them a fix that had landed at the site a reproducer named and
not at its siblings. This release fixes each at every site of its kind and,
where the siblings can be listed, puts the list in the tests
(`test-review3.R`, `test-src-hygiene.R`), so a new one cannot appear
unnoticed.

## Language-model routes and the signed services document

* **`bricklayer_llm_ask()` tries an endpoint of your own, then a local
  Ollama server, then the hosted MORIE tier.** `MORIE_LLM_BASE_URL` (with
  `MORIE_LLM_API_KEY`, `MORIE_LLM_MODEL`) names any OpenAI-compatible
  server; `OLLAMA_HOST` / `OLLAMA_BASE_URL` (default `http://localhost:11434`,
  `off` to skip) a local Ollama, whose first listed model is the default
  unless `OLLAMA_MODEL` says otherwise. `route = "own" | "ollama" | "hosted"`
  insists on one. `bricklayer_llm_status()` and `rmoriebricklayer doctor`
  report all three, in order; `agent_bundle()` follows the same order.
* **The hosted tier's addresses come from a signed document, not from the
  package.** `bricklayer_services()` reads
  `https://rmorie.com/.well-known/morie-services.json` and its detached
  ML-DSA-44 signature, verifies it against the public key pinned in the
  package, caches it for a day under `tools::R_user_dir()`, refuses a
  document older than the one it holds, and falls back to the cached copy,
  then the copy bundled in `inst/services/`, then a document with every
  service switched off. The endpoint, the model list, the sign-in address
  and whether the tier is open can now change without a package release;
  a document that does not verify is ignored. `MORIE_HOSTED_BASE_URL`,
  `MORIE_HOSTED_AUTH_URL`, `MORIE_HOSTED_MODEL` and `MORIE_DATA_URL` still
  override. The hosted tier is a last resort; keys are personal and issued on
  request at `www.rmorie.com/access/`, and every hint in the package says
  so. The GitHub and emailed-code sign-ins keep working.
* **Plain http on the loopback host is admitted for the local routes only.**
  The URL policy that guards every other address refuses `http://` and
  loopback twice over; the own-endpoint and Ollama calls set
  `options(rmoriebricklayer.allow_loopback = TRUE)` for their own duration,
  which admits exactly the loopback host (`localhost`, `127.0.0.0/8`,
  `::1`), nothing else private, and a redirect off it meets the ordinary
  rules (`test-llm-routes.R`).

* SIU core: every string-to-integer conversion on a regex capture goes through one bounded helper (`small_int()`); `std::stoi` on a tag such as `SO #4444444444444444` threw `std::out_of_range` and aborted the process (found by the libFuzzer target; the input is in the fuzz corpus). Ported to the rmorie and morie copies.
* **`bricklayer_siu_text()` and `bricklayer_parse_siu()` killed R on 25 KB
  of whitespace.** libstdc++'s regex executor recurses once per character a
  repeated atom consumes, so `\s+` over a long run overflowed the C stack,
  which no `tryCatch()` and no exception barrier can see. Every pass that
  runs over a whole document (newline normalisation, script and style
  removal, tags, entities, whitespace) is a plain loop now, byte-identical
  to the regexes it replaced (the test keeps the old pipeline as an R
  reference and compares); the text every field extractor sees has its
  spaces collapsed and no line longer than 2,000 characters, so no remaining
  regex can recurse further than that (and MSVC's regex, which has a step
  budget instead of a stack, stays inside it -- the one time it did not, the
  public entry points now answer "no match" instead of throwing); the input cap of every SIU entry
  point is 2 MiB (a report page is a few hundred KB). The guard is a test
  that enumerates every one-string SIU entry point from the namespace and
  runs ten hostile inputs through each in a subprocess. XMSS key generation
  polls for Ctrl-C with the throwing check like the other ten sites.
* **One attestation still verified two documents.** 0.5.7 wrote a level
  whose names were all empty as an array, so `{"k":{"":"X"}}` and
  `{"k":["X"]}` shared a digest. The names attribute, present or absent, is
  now the one thing that tells an object from an array at every level,
  empty names included, and a named atomic vector is an object too
  (`{"a":1}` is not `[1]`). Attestations of documents whose fields are named
  vectors change digest; capsules verified against a stored digest should be
  re-attested.
* **Every network byte goes through the compiled transport.**
  `bricklayer_download()` gated with the validator and then transported with
  base R's `url()`: no DNS check, no pin, no redirect re-validation, no size
  cap on the package's own documented pipeline; `bricklayer_json_from_json()`
  fetched a bare URL with no gate at all; `download_data()` wrapped
  `download.file()`. All three use `src/rmbl_fetch.cpp`, with the live
  progress bar driven by a callback from libcurl. The transport itself now
  drops `Authorization`, `Cookie` and `Proxy-Authorization` on a cross-host
  redirect, refuses a redirect from https to plain http even when the http
  option is set, checks a URL before opening the destination and writes
  beside it, moving the body into place only on a 2xx (a refused URL or a
  404 no longer deletes a pre-existing file). The redirect rule is one pure
  function with its own `.Call` entry and tests. A single-label hostname
  (`metadata`, `instance-data`) is refused by shape, without DNS. A test
  lists every network open in `R/` and allows exactly the two base-R
  fallbacks a standalone capsule bundle needs.
* **The interrupt flag.** The barrier cleared `rmbl_kernel_interrupted`
  only on the normal path; it is cleared on entry and on every exit now, and
  a kernel called with no barrier active (a sibling package's own `.Call`)
  re-raises the pending interrupt instead of eating it and returning `NA`.
  `rmbl_pbkdf2_sha256()` in the C API returns an int (0, or -1 for an
  argument it refuses); an interrupt inside it is raised, never a zero key.
* `capsule_drift()`'s identifier heuristic applies its ratio test from a
  hundred rows a side: a five-level factor on ten rows gets a verdict again.
* `mahalanobis_outliers()` carries `log_p_value`, the fifth chi-square site;
  `log_p_value` is documented at every site. `drift_psi()` accepts any
  `eps` in (0, 1) again (0.5.7 refused values above 0.01, a new hard error
  on a previously accepted argument) and the help explains what the floor
  does to the index.
* The Mann-Kendall exact-distribution memo is bounded; hostnames may carry
  underscores; `Makevars.win`'s libcurl fallback link line is wired in;
  `rmbl_digest_equal()` gets the same value barrier as the ML-KEM select.

# rmoriebricklayer 0.5.7

A release about measuring what the 0.5.6 README could only describe. Every
claim in the new "Security posture" table is a check that runs in CI.

* **Constant-time verification, every primitive.** `inst/ctcheck/` runs
  ML-KEM, ML-DSA, SLH-DSA, HQC (v5 and round 4), XMSS, the CTR_DRBG, HMAC,
  PBKDF2, keyed BLAKE2b, SHA-2, SHA-3 and the digest comparison under
  valgrind memcheck with their secrets marked undefined (ctgrind), with GCC
  and Clang; a branch or memory address that depends on a secret fails the
  `constant-time` workflow. The run found and this release fixes: ML-KEM's
  `ByteEncode` branched on every bit it packed (the secret key included);
  the hex encoder used a table indexed by the secret nibble (every HMAC,
  PBKDF2 and key output); ML-DSA's norm check returned at the first
  offending coefficient; PBKDF2 round-tripped each MAC through hex and
  branched on the characters; XMSS measured its hex-encoded seeds with
  `strlen()`. The values the specifications publish (rejected samples, the
  challenge, the hints, R) are declassified at one named line each.
* **Secrets are wiped.** The same harness scans the dead stack after each
  operation for copies of the seed, signing key or password. Every scheme
  left at least one; all temporaries now clear on every return path
  (`rmbl_ct::Guard`), and the scan is part of the gate.
* **Wycheproof.** 1,247 Project Wycheproof vectors (ECDSA P-256/SHA-256,
  P-384/SHA-384, RSASSA-PKCS1-v1_5 2048/SHA-256) run in the test suite.
  They found that the DER parser accepted BER (long-form lengths below
  128, lengths with leading zeros, non-minimal tags, end-of-contents
  octets), that `ECDSA-Sig-Value` was accepted with extra elements,
  padded or negative integers, and that a PKCS#1 block was checked field
  by field rather than against RFC 8017's exact DigestInfo bytes. All
  three are fixed; every valid vector verifies, every invalid and every
  legacy "acceptable" one is refused.
* **Fuzzing.** `inst/fuzz/` holds libFuzzer targets (ASan + UBSan) for the
  DER parser and RSA arithmetic, the decimal-to-double conversion (compared
  bit for bit with the C library), and the SIU report parsers, with seed
  corpora; the `fuzz` workflow runs them on every change and for longer
  weekly.
* `SECURITY.md`: threat model, what each check catches and does not,
  reporting. The README's "Security posture" is now that table.
* `rmbl_hmac_sha256_raw()` joins the C API (the hex variant is a wrapper).

The second review of 0.5.6 (2026-10-06) asked for each fix's neighbours.
Every item below has a test in `tests/testthat/test-review2.R`.

* **Every `.Call` entry point has the exception barrier**, not two of 110:
  `src/rmbl_barrier.cpp`, generated from `init.c` by
  `inst/scripts/gen_barrier.R`, wraps each entry so a C++ exception is an
  R error raised after every destructor has run. Seven `NULL`s to
  `hawkes_rescaled`, a 2 GB `shake`, mismatched `theil_sen` lengths (a
  40 MB out-of-bounds read), a 4 TB `sen_slopes`, a 2^31 reservoir and an
  INT_MAX PBKDF2 are all plain errors now; the quadratic loops and the RSA
  arithmetic check for Ctrl-C; the RSA public exponent is capped at 64
  bytes (1 KB took 1.2 s, 1 MB would have taken 20 minutes, from a
  certificate); `shake` output and PBKDF2 iterations are capped; every
  string argument goes through one `rmbl_str0()`; the DER tree is converted
  under `R_UnwindProtect`, so an allocation failure cannot skip its
  destructor either.
* **SSRF gate rewritten, in the transport.** `src/rmbl_fetch.cpp` parses the
  authority as a URL parser does (`#@` and `?@` no longer hide a host, any
  userinfo is refused), reads IPv4 literals with `inet_aton`'s grammar
  (`127.1`, `0177.0.0.1`, `2130706433`, `0x7f000001`), IPv6 with
  `inet_pton` (mapped, NAT64, link-local, unique-local), refuses local
  names by suffix (`localhost`, `.local`, `.internal`, `.localdomain`,
  `.home.arpa`), resolves every hostname and tests every address, pins the
  connection to those addresses (`CURLOPT_RESOLVE`, so DNS rebinding
  cannot answer differently), follows redirects itself one checked hop at
  a time (an `https` fetch cannot be bounced to `http` or to a private
  host), and caps a chunked download. `bricklayer_fetch()`,
  `.rmbl_read_json()`, the CRL/OCSP fetch, the Wayback resolver and the
  hosted-model client all go through it. `.rmbl_check_public_url()` calls
  the same C check.
* `verify_capsule()`: `provenance_file` is contained like every other
  path (a symlinked `data_provenance.json` verified tampered data as
  intact); `data_not_synthetic` is a required row that always exists and
  reads the sidecar, the manifest and the provenance; a `manifest.json` in
  the capsule is checked by default and `manifest_consistent` /
  `script_sha256` are required whenever they apply; a `sha256` or
  `filename` that is not a single string, an unreadable file or a
  directory are failed rows, not R errors.
* `manifest_digest()` is injective again: the canonical encoder writes an
  empty key as `""` (0.5.6 renamed it to its index, so `{"":"X"}` and
  `{"1":"X"}` shared a digest and one attestation verified both). A list
  with a names attribute is an object and is sorted, empty names included:
  a manifest built with unnamed elements in a named list gets a different
  digest from 0.5.5's, which never canonicalised such a level.
  `make_manifest()` writes `meta$synthetic` only when it is `TRUE`, so a
  real-data manifest keeps its pre-0.5.6 digest, and `make_synthetic_csv()`
  sets the flag in-process.
* JSON: string assembly is linear (250,000 escapes took 16 minutes); the
  reformatter refuses NUL and lone surrogates as the parser does; parser
  and encoder share one 100-level cap (the encoder used to hit the C stack
  first); `bricklayer_json_base64_dec()` refuses characters outside the
  alphabet instead of deleting them; whole numbers beyond 2^53 warn on the
  decimal branch too; `bigint_warn = FALSE` and `duplicate_keys = "keep"`
  are what the package's own API readers use; the gzip inflate cap is
  64 MiB.
* `capsule_drift()`: a character column of dates is compared as dates
  (two disjoint years drift); a column with more than `identifier_levels`
  distinct values, or one per five rows, is an identifier -- its
  `unseen_share` is reported and `drifted` is `NA` (the 0.5.6 PSI over the
  union of categories fired on every id and date column); PSI for the rest
  is over the reference's categories with unseen mass pooled. The result
  gains `type`, `unseen_share` and `note` columns.
* `drift_homogeneity()` returns `p_value = NA` with
  `method = "inapplicable: ..."` when the categories outnumber half the
  observations (every table with those margins has the same statistic),
  draws its Monte Carlo p-value under a local `seed` and restores the
  caller's RNG, and like `drift_chisq()` refuses negative, NA and infinite
  counts. All chi-square sites report `log_p_value` next to `p_value`: a
  double has no number for exp(-2536), and the log says how far below
  zero the tail is. `cramers_v()` drops an unused level (it returned NaN)
  and takes a `seed` too.
* `parse_bands()`: trailing units with punctuation ("18 to 24 (years)",
  "5 to 9 years, inclusive") parse again; cue words are matched as words
  ("overnight" is not "over") in the leading slot as well as the tail
  ("under 18 to 24" is NA, not 18-24); a label with two numbers that is
  not a range is NA ("more than 10 - 20"); thousands separators are
  removed only from correctly grouped numbers ("12,34,567+" is NA); a
  label with a decimal point is on a decimal scale; the dash family is
  normalised byte-wise, so an en dash parses in a C locale.
  `band_values()` guards the open-lower floor as it guards the cap, and
  its default floor is `min(0, upper)`, so "under 0" has its midpoint
  inside the band.
* `trend_test()` reports `slope_ci_clamped = TRUE` exactly when a rank
  is at an end, warns when `exact = TRUE` cannot be honoured (n > 8), and
  memoises the tied exact null; `count_trend()` refuses an all-zero
  series; `step_change()` and `count_trend()` refuse infinite values as
  `trend_test()` does; `morans_i()` refuses negative weights and a
  constant variable; `gini()`, `top_share()`, `lorenz()` and
  `hill_tail_index()` refuse empty input; `hurwitz_zeta()` returns the
  Bernoulli values at non-positive integers (zeta(0, 1) = -1/2); the
  Benford first digit of a subnormal is read from the shortest
  round-tripping decimal (1e-310 is 1, not 9).
* Result changes from 0.5.6 that NEWS did not state: `morans_i()` excludes
  self-neighbours from a weight matrix; `make_manifest()` no longer
  changes the digest of a real-data manifest (0.5.6 did); the OTIS
  full-verification workflow runs on demand only.

The coverage pass that followed (every branch below was untested at
96.2%) found five defects that no test had reached; the CRAN checks and
the entry-point sweep found two more.

* **Revocation checking worked only on paper.** `revocation_fetch()` ran
  every certificate through the single-file-path guard, so a parsed path
  was refused before anything was fetched; the CRL/OCSP fetch refused
  plain `http`, which is what RFC 5280 distribution points and RFC 6960
  responders use (the answers are signed, the transport adds nothing);
  and a delegated OCSP responder's certificate was never found, because
  the search for the `[0]` certificates element landed on `nextUpdate`
  inside the SingleResponse first and the signed answer was reported as
  unverifiable. All three are fixed; the client is now tested end to end
  against recorded OpenSSL responses (good, revoked, unknown, SHA-384
  without an embedded certificate, a delegated responder, an ECDSA
  responder, `tryLater`, and every malformed shape), with the two network
  calls behind one-line seams. The fixtures are documented in
  `tests/testthat/x509-fixtures.txt`.
* `top_share()` summed from the start for every fraction: a million
  fractions over a million values was 10^12 additions with no interrupt
  check (the entry-point sweep found it as the one hang). It is one prefix
  sum now, interruptible.
* `manifest_restore_seed()` padded a record naming only the main generator
  kind with `NA`, which `RNGkind()` rejects; the recorded names are passed
  as they are.
* The JSON simplifier's date-list test used `is.numeric()`, which is
  `FALSE` for a `POSIXct`, so a list of times was never folded back into
  one vector.
* `capsule_drift()`'s date detection errored on a column of timestamps
  with one unreadable value ("2020-01-01 25:99") instead of treating the
  column as text.
* `rmbl_barrier.cpp` re-raised an interrupt through `Rf_onintr()`, which
  is not part of R's API (CRAN refuses it). It now signals R's own
  `interrupt` condition and invokes the `abort` restart, so
  `tryCatch(interrupt = )` sees it exactly as before.
* The two helper scripts that shipped in the tarball were Python
  (`inst/scripts/gen_barrier.py`, `inst/fuzz/mkcorpus.py`); they are R
  now (`gen_barrier.R`, `mkcorpus.R`), with the same output byte for byte.
  `inst/ctcheck/` and `inst/fuzz/` each carry a README saying what they
  are and how to run them. The `agent_bundle()` example switches the hosted
  tier off for its run rather than reaching the network when a key is
  stored.
* Dead code found by the same pass is gone: the unused `wots_gen_pk()` /
  `wots_sign()` in the SLH-DSA body, `rmbl_mad_constant()`, three
  unreachable guards in `.rmbl_conc_input()` / `cramers_v()` /
  `drift_chisq()`, and a duplicated line in the JSON object writer. The
  LinkingTo consumer test now calls the Weibull, Lomax and gamma Hawkes
  kernels and the NaN/short-input paths of the statistics kernels.

# rmoriebricklayer 0.5.6

A security and correctness release from a full external review of 0.5.5
(every item below was reproduced against the installed package before it
was fixed, and each has a test that fails on 0.5.5).

* **`verify_capsule()` fails when it cannot check.** A provenance file that
  lacked `resource$sha256`, `resource$filename` or the whole `resource`
  block -- or was exactly `{}` -- verified a capsule with ALTERED data as
  `ok = TRUE`, because an absent field appended no row and `all()` of the
  remaining rows was still true. Every check that cannot be made is now a
  FAILED row with the reason, `ok` requires the three required rows
  (`provenance_readable`, `data_present`, `data_sha256`) to exist and pass,
  a pinned script digest is checked whenever one exists, a non-CSV file
  with a recorded row count or schema is a failed check, a
  `<data>.synthetic` sidecar is a failed check, and the result has a class
  and a print method that shows what was skipped.
* **The DER parser no longer aborts R.** A 22-byte file made `cert_parse()`
  (and every OCSP, timestamp and X.509 path that parses network bytes)
  throw `std::bad_alloc` through `std::terminate`, killing the session
  past any `tryCatch()`: a length field could be read as 2^64-1 and the
  bound checks wrapped. Lengths are bounded without wrapping, the node
  count is capped, a child must advance the cursor, and no C++ exception
  can cross the R boundary (`rmbl_asn1.cpp`). The same discipline for
  `Rf_error()` over live C++ objects in the RSA, BLAKE2b, SHAKE and digest
  entry points.
* **ML-DSA signing cannot loop forever.** A length-correct but corrupt
  secret key (s1/s2 outside +-eta) is refused in words, and the rejection
  loop is capped. The seven unguarded FIPS 204 arithmetic probes that read
  past a 1-byte allocation are removed (nothing called them); the two
  other unreachable `.Call` registrations are gone too. `pack_sig()` uses
  `memmove()` for its aliased copy; the `poly_chknorm()` comment says what
  the code does.
* Every `.Call` entry that reads a string checks it is one (`rmbl_str0()`);
  `random_bytes()` prefers `getrandom(2)` where glibc has it; XMSS key
  generation can be interrupted.
* **Paths and URLs are checked before use.** `resource$filename`, bundle
  paths and the pipeline's download target must be plain relative paths
  inside the capsule (`..`, absolute paths, drive letters and symlinks out
  are refused). Every URL the resolvers return and every URL
  `bricklayer_download()`, `friendly_download()` and `download_data()`
  fetch must be https (plain http only with
  `options(rmoriebricklayer.allowhttp = TRUE)`), never `file://` (an
  offline test passes `allow_file = TRUE`), and never a loopback,
  link-local, private or metadata address. The Wayback availability API is
  queried over https; the snapshot URL it returns passes the same gate.
  libcurl transfers are bounded: 5 redirects pinned to http(s), 2 GiB to a
  file, 64 MiB into memory, and the `"available": true` check reads the
  literal value.
* **JSON.** A repeated key is an error (`duplicate_keys = "keep"` restores
  jsonlite's behaviour); nesting is capped at 200 levels; a lone surrogate
  escape is an error rather than the text `"NA"`; an integer above 2^53
  warns once unless `bigint_as_char = TRUE`. `bricklayer_json_unserialize()`
  rebuilds data types only by default and refuses functions, calls,
  expressions, namespaces and S4 objects (`trusted = TRUE` for your own
  session's JSON). `manifest_canonical()` sorts a level with an
  empty-string key, so a re-serialised manifest keeps its digest.
  `json_gzip_decode()` refuses a member whose ISIZE trailer declares more
  than 512 MiB and checks the trailer after inflating.
* **Synthetic data say so.** `make_synthetic_csv()` writes a
  `<path>.synthetic` sidecar and returns a classed object; `make_manifest()`
  and `write_manifest_json()` set `meta$synthetic` from
  `BRICKLAYER_SYNTHETIC` themselves, and `record()` marks every comparison
  `INFO` on a synthetic manifest, whatever the analysis script did.
* **The reference pipeline stops on a digest mismatch** (exit 7) unless
  `--allow-digest-drift` is given, and then records the override in the
  manifest. Its subprocess command line is fully quoted.
* `capsule_bundle()` hashes dotfiles and `capsule_bundle_verify()` lists
  them; only the bundle's own file is exempt from "unlisted".
* The hosted-tier endpoints taken from `MORIE_DATA_URL` /
  `MORIE_HOSTED_BASE_URL` must be https and public before a bearer key is
  sent; the credentials file is created `0600` before the key is written;
  a DRBG reseeds itself from the operating system in a forked or restored
  process; the launcher `install_cli()` writes quotes its library path.
* **Statistics.** Chi-square p-values are the upper tail (they underflowed
  to exactly 0 in `drift_chisq()`, `drift_homogeneity()`, `benford_test()`,
  `mcar_test()` and the Mahalanobis screen); the KS p-value uses the
  theta-function series for small t (two million-row columns differing in
  one value were flagged as drifted); `drift_psi()` no longer collapses to
  one bin on a constant or mostly-constant reference (a 1000x rescale
  reported PSI = 0); `drift_homogeneity()` gives a Monte Carlo p-value
  below five expected counts, and `capsule_drift()` reports a PSI and the
  unseen-category share for categorical columns, so two disjoint date
  columns are flagged; a one-category table reports df 0 and NA.
  `morans_i()` honours the magnitudes of a weight matrix. The exact
  Mann-Kendall p-value enumerates the observed values, ties kept.
  `eb_rates()` refuses negative, missing and infinite counts.
  `parse_bands()` strips thousands separators, reads "ages 18-24", and
  leaves a bare "-5", inverted bounds, "100-200-300" and "15 to 19 and
  over" as NA; `expand_bands()` errors (or warns, with
  `drop_unparsed = TRUE`) instead of dropping units; `band_values()`
  refuses a cap below a band's lower bound. `count_trend()` uses t
  quantiles in its quasi-Poisson branch; `trend_test()` reports
  `slope_ci_clamped` when the pairwise slopes do not reach the requested
  confidence and refuses infinite values. Benford digits are read from
  the decimal rendering (2e-300 was digit 1).
* **Packaging.** `graphics`, `grDevices` and `tools` are declared; `R CMD
  check` fails CI on a WARNING; a `configure` script probes pkg-config /
  curl-config for libcurl on Unix; an ASAN + UBSAN job runs the suite;
  DESCRIPTION names every scheme the package implements and states that
  none has been audited; the key and signature help pages carry a
  Security section; a FIPS 202 known-answer test covers SHA-3 and SHAKE
  directly; the LinkingTo consumer test calls all 45 published kernels;
  the stale CHANGELOG.md is gone (NEWS.md is the record).

# rmoriebricklayer 0.5.5

* **XMSS: an index never signs twice.** `capsule_sign()` signed two messages at index 0 when called
  twice with the same key object (the key is an R value, so it cannot advance the caller's copy),
  and the help said it refused. It now remembers, for the session, the highest index each key has
  signed with and refuses that index or an earlier one (one key object signed twice, or a stale
  copy), retiring the index before the signature exists (RFC 8391; NIST SP 800-208). A damaged
  `next_index` (NA, negative, fractional) is refused in words. Across sessions, save the latest
  `key_state` after every signature.
* Hawkes processes: events at the same instant no longer excite each other. The intensity sums over
  strictly earlier events, as the definition of a Hawkes process (a simple point process) has it;
  the exponential recursion, the sum-of-exponentials recursion and the exponential and Lomax
  densities counted a tie as an excitation at lag 0. `core_hawkes_fit()` warns when times are tied,
  and `core_hawkes_jitter()` spreads times recorded to a resolution (daily dates) uniformly across
  their interval, as Filimonov & Sornette (2015) recommend, with the splitmix64 uniforms rmorie and
  morie use for the TPS fits (the same numbers on daily data). The goodness-of-fit KS test uses the
  exact distribution only without tied residuals (the exact computation with ties ran for minutes
  and exhausted memory).
* `core_hawkes_fit()` is fast for the Lomax kernel: the projected BFGS now restarts its curvature
  estimate when a parameter reaches or leaves its bound (as L-BFGS-B does). A Lomax fit to
  exponential-like data drifts to the bound on `alpha` (its exponential limit), and the matrix learned
  with `alpha` free mis-scaled the remaining steps: 1,164 iterations and 196 s on 9,839 events, now 64
  iterations and 3 s to the same optimum. The same restart ends the gamma kernel's stall on its sum-of-
  exponentials and truncated likelihoods (2,000 iterations to a worse optimum on 2,118 tied events;
  now 2.8 s to the exact route's maximum), so `"auto"` keeps `"soe"` for gamma. `core_hawkes_fit()`
  also returns `at_bound`, the parameters whose estimate lies on the box:
  `converged` alone did not show that day-dated times had driven a shape to its wall. A fit whose event rate `n / horizon` lies outside what the
  bounded baseline can reach (`e^-15` to `100 e^15` per unit time; `horizon = 1e308`) is refused with
  a message to express the times in another unit, instead of returning its start.
* `core_hawkes_nll()` is the likelihood `core_hawkes_fit()` maximises, on the same parameters: its
  Lomax was a power law with exponent `alpha` (a Lomax of shape `alpha - 1`), so its values and a fit
  of it disagreed with the fit and with the documented density; it now uses the shared core for every
  kernel, keeping its documented sentinel outside the feasible region. A non-finite `horizon` is
  refused by every Hawkes function (`Inf` returned a list that looked like a fit).
* SIU reports: counts in every layout. Investigators, forensic investigators, subject and witness
  officials and civilian witnesses are read from 2020-on English pages ("Witness Officials ( WO )",
  the singular "Civilian Witness ( CW )"), French pages ("Agents témoins ( AT )", numbered
  "AT no 1" or "AT n o 1", "Nombre d'enquêteurs de l'UES assignés : 3") and the legacy
  (2005-2011) layouts ("Witness Officer #2", "Three SIU investigators and two forensic
  investigators", "l'agent témoin n o 1", "Cinq enquêteurs"); "No civilian witnesses were
  identified" is 0, and with no subject-official section the resolver's rules decide (a bare "SO" no
  longer counts as one). Checked against the reviewed corpus on the 29 pages of the round-8 test:
  witness officials 27 of 29 (16 before), civilian witnesses 24 of 25 (14), investigators 29 of 29
  (20), subject officials 20 of 20 (17).
* SIU `police_service`: a service named as the one that notified the SIU ("the OPS contacted the SIU
  to report that police officers with the VPD ...") is passed over for the subject officials' service
  (drid 2010: Vancouver Police Department, not Ottawa); the OPP has one French name ("la Police
  provinciale", a legacy header's detachment) and one English name ("OPP Sioux Lookout").
* SIU dates: a notification that dates the incident relative to itself ("during his arrest two hours
  prior", "the day before", "deux heures plus tôt", "la veille") gives the incident date (drid 648:
  2019-09-12, not an earlier break-in); legacy headers ("Incident date:", "Date de l'incident :") are
  read; the French narrative's "du 9 février 2022" is read and interview and team dates are passed
  over. Legacy pages are recognised by language. French abbreviated months ("5 janv. 2023"),
  upper-case accented months ("3 AOÛT 2017") and "March 3 , 2020" are read.
* SIU dates: the incident date is the first dated sentence of the narrative that is not the
  notification or the SIU's own work (drid 670: "... contacted the SIU to report a serious injury. On
  July 8, 2019 at about 3:50 p.m., CKLPS were called" is 2019-07-08), "of <date>" counts ("Just
  before 4:00 a.m. of January 7, 2020"), and a narrative without a date gives way to the director's
  analysis ("On December 4, 2020, the Complainant rolled his SUV"); drids 670, 820, 1200 and 4600
  were empty. "The SIU was notified of the incident by ... on October 27, 2017" dates the
  notification, and French "1 er septembre 2016" and "L'UES a été avisée ... le" are read.
* SIU fields: `specific_injuries` comes from the investigation, never from the mandate's definition of
  a serious injury, with whole words ("stab" is not "constables", "arm" not "firearm"), more body
  parts, and French injuries ("fracture de l'épaule droite"); French `charges_recommended` and
  `relevant_legislation` ("Code criminel") are read. `&Agrave;`, `&laquo;`, `&raquo;`, `&thinsp;` and
  the other capital and French entities decode.
* `bricklayer_siu_resolve_so()`: the spelled-out plural ("Two subject officials were designated"), "no
  official was a subject official" and witness officials with no subject official named resolve, as
  the help describes.
* `bricklayer_siu_resolve_so()` reads French reports: the "Agent(s) impliqué(s)" roster ("AI no 1", a
  lone "AI"), legacy ordinals ("agent impliqué n o 3", "l'agent(e) impliqué(e) n o 1"), "aucun agent
  impliqué" and witness officials (AT) alone; the privacy, definition and legal paragraphs ("des agents
  impliqués et témoins", "les agents impliqués sont invités ...") are not read as cues. It returned NA
  on every French page. `bricklayer_parse_siu()` falls back to these rules for a French report with no roster,
  as it does for an English one (drid 3658: 9, as its English twin).
* Inputs: `kem_keygen(512.5)`, `kem_keygen(c(512, 768))`, `pqc_keygen(2.5)` and every other whole-number
  argument refuse a fractional value instead of truncating it to another setting;
  `bricklayer_fetch_siu(1.5)` no longer fetches drid 1; `bricklayer_parse_siu()` refuses a path that
  does not exist (it parsed the string as an empty report); `bricklayer_fetch_parse_siu(lang = "xx")`
  is an argument error.
* Argument errors in words where R's internals spoke: `bricklayer_json_base64url_dec(character(0))`
  (now empty, as `bricklayer_json_base64_dec()`), `bricklayer_json_unserialize()` of a number,
  `capsule_bundle(character(0))`, `yoy()` of an infinite value, HyperLogLog registers beyond 64
  (`distinct_count(1e300)`), and `bricklayer_fetch_parse_siu()` with an invalid drid, which is now an
  argument error before any network instead of a message and `NULL`.
* `core_hawkes_jitter(horizon = )` spreads each event over `[t, min(t + resolution, horizon)]`, so a
  time dated on the horizon stays inside the window (it was pushed past it, and the fit then refused
  the times); the fit's refusal names the span and the remedy.
* The `?mahalanobis_outliers` example contradicted itself: its "ordinary on each variable" row had
  the largest weight, and its classical-versus-robust comparison printed `FALSE`. The row is now
  short and heavy within both ranges, and the comparison uses a cluster of bad rows.
* A count argument refuses `TRUE` (it was read as 1: `drbg_generate(d, TRUE)` gave one byte), `Inf`
  and values beyond the integer range in words, with no coercion warning; `hqc_sizes(Inf)` no longer
  warns before refusing.
* `bricklayer_fetch()` gives the HTTP status of a server that answered ("answered HTTP 404"; it said
  "could not reach"); `friendly_download(attempt_wayback = FALSE)` (or `""`) says the fallback is
  switched off instead of claiming the Wayback Machine has no snapshot.
* `data pull` refuses an `--out` path it cannot write before downloading the table.
* CLI exit codes: a `bundle` with no language-model route exits 1; an empty prompt or request, a
  malformed `--email` and an unknown option to `help` exit 2.
* `bricklayer_json_to_json()` is byte-identical to jsonlite's `toJSON()` where jsonlite does not
  pass an option on: `raw = "js"` is written with jsonlite's defaults (`new Uint8Array([35])`, an
  array, even under `auto_unbox`, where it wrote the number 35), `raw = "hex"` is unpadded ("f"), a
  `Date` epoch never gets a decimal point, the mongo `$date` and `$binary` objects and
  `keep_vec_names` objects stay on one line under `pretty`, and `keep_vec_names` does not reach the
  columns of a data frame. 18,000 random objects now encode identically (30 in 3,000 differed).
* `bricklayer_json_serialize()` is no longer called lossless: like jsonlite's `serializeJSON()` it
  rounds doubles to `digits` (8); `digits = I(17)` round-trips them exactly. `?bricklayer_llm_login`
  says a token is checked with the gateway before it is stored.
* CI checks on Intel macOS (`macos-15-intel`), where r-universe's check had failed.
* `hqc_compress_key()` stores an HQC secret key as its seed alone: for v5 the specification's
  compressed format `dk = seed_KEM` (32 bytes), for round 4 the 96 to 112 bytes its key generation
  draws (round 4 defines no compressed format). `hqc_decapsulate()` takes such a key, re-derives the
  pair and refuses a seed that does not give the key's own public half.
* The HQC documentation no longer calls FIPS 207 a draft: NIST has named the standard but had
  published neither it nor a draft by 2026-10-05.
* `core_hawkes_fit(method = "em")` finishes with the projected BFGS on the exact likelihood from
  EM's point. EM converges linearly, so its steps shrink before it reaches the maximum: it stopped
  up to 1.5e-5 short of the direct fit in the negative log-likelihood (1.4e-5 on macOS x86_64,
  where r-universe's check failed); it now ends within 2e-8. `converged` reports whether that
  finish converged instead of always `TRUE`.
* SIU `police_service` is now the service of the subject officials, read from the director's analysis:
  the first service named in a sentence that names a subject official (or the sentence before it),
  else the service the analysis names most. It was the force that notified the SIU, which is often a
  custody, requesting or neighbouring service -- on 93 French reports it disagreed with the reviewed
  English report. The case number's letter (T Toronto, P OPP, I First Nations, O any other service)
  rules out services of the wrong kind, and legacy reports' "Police service:" header decides for them.
  Checked against every reviewed report in the corpus: 2,147 of 2,163 French and 111 of 118 English
  agree; the French values the old rule wrote agreed on 2,097 of 2,191.
* SIU reports name the same people "subject officers" (before the SIU Act, 2019), "subject
  officials" (after it) or "SO": the parser now writes the count as `number_of_subject_officials`,
  the corpus's and the SIU Act's term and the same form as `number_of_witness_officials` (it was
  `number_of_subject_officers`, so the parsed row and the shipped corpus disagreed on the column
  name). The section and ordinal matching already read all three spellings.
* A deterministic random bit generator: `drbg_new()`, `drbg_generate()` and `drbg_reseed()` are the
  CTR_DRBG of NIST SP 800-90A with AES-256 and no derivation function, written here (AES computed in
  constant time, with AES-NI on x86-64). It reproduces all 720 AES-256 no-df vectors of NIST's DRBG
  validation suite (no reseed, reseed, prediction resistance) on both ciphers, and it is the
  `randombytes()` of NIST's `rng.c`: seeded with the bytes 0..47 it gives the seed of vector 0 of
  the post-quantum known-answer files written with it.
* HQC in both revisions: `hqc_keygen(version = "round4")` adds the fourth-round submission of
  2023-04-30 (HQC-128/192/256, the HQC of liboqs up to 0.12 and of PQClean) with its 64-byte shared
  secret, next to the default v5 (2025-08-22, 32 bytes). It shares v5's codes and parameters and
  reproduces all 300 of that revision's official known-answer vectors on both multipliers. Keys
  carry their `version`, `hqc_encapsulate()` / `hqc_decapsulate()` follow it, `hqc_sizes()` takes
  it, and a round-4 secret key whose public half is not the one its seed makes is refused. A `level`
  must be one whole number (`c(1, 3)` and `3.5` were read as 1 and 3).
* Hawkes processes fitted fast and exactly: `core_hawkes_fit()` (constant or sinusoidal baseline;
  exponential, Weibull, gamma or Lomax kernel) maximises the likelihood with its analytic gradient
  by projected BFGS in C++, and `core_hawkes_residuals()` gives the time-rescaling residuals in O(n)
  or O(n w). Routes: `"exact"` (Ozaki's O(n) recursion for the exponential kernel; the Weibull and
  gamma double sums stop where the kernel underflows to 0, so they equal the full sums), `"soe"`
  (Lomax and gamma with shape < 1 as sums of exponentials with relative error `eps`, Beylkin &
  Monzon 2010), `"truncate"`, `"em"` (Veen & Schoenberg 2008) and `"inar"` (Kirchner 2017). The code
  is shared with morie's Python arm, which calls the same routine, so the two return the same
  estimate (asserted on common data in both test suites). `core_uniforms()` exposes the splitmix64
  stream both arms use where they must draw the same numbers. The default `method = "auto"` is exact
  for the exponential kernel, `"truncate"` for Weibull (whose exact window, where the kernel
  underflows, spans the whole record when the shape is below 1) and `"soe"` for Lomax and gamma;
  `"soe"` truncates a gamma kernel with shape >= 1 at `eps`.
* HQC-KEM, the code-based key encapsulation NIST selected in March 2025 beside ML-KEM:
  `hqc_keygen()`, `hqc_public_key()`, `hqc_encapsulate()`, `hqc_decapsulate()` and `hqc_sizes()` at
  HQC-1, HQC-3 and HQC-5, implemented in the package. All 300 official known-answer vectors of the
  specification of 2025-08-22 (reference implementation v5.0.0) are reproduced byte for byte, on
  both the hardware (PCLMULQDQ / PMULL) and the portable carry-less product, and on big-endian
  machines. Secret-dependent work is branch-free with no secret-indexed memory or shift (checked
  with valgrind), secret intermediates are wiped, a ciphertext that fails the FO check yields the
  implicit-rejection key, and a decapsulation key whose seeds do not derive from each other is
  refused.
* Fresh-user round 5: `VERB --help` prints the verb's usage under both names and never runs it
  (`logout --help` used to forget the key); messages name the command typed (`rmbl` or
  `rmoriebricklayer`); usage errors exit 2 and an unknown function in `describe` / `examples` exits 1;
  `--version` works. `login --token` asks the gateway before storing a key and refuses a rejected one;
  `login --email` checks the address and `--code` needs `--email`; the GitHub sign-in says it is still
  waiting every 30 s. A key the gateway rejects is reported as rejected (not "gateway not reachable"),
  the gateway's quote of the key and its hash is never printed, and `models` lists the models without
  the suggested jsonlite. `agent_bundle()` and `doctor` use the package's own hosted route only
  (`backend` is "auto" or "hosted").
* `bricklayer_fetch()` says why a download failed (the HTTP status, a server never reached, no
  Wayback snapshot) and refuses a non-http(s) URL, an unwritable destination or a non-positive timeout
  before downloading; `friendly_download()` keeps R's `url()` warning out of the console, reports its
  status as the cause and says when the Wayback Machine has no copy; the Wayback lookup retries once.
  SIU: an impossible date ("February 30") is no date, day-first ordinals ("2nd February 2018",
  "22nd of March 2019") and abbreviated months read, the hex quotes and dashes decode as the decimal
  ones, report pages are read from their body rather than the table of contents (incident dates were
  empty), and the helpers take `NA` and several reports. `yoy()` compares a biennial series step to
  step (it found no comparisons) and labels an inserted year "no data"; `report_analysis()` prints
  years without a thousands separator and describes a percent analysis in percentage points;
  `sha256_file()` names a missing file.

* The SIU parser reads ordinal dates ("August 3rd, 2017") as well as French months, and legislation
  such as the Police Services Act no longer outvotes the police service (17-OVI-201 reads Guelph Police
  Service, 2017-08-03). `data --help` exits 0 like every other help, and `bricklayer_fetch()` refuses
  an empty URL or path in words.
* The command line answers to `rmbl` as well as `rmoriebricklayer`: `install_cli()` writes both
  launchers, pinned to the library they were installed from with `.libPaths()` inside R (an `R_LIBS`
  in the shell or `~/.Renviron` cannot swap in another copy) and without the explicit `--args` that
  made R 4.6 report "unknown verb '--args'"; `login --help` prints the usage instead of starting the
  sign-in.
* Fixes from the 1.4.0 stress test of the family: `friendly_download()` no longer fails inside its own
  Wayback fallback when the snapshot lookup returns nothing usable, and names a cause for an error it
  does not recognise; `wayback_snapshot_url()` returns `NULL` for a malformed answer; `yoy()` averages
  several rows of one period for continuous values and percentages (counts still add up; pass `fun`
  to choose); `report_analysis()` renders a percent analysis (its changes are percentage points);
  the SIU parser reads French dates ("3 ao\u00fbt 2017") and decodes accented named entities
  (`&ccedil;`, `&eacute;`, ...) and every numeric entity.

# rmoriebricklayer 0.5.4

* The hosted tier lists additional AI models (kimi-k2.6:cf, kimi-k2.7-code:cf, deepseek-v4-pro:cf, deepseek-v4-flash:cf, glm-5.2:cf, glm-5.3:cf, glm-5.3-flash:cf, gpt-oss-120b:cf, gpt-oss-20b:cf, llama-4-scout:cf, qwen3.8-27b:cf, nemotron-3-120b:cf and gemma-4-26b:cf) beside the
  ollama.com ones, and falls back to them when a cloud model is rate
  limited; `rmoriebricklayer ask --model gpt-oss-120b:cf` picks one.

* The `rmoriebricklayer` launcher works under R 4.6, which keeps `--args` in
  `commandArgs()`; `friendly_download()` goes through `bricklayer_download()`.

* `bricklayer_download()`: one download routine with a live progress bar
  (percent, size, rate) on a terminal and milestone lines in a log, used by
  `friendly_download()` and the data hub. `options(morie.quiet = TRUE)`
  silences it.

* `cert_chain_verify()` and `timestamp_verify()` verify SHA-384 signatures
  (ECDSA-SHA384, RSA-SHA384): the digest was computed natively but never
  routed to the verifier, so such chains stopped with an error.

## Curated datasets at data.rmorie.com

* `bricklayer_data_manifest()`, `bricklayer_data_tables()` and
  `bricklayer_data_load("db/table")`: the 160 databases the MORIE project
  materialises from BigQuery public datasets, served from the edge and opened
  by the key `bricklayer_llm_login()` stores. From the shell:
  `rmoriebricklayer data list`, `rmoriebricklayer data pull db/table`.

# rmoriebricklayer 0.5.3

## See what you can ask

* `bricklayer_llm_models()` returns the models the hosted MORIE tier offers
  your key (through the package's own libcurl GET), with the default
  `bricklayer_llm_ask()` would use as an attribute.
* `rmoriebricklayer models` prints that list (default marked);
  `rmoriebricklayer doctor` names the models on its hosted line;
  `rmoriebricklayer ask --model NAME PROMPT` picks one for a single call.

# rmoriebricklayer 0.5.2

## A language-model route of its own, and a command line

* `bricklayer_llm_ask()`, `bricklayer_llm_login()`, `bricklayer_llm_logout()`
  and `bricklayer_llm_status()` talk to the hosted MORIE LLM tier at
  llm.rmorie.com (retired in 0.5.12) through the package's own libcurl POST. Sign in
  with the GitHub device flow, a code sent to your email, or a key you
  already have; the key is kept in `$XDG_CONFIG_HOME/morie/credentials.json`
  (owner-only, written only by an explicit `login`), the file `morie` and
  `rmorie` read as well, so one sign-in serves all three. Nothing is
  imported from either.
* `agent_bundle()` answers through that route when a key is stored and only
  then falls back to the optional rmorie-cli agent; it recognises the
  launcher that the rmorie R package installs under the same command name
  (which has no `agent` verb) and skips it.
* `bricklayer_cli()` and the `inst/bin/rmoriebricklayer` launcher give the
  package a shell command; `install_cli()` links it into `~/.local/bin`
  (a `.cmd` wrapper on Windows), only when called. Verbs: `login`,
  `logout`, `doctor`, `ask`, `bundle`, `functions`, `describe`, `examples`,
  `version`, `help`.
* The POST primitive takes extra headers (bearer authentication); Docker
  images get semver tags and `latest` follows release tags.

# rmoriebricklayer 0.5.1

## Categorical integrity: labels that cannot be swapped quietly

The Ontario Human Rights Commission's 2020 report *A Disparate Impact*
stated that Black civilians in Toronto were 30 to 58 times as likely as
White civilians to experience police use of force; the corrected figure
(OHRC correction of 26 January 2023, after Maria Jung's independent review)
is 4 to 5 times, because the four race codes had been rotated during a
transfer from SPSS to R (White read as Black, Black as other racialized,
other racialized as unknown, unknown as White), and the transfer took the
blame for two and a half years. Thirteen functions make that
class of error impossible to commit silently and easy to name after the
fact: `guard_recode()` maps by name and refuses anything unmapped,
`decode_codes()` decodes imported integer codes against an explicit
dictionary, `guard_levels()` fixes levels and the reference group,
`audit_categories()` flags the import hazards, `verify_recode()` proves
a recode by cross-tabulation, `verify_marginals()` checks recoded counts
against published counts and names the label permutation that would
explain a mismatch, `odds_ratio_check()` recomputes reported odds ratios
under every relabelling of the table and names the one that reproduces
them, `guard_binary()` stops a factor reaching a numeric treatment slot,
and `recode_manifest()` with `write_recode_manifest()` and
`verify_recode_manifest()` records the chain, signs it with a
[capsule_sign()] key, and verifies it later. The same guards ship in
rmorie and morie (both arms), verified three-way. New vignette:
*Categorical integrity*.

The transfer itself is guarded and, when blamed, examined. `relabel()`
maps old labels to new ones BY NAME and refuses a positional vector of
labels, which is the one-line idiom (`levels(f) <- sort(labels)`) that
produces exactly the documented rotation from codes 1 to 4.
`decode_labelled()` decodes a haven-style labelled import by code, with
the levels in code order. `transfer_verify()` takes what the source
program printed (its code book and its frequency table) and refuses an
import that does not reproduce both. `relabel_forensics()` names which
mechanical step (alphabetical, reversed, rotated, frequency-ordered,
string-sorted codes) reproduces an observed permutation, so a transfer can
be exonerated, or not, from the code book alone: no import routine sorts
value labels onto codes. `audit_categories()` also flags code-prefixed
labels such as "1. White".

## gcc-UBSAN clean

CRAN's gcc-UBSAN run on 0.5.0 reported two undefined operations, both
fixed: ML-KEM's Montgomery reduction multiplied two 16-bit unsigned
values in `int` (overflow above 2^15); it now multiplies in `uint32_t`.
HMAC with an empty key passed a null pointer to `memcpy` for zero bytes;
the copy is skipped.

## Capsule bundle staging

The bundle built by `make_bundle.sh` runs on a machine with none of the
family packages installed, so every internal name a staged file calls has
to be staged too. Three were not: the input guards the libraries now
call, the seed helper behind the synthetic-data route, and the compiled
`core_sha256()` behind `manifest_digest()`. The first two files are now
staged; `manifest_digest()`, `.rmbl_read_json()` and the describe table
fall back to the pure-R implementations when the compiled ones are
absent, with the same numbers. `dev/bundle_symbol_scan.R` now runs inside
the build and fails it on any called-but-unstaged name, so the class
cannot recur. `setup_and_run.R --synthetic` (or `OTIS_MRP_SYNTHETIC=1`)
takes the synthetic route without a prompt, and the exhausted-downloads
message names that route by its real menu number.

## Every export, degenerate inputs and known answers

* `verify_capsule()` failed on every intact capsule: the pinned digest
  arrives from provenance JSON as a length-1 list and was compared to the
  computed string with `identical()`. `verify_sha256()` now coerces the
  digest and compares case-insensitively.
* `core_ipw_weights()` refuses a treatment that is not coded 0/1 (a 1/2
  coding used to send every unit down the control branch) and a
  propensity outside [0, 1] (previously clipped to the trim bound); a
  missing treatment or propensity gives a missing weight.
* Input contracts on the exported primitives: numeric kernels refuse
  character, list and data-frame input instead of coercing to NA; the
  hash functions all map `NA` to `NA`; signatures, HMAC and key derivation
  need character or raw messages; stock-and-flow measures refuse `Inf` and
  numeric dates; band parsers need character labels; rule constructors
  need a column name; manifests need lists; the download, wayback,
  revocation and capsule verifiers need non-empty paths, and
  `verify_capsule()` an existing directory.
* `sir()` reports `excess` only when the interval lies above one, plus
  `deficit` and `significant`; `published_bounds()` labels a bare `NA`
  `"missing"` instead of `"exact"`.
* `examples/otis-mrp/analysis.R` prefers rmorie for the DML recompute, as
  its header says, and falls back to DoubleML.

## Third stress round

* `core_cor()`: the shared kernel now uses the centred two-pass formula
  and clamps to [-1, 1]. The one-pass expansion was wrong at the second
  decimal for a spread of 1e-7 of the mean, NaN by 1e-8, and returned
  |r| > 1 at 1e-15; `cor(x, x)` could come back -1.
* `verify_marginals()` and `transfer_verify()` gain `strict`. The default
  still errors on a mismatch; with `strict = FALSE` the result comes back
  with `ok = FALSE`, the `permutation` that explains the counts, a
  `message`, and (for `transfer_verify()`) `reasons`, so
  `relabel_forensics()` is reachable from the public path. The documented
  `ok = FALSE` was previously unreachable.
* `audit_categories()` flags leading/trailing whitespace including
  non-breaking spaces, whitespace-variant duplicates, empty-string
  labels, missing-value sentinels stored as labels ("NA", "N/A", "NULL",
  ...), and a reference level that is any of those. Five such columns
  used to pass as "no hazards detected", two of them with the invisible
  variant as the reference level.
* `relabel_forensics()` reports an identity permutation as "no
  permutation to explain" instead of naming a mechanism.
* `scan_adjust()` refuses p-values outside [0, 1] instead of adjusting
  them and calling a negative value significant.

## trend_test() no longer stalls beyond a few hundred periods

The Sen confidence interval enumerated every pairwise slope in an R
double loop that grew a vector one element at a time, so a series of
2,000 periods took minutes and a long one never returned. The slopes are
now enumerated and sorted in C (`n` of 3,000 runs in seconds, identical
interval), and `trend_test()` refuses more than 20,000 periods with a
message giving the memory the pairwise slopes would need.

## Functions that seed the RNG leave the caller's stream alone

`drift_calibrate()`, `capsule_power()`, `capsule_falsify()`,
`falsify_family()`, the synthetic-data generator and the trend bootstrap
seeded the session and left it seeded, so a user who had set a seed for
reproducibility got identical downstream draws whatever seed they chose.
Each now seeds for its own call and restores the caller's stream on exit;
the seeded results are unchanged.

## core_moments() and json_gzip_decode() at the extremes

`core_moments()` squared its first value on the first step of the
single-pass update, so any input above the square root of the largest
double gave NaN for every statistic, and raised raw deviations to the
fourth power, which overflowed beyond about 1e77. It now takes two passes
on deviations scaled by their largest magnitude; the definitions and the
results on ordinary data are unchanged, and the shape statistics are NaN
only when the variance is zero. The streaming accumulator behind
`rmbl_moments_acc_add()` no longer squares its first value either.

`json_gzip_decode()` refuses input that is not a gzip member (fewer than
18 bytes or not starting 1f 8b) with a clear error. It used to pass the
bytes straight to `memDecompress()`, which in R 4.6 dumps core on an
empty vector, so `json_gzip_decode("")` crashed the session.

## core_mean() no longer overflows where base R does not

The shared numeric core summed naively, so `core_mean(rep(1e308, 3))` was
`Inf` and `core_mean(rep(1e120, 3))` was off by 1.4e104; `core_var()`,
`core_sd()` and `core_moments()` inherited it, returning 3e208 for the
variance of three identical values. The core now uses base R's algorithm
(extended precision sum plus one corrective pass) with a running mean as
the fallback when the sum overflows although every input is finite, and
the same fix ships in rmorie, which carries a copy of the header. Results
on ordinary data are bit-identical to `mean()`.

## One call for a published table

`analyse_table()` runs the questions asked of every published table of
counts (what is in it, what changed and how sure, rates if there is an
exposure, trend, drift against the prior capsule) and returns one object;
`report_analysis()` writes it as Markdown or a single HTML file;
`use_capsule_template()` writes a capsule folder whose `analysis.R` runs
as written. A getting-started vignette walks the shipped OTIS table
through it in twenty lines.

## Uncertainty the release itself introduces

`published_bounds()` turns rounded (`rounding = 5`, nearest or Statistics
Canada random rounding) and suppressed (`"x"`, `"<5"`) cells into the
interval of observed counts that could have produced them;
`change_envelope()` carries that interval through a difference, a percent
change or a rate exactly; `yoy_bounds()` adds it to a `yoy()` table with
a combined interval that is the union of the sampling interval and the
envelope. No confidence interval covers this uncertainty, so it was
previously invisible.

## Many comparisons, and screens that fire on nothing

`yoy_pvalues()` gives the exact conditional-binomial test that matches
the `yoy()` interval; `scan_adjust()` adjusts a `yoy()` or `rate_change()`
scan for multiple comparisons (Benjamini-Hochberg by default) and marks
what survives; `rate_change()` now returns `previous_count` and
`previous_population` so the test is exact given the exposures.
`drift_calibrate()` estimates how often `capsule_drift()`'s screens fire
on identical data by splitting one release into random halves, per
column and family-wise, with the per-screen alpha that would hold the
family-wise rate.

## Encoding handling no longer depends on the session locale

`ascii_fallback()` and `to_ascii()` test the bytes with `validUTF8()` and
drop invalid ones with an explicit UTF-8-to-UTF-8 `iconv()`. The previous
guard went through `enc2utf8()`, which under a C locale re-encodes invalid
bytes as Latin-1 instead of flagging them, so the fallback returned them
untouched. `bricklayer_json_minify()` and `bricklayer_json_prettify()`
declare their result as UTF-8 (`paste()` had dropped the mark, so
`nchar(x, "chars")` over-counted in a C locale). Found by an independent
C-locale check of 0.5.0; the check matrix now includes a C-locale cell.
The JSON byte-order-mark test and strip work on the bytes, so a C locale
no longer warns "unable to translate '<U+FEFF>...'" or "invalid char
string in output conversion" while validating or minifying JSON.

# rmoriebricklayer 0.5.0

## Point locations and the regions that contain them

A region map from facilities to statistical regions is built once and read
many times, so an error in it is the one error recomputing the downstream
tables cannot find: everything downstream reads the region map, and both
sides of any comparison move together. `R/region_map.R` adds the checks
that can find it.

* `region_coverage()` reports how many regions hold at least one unit and
  what share of the population lives in them, and its print method says
  each time that the share is not a rate denominator. A region holding no
  unit is not an unserved population: units serve catchments, which a
  point location does not state. Summing the populations of unit-holding
  regions pairs a partial denominator with a numerator drawn from the
  whole territory, and every rate built that way is inflated unevenly.

* `region_map_integrity()` finds what a comparison against published
  output cannot, because it would be present on both sides: a unit
  assigned two regions, a unit assigned none, a region code belonging to
  another province. No geometry, so it runs with nothing installed.

* `region_map_compare()` matches two region maps on the unit identifier and
  compares them cell by cell, numerics through `all.equal()` so a
  coordinate that survived a round trip through text is not reported as a
  change.

* `region_map_second_route()` compares the assignment against one derived a
  DIFFERENT way, and takes the known-bad cases by name rather than by a
  loosened tolerance. This is the only one of the four that can catch an
  error in the original method, because it does not use that method.

* `region_map_from_points()` recomputes the assignment by point in
  polygon, projecting the points onto the boundary file's own coordinate
  system rather than the reverse. It returns `NULL` without `sf` or
  without the boundary file, so a verification script records the check as
  unavailable instead of failing over an optional dependency. `sf` joins
  Suggests.

## The otis-mrp example

* New section 3g re-derives the institution to census division region map
  and the division populations under it, rather than reading them. The
  49 Ontario census-division populations re-derive exactly from Statistics
  Canada 17-10-0139-01, summing to 15,109,416; the 21 divisions holding an
  open institution hold 10,110,752 of those. Twelve checks run with
  nothing granted, and injected errors were confirmed to fail them: a
  moved institution, a foreign region code, an altered population, a
  dropped division and a duplicated row each break at least one.

* The city-name second route covers eleven of the twenty-five open
  institutions and disagrees on one, which is recorded as documented
  rather than tolerated. Sudbury Jail stands inside the City of Greater
  Sudbury, census division 3553 and 171,568 people; the bare name
  "Sudbury" belongs to census division 3552, Sudbury District, 22,746
  people. Two places, one name. The geometry is right and the name route
  is wrong, and a SECOND disagreement is still a failure.

* `institution_cd_region_map.csv` and `cd_population_2022.csv` now travel
  with the example, so the checks run from the bundle.

## Verification that runs

* The push CI now fetches the public OTIS A01 input (4.7 MB, cached on
  its pinned provenance) and passes it to the smoke test, so every section
  of `analysis.R` is exercised on each push instead of recording as INFO.
  The bundle's R packages are read from `config.json` rather than listed a
  second time in the workflow.

* `verify_bundle.sh` compares the manifest against `config.json`'s
  `total_checks` and `pass_csv` whenever real data was supplied, and fails
  on a mismatch. The expected counts are now an assertion, not a note.

* A weekly workflow, `otis-full-verify.yml`, runs `analysis.R` with every
  opt-in verification on: the 147 published year-over-year tables, the
  108 rate tables, the census-division populations re-derived from
  Statistics Canada, and the point-in-polygon recompute of the region map
  against the 2021 boundary file. It fails on any DIFFER and keeps the
  manifest for ninety days, so "verified" carries a date.

* CI refuses a copy of any vendored R file tracked under `examples/`, the
  shape of the `custody.R` shadowing below.

* `check_pkgdown()` runs in the test suite when pkgdown is installed, so a
  topic missing from the reference index fails locally rather than on the
  site build.

## Printing

* The statistics that return a classed data frame -- `rate()`, `share()`,
  `rate_change()`, `stock_flow()`, `region_coverage()` and
  `band_sensitivity()` -- print through one frame: a titled rule, the
  table, the lines that qualify it. The caveats each of them carries are
  laid out the same way instead of rewritten per method.

## Bug fixes

* `examples/otis-mrp/custody.R` is removed. It duplicated `R/custody.R`
  and took precedence over it: `analysis.R` searches beside the script
  before `../../R`, so a run from a checkout without the package
  installed resolved to a `stock_flow()` without the `baseline` argument
  and without `period_days()` or `stay_summary()`. It was the only one of
  the nine vendored R files tracked under `examples/`, and
  `make_bundle.sh` copies the package file over it at build time, so
  built bundles were unaffected.

# rmoriebricklayer 0.4.9

## Bug fixes

* The JSON writer no longer asks the platform for its digits. Seventeen
  significant digits are this package's round-trip guarantee, but
  `sprintf("%.17g")` delegates to the C library, and Windows aarch64's
  gets it wrong: it renders the largest double as
  `1.7976931348623156e+308`, one ulp low, so the text reads back as a
  different number. Eight assertions in `test-attest.R` and
  `test-json-edges.R` failed there while passing on every other
  platform, and jsonlite, which brings its own converter, disagreed with
  both. The digits are now generated by exact integer arithmetic in
  `src/rmbl_strtod.cpp`, the same way the reader already worked:
  mantissa times a power of two, scaled by an exact multiply and an
  exact division, with the remainder deciding the rounding, ties to
  even. Verified byte-for-byte identical to the platform across 199,934
  doubles wherever the platform is correct, so nothing changes on a
  sound library.

# rmoriebricklayer 0.4.8

## Why the version moved

Five exported functions -- `adp()`, `alos()`, `admissions()`,
`adp_from_counts()`, `stock_flow()`, and then `period_days()` and
`stay_summary()` -- were added across three commits that all carried
`Version: 0.4.7`. r-universe had already built and served 0.4.7 from an
earlier snapshot, so a package depending on `rmoriebricklayer (>= 0.4.7)`
could be handed a build without any of them, and rmorie's minimal-dependency
job duly failed on exactly that. A version number that does not move when
the interface grows cannot be depended on, which is the whole reason it
exists. Everything below was previously listed under 0.4.7.


## The stock and flow measures reach the example, and so does the MNAR pair

Both were computed and published for reading before they were shipped
anywhere a check could see them. They are in `analysis.R` now.

**Section 3e** computes Lakner's measures for segregation through the
package's own `adp()`, `alos()` and `stock_flow()`, so the example
exercises the functions rather than reimplementing them. It is NOT
gated, unlike the rate tables: there is no denominator to argue about,
since days divided by 365 and days divided by the people who served them
are both unambiguous.

It records checks that can fail, not just values:

* `lakner_b02_one_row_per_person` asserts the structure that makes
  `TotalAggregatedDays_Segregation` Lakner's X-sub-i.
* `lakner_people_b01_vs_b02_*` requires the two tables to agree on how
  many people there were.
* `lakner_decomposition_exact` requires `(1 + p) * (1 + l) - 1` to
  recover the change in days, to 1e-9.
* `lakner_b01_consecutive_is_not_total_*` records the ratio, about 0.67,
  so the trap cannot be rediscovered the hard way: `b01` holds roughly
  2.7 rows per person and its `NumberConsecutiveDays_Segregation` is a
  spell length, not an additive share of the year.
* `lakner_day_share_*` puts the day share beside the headcount share,
  which is how Lakner p.15 says a subgroup share of the average daily
  population must be taken.

**Section 3f** is the capacity analysis, as a pair rather than an
imputation. `Operational_Capacity` is missing for three of the 25 open
institutions and they are the large ones -- Central East CC, Central
North CC and Toronto South DC -- while the largest observed capacity is
944. Missingness that depends on the value is MNAR, not MAR, so imputing
would pull all three toward the observed mean and understate three
denominators in a knowable direction.

So Central and Northern, whose capacity is fully observed, get a
complete-case estimate, and the other three get a range across the
plausible span of their one missing capacity. Three checks carry the
argument: that every `Alert_Type` gives the same yearly total, since
summing across types would count each placement six times; that exactly
two regions are fully observed; and that all three unobserved capacities
exceed the largest observed one, which is what makes this MNAR.

New outputs: `12_stock_flow.csv` and `13_capacity_mnar.csv`. The
capacity analyses need Ontario's institutional-locations CSV, a separate
CKAN dataset, shipped with the example and overridable with
`OTIS_LOCATIONS`.

## Stock and flow: person-days have two denominators

`adp()`, `alos()`, `admissions()`, `adp_from_counts()` and
`stock_flow()` implement the measures from Lakner, *A Manual of
Statistical Sampling Methods for Corrections Planners* (University of
Illinois at Urbana-Champaign, 1976). One quantity, person-days, carries
two denominators:

* divided by TIME it gives the average daily population, a **stock**:
  how many people are held at once. Lakner p.15.
* divided by PEOPLE it gives the average length of stay. Lakner p.16.

`stock_flow()` puts both in one table with the decomposition, because
when length of stay moves the two can carry **opposite signs** and a
report quoting either alone states the wrong direction for the other.
The print method says so explicitly when the signs disagree.

This is not a hypothetical. On Ontario's segregation data the number of
people held fell 24.0% between FY2023 and FY2025 while their stays grew
43.5% longer, so total detention days rose 9.0% and the average daily
population rose with them. A flow rate falls 27.6% over exactly the
window in which a stock rate rises 3.9%. The decomposition is exact:
days are people times length of stay, so
`(1 + p) * (1 + l) - 1` recovers the change in days.

`admissions()` inverts the identity when two of the three quantities are
published and the third is not. `adp_from_counts()` covers the case
where only periodic headcounts exist rather than a record per person
(Lakner eq 2.7, p.21), with the assumption stated: the days counted must
not differ systematically from the days missed.

`alos()`'s documentation carries Lakner's own caveat (p.16-17), which is
easy to lose: the period must exceed the longest stay people actually
serve, or the average is biased DOWNWARD, because the longest stays are
the ones that fail to finish inside the window.

Nothing about the arithmetic is specific to custody -- the same
relationship governs hospital beds, shelter occupancy and open caseloads.
It is Little's law under the names corrections planning uses.

The tests anchor on Lakner's own worked examples rather than on each
other: 13,500 days over a year giving 36.986; 12,150 days across 2,700
people giving 4.5; 25 held daily against 1,750 admissions giving 5.2;
and counts on 255 days summing to 34,935 giving 50,005 person-days.
Those are numbers computed by someone else, so they can disagree with
this code, which is the property a test needs.

## Rates, shares and rate change

A count is not comparable across places of different size or years of
different population, so `rate()` divides counts by exposure and scales
to a denominator -- `per = 1000`, `"10k"`, `"100k"`, `"1m"`, or any
positive number. The interval is the exact Poisson one, matching
`stats::poisson.test` to the last digit, so a count of zero gives a
lower limit of exactly zero instead of a negative rate.

`share()` is the other quantity people mean by "percentage": what
fraction of a total each count is. Its denominator is the total of the
same events, not a population, so shares over a complete grouping sum
to 100. The interval is Wilson's rather than the normal approximation,
which runs past the ends of the scale and reports negative percentages
at exactly the small counts people reach for it.

Labelling one of these as the other is the most common error in a
published table, which is why they are separate functions with separate
intervals rather than one function with a flag.

`rate_change()` is the change in a rate between periods. This is not
the percent change of two rates treated as measured numbers: both
denominators move, and an interval that ignores them understates the
uncertainty. It conditions on the total of the two counts and corrects
for the exposure ratio -- `yoy()`'s exact conditional-binomial interval
generalised to unequal denominators, and it reduces to exactly that
interval when the two populations are equal, which is a test.

Like `yoy()`, the comparison period is matched on the period value and
not on row position, so a missing year reports no comparison instead of
silently comparing 2023 against 2020.

## Verifying the published year-over-year tables

The `otis-mrp` example now recomputes every published OTIS
year-over-year table from the province's own CSVs and compares all of
them: 147 tables across 29 datasets, 8,214 cells. Previously the
example verified the models and the descriptives but said nothing about
those tables, so a reader checking them had nothing to check against.

The table definitions are a port of the generator that produced the
published page, not a reimplementation from column names -- percent
change rounded to one decimal and undefined when the earlier value is
zero, shares against the column total, groups sorted with NA and empty
dropped. Getting those subtly different would produce mismatches that
look like data errors and are actually definition errors.

It also checks something a cell-by-cell comparison cannot: three OTIS
datasets reach the same restrictive-confinement population by different
routes, and `a01` distinct individuals, `c01` totals and `c04` totals
must agree per fiscal year (20,781 / 19,641 / 25,045). A wrong grain
rule would move both sides of a cell comparison together and pass; this
fails.

The datasets are ~14 MB and are not shipped. They come from
`OTIS_DATASETS_DIR` if you already have them, or `OTIS_YOY_DOWNLOAD=1`
to fetch them from the province. rmoriedata is deliberately not a
source: its OTIS files are five-row samples for examples, so comparing
published totals against them would fail by construction rather than
tell anyone anything.

Files are named from the CKAN resource URL, which ends in the canonical
filename for all 29. Nothing is inferred from the resource title, which
would be guesswork -- "Segregation Placements - Maximum, Median and Mode
Consecutive Durations by Region" is the file called
`b04_segregation_placements_consecutive_durations_by_region`, and 15 of
the 29 diverge that way. A column signature then confirms a downloaded
file contains what its name claims, which catches the province
reshuffling data behind a URL -- an error no comparison against
published output could catch, because both sides would move together.

## Rate tables, verified against both exposures -- opt-in

The example can verify the 108 published rate tables across 24 OTIS
datasets, 15,831 cells, and does so on request:

    OTIS_RATES_VERIFY=1 Rscript analysis.R <input> <outdir>

It is off by default, and not because it fails -- it passes all 108.
It is held back because a group row in those tables divides that group's
count by the WHOLE yearly population, so it states how much the group
contributes to the overall rate rather than the rate among its own
members: men's placements over the whole restrictive-confinement
population is not a rate for men. c01 carries the population by gender,
so a matched denominator exists for some tables and not others, and
choosing per table is its own piece of work. The example already has
the rates it needs, and the year-over-year tables already give counts,
shares and percentage change for every published table.

Each count is expressed against two exposures:

* the yearly total of the prison population the dataset covers, per
  1,000, taken from `c01`, which states all three regime totals
  directly. Those totals were checked against the detailed datasets
  rather than trusted: `a01` distinct individuals equal `c01`'s
  restrictive-confinement total, and `b01` and `b02` distinct
  individuals equal its segregation total, in every year.
* Ontario residents at April 1, per 100,000, from Statistics Canada
  table 17-10-0009-01. Geography position 7 was confirmed as Ontario
  from the cube metadata rather than assumed.

This is the construction criminology uses for a rate -- a count over an
exposure, which in a count model enters as an offset of log(exposure).
Intervals are the exact Poisson interval, and change between years is
the exact conditional interval for a rate ratio corrected for both
exposures, cross-checked against the two-sample `stats::poisson.test`.

`otis_headline_rates()` reports the named rates. Over FY2023 to FY2025
the incarceration rate rose from 216.7 to 267.5 per 100,000 residents
while the solitary-confinement rate fell from 81.6 to 59.1, and within
custody solitary use fell from 376.7 to 221.0 per 1,000. The two move in
opposite directions, which a count alone hides.

The recomputation deliberately does not port the generator's
arithmetic, as the year-over-year check does; it goes through `rate()`
and `rate_change()`, whose intervals are anchored to base R. That
independence found two defects in the generator that a like-for-like
port would have reproduced silently: the rate-ratio arguments were
reversed, giving a +34.4% change an interval of -25.9 to -25.3 that did
not contain its own estimate, and a group with no exposure in a year got
an upper limit of `Inf` on a change that was simply undefined. Both are
now guarded by assertions that every rate and every change must lie
inside its own interval.

A group row in these tables is a CONTRIBUTION, not a per-capita rate:
the numerator is that group's count and the denominator is the whole
yearly population, so men's placements over the whole
restrictive-confinement population is not a rate for men. Where the
measure counts recurring events rather than people the per-1,000 figure
can exceed 1,000, for the same reason one person can hold several
placements. Both facts are stated on every table rather than left for a
reader to infer.

## The count model no longer reports a missing AIC

The canonical `glmmTMB` fit returned a non-positive-definite Hessian and
no AIC, which the example flagged as a warning for several releases. The
cause is identifiable: the negative-binomial dispersion runs to
4.35e+08. A negative binomial whose theta goes to infinity IS a Poisson,
so the likelihood is flat in that direction and the Hessian is singular
in it. The `rc` random intercept, with a standard deviation of 4.5, has
already absorbed the overdispersion theta would explain -- the outcome
is 93% zeros with mean 0.173 and variance 0.473 -- so the two compete to
describe the same variation and one is left unidentified.

The fit now names the model it is actually fitting. The Poisson gives
the same coefficient and the same standard error to four decimals, with
a positive-definite Hessian and an AIC of 3045.3 against the published
3041.7. Which family produced the numbers is recorded in the manifest,
because a coefficient is not interpretable without it.

A different optimiser was the wrong answer and was tried first:
Nelder-Mead converges, but to a worse optimum (AIC 3054), trading a
missing AIC for a wrong one.

## The otis-mrp example

The example analysis had an absolute path to the author's own volume as
its default input. It could not exist on a reviewer's machine and it
published a local directory layout, so the input is now searched for --
command line, then `OTIS_INPUT`, then known filenames in the working
directory and beside the script -- and the script stops with the exact
command to run when it finds nothing.

`lme4` and `DHARMa` were attached and recorded as dependencies but
never called; both are gone. The header now also says which arm is
canonical for what: `rmorie::morie_otis_irm_dml` is the preferred DML
path and makes `DoubleML`, `mlr3`, `mlr3learners` and `lgr`
unnecessary, while `MatchIt` and `glmmTMB` stay because the published
numbers came from them and the script exists to let a reviewer check
those numbers.

The analysis now also writes `08_rates_and_yoy.csv`: movement rates per
1,000 placements and per 1,000 person-years, each year's share of the
total, and the year-over-year change in the rate. Capsule bundles carry
`yoy.R` and `rate.R` so this works with nothing installed.

## Fixes

* A capsule bundle sources `json_native.R` with no compiled library
  present, so calling the registered native decimal converter failed
  with `object 'C_rmbl_strtod' not found` and every bundle run died.
  The converter is used when it is there and R's own reader when it is
  not.
* `test-attest.R` compared the decimal converter against decimal
  literals, which are converted by whatever C library R was built
  against -- the thing under test. On macOS both sides moved together
  and the test failed against the correct answer. Expected values are
  now transported as the bytes of the double.
* The version-drift test read `DESCRIPTION` from a source tree that
  `R CMD check` does not provide, erroring on all five platforms.
* `rate_change()` on non-numeric periods indexed with positions that
  could be zero, which returns a shorter vector and recycles wrong
  answers rather than reporting anything.

* `analysis.R` called `say()`, which is defined only in the bundle's
  `lib_interactive.R`. Run from a bundle it resolved; run directly from
  a checkout -- which is how a reviewer runs it -- it died with
  `Error in say(...)`. Both call sites use `cat()` now.
* The example's default input was an absolute path inside the author's
  own volume. It could not exist on a reviewer's machine and it
  published a local directory layout. The input is searched for now.
* Column signatures are compared after sorting with `method = "radix"`.
  The default `sort()` uses the locale's collation, which orders
  `Number_Of_Placements` before `NumberConsecutiveDays_Segregation`
  while byte order does the reverse; one dataset of the 29 differs only
  in that pair, so under the default sort its signature failed to match
  itself and the file went unidentified.

# rmoriebricklayer 0.4.6

Certificate path validation is now complete: the three things 0.4.5
listed as still missing are done.

## Name constraints

A CA can be limited to part of the name space, and a verifier that
ignores the limit treats a CA constrained to one organisation's domains
as able to issue for any name at all. `cert_chain_verify()` now enforces
`nameConstraints` for every CA in the path against every certificate
below it -- not only the leaf, so a constrained CA cannot escape by
issuing an intermediate.

The matching rules are per type and deliberately not shared: a DNS
constraint of `example.org` covers `host.example.org` and
`example.org`; an email constraint of `example.org` covers mailboxes
whose host is exactly that and NOT its subdomains; a directory name
constraint matches whole relative distinguished names, so `O=Acme` is
not satisfied by `O=AcmeCorp`. `pathLenConstraint` is enforced too.

## Certificate policies

`certificatePolicies`, `policyMappings`, `policyConstraints` and
`inhibitAnyPolicy` are processed as RFC 5280 section 6.1 describes, with
its three counters. Pass `policies` to `cert_chain_verify()` and the
path must yield one of them after mapping; omit it and policies are
still processed, but only reported as a failure where a certificate in
the path requires an explicit policy. Mapping to or from `anyPolicy` is
rejected, as the standard requires.

Not done: policy qualifier processing. A user notice attached to a
policy is parsed past rather than surfaced.

## Revocation can now be fetched

`revocation = "fetch"` retrieves CRLs from the distribution points in
the certificates and queries any OCSP responder they name. OCSP is
POSTed as RFC 6960 requires a responder to accept, falling back to the
optional GET form.

It is opt-in, and that is the design rather than caution. A verifier
that reaches out during a check stops working offline -- which is where
an archival capsule is most likely to be verified -- becomes
non-deterministic, and tells whoever runs the responder which
certificates are being checked and when. `"supplied"` (the default)
uses only CRLs handed in; `"none"` skips revocation entirely.

A responder's answer is believed only when its signature verifies under
a certificate in the path, or one it carries that the path issued. An
unverifiable "good" is reported as a failure: treating it as a pass
would be worse than skipping the check, because it would look like the
check had happened.

## Along the way

* SHA-1, for OCSP CertID only -- RFC 6960 keys a request on the SHA-1
  of the issuer's name and public key, and a responder given anything
  else answers "unauthorized". It verifies no signatures here and must
  not: SHA-1 collisions are practical.
* `C_rmbl_http_post()`, so OCSP can POST. It is the only thing in the
  package that sends a body.
* Every verdict here was cross-checked against `openssl verify` on the
  same certificates -- it rejects the three name-constrained leaves and
  the wrong-policy leaf that these tests reject -- and the OCSP request
  this package builds is byte-identical to `openssl ocsp -reqout`,
  which checks the DER encoder, the CertID and the SHA-1 at once.
* Fixed a `logical(0)` trap in policy processing: `is.na(NULL)` is
  `logical(0)` and `if` on it is an error, so a counter read from a
  structure that did not carry the field failed instead of defaulting.

# rmoriebricklayer 0.4.5

The four things the previous release documented as deliberately
incomplete are now complete.

## Certificates are validated, not just used

`timestamp_verify()` gained `trust`, `crls` and `at_time`, and there is
a new `cert_parse()` and `cert_chain_verify()` behind them. The chain is
built to an anchor you name, every signature in it is verified, every
validity window is checked, an issuer must be a CA, and the leaf must
carry the timeStamping extended key usage. A CRL can be handed in.

Validity is judged at the time the TOKEN asserts, not at the time the
check runs. A token signed in 2020 under a certificate that expired in
2021 was validly signed, and judging it by today's date would reject it
for a reason unconnected to its validity.

Omitting `trust` no longer passes quietly: `certificate_trust` is
reported as failed, because a signature that verifies under an
unvouched-for certificate says only that some key signed the token.

Still not done, and now the only gaps here: name constraints, policy
mapping, and fetching revocation data over the network.

## ECDSA, not only RSA

`rmbl_ecdsa.cpp` implements ECDSA verification over P-256, P-384 and
P-521 -- field and group arithmetic, Jacobian point operations, and the
FIPS 186-4 verification equation with the range and on-curve checks that
a lax verifier skips. Certificates and timestamp tokens signed with
`ecdsa-with-SHA256/384/512` now verify; the test fixtures carry one
token of each kind over the same payload under the same CA, so the two
paths are exercised against real tokens rather than against each other.

SHA-384 was added for `ecdsa-with-SHA384`, checked against its FIPS
180-4 vectors.

One bug is worth recording because of how it presented. The P-521 group
order was written four hex digits short. Every published base-point
multiple still matched -- the curve arithmetic uses only the field
prime and b -- while every operation mod n was wrong and no signature
verified. The fix added a width check on every curve constant and a test
that `n * G` is the point at infinity, which is the property that fails
the moment the order is wrong.

## Falsification can now confirm as well as refute

`capsule_power()` injects an effect of known size, reruns the whole
detection procedure, and reports the rate at which it is found. The
smallest size detected reliably is the smallest effect the analysis
could have seen.

This is the case the negative controls cannot reach. A procedure with no
power against the effect at issue passes every control in
`capsule_falsify()` by failing to see anything at all, and a null result
from it is not evidence of absence. A design whose permutation floor sits
above alpha -- where no size could ever be detected -- is refused rather
than run.

## Signing an SLH-DSA `s` parameter set is five to seven times faster

Worst case went from 7.20 seconds to 2.67, and the SHA-2 sets from 7.20
to 1.09. Nothing is gated behind an environment variable any more; every
parameter set signs in the test suite.

Three changes, in order of what they were worth:

* the Keccak round no longer evaluates `% 5` on every lane -- the
  permutation is straight-line code with literal indices, generated from
  the formulas rather than transcribed;
* the tweakable hash no longer heap-allocates, which it was doing a few
  million times per signature;
* the SHA-2 parameter sets resume from a cached midstate instead of
  recompressing the padded public seed on every call, which is what the
  reference implementation means by a seeded state.

`sha256_update()` and `sha512_update()` also now copy in bulk rather
than a byte at a time, which speeds up every other user of them.

All 15 signature parameter sets remain byte-identical to OpenSSL 3.5,
re-checked after the optimisation: 300 comparisons, no differences.

# rmoriebricklayer 0.4.4

## From "the record is intact" to "the record is right"

`verify_capsule()` checks a manifest against itself, which catches an
edited manifest and cannot catch one that was wrong when it was written.

* `manifest_recompute()` re-runs named statistics against the data and
  compares each to what was recorded. Results that were recorded but
  NOT recomputed are reported as `unchecked`: an analysis that recorded
  twenty statistics and re-derives three has seventeen it has not, and a
  report that quietly omitted them would read as a clean bill of health.
* `manifest_record_seed()` and `manifest_restore_seed()` record and
  replay the generator's full state. `set.seed()` is reproducible only
  if everything before it is too -- one extra draw upstream shifts
  every later value -- so the state is what gets recorded, and the kind
  beside it, because a seed replayed under a different kind gives
  different numbers silently.
* `capture_dependencies()` records where each package came from: the
  library, the repository, and for a remote install its URL and commit.
  Two installations can report the same version and differ.

## Falsification, and what comes before and after it

* `prereg_declare()` and `prereg_check()` -- declare the statistics an
  analysis intends to report, and compare that against what it did.
  The two departures are reported separately because they are different
  failures: a declared statistic that was not reported is outcome
  switching, and a reported statistic that was not declared is an
  addition. Both are invisible without a declaration made in advance.
* `falsify_family()` -- corrects a family of permutation p-values by
  Holm, Benjamini-Hochberg or Bonferroni, and names those sitting at
  the permutation floor, where more permutations would be needed to say
  anything more. Running the control over twenty statistics and
  reporting the one under 0.05 is not a finding.
* `evalue_rr()` -- the E-value of VanderWeele and Ding: how strong an
  unmeasured confounder would have to be, with both the exposure and
  the outcome, to explain the result away.

## Distribution and time

* `capsule_bundle()`, `capsule_bundle_read()` and
  `capsule_bundle_verify()` -- one signed artifact holding a digest of
  every file, the manifest digest and an attestation over both. The file
  digests are inside the signature: a list of hashes that is not itself
  signed can be rewritten to match whatever the files now say. Files
  present but unlisted are reported too.
* `timestamp_verify()` and `timestamp_info()` -- RFC 3161 timestamp
  tokens, verified natively. The message imprint is checked against the
  data, the genTime is reported, and the authority's RSA signature over
  the signed attributes is verified, which meant implementing DER
  parsing and a bignum modular exponentiation (`C_rmbl_der_parse`,
  `C_rmbl_rsa_recover`). A hash chain proves the order of a sequence of
  manifests and not that any of them existed at a given time; this
  supplies the date.

  What it does NOT do, stated plainly because it is the difference
  between this and a browser's padlock: validate the certificate. No
  chain building, no validity dates, no revocation, no check of the
  timeStamping key usage. Pass the certificate you have decided to
  trust, and read a pass as "this key said so".

# rmoriebricklayer 0.4.3

## A manifest can now reproduce its own numbers

`write_manifest_json()` wrote doubles at four significant digits, so a
manifest recording `1/3` said `0.3333` and no later recomputation could
match what was written. Every number is now written at full double
precision -- seventeen significant digits, which is enough to recover
any double exactly -- and round-trips exactly, the smallest denormal
included.

That holds on every platform, because the package no longer asks the
platform. Seventeen digits recover any double only through a reader
that rounds correctly, and not every C library does: macOS arm64
(R 4.6.0) reads the correct decimal for `.Machine$double.xmax` as
`Inf`, and loses low bits above about 1e100 on text written elsewhere.
So the decimal conversion is done here instead, in integer arithmetic
with a remainder that decides the rounding -- round to nearest, ties to
even, with no floating point involved in the decision. A manifest
written on one machine now reads back bit-identically on another, and a
caller does nothing to get that. A provenance record that cannot reproduce its own numbers is
the one failure mode the whole capsule apparatus exists to prevent, and
this was it.

* `manifest_canonical()` and `manifest_digest()` -- one line of JSON
  with every object's keys sorted, and its SHA-256. R lists keep
  insertion order, so the same manifest assembled in a different order
  used to serialise to different bytes, which made a signature over the
  JSON depend on the order a script happened to build a list in. Sign
  the digest.
* `capture_environment()` now records `rng_kind` and whether a seed was
  in force. Without the generator's identity a stochastic result cannot
  be reproduced even on the same machine: R has changed its default
  `sample()` algorithm before, and a recorded seed means nothing without
  the kind it was fed to.

## Attestation: a signature a third party can actually check

`capsule_attest()` and `capsule_check_attestation()`. A bare signature
leaves three things implicit -- which key, which scheme, which bytes --
and a verifier who has to be told them out of band cannot check anything
they were not already given. An attestation records the scheme, the
public key, the context, the pre-hash, the manifest digest and a note
from the signer, all inside the signed payload, so the check is
`capsule_check_attestation(attestation, manifest)` and nothing else.
Editing any field afterwards is detected, including the note.

## Falsification: controls that can fail

`capsule_falsify()` runs four negative controls against a statistic and
reports whether it behaved: a permutation test that destroys the
association on purpose, a random common cause that cannot matter, a
placebo exposure, and subset stability. Reproducibility is a property of
a pipeline, not of a claim -- a capsule can be signed, hashed, chained
and reproduced byte for byte while reporting a number that means
nothing.

The permutation control reports the smallest p-value its design could
have produced, because a reader who does not know that 19 permutations
floor at 0.05 will over-read a p of 0.05. The controls are demonstrated
failing as well as passing: a constant statistic fails the permutation
test, noise fails it, and a statistic that reads the injected noise
column fails the random-common-cause control.

# rmoriebricklayer 0.4.2

## The rest of the NIST post-quantum standards

* **ML-KEM (FIPS 203)** at all three levels -- `kem_keygen()`,
  `kem_encapsulate()`, `kem_decapsulate()`, `kem_sizes()`. A key
  encapsulation mechanism answers a different question from a
  signature: not who produced a capsule but what key two parties now
  share. Decapsulation has no failure path, deliberately: a bad
  ciphertext yields a shared secret derived from a value held only
  inside the decapsulation key, so the sender learns nothing from
  whether it worked. That is the Fujisaki-Okamoto transform's implicit
  rejection.
* **HashML-DSA (FIPS 204 section 5.4) and HashSLH-DSA (FIPS 205 section
  10.2.2)** -- `capsule_sign(prehash = )`, for signing a digest of the
  message rather than the message. The identifier of the pre-hash is
  bound into the signature, not merely its output, so a signature over a
  SHA-256 digest is never interchangeable with one over a SHAKE128
  digest of the same length.
* **ExternalMu-ML-DSA** -- `fips_mu()`, `fips_sign_mu()`,
  `fips_verify_mu()`. A message can be reduced to the 64-byte value that
  is all ML-DSA signing consumes, and only that handed to whatever holds
  the key, so a large file never has to cross the boundary the key sits
  behind. mu binds the public key and the context, so it is not a bare
  digest.

Every one of these is checked against OpenSSL 3.5, which shares no code
with this package. ML-KEM keys generated from the same seed agree byte
for byte at all three levels, its ciphertexts decapsulate here to the
secret it reports and ours to the secret we report, and a corrupted
ciphertext produces the same rejection secret in both. The pre-hash and
external-mu signatures are byte-identical for every parameter set and
every pre-hash.

# rmoriebricklayer 0.4.1

## The standardised post-quantum schemes are now implemented here

ML-DSA (FIPS 204) and SLH-DSA (FIPS 205) were previously reached through
liboqs, so which schemes a build offered depended on what happened to be
installed on the machine that built it -- a poor property for a signature
format meant to outlive that machine. Both are now implemented in the
package, on its own Keccak sponge, and the optional system dependency is
gone along with the `./configure` step that probed for it.

* `fips_keygen()`, `fips_public_key()`, `fips_key()` and `fips_sizes()`
  are the new entry points. `pqc_backends()` now reports a fixed list --
  ML-DSA at all three parameter sets and SLH-DSA at all twelve, six over
  SHAKE and six over SHA-2 -- available in every build. `fips_key()`
  wraps key material from elsewhere, so a key written by another
  implementation can be used directly.
* SHA-512, HMAC and MGF1 gained the pieces the SHA-2 instantiation of
  FIPS 205 needs. Its address is compressed from 32 bytes to 22 with
  every field moved, its message randomiser is an HMAC and its digest an
  MGF1, and its multi-block tweakable hash switches to SHA-512 at
  192-bit security and above but its single-block one does not -- none of
  which a test that only signs and verifies would notice.
* `capsule_sign()` and `capsule_verify()` gained `context`, the context
  string both standards bind into the message encoding, so one key can
  be used for two purposes without a signature crossing between them.
  `capsule_sign()` also gained `deterministic`, selecting the variant
  whose output depends only on key, message and context.
* `oqs_keygen()` and `oqs_public_key()` are deprecated in favour of the
  `fips_*` names and now warn. They still work, and still return the
  same classes.

Every parameter set is checked against OpenSSL 3.5, which shares no code
with this package: in deterministic mode the two produce the SAME BYTES,
over several message and context lengths, and each verifies the other's
signatures. That cross-check is the conformance claim. Reference
parity is not: this implementation matched the pq-crystals and
sphincsplus reference code byte for byte while disagreeing with the
standards twice over -- FIPS 204 and FIPS 205 both prepend a context
domain separator the reference code omits, and FIPS 205 reads the FORS
indices most significant bit first where SPHINCS+ read them least
significant bit first. Neither is detectable from the inside: a
signature scheme that verifies only its own output still rejects every
tampering.

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

## One command for the whole assessment

`capsule_report()` runs the checks above over one data frame and collects
the findings into a single report, ordered by severity: a missing
required column is `fatal`, a drifted column or an unverified signature
is a `warn`, an outlier or a Benford departure is a `note`. It exists
because the failure mode this package is built against is a person
running one check, seeing it pass, and concluding the data is fine.

Each problem is reported ONCE. An entirely missing column is missing, is
trivially constant, and makes any covariance singular; reporting all
three would bury the findings that matter under a single cause. The
collinearity note therefore fires only for a genuinely duplicated or
derived column, which is the case that tells the reader something new.

`report_markdown()` writes the assessment beside the capsule it
describes. Both renderings carry the caveat that no finding is proof of
correctness.

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

## Behaviour changes worth knowing about

Three functions now REFUSE input they previously computed through. In
each case the old answer was a number produced by an internal guard
rather than by the data, which is worse than an error because it looks
like a result.

* `mahalanobis_outliers()` and `mcar_test()` reject exactly collinear or
  constant columns. Both repair a singular covariance by flooring its
  eigenvalues so the algorithm can proceed; with a duplicated column
  that floor, not the data, determined the answer. `mcar_test()` checks
  the complete-case covariance where it can, because two identical
  columns with different missingness leave the pairwise covariance only
  nearly singular.
* `capsule_verify()` rejects a signature presented with a key of a
  different scheme explicitly. It already failed, but incidentally, on a
  length mismatch.

## SIU parser fixes

Four defects in the report parser, each of which produced a wrong field
rather than an error:

* statute sections with a decimal were dropped, so `Section 320.13,
  Criminal Code` -- the ordinary dangerous-driving citation -- never
  reached `relevant_legislation`;
* the director's name and the police service both reached back across a
  line break, so the real signature block `Dated at Toronto.\n\nAlex
  Morrow\nDirector` yielded `"Toronto. Alex Morrow"`, and a force named
  once just under a heading picked the heading up with it;
* only `&amp;`, `&nbsp;` and one smart quote were decoded, so `&lt;`,
  `&gt;`, `&quot;`, `&apos;`, the remaining quotes and the dashes
  survived into the extracted text.

## Statistics for the tables these capsules hold

An open-data extract from a criminal-justice system has a shape the
general-purpose toolkits do not assume: a handful of fiscal years,
counts rather than measurements, categories reported as bands rather
than values, and a region code with no geometry attached.

`yoy()` computes period-over-period change and declines it in the three
cases where the figure would describe something other than the data.
Periods are matched on their own **value**, not on row position, so a
missing year is a gap rather than a quietly multi-year comparison. A
percent off a base below the gate is withheld with its reason recorded
-- two placements becoming twenty is a 900% rise and also nothing at all
-- while the count change and the direction are still reported, those
being facts. A column already in percent is handled in percentage
**points**, a percent of a percent being a different quantity. For
counts the interval is exact: conditional on the two periods' total the
current count is binomial, so the ratio has a Clopper-Pearson interval,
verified identical to `stats::poisson.test` on every case including both
zero boundaries.

* `yoy_write()` renders to HTML, PDF, CSV, TSV, JSON or Markdown, with
  the format taken from the file name; `yoy_html()`, `yoy_pdf()`,
  `yoy_csv()`, `yoy_tsv()`, `yoy_json()` and `yoy_markdown()` are
  available individually. Nothing here needs a package beyond base R:
  the HTML is self-contained and makes no network request, so it renders
  later as it rendered when the capsule was sealed, and the PDF is drawn
  on R's own device and paginates rather than truncating.
* `yoy_summary()` gives the change across the whole span and the
  compound rate per period. `yoy_label()` and `fiscal_year_label()`
  render a fiscal year by the years it spans, so an `EndFiscalYear` of
  2023 prints as `2022/23` rather than naming a calendar year the row is
  not about.
* Colour encodes whether a change is an **improvement**, which is not
  the sign of the change: segregation days rising is bad news and a
  completion rate rising is not. `yoy_palettes()` offers a
  colour-blind-safe pair and a monochrome option for print.

## Categories published as intervals

`parse_bands()` reads the interval labels publishers actually use --
`"2 to 5"`, `"50+"`, `"Greater than 10"`, `"under 18"`, and the whole
dash family -- and returns **bounds**, distinguishing the inclusive
wordings from the exclusive ones: `"65 and over"` starts at 65 and
`"over 65"` at 66, which is a whole unit of the quantity being measured.

* `band_values()` makes the representative-value rule explicit, and
  marks the rows whose value rests on an assumption about the open top
  band, that band having no midpoint to take.
* `band_sensitivity()` reports how far a derived statistic moves as the
  assumed cap varies. Everything computed from banded data carries that
  dependence; the only question is whether it was measured.

## Concentration, association and heavy tails

* `gini()`, `lorenz()` and `top_share()` answer whether a few units
  account for most of a total. Gini is verified both against the
  mean-absolute-difference definition and against twice the area under
  its own Lorenz curve. Its maximum for `n` units is `1 - 1/n`, not 1,
  so the value means different things across ten units and ten thousand.
* `hill_tail_index()` maximises the **exact** discrete likelihood. The
  closed-form continuity correction usually quoted is an asymptotic
  approximation in the threshold, and at a threshold of one -- where
  administrative counts start -- it returns about 2.0 from data
  generated with an exponent of 2.5. It also reports a
  goodness-of-fit distance, because an exponent fitted to a tail that is
  not a power law is a number with no referent.
* `hurwitz_zeta()` is the normalising constant that needs, computed by
  Euler-Maclaurin and verified against `pi^2/6`, `pi^4/90`, Apery's
  constant and the shift identity.
* `cramers_v()` carries Bergsma's bias correction, without which a
  sparse table reports association that is an artefact of its size, and
  permutes its p-value rather than trusting the chi-square
  approximation when an expected count is small.

## Trend in a series of a few periods

* `trend_test()` is Mann-Kendall with a Theil-Sen slope: no
  distributional assumption, resistant to one aberrant period, exact by
  enumeration up to eight periods, and agreeing with
  `stats::cor.test`'s tau and exact p-values.
* `step_change()` scans every admissible split and takes its p-value
  from the permutation distribution of the **maximum** over splits, not
  from the best split's own test -- which is how a break is found in any
  series. It records that six points cannot produce a p-value below
  `(1 + 72) / (1 + 720)` however clean the step.
* `count_trend()` is a Poisson rate ratio per period, matching
  `stats::glm` to 1e-8, with an offset for a varying denominator and a
  widening to quasi-Poisson when the dispersion says the Poisson
  interval is too narrow.

## Region-coded counts

A region is an areal unit with a population, not a coordinate.

* `expected_counts()` does indirect standardisation, removing the part
  of a difference explained by who the area holds. The expected counts
  total the observed ones, which is the identity that makes them a
  standardisation rather than a prediction.
* `sir()` reports the ratio with the exact Poisson interval, identical
  to `stats::poisson.test`'s, including a lower limit of exactly zero at
  an observed count of zero.
* `eb_rates()` is the Clayton-Kaldor empirical Bayes shrinkage, which
  stops a small area's noise from ranking it to the top or bottom of a
  league table. Where the between-area variance estimate is not
  positive there is no evidence of real variation and every estimate
  collapses to the overall rate, reported through total shrinkage rather
  than hidden.
* `funnel_limits()` gives exact Poisson control limits, which stay
  correct at the small expected counts where a normal funnel's lower
  limit goes below zero.
* `morans_i()` requires a neighbour list and does not invent one, an
  extract keyed on a region shipping no geometry. Its null expectation
  is `-1/(n - 1)`, not zero.

Two vignettes cover the lot: *Year-over-year change, and the three ways
it goes wrong* and *Statistics for a published administrative table*.

## Byte compatibility

Every hash, keyed hash, checksum, key derivation, base64 and JSON output
is now compared against an **independent** implementation -- `digest`,
`openssl`, `jsonlite` and base R's own inflater -- over a length sweep
crossing each construction's block boundaries. Published vectors prove a
primitive reproduces a handful of documented inputs; they do not prove
it agrees with the libraries already in a user's pipeline. SHA-256,
SHA-512, HMAC-SHA-256, BLAKE2b, PBKDF2 and the JSON writer were already
exact. Five things were not.

* **Merkle chunks could not hold binary data at all.** Chunks were taken
  as strings and measured with `strlen`, and `chunk_file()` called
  `rawToChar()`, which errors on any file containing a zero byte. A raw
  vector handed in was coerced, so `merkle_root(list(charToRaw("a")))`
  hashed deparsed text and returned a confident digest of the wrong
  thing. Chunks are now bytes end to end, and `chunk_file()` returns a
  list of raw vectors. **Roots for character input are unchanged**, so
  manifests already recorded still verify.
* **`json_gzip_encode()` did not produce gzip.**
  `memCompress(type = "gzip")` emits a zlib stream (RFC 1950, header
  `0x78 0x9c`), not a gzip member (RFC 1952, `0x1f 0x8b`), and
  `memDecompress` reads both -- so the round trip looked correct while no
  external tool could read bytes the documentation calls "raw gzip
  bytes, for writing to a file". Now a real member, with the CRC-32 and
  length trailer, and MTIME pinned to zero so a capsule digest does not
  move with the clock.
* **base64 line-wrapping was off by one byte** at every multiple of 54
  input bytes. The wrap terminates the 54-byte input block, not the
  72-character output, and 52, 53 and 54 bytes all encode to 72
  characters while only 54 fills a block. A field encoded by `jsonlite`
  and re-encoded here differed, and a digest comparison read that as
  drift. Now exact over every length from 0 to 400.
* **`digest_object()` accepted `key` but wired it only to blake2b**, so a
  keyed `sha256`, `sha512` or `crc32` silently returned the *unkeyed*
  digest -- an authentication request answered with a checksum. `sha256`
  now routes to HMAC-SHA-256 and the two algorithms with no keyed form
  refuse the key.
* **`json_gzip_decode()` trusted its flag over its input's type**, so
  handing back what `json_gzip_encode(raw = TRUE)` returned, without
  repeating the flag, ran the bytes through a base64 decode and failed
  inside the inflater.

## Newly reachable through LinkingTo

`gini`, `top_share`, `lorenz`, `mann_kendall`, `theil_sen` and
`hurwitz_zeta` are published with `R_RegisterCCallable` and shimmed in
`inst/include/rmoriebricklayer.h`, so a sibling package reaches them
without going back through R.

A consumer package is now built **and run** against the header as part
of the suite. The two halves fail independently: a signature mismatch is
a compile error, while a wrong name in `R_RegisterCCallable` compiles
perfectly and raises only on first call, `R_GetCCallable` resolving
lazily. That test immediately earned its place by recording a real
requirement -- **`LinkingTo` alone is not enough**. It puts the header on
the include path at compile time but does not load the providing
package, so a consumer needs `Imports: rmoriebricklayer` as well or the
first kernel call raises "function 'rmbl_gini' not provided by package
'rmoriebricklayer'".

## Verification

Everything with a published test vector is checked against it: SHA-512
against FIPS 180-4, HMAC-SHA-256 against RFC 4231, PBKDF2-HMAC-SHA256
against the published vectors including the multi-block case, BLAKE2b
against RFC 7693, and CRC-32 against the ITU V.42 check value. The
statistics are anchored on base R, the Merkle construction on digests
recomputed by hand, and the exceedance and reservoir distributions on
exhaustive enumeration and simulation respectively.

The XMSS signature scheme is **byte-compatible with the RFC 8391
reference implementation**. Getting there required fixing three
divergences from the specification, none of which the previous
security-property tests could detect, because a sound-but-wrong
pseudorandom function passes every one of them:

* the WOTS+ chain seeds came from `PRF(SK_SEED, toByte(i, 32))` rather
  than `PRF_keygen(SK_SEED, PUB_SEED || ADRS)` (NIST SP 800-208's
  domain 4);
* the message digest was keyed with `PUB_SEED`, with the index and root
  pushed into the message, rather than keyed with
  `R || root || toByte(idx, n)` as section 4.1.9 requires;
* there was no `SK_PRF`, so the per-signature randomiser `R` that the
  RFC binds the digest to did not exist at all.

The whole 2500-byte signature for XMSS-SHA2_10_256 -- index,
randomiser, WOTS+ signature and authentication path -- now matches the
reference byte for byte, and the vectors are embedded in the test suite
so the check needs neither a network nor a C toolchain.

**This changes the key and signature formats.** `pqc_keygen()` now
generates a third secret (`sk_prf`) and `capsule_sign()` returns
`randomizer` and `wire` alongside the existing fields. A key made by an
earlier build cannot sign, and a signature made by one cannot be
verified; both raise an explicit error rather than failing quietly.
Nothing is lost in practice, because signing is new in this release and
was never in a version on CRAN.

It is verified against its security properties as well -- a valid
signature verifies, and every tampering of the message, signature,
authentication path, index or key fails -- and it must still not be
treated as *certified*, which is a statement about process rather than
about the bytes. The standardised schemes carry no such
caveat, because they are liboqs's implementation rather than one of
ours; what is tested here is the binding, including that ML-DSA-65
produces the key and signature sizes FIPS 204 specifies.

Everything added in this release is anchored outside itself. The exact
count interval is checked against `stats::poisson.test`, the Poisson
trend against `stats::glm`, Kendall's tau and its exact p-values against
`stats::cor.test`, the funnel limits against `stats::qpois`, Gini
against its own definition and its own Lorenz curve, the Hurwitz zeta
against three published constants and a functional identity, and the
tail-index estimator against samples whose exponent is known by
construction -- the only anchor that can fail, since comparing against
the closed form would compare against the thing being replaced. The
statistical methods are grounded in the local corpus where it has them
(Lawson on standardised incidence ratios and Clayton-Kaldor shrinkage;
Hedderich and Sachs on the Lorenz construction and the indirect/direct
distinction); Bergsma and Clauset-Shalizi-Newman are not in it and are
cited from the published papers, marked as such.

Three source-level invariants are now checked too, because they break
only on platforms the development host is not: that no R header precedes
a standard header reaching libc++'s `<locale>` (R's `length` macro
otherwise rewrites it, which fails on macOS and is silent on Linux),
that every C entry point is registered with a matching arity and every
registration resolves, and that no source file carries a non-ASCII byte.

The suite is 5,300 assertions at 97.6% coverage, and
`R CMD check --as-cran` is clean.

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
