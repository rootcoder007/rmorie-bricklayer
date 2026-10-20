# Package index

## One call for a published table

Analyse a table of counts by period and group in one call: exact
intervals on every change, multiple-comparison adjustment over the scan,
the envelope that rounding and suppression imply, trend, and a drift
screen against the prior capsule; then a report and a capsule template.

- [`anltab()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/anltab.md)
  : Analyse a published administrative table in one call
- [`rptanl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rptanl.md)
  : Write an analysis as a Markdown or HTML report
- [`pubbnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pubbnd.md)
  : Bounds implied by rounding and suppression in a published table
- [`chgenv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chgenv.md)
  : Envelope of a difference, a percent change or a rate under
  publication bounds
- [`yoybnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoybnd.md)
  : Add publication bounds to a year-over-year table
- [`yoypv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoypv.md)
  : Exact p-values for the rows of a year-over-year table
- [`scanadj()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scanadj.md)
  : Adjust a scan of many comparisons for multiple testing
- [`drftcal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftcal.md)
  : Calibrate the drift screens on data known not to have drifted
- [`usecpstmpl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/usecpstmpl.md)
  : Start a capsule from a template

## Fetch open data

Resilient downloaders with libcurl + Wayback fallback for pulling public
datasets over flaky endpoints.

- [`blfetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blfetch.md)
  : Fetch a URL to disk with an Internet Archive fallback (C++/libcurl)
- [`fetchvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fetchvrf.md)
  : Fetch a file from its source or a mirror, verified by its SHA-256
- [`arccap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arccap.md)
  : Capture files the Internet Archive cannot reach, and publish them as
  an archive.org item
- [`siufetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siufetch.md)
  : Fetch an Ontario SIU director's report by drid
- [`dldata()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dldata.md)
  : Download a File
- [`fdl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fdl.md)
  : Download a File With Diagnostic Error Messages

## SIU report mining

Deterministic, offline parse/resolve core for Ontario Special
Investigations Unit director’s reports — schema, parser,
subject-official resolver.

- [`siusch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siusch.md)
  : The panel-reviewed SIU report field schema
- [`siuprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuprs.md)
  : Parse an SIU director's report into the schema fields
- [`siufprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siufprs.md)
  : Fetch and parse one SIU director's report
- [`siutxt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siutxt.md)
  : Convert SIU report HTML to plain text
- [`siudate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siudate.md)
  : Convert a human-readable SIU report date to ISO format
- [`siuso()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuso.md)
  : Resolve the subject-official count from SIU report text

## Portal resolvers

Turn a dataset identifier on a government open-data portal into a direct
resource URL — CKAN, Socrata, ArcGIS, and Wayback snapshots.

- [`rslvckan()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rslvckan.md)
  : Resolve a Download URL via CKAN package_show
- [`rslvckns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rslvckns.md)
  : Resolve a Download URL via CKAN package_search
- [`rslvsoc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rslvsoc.md)
  : Resolve a Download URL via the Socrata Metadata API
- [`rslvarc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rslvarc.md)
  : Resolve a Query URL via ArcGIS FeatureServer Metadata
- [`wbsnpurl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsnpurl.md)
  : Resolve a Wayback Machine snapshot URL
- [`wbsnpnat()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsnpnat.md)
  : Resolve a Wayback Machine snapshot URL (C++/libcurl)
- [`wbsave()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md)
  : Archive many pages in the Wayback Machine
- [`wbrtry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbrtry.md)
  : Retry the failures of a bulk Wayback run

## Provenance & reproducibility capsules

Capture the environment, record a citable data-provenance capsule, and
verify it later so an analysis reproduces from the same inputs.

- [`capenv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capenv.md)
  : Capture the Analysis Environment for a Manifest
- [`citecps()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/citecps.md)
  : Generate a Data Citation From Provenance
- [`vrfcps()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md)
  : Re-Verify an Entire Reproducible Data Capsule
- [`cpschk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpschk.md)
  [`format(`*`<rmbl_cpschk>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpschk.md)
  [`print(`*`<rmbl_cpschk>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpschk.md)
  : Check every capsule under a folder
- [`cpsseal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsseal.md)
  : Pin and sign every capsule under a folder
- [`ghann()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ghann.md)
  [`ghcmt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ghann.md)
  [`ghout()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ghann.md)
  : GitHub workflow annotations, sticky comment and outputs of a capsule
  check
- [`cpsrfrsh()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsrfrsh.md)
  : Fetch a capsule's source again and pin the new bytes
- [`mnfdiff()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfdiff.md)
  [`format(`*`<rmbl_mnfdiff>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfdiff.md)
  [`print(`*`<rmbl_mnfdiff>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfdiff.md)
  : Compare the resources of two manifests
- [`schemapath()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schemapath.md)
  : Path of a JSON Schema shipped with the package
- [`loadprov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loadprov.md)
  : Load a Pinned Data-Provenance Record
- [`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md)
  : Record a Cross-Check Result in a Manifest
- [`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md)
  : Construct a Reproducibility Manifest
- [`mnfcanon()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md)
  [`mnfdgst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md)
  : The canonical serialisation of a manifest, and its digest
- [`mnfrcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfrcmp.md)
  : Recompute a manifest's recorded statistics against the data
- [`mnfrecseed()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfrecseed.md)
  [`mnfrstseed()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfrecseed.md)
  : Record and restore the random number generator state
- [`capdeps()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capdeps.md)
  : Where each loaded package came from
- [`wrmnfjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrmnfjs.md)
  : Write a Manifest to JSON
- [`wrsmrytxt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrsmrytxt.md)
  : Write a Plain-Language Run Summary

## Language model and command line

Language models you bring (a provider’s key, an OpenAI-compatible server
of your own, or a local Ollama), answering from the MORIE packages’
help; the rmoriebricklayer shell command.

- [`agentbndl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agentbndl.md)
  : Agent-assisted reproducibility-bundle help
- [`llmask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md)
  : Ask a language model
- [`explerr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/explerr.md)
  : Explain an error from rmoriebricklayer (or a package built on it)
- [`llmcfg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmcfg.md)
  : Show or save the language-model settings
- [`dlogin()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dlogin.md)
  : Sign in for the curated tables at data.rmorie.com
- [`dlogout()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dlogout.md)
  : Forget the MORIE data key
- [`llmstat()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmstat.md)
  : Report the language-model routes available from this machine
- [`svcs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svcs.md)
  : The hosted MORIE services, as the project site currently describes
  them
- [`llmmdls()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmmdls.md)
  : Models a language-model route offers
- [`llmprvd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmprvd.md)
  : The language-model providers a key can be brought for
- [`llmrte()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmrte.md)
  : The language-model route that would answer
- [`llmchat()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmchat.md)
  : A conversation with a language model
- [`dmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dmnf.md)
  [`dtabs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dmnf.md)
  [`dload()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dmnf.md)
  : Curated datasets at data.rmorie.com
- [`bldl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bldl.md)
  : Download a file with live progress
- [`blprog()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blprog.md)
  : Live progress for long-running work
- [`blcli()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blcli.md)
  : Run the rmoriebricklayer command line
- [`instcli()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/instcli.md)
  : Install the rmoriebricklayer command-line launcher

## JSON (native codec)

jsonlite’s mapping in base R, byte-for-byte; no jsonlite at run time.

- [`fromjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fromjs.md)
  : Parse JSON into R objects (jsonlite's fromJSON, natively)
- [`tojs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tojs.md)
  : Encode an R object as JSON (jsonlite's toJSON, natively)
- [`jsser()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/jsserdoc.md)
  [`jsunser()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/jsserdoc.md)
  : JSON serialisation of an R object, type and attributes included
- [`jsgzenc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/jsgz.md)
  [`jsgzdec()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/jsgz.md)
  : Compressed, base64-encoded JSON
- [`jsb64enc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/b64.md)
  [`jsb64dec()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/b64.md)
  [`jsb64uenc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/b64.md)
  [`jsb64udec()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/b64.md)
  : Base64 encoding

## Integrity & checksums

SHA-256 hashing and verification for downloaded files.

- [`sha256file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256file.md)
  : Compute a File's SHA256 Digest
- [`vrfsha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfsha256.md)
  : Verify a File's SHA256 Against an Expected Digest
- [`csha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md)
  : SHA-256 hex digest (C backend)

## Categorical integrity

Labels that cannot be swapped quietly: name-based recodes that refuse
anything unmapped, explicit levels, an import audit, a before/after
cross-tabulation proof, counts checked against what was published,
reported odds ratios checked under every relabelling, and a signed
manifest of the whole chain.

- [`grdrcd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/grdrcd.md)
  : Recode a categorical column by explicit name-to-name mapping
- [`deccodes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/deccodes.md)
  : Decode numeric category codes with an explicit code-to-label
  dictionary
- [`grdlvls()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/grdlvls.md)
  : Build a factor with explicit, verified levels
- [`audcats()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/audcats.md)
  : Audit the categorical columns of a data frame for coding hazards
- [`vrfrcd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfrcd.md)
  : Prove a recode with a before/after cross-tabulation
- [`vrfmrg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfmrg.md)
  : Verify recoded category counts against the counts a release
  published
- [`orchk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/orchk.md)
  : Check reported odds ratios against a labelled table, under every
  relabelling
- [`relbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relbl.md)
  : Relabel a categorical variable by name, never by position
- [`declbld()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/declbld.md)
  : Decode a labelled import by its value labels, by code
- [`xfrvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/xfrvrf.md)
  : Verify a categorical variable that crossed from one program to
  another
- [`rlblfrns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rlblfrns.md)
  : Name the mechanical step that reproduces a label permutation
- [`grdbin()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/grdbin.md)
  : Refuse a categorical column where a numeric 0/1 treatment is
  required
- [`rcdmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rcdmnf.md)
  : Record a recode as a manifest that can be signed and verified later
- [`wrrcdmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrrcdmnf.md)
  [`vrfrcdmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrrcdmnf.md)
  : Write and verify a recode manifest

## Categorical integrity

Labels that cannot be swapped quietly: name-based recodes that refuse
anything unmapped, explicit levels, an import audit, a before/after
cross-tabulation proof, counts checked against what was published,
reported odds ratios checked under every relabelling, and a signed
manifest of the whole chain.

- [`grdrcd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/grdrcd.md)
  : Recode a categorical column by explicit name-to-name mapping
- [`deccodes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/deccodes.md)
  : Decode numeric category codes with an explicit code-to-label
  dictionary
- [`grdlvls()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/grdlvls.md)
  : Build a factor with explicit, verified levels
- [`audcats()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/audcats.md)
  : Audit the categorical columns of a data frame for coding hazards
- [`vrfrcd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfrcd.md)
  : Prove a recode with a before/after cross-tabulation
- [`vrfmrg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfmrg.md)
  : Verify recoded category counts against the counts a release
  published
- [`orchk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/orchk.md)
  : Check reported odds ratios against a labelled table, under every
  relabelling
- [`grdbin()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/grdbin.md)
  : Refuse a categorical column where a numeric 0/1 treatment is
  required
- [`rcdmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rcdmnf.md)
  : Record a recode as a manifest that can be signed and verified later
- [`wrrcdmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrrcdmnf.md)
  [`vrfrcdmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrrcdmnf.md)
  : Write and verify a recode manifest

## Schema validation & synthetic data

Validate a data frame against a declared schema, and build typed
synthetic columns/CSVs for tests and documentation.

- [`schval()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schval.md)
  : Apply Schema Validation, Stopping on Fatal Issues
- [`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md)
  : Validate a Data Frame Against a Provenance Schema
- [`mksyncol()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncol.md)
  : Generate One Synthetic Column From a Spec
- [`mksyncsv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncsv.md)
  : Generate a Synthetic CSV From a Schema Recipe

## Text & encoding utilities

ASCII transliteration and safe text fallbacks for non-UTF-8 sinks.

- [`toascii()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/toascii.md)
  : Transliterate Text to Plain ASCII
- [`asciifb()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/asciifb.md)
  : Use Text As-Is, Falling Back to ASCII When It Cannot Be Represented
- [`wrtxtfb()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrtxtfb.md)
  : Write Text as UTF-8, Falling Back to ASCII on an Encoding Error

## Core numeric primitives

Thin R wrappers over the shared compiled core that the whole ecosystem
links against via `LinkingTo: rmoriebricklayer`, so every sibling
package computes with one copy of the arithmetic.

- [`cmn()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cstat.md)
  [`cvari()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cstat.md)
  [`ccorr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cstat.md)
  : Fast summary statistics (C backend)
- [`cnormpdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnormpdf.md)
  : Normal density (C backend)
- [`cnormlpdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnormlpdf.md)
  : Normal log-density (C backend)
- [`csdev()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cspread.md)
  [`cdistm()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cspread.md)
  : Standard deviation and Euclidean distance (C backend)
- [`cmom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cmom.md)
  : Mean, variance, skewness and kurtosis (C backend)
- [`cqnt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crob.md)
  [`cmed()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crob.md)
  [`cmad()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crob.md)
  [`ciqr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crob.md)
  [`ctkyfnc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crob.md)
  : Quantiles, median and robust spread (C backend)
- [`ctrmmean()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ctrm.md)
  [`cwinsmean()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ctrm.md)
  : Trimmed and winsorized means (C backend)
- [`cwtd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cwtd.md)
  : Weighted mean and variance (C backend)
- [`cspr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crank.md)
  [`cmidrk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crank.md)
  : Rank correlation and midranks (C backend)
- [`ccovm()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ccovm.md)
  : Covariance matrix of a numeric matrix (C backend)
- [`cbootmean()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cbootmean.md)
  : Bootstrap replicate means (C backend)
- [`cipw()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cipw.md)
  : Trimmed inverse-probability weights (C backend)
- [`cgamcdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cgamcdf.md)
  : Regularized incomplete gamma function (C backend)
- [`chwknll()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwknll.md)
  : Hawkes-process negative log-likelihood (C backend)
- [`chwkfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwkfit.md)
  : Fit a Hawkes process by maximum likelihood (analytic gradient, fast
  routes)
- [`chwkres()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwkres.md)
  : Time-rescaling residuals of a Hawkes process
- [`cunif()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cunif.md)
  : Reproducible uniforms shared with morie's Python arm (splitmix64)
- [`chwkjit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwkjit.md)
  : Spread event times recorded to a resolution across their interval

## Distributional drift

Whether a freshly fetched column is still the column the capsule was
pinned against. A byte digest cannot answer this: a re-release can be
statistically identical yet differ byte-for-byte, and a column can keep
its name and type while having been silently rescaled.

- [`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
  : Compare a fetched data frame with the one a capsule was pinned
  against
- [`drftks()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftks.md)
  : Two-sample Kolmogorov-Smirnov test (C backend)
- [`drftpsi()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftpsi.md)
  : Population stability index and Jensen-Shannon divergence (C backend)
- [`drftchisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftchisq.md)
  : Chi-square test for a categorical column
- [`drfthomog()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drfthomog.md)
  : Chi-square test of homogeneity for two categorical samples
- [`benfordtst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/benfordtst.md)
  : Benford first-digit test
- [`drfthtml()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drfthtml.md)
  : Interactive drift report as one HTML file
- [`drftapp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftapp.md)
  : Drift report as a Shiny app

## Signed provenance

Authenticated rather than merely checksummed. Keyed digests for a shared
secret, post-quantum hash-based signatures for a public verifier, Merkle
trees to pin a capsule chunk by chunk, and hash chains to make the run
history itself tamper-evident.

- [`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)
  [`cpschkatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)
  : Attest a capsule, binding a signature to what it covers
- [`cpsbndl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md)
  [`cpsbndlrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md)
  [`cpsbndlvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md)
  : Bundle a capsule into one signed artifact
- [`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md)
  : Run falsification controls against a statistic
- [`cpspwr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpspwr.md)
  : Detect an injected effect of known size
- [`prrgdecl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prrgdecl.md)
  [`prrgchk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prrgdecl.md)
  : Declare an analysis before running it
- [`falsfam()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/falsfam.md)
  : Correct a family of falsification results for multiple testing
- [`evlrr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evlrr.md)
  : How strong would an unmeasured confounder have to be
- [`tsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md)
  [`tsinfo()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md)
  : Verify an RFC 3161 timestamp token
- [`certprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certprs.md)
  : Parse an X.509 certificate
- [`certchnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certchnvrf.md)
  : Verify a certificate chain
- [`rvkfetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rvkfetch.md)
  : Fetch revocation data for a certificate path
- [`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
  : Sign a capsule manifest
- [`xmssadv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/xmssadv.md)
  [`xmssregkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/xmssadv.md)
  [`xmssfgt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/xmssadv.md)
  : Advance an XMSS key past a signature it made
- [`cpsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsvrf.md)
  : Verify a capsule manifest signature
- [`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md)
  : Generate a post-quantum signing key for capsule provenance
- [`signpubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/signpubkey.md)
  : Public half of a signing key
- [`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
  [`fipspubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
  : Generate a standardised post-quantum signing key
- [`fipskey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskey.md)
  : Assemble a standardised key from raw key material
- [`fipsmu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipsmu.md)
  [`fipssignmu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipsmu.md)
  [`fipsvrfmu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipsmu.md)
  : Sign an ML-DSA message digest computed elsewhere
- [`fipssz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipssz.md)
  : Byte lengths of a standardised signature scheme
- [`kemkg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemkg.md)
  [`kempubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemkg.md)
  : Generate an ML-KEM key pair
- [`kemsz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemsz.md)
  : Byte lengths of an ML-KEM parameter set
- [`kemencap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemencap.md)
  : Encapsulate a shared secret under an ML-KEM key
- [`kemdecap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemdecap.md)
  : Recover a shared secret from an ML-KEM ciphertext
- [`hqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqckg.md)
  [`hqcpubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqckg.md)
  : Generate an HQC key pair
- [`hqcsz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcsz.md)
  : Byte lengths of an HQC parameter set
- [`hqcencap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcencap.md)
  : Encapsulate a shared secret under an HQC key
- [`hqcdecap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcdecap.md)
  : Recover a shared secret from an HQC ciphertext
- [`hqccmpkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqccmpkey.md)
  : The compressed HQC decapsulation key
- [`oqskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/oqskg.md)
  [`oqspubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/oqskg.md)
  : Generate a standardised post-quantum signing key (deprecated name)
- [`pqcbknd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqcbknd.md)
  : Available post-quantum signature schemes
- [`chnnew()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chn.md)
  [`chnapp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chn.md)
  [`chnhead()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chn.md)
  [`chnseal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chn.md)
  [`chnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chn.md)
  : Tamper-evident chain of capsule manifests
- [`mrkroot()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mrk.md)
  [`mrklvs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mrk.md)
  [`mrkprf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mrk.md)
  [`mrkvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mrk.md)
  : Merkle tree over capsule chunks (C backend)
- [`chnkfile()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chnkfile.md)
  : Split a file into fixed-size chunks

## Digests and keys

The hashes and key-derivation the provenance layer is built on, each
verified against its published test vectors.

- [`csha512()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha512.md)
  : SHA-512 hex digest (C backend)
- [`ccrc32()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ccrc32.md)
  : CRC-32 checksum (C backend)
- [`cblake2b()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cblake2b.md)
  : BLAKE2b digest, optionally keyed
- [`chmac()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/keyeddgst.md)
  [`cdgsteq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/keyeddgst.md)
  : Keyed digest and constant-time comparison (C backend)
- [`sha512file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/filedgst.md)
  [`crc32file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/filedgst.md)
  : SHA-512 and CRC-32 of a file
- [`dgstobj()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dgstobj.md)
  : Digest an arbitrary R object
- [`rndbytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rndbytes.md)
  : Cryptographically strong random bytes
- [`drbgnew()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbgnew.md)
  : A deterministic random bit generator: AES-256 CTR_DRBG (NIST SP
  800-90A)
- [`drbggen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbggen.md)
  : Draw bytes from a DRBG
- [`drbgrsd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbgrsd.md)
  : Reseed a DRBG
- [`drvkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drvkey.md)
  : Derive a key from a passphrase

## Schema and rules

Derive a pinnable schema from data you already trust, then declare the
project-specific checks a generic schema cannot express.

- [`infsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infsch.md)
  : Infer a pinnable schema from a data frame
- [`rul()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rul.md)
  : Declare a validation rule
- [`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md)
  : Apply declared rules to a data frame
- [`ruleinset()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
  [`rulebtw()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
  [`rulenull()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
  [`ruleuniq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
  [`rulerx()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
  [`ruleincr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
  [`rulemad()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
  [`rulecmpl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
  [`ruledstn()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
  [`rulecolcnt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
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
- [`yoysmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoysmry.md)
  : Summarise a change table
- [`yoylbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoylbl.md)
  : Label a period without changing it
- [`fylbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fylbl.md)
  : Name a fiscal year by the years it spans
- [`yoyhtml()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoyren.md)
  [`yoypdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoyren.md)
  : Render a change table to HTML or PDF
- [`yoywr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoywr.md)
  : Write a change table to a file, in whatever format the name implies
- [`yoycsv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoydelim.md)
  [`yoytsv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoydelim.md)
  [`yoyjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoydelim.md)
  [`yoymd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoydelim.md)
  : Write a change table as delimited text, JSON or Markdown
- [`yoypals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoypals.md)
  : Colour palettes for change tables

## Stock and flow over time

Person-days are one quantity with two denominators. Divided by TIME they
give the average daily population, a stock: how many are held at once.
Divided by PEOPLE they give the average length of stay. When stay length
moves the two can carry opposite signs, so a report quoting one implies
the wrong direction for the other. After Lakner (1976), A Manual of
Statistical Sampling Methods for Corrections Planners.

- [`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md)
  : Average daily population
- [`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)
  : Average length of stay
- [`admits()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/admits.md)
  : Admissions implied by a population and a length of stay
- [`adpcnts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adpcnts.md)
  : Person-days estimated from periodic headcounts
- [`stkflow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stkflow.md)
  : Stock and flow side by side, with the decomposition
- [`staysmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/staysmry.md)
  : Length of stay with its distribution and interval
- [`perdays()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/perdays.md)
  : Period length in days, from dates

## Rates, shares and rate change

A count is not comparable across places of different size or years of
different population, and a share of a total is not a rate per
population – labelling one as the other is the most common error in a
published table, so they are separate functions with separate intervals.
Rates carry the exact Poisson interval, shares carry Wilson-s, and the
change in a rate conditions on the two counts and corrects for the
exposure ratio rather than treating two rates as measured numbers.

- [`rtcalc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rtcalc.md)
  : Event rates per unit of population
- [`shrs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/shrs.md)
  : Share of a total, in percent
- [`ratechg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ratechg.md)
  : Change in a rate between periods

## Banded categories

Published categories are intervals – “2 to 5”, “50+” – and anything
computed from them rests on where inside each band the mass sits and on
where the open top band ends. These parse to bounds, make the
representative-value rule explicit, and measure how far a result moves
as the open band’s assumed cap varies.

- [`prsbands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prsbands.md)
  : Parse banded category labels into numeric bounds
- [`bandvals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandvals.md)
  : Representative values for banded categories
- [`expbands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expbands.md)
  : Expand a banded frequency table into per-unit values
- [`bandsens()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandsens.md)
  [`print(`*`<rmbl_band_sensitivity>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandsens.md)
  : How much a result depends on the open band's assumed cap

## Concentration and association

Whether a few units account for most of a total, and how strongly two
categorical variables move together. Gini is twice the area under its
own Lorenz curve, and has a ceiling of 1 - 1/n rather than 1. The tail
index maximises the exact discrete likelihood, the closed-form
continuity correction being badly biased at the small thresholds
administrative counts start from.

- [`ginicoef()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
  [`lorenzc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
  [`topshr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
  : Concentration of a total across units
- [`hilltlidx()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hilltlidx.md)
  : Tail index of a heavy-tailed count
- [`hurwzeta()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hurwzeta.md)
  : Hurwitz zeta function
- [`cramerv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cramerv.md)
  : Association in a contingency table

## Trend in a short series

An annual extract is five to ten points, which supports a rank test and
a resistant slope but not a model with an autocorrelation structure. The
step test takes its p-value from the permutation distribution of the
maximum over splits, not from the best split’s own test.

- [`trndtst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trndtst.md)
  : Trend in a short series
- [`stepchg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stepchg.md)
  : A single step change, with the scan's own null distribution
- [`cnttrnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnttrnd.md)
  : Trend in a count series, as a rate ratio per period

## Air pollution, dispersion and health burden

Pasquill-Gifford dispersion and Briggs plume rise, Gaussian plume and
puff, grid and particle models; concentration-response functions,
attributable fraction, displaced mortality, the burden chain per area,
the concentration index of exposure by income, a cross-fitted
exposure-response estimator, and the one-call pipeline with its
assumption log.

- [`pgsig()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md)
  [`briggs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md)
  [`gplume()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md)
  [`gspuff()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md)
  [`advdif2d()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md)
  [`lagrprt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md)
  : Atmospheric dispersion: sigmas, plume rise, plume, puff, grid and
  particles
- [`crfpm25()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crfpm25.md)
  [`crfno2()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crfpm25.md)
  : Concentration-response functions for PM2.5 and NO2
- [`attrfrac()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/attrfrac.md)
  : Population attributable fraction
- [`mortdisp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mortdisp.md)
  : Deaths avoided under a counterfactual exposure reduction
- [`polbrdn()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md)
  : End-to-end pollution burden
- [`polbrdarea()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdarea.md)
  : Per-area pollution burden
- [`plrcf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plrcf.md)
  : Cross-fitted partially linear regression (double machine learning)
- [`exprspplr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/exprspplr.md)
  : Exposure-response estimate with a bootstrap sensitivity interval
- [`expconcidx()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expconcidx.md)
  : Concentration index of exposure by income
- [`vrfpol()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfpol.md)
  [`polrpttxt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfpol.md)
  : Run the pollution-to-health pipeline and report it
- [`plmfld()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plmfld.md)
  : A Gaussian-plume concentration field on a grid

## Courts and police-reported crime

Case flow and clearance through a court, time to disposition from banded
shares, the mix of outcomes, the change in a clearance rate split into
rate and case-mix effects (Simpson’s paradox), where incidents cluster,
and near-repeat space-time clustering; with real Ontario Court of
Justice and Toronto Police Service data.

- [`caseflow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/caseflow.md)
  : Case flow through a court: clearance, backlog and time to clear
- [`lifetbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/lifetbl.md)
  : Life table for grouped times: how long cases take
- [`dispmix()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dispmix.md)
  : The mix of outcomes over time, with simultaneous intervals and trend
  tests
- [`clrdcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/clrdcmp.md)
  : Decompose a change in a clearance rate into rate and case-mix
  effects
- [`crmdens()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crmdens.md)
  : Where incidents cluster: a kernel density surface
- [`hotpers()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hotpers.md)
  : Hot spots and how long they last
- [`knoxtst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/knoxtst.md)
  : Near-repeat analysis: the Knox test for space-time clustering
- [`justice-data`](https://rootcoder007.github.io/rmorie-bricklayer/reference/justice-data.md)
  : Court and police data shipped with the package

## Evaluating a policy

Difference in differences with two-way fixed effects, event studies,
staggered adoption (Callaway and Sant’Anna; Wooldridge), the
Goodman-Bacon decomposition, switching treatments, permutation inference
and Westfall-Young stepdown p-values, fixed-effects Poisson, synthetic
control; severity-weighted crime indices, justice-pipeline rates,
cumulative risk of a first event, and place-based buffers.

- [`plndid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md)
  : Difference in differences with two-way fixed effects
- [`evstudy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md)
  : An event study: the effect period by period around adoption
- [`stgatt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stgatt.md)
  : Effects of a policy adopted at different times
- [`bacondcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bacondcmp.md)
  : The Goodman-Bacon decomposition of a two-way fixed-effects estimate
- [`swtdid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/swtdid.md)
  : Difference in differences for treatments that switch on and off
- [`perminf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/perminf.md)
  : Permutation inference for a policy's adoption
- [`stpdnpv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stpdnpv.md)
  : Westfall-Young stepdown p-values
- [`plnpois()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plnpois.md)
  : A fixed-effects Poisson or negative binomial regression for counts
- [`synctl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/synctl.md)
  : Synthetic control for one treated unit
- [`sevidx()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sevidx.md)
  : A severity-weighted crime index
- [`piperate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/piperate.md)
  : Justice-pipeline rates with a lag between stages
- [`cmlrisk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cmlrisk.md)
  : Cumulative risk of a first event by age
- [`bufasgn()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bufasgn.md)
  : Treated, comparison and excluded places around sites
- [`polex()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polex.md)
  : A simulated policy panel for the examples
- [`plotevgrid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotevgrid.md)
  : Event studies for several outcomes in one grid
- [`loounit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loounit.md)
  : Leave-one-out estimates of a difference in differences
- [`cohtrnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cohtrnd.md)
  : Raw outcome trends by adoption cohort

## Causal estimation on panels

Double machine learning with fixed effects (lasso, ridge or any learner,
cross-fitted by unit), matching on pre-treatment trajectories, synthetic
difference in differences, the wild cluster bootstrap for few clusters,
sensitivity to departures from parallel trends, and design-based power.

- [`plndml()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndml.md)
  : Double machine learning for panels with fixed effects
- [`aipwcf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/aipwcf.md)
  : Cross-fitted augmented inverse probability weighting for a binary
  treatment
- [`mtchdid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mtchdid.md)
  : Difference in differences after matching on pre-treatment
  trajectories
- [`baltab()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/baltab.md)
  : A covariate balance table
- [`syndid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/syndid.md)
  : Synthetic difference in differences
- [`wcb()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wcb.md)
  : The wild cluster bootstrap for a difference in differences with few
  clusters
- [`tse()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tse.md)
  : How far parallel trends can fail before an effect disappears
- [`plnpwr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plnpwr.md)
  : Power and minimum detectable effect of a difference-in-differences
  design

## First Nations, Metis and Inuit health

Statistics Canada tables read as published (suppressed cells never
imputed), distinctions-based comparisons, age-standardised rates,
intergenerational exposure, and the Truth and Reconciliation Commission
Calls to Action.

- [`sctidy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sctidy.md)
  : Read a Statistics Canada table as published
- [`qltyrcd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/qltyrcd.md)
  : Recode another agency's quality flags to the package's
- [`limfrom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/limfrom.md)
  : Confidence limits from a standard error, a coefficient of variation
  or a margin of error
- [`indgap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indgap.md)
  : Compare published group estimates with a reference group
- [`agestd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agestd.md)
  : Directly age-standardised rates, with Fay-Feuer gamma intervals
- [`rategap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rategap.md)
  : The gap between two standardised rates
- [`genexpo()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/genexpo.md)
  : Generations of residential school attendance in a family
- [`exptrnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/exptrnd.md)
  : A dose-response across generations of exposure
- [`trccmpl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trccmpl.md)
  : Calls to Action completed, year by year
- [`trcprog()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trcprog.md)
  : How fast the Calls to Action are being completed
- [`trcind()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trcind.md)
  : The indicators of Calls to Action 19 and 55, and the tables that
  measure them
- [`trchlthgap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trchlthgap.md)
  : The Call to Action 19 health gaps, in one place
- [`indtabs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indtabs.md)
  : The Indigenous health and wellbeing tables the data service holds
- [`indiex()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indiex.md)
  : First Nations, Metis and Inuit health and mental health: bundled
  Statistics Canada excerpts

## First Nations, Metis and Inuit mental health and wellness

Survey estimates taken out of a table with their limits, rated scales
compared as whole distributions, age-standardised percentages, and
wellness reported beside distress; Indigenous frameworks of mental
wellness put to work as estimators (holistic balance, the four
directions of the First Nations Mental Wellness Continuum, healing as
change, connection across places, community-set weights), the Community
Well-Being index, a test before pooling, and an audit of deficit
framing.

- [`scests()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scests.md)
  : The estimates of a Statistics Canada table, with their confidence
  limits
- [`ordcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ordcmp.md)
  : Compare rated scales (perceived mental health, life satisfaction)
  between groups
- [`stdprev()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdprev.md)
  : Age-standardise survey percentages
- [`welprof()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md)
  : Wellness beside distress: a strengths-first profile of published
  indicators
- [`dualcont()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dualcont.md)
  : Wellness and distress as two continua
- [`holbal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/holbal.md)
  : Holistic balance: how evenly wellness is held across the domains of
  a whole person
- [`mhcont()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mhcont.md)
  : The four directions of the First Nations Mental Wellness Continuum,
  from published indicators
- [`healchg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/healchg.md)
  : Healing as a process: change in published indicators between two
  periods
- [`connassoc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/connassoc.md)
  : Connection across places: does one indicator rise where another
  does?
- [`commidx()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/commidx.md)
  : A community-weighted index of protective and risk factors
- [`dstntst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstntst.md)
  : Do distinct groups differ? A heterogeneity test before pooling
- [`cwbscr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cwbscr.md)
  : The Community Well-Being index of a community
- [`frmaud()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/frmaud.md)
  : How deficit-framed is a set of results?

## The 2021 Census Indigenous Population Profile

The census profile read with its hierarchy, symbols and sample; shares
with intervals that carry the long-form sample and random rounding; an
Indigenous standard population; and a Community Well-Being score from
public figures.

- [`cnsprof()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnsprof.md)
  : Read the 2021 Census Indigenous Population Profile
- [`profshr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profshr.md)
  : The share of a population with a characteristic, from the census
  profile
- [`cnsstd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnsstd.md)
  : An Indigenous standard population from the census
- [`cnscwb()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnscwb.md)
  : A Community Well-Being score from the census profile

## Complex survey estimation

Design-based means, totals, proportions and ratios, overall and by
domain, with variances from replicate weights (Statistics Canada
bootstrap, mean bootstrap, jackknife, BRR, Fay) or Taylor linearization
over strata and PSUs, and design-based comparisons between domains.

- [`svydes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svydes.md)
  : Describe a complex survey design
- [`svyest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svyest.md)
  : Estimate a mean, total, proportion or ratio from a survey design
- [`svycmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svycmp.md)
  : Compare survey estimates between domains
- [`sprd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sprd.md)
  : Variance and standard deviation with the right correction, and why

## The footprint of the computation

Electricity and CO2-equivalent of an expression, measured from RAPL
energy counters where the operating system exposes them, otherwise
modelled with the Green Algorithms method, against a sourced
carbon-intensity table.

- [`co2fp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md)
  : Energy and carbon footprint of a computation
- [`co2int()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2int.md)
  [`co2inttab()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2int.md)
  : Carbon intensity of electricity by location, offline, anywhere
- [`dtctloc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dtctloc.md)
  : Where is this computation running?
- [`raplok()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/raplok.md)
  : Is CPU energy measurable here?
- [`fpeqv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fpeqv.md)
  : Everyday equivalents of a quantity of CO2-equivalent

## Region-coded counts

A region is an areal unit with a population, not a coordinate. Indirect
standardisation removes the part of a difference explained by who the
area holds; empirical Bayes stops a small area’s noise from ranking it
to the top or bottom; a funnel plot shows the reader the same thing
directly.

- [`expcnts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expcnts.md)
  : Expected counts under indirect standardisation
- [`stdinc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdinc.md)
  : Standardised incidence ratio, with an exact interval
- [`ebrates()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ebrates.md)
  : Empirical Bayes rates, shrunk toward the overall experience
- [`fnllim()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fnllim.md)
  : Funnel-plot control limits
- [`morani()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/morani.md)
  : Global Moran's I over a neighbour list

## Points, and the regions that contain them

A region map from point locations to statistical regions is built once
and read many times, so an error in it reproduces downstream instead of
showing up there. These check it three ways: that it is internally
sound, that a recomputation agrees with it cell by cell, and that an
assignment derived a DIFFERENT way agrees too, which is the only one of
the three that can catch an error in the original method. The coverage
summary reports what share of the population lives in a region holding a
unit, and says each time that the share is context rather than a rate
denominator: units serve catchments, which a point location does not
state.

- [`rgncov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgncov.md)
  : Population of the regions that contain a unit, and of those that do
  not
- [`rgnmapintg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapintg.md)
  : Internal soundness of a region map
- [`rgnmapcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapcmp.md)
  : Compare a recomputed region map against a published one
- [`rgnmapalt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapalt.md)
  : Check a region map against an independently derived assignment
- [`rgnmappts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmappts.md)
  : Recompute a region map by point in polygon

## Describe a capsule

The summaries worth reading before trusting a capsule: what every column
looks like, where the gaps are, which values dominate, and which rows do
not belong.
[`cpsrpt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsrpt.md)
runs the lot and orders the findings by severity.

- [`cpsrpt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsrpt.md)
  : Assess a capsule in one call
- [`rptmd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rptmd.md)
  : Write a capsule report as Markdown
- [`profcols()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profcols.md)
  : Column report for a data frame
- [`inlhist()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/inlhist.md)
  : Inline histogram for a numeric vector
- [`freqtbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/freqtbl.md)
  : Frequency table for one column
- [`cortbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cortbl.md)
  : Full pairwise correlation table
- [`topcors()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/topcors.md)
  : Strongest pairwise correlations in a data frame
- [`mahaoutl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mahaoutl.md)
  : Multivariate outliers by Mahalanobis distance
- [`duprows()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/duprows.md)
  : Duplicated rows, with their groups
- [`drpempty()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drp.md)
  [`drpconst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drp.md)
  : Drop empty or constant columns and rows
- [`clncolnms()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/clncolnms.md)
  : Tidy the column names of an ingested table
- [`envdiff()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/envdiff.md)
  : Compare two captured environments

## Missingness

Not just how much is missing, but the shape of it – which columns go
together, whether the gaps are contiguous, and whether the missingness
is related to the data (in which case dropping incomplete rows is
biased).

- [`misssmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/misssmry.md)
  : Missingness in one line per question
- [`misspat()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/misspat.md)
  : Which columns are missing together
- [`missruns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missruns.md)
  : Runs of consecutive missing values
- [`missgrid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missgrid.md)
  : Text map of where the missing values are
- [`mcartst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mcartst.md)
  : Little's test for data missing completely at random

## Large capsules

One-pass algorithms for members bigger than memory: exact block-wise
moments, uniform sampling of a stream, and fixed-memory distinct counts.

- [`onlsmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/onl.md)
  [`smryupd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/onl.md)
  [`smrymrg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/onl.md)
  [`smrystat()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/onl.md)
  : Summary statistics accumulated in blocks
- [`rsvidx()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rsv.md)
  [`rsvsmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rsv.md)
  : Uniform sample of a stream in one pass
- [`dstnskch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstn.md)
  [`dstncnt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstn.md)
  [`skchmrg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstn.md)
  : Distinct-value count in fixed memory

## Output

Printed reports for the objects the package returns.

- [`print(`*`<bricklayer_attestation>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_attestation_check>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_bundle>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_bundle_check>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_chain>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_drbg>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_falsification>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_hqc_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_hqc_public_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_hqc_capsule>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_kem_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_kem_public_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_kem_capsule>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_mcar>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_power>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_prereg>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_prereg_check>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_falsify_family>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_drift>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`summary(`*`<bricklayer_drift>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_benford>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_signing_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_public_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_signature>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`summary(`*`<bricklayer_benford>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_env_diff>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_report>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`summary(`*`<bricklayer_report>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_recompute>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_schema>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_oqs_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_oqs_public_key>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_timestamp>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_certificate>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  [`print(`*`<bricklayer_certpath_check>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/printmeth.md)
  : Printed reports for bricklayer objects

## Plots

Every result draws itself with plot(), on base graphics, with one shared
look and the same customisation everywhere; palettes and session
options; Lorenz and funnel plots for results that are plain data frames.

- [`plot(`*`<rmbl_census_cwb>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_profile_share>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_hotspot>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_connection>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_healing_change>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_community_index>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_indigenous_gap>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_prevalence>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_dsr>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_exposure_trend>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_trc_progress>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_ordinal_compare>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_wellness_profile>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_holistic_balance>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_dual_continuum>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_distinctions>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_case_flow>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_life_table>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_disposition_mix>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_density>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_knox>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_clearance_decomposition>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_synthdid>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_power>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_balance>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_aipw>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_stock_flow>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_yoy>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_rate>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_share>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_rate_change>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_band_sensitivity>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_drift_calibration>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<bricklayer_drift>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<bricklayer_benford>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<bricklayer_power>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<bricklayer_freq>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<bricklayer_missingness>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_region_coverage>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<bricklayer_outliers>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<bricklayer_correlations>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<bricklayer_cortable>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<bricklayer_falsification>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_bounds>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_crf>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_burden>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_equity>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_pollution_report>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_footprint>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_field>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_particles>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_count_trend>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<bricklayer_analysis>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_event_study>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_staggered_att>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_synth>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_bacon>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_permutation>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_loo>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_cohort_trends>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_svy_estimate>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_svy_compare>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  [`plot(`*`<rmbl_trc_gaps>`*`)`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)
  : Plot methods for the package's results
- [`blpal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blpal.md)
  [`plotopt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blpal.md)
  : Plot styling for the package's plot methods
- [`plotlrnz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotlrnz.md)
  [`plotfnl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotlrnz.md)
  : Lorenz and funnel plots
