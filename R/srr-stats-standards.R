#' srr_stats
#'
#' rOpenSci statistical software standards that hold for the package as a whole, those that
#' do not apply, and those still to be met. Standards met by one function are tagged in that
#' function's own roxygen block.
#'
#' @srrstatsVerbose TRUE
#'
#' @srrstats {G1.0} 37 R files carry @references to primary literature (e.g. trend.R: Sen 1968 JASA; concentration.R: Hedderich & Sachs 2020).
#' @srrstats {G1.3} Exported functions define their terms and estimators in @details with formulas (e.g. svyest mean/total/ratio, ginicoef Gini, cmn n-1 variance).
#' @srrstats {G1.4} All exports are documented with roxygen2 (DESCRIPTION Roxygen: markdown = TRUE; man/ is generated).
#' @srrstats {G1.6} Results are checked against other implementations: survey package (test-survey.R), digest/openssl (test-byte-parity.R), OpenSSL 3.5 vectors (test-fips-*.R).
#' @srrstats {G2.4} Explicit conversions are centralised in R/aaa_input_guards.R (.rmbl_num, .rmbl_scalar) and the categorical decoders; see G2.4a-e.
#' @srrstats {G5.2} There are about 2,200 expect_error/expect_warning/expect_message calls across 159 test files.
#' @srrstats {G5.2b} Tests trigger the refusals and match the message text (e.g. test-input-contracts.R, test-docs-bugs-0513.R, test-cran-stress-*.R).
#' @srrstats {G5.4} Correctness tests against the survey package, Lakner's published examples and closed forms; see G5.4a-c.
#' @srrstats {G5.10} Network/extended tests are switched on by RMBL_LIVE_TESTS=1 inside the same testthat suite (test-fetch-native.R, test-coverage-0_5_9-c.R).
#' @srrstats {G5.11} Live tests fetch their assets (CRAN mirror, archive.org snapshots) during the test run instead of shipping them.
#' @srrstats {G5.11a} skip_if_no_internet()/online_now() skip with a message ("no internet", "no network") when a download fails.
#' @srrstats {EA1.3} Every export's @param gives the accepted input type (for example yoy x: data frame, numeric vector or ts; ginicoef x: non-negative numeric vector).
#' @srrstats {EA6.0} 159 testthat files check return values: classes, dimensions, names and numeric values against reference computations.
#' @srrstats {EA6.0a} expect_s3_class/expect_type in 63 test files, for example test-analyse-table.R:110-133 and test-yoy.R:14.
#' @srrstats {EA6.0b} About 190 nrow/ncol/dim expectations, for example test-print-methods.R:149 and test-plots.R.
#' @srrstats {EA6.0c} Column names are tested, for example test-print-methods.R:150 (profcols) and test-plots.R:47 (names of the drawn frame).
#' @srrstats {EA6.0e} 253 expect_equal calls give an explicit tolerance (for example test-yoy.R:67, tolerance = 1e-9); the rest use testthat edition 3's default tolerance.
#' @srrstats {EA6.1} Each plot method returns the data it drew, and tests check it; label and size helpers are tested with mocked title() (test-plots.R, test-plot-fit-1_0_0.R).
#'
#' @srrstatsNA {G1.5} No associated publication is cited in inst/CITATION. README's OTIS recomputation (examples/otis-mrp/) is in the repo, not the tarball.
#' @srrstatsNA {G2.14c} Imputation is deliberately excluded: published tables' suppressed cells are never imputed (comment at top of R/indigenous.R).
#' @srrstatsNA {EA2.0} The package does no extensive table filtering or joining; its only internal merge fills missing periods into one user table.
#' @srrstatsNA {EA2.1} No index-column system, because no multi-table joins (EA2.0 NA); yoy collapses duplicate period/group keys with an explicit `fun`.
#' @srrstatsNA {EA2.2} No index columns, for the reason given under EA2.0.
#' @srrstatsNA {EA2.2a} No index columns, for the reason given under EA2.0.
#' @srrstatsNA {EA2.2b} No index columns, for the reason given under EA2.0.
#' @srrstatsNA {EA2.4} No multi-table relational input, so a dm-style class system does not apply.
#' @srrstatsNA {EA2.5} No index columns, for the reason given under EA2.0.
#' @srrstatsNA {EA5.1} No plot sets a typeface family (grep shows no `family=` in plots.R or policy_plots.R); device defaults are used.
#' @srrstatsNA {EA5.6} No dynamic-visualisation library is bundled: base graphics only, Imports are base packages, and inst/ holds no .js files.
#' @srrstatsNA {TS1.0} Series are short published tables keyed by period columns (fiscal years, dates), not regular ts objects; plain vectors and data frames are deliberate, and yoy() also accepts ts.
#' @srrstatsNA {TS1.7} Inputs are dimensionless counts or periods and days the user sets; there is no physical-unit arithmetic for the units package to protect.
#' @srrstatsNA {TS2.1c} Imputing a missing published count would invent an official statistic; missing periods are kept as gaps (yoy) or dropped (trndtst, cnttrnd).
#' @srrstatsNA {TS2.5} No auto-covariance matrix is returned; the INAR route's autocovariances stay internal. evstudy's vcov is a covariance of estimates, labelled by event time.
#' @srrstatsNA {TS2.6} No auto-covariance matrices are returned (see TS2.5).
#' @srrstatsNA {TS3.1} Under the one constant-rate Poisson projection (trcprog), interval width is monotone in horizon by construction, so no valid case can break TS3.0.
#' @srrstatsNA {TS3.3} The only projection is one completion year with an interval, not a forecast path that could be trimmed to an error margin.
#' @srrstatsNA {TS3.3a} Same as TS3.3: there is no forecast path to trim.
#' @srrstatsNA {TS3.3b} Same as TS3.3: there is no forecast path to trim.
#' @srrstatsNA {TS4.0a} The alternative TS4.0b is followed: outputs are tables of changes or estimates, not re-expressions of the input series.
#' @srrstatsNA {TS4.4} No transformation is applied to data before the projection (trcprog uses raw cumulative counts), so there is no effect to document.
#' @srrstatsNA {TS4.5a} No stationarity-inducing transformation is applied, so there is nothing to back-transform.
#' @srrstatsNA {TS4.5b} No stationarity-inducing transformation is applied, so there is nothing to back-transform.
#' @srrstatsNA {TS4.6a} The alternative TS4.6c is followed; a single projected year does not call for a distribution object.
#' @srrstatsNA {TS4.6b} The alternative TS4.6c is followed: an exact interval is returned instead of a standard error.
#' @srrstatsNA {TS4.7a} The alternative TS4.7b is followed.
#' @srrstatsNA {TS4.7c} The alternative TS4.7b is followed.
#' @srrstatsNA {TS5.4} No frequency-domain or spectral output exists.
#'
#' @srrstatsTODO {G1.1} README/DESCRIPTION never says which methods are first R implementations and which re-implement existing ones (survey, Mann-Kendall, Hawkes).
#' @srrstatsTODO {G1.2} README has only a "lifecycle: maturing" badge (line 8); there is no written Life Cycle Statement about current and future development.
#' @srrstatsTODO {G1.4a} Only 77 @noRd blocks for about 697 internal functions; most internal helpers have plain # comments, and 235 have none at all.
#' @srrstatsTODO {G2.5} Factor-accepting docs never say whether ordered factors are expected or treated the same as unordered ones.
#' @srrstatsTODO {G5.2a} 63 stop() messages are duplicated (e.g. "`data` must be a data frame" appears 21 times; "`col` must name a column" 7 times).
#' @srrstatsTODO {G5.6b} The recovery test uses only polex()'s default seed; it should loop over several seeds.
#' @srrstatsTODO {G5.9} There are no noise-susceptibility tests; see G5.9a and G5.9b.
#' @srrstatsTODO {G5.9a} No test adds .Machine$double.eps-scale noise and checks that results barely move.
#' @srrstatsTODO {G5.9b} The tests only show that seeds 11 and 12 give different replicates; none shows that the results agree within tolerance across seeds.
#' @srrstatsTODO {G5.12} RMBL_LIVE_TESTS is described only in NEWS.md; there are no developer docs giving its network needs, runtime or artefacts.
#' @srrstatsTODO {EA1.0} README and vignettes describe the data and the questions but never name the intended users; add one sentence saying who the package is for.
#' @srrstatsTODO {EA5.0a} The default cex is base R's 1, and labels shrink to fit (title 0.85, row labels down to 0.45); nothing is enlarged for accessibility.
#' @srrstatsTODO {EA6.0d} Column types are tested only here and there (about 19 expectations); the main frames (yoy, rtcalc, cpsdrft, profcols) have no per-column class check.
#' @srrstatsTODO {TS1.6} chwkfit/chwknll refuse unsorted times, but stepchg never checks that x is ordered, and trndtst silently skips duplicated x periods.
#' @srrstatsTODO {TS2.4a} A fit with eta on its 0.99 upper bound (near-critical, probably non-stationary) appears only in `atbound`; no message or warning is raised.
#' @srrstatsTODO {TS3.0} trcprog's projection band widens with horizon by construction, but no test asserts it; test-indigenous.R checks only point values.
#' @srrstatsTODO {TS5.1} plot.rmbl_yoy(what = "value") draws an empty x label, and yoy and stkflow plots place periods at positions 1..n, not on a continuous time scale.
#' @srrstatsTODO {TS5.2} plot.rmbl_yoy (default pctchg) and plot.rmbl_rate_change use .bl_dot_interval, which puts the periods on the vertical axis.
#' @srrstatsTODO {TS5.3} Plots hard-code xlab = "Period" or "Periods since adoption" without the unit, and passing xlab through ... errors (matched twice).
#' @srrstatsTODO {TS5.5} .bl_line drops non-finite points, so a "no data" year inserted by yoy is joined over; there is no option for broken lines.
#' @noRd
NULL
